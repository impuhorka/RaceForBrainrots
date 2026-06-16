local Shared_Marketplace = {}

Shared_Marketplace.ProductType = {
	DevProduct = "DevProduct",
	GamePass = "GamePass",
}

export type ProductTypeName = "DevProduct" | "GamePass"

export type ProductConfig = {
	ProductType: ProductTypeName,
	ProductId: number,
	DisplayName: string?,
	Description: string?,
	GrantAmount: number?,
	GrantItemType: string?,
	GrantConfigName: string?,
	RequiresPaidRandomItems: boolean?,
	CashPopupCount: number?,
	CashPopupTemplate: string?,
}

--[[
	ProductId = Roblox developer product or game pass id (0 = disabled / not set yet).
	Config keys are used in code, save data, and client UI.
]]
Shared_Marketplace.Products = {
	VIPLuckyBlock1 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3604907188,
		DisplayName = "VIP Lucky Block",
		Description = "1 VIP Lucky Block",
		GrantAmount = 1,
		GrantItemType = "LuckyBlock",
		GrantConfigName = "VIPLuckyBlock",
		RequiresPaidRandomItems = true,
	},
	VIPLuckyBlock3 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3604907231,
		DisplayName = "VIP Lucky Block x3",
		Description = "3 VIP Lucky Blocks",
		GrantAmount = 3,
		GrantItemType = "LuckyBlock",
		GrantConfigName = "VIPLuckyBlock",
		RequiresPaidRandomItems = true,
	},
	VIPLuckyBlock10 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3604907269,
		DisplayName = "VIP Lucky Block x10",
		Description = "10 VIP Lucky Blocks",
		GrantAmount = 10,
		GrantItemType = "LuckyBlock",
		GrantConfigName = "VIPLuckyBlock",
		RequiresPaidRandomItems = true,
	},

	RobuxCash1 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3604909509,
		DisplayName = "Cash Pack",
		Description = "Cash pack tier 1",
		GrantAmount = 50_000,
		GrantItemType = "Cash",
		CashPopupCount = 3,
		CashPopupTemplate = "1",
	},
	RobuxCash2 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3604909905,
		DisplayName = "Cash Pack",
		Description = "Cash pack tier 2",
		GrantAmount = 400_000,
		GrantItemType = "Cash",
		CashPopupCount = 7,
		CashPopupTemplate = "2",
	},
	RobuxCash3 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3604909938,
		DisplayName = "Cash Pack",
		Description = "Cash pack tier 3",
		GrantAmount = 8_000_000,
		GrantItemType = "Cash",
		CashPopupCount = 13,
		CashPopupTemplate = "3",
	},
	RobuxCash4 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3604909975,
		DisplayName = "Cash Pack",
		Description = "Cash pack tier 4",
		GrantAmount = 100_000_000,
		GrantItemType = "Cash",
		CashPopupCount = 24,
		CashPopupTemplate = "4",
	},

	VIP = {
		ProductType = Shared_Marketplace.ProductType.GamePass,
		ProductId = 1880746286,
		DisplayName = "VIP",
		Description = "VIP game pass",
	},
}

Shared_Marketplace.VIPLuckyBlockBundleAmounts = { 1, 3, 10 }
Shared_Marketplace.RobuxCashTiers = { 1, 2, 3, 4 }

local function isProductType(value: any): boolean
	return value == Shared_Marketplace.ProductType.DevProduct
		or value == Shared_Marketplace.ProductType.GamePass
end

function Shared_Marketplace.GetProduct(configKey: string): ProductConfig?
	local config = Shared_Marketplace.Products[configKey]
	if type(config) ~= "table" then
		return nil
	end
	return config
end

function Shared_Marketplace.GetAllProducts(): { [string]: ProductConfig }
	return Shared_Marketplace.Products
end

function Shared_Marketplace.GetProductKeys(): { string }
	local keys: { string } = {}
	for configKey in Shared_Marketplace.Products do
		table.insert(keys, configKey)
	end
	table.sort(keys)
	return keys
end

function Shared_Marketplace.GetVIPLuckyBlockProductKey(bundleAmount: number): string?
	local safeAmount = math.floor(tonumber(bundleAmount) or 0)
	if safeAmount <= 0 then
		return nil
	end
	return `VIPLuckyBlock{safeAmount}`
