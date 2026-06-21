local Shared_Rarities = {}

Shared_Rarities.Balance = {
	BaseIncome = {
		Common = { Min = 35, Max = 50 },
		Rare = { Min = 350, Max = 500 },
		Epic = { Min = 5000, Max = 15000 },
		Legendary = { Min = 25000, Max = 50000 },
		Mythical = { Min = 60000, Max = 100000 },
		Secret = { Min = 100000, Max = 300000 },
		Divine = { Min = 500000, Max = 1500000 },
		Superior = { Min = 2500000, Max = 10000000 },
	},
	MaxRequiredStrength = {
		Common = 9,
		Rare = 23,
		Epic = 45,
		Legendary = 90,
		Mythical = 180,
		Secret = 360,
		Divine = 585,
		Superior = 900,
	},
	-- Minimum strength to pick up any lucky block from this rarity zone.
	MinPickupStrength = {
		Common = 1,
		Rare = 14,
		Epic = 30,
		Legendary = 58,
		Mythical = 117,
		Secret = 234,
		Divine = 380,
		Superior = 585,
	},
	-- Default carry weight (kg) for brainrots / rolls when no lucky-block origin is stored.
	DefaultCarryBaseWeight = {
		Common = 10,
		Rare = 25,
		Epic = 50,
		Legendary = 100,
		Mythical = 200,
		Secret = 400,
		Divine = 650,
		Superior = 1000,
	},
	PaybackMultiplier = {
		Common = 0.9,
		Rare = 1.05,
		Epic = 1.2,
		Legendary = 1.4,
		Mythical = 1.65,
		Secret = 2.0,
		Divine = 2.8,
		Superior = 3.5,
	},
}

Shared_Rarities.Data = {
	Common = {
		DisplayName = "Common",
		LayoutOrder = 1,

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 75)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 0)),
		}),
		GradientRotation = 90,

		Color = Color3.fromRGB(124, 255, 72),
	},
	Rare = {
		DisplayName = "Rare",
		LayoutOrder = 2,

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 245, 210)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(55, 125, 240)),
		}),
		GradientRotation = 90,

		Color = Color3.fromRGB(95, 194, 255),
	},
	Epic = {
		DisplayName = "Epic",
		LayoutOrder = 3,

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 175, 220)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 255)),
		}),
		GradientRotation = 90,

		Color = Color3.fromRGB(255, 99, 239),
	},
	Legendary = {
		DisplayName = "Legendary",
		LayoutOrder = 4,

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 35, 0)),
		}),
		GradientRotation = 90,

		Color = Color3.fromRGB(255, 107, 107),
	},
	Mythical = {
		DisplayName = "Mythical",
		LayoutOrder = 5,

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 235, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 40, 0)),
		}),
		GradientRotation = 90,

		Color = Color3.fromRGB(255, 123, 71),
	},
	Secret = {
		DisplayName = "Secret",
		LayoutOrder = 6,

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 40)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(98, 44, 44)),
		}),
		GradientRotation = 90,

		Color = Color3.fromRGB(130, 45, 45),
	},
	Divine = {
		DisplayName = "Divine",
		LayoutOrder = 7,

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 240, 230)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 0, 255)),
		}),
		GradientRotation = 90,

		Color = Color3.fromRGB(249, 212, 255),
	},
	Superior = {
		DisplayName = "SUPERIOR",
		LayoutOrder = 8,

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 255, 200)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(245, 0, 210)),
		}),
		GradientRotation = 90,

		Color = Color3.fromRGB(255, 253, 164),
	},
}

function Shared_Rarities.GetBaseIncomeRange(rarity: string): { Min: number, Max: number }?
	local balance = Shared_Rarities.Balance
	return balance and balance.BaseIncome and balance.BaseIncome[rarity]
end

function Shared_Rarities.GetPaybackMultiplier(rarity: string): number
	local balance = Shared_Rarities.Balance
	local mult = balance and balance.PaybackMultiplier and balance.PaybackMultiplier[rarity]
	return mult or 1
end

function Shared_Rarities.GetMaxRequiredStrength(rarity: string): number?
	local balance = Shared_Rarities.Balance
	local value = balance and balance.MaxRequiredStrength and balance.MaxRequiredStrength[rarity]
	if type(value) == "number" and value > 0 then
		return math.floor(value)
	end
	return nil
end

function Shared_Rarities.GetMinPickupStrength(rarity: string): number?
	local balance = Shared_Rarities.Balance
	local value = balance and balance.MinPickupStrength and balance.MinPickupStrength[rarity]
	if type(value) == "number" and value > 0 then
		return math.floor(value)
	end
	return nil
end

function Shared_Rarities.GetDefaultCarryBaseWeight(rarity: string): number
	local balance = Shared_Rarities.Balance
	local value = balance and balance.DefaultCarryBaseWeight and balance.DefaultCarryBaseWeight[rarity]
	if type(value) == "number" and value > 0 then
		return value
	end
	return 15
end

return Shared_Rarities
