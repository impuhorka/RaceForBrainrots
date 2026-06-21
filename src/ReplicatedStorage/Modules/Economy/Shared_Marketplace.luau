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
	WeightLuckMultiplier: number?,
	GrantItemType: string?,
	GrantConfigName: string?,
	RequiresPaidRandomItems: boolean?,
	CashPopupCount: number?,
	CashPopupTemplate: string?,
}

Shared_Marketplace.GrantItemType = {
	LuckMultiplier = "LuckMultiplier",
	FastCollect = "FastCollect",
	Speed = "Speed",
	Strength = "Strength",
	Rebirth = "Rebirth",
	OfflineCash = "OfflineCash",
	TeleportHome = "TeleportHome",
}

-- Loaded first so shop UI prices appear quickly; remaining products follow alphabetically.
Shared_Marketplace.CatalogLoadPriority = {
	"VIP",
	"LuckX4",
	"LuckX2",
	"FastCollect",
	"OfflineCashX10",
	"RebirthT1",
	"RebirthT2",
	"RebirthT3",
	"RobuxCash1",
	"RobuxCash2",
	"RobuxCash3",
	"RobuxCash4",
	"VIPLuckyBlock1",
	"VIPLuckyBlock3",
	"VIPLuckyBlock10",
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

	SpeedRobuxT1_1 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605872979,
		DisplayName = "+1 Speed",
		Description = "+1 speed (tier 1)",
		GrantAmount = 1,
		GrantItemType = Shared_Marketplace.GrantItemType.Speed,
	},
	SpeedRobuxT1_2 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605873029,
		DisplayName = "+1 Speed",
		Description = "+1 speed (tier 2)",
		GrantAmount = 1,
		GrantItemType = Shared_Marketplace.GrantItemType.Speed,
	},
	SpeedRobuxT1_3 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605873062,
		DisplayName = "+1 Speed",
		Description = "+1 speed (tier 3)",
		GrantAmount = 1,
		GrantItemType = Shared_Marketplace.GrantItemType.Speed,
	},
	SpeedRobuxT2_1 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605873170,
		DisplayName = "+5 Speed",
		Description = "+5 speed (tier 1)",
		GrantAmount = 5,
		GrantItemType = Shared_Marketplace.GrantItemType.Speed,
	},
	SpeedRobuxT2_2 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605873210,
		DisplayName = "+5 Speed",
		Description = "+5 speed (tier 2)",
		GrantAmount = 5,
		GrantItemType = Shared_Marketplace.GrantItemType.Speed,
	},
	SpeedRobuxT2_3 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605873252,
		DisplayName = "+5 Speed",
		Description = "+5 speed (tier 3)",
		GrantAmount = 5,
		GrantItemType = Shared_Marketplace.GrantItemType.Speed,
	},
	SpeedRobuxT3_1 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605873301,
		DisplayName = "+10 Speed",
		Description = "+10 speed (tier 1)",
		GrantAmount = 10,
		GrantItemType = Shared_Marketplace.GrantItemType.Speed,
	},
	SpeedRobuxT3_2 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605873364,
		DisplayName = "+10 Speed",
		Description = "+10 speed (tier 2)",
		GrantAmount = 10,
		GrantItemType = Shared_Marketplace.GrantItemType.Speed,
	},
	SpeedRobuxT3_3 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605873438,
		DisplayName = "+10 Speed",
		Description = "+10 speed (tier 3)",
		GrantAmount = 10,
		GrantItemType = Shared_Marketplace.GrantItemType.Speed,
	},

	StrengthRobuxT1_1 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605876398,
		DisplayName = "+1 Strength",
		Description = "+1 strength (tier 1)",
		GrantAmount = 1,
		GrantItemType = Shared_Marketplace.GrantItemType.Strength,
	},
	StrengthRobuxT1_2 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605876428,
		DisplayName = "+1 Strength",
		Description = "+1 strength (tier 2)",
		GrantAmount = 1,
		GrantItemType = Shared_Marketplace.GrantItemType.Strength,
	},
	StrengthRobuxT1_3 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605876458,
		DisplayName = "+1 Strength",
		Description = "+1 strength (tier 3)",
		GrantAmount = 1,
		GrantItemType = Shared_Marketplace.GrantItemType.Strength,
	},
	StrengthRobuxT2_1 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605876502,
		DisplayName = "+5 Strength",
		Description = "+5 strength (tier 1)",
		GrantAmount = 5,
		GrantItemType = Shared_Marketplace.GrantItemType.Strength,
	},
	StrengthRobuxT2_2 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605876541,
		DisplayName = "+5 Strength",
		Description = "+5 strength (tier 2)",
		GrantAmount = 5,
		GrantItemType = Shared_Marketplace.GrantItemType.Strength,
	},
	StrengthRobuxT2_3 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605876806,
		DisplayName = "+5 Strength",
		Description = "+5 strength (tier 3)",
		GrantAmount = 5,
		GrantItemType = Shared_Marketplace.GrantItemType.Strength,
	},
	StrengthRobuxT3_1 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605876858,
		DisplayName = "+10 Strength",
		Description = "+10 strength (tier 1)",
		GrantAmount = 10,
		GrantItemType = Shared_Marketplace.GrantItemType.Strength,
	},
	StrengthRobuxT3_2 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605876889,
		DisplayName = "+10 Strength",
		Description = "+10 strength (tier 2)",
		GrantAmount = 10,
		GrantItemType = Shared_Marketplace.GrantItemType.Strength,
	},
	StrengthRobuxT3_3 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605876924,
		DisplayName = "+10 Strength",
		Description = "+10 strength (tier 3)",
		GrantAmount = 10,
		GrantItemType = Shared_Marketplace.GrantItemType.Strength,
	},

	RebirthT1 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605880936,
		DisplayName = "Rebirth",
		Description = "Rebirth (early tier)",
		GrantAmount = 1,
		GrantItemType = Shared_Marketplace.GrantItemType.Rebirth,
	},
	RebirthT2 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605880981,
		DisplayName = "Rebirth",
		Description = "Rebirth (mid tier)",
		GrantAmount = 1,
		GrantItemType = Shared_Marketplace.GrantItemType.Rebirth,
	},
	RebirthT3 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605881030,
		DisplayName = "Rebirth",
		Description = "Rebirth (late tier)",
		GrantAmount = 1,
		GrantItemType = Shared_Marketplace.GrantItemType.Rebirth,
	},

	OfflineCashX10 = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605882564,
		DisplayName = "x10 Offline Cash",
		Description = "Collect 10x your pending offline cash",
		GrantAmount = 10,
		GrantItemType = Shared_Marketplace.GrantItemType.OfflineCash,
	},

	TeleportHomeCommon = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605877625,
		DisplayName = "Teleport Home",
		Description = "Teleport home with a Common lucky block",
		GrantItemType = Shared_Marketplace.GrantItemType.TeleportHome,
		GrantConfigName = "Common",
	},
	TeleportHomeRare = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605877652,
		DisplayName = "Teleport Home",
		Description = "Teleport home with a Rare lucky block",
		GrantItemType = Shared_Marketplace.GrantItemType.TeleportHome,
		GrantConfigName = "Rare",
	},
	TeleportHomeEpic = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605877688,
		DisplayName = "Teleport Home",
		Description = "Teleport home with an Epic lucky block",
		GrantItemType = Shared_Marketplace.GrantItemType.TeleportHome,
		GrantConfigName = "Epic",
	},
	TeleportHomeLegendary = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605877921,
		DisplayName = "Teleport Home",
		Description = "Teleport home with a Legendary lucky block",
		GrantItemType = Shared_Marketplace.GrantItemType.TeleportHome,
		GrantConfigName = "Legendary",
	},
	TeleportHomeMythical = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605877944,
		DisplayName = "Teleport Home",
		Description = "Teleport home with a Mythical lucky block",
		GrantItemType = Shared_Marketplace.GrantItemType.TeleportHome,
		GrantConfigName = "Mythical",
	},
	TeleportHomeSecret = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605877971,
		DisplayName = "Teleport Home",
		Description = "Teleport home with a Secret lucky block",
		GrantItemType = Shared_Marketplace.GrantItemType.TeleportHome,
		GrantConfigName = "Secret",
	},
	TeleportHomeDivine = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605878037,
		DisplayName = "Teleport Home",
		Description = "Teleport home with a Divine lucky block",
		GrantItemType = Shared_Marketplace.GrantItemType.TeleportHome,
		GrantConfigName = "Divine",
	},
	TeleportHomeSuperior = {
		ProductType = Shared_Marketplace.ProductType.DevProduct,
		ProductId = 3605878084,
		DisplayName = "Teleport Home",
		Description = "Teleport home with a Superior lucky block",
		GrantItemType = Shared_Marketplace.GrantItemType.TeleportHome,
		GrantConfigName = "Superior",
	},

	VIP = {
		ProductType = Shared_Marketplace.ProductType.GamePass,
		ProductId = 1880746286,
		DisplayName = "VIP",
		Description = "VIP game pass",
	},
	LuckX2 = {
		ProductType = Shared_Marketplace.ProductType.GamePass,
		ProductId = 1882403463,
		DisplayName = "x2 Luck",
		Description = "2x better lucky block weight rolls",
		GrantAmount = 2,
		WeightLuckMultiplier = 1.6,
		GrantItemType = Shared_Marketplace.GrantItemType.LuckMultiplier,
	},
	LuckX4 = {
		ProductType = Shared_Marketplace.ProductType.GamePass,
		ProductId = 1883987445,
		DisplayName = "x4 Luck",
		Description = "4x better lucky block weight rolls",
		GrantAmount = 4,
		WeightLuckMultiplier = 2.55,
		GrantItemType = Shared_Marketplace.GrantItemType.LuckMultiplier,
	},
	FastCollect = {
		ProductType = Shared_Marketplace.ProductType.GamePass,
		ProductId = 1883333418,
		DisplayName = "Fast Collect",
		Description = "Faster plot cash collection",
		GrantItemType = Shared_Marketplace.GrantItemType.FastCollect,
	},
}

