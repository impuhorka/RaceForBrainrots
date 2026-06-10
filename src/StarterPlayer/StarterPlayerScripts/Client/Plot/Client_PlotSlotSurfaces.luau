local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local Workspace = game:GetService("Workspace")
local ClientLoader = require(script.Parent.Parent.Loader)

local Shared_Abbreviation = SharedModules.require("Shared_Abbreviation")
local Shared_Brainrots = SharedModules.require("Shared_Brainrots")

local Client_Data = ClientLoader.require("Client_Data")
local Client_Messaging = ClientLoader.require("Client_Messaging")

local localPlayer = Players.LocalPlayer

local Client_PlotSlotSurfaces = {}

local slotGuis: { [Model]: SurfaceGui } = {}
local watchingSlots: { [Model]: boolean } = {}
local hookedPlots: { [Model]: boolean } = {}
local hookedSlotsFolders: { [Folder]: boolean } = {}
local cachedSlotLevels: { [Model]: number } = {}

local plotHandler: RemoteEvent

local function getOwnerUserId(plotModel: Model): number
	return tonumber(plotModel:GetAttribute("OwnerUserId")) or 0
end

local function getSurfaceGuisFolder(): Folder
	local main = localPlayer:WaitForChild("PlayerGui"):WaitForChild("Main")
	local folder = main:FindFirstChild("SurfaceGuis")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SurfaceGuis"
		folder.Parent = main
	end
	return folder :: Folder
end

local function getUpgradePart(slotModel: Model): BasePart?
	local upgradePart = slotModel:FindFirstChild("UpgradePart", true)
	if upgradePart and upgradePart:IsA("BasePart") then
		return upgradePart
	end
	return nil
end

local function getUpgradeSurfaceTemplate(upgradePart: BasePart): SurfaceGui?
	local named = upgradePart:FindFirstChild("UpgradeDisplay")
	if named and named:IsA("SurfaceGui") then
		return named
	end

	for _, child in upgradePart:GetChildren() do
		if child:IsA("SurfaceGui") then
			return child
		end
	end

	return upgradePart:FindFirstChildWhichIsA("SurfaceGui")
end

local function getUpgradeLabels(gui: SurfaceGui): (TextLabel?, TextLabel?)
	local imageButton = gui:FindFirstChild("ImageButton", true)
	if not imageButton then
		return nil, nil
	end

	local costLabel = imageButton:FindFirstChild("Cost")
	local levelLabel = imageButton:FindFirstChild("Level")

	if costLabel and costLabel:IsA("TextLabel") and levelLabel and levelLabel:IsA("TextLabel") then
		return costLabel, levelLabel
	end

	return nil, nil
end

local function getUpgradeButton(gui: SurfaceGui): ImageButton?
	local imageButton = gui:FindFirstChild("ImageButton", true)
	if imageButton and imageButton:IsA("ImageButton") then
		return imageButton
	end
	return nil
end

local function getSlotId(slotModel: Model): number
	return tonumber(string.match(slotModel.Name, "%d+")) or 0
end

local function hasBrainrot(slotModel: Model): boolean
	local configName = slotModel:GetAttribute("ConfigName")
	return type(configName) == "string" and configName ~= ""
end

local function getSlotLevel(slotModel: Model): number
	return cachedSlotLevels[slotModel] or math.max(1, slotModel:GetAttribute("Level") or 1)
end

local function findOwnSlotModel(slotId: number): Model?
	local gameFolder = Workspace:FindFirstChild("Game")
	local plotsFolder = gameFolder and gameFolder:FindFirstChild("Plots")
	if not plotsFolder then
		return nil
	end

	for _, plotModel in plotsFolder:GetChildren() do
		if plotModel:IsA("Model") and getOwnerUserId(plotModel) == localPlayer.UserId then
			local slotsFolder = plotModel:FindFirstChild("Slots")
			if slotsFolder then
				local slotModel = slotsFolder:FindFirstChild("Slot" .. slotId)
				if slotModel and slotModel:IsA("Model") then
					return slotModel
				end
			end
		end
	end

	return nil
end

