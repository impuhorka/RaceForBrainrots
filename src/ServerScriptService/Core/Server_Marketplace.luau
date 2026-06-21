local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Server_Data = require(script.Parent.Server_Data)
local Shared_Marketplace = SharedModules.require("Shared_Marketplace")
local Shared_SpeedStore = SharedModules.require("Shared_SpeedStore")
local Shared_StrengthStore = SharedModules.require("Shared_StrengthStore")
local GameProcessService = require(script.Parent.Parent.GameProcess.GameProcessService)
local PlotOfflineCash = require(script.Parent.Parent.Plot.PlotOfflineCash)

local Server_Marketplace = {}

export type ProductInfoRecord = {
	ConfigKey: string,
	ProductType: Shared_Marketplace.ProductTypeName,
	ProductId: number,
	DisplayName: string?,
	Description: string?,
	Name: string?,
	PriceInRobux: number?,
	UserBasePriceInRobux: number?,
	AssetId: number?,
	IsForSale: boolean?,
	GrantAmount: number?,
	GrantItemType: string?,
	GrantConfigName: string?,
	RequiresPaidRandomItems: boolean?,
	Loaded: boolean,
	Error: string?,
}

export type ClientProductInfo = {
	ConfigKey: string,
	ProductType: string,
	ProductId: number,
	DisplayName: string?,
	Description: string?,
	Name: string?,
	PriceInRobux: number?,
	UserBasePriceInRobux: number?,
	IsForSale: boolean?,
	GrantAmount: number?,
	GrantItemType: string?,
	GrantConfigName: string?,
	RequiresPaidRandomItems: boolean?,
	Loaded: boolean,
	Error: string?,
}

local INVENTORY_MAX_SLOTS = 60

local productInfoByKey: { [string]: ProductInfoRecord } = {}
local productInfoById: { [number]: ProductInfoRecord } = {}
local grantHandlers: { [string]: (player: Player, receiptInfo: any?) -> (boolean, string?) } = {}
local marketplaceHandler: RemoteEvent? = nil
local plotServiceRef: any = nil
local initialized = false
local productLoadGeneration = 0
local PRODUCT_LOAD_YIELD_SECONDS = 0.04

local function getInfoType(productType: string): Enum.InfoType
	if productType == Shared_Marketplace.ProductType.GamePass then
		return Enum.InfoType.GamePass
	end
	return Enum.InfoType.Product
end

local function buildBaseRecord(configKey: string, config: Shared_Marketplace.ProductConfig): ProductInfoRecord
	return {
		ConfigKey = configKey,
		ProductType = config.ProductType,
		ProductId = math.floor(tonumber(config.ProductId) or 0),
		DisplayName = config.DisplayName,
		Description = config.Description,
		Name = config.DisplayName,
		PriceInRobux = nil,
		UserBasePriceInRobux = nil,
		AssetId = nil,
		IsForSale = nil,
		GrantAmount = config.GrantAmount,
		GrantItemType = config.GrantItemType,
		GrantConfigName = config.GrantConfigName,
		RequiresPaidRandomItems = config.RequiresPaidRandomItems == true,
		Loaded = false,
		Error = nil,
	}
end

local function applyMarketplaceInfo(record: ProductInfoRecord, info: any)
	record.Name = if type(info.Name) == "string" then info.Name else record.DisplayName
	record.Description = if type(info.Description) == "string" then info.Description else record.Description
	record.PriceInRobux = tonumber(info.PriceInRobux)
	record.UserBasePriceInRobux = tonumber(info.UserBasePriceInRobux) or tonumber(info.PriceInRobux)
	record.AssetId = tonumber(info.AssetId)
	record.IsForSale = if type(info.IsForSale) == "boolean" then info.IsForSale else nil
	record.Loaded = true
	record.Error = nil
end

