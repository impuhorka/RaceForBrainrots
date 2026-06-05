local Workspace = game:GetService("Workspace")

local Shared_BrainrotAnimations = require(game:GetService("ReplicatedStorage").Modules.Shared_BrainrotAnimations)

local Client_PlotBrainrotAnimations = {}

local hookedSlots: { [Model]: boolean } = {}
local hookedPlots: { [Model]: boolean } = {}
local hookedSlotsFolders: { [Folder]: boolean } = {}

local function playPlacedBrainrot(brainrotModel: Model)
	local configName = brainrotModel:GetAttribute("ConfigName")
	if type(configName) ~= "string" or configName == "" then
		return
	end

	Shared_BrainrotAnimations.PlayIdle(brainrotModel, configName)
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
end

return Client_PlotBrainrotAnimations
