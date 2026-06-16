local Shared_Rarities = require(script.Parent.Shared_Rarities)
local Shared_Modifiers = require(script.Parent.Shared_Modifiers)
local Shared_Weight = require(script.Parent.Shared_Weight)

local Brainrots = {}

Brainrots.MaxLevel = 150
Brainrots.UpgradesEnabled = false

Brainrots.DefaultBaseWeight = 15

Brainrots.Balance = {
	IncomeLevelMultiplier = 1.25,
	MinPlotScale = 0.5,
	MaxPlotScale = 2,
	UpgradePayback = {
		BaseSeconds = 36,
		PerLevelMultiplier = 1.05,
		StepLevels = 5,
		StepMultiplierPhase1 = 1.28,
		StepMultiplierPhase2 = 1.55,
		Phase1StepCount = 20,
	},
	SellWorthSeconds = 30,
}

-- PowerTier (1-10) sets base $/s inside each rarity band from Shared_Rarities.BaseIncome.
Brainrots.Data = {

	-- Common
	BananitoDelfinito = { DispalayName = "Bananito Delfinito", Rarity = "Common", PowerTier = 1 },
	EspressoSignora = { DispalayName = "Espresso Signora", Rarity = "Common", PowerTier = 2 },
	ChillinChili = { DispalayName = "Chillin Chili", Rarity = "Common", PowerTier = 3 },
	GanganzelliTrulala = { DispalayName = "Ganganzelli Trulala", Rarity = "Common", PowerTier = 3 },
	GangsterFootera = { DispalayName = "Gangster Footera", Rarity = "Common", PowerTier = 3 },
	Garamararam = { DispalayName = "Garamararam", Rarity = "Common", PowerTier = 4 },
	LiriliLarila = { DispalayName = "Lirili Larila", Rarity = "Common", PowerTier = 5 },
	NuclearoDinosauro = { DispalayName = "Nuclearo Dinosauro", Rarity = "Common", PowerTier = 6 },
	Pakrahmatmatina = { DispalayName = "Pakrahmatmatina", Rarity = "Common", PowerTier = 7 },
	TralalitaTralala = { DispalayName = "Tralalita Tralala", Rarity = "Common", PowerTier = 8 },
	TrippiTroppi = { DispalayName = "Trippi Troppi", Rarity = "Common", PowerTier = 8 },
	Trollface = { DispalayName = "Trollface", Rarity = "Common", PowerTier = 9 },
	TrulimeroTrulicina = { DispalayName = "Trulimero Trulicina", Rarity = "Common", PowerTier = 10 },

	-- Rare
	BalerinaCapucina = { DispalayName = "Balerina Capucina", Rarity = "Rare", PowerTier = 1 },
	BanditoBobrito = { DispalayName = "Bandito Bobrito", Rarity = "Rare", PowerTier = 2 },
	BrrBicusDicus = { DispalayName = "Brr Bicus Dicus", Rarity = "Rare", PowerTier = 3 },
	ChefCrabracadabra = { DispalayName = "Chef Crabracadabra", Rarity = "Rare", PowerTier = 4 },
	FluriFlura = { DispalayName = "Fluri Flura", Rarity = "Rare", PowerTier = 4 },
	EsokSekolah = { DispalayName = "Esok Sekolah", Rarity = "Rare", PowerTier = 5 },
	Lerulerulerule = { DispalayName = "Lerulerulerule", Rarity = "Rare", PowerTier = 6 },
	OdinDinDinDun = { DispalayName = "Odin Din Din Dun", Rarity = "Rare", PowerTier = 7 },
	Tralaledon = { DispalayName = "Tralaledon", Rarity = "Rare", PowerTier = 8 },
	TricTracBarabum = { DispalayName = "Tric Trac Barabum", Rarity = "Rare", PowerTier = 9 },
	TrippiTroppiTroppaTrippa = { DispalayName = "Trippi Troppi Troppa Trippa", Rarity = "Rare", PowerTier = 10 },

	-- Epic
	BlueberrinniOctopusini = { DispalayName = "Blueberrinni Octopusini", Rarity = "Epic", PowerTier = 1 },
	CavalloVirtuoso = { DispalayName = "Cavallo Virtuoso", Rarity = "Epic", PowerTier = 2 },
	SmurfCat = { DispalayName = "Smurf Cat", Rarity = "Epic", PowerTier = 4 },
	BrrBrrPatapim = { DispalayName = "Brr Brr Patapim", Rarity = "Epic", PowerTier = 5 },
	TigroligreFrutonni = { DispalayName = "Tigroligre Frutonni", Rarity = "Epic", PowerTier = 6 },
	TimCheese = { DispalayName = "Tim Cheese", Rarity = "Epic", PowerTier = 7 },
	TriplitoTralaleritos = { DispalayName = "Triplito Tralaleritos", Rarity = "Epic", PowerTier = 8 },
	ZibraZubraZibralini = { DispalayName = "Zibra Zubra Zibralini", Rarity = "Epic", PowerTier = 10 },

	-- Legendary
	AgarriniLaPallini = { DispalayName = "Agarrini La Pallini", Rarity = "Legendary", PowerTier = 1 },
	CappuccinoAssassino = { DispalayName = "Cappuccino Assassino", Rarity = "Legendary", PowerTier = 3 },
	GorilloWatermelondrillo = { DispalayName = "Gorillo Watermelondrillo", Rarity = "Legendary", PowerTier = 5 },
	FrigoCamelo = { DispalayName = "Frigo Camelo", Rarity = "Legendary", PowerTier = 6 },
	LioneloCactuseli = { DispalayName = "Lionelo Cactuseli", Rarity = "Legendary", PowerTier = 6 },
	Mateo = { DispalayName = "Mateo", Rarity = "Legendary", PowerTier = 8 },
	PandacciniBananini = { DispalayName = "Pandaccini Bananini", Rarity = "Legendary", PowerTier = 10 },

	-- Mythical
	["69"] = { DispalayName = "69", Rarity = "Mythical", PowerTier = 1 },
	ChicleteiraBicicleteira = { DispalayName = "Chicleteira Bicicleteira", Rarity = "Mythical", PowerTier = 3 },
	PotHotspot = { DispalayName = "Pot Hotspot", Rarity = "Mythical", PowerTier = 6 },
	GirafaCelestre = { DispalayName = "Girafa Celestre", Rarity = "Mythical", PowerTier = 7 },
	StrawberrelliFlamingelli = { DispalayName = "Strawberrelli Flamingelli", Rarity = "Mythical", PowerTier = 8 },
	TralaleroTralala = { DispalayName = "Tralalero Tralala", Rarity = "Mythical", PowerTier = 10 },

	-- Secret
	ChicleteirinaBicicleteirina = { DispalayName = "Chicleteirina Bicicleteirina", Rarity = "Secret", PowerTier = 1 },
	DragonCannelloni = { DispalayName = "Dragon Cannelloni", Rarity = "Secret", PowerTier = 6 },
	PipiPotato = { DispalayName = "Pipi Potato", Rarity = "Secret", PowerTier = 8 },
	TorrtuginniDragonfrutini = { DispalayName = "Torrtuginni Dragonfrutini", Rarity = "Secret", PowerTier = 10 },

	-- Divine
	Pakrahmatmamat = { DispalayName = "Pakrahmatmamat", Rarity = "Divine", PowerTier = 5 },
	SixSeven = { DispalayName = "Six Seven", Rarity = "Divine", PowerTier = 9 },

	-- Superior
	TatatataSahur = { DispalayName = "Tatatata Sahur", Rarity = "Superior", PowerTier = 10 },
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

function Brainrots.AreUpgradesEnabled(): boolean
	return Brainrots.UpgradesEnabled == true
end

function Brainrots.GetIncomeLevel(level: number): number
	if not Brainrots.AreUpgradesEnabled() then
		return 1
	end
	return math.max(1, level or 1)
end

local function getRawCashPerSecond(configName: string, level: number, modifier: string): number
	local baseCps = Brainrots.GetBaseCashPerSecond(configName)
	local modMultiplier = Shared_Modifiers.GetIncomeMultiplier(modifier)
	local incomeLevelMult = Brainrots.Balance.IncomeLevelMultiplier or 1

	local safeLevel = Brainrots.GetIncomeLevel(level)
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

function Brainrots.GetPowerTier(configName: string): number
	local config = Brainrots.Data[configName]
	if not config then
		return 5
	end
	return math.clamp(config.PowerTier or 5, 1, 10)
end

function Brainrots.GetConfigNamesForRarity(rarity: string): { string }
	local configNames: { string } = {}
	for configName, config in Brainrots.Data do
		if config.Rarity == rarity then
			table.insert(configNames, configName)
		end
	end

	table.sort(configNames, function(a, b)
		local tierA = Brainrots.GetPowerTier(a)
		local tierB = Brainrots.GetPowerTier(b)
		if tierA ~= tierB then
			return tierA < tierB
		end
		return Brainrots.GetDisplayName(a) < Brainrots.GetDisplayName(b)
	end)

	return configNames
end

function Brainrots.GetDefaultBaseWeight(_configName: string?): number
	return Brainrots.DefaultBaseWeight or 15
end

function Brainrots.GetScaleForWeight(baseWeight: number?, rolledWeight: number?): number
	local base, rolled = Shared_Weight.ResolveBrainrotWeights(
		{ BaseWeight = baseWeight, Weight = rolledWeight },
		""
	)
	return Shared_Weight.GetBrainrotScaleMultiplier(base, rolled)
end

function Brainrots.GetScaleForLevel(level: number): number
	return Brainrots.GetScaleForWeight(Brainrots.DefaultBaseWeight, Brainrots.DefaultBaseWeight)
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

	local powerTier = Brainrots.GetPowerTier(configName)
	local minIncome = rarityRange.Min
	local maxIncome = rarityRange.Max
	local cashPerSecond = minIncome + ((maxIncome - minIncome) * (powerTier - 1) / 9)

	return math.floor(cashPerSecond)
end

function Brainrots.GetCashPerSecond(
	configName: string,
	level: number,
	modifier: string,
	baseWeight: number?,
	rolledWeight: number?
): number
	local rawIncome = getRawCashPerSecond(configName, level, modifier)
	local base, rolled = Shared_Weight.ResolveBrainrotWeights(
		{ BaseWeight = baseWeight, Weight = rolledWeight },
		configName
	)
	local weightMult = Shared_Weight.GetIncomeMultiplier(base, rolled)
	return math.max(0, math.floor(rawIncome * weightMult + 0.5))
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

function Brainrots.GetUpgradeCost(
	configName: string,
	currentLevel: number,
	modifier: string,
	baseWeight: number?,
	rolledWeight: number?
): number
	if not Brainrots.AreUpgradesEnabled() then
		return 0
	end

	local config = Brainrots.Data[configName]
	if not config then
		return 0
	end

	local safeLevel = math.max(1, currentLevel or 1)
	if safeLevel >= Brainrots.MaxLevel then
		return 0
	end

	local resolvedModifier = modifier or "Normal"
	local upgradeIncomeInfluence = Shared_Modifiers.GetUpgradeIncomeInfluence(resolvedModifier)
	local incomeNow = getRawCashPerSecond(configName, safeLevel, resolvedModifier)
	local incomeNext = getRawCashPerSecond(configName, safeLevel + 1, resolvedModifier)
	local normalIncomeNow = getRawCashPerSecond(configName, safeLevel, "Normal")
	local normalIncomeNext = getRawCashPerSecond(configName, safeLevel + 1, "Normal")
	local dampenedIncomeNow = normalIncomeNow + (incomeNow - normalIncomeNow) * upgradeIncomeInfluence
	local dampenedIncomeNext = normalIncomeNext + (incomeNext - normalIncomeNext) * upgradeIncomeInfluence
	local base, rolled = Shared_Weight.ResolveBrainrotWeights(
		{ BaseWeight = baseWeight, Weight = rolledWeight },
		configName
	)
	local weightMult = Shared_Weight.GetIncomeMultiplier(base, rolled)
	incomeNow = math.max(0, math.floor(dampenedIncomeNow * weightMult + 0.5))
	incomeNext = math.max(0, math.floor(dampenedIncomeNext * weightMult + 0.5))
	local delta = math.max(0, incomeNext - incomeNow)

	local paybackSeconds = Brainrots.GetUpgradePaybackSeconds(safeLevel)
	paybackSeconds *= Shared_Rarities.GetPaybackMultiplier(config.Rarity)
	paybackSeconds *= Shared_Modifiers.GetUpgradeCostMultiplier(resolvedModifier)

	return roundEconomy(delta * paybackSeconds)
end

function Brainrots.GetSellWorth(
	configName: string,
	level: number,
	modifier: string,
	baseWeight: number?,
	rolledWeight: number?
): number
	if not Brainrots.Data[configName] then
		return 0
	end

	local income = Brainrots.GetCashPerSecond(configName, level, modifier, baseWeight, rolledWeight)
	local secondsWorth = Brainrots.Balance.SellWorthSeconds or 30
	return roundEconomy(income * secondsWorth)
end

return Brainrots
