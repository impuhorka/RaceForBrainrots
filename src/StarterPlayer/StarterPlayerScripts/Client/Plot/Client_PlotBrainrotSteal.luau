local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local ClientLoader = require(script.Parent.Parent.Loader)
local Shared_Brainrots = SharedModules.require("Shared_Brainrots")
local Shared_Marketplace = SharedModules.require("Shared_Marketplace")
local Shared_ProximityPrompt = SharedModules.require("Shared_ProximityPrompt")

local Client_PlotBrainrotSteal = {}

local localPlayer = Players.LocalPlayer

local stealPrompts: { [Model]: ProximityPrompt } = {}
local hookedPlots: { [Model]: boolean } = {}
local hookedSlotsFolders: { [Folder]: boolean } = {}
local hookedBrainrotDestroy: { [Model]: boolean } = {}
local awaitingBeginResult = false
local beginStealToken = 0
local pendingStealConfigKey: string? = nil
local pendingStealProductId: number? = nil
local pendingStealCleanupToken = 0

local BEGIN_STEAL_TIMEOUT_SECONDS = 8
local PURCHASE_SESSION_TIMEOUT_SECONDS = 45

local function getOwnerUserId(plotModel: Model): number
	return tonumber(plotModel:GetAttribute("OwnerUserId")) or 0
end

local function getSlotId(slotModel: Model): number
	return tonumber(string.match(slotModel.Name, "%d+")) or 0
end

local function slotHasBrainrot(slotModel: Model): boolean
	local configName = slotModel:GetAttribute("ConfigName")
	return type(configName) == "string" and configName ~= ""
end

local function getMarketplaceHandler(): RemoteEvent
	return ReplicatedStorage:WaitForChild("Events"):WaitForChild("MarketplaceHandler") :: RemoteEvent
end

local function cancelPendingSteal()
	getMarketplaceHandler():FireServer("CancelStealBrainrot")
end

local function abandonStealPurchase(cancelServer: boolean?)
	if cancelServer ~= false then
		cancelPendingSteal()
	end

	pendingStealConfigKey = nil
	pendingStealProductId = nil
	pendingStealCleanupToken += 1
	awaitingBeginResult = false
	beginStealToken += 1
end

local function getPickupAttachment(brainrotModel: Model): Attachment?
	local primary = brainrotModel.PrimaryPart
	if not primary then
		primary = brainrotModel:FindFirstChildWhichIsA("BasePart", true)
	end
	if not primary then
		return nil
	end

	local attachment = primary:FindFirstChild("PickupAttachment")
	if attachment and attachment:IsA("Attachment") then
		return attachment
	end

	return nil
end

local function hidePickupPrompt(brainrotModel: Model)
	local attachment = getPickupAttachment(brainrotModel)
	if not attachment then
		return
	end

	local pickupPrompt = attachment:FindFirstChild("PickUpPrompt")
	if pickupPrompt and pickupPrompt:IsA("ProximityPrompt") then
		pickupPrompt.Enabled = false
	end
end

local function removeStealPrompt(slotModel: Model)
	local prompt = stealPrompts[slotModel]
	if prompt then
		prompt:Destroy()
		stealPrompts[slotModel] = nil
	end
end

local function ensureStealPromptEnabled(prompt: ProximityPrompt)
	prompt.Enabled = true
end

local function onStealTriggered(plotModel: Model, slotModel: Model)
	if awaitingBeginResult then
		return
	end

	abandonStealPurchase()

	local ownerUserId = getOwnerUserId(plotModel)
	if ownerUserId <= 0 or ownerUserId == localPlayer.UserId then
		return
	end

	if not slotHasBrainrot(slotModel) then
		return
	end

	local slotId = getSlotId(slotModel)
	if slotId <= 0 then
		return
	end

	local configName = slotModel:GetAttribute("ConfigName")
	local brainrotConfig = if type(configName) == "string" then Shared_Brainrots.Data[configName] else nil
	local rarity = brainrotConfig and brainrotConfig.Rarity
	local productConfigKey = if type(rarity) == "string" then Shared_Marketplace.GetStealBrainrotProductKey(rarity) else nil
	if not productConfigKey then
		return
	end

	awaitingBeginResult = true
	beginStealToken += 1
	local token = beginStealToken

	task.delay(BEGIN_STEAL_TIMEOUT_SECONDS, function()
		if awaitingBeginResult and beginStealToken == token then
			abandonStealPurchase()
		end
	end)

	getMarketplaceHandler():FireServer("BeginStealBrainrot", ownerUserId, slotId)
