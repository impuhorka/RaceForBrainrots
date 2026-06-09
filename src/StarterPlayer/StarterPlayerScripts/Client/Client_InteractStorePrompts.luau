local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared_ProximityPrompt = require(ReplicatedStorage.Modules.Shared_ProximityPrompt)
local FrameController = require(script.Parent.Parent.UI.FrameController)

local Client_InteractStorePrompts = {}

local STORE_MODELS = {
	StrengthStore = true,
	SpeedStore = true,
}

local PROMPT_DISTANCE = 25
local hookedStores: { [Model]: boolean } = {}
local storeModels: { [string]: Model } = {}

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
	if hookedStores[storeModel] then
		return
	end
	hookedStores[storeModel] = true
	storeModels[storeModel.Name] = storeModel

	local proximityPart = storeModel:FindFirstChild("ProximityPart")
	if not proximityPart or not proximityPart:IsA("BasePart") then
		return
	end

	local prompt = Shared_ProximityPrompt.Create(proximityPart, {
		Name = storeModel.Name .. "Prompt",
		ActionText = "Open!",
		ObjectText = "",
		HoldDuration = 0.5,
		MaxActivationDistance = PROMPT_DISTANCE,
		RequiresLineOfSight = false,
	})

	prompt.Triggered:Connect(function()
		openStoreFrame(storeModel.Name)
	end)

	storeModel.Destroying:Connect(function()
		hookedStores[storeModel] = nil
		storeModels[storeModel.Name] = nil
	end)
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
		local playerPosition = getPlayerPosition()
		if not playerPosition then
			return
		end

		for storeName in pairs(STORE_MODELS) do
			local frame = FrameController.getFrame(storeName)
			if not frame or not frame.Visible then
				continue
			end

			local storeModel = storeModels[storeName]
			if not storeModel then
				continue
			end

			local proximityPart = storeModel:FindFirstChild("ProximityPart")
			if not proximityPart or not proximityPart:IsA("BasePart") then
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
	local interactFolder = gameFolder:WaitForChild("Interact")

	for _, child in interactFolder:GetChildren() do
		if child:IsA("Model") and STORE_MODELS[child.Name] then
			setupStorePrompt(child)
		end
	end

	interactFolder.ChildAdded:Connect(function(child)
		if child:IsA("Model") and STORE_MODELS[child.Name] then
			setupStorePrompt(child)
		end
	end)

	watchStoreDistance()
end

return Client_InteractStorePrompts
