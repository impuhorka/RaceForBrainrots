local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared_BrainrotAnimations = require(game:GetService("ReplicatedStorage").Modules.Shared_BrainrotAnimations)
local Client_Data = require(script.Parent.Client_Data)

local Client_PlotBrainrotAnimations = {}

local hookedSlots: { [Model]: boolean } = {}
local hookedPlots: { [Model]: boolean } = {}
local hookedSlotsFolders: { [Folder]: boolean } = {}
local hookedTaggedModels: { [Model]: boolean } = {}
local hookedPlacedModels: { [Model]: boolean } = {}
local playRetryTokens: { [Model]: number } = {}
local ANIMATED_BRAINROT_TAG = "AnimatedBrainrot"

local function resolveConfigName(brainrotModel: Model): string?
	local configName = brainrotModel:GetAttribute("ConfigName")
	if type(configName) == "string" and configName ~= "" then
		return configName
	end

	if CollectionService:HasTag(brainrotModel, ANIMATED_BRAINROT_TAG) then
		if brainrotModel.Name ~= "" and brainrotModel.Name ~= "PlacedBrainrot" then
			return brainrotModel.Name
		end
	end

	return nil
end

local function playPlacedBrainrot(brainrotModel: Model): boolean
	if Client_Data:GetValue("Animations") == false then
		return false
	end

	local configName = resolveConfigName(brainrotModel)
	if not configName then
		return false
	end
	return Shared_BrainrotAnimations.PlayIdle(brainrotModel, configName) ~= nil
end

local function queuePlayRetry(brainrotModel: Model)
	local token = (playRetryTokens[brainrotModel] or 0) + 1
	playRetryTokens[brainrotModel] = token

	task.spawn(function()
		for _ = 1, 15 do
			if playRetryTokens[brainrotModel] ~= token then
				return
			end

			if not brainrotModel.Parent or not brainrotModel:IsDescendantOf(Workspace) then
				return
			end

			if playPlacedBrainrot(brainrotModel) then
				return
			end

			task.wait(0.2)
		end
	end)
end

local function hookPlacedBrainrotModel(brainrotModel: Model)
	if hookedPlacedModels[brainrotModel] then
		if brainrotModel:IsDescendantOf(Workspace) and not playPlacedBrainrot(brainrotModel) then
			queuePlayRetry(brainrotModel)
		end
		return
	end
	hookedPlacedModels[brainrotModel] = true

	if brainrotModel:IsDescendantOf(Workspace) and not playPlacedBrainrot(brainrotModel) then
		queuePlayRetry(brainrotModel)
	end

	brainrotModel:GetAttributeChangedSignal("ConfigName"):Connect(function()
		if brainrotModel:IsDescendantOf(Workspace) and not playPlacedBrainrot(brainrotModel) then
			queuePlayRetry(brainrotModel)
		end
	end)

	brainrotModel.AncestryChanged:Connect(function(_, newParent)
		if newParent and brainrotModel:IsDescendantOf(Workspace) then
			if not playPlacedBrainrot(brainrotModel) then
				queuePlayRetry(brainrotModel)
			end
		else
			Shared_BrainrotAnimations.StopIdle(brainrotModel)
		end
	end)

	brainrotModel.Destroying:Connect(function()
		hookedPlacedModels[brainrotModel] = nil
		playRetryTokens[brainrotModel] = nil
		Shared_BrainrotAnimations.StopIdle(brainrotModel)
	end)
end

local function hookTaggedBrainrotModel(model: Model)
	if hookedTaggedModels[model] then
		return
	end
	hookedTaggedModels[model] = true

	if model:IsDescendantOf(Workspace) then
		if not playPlacedBrainrot(model) then
			queuePlayRetry(model)
		end
	end

	model.AncestryChanged:Connect(function(_, newParent)
		if newParent and model:IsDescendantOf(Workspace) then
			if not playPlacedBrainrot(model) then
				queuePlayRetry(model)
			end
		else
			Shared_BrainrotAnimations.StopIdle(model)
		end
	end)

	model.Destroying:Connect(function()
		hookedTaggedModels[model] = nil
		playRetryTokens[model] = nil
		Shared_BrainrotAnimations.StopIdle(model)
	end)
end