end

local function setupStealPrompt(plotModel: Model, slotModel: Model, brainrotModel: Model)
	if getOwnerUserId(plotModel) == localPlayer.UserId then
		removeStealPrompt(slotModel)
		return
	end

	if not slotHasBrainrot(slotModel) then
		removeStealPrompt(slotModel)
		return
	end

	hidePickupPrompt(brainrotModel)

	local attachment = getPickupAttachment(brainrotModel)
	if not attachment then
		return
	end

	if not hookedBrainrotDestroy[brainrotModel] then
		hookedBrainrotDestroy[brainrotModel] = true
		brainrotModel.Destroying:Connect(function()
			hookedBrainrotDestroy[brainrotModel] = nil
			removeStealPrompt(slotModel)
		end)
	end

	local existingPrompt = stealPrompts[slotModel]
	if existingPrompt and existingPrompt.Parent then
		ensureStealPromptEnabled(existingPrompt)
		return
	end

	stealPrompts[slotModel] = nil

	local pickupPreset = Shared_ProximityPrompt.GetPreset("PickUp")
	local stealDistance = (pickupPreset.MaxActivationDistance or 10) * 1.35

	local prompt = Shared_ProximityPrompt.Create(attachment, {
		Preset = "Steal",
		MaxActivationDistance = stealDistance,
	})

	stealPrompts[slotModel] = prompt

	prompt.Triggered:Connect(function()
		onStealTriggered(plotModel, slotModel)
	end)
end

local function refreshSlot(plotModel: Model, slotModel: Model)
	if getOwnerUserId(plotModel) == localPlayer.UserId then
		removeStealPrompt(slotModel)
		return
	end

	if not slotHasBrainrot(slotModel) then
		removeStealPrompt(slotModel)
		return
	end

	local brainrotModel = slotModel:FindFirstChild("PlacedBrainrot")
	if brainrotModel and brainrotModel:IsA("Model") then
		setupStealPrompt(plotModel, slotModel, brainrotModel)
	end
end

local function setupSlot(plotModel: Model, slotModel: Model)
	refreshSlot(plotModel, slotModel)

	slotModel:GetAttributeChangedSignal("ConfigName"):Connect(function()
		refreshSlot(plotModel, slotModel)
	end)

	slotModel.ChildAdded:Connect(function(child)
		if child.Name == "PlacedBrainrot" and child:IsA("Model") then
			refreshSlot(plotModel, slotModel)
		end
	end)
end

local function setupAllSlots(plotModel: Model, slotsFolder: Folder)
	for _, slotModel in slotsFolder:GetChildren() do
		if slotModel:IsA("Model") then
			setupSlot(plotModel, slotModel)
		end
	end
end

local function hookSlotsFolder(plotModel: Model, slotsFolder: Folder)
	if not hookedSlotsFolders[slotsFolder] then
		hookedSlotsFolders[slotsFolder] = true

		slotsFolder.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				setupSlot(plotModel, child)
			end
		end)
	end

	setupAllSlots(plotModel, slotsFolder)
end

local function refreshPlot(plotModel: Model)
	local slotsFolder = plotModel:FindFirstChild("Slots")
	if slotsFolder and slotsFolder:IsA("Folder") then
		hookSlotsFolder(plotModel, slotsFolder)
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
		if child.Name == "Slots" and child:IsA("Folder") then
			hookSlotsFolder(plotModel, child)
		end
	end)

	refreshPlot(plotModel)
end

local function hookPlotsFolder(plotsFolder: Folder)
	for _, plotModel in plotsFolder:GetChildren() do
		if plotModel:IsA("Model") then
			hookPlot(plotModel)
		end
	end

	plotsFolder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			hookPlot(child)
		end
	end)
end

