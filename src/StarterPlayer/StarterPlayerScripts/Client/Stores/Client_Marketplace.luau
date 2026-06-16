local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local ClientLoader = require(script.Parent.Parent.Loader)

local Shared_Marketplace = SharedModules.require("Shared_Marketplace")

local Client_Marketplace = {}

export type UserProductPrice = {
	PriceInRobux: number?,
	UserBasePriceInRobux: number?,
	PlusDiscountPercent: number?,
	Loaded: boolean,
	Error: string?,
}

export type ServerProductInfo = {
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

local localPlayer = Players.LocalPlayer
local marketplaceHandler: RemoteEvent? = nil

local serverCatalog: { [string]: ServerProductInfo } = {}
local userPricesByKey: { [string]: UserProductPrice } = {}
local policyLoaded = false
local canPurchasePaidRandomItems = false
local catalogReady = false
local isReady = false

local catalogChangedCallbacks: { () -> () } = {}
local policyChangedCallbacks: { () -> () } = {}
local pricesChangedCallbacks: { () -> () } = {}

local gamepassOwnershipCallbacks: { () -> () } = {}

local pendingCanPurchase: { [string]: { thread } } = {}

local function getPlusDiscountPercent(info: any): number?
	if type(info) ~= "table" or type(info.PriceDiscountDetails) ~= "table" then
		return nil
	end

	for _, discount in info.PriceDiscountDetails do
		if type(discount) == "table" and discount.Type == "RobloxPlusSubscription" then
			local percent = tonumber(discount.Percent)
			if percent and percent > 0 then
				return math.floor(percent)
			end
		end
	end

	return nil
end

local function getInfoType(productType: string): Enum.InfoType
	if productType == Shared_Marketplace.ProductType.GamePass then
		return Enum.InfoType.GamePass
	end
	return Enum.InfoType.Product
end

local function getMarketplaceHandler(): RemoteEvent
	if marketplaceHandler then
		return marketplaceHandler
	end

	marketplaceHandler = ReplicatedStorage:WaitForChild("Events"):WaitForChild("MarketplaceHandler") :: RemoteEvent
	return marketplaceHandler
end

local function notify(callbacks: { () -> () })
	for _, callback in callbacks do
		task.spawn(callback)
	end
end

local function setReady()
	if isReady then
		return
	end
	if not catalogReady or not policyLoaded then
		return
	end
	isReady = true
end

local function loadPolicyInfo()
	local ok, policyInfo = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(localPlayer)
	end)

	policyLoaded = true
	canPurchasePaidRandomItems = ok
		and type(policyInfo) == "table"
		and policyInfo.ArePaidRandomItemsRestricted ~= true

	notify(policyChangedCallbacks)
	setReady()
end

local function loadUserPriceForRecord(record: ServerProductInfo)
	if record.ProductId <= 0 or record.Loaded ~= true then
		userPricesByKey[record.ConfigKey] = {
			PriceInRobux = record.PriceInRobux,
			UserBasePriceInRobux = record.UserBasePriceInRobux or record.PriceInRobux,
			PlusDiscountPercent = nil,
			Loaded = false,
			Error = record.Error or "Product unavailable",
		}
		return
	end

	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(record.ProductId, getInfoType(record.ProductType))
	end)

	if not ok or type(info) ~= "table" then
		userPricesByKey[record.ConfigKey] = {
			PriceInRobux = record.PriceInRobux,
			UserBasePriceInRobux = record.UserBasePriceInRobux or record.PriceInRobux,
			PlusDiscountPercent = nil,
			Loaded = false,
			Error = if type(info) == "string" then info else "Failed to load user price",
		}
		return
	end

	userPricesByKey[record.ConfigKey] = {
		PriceInRobux = tonumber(info.PriceInRobux),
		UserBasePriceInRobux = tonumber(info.UserBasePriceInRobux) or tonumber(info.PriceInRobux),
		PlusDiscountPercent = getPlusDiscountPercent(info),
		Loaded = true,
		Error = nil,
	}
end

function Client_Marketplace.RefreshUserPrices()
	for _, record in serverCatalog do
		loadUserPriceForRecord(record)
	end
	notify(pricesChangedCallbacks)
end

local function applyCatalog(catalog: { [string]: ServerProductInfo })
	table.clear(serverCatalog)
	for configKey, record in catalog do
		if type(record) == "table" then
			serverCatalog[configKey] = record
		end
	end

	catalogReady = true
	Client_Marketplace.RefreshUserPrices()
	notify(catalogChangedCallbacks)
	setReady()
end

local function resolveCanPurchaseWaiters(configKey: string, allowed: boolean)
	local waiters = pendingCanPurchase[configKey]
	pendingCanPurchase[configKey] = nil
	if not waiters then
		return
	end

	for _, thread in waiters do
		task.spawn(thread, allowed)
	end
end

local function onMarketplaceEvent(action: string, arg1: any, arg2: any, arg3: any)
	if action == "CatalogSync" then
		if type(arg1) == "table" then
			applyCatalog(arg1)
		end
		return
	end

	if action == "CanPurchaseResult" then
		local configKey = if type(arg1) == "string" then arg1 else nil
		if not configKey then
			return
		end
		resolveCanPurchaseWaiters(configKey, arg2 == true)
		return
	end

	if action == "PurchaseSuccess" then
		Client_Marketplace.OnPurchaseSuccess(arg1)
		return
	end

	if action == "PurchaseFailed" then
		Client_Marketplace.OnPurchaseFailed(arg1, arg2)
	end
end

