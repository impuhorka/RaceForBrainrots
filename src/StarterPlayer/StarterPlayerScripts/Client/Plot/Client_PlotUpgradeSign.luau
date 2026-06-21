local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local Workspace = game:GetService("Workspace")
local ClientLoader = require(script.Parent.Parent.Loader)
local Client_PlotSignVisibility = require(script.Parent.Client_PlotSignVisibility)

local Shared_PlotConfig = SharedModules.require("Shared_PlotConfig")
local Shared_Abbreviation = SharedModules.require("Shared_Abbreviation")
local Shared_Rebirth = SharedModules.require("Shared_Rebirth")

local Client_Data = ClientLoader.require("Client_Data")
local Client_Messaging = ClientLoader.require("Client_Messaging")

local localPlayer = Players.LocalPlayer

local Client_PlotUpgradeSign = {}

local ANIMATED_BUTTON_TAG = "AnimatedButton0"

local plotGuis: { [Model]: SurfaceGui } = {}
local hookedPlots: { [Model]: boolean } = {}
local watchingPlots: { [Model]: boolean } = {}
local watchingSlotsFolders: { [Model]: boolean } = {}
local buttonConnections: { [ImageButton]: RBXScriptConnection } = {}
local originalSlotsLayouts: { [TextLabel]: { Position: UDim2, Size: UDim2 } } = {}
local originalFrameVisible: { [GuiObject]: boolean } = {}

local plotHandler: RemoteEvent

local function getOwnerUserId(plotModel: Model): number
	return tonumber(plotModel:GetAttribute("OwnerUserId")) or 0
end

local function isPlotRegistered(plotModel: Model): boolean
	return getOwnerUserId(plotModel) > 0
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

local function getUpgradeSign(plotModel: Model): Instance?
	return plotModel:FindFirstChild("UpgradeSign", true)
end

local function getUpgradeSignMainPart(upgradeSign: Instance): BasePart?
	local main = upgradeSign:FindFirstChild("main", true)
	if main and main:IsA("BasePart") then
		return main
	end
	return nil
end

local function getUpgradeSignOriginPart(upgradeSign: Instance): BasePart?
	local origin = upgradeSign:FindFirstChild("origin", true)
	if origin and origin:IsA("BasePart") then
		return origin
	end

	return getUpgradeSignMainPart(upgradeSign)
end

local function getUpgradeSignSurfaceTemplate(mainPart: BasePart): SurfaceGui?
	for _, child in mainPart:GetChildren() do
		if child:IsA("SurfaceGui") then
			return child
		end
	end

	return mainPart:FindFirstChildWhichIsA("SurfaceGui")
end

local function getUpgradeSignElements(gui: SurfaceGui): (ImageButton?, TextLabel?, Frame?, TextLabel?)
	local imageButton = gui:FindFirstChild("ImageButton", true)
	if not imageButton or not imageButton:IsA("ImageButton") then
		return nil, nil, nil, nil
	end

	local slotsLabel = imageButton:FindFirstChild("Slots")
	if slotsLabel and not slotsLabel:IsA("TextLabel") then
		slotsLabel = nil
	end

	local frame = imageButton:FindFirstChild("Frame")
	if frame and not frame:IsA("Frame") then
		frame = nil
	end

	local costLabel = frame and frame:FindFirstChild("Cost")
	if costLabel and not costLabel:IsA("TextLabel") then
		costLabel = nil
	end

	return imageButton, slotsLabel, frame, costLabel
end

local function storeUpgradeSignDefaults(slotsLabel: TextLabel, frame: Frame?)
	if not originalSlotsLayouts[slotsLabel] then
		originalSlotsLayouts[slotsLabel] = {
			Position = slotsLabel.Position,
			Size = slotsLabel.Size,
		}
	end

	if frame and originalFrameVisible[frame] == nil then
		originalFrameVisible[frame] = frame.Visible
	end
end

local function applyRebirthLockedLayout(slotsLabel: TextLabel, frame: Frame?, requiredRebirths: number)
	storeUpgradeSignDefaults(slotsLabel, frame)

	if frame then
		frame.Visible = false
	end

	local original = originalSlotsLayouts[slotsLabel]
	local xScale = if original then original.Position.X.Scale else slotsLabel.Position.X.Scale
	local xOffset = if original then original.Position.X.Offset else slotsLabel.Position.X.Offset
	local sizeXScale = if original then original.Size.X.Scale else slotsLabel.Size.X.Scale
	local sizeXOffset = if original then original.Size.X.Offset else slotsLabel.Size.X.Offset

	slotsLabel.Text = ("Rebirth %d to unlock"):format(requiredRebirths)
	slotsLabel.Position = UDim2.new(xScale, xOffset, 0.55, 0)
	slotsLabel.Size = UDim2.new(sizeXScale, sizeXOffset, 0.5, 0)