Shared_Marketplace.OfflineCashRobuxProductKey = "OfflineCashX10"

Shared_Marketplace.VIPLuckyBlockBundleAmounts = { 1, 3, 10 }
Shared_Marketplace.RobuxCashTiers = { 1, 2, 3, 4 }
Shared_Marketplace.LuckGamepassConfigKeys = { "LuckX4", "LuckX2" }
Shared_Marketplace.FastCollectGamepassConfigKey = "FastCollect"
Shared_Marketplace.RobuxIcon = utf8.char(0xE002)

function Shared_Marketplace.FormatRobuxPrice(amount: number): string
	local safeAmount = math.max(0, math.floor(tonumber(amount) or 0))
	return `{safeAmount}{Shared_Marketplace.RobuxIcon}`
end

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

function Shared_Marketplace.GetSpeedRobuxProductKey(tier: number, productType: number): string?
	local safeTier = math.floor(tonumber(tier) or 0)
	local safeType = math.floor(tonumber(productType) or 0)
	if safeTier <= 0 or safeType <= 0 then
		return nil
	end
	return `SpeedRobuxT{safeTier}_{safeType}`
end

function Shared_Marketplace.IsSpeedProduct(configKey: string): boolean
	local config = Shared_Marketplace.GetProduct(configKey)
	return config ~= nil and config.GrantItemType == Shared_Marketplace.GrantItemType.Speed