local function schedulePurchaseSessionTimeout(configKey: string, productId: number)
	pendingStealCleanupToken += 1
	local token = pendingStealCleanupToken

	task.delay(PURCHASE_SESSION_TIMEOUT_SECONDS, function()
		if pendingStealConfigKey == configKey and pendingStealCleanupToken == token then
			abandonStealPurchase()
		end
	end)
end

local function onStealBrainrotBeginResult(success: boolean, productConfigKey: string?, reason: string?)
	awaitingBeginResult = false

	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	local Client_Messaging = ClientLoader.require("Client_Messaging")

	if not success or type(productConfigKey) ~= "string" then
		abandonStealPurchase(false)
		if type(reason) == "string" and reason ~= "" then
			Client_Messaging.Show(reason, "red")
		end
		return
	end

	local allowed = Client_Marketplace.RequestServerCanPurchase(productConfigKey)
	if not allowed then
		abandonStealPurchase()
		Client_Messaging.Show("You cannot steal this brainrot right now.", "red")
		return
	end

	local productId = Shared_Marketplace.GetConfiguredProductId(productConfigKey)
	if not productId or productId <= 0 then
		abandonStealPurchase()
		Client_Messaging.Show("Steal product is unavailable.", "red")
		return
	end

	pendingStealConfigKey = productConfigKey
	pendingStealProductId = productId

	local opened = Client_Marketplace.PromptProductPurchase(productConfigKey)
	if not opened then
		abandonStealPurchase()
		Client_Messaging.Show("Steal product is unavailable.", "red")
		return
	end

	schedulePurchaseSessionTimeout(productConfigKey, productId)
end

local function onStealPurchaseEnded(productId: number, wasPurchased: boolean)
	if not pendingStealConfigKey then
		return
	end

	if pendingStealProductId and productId > 0 and productId ~= pendingStealProductId then
		return
	end

	if wasPurchased == true then
		pendingStealConfigKey = nil
		pendingStealProductId = nil
		pendingStealCleanupToken += 1
		return
	end

	abandonStealPurchase()
end

local function bindMarketplaceEvents()
	getMarketplaceHandler().OnClientEvent:Connect(function(action: string, arg1: any, arg2: any, arg3: any)
		if action == "StealBrainrotBeginResult" then
			onStealBrainrotBeginResult(arg1 == true, if arg1 == true then arg2 else nil, arg3)
			return
		end

		if action == "PurchaseFailed" then
			if pendingStealConfigKey and Shared_Marketplace.IsStealBrainrotProduct(arg1) then
				abandonStealPurchase()
				local Client_Messaging = ClientLoader.require("Client_Messaging")
				local reason = if type(arg2) == "string" and arg2 ~= "" then arg2 else "Steal failed."
				Client_Messaging.Show(reason, "red")
			end
			return
		end

		if action == "PurchaseSuccess" then
			if pendingStealConfigKey and Shared_Marketplace.IsStealBrainrotProduct(arg1) then
				pendingStealConfigKey = nil
				pendingStealProductId = nil
				pendingStealCleanupToken += 1
			end
		end
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(player: Player, productId: number, wasPurchased: boolean)
		if player ~= localPlayer then
			return
		end

		onStealPurchaseEnded(productId, wasPurchased)
	end)
end

local function bindPlotEvents()
	local plotHandler = ReplicatedStorage:WaitForChild("Events"):WaitForChild("PlotHandler") :: RemoteEvent
	plotHandler.OnClientEvent:Connect(function(action: string, arg1: any)
		if action == "BrainrotStolen" then
			local Client_Messaging = ClientLoader.require("Client_Messaging")
			local configName = if type(arg1) == "string" then arg1 else "brainrot"
			Client_Messaging.Show(`Someone stole your {configName}!`, "red")
		end
	end)
end

function Client_PlotBrainrotSteal.Init()
	bindMarketplaceEvents()
	bindPlotEvents()

	task.spawn(function()
		local gameFolder = Workspace:WaitForChild("Game")
		local plotsFolder = gameFolder:WaitForChild("Plots")
		if plotsFolder:IsA("Folder") then
			hookPlotsFolder(plotsFolder)
		end
	end)
end

return Client_PlotBrainrotSteal