end

local function applyMaxSlotsLayout(slotsLabel: TextLabel, frame: Frame?)
	storeUpgradeSignDefaults(slotsLabel, frame)

	if frame then
		frame.Visible = false
	end

	local original = originalSlotsLayouts[slotsLabel]
	local xScale = if original then original.Position.X.Scale else slotsLabel.Position.X.Scale
	local xOffset = if original then original.Position.X.Offset else slotsLabel.Position.X.Offset
	local sizeXScale = if original then original.Size.X.Scale else slotsLabel.Size.X.Scale
	local sizeXOffset = if original then original.Size.X.Offset else slotsLabel.Size.X.Offset

	slotsLabel.Text = "MAX Slots"
	slotsLabel.Position = UDim2.new(xScale, xOffset, 0.55, 0)
	slotsLabel.Size = UDim2.new(sizeXScale, sizeXOffset, 0.5, 0)
end

local function applyNormalSlotsLayout(slotsLabel: TextLabel, frame: Frame?)
	storeUpgradeSignDefaults(slotsLabel, frame)

	local original = originalSlotsLayouts[slotsLabel]
	if original then
		slotsLabel.Position = original.Position
		slotsLabel.Size = original.Size
	end

	if frame then
		frame.Visible = originalFrameVisible[frame] ~= false
	end
end

local function getUpgradeSignButton(gui: SurfaceGui): ImageButton?
	local imageButton = gui:FindFirstChild("ImageButton", true)
	if imageButton and imageButton:IsA("ImageButton") then
		return imageButton
	end
	return nil
end

local function isOwnPlot(plotModel: Model): boolean
	return getOwnerUserId(plotModel) == localPlayer.UserId
end

local function getPlotSlotCount(plotModel: Model): number
	if isOwnPlot(plotModel) then
		return Client_Data:GetValue("TotalPlotSlots") or Shared_PlotConfig.DefaultPlotSlots
	end

	local slotsFolder = plotModel:FindFirstChild("Slots")
	if not slotsFolder then
		return Shared_PlotConfig.DefaultPlotSlots
	end

	local maxSlotId = 0
	for _, child in slotsFolder:GetChildren() do
		if child:IsA("Model") then
			local slotId = tonumber(string.match(child.Name, "^Slot(%d+)$"))
			if slotId and slotId > maxSlotId then
				maxSlotId = slotId
			end
		end
	end

	return if maxSlotId > 0 then maxSlotId else Shared_PlotConfig.DefaultPlotSlots
end

local function updateUpgradeSignLabels(gui: SurfaceGui?, plotModel: Model)
	if not gui or not gui.Parent then
		return
	end

	local _, slotsLabel, frame, costLabel = getUpgradeSignElements(gui)
	if not slotsLabel then
		return
	end

	local currentSlots = getPlotSlotCount(plotModel)
	local maxSlots = Shared_PlotConfig.MaxPlotSlots
	local rebirths = if isOwnPlot(plotModel)
		then Client_Data:GetValue("Rebirths")
		else plotModel:GetAttribute("OwnerRebirths")
	local maxAllowed = Shared_Rebirth.GetMaxPlotSlots(rebirths)

	if currentSlots >= maxSlots then
		applyMaxSlotsLayout(slotsLabel, frame)
		return
	end

	if isOwnPlot(plotModel) and currentSlots >= maxAllowed then
		local requiredRebirths = Shared_Rebirth.GetRebirthsRequiredForNextSlot(currentSlots, rebirths)
		if requiredRebirths then
			applyRebirthLockedLayout(slotsLabel, frame, requiredRebirths)
		else
			applyMaxSlotsLayout(slotsLabel, frame)
		end
		return
	end

	applyNormalSlotsLayout(slotsLabel, frame)

	local nextSlots = currentSlots + 1
	local cost = Shared_PlotConfig.getNextSlotCost(currentSlots)

	slotsLabel.Text = ("%s -> %s Slots"):format(currentSlots, nextSlots)
	if costLabel then
		costLabel.Text = ("$%s"):format(Shared_Abbreviation:Number(cost))
	end