end

function Shared_Marketplace.GetStrengthRobuxProductKey(tier: number, productType: number): string?
	local safeTier = math.floor(tonumber(tier) or 0)
	local safeType = math.floor(tonumber(productType) or 0)
	if safeTier <= 0 or safeType <= 0 then
		return nil
	end
	return `StrengthRobuxT{safeTier}_{safeType}`
end

function Shared_Marketplace.IsStrengthProduct(configKey: string): boolean
	local config = Shared_Marketplace.GetProduct(configKey)
	return config ~= nil and config.GrantItemType == Shared_Marketplace.GrantItemType.Strength
end

function Shared_Marketplace.GetRebirthRobuxProductKey(tier: number): string?
	local safeTier = math.floor(tonumber(tier) or 0)
	if safeTier <= 0 or safeTier > 3 then
		return nil
	end
	return `RebirthT{safeTier}`
end

function Shared_Marketplace.IsRebirthProduct(configKey: string): boolean
	local config = Shared_Marketplace.GetProduct(configKey)
	return config ~= nil and config.GrantItemType == Shared_Marketplace.GrantItemType.Rebirth
end

function Shared_Marketplace.IsOfflineCashProduct(configKey: string): boolean
	local config = Shared_Marketplace.GetProduct(configKey)
	return config ~= nil and config.GrantItemType == Shared_Marketplace.GrantItemType.OfflineCash
