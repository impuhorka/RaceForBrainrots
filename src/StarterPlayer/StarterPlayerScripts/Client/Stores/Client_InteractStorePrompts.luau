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
}

local PROMPT_DISTANCE = 25
local hookedStores: { [Model]: boolean } = {}
local watchingStores: { [Model]: boolean } = {}
local storeModels: { [string]: Model } = {}

local function getProximityPart(storeModel: Model): BasePart?
	local proximityPart = storeModel:FindFirstChild("ProximityPart", true)
	if proximityPart and proximityPart:IsA("BasePart") then
		return proximityPart
	end
	return nil
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
			if descendant.Name ~= "ProximityPart" or not descendant:IsA("BasePart") then
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
			watchingStores[storeModel] = nil
		end)
		return
	end

	hookedStores[storeModel] = true
	storeModels[storeModel.Name] = storeModel

	local prompt = Shared_ProximityPrompt.Create(proximityPart, {
		Name = storeModel.Name .. "Prompt",
		ActionText = "Open!",
		ObjectText = "",
		HoldDuration = 0.5,
		MaxActivationDistance = PROMPT_DISTANCE,
		RequiresLineOfSight = false,
		Enabled = true,
	})

	prompt.Triggered:Connect(function()
		openStoreFrame(storeModel.Name)
	end)

	storeModel.Destroying:Connect(function()
		hookedStores[storeModel] = nil
		watchingStores[storeModel] = nil
		storeModels[storeModel.Name] = nil
	end)
end

local function tryHookStoreModel(instance: Instance)
	if instance:IsA("Model") and STORE_MODELS[instance.Name] then
		setupStorePrompt(instance)
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
	local interactFolder = gameFolder:WaitForChild("Interact")

	for _, descendant in interactFolder:GetDescendants() do
		tryHookStoreModel(descendant)
	end

	interactFolder.DescendantAdded:Connect(tryHookStoreModel)

	watchStoreDistance()
end

return Client_InteractStorePrompts