local function tryUpgrade(slotModel: Model)
	if not hasBrainrot(slotModel) then
		return
	end

	local configName = slotModel:GetAttribute("ConfigName")
	if type(configName) ~= "string" or not Shared_Brainrots.Data[configName] then
		return
	end

	local level = getSlotLevel(slotModel)
	if level >= (Shared_Brainrots.MaxLevel or 150) then
		return
	end

	local modifier = slotModel:GetAttribute("Modifier") or "Normal"
	local baseWeight = slotModel:GetAttribute("BaseWeight")
	local weight = slotModel:GetAttribute("Weight")
	local upgradeCost = Shared_Brainrots.GetUpgradeCost(configName, level, modifier, baseWeight, weight)
	local cash = Client_Data:GetValue("Cash") or 0

	if cash < upgradeCost then
		Client_Messaging.Show("You need more cash to purchase this upgrade!", "red")
		return
	end

	local slotId = getSlotId(slotModel)
	if slotId <= 0 then
		return
	end

	plotHandler:FireServer("Upgrade", slotId)
end

local function setupUpgradeButton(slotModel: Model, upgradeGui: SurfaceGui)
	local imageButton = getUpgradeButton(upgradeGui)
	if not imageButton then
		return
	end

	imageButton.MouseButton1Click:Connect(function()
		tryUpgrade(slotModel)
	end)
end

local function updateUpgradeLabels(slotModel: Model, upgradeGui: SurfaceGui?)
	if not upgradeGui or not upgradeGui.Parent then
		return
	end

	local costLabel, levelLabel = getUpgradeLabels(upgradeGui)
	if not costLabel or not levelLabel then
		return
	end

	if not hasBrainrot(slotModel) then
		return
	end

	local configName = slotModel:GetAttribute("ConfigName")
	if type(configName) ~= "string" or not Shared_Brainrots.Data[configName] then
		return
	end

	local level = getSlotLevel(slotModel)
	local modifier = slotModel:GetAttribute("Modifier") or "Normal"
	local baseWeight = slotModel:GetAttribute("BaseWeight")
	local weight = slotModel:GetAttribute("Weight")
	local maxLevel = Shared_Brainrots.MaxLevel or 150

	if level >= maxLevel then
		costLabel.Text = "$--"
		levelLabel.Text = ("Level %s -> %s"):format(level, level)
		return
	end

	local upgradeCost = Shared_Brainrots.GetUpgradeCost(configName, level, modifier, baseWeight, weight)
	costLabel.Text = ("$%s"):format(Shared_Abbreviation:Number(upgradeCost))
	levelLabel.Text = ("Level %s -> %s"):format(level, level + 1)
end

local function updateSlotVisuals(slotModel: Model, upgradeGui: SurfaceGui?)
	if upgradeGui and upgradeGui.Parent then
		upgradeGui.Enabled = hasBrainrot(slotModel)
		updateUpgradeLabels(slotModel, upgradeGui)
	end
end

local function refreshAllSlotVisuals()
	for slotModel, gui in slotGuis do
		if slotModel.Parent and gui.Parent then
			updateSlotVisuals(slotModel, gui)
		else
			slotGuis[slotModel] = nil
		end
	end
end

local function cleanupSlotSurface(slotModel: Model)
	local gui = slotGuis[slotModel]
	if gui then
		gui:Destroy()
		slotGuis[slotModel] = nil
	end
	watchingSlots[slotModel] = nil
end

local function setupSlotSurface(slotModel: Model)
	if slotGuis[slotModel] then
		updateSlotVisuals(slotModel, slotGuis[slotModel])
		return
	end

	local upgradePart = getUpgradePart(slotModel)
	if not upgradePart then
		if not watchingSlots[slotModel] then
			watchingSlots[slotModel] = true
			slotModel.DescendantAdded:Connect(function()
				if getUpgradePart(slotModel) then
					setupSlotSurface(slotModel)
				end
			end)
			slotModel.Destroying:Connect(function()
				watchingSlots[slotModel] = nil
			end)
		end
		return
	end

	local template = getUpgradeSurfaceTemplate(upgradePart)
	if not template then
		return
	end

	template.Enabled = false

	local slotId = getSlotId(slotModel)
	local gui = template:Clone()
	gui.Name = "UpgradeDisplay_Slot" .. slotId
	gui.Parent = getSurfaceGuisFolder()
	gui.Adornee = upgradePart
	gui.Enabled = hasBrainrot(slotModel)

	slotGuis[slotModel] = gui

	updateUpgradeLabels(slotModel, gui)
	setupUpgradeButton(slotModel, gui)

	slotModel:GetAttributeChangedSignal("ConfigName"):Connect(function()
		updateSlotVisuals(slotModel, gui)
	end)

	slotModel:GetAttributeChangedSignal("Level"):Connect(function()
		local level = slotModel:GetAttribute("Level")
		if type(level) == "number" then
			cachedSlotLevels[slotModel] = level
		end
		updateUpgradeLabels(slotModel, gui)
	end)

	slotModel:GetAttributeChangedSignal("Modifier"):Connect(function()
		updateUpgradeLabels(slotModel, gui)
	end)

	slotModel.Destroying:Connect(function()
		cleanupSlotSurface(slotModel)
	end)