end

function Shared_Marketplace.GetCatalogLoadOrder(): { string }
	local priorityIndex: { [string]: number } = {}
	for index, configKey in Shared_Marketplace.CatalogLoadPriority do
		priorityIndex[configKey] = index
	end

	local keys: { string } = {}
	for configKey in Shared_Marketplace.Products do
		table.insert(keys, configKey)
	end

	table.sort(keys, function(a, b)
		local priorityA = priorityIndex[a] or (1000 + string.len(a))
		local priorityB = priorityIndex[b] or (1000 + string.len(b))
		if priorityA ~= priorityB then
			return priorityA < priorityB
		end
		return a < b
	end)

	return keys
end

function Shared_Marketplace.GetTeleportHomeProductKey(rarity: string): string?
	if type(rarity) ~= "string" or rarity == "" then
		return nil
	end
	return `TeleportHome{rarity}`
end

function Shared_Marketplace.GetTeleportHomeRarity(configKey: string): string?
	local config = Shared_Marketplace.GetProduct(configKey)
	if not config or config.GrantItemType ~= Shared_Marketplace.GrantItemType.TeleportHome then
		return nil
	end
	if type(config.GrantConfigName) ~= "string" or config.GrantConfigName == "" then
		return nil
	end
	return config.GrantConfigName
end

function Shared_Marketplace.IsTeleportHomeProduct(configKey: string): boolean
	return Shared_Marketplace.GetTeleportHomeRarity(configKey) ~= nil
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

function Shared_Marketplace.IsLuckGamePass(configKey: string): boolean
	local config = Shared_Marketplace.GetProduct(configKey)
	return config ~= nil
		and config.ProductType == Shared_Marketplace.ProductType.GamePass
		and config.GrantItemType == Shared_Marketplace.GrantItemType.LuckMultiplier
end

function Shared_Marketplace.IsFastCollectGamePass(configKey: string): boolean
	local config = Shared_Marketplace.GetProduct(configKey)
	return config ~= nil
		and config.ProductType == Shared_Marketplace.ProductType.GamePass
		and config.GrantItemType == Shared_Marketplace.GrantItemType.FastCollect
end

function Shared_Marketplace.GetLuckMultiplier(configKey: string): number
	local config = Shared_Marketplace.GetProduct(configKey)
	if not config or config.GrantItemType ~= Shared_Marketplace.GrantItemType.LuckMultiplier then
		return 1
	end

	local weightLuck = tonumber(config.WeightLuckMultiplier)
	if weightLuck and weightLuck > 1 then
		return weightLuck
	end

	return math.max(1, tonumber(config.GrantAmount) or 1)
end

function Shared_Marketplace.GetWeightLuckMultiplierFromGamepasses(gamepasses: { [string]: any }?): number
	if type(gamepasses) ~= "table" then
		return 1
	end

	local bestMultiplier = 1
	for _, configKey in Shared_Marketplace.LuckGamepassConfigKeys do
		if gamepasses[configKey] == true then
			bestMultiplier = math.max(bestMultiplier, Shared_Marketplace.GetLuckMultiplier(configKey))
		end
	end

	return bestMultiplier
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
	if type(frameName) ~= "string" or frameName == "" then
		return nil
	end

	if Shared_Marketplace.IsGamePass(frameName) then
		return frameName
	end

	local configKey = Shared_Marketplace.GetConfigKeyForProductId(frameName)
	if configKey and Shared_Marketplace.IsGamePass(configKey) then
		return configKey
	end

	return nil
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