local function loadProductInfo(record: ProductInfoRecord)
	if record.ProductId <= 0 then
		record.Error = "ProductId is not configured"
		return
	end

	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(record.ProductId, getInfoType(record.ProductType))
	end)

	if not ok or type(info) ~= "table" then
		record.Error = if type(info) == "string" then info else "Failed to load product info"
		warn(`[Server_Marketplace] Failed to load {record.ConfigKey} ({record.ProductId}): {record.Error}`)
		return
	end

	applyMarketplaceInfo(record, info)
end

local function indexRecord(record: ProductInfoRecord)
	productInfoByKey[record.ConfigKey] = record
	if record.ProductId > 0 then
		productInfoById[record.ProductId] = record
	end
end

local function toClientProductInfo(record: ProductInfoRecord): ClientProductInfo
	return {
		ConfigKey = record.ConfigKey,
		ProductType = record.ProductType,
		ProductId = record.ProductId,
		DisplayName = record.DisplayName,
		Description = record.Description,
		Name = record.Name,
		PriceInRobux = record.PriceInRobux,
		UserBasePriceInRobux = record.UserBasePriceInRobux,
		IsForSale = record.IsForSale,
		GrantAmount = record.GrantAmount,
		GrantItemType = record.GrantItemType,
		GrantConfigName = record.GrantConfigName,
		RequiresPaidRandomItems = record.RequiresPaidRandomItems,
		Loaded = record.Loaded,
		Error = record.Error,
	}
end

local function getMarketplaceHandler(): RemoteEvent
	if marketplaceHandler then
		return marketplaceHandler
	end

	marketplaceHandler = ReplicatedStorage:WaitForChild("Events"):WaitForChild("MarketplaceHandler") :: RemoteEvent
	return marketplaceHandler
end

local function getInventoryFreeSlots(player: Player): number
	local data = Server_Data:GetData(player)
	if not data or type(data.Inventory) ~= "table" then
		return 0
	end
	return math.max(0, INVENTORY_MAX_SLOTS - #data.Inventory)
end

function Server_Marketplace.CanPurchasePaidRandomItems(player: Player): boolean
	local ok, policyInfo = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)

	if not ok or type(policyInfo) ~= "table" then
		return false
	end

	return policyInfo.ArePaidRandomItemsRestricted ~= true
end

local function isRecordConfigured(record: ProductInfoRecord?): boolean
	return record ~= nil and record.ProductId > 0
end

local function canPurchaseProduct(player: Player, configKey: string): (boolean, string?)
	local record = productInfoByKey[configKey]
	if not isRecordConfigured(record) then
		return false, "Product is unavailable"
	end

	if record.RequiresPaidRandomItems and not Server_Marketplace.CanPurchasePaidRandomItems(player) then
		return false, "Paid random items are not available in your region"
	end

	if record.ProductType == Shared_Marketplace.ProductType.GamePass then
		if Server_Marketplace.PlayerOwnsGamepass(player, configKey) then
			return false, "Already owned"
		end
		return true, nil
	end

	if record.GrantItemType == "Cash" then
		local cashAmount = math.max(0, math.floor(tonumber(record.GrantAmount) or 0))
		if cashAmount <= 0 then
			return false, "Product is unavailable"
		end
		return true, nil
	end

	if record.GrantItemType == Shared_Marketplace.GrantItemType.Speed then
		local grantAmount = math.max(1, math.floor(tonumber(record.GrantAmount) or 1))
		if not Shared_SpeedStore.IsValidPurchaseAmount(grantAmount) then
			return false, "Product is unavailable"
		end

		return true, nil
	end

	if record.GrantItemType == Shared_Marketplace.GrantItemType.Strength then
		local grantAmount = math.max(1, math.floor(tonumber(record.GrantAmount) or 1))
		if not Shared_StrengthStore.IsValidPurchaseAmount(grantAmount) then
			return false, "Product is unavailable"
		end

		return true, nil
	end

	if record.GrantItemType == Shared_Marketplace.GrantItemType.Rebirth then
		return true, nil
	end

	if record.GrantItemType == Shared_Marketplace.GrantItemType.OfflineCash then
		local pendingCash = Server_Data:GetValue(player, "PendingOfflineCash") or 0
		if pendingCash <= 0 then
			return false, "No offline cash pending"
		end
		return true, nil
	end

	if record.GrantItemType == Shared_Marketplace.GrantItemType.TeleportHome then
		local expectedRarity = record.GrantConfigName
		if type(expectedRarity) ~= "string" or expectedRarity == "" then
			return false, "Product is unavailable"
		end

		if not GameProcessService.CanPurchaseTeleportHome(player, expectedRarity) then
			return false, "Not carrying lucky block"
		end

		if getInventoryFreeSlots(player) < 1 then
			return false, "Inventory is full"
		end

		return true, nil
	end

	if record.GrantItemType == "LuckyBlock" then
		local grantAmount = math.max(1, math.floor(tonumber(record.GrantAmount) or 1))
		if getInventoryFreeSlots(player) < grantAmount then
			return false, "Inventory is full"
		end
	end

	return true, nil