end

local function setupAllSlots(slotsFolder: Folder)
	for _, slotModel in slotsFolder:GetChildren() do
		if slotModel:IsA("Model") then
			setupSlotSurface(slotModel)
		end
	end
	refreshAllSlotVisuals()
end

local function cleanupPlotSurfaces(plotModel: Model)
	local slotsFolder = plotModel:FindFirstChild("Slots")
	if not slotsFolder then
		return
	end

	for _, slotModel in slotsFolder:GetChildren() do
		if slotModel:IsA("Model") then
			cleanupSlotSurface(slotModel)
		end
	end
end

local function hookSlotsFolder(slotsFolder: Folder)
	if not hookedSlotsFolders[slotsFolder] then
		hookedSlotsFolders[slotsFolder] = true

		slotsFolder.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				setupSlotSurface(child)
			end
		end)

		slotsFolder.ChildRemoved:Connect(function(child)
			if child:IsA("Model") then
				cleanupSlotSurface(child)
			end
		end)
	end

	setupAllSlots(slotsFolder)
end

local function refreshPlot(plotModel: Model)
	if getOwnerUserId(plotModel) ~= localPlayer.UserId then
		cleanupPlotSurfaces(plotModel)
		return
	end

	local slotsFolder = plotModel:FindFirstChild("Slots")
	if slotsFolder and slotsFolder:IsA("Folder") then
		hookSlotsFolder(slotsFolder)
	end
end

local function refreshOwnPlot()
	local gameFolder = Workspace:FindFirstChild("Game")
	local plotsFolder = gameFolder and gameFolder:FindFirstChild("Plots")
	if not plotsFolder then
		return
	end

	for _, plotModel in plotsFolder:GetChildren() do
		if plotModel:IsA("Model") then
			refreshPlot(plotModel)
		end
	end

	refreshAllSlotVisuals()
end

local function hookPlot(plotModel: Model)
	if not hookedPlots[plotModel] then
		hookedPlots[plotModel] = true

		plotModel:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			refreshPlot(plotModel)
		end)

		plotModel.ChildAdded:Connect(function(child)
			if child.Name == "Slots" and child:IsA("Folder") then
				refreshPlot(plotModel)
			end
		end)
	end

	refreshPlot(plotModel)
end

function Client_PlotSlotSurfaces.Init()
	plotHandler = ReplicatedStorage:WaitForChild("Events"):WaitForChild("PlotHandler") :: RemoteEvent

	plotHandler.OnClientEvent:Connect(function(action: string, slotId: number, level: number)
		if action ~= "UpgradeSuccess" or type(slotId) ~= "number" or type(level) ~= "number" then
			return
		end

		local slotModel = findOwnSlotModel(slotId)
		if slotModel then
			cachedSlotLevels[slotModel] = level
			local gui = slotGuis[slotModel]
			if gui then
				updateUpgradeLabels(slotModel, gui)
			end
		end

		Client_Messaging.Show("You've upgraded your brainrot!", "green")
	end)

	local gameFolder = Workspace:WaitForChild("Game")
	local plotsFolder = gameFolder:WaitForChild("Plots")

	getSurfaceGuisFolder()

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

	task.defer(refreshOwnPlot)
	task.delay(1, refreshOwnPlot)

	task.spawn(function()
		Client_Data.WaitUntilReady()
		Client_Data:ListenToChange("Cash", function()
			refreshAllSlotVisuals()
		end)
	end)
end

return Client_PlotSlotSurfaces