function Client_Marketplace.OnPurchaseSuccess(_configKey: string) end
function Client_Marketplace.OnPurchaseFailed(_configKey: string, _reason: string?) end

function Client_Marketplace.WaitUntilReady(timeoutSeconds: number?): boolean
	if isReady then
		return true
	end

	local timeout = timeoutSeconds or 30
	local waited = 0
	while not isReady and waited < timeout do
		task.wait(0.1)
		waited += 0.1
	end
	return isReady
end

function Client_Marketplace.IsReady(): boolean
	return isReady
end

function Client_Marketplace.CanPurchasePaidRandomItems(): boolean
	return canPurchasePaidRandomItems
end

function Client_Marketplace.GetServerProductInfo(configKey: string): ServerProductInfo?
	return serverCatalog[configKey]
end

function Client_Marketplace.GetAllServerProductInfo(): { [string]: ServerProductInfo }
	return serverCatalog
end

function Client_Marketplace.GetUserPrice(configKey: string): UserProductPrice?
	return userPricesByKey[configKey]
end

function Client_Marketplace.GetUserPriceInRobux(configKey: string): number?
	local priceInfo = userPricesByKey[configKey]
	if not priceInfo then
		return nil
	end
	return priceInfo.PriceInRobux
end

function Client_Marketplace.GetRobloxPlusDiscountPercent(): number?
	for _, priceInfo in userPricesByKey do
		local percent = priceInfo.PlusDiscountPercent
		if type(percent) == "number" and percent > 0 then
			return percent
		end
	end
	return nil
end

function Client_Marketplace.GetBundleDiscount(configKey: string, unitConfigKey: string): number
	local bundlePrice = Client_Marketplace.GetUserPriceInRobux(configKey)
	local unitPrice = Client_Marketplace.GetUserPriceInRobux(unitConfigKey)
	if not bundlePrice or not unitPrice then
		return 0
	end

	local bundleAmount = Shared_Marketplace.GetGrantAmount(configKey)
	local expectedTotal = unitPrice * bundleAmount
	local discount = math.floor(expectedTotal - bundlePrice)
	if discount <= 0 then
		return 0
	end
	return discount
end

function Client_Marketplace.RequestServerCanPurchase(configKey: string, timeoutSeconds: number?): boolean
	local record = serverCatalog[configKey]
	if not record or record.Loaded ~= true then
		return false
	end

	if record.RequiresPaidRandomItems and not canPurchasePaidRandomItems then
		return false
	end

	local waiters = pendingCanPurchase[configKey]
	if not waiters then
		waiters = {}
		pendingCanPurchase[configKey] = waiters
	end

	local allowed = false
	local completed = false

	table.insert(waiters, function(result: boolean)
		allowed = result
		completed = true
	end)

	getMarketplaceHandler():FireServer("CanPurchase", configKey)

	local timeout = timeoutSeconds or 5
	local waited = 0
	while not completed and waited < timeout do
		task.wait(0.05)
		waited += 0.05
	end

	if not completed then
		resolveCanPurchaseWaiters(configKey, false)
	end

	return allowed
end

function Client_Marketplace.PlayerOwnsGamepass(configKey: string): boolean
	local Client_Data = ClientLoader.require("Client_Data")
	local gamepasses = Client_Data:GetValue("DataGamepasses")
	if type(gamepasses) ~= "table" then
		return false
	end
	return gamepasses[configKey] == true
end

function Client_Marketplace.PromptGamePassPurchase(configKey: string): boolean
	local record = serverCatalog[configKey]
	if not record or record.ProductType ~= Shared_Marketplace.ProductType.GamePass or record.ProductId <= 0 then
		return false
	end

	if Client_Marketplace.PlayerOwnsGamepass(configKey) then
		return false
	end

	MarketplaceService:PromptGamePassPurchase(localPlayer, record.ProductId)
	return true
end

function Client_Marketplace.RequestGamepassSync()
	getMarketplaceHandler():FireServer("RequestGamepassSync")
end

function Client_Marketplace.OnGamepassOwnershipChanged(callback: () -> ())
	table.insert(gamepassOwnershipCallbacks, callback)
end

function Client_Marketplace.PromptProductPurchase(configKey: string): boolean
	local record = serverCatalog[configKey]
	if not record or record.ProductId <= 0 then
		return false
	end

	MarketplaceService:PromptProductPurchase(localPlayer, record.ProductId)
	return true
end

function Client_Marketplace.OnCatalogChanged(callback: () -> ())
	table.insert(catalogChangedCallbacks, callback)
end

function Client_Marketplace.OnPolicyChanged(callback: () -> ())
	table.insert(policyChangedCallbacks, callback)
end

function Client_Marketplace.OnPricesChanged(callback: () -> ())
	table.insert(pricesChangedCallbacks, callback)
end

function Client_Marketplace.Init()
	getMarketplaceHandler().OnClientEvent:Connect(onMarketplaceEvent)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
		if player ~= localPlayer or wasPurchased ~= true then
			return
		end

		local configKey = Shared_Marketplace.GetConfigKeyForProductId(gamePassId)
		if not configKey or not Shared_Marketplace.IsGamePass(configKey) then
			return
		end

		Client_Marketplace.RequestGamepassSync()

		task.spawn(function()
			for _ = 1, 30 do
				if Client_Marketplace.PlayerOwnsGamepass(configKey) then
					break
				end
				task.wait(0.1)
			end

			notify(gamepassOwnershipCallbacks)
			Client_Marketplace.OnPurchaseSuccess(configKey)
		end)
	end)

	task.spawn(loadPolicyInfo)
	getMarketplaceHandler():FireServer("RequestCatalog")
end

return Client_Marketplace
