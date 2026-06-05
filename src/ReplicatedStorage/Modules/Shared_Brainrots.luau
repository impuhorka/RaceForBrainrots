local Shared_Rarities = require(script.Parent.Utilities.Shared_Rarities)
local Shared_Modifiers = require(script.Parent.Utilities.Shared_Modifiers)

local Brainrots = {}

Brainrots.MaxLevel = 150

Brainrots.Balance = {
	IncomeLevelMultiplier = 1.25,
	MinPlotScale = 0.5,
	MaxPlotScale = 2,
	UpgradePayback = {
		BaseSeconds = 15,
		PerLevelMultiplier = 1.04,
		StepLevels = 10,
		StepMultiplierPhase1 = 1.5,
		StepMultiplierPhase2 = 2,
		Phase1StepCount = 8,
	},
	SellWorthSeconds = 10,
}

Brainrots.Data = {
	ChillinChili = {
		DispalayName = "Chillin Chili",
		Rarity = "Common",
		PowerTier = 5,
	},
	FluriFlura = {
		DispalayName = "Fluri Flura",
		Rarity = "Rare",
		PowerTier = 5,
	},
	BrrBrrPatapim = {
		DispalayName = "BrrBrr Patapim",
		Rarity = "Epic",
		PowerTier = 5,
	},
	FrigoCamelo = {
		DispalayName = "Frigo Camelo",
		Rarity = "Legendary",
		PowerTier = 5,
	},
	GirafaCelestre = {
		DispalayName = "Girafa Celestre",
		Rarity = "Mythical",
		PowerTier = 5,
	},
	PipiPotato = {
		DispalayName = "Pipi Potato",
		Rarity = "Secret",
		PowerTier = 5,
	},
	SixSeven = {
		DispalayName = "Six Seven",
		Rarity = "Divine",
		PowerTier = 5,
	},
	TatatataSahur = {
		DispalayName = "Tatatata Sahur",
		Rarity = "Superior",
		PowerTier = 5,
	},
}

local function roundEconomy(value: number): number
	if value <= 0 then
		return 0
	end
	if value < 10 then
		return math.floor(value + 0.5)
	end

	local magnitude = math.floor(math.log10(value))
	local divisor = 10 ^ magnitude
	local firstDigit = math.floor(value / divisor)

	local step
	if firstDigit <= 2 then
		step = divisor * 0.1
	elseif firstDigit <= 5 then
		step = divisor * 0.5
	else
		step = divisor
	end

	return math.floor(value / step + 0.5) * step
end

local function getRawCashPerSecond(configName: string, level: number, modifier: string): number
	local baseCps = Brainrots.GetBaseCashPerSecond(configName)
	local modMultiplier = Shared_Modifiers.GetIncomeMultiplier(modifier)
	local incomeLevelMult = Brainrots.Balance.IncomeLevelMultiplier or 1

	local safeLevel = math.max(1, level or 1)
	local levelFactor = incomeLevelMult ^ (safeLevel - 1)

	return baseCps * levelFactor * modMultiplier
end

function Brainrots.GetDisplayName(configName: string): string
	local config = Brainrots.Data[configName]
	if not config then
		return configName
	end
	return config.DispalayName or config.DisplayName or configName
end

function Brainrots.GetScaleForLevel(level: number): number
	local minScale = Brainrots.Balance.MinPlotScale or 0.5
	local maxScale = Brainrots.Balance.MaxPlotScale or 2
	local maxLevel = Brainrots.MaxLevel or 150
	local safeLevel = math.clamp(level or 1, 1, maxLevel)

	if maxLevel <= 1 then
		return minScale
	end

	local alpha = (safeLevel - 1) / (maxLevel - 1)
	return minScale + (maxScale - minScale) * alpha
end

function Brainrots.GetBaseCashPerSecond(configName: string): number
	local config = Brainrots.Data[configName]
	if not config then
		return 0
	end

	local rarityRange = Shared_Rarities.GetBaseIncomeRange(config.Rarity)
	if not rarityRange then
		return 0
	end

	local powerTier = math.clamp(config.PowerTier or 5, 1, 10)
	local minIncome = rarityRange.Min
	local maxIncome = rarityRange.Max
	local cashPerSecond = minIncome + ((maxIncome - minIncome) * (powerTier - 1) / 9)

	return math.floor(cashPerSecond)
end

function Brainrots.GetCashPerSecond(configName: string, level: number, modifier: string): number
	return roundEconomy(getRawCashPerSecond(configName, level, modifier))
end

function Brainrots.GetUpgradePaybackSeconds(level: number): number
	local cfg = Brainrots.Balance.UpgradePayback
	local safeLevel = math.max(1, level or 1)
	local stepLevels = cfg.StepLevels or 10
	local steps = math.floor((safeLevel - 1) / stepLevels)

	local base = cfg.BaseSeconds or 15
	local perLevelMult = cfg.PerLevelMultiplier or 1.04
	local phase1Count = cfg.Phase1StepCount or 8
	local mult1 = cfg.StepMultiplierPhase1 or 1.5
	local mult2 = cfg.StepMultiplierPhase2 or 2

	local stepFactor
	if steps <= phase1Count then
		stepFactor = mult1 ^ steps
	else
		stepFactor = mult1 ^ phase1Count * mult2 ^ (steps - phase1Count)
	end

	local levelFactor = perLevelMult ^ (safeLevel - 1)
	return base * levelFactor * stepFactor
end

function Brainrots.GetUpgradeCost(configName: string, currentLevel: number, modifier: string): number
	local config = Brainrots.Data[configName]
	if not config then
		return 0
	end

	local safeLevel = math.max(1, currentLevel or 1)
	if safeLevel >= Brainrots.MaxLevel then
		return 0
	end

	local incomeNow = getRawCashPerSecond(configName, safeLevel, modifier)
	local incomeNext = getRawCashPerSecond(configName, safeLevel + 1, modifier)
	local delta = math.max(0, incomeNext - incomeNow)

	local paybackSeconds = Brainrots.GetUpgradePaybackSeconds(safeLevel)
	paybackSeconds *= Shared_Rarities.GetPaybackMultiplier(config.Rarity)
	paybackSeconds *= Shared_Modifiers.GetUpgradeCostMultiplier(modifier)

	return roundEconomy(delta * paybackSeconds)
end

function Brainrots.GetSellWorth(configName: string, level: number, modifier: string): number
	if not Brainrots.Data[configName] then
		return 0
	end

	local income = getRawCashPerSecond(configName, level, modifier)
	local secondsWorth = Brainrots.Balance.SellWorthSeconds or 10
	return roundEconomy(income * secondsWorth)
end

return Brainrots