end

local function tryBuySlot()
	local currentSlots = Client_Data:GetValue("TotalPlotSlots") or Shared_PlotConfig.DefaultPlotSlots
	local rebirths = Client_Data:GetValue("Rebirths")
	local maxAllowed = Shared_Rebirth.GetMaxPlotSlots(rebirths)

	if currentSlots >= Shared_PlotConfig.MaxPlotSlots then
		Client_Messaging.Show("You've purchased MAX amount of slots!", "red")
		return
	end

	if currentSlots >= maxAllowed then
		local requiredRebirths = Shared_Rebirth.GetRebirthsRequiredForNextSlot(currentSlots, rebirths)
		if requiredRebirths then
			Client_Messaging.Show(("Rebirth %d times to unlock more slots!"):format(requiredRebirths), "red")
		end
		return
	end

	local cost = Shared_PlotConfig.getNextSlotCost(currentSlots)
	local cash = Client_Data:GetValue("Cash") or 0

	if cash < cost then
		Client_Messaging.Show("You need more cash to purchase this slot!", "red")
		return
	end

	plotHandler:FireServer("BuySlot")
end

local function setupUpgradeSignButton(gui: SurfaceGui, plotModel: Model)
	local imageButton = getUpgradeSignButton(gui)
	if not imageButton then
		return
	end

	local ownPlot = isOwnPlot(plotModel)
	imageButton.Active = ownPlot

	local existingConnection = buttonConnections[imageButton]
	if existingConnection then
		existingConnection:Disconnect()
		buttonConnections[imageButton] = nil
	end

	if ownPlot then
		if not CollectionService:HasTag(imageButton, ANIMATED_BUTTON_TAG) then
			CollectionService:AddTag(imageButton, ANIMATED_BUTTON_TAG)
		end
		buttonConnections[imageButton] = imageButton.MouseButton1Click:Connect(function()
			tryBuySlot()
		end)
	else
		if CollectionService:HasTag(imageButton, ANIMATED_BUTTON_TAG) then
			CollectionService:RemoveTag(imageButton, ANIMATED_BUTTON_TAG)
		end
	end
end

local function watchPlotSlotsFolder(plotModel: Model)
	if watchingSlotsFolders[plotModel] then
		return
	end

	local slotsFolder = plotModel:FindFirstChild("Slots")
	if not slotsFolder then
		return
	end

	watchingSlotsFolders[plotModel] = true

	local function refreshLabels()
		local gui = plotGuis[plotModel]
		if gui and gui.Parent then
			updateUpgradeSignLabels(gui, plotModel)
		end
	end

	slotsFolder.ChildAdded:Connect(refreshLabels)
	slotsFolder.ChildRemoved:Connect(refreshLabels)
end

local function cleanupPlotSurface(plotModel: Model)
	local gui = plotGuis[plotModel]
	if gui then
		local imageButton = getUpgradeSignButton(gui)
		if imageButton then
			local existingConnection = buttonConnections[imageButton]
			if existingConnection then
				existingConnection:Disconnect()
				buttonConnections[imageButton] = nil
			end
		end
		gui:Destroy()
		plotGuis[plotModel] = nil
	end
	watchingSlotsFolders[plotModel] = nil
end

local function hideOtherPlotUpgradeSign(plotModel: Model)
	cleanupPlotSurface(plotModel)

	local upgradeSign = getUpgradeSign(plotModel)
	Client_PlotSignVisibility.setPlotSignVisible(upgradeSign, false)

	if not watchingPlots[plotModel] then
		watchingPlots[plotModel] = true
		plotModel.DescendantAdded:Connect(function()
			if isOwnPlot(plotModel) then
				return
			end
			Client_PlotSignVisibility.setPlotSignVisible(getUpgradeSign(plotModel), false)
		end)
		plotModel.Destroying:Connect(function()
			watchingPlots[plotModel] = nil
		end)
	end
end