end

local function grantCash(player: Player, record: ProductInfoRecord): (boolean, string?)
	local cashAmount = math.max(0, math.floor(tonumber(record.GrantAmount) or 0))
	if cashAmount <= 0 then
		return false, "Invalid cash amount"
	end

	Server_Data:AddValue(player, "Cash", cashAmount)
	return true, nil
end

local function grantSpeed(player: Player, record: ProductInfoRecord): (boolean, string?)
	local grantAmount = math.max(1, math.floor(tonumber(record.GrantAmount) or 1))
	if not Shared_SpeedStore.IsValidPurchaseAmount(grantAmount) then
		return false, "InvalidAmount"
	end

	local currentSpeed = math.max(
		1,
		math.floor(Server_Data:GetValue(player, "Speed") or Shared_SpeedStore.DefaultSpeed)
	)

	local newSpeed = Shared_SpeedStore.GetSpeedAfterPurchase(currentSpeed, grantAmount)
	Server_Data:SetValue(player, "Speed", newSpeed)
	return true, nil
end

local function grantStrength(player: Player, record: ProductInfoRecord): (boolean, string?)
	local grantAmount = math.max(1, math.floor(tonumber(record.GrantAmount) or 1))
	if not Shared_StrengthStore.IsValidPurchaseAmount(grantAmount) then
		return false, "InvalidAmount"
	end

	local currentStrength = math.max(
		1,
		math.floor(Server_Data:GetValue(player, "Strength") or Shared_StrengthStore.DefaultStrength)
	)

	local newStrength = Shared_StrengthStore.GetStrengthAfterPurchase(currentStrength, grantAmount)
	Server_Data:SetValue(player, "Strength", newStrength)
	return true, nil
end

local function grantRebirth(player: Player): (boolean, string?)
	if not plotServiceRef or type(plotServiceRef.GrantRobuxRebirth) ~= "function" then
		return false, "Rebirth is unavailable"
	end

	return plotServiceRef:GrantRobuxRebirth(player), nil
end

local function grantOfflineCash(player: Player, record: ProductInfoRecord): (boolean, string?)
	local multiplier = math.max(1, math.floor(tonumber(record.GrantAmount) or 10))
	local plotHandler = ReplicatedStorage:WaitForChild("Events"):WaitForChild("PlotHandler") :: RemoteEvent
	local granted = PlotOfflineCash.GrantRobuxCollect(player, plotHandler, multiplier)
	return granted, if granted then nil else "No offline cash pending"
end

local function grantTeleportHome(player: Player, record: ProductInfoRecord): (boolean, string?)
	local expectedRarity = record.GrantConfigName
	if type(expectedRarity) ~= "string" or expectedRarity == "" then
		return false, "Invalid product"
	end

	return GameProcessService.GrantTeleportHome(player, expectedRarity)
end

local function appendPurchaseLog(player: Player, configKey: string, productId: number, purchaseId: string?)
	local data = Server_Data:GetData(player)
	if not data then
		return
	end

	if type(data.PurchasesLogs) ~= "table" then
		data.PurchasesLogs = {}
	end

	table.insert(data.PurchasesLogs, {
		ConfigKey = configKey,
		ProductId = productId,
		PurchaseId = purchaseId,
		Time = os.time(),
	})

	local replica = Server_Data:GetReplica(player)
	if replica then
		replica:SetValue({ "PurchasesLogs" }, data.PurchasesLogs)
	end
