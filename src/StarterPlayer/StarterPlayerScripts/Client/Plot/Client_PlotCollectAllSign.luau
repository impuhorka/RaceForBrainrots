local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local Workspace = game:GetService("Workspace")
local ClientLoader = require(script.Parent.Parent.Loader)
local Client_PlotSignVisibility = require(script.Parent.Client_PlotSignVisibility)

local Shared_Marketplace = SharedModules.require("Shared_Marketplace")

local Client_PlotCollectAllSign = {}

local ANIMATED_BUTTON_TAG = "AnimatedButton0"
local FAST_COLLECT_CONFIG_KEY = Shared_Marketplace.FastCollectGamepassConfigKey
local COLLECT_COOLDOWN = 1

local localPlayer = Players.LocalPlayer

local plotGuis: { [Model]: SurfaceGui } = {}
local hookedPlots: { [Model]: boolean } = {}
local watchingPlots: { [Model]: boolean } = {}
local buttonConnections: { [ImageButton]: RBXScriptConnection } = {}
local collectOnCooldown = false

local plotHandler: RemoteEvent

local function getOwnerUserId(plotModel: Model): number
	return tonumber(plotModel:GetAttribute("OwnerUserId")) or 0
end

local function isPlotRegistered(plotModel: Model): boolean
	return getOwnerUserId(plotModel) > 0
end

local function isOwnPlot(plotModel: Model): boolean
	return getOwnerUserId(plotModel) == localPlayer.UserId
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

local function getCollectAllSign(plotModel: Model): Instance?
	return plotModel:FindFirstChild("CollectAllSign", true)
end

local function getCollectAllSignMainPart(collectAllSign: Instance): BasePart?
	local main = collectAllSign:FindFirstChild("main", true)
	if main and main:IsA("BasePart") then
		return main
	end
	return nil
end

local function getCollectAllSignOriginPart(collectAllSign: Instance): BasePart?
	local origin = collectAllSign:FindFirstChild("origin", true)
	if origin and origin:IsA("BasePart") then
		return origin
	end

	return getCollectAllSignMainPart(collectAllSign)
end

local function getCollectAllSignSurfaceTemplate(mainPart: BasePart): SurfaceGui?
	for _, child in mainPart:GetChildren() do
		if child:IsA("SurfaceGui") then
			return child
		end
	end

	return mainPart:FindFirstChildWhichIsA("SurfaceGui")
end

local function getCollectAllSignButton(gui: SurfaceGui): ImageButton?
	local imageButton = gui:FindFirstChild("ImageButton", true)
	if imageButton and imageButton:IsA("ImageButton") then
		return imageButton
	end
	return nil
end

local function findButtonGuiChild(imageButton: ImageButton, childName: string): GuiObject?
	local direct = imageButton:FindFirstChild(childName)
	if direct and direct:IsA("GuiObject") then
		return direct
	end

	local nested = imageButton:FindFirstChild(childName, true)
	if nested and nested:IsA("GuiObject") then
		return nested
	end

	return nil
end

local function setPurchasePromptVisible(imageButton: ImageButton, visible: boolean)
	local cost = findButtonGuiChild(imageButton, "Cost")
	local forever = findButtonGuiChild(imageButton, "Forever")

	if cost then
		cost.Visible = visible
	end
	if forever then
		forever.Visible = visible
	end
end

local function ownsFastCollect(): boolean
	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	return Client_Marketplace.PlayerOwnsGamepass(FAST_COLLECT_CONFIG_KEY)
end

local function updateFastCollectButtonUi(imageButton: ImageButton)
	local owned = ownsFastCollect()
	setPurchasePromptVisible(imageButton, not owned)

	if owned then
		return
	end

	local cost = findButtonGuiChild(imageButton, "Cost")
	if cost and cost:IsA("TextLabel") then
		local Client_Marketplace = ClientLoader.require("Client_Marketplace")
		local price = Client_Marketplace.GetUserPriceInRobux(FAST_COLLECT_CONFIG_KEY)
		if price then
			cost.Text = Shared_Marketplace.FormatRobuxPrice(price)
		end
	end
end

local function refreshAllCollectAllSignUi()
	local owned = ownsFastCollect()

	for plotModel, gui in plotGuis do
		if not gui.Parent then
			continue
		end

		local imageButton = getCollectAllSignButton(gui)
		if imageButton then
			setPurchasePromptVisible(imageButton, not owned)
			if not owned then
				updateFastCollectButtonUi(imageButton)
			end
		end
	end
end

local function setWorldCollectAllSurfaceEnabled(plotModel: Model, enabled: boolean)
	local collectAllSign = getCollectAllSign(plotModel)
	if not collectAllSign then
		return
	end

	local mainPart = getCollectAllSignMainPart(collectAllSign)
	if not mainPart then
		return
	end

	local surfaceGui = getCollectAllSignSurfaceTemplate(mainPart)
	if surfaceGui then
		surfaceGui.Enabled = enabled
	end
end

local function tryCollectAll()
	if collectOnCooldown then
		return
	end

	if not ownsFastCollect() then
		local Client_Marketplace = ClientLoader.require("Client_Marketplace")
		Client_Marketplace.PromptGamePassPurchase(FAST_COLLECT_CONFIG_KEY)
		return
	end

	collectOnCooldown = true
	plotHandler:FireServer("CollectAll")

	task.delay(COLLECT_COOLDOWN, function()
		collectOnCooldown = false
	end)
end

