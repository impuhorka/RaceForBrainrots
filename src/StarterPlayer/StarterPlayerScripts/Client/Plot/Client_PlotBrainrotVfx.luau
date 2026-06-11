local Workspace = game:GetService("Workspace")
local ClientLoader = require(script.Parent.Parent.Loader)

local Client_ModelVfx = ClientLoader.require("Client_ModelVfx")
local Client_VisualSettings = ClientLoader.require("Client_VisualSettings")

local Client_PlotBrainrotVfx = {}

local hookedPlots: { [Model]: boolean } = {}
local hookedSlotsFolders: { [Folder]: boolean } = {}
local hookedBrainrots: { [Model]: boolean } = {}

local function applyEffectsToAll()
	local effectsEnabled = Client_VisualSettings.AreEffectsEnabled()
	for brainrotModel in hookedBrainrots do
		if brainrotModel.Parent then
			Client_ModelVfx.ApplyToModel(brainrotModel, effectsEnabled)
		end
	end
end

local function hookBrainrotModel(brainrotModel: Model)
	if hookedBrainrots[brainrotModel] then
		Client_ModelVfx.ApplyToModel(brainrotModel, Client_VisualSettings.AreEffectsEnabled())
		return
	end
	hookedBrainrots[brainrotModel] = true

	Client_ModelVfx.TrackModel(brainrotModel, Client_VisualSettings.AreEffectsEnabled())

	brainrotModel.Destroying:Connect(function()
		hookedBrainrots[brainrotModel] = nil
		Client_ModelVfx.UntrackModel(brainrotModel)
	end)
end

local function hookSlot(slotModel: Model)
	local placedBrainrot = slotModel:FindFirstChild("PlacedBrainrot")
	if placedBrainrot and placedBrainrot:IsA("Model") then
		hookBrainrotModel(placedBrainrot)
	end

	slotModel.ChildAdded:Connect(function(child)
		if child.Name == "PlacedBrainrot" and child:IsA("Model") then
			hookBrainrotModel(child)
		end
	end)

	slotModel.ChildRemoved:Connect(function(child)
		if child.Name == "PlacedBrainrot" and child:IsA("Model") then
			hookedBrainrots[child] = nil
			Client_ModelVfx.UntrackModel(child)
		end
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
end

local function hookPlot(plotModel: Model)
	if not hookedPlots[plotModel] then
		hookedPlots[plotModel] = true

		plotModel.ChildAdded:Connect(function(child)
			if child.Name == "Slots" and child:IsA("Folder") then
				hookSlotsFolder(child)
			end
		end)
	end

	local slotsFolder = plotModel:FindFirstChild("Slots")
	if slotsFolder and slotsFolder:IsA("Folder") then
		hookSlotsFolder(slotsFolder)
	end
end

function Client_PlotBrainrotVfx.Init()
	local gameFolder = Workspace:WaitForChild("Game", 30)
	if not gameFolder then
		return
	end

	local plotsFolder = gameFolder:WaitForChild("Plots", 30)
	if not plotsFolder then
		return
	end

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

	Client_VisualSettings.Listen(function()
		applyEffectsToAll()
	end)
end

return Client_PlotBrainrotVfx