end

function Shared_Marketplace.GetRobuxCashProductKey(tier: number): string?
	local safeTier = math.floor(tonumber(tier) or 0)
	if safeTier <= 0 then
		return nil
	end
	return `RobuxCash{safeTier}`
end

function Shared_Marketplace.IsCashProduct(configKey: string): boolean
	local config = Shared_Marketplace.GetProduct(configKey)
	return config ~= nil and config.GrantItemType == "Cash"
end

function Shared_Marketplace.GetGrantCash(configKey: string): number
	local config = Shared_Marketplace.GetProduct(configKey)
	if not config or config.GrantItemType ~= "Cash" then
		return 0
	end
	return math.max(0, math.floor(tonumber(config.GrantAmount) or 0))
end

function Shared_Marketplace.GetCashPopupCount(configKey: string): number
	local config = Shared_Marketplace.GetProduct(configKey)
	if not config or config.GrantItemType ~= "Cash" then
		return 3
	end
	return math.max(1, math.floor(tonumber(config.CashPopupCount) or 3))
end

function Shared_Marketplace.GetCashPopupTemplate(configKey: string): string?
	local config = Shared_Marketplace.GetProduct(configKey)
	if not config or config.GrantItemType ~= "Cash" then
		return nil
	end
	if type(config.CashPopupTemplate) == "string" and config.CashPopupTemplate ~= "" then
		return config.CashPopupTemplate
	end
	return nil
end

function Shared_Marketplace.GetGrantAmount(configKey: string): number
	local config = Shared_Marketplace.GetProduct(configKey)
	if not config then
		return 0
	end
	return math.max(1, math.floor(tonumber(config.GrantAmount) or 1))
end

function Shared_Marketplace.RequiresPaidRandomItems(configKey: string): boolean
	local config = Shared_Marketplace.GetProduct(configKey)
	return config ~= nil and config.RequiresPaidRandomItems == true
end

function Shared_Marketplace.IsDevProduct(configKey: string): boolean
	local config = Shared_Marketplace.GetProduct(configKey)
	return config ~= nil and config.ProductType == Shared_Marketplace.ProductType.DevProduct
end

function Shared_Marketplace.IsGamePass(configKey: string): boolean
	local config = Shared_Marketplace.GetProduct(configKey)
	return config ~= nil and config.ProductType == Shared_Marketplace.ProductType.GamePass
end

function Shared_Marketplace.GetConfiguredProductId(configKey: string): number?
	local config = Shared_Marketplace.GetProduct(configKey)
	if not config then
		return nil
	end

	local productId = math.floor(tonumber(config.ProductId) or 0)
	if productId <= 0 then
		return nil
	end

	return productId
end

function Shared_Marketplace.GetConfigKeyForProductId(productId: number): string?
	local safeProductId = math.floor(tonumber(productId) or 0)
	if safeProductId <= 0 then
		return nil
	end

	for configKey, config in Shared_Marketplace.Products do
		if math.floor(tonumber(config.ProductId) or 0) == safeProductId then
			return configKey
		end
	end

	return nil
end

function Shared_Marketplace.GetGamePassConfigKeyFromFrameName(frameName: string): string?
	local configKey = Shared_Marketplace.GetConfigKeyForProductId(frameName)
	if not configKey or not Shared_Marketplace.IsGamePass(configKey) then
		return nil
	end
	return configKey
end

function Shared_Marketplace.ValidateProducts(): { string }
	local issues: { string } = {}
	local usedIds: { [number]: string } = {}

	for configKey, config in Shared_Marketplace.Products do
		if type(config) ~= "table" then
			table.insert(issues, `Product "{configKey}" is not a table`)
			continue
		end

		if not isProductType(config.ProductType) then
			table.insert(issues, `Product "{configKey}" has invalid ProductType`)
		end

		local productId = math.floor(tonumber(config.ProductId) or 0)
		if productId <= 0 then
			table.insert(issues, `Product "{configKey}" has ProductId 0 (not configured)`)
		else
			local existingKey = usedIds[productId]
			if existingKey then
				table.insert(
					issues,
					`Duplicate ProductId {productId} on "{configKey}" and "{existingKey}"`
				)
			else
				usedIds[productId] = configKey
			end
		end
	end

	return issues
end

return Shared_Marketplace