local function setupPlotSurface(plotModel: Model)
	if not isOwnPlot(plotModel) then
		hideOtherPlotUpgradeSign(plotModel)
		return
	end

	if plotGuis[plotModel] then
		updateUpgradeSignLabels(plotGuis[plotModel], plotModel)
		setupUpgradeSignButton(plotGuis[plotModel], plotModel)
		return
	end

	local upgradeSign = getUpgradeSign(plotModel)
	Client_PlotSignVisibility.setPlotSignVisible(upgradeSign, true)
	if not upgradeSign then
		if not watchingPlots[plotModel] then
			watchingPlots[plotModel] = true
			plotModel.DescendantAdded:Connect(function()
				if getUpgradeSign(plotModel) then
					refreshPlot(plotModel)
				end
			end)
			plotModel.Destroying:Connect(function()
				watchingPlots[plotModel] = nil
			end)
		end
		return
	end

	local mainPart = getUpgradeSignMainPart(upgradeSign)
	local originPart = getUpgradeSignOriginPart(upgradeSign)
	if not mainPart or not originPart then
		return
	end

	local template = getUpgradeSignSurfaceTemplate(mainPart)
	if not template then
		return
	end

	local gui = template:Clone()
	gui.Name = "UpgradeSignDisplay_" .. plotModel.Name

	local clonedButton = getUpgradeSignButton(gui)
	if clonedButton and not isOwnPlot(plotModel) and CollectionService:HasTag(clonedButton, ANIMATED_BUTTON_TAG) then
		CollectionService:RemoveTag(clonedButton, ANIMATED_BUTTON_TAG)
	end

	gui.Parent = getSurfaceGuisFolder()
	gui.Adornee = originPart
	gui.Enabled = true

	plotGuis[plotModel] = gui

	updateUpgradeSignLabels(gui, plotModel)
	setupUpgradeSignButton(gui, plotModel)
	watchPlotSlotsFolder(plotModel)

	plotModel.Destroying:Connect(function()
		cleanupPlotSurface(plotModel)
	end)
end

local function refreshPlot(plotModel: Model)
	if not isPlotRegistered(plotModel) then
		cleanupPlotSurface(plotModel)
		local upgradeSign = getUpgradeSign(plotModel)
		Client_PlotSignVisibility.setPlotSignVisible(upgradeSign, false)
		return
	end

	setupPlotSurface(plotModel)
	if isOwnPlot(plotModel) then
		watchPlotSlotsFolder(plotModel)
	end
end

local function refreshAllPlots()
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

	for plotModel, gui in plotGuis do
		if gui.Parent then
			updateUpgradeSignLabels(gui, plotModel)
		end
	end
end

local function hookPlot(plotModel: Model)
	if hookedPlots[plotModel] then
		refreshPlot(plotModel)
		return
	end
	hookedPlots[plotModel] = true

	plotModel:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		refreshPlot(plotModel)
	end)

	plotModel.ChildAdded:Connect(function(child)
		if child.Name == "Slots" then
			watchPlotSlotsFolder(plotModel)
			local gui = plotGuis[plotModel]
			if gui and gui.Parent then
				updateUpgradeSignLabels(gui, plotModel)
			end
		end
	end)

	refreshPlot(plotModel)
end

function Client_PlotUpgradeSign.Init()
	plotHandler = ReplicatedStorage:WaitForChild("Events"):WaitForChild("PlotHandler") :: RemoteEvent

	plotHandler.OnClientEvent:Connect(function(action: string, newTotal: number)
		if action ~= "SlotPurchaseSuccess" or type(newTotal) ~= "number" then
			return
		end

		for plotModel, gui in plotGuis do
			if gui.Parent and isOwnPlot(plotModel) then
				updateUpgradeSignLabels(gui, plotModel)
			end
		end

		Client_Messaging.Show(("You've unlocked slot %s!"):format(newTotal), "green")
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

	task.defer(refreshAllPlots)
	task.delay(1, refreshAllPlots)

	task.spawn(function()
		Client_Data.WaitUntilReady()
		Client_Data:ListenToChange("TotalPlotSlots", function()
			for plotModel, gui in plotGuis do
				if gui.Parent and isOwnPlot(plotModel) then
					updateUpgradeSignLabels(gui, plotModel)
				end
			end
		end)
		Client_Data:ListenToChange("Cash", function()
			for plotModel, gui in plotGuis do
				if gui.Parent and isOwnPlot(plotModel) then
					updateUpgradeSignLabels(gui, plotModel)
				end
			end
		end)
		Client_Data:ListenToChange("Rebirths", function()
			for plotModel, gui in plotGuis do
				if gui.Parent and isOwnPlot(plotModel) then
					updateUpgradeSignLabels(gui, plotModel)
				end
			end
		end)
	end)
end

return Client_PlotUpgradeSign