end

local function grantInventoryItem(player: Player, record: ProductInfoRecord): (boolean, string?)
	local grantAmount = math.max(1, math.floor(tonumber(record.GrantAmount) or 1))
	local itemType = record.GrantItemType or "LuckyBlock"
	local configName = record.GrantConfigName or "VIPLuckyBlock"

	if getInventoryFreeSlots(player) < grantAmount then
		return false, "Inventory is full"
	end

	for _ = 1, grantAmount do
		local newIndex = Server_Data:AddInventoryItem(player, {
			ItemType = itemType,
			ConfigName = configName,
			Data = {},
		})
		if not newIndex then
			return false, "Inventory is full"
		end
	end

	return true, nil
end

local function tryGrantProduct(player: Player, configKey: string, receiptInfo: any?): (boolean, string?)
	local handler = grantHandlers[configKey]
	if handler then
		local ok, granted, reason = pcall(handler, player, receiptInfo)
		if not ok then
			return false, "Grant failed"
		end
		if type(granted) == "boolean" then
			return granted, reason
		end
		return granted == true, reason
	end

	local record = productInfoByKey[configKey]
	if not record then
		return false, "Unknown product"
	end

	if record.GrantItemType == "Cash" then
		return grantCash(player, record)
	end

	if record.GrantItemType == Shared_Marketplace.GrantItemType.Speed then
		return grantSpeed(player, record)
	end

	if record.GrantItemType == Shared_Marketplace.GrantItemType.Strength then
		return grantStrength(player, record)
	end

	if record.GrantItemType == Shared_Marketplace.GrantItemType.Rebirth then
		return grantRebirth(player)
	end

	if record.GrantItemType == Shared_Marketplace.GrantItemType.OfflineCash then
		return grantOfflineCash(player, record)
	end

	if record.GrantItemType == Shared_Marketplace.GrantItemType.TeleportHome then
		return grantTeleportHome(player, record)
	end

	return grantInventoryItem(player, record)
end

local function notifyPurchaseResult(player: Player, configKey: string, success: boolean, reason: string?)
	local handler = getMarketplaceHandler()
	if success then
		handler:FireClient(player, "PurchaseSuccess", configKey)
	else
		handler:FireClient(player, "PurchaseFailed", configKey, reason or "Purchase failed")
	end
end