local function hookSlot(slotModel: Model)
	if hookedSlots[slotModel] then
		return
	end
	hookedSlots[slotModel] = true

	local placedBrainrot = slotModel:FindFirstChild("PlacedBrainrot")
	if placedBrainrot and placedBrainrot:IsA("Model") then
		hookPlacedBrainrotModel(placedBrainrot)
	end

	slotModel.ChildAdded:Connect(function(child)
		if child.Name == "PlacedBrainrot" and child:IsA("Model") then
			hookPlacedBrainrotModel(child)
		end
	end)

	slotModel.ChildRemoved:Connect(function(child)
		if child.Name == "PlacedBrainrot" and child:IsA("Model") then
			hookedPlacedModels[child] = nil
			playRetryTokens[child] = nil
			Shared_BrainrotAnimations.StopIdle(child)
		end
	end)

	slotModel.Destroying:Connect(function()
		hookedSlots[slotModel] = nil
	end)
end

local function hookSlotsFolder(slotsFolder: Folder)
	if hookedSlotsFolders[slotsFolder] then
		return
	end
	hookedSlotsFolders[slotsFolder] = true

	for _, slotModel in slotsFolder:GetChildren() do
		if slotModel:IsA("Model") then
			hookSlot(slotModel)
		end
	end

	slotsFolder.ChildAdded:Connect(function(slotModel)
		if slotModel:IsA("Model") then
			hookSlot(slotModel)
		end
	end)

	slotsFolder.Destroying:Connect(function()
		hookedSlotsFolders[slotsFolder] = nil
	end)
end

local function stopAllAnimations()
	for model in hookedPlacedModels do
		if model.Parent then
			Shared_BrainrotAnimations.StopIdle(model)
		end
	end

	for model in hookedTaggedModels do
		if model.Parent then
			Shared_BrainrotAnimations.StopIdle(model)
		end
	end
end

local function refreshAllAnimations()
	if Client_Data:GetValue("Animations") == false then
		stopAllAnimations()
		return
	end

	for model in hookedPlacedModels do
		if model.Parent and model:IsDescendantOf(Workspace) then
			if not playPlacedBrainrot(model) then
				queuePlayRetry(model)
			end
		end
	end

	for model in hookedTaggedModels do
		if model.Parent and model:IsDescendantOf(Workspace) then
			if not playPlacedBrainrot(model) then
				queuePlayRetry(model)
			end
		end
	end
end

local function hookPlot(plotModel: Model)
	if not hookedPlots[plotModel] then
		hookedPlots[plotModel] = true

		plotModel.ChildAdded:Connect(function(child)
			if child.Name == "Slots" and child:IsA("Folder") then
				hookSlotsFolder(child)
			end
		end)

		plotModel.Destroying:Connect(function()
			hookedPlots[plotModel] = nil
		end)
	end

	local slotsFolder = plotModel:FindFirstChild("Slots")
	if slotsFolder and slotsFolder:IsA("Folder") then
		hookSlotsFolder(slotsFolder)
	end
end

function Client_PlotBrainrotAnimations.Init()
	Client_Data.WaitUntilReady()

	local gameFolder = Workspace:WaitForChild("Game")
	local plotsFolder = gameFolder:WaitForChild("Plots")

	for _, plotModel in plotsFolder:GetChildren() do
		if plotModel:IsA("Model") then
			hookPlot(plotModel)
		end
	end

	plotsFolder.ChildAdded:Connect(function(plotModel)
		if plotModel:IsA("Model") then
			hookPlot(plotModel)
		end
	end)

	for _, tagged in CollectionService:GetTagged(ANIMATED_BRAINROT_TAG) do
		if tagged:IsA("Model") then
			hookTaggedBrainrotModel(tagged)
		end
	end

	CollectionService:GetInstanceAddedSignal(ANIMATED_BRAINROT_TAG):Connect(function(instance)
		if instance:IsA("Model") then
			hookTaggedBrainrotModel(instance)
		end
	end)

	CollectionService:GetInstanceRemovedSignal(ANIMATED_BRAINROT_TAG):Connect(function(instance)
		if instance:IsA("Model") then
			Shared_BrainrotAnimations.StopIdle(instance)
		end
	end)

	Client_Data:ListenToChange("Animations", refreshAllAnimations)
end

return Client_PlotBrainrotAnimations
