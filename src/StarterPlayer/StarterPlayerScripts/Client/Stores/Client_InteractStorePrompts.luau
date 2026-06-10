local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared_ProximityPrompt = SharedModules.require("Shared_ProximityPrompt")
local FrameController = require(script.Parent.Parent.Parent.UI.FrameController)

local Client_InteractStorePrompts = {}

local STORE_MODELS = {
	StrengthStore = true,
	SpeedStore = true,
	Rebirth = true,
}

local CLOSE_ON_WALK_AWAY = {
	StrengthStore = true,
	SpeedStore = true,
}

local PROXIMITY_PART_NAMES = {
	ProximityPart = true,
	ProximityPrompt = true,
}

local PROMPT_DISTANCE = 25
local RESCAN_INTERVAL_SECONDS = 2

local hookedStores: { [Model]: boolean } = {}
local watchingStores: { [Model]: boolean } = {}
local storeModels: { [string]: Model } = {}
local boundInteractFolder: Instance?
local lastRescanAt = 0

local function isProximityAnchorPart(instance: Instance): boolean
	return instance:IsA("BasePart") and PROXIMITY_PART_NAMES[instance.Name] == true
end

local function getProximityPart(storeModel: Model): BasePart?
	for _, descendant in storeModel:GetDescendants() do
		if isProximityAnchorPart(descendant) then
			return descendant
		end
	end
	return nil
end

local function findExistingPrompt(proximityPart: BasePart): ProximityPrompt?
	for _, child in proximityPart:GetChildren() do
		if child:IsA("ProximityPrompt") then
			return child
		end
	end
	return nil
end

local function getStorePromptName(storeModel: Model): string
	return storeModel.Name .. "Prompt"
end

local function getStorePrompt(storeModel: Model): ProximityPrompt?
	local proximityPart = getProximityPart(storeModel)
	if not proximityPart then
		return nil
	end

	local prompt = proximityPart:FindFirstChild(getStorePromptName(storeModel))
	if prompt and prompt:IsA("ProximityPrompt") then
		return prompt
	end

	return nil
end

local function clearStoreHook(storeModel: Model)
	hookedStores[storeModel] = nil
	watchingStores[storeModel] = nil
	if storeModels[storeModel.Name] == storeModel then
		storeModels[storeModel.Name] = nil
	end
end

local function openStoreFrame(storeName: string)
	local frame = FrameController.getFrame(storeName)
	if not frame then
		return
	end

	if frame.Visible then
		return
	end

	FrameController.open(frame)
end

local function setupStorePrompt(storeModel: Model)
	if getStorePrompt(storeModel) and hookedStores[storeModel] then
		return
	end

	if hookedStores[storeModel] and not getStorePrompt(storeModel) then
		clearStoreHook(storeModel)
	end

	if hookedStores[storeModel] then
		return
	end

	local proximityPart = getProximityPart(storeModel)
	if not proximityPart then
		if watchingStores[storeModel] then
			return
		end
		watchingStores[storeModel] = true

		local connection: RBXScriptConnection?
		connection = storeModel.DescendantAdded:Connect(function(descendant)
			if not isProximityAnchorPart(descendant) then
				return
			end
			if connection then
				connection:Disconnect()
				connection = nil
			end
			watchingStores[storeModel] = nil
			setupStorePrompt(storeModel)
		end)

		storeModel.Destroying:Connect(function()
			if connection then
				connection:Disconnect()
			end
			clearStoreHook(storeModel)
		end)
		return
	end

	hookedStores[storeModel] = true
	storeModels[storeModel.Name] = storeModel

	local promptOptions = {
		Name = getStorePromptName(storeModel),
		ActionText = "Open!",
		ObjectText = "",
		HoldDuration = 0.5,
		MaxActivationDistance = PROMPT_DISTANCE,
		RequiresLineOfSight = false,
		Enabled = true,
	}

	local prompt = findExistingPrompt(proximityPart)
	if prompt then
		Shared_ProximityPrompt.Apply(prompt, promptOptions)
	else
		prompt = Shared_ProximityPrompt.Create(proximityPart, promptOptions)
	end

	prompt.Triggered:Connect(function()
		openStoreFrame(storeModel.Name)
	end)

	prompt.Destroying:Connect(function()
		clearStoreHook(storeModel)
		if storeModel.Parent then
			task.defer(setupStorePrompt, storeModel)
		end
	end)

	storeModel.Destroying:Connect(function()
		clearStoreHook(storeModel)
	end)
end

local function tryHookStoreModel(instance: Instance)
	if instance:IsA("Model") and STORE_MODELS[instance.Name] then
		setupStorePrompt(instance)
	end
end

local function scanInteractFolder(interactFolder: Instance)
	for _, descendant in interactFolder:GetDescendants() do
		tryHookStoreModel(descendant)
	end
end

local function bindInteractFolder(interactFolder: Instance)
	if boundInteractFolder == interactFolder then
		scanInteractFolder(interactFolder)
		return
	end

	boundInteractFolder = interactFolder
	scanInteractFolder(interactFolder)
	interactFolder.DescendantAdded:Connect(tryHookStoreModel)
end

local function tryBindInteractFolder()
	local gameFolder = Workspace:FindFirstChild("Game")
	local interactFolder = gameFolder and gameFolder:FindFirstChild("Interact")
	if interactFolder then
		bindInteractFolder(interactFolder)
	end
end

local function rescanStorePrompts()
	local gameFolder = Workspace:FindFirstChild("Game")
	local interactFolder = gameFolder and gameFolder:FindFirstChild("Interact")
	if not interactFolder then
		return
	end

	for _, descendant in interactFolder:GetDescendants() do
		if descendant:IsA("Model") and STORE_MODELS[descendant.Name] then
			if not getStorePrompt(descendant) then
				clearStoreHook(descendant)
				setupStorePrompt(descendant)
			end
		end
	end
end

local function getPlayerPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function watchStoreDistance()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastRescanAt >= RESCAN_INTERVAL_SECONDS then
			lastRescanAt = now
			tryBindInteractFolder()
			rescanStorePrompts()
		end

		local playerPosition = getPlayerPosition()
		if not playerPosition then
			return
		end

		for storeName in pairs(STORE_MODELS) do
			if not CLOSE_ON_WALK_AWAY[storeName] then
				continue
			end

			local frame = FrameController.getFrame(storeName)
			if not frame or not frame.Visible then
				continue
			end

			local storeModel = storeModels[storeName]
			if not storeModel then
				continue
			end

			local proximityPart = getProximityPart(storeModel)
			if not proximityPart then
				continue
			end

			if (playerPosition - proximityPart.Position).Magnitude > PROMPT_DISTANCE then
				FrameController.close(frame)
			end
		end
	end)
end

function Client_InteractStorePrompts.Init()
	local gameFolder = Workspace:WaitForChild("Game")
	gameFolder.ChildAdded:Connect(function(child)
		if child.Name == "Interact" then
			bindInteractFolder(child)
		end
	end)

	tryBindInteractFolder()
	watchStoreDistance()
end

return Client_InteractStorePrompts
