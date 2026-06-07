local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared_BrainrotAnimations = require(game:GetService("ReplicatedStorage").Modules.Shared_BrainrotAnimations)

local Client_PlotBrainrotAnimations = {}

local hookedSlots: { [Model]: boolean } = {}
local hookedPlots: { [Model]: boolean } = {}
local hookedSlotsFolders: { [Folder]: boolean } = {}
local hookedTaggedModels: { [Model]: boolean } = {}
local ANIMATED_BRAINROT_TAG = "AnimatedBrainrot"

local function resolveConfigName(brainrotModel: Model): string?
	if CollectionService:HasTag(brainrotModel, ANIMATED_BRAINROT_TAG) then
		if brainrotModel.Name ~= "" then
			return brainrotModel.Name
		end
	end

	local configName = brainrotModel:GetAttribute("ConfigName")
	if type(configName) == "string" and configName ~= "" then
		return configName
	end

	return nil
end

local function playPlacedBrainrot(brainrotModel: Model)
	local configName = resolveConfigName(brainrotModel)
	if not configName then
		return
	end
	Shared_BrainrotAnimations.PlayIdle(brainrotModel, configName)
end

local function hookTaggedBrainrotModel(model: Model)
	if hookedTaggedModels[model] then
		return
	end
	hookedTaggedModels[model] = true

	if model:IsDescendantOf(Workspace) then
		playPlacedBrainrot(model)
	end

	model.AncestryChanged:Connect(function(_, newParent)
		if newParent and model:IsDescendantOf(Workspace) then
			playPlacedBrainrot(model)
		else
			Shared_BrainrotAnimations.StopIdle(model)
		end
	end)

	model.Destroying:Connect(function()
		hookedTaggedModels[model] = nil
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
		playPlacedBrainrot(placedBrainrot)
	end

	slotModel.ChildAdded:Connect(function(child)
		if child.Name == "PlacedBrainrot" and child:IsA("Model") then
			playPlacedBrainrot(child)
		end
	end)

	slotModel.ChildRemoved:Connect(function(child)
		if child.Name == "PlacedBrainrot" and child:IsA("Model") then
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
end

return Client_PlotBrainrotAnimations
