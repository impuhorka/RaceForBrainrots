local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Client_Data = require(script.Parent.Client_Data)

local Client_PlotSpawnAnimation = {}

local SCALE_IN_TIME = 0.392
local MIN_AXIS_SIZE = 0.05
local START_SCALE_FACTOR = 0.01

local localPlayer = Players.LocalPlayer

local watchedPlots: { [Model]: boolean } = {}
local watchedPlotConnections: { [Model]: { RBXScriptConnection } } = {}
local seenInstancesByPlot: { [Model]: { [Instance]: boolean } } = {}

local function getOwnerUserId(plotModel: Model): number
	return tonumber(plotModel:GetAttribute("OwnerUserId")) or 0
end

local function isOwnPlot(plotModel: Model): boolean
	return getOwnerUserId(plotModel) == localPlayer.UserId
end

local function hasAncestorNamed(instance: Instance, targetName: string): boolean
	local current = instance.Parent
	while current do
		if current.Name == targetName then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isSpawnAnimatedPart(part: BasePart): boolean
	if hasAncestorNamed(part, "PlacedBrainrot") then
		return false
	end
	return true
end

local function getStartSize(size: Vector3): Vector3
	return Vector3.new(
		math.max(MIN_AXIS_SIZE, size.X * START_SCALE_FACTOR),
		math.max(MIN_AXIS_SIZE, size.Y * START_SCALE_FACTOR),
		math.max(MIN_AXIS_SIZE, size.Z * START_SCALE_FACTOR)
	)
end

local function animatePartScaleIn(part: BasePart)
	if not part.Parent or not isSpawnAnimatedPart(part) then
		return
	end

	local originalSize = part.Size
	part.Size = getStartSize(originalSize)

	TweenService:Create(
		part,
		TweenInfo.new(SCALE_IN_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = originalSize }
	):Play()
end

local function animateModelPartsScaleIn(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			animatePartScaleIn(descendant)
		end
	end
end

local function markExistingDescendants(plotModel: Model)
	local seen = seenInstancesByPlot[plotModel]
	if not seen then
		seen = {}
		seenInstancesByPlot[plotModel] = seen
	end

	for _, descendant in plotModel:GetDescendants() do
		seen[descendant] = true
	end
end

local function onPlotDescendantAdded(plotModel: Model, descendant: Instance)
	local seen = seenInstancesByPlot[plotModel]
	if not seen then
		seen = {}
		seenInstancesByPlot[plotModel] = seen
	end
	if seen[descendant] then
		return
	end
	seen[descendant] = true

	if not isOwnPlot(plotModel) then
		return
	end

	if descendant:IsA("BasePart") then
		task.defer(animatePartScaleIn, descendant)
	end
end

local function unwatchPlot(plotModel: Model)
	watchedPlots[plotModel] = nil
	seenInstancesByPlot[plotModel] = nil
	local connections = watchedPlotConnections[plotModel]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
		watchedPlotConnections[plotModel] = nil
	end
end

local function watchPlot(plotModel: Model)
	if watchedPlots[plotModel] then
		return
	end
	watchedPlots[plotModel] = true

	markExistingDescendants(plotModel)

	local connections: { RBXScriptConnection } = {}
	table.insert(connections, plotModel.DescendantAdded:Connect(function(descendant: Instance)
		onPlotDescendantAdded(plotModel, descendant)
	end))

	table.insert(connections, plotModel.Destroying:Connect(function()
		unwatchPlot(plotModel)
	end))

	watchedPlotConnections[plotModel] = connections
end

local function hookPlotsFolder(plotsFolder: Folder)
	for _, child in plotsFolder:GetChildren() do
		if child:IsA("Model") then
			watchPlot(child)
		end
	end

	plotsFolder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			watchPlot(child)
		end
	end)
end

function Client_PlotSpawnAnimation.Init()
	Client_Data.WaitUntilReady()

	local gameFolder = Workspace:WaitForChild("Game")
	local plotsFolder = gameFolder:WaitForChild("Plots")
	hookPlotsFolder(plotsFolder)
end

function Client_PlotSpawnAnimation.AnimateSlotPlace(slotModel: Model)
	if not slotModel or not slotModel.Parent then
		return
	end
	animateModelPartsScaleIn(slotModel)
end

return Client_PlotSpawnAnimation