local function onProcessReceipt(receiptInfo: any)
	local productId = math.floor(tonumber(receiptInfo.ProductId) or 0)
	local record = productInfoById[productId]
	if not record then
		warn(`[Server_Marketplace] Unknown developer product id: {productId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(tonumber(receiptInfo.PlayerId) or 0)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local allowed, denyReason = canPurchaseProduct(player, record.ConfigKey)
	if not allowed then
		notifyPurchaseResult(player, record.ConfigKey, false, denyReason)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	appendPurchaseLog(player, record.ConfigKey, productId, receiptInfo.PurchaseId)

	local granted, grantReason = tryGrantProduct(player, record.ConfigKey, receiptInfo)
	if granted then
		notifyPurchaseResult(player, record.ConfigKey, true, nil)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	warn(
		`[Server_Marketplace] Failed to grant "{record.ConfigKey}" ({productId}) to {player.Name}: {grantReason or "unknown"}`
	)
	notifyPurchaseResult(player, record.ConfigKey, false, grantReason)
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function waitForPlayerData(player: Player): boolean
	for _ = 1, 100 do
		if Server_Data:GetData(player) then
			return true
		end
		if not player.Parent then
			return false
		end
		task.wait(0.1)
	end
	return false
end

local function buildClientCatalog(): { [string]: ClientProductInfo }
	local catalog: { [string]: ClientProductInfo } = {}
	for configKey, record in productInfoByKey do
		catalog[configKey] = toClientProductInfo(record)
	end
	return catalog
end

function Server_Marketplace.SyncPlayerCatalog(player: Player)
	getMarketplaceHandler():FireClient(player, "CatalogSync", buildClientCatalog())
end

local function broadcastCatalogProductUpdate(configKey: string)
	local record = productInfoByKey[configKey]
	if not record then
		return
	end

	local clientRecord = toClientProductInfo(record)
	for _, player in Players:GetPlayers() do
		getMarketplaceHandler():FireClient(player, "CatalogProductUpdate", configKey, clientRecord)
	end
end

local function startProgressiveProductLoad()
	productLoadGeneration += 1
	local generation = productLoadGeneration

	task.spawn(function()
		for _, configKey in Shared_Marketplace.GetCatalogLoadOrder() do
			if generation ~= productLoadGeneration then
				return
			end

			local record = productInfoByKey[configKey]
			if not record or record.ProductId <= 0 or record.Loaded then
				continue
			end

			loadProductInfo(record)
			broadcastCatalogProductUpdate(configKey)
			task.wait(PRODUCT_LOAD_YIELD_SECONDS)
		end
	end)
end

local function syncPlayerGamepasses(player: Player)
	local data = Server_Data:GetData(player)
	if not data then
		return
	end

	if type(data.DataGamepasses) ~= "table" then
		data.DataGamepasses = {}
	end

	local changed = false

	for configKey, config in Shared_Marketplace.GetAllProducts() do
		if config.ProductType ~= Shared_Marketplace.ProductType.GamePass then
			continue
		end

		local productId = Shared_Marketplace.GetConfiguredProductId(configKey)
		if not productId then
			continue
		end

		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, productId)
		end)

		local owned = ok and owns == true
		if data.DataGamepasses[configKey] ~= owned then
			data.DataGamepasses[configKey] = owned
			changed = true
		end
	end

	if changed then
		local replica = Server_Data:GetReplica(player)
		if replica then
			replica:SetValue({ "DataGamepasses" }, data.DataGamepasses)
		end
	end
end

local function onPlayerAdded(player: Player)
	task.defer(function()
		if not waitForPlayerData(player) then
			return
		end
		task.spawn(function()
			for _ = 1, 6 do
				syncPlayerGamepasses(player)
				task.wait(0.5)
			end
		end)
		Server_Marketplace.SyncPlayerCatalog(player)
	end)
end

local function onMarketplaceClientEvent(player: Player, action: string, arg1: any)
	if action == "RequestCatalog" then
		Server_Marketplace.SyncPlayerCatalog(player)
		return
	end

	if action == "CanPurchase" then
		local configKey = if type(arg1) == "string" then arg1 else nil
		if not configKey then
			return
		end

		local allowed, reason = canPurchaseProduct(player, configKey)
		getMarketplaceHandler():FireClient(player, "CanPurchaseResult", configKey, allowed, reason)
		return
	end

	if action == "RequestGamepassSync" then
		task.spawn(function()
			for _ = 1, 12 do
				syncPlayerGamepasses(player)
				task.wait(0.25)
			end
		end)
	end
end

local function registerDefaultGrantHandlers()
	for configKey, config in Shared_Marketplace.GetAllProducts() do
		if config.ProductType ~= Shared_Marketplace.ProductType.DevProduct then
			continue
		end

		if config.GrantItemType == "Cash" then
			grantHandlers[configKey] = function(player: Player)
				local record = productInfoByKey[configKey]
				if not record then
					return false, "Unknown product"
				end
				return grantCash(player, record)
			end
			continue
		end

		if config.GrantItemType == Shared_Marketplace.GrantItemType.Speed then
			grantHandlers[configKey] = function(player: Player)
				local record = productInfoByKey[configKey]
				if not record then
					return false, "Unknown product"
				end
				return grantSpeed(player, record)
			end
			continue
		end

		if config.GrantItemType == Shared_Marketplace.GrantItemType.Strength then
			grantHandlers[configKey] = function(player: Player)
				local record = productInfoByKey[configKey]
				if not record then
					return false, "Unknown product"
				end
				return grantStrength(player, record)
			end
			continue
		end

		if config.GrantItemType == Shared_Marketplace.GrantItemType.Rebirth then
			grantHandlers[configKey] = function(player: Player)
				return grantRebirth(player)
			end
			continue
		end

		if config.GrantItemType == Shared_Marketplace.GrantItemType.OfflineCash then
			grantHandlers[configKey] = function(player: Player)
				local record = productInfoByKey[configKey]
				if not record then
					return false, "Unknown product"
				end
				return grantOfflineCash(player, record)
			end
			continue
		end

		if config.GrantItemType == Shared_Marketplace.GrantItemType.TeleportHome then
			grantHandlers[configKey] = function(player: Player)
				local record = productInfoByKey[configKey]
				if not record then
					return false, "Unknown product"
				end
				return grantTeleportHome(player, record)
			end
			continue
		end

		if type(config.GrantItemType) ~= "string" or type(config.GrantConfigName) ~= "string" then
			continue
		end

		grantHandlers[configKey] = function(player: Player)
			local record = productInfoByKey[configKey]
			if not record then
				return false, "Unknown product"
			end
			return grantInventoryItem(player, record)
		end
	end
end

function Server_Marketplace.LoadProductInfo()
	productLoadGeneration += 1

	table.clear(productInfoByKey)
	table.clear(productInfoById)

	for _, issue in Shared_Marketplace.ValidateProducts() do
		if string.find(issue, "ProductId 0", 1, true) then
			continue
		end
		warn(`[Server_Marketplace] Config issue: {issue}`)
	end

	for _, configKey in Shared_Marketplace.GetCatalogLoadOrder() do
		local config = Shared_Marketplace.GetProduct(configKey)
		if not config then
			continue
		end

		local record = buildBaseRecord(configKey, config)
		indexRecord(record)
	end

	startProgressiveProductLoad()
end

function Server_Marketplace.GetProductInfo(configKey: string): ProductInfoRecord?
	return productInfoByKey[configKey]
end

function Server_Marketplace.GetProductInfoById(productId: number): ProductInfoRecord?
	return productInfoById[math.floor(tonumber(productId) or 0)]
end

function Server_Marketplace.GetAllProductInfo(): { [string]: ProductInfoRecord }
	return productInfoByKey
end

function Server_Marketplace.IsProductInfoLoaded(configKey: string): boolean
	local record = productInfoByKey[configKey]
	return record ~= nil and record.Loaded == true
end

function Server_Marketplace.PlayerOwnsGamepass(player: Player, configKey: string): boolean
	local data = Server_Data:GetData(player)
	if not data or type(data.DataGamepasses) ~= "table" then
		return false
	end
	return data.DataGamepasses[configKey] == true
end

function Server_Marketplace.GetPlayerWeightLuckMultiplier(player: Player): number
	local data = Server_Data:GetData(player)
	if not data then
		return 1
	end
	return Shared_Marketplace.GetWeightLuckMultiplierFromGamepasses(data.DataGamepasses)
end

function Server_Marketplace.PlayerOwnsFastCollect(player: Player): boolean
	return Server_Marketplace.PlayerOwnsGamepass(player, Shared_Marketplace.FastCollectGamepassConfigKey)
end

function Server_Marketplace.RegisterGrantHandler(
	configKey: string,
	handler: (player: Player, receiptInfo: any?) -> (boolean, string?)
)
	grantHandlers[configKey] = handler
end

function Server_Marketplace.SetPlotService(service: any)
	plotServiceRef = service
end

function Server_Marketplace.SyncPlayerGamepasses(player: Player)
	syncPlayerGamepasses(player)
end

function Server_Marketplace.Init()
	if initialized then
		return
	end
	initialized = true

	registerDefaultGrantHandlers()
	Server_Marketplace.LoadProductInfo()

	MarketplaceService.ProcessReceipt = onProcessReceipt

	getMarketplaceHandler().OnServerEvent:Connect(onMarketplaceClientEvent)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
end

return Server_Marketplace
