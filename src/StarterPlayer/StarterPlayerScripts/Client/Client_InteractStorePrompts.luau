local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
end

return Client_InteractStorePrompts