local function setupCollectAllButton(gui: SurfaceGui, plotModel: Model)
	local imageButton = getCollectAllSignButton(gui)
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

	updateFastCollectButtonUi(imageButton)
	task.defer(function()
		if imageButton.Parent then
			updateFastCollectButtonUi(imageButton)
		end
	end)

	if not ownPlot then
		if CollectionService:HasTag(imageButton, ANIMATED_BUTTON_TAG) then
			CollectionService:RemoveTag(imageButton, ANIMATED_BUTTON_TAG)
		end
		return
	end

	if not CollectionService:HasTag(imageButton, ANIMATED_BUTTON_TAG) then
		CollectionService:AddTag(imageButton, ANIMATED_BUTTON_TAG)
	end

	buttonConnections[imageButton] = imageButton.MouseButton1Click:Connect(function()
		tryCollectAll()
	end)
end

local function cleanupPlotSurface(plotModel: Model)
	local gui = plotGuis[plotModel]
	if not gui then
		return
	end

	local imageButton = getCollectAllSignButton(gui)
	if imageButton then
		local existingConnection = buttonConnections[imageButton]
		if existingConnection then
			existingConnection:Disconnect()
			buttonConnections[imageButton] = nil
		end
	end

	gui:Destroy()
	plotGuis[plotModel] = nil
	setWorldCollectAllSurfaceEnabled(plotModel, true)
end

local function hideOtherPlotCollectAllSign(plotModel: Model)
	cleanupPlotSurface(plotModel)

	local collectAllSign = getCollectAllSign(plotModel)
	Client_PlotSignVisibility.setPlotSignVisible(collectAllSign, false)

	if not watchingPlots[plotModel] then
		watchingPlots[plotModel] = true
		plotModel.DescendantAdded:Connect(function()
			if isOwnPlot(plotModel) then
				return
			end
			Client_PlotSignVisibility.setPlotSignVisible(getCollectAllSign(plotModel), false)
		end)
		plotModel.Destroying:Connect(function()
			watchingPlots[plotModel] = nil
		end)
	end
end

local function setupPlotSurface(plotModel: Model)
	if not isOwnPlot(plotModel) then
		hideOtherPlotCollectAllSign(plotModel)
		return
	end

	if plotGuis[plotModel] then
		setupCollectAllButton(plotGuis[plotModel], plotModel)
		return
	end

	local collectAllSign = getCollectAllSign(plotModel)
	Client_PlotSignVisibility.setPlotSignVisible(collectAllSign, true)
	if not collectAllSign then
		if not watchingPlots[plotModel] then
			watchingPlots[plotModel] = true
			plotModel.DescendantAdded:Connect(function()
				if getCollectAllSign(plotModel) then
					setupPlotSurface(plotModel)
				end
			end)
			plotModel.Destroying:Connect(function()
				watchingPlots[plotModel] = nil
			end)
		end
		return
	end

	local mainPart = getCollectAllSignMainPart(collectAllSign)
	local originPart = getCollectAllSignOriginPart(collectAllSign)
	if not mainPart or not originPart then
		return
	end

	local template = getCollectAllSignSurfaceTemplate(mainPart)
	if not template then
		return
	end

	local gui = template:Clone()
	gui.Name = "CollectAllSignDisplay_" .. plotModel.Name

	local clonedButton = getCollectAllSignButton(gui)
	if clonedButton and not isOwnPlot(plotModel) and CollectionService:HasTag(clonedButton, ANIMATED_BUTTON_TAG) then
		CollectionService:RemoveTag(clonedButton, ANIMATED_BUTTON_TAG)
	end

	gui.Parent = getSurfaceGuisFolder()
	gui.Adornee = originPart
	gui.Enabled = true
	setWorldCollectAllSurfaceEnabled(plotModel, false)

	plotGuis[plotModel] = gui
	setupCollectAllButton(gui, plotModel)

	plotModel.Destroying:Connect(function()
		cleanupPlotSurface(plotModel)
	end)
end

local function refreshPlot(plotModel: Model)
	if not isPlotRegistered(plotModel) then
		cleanupPlotSurface(plotModel)
		local collectAllSign = getCollectAllSign(plotModel)
		Client_PlotSignVisibility.setPlotSignVisible(collectAllSign, false)
		return
	end

	setupPlotSurface(plotModel)
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

	plotModel.Destroying:Connect(function()
		hookedPlots[plotModel] = nil
		cleanupPlotSurface(plotModel)
	end)

	refreshPlot(plotModel)
end

local function onCollectAllSuccess(totalCollected: number)
	refreshAllCollectAllSignUi()

	if type(totalCollected) ~= "number" or totalCollected <= 0 then
		return
	end

	local Client_CashAddingPopups = ClientLoader.require("Client_CashAddingPopups")
	Client_CashAddingPopups.Show(totalCollected)
end

function Client_PlotCollectAllSign.Init()
	plotHandler = ReplicatedStorage:WaitForChild("Events"):WaitForChild("PlotHandler") :: RemoteEvent

	plotHandler.OnClientEvent:Connect(function(action: string, arg1: any)
		if action == "CollectAllSuccess" then
			onCollectAllSuccess(arg1)
		end
	end)

	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	Client_Marketplace.OnGamepassOwnershipChanged(refreshAllCollectAllSignUi)
	Client_Marketplace.OnPricesChanged(refreshAllCollectAllSignUi)

	local Client_Data = ClientLoader.require("Client_Data")
	task.spawn(function()
		Client_Data.WaitUntilReady()
		Client_Data:ListenToChange("DataGamepasses", refreshAllCollectAllSignUi)
		refreshAllCollectAllSignUi()
	end)

	task.spawn(function()
		Client_Marketplace.WaitUntilReady()
		refreshAllCollectAllSignUi()
	end)

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

return Client_PlotCollectAllSign
