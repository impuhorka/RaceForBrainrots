local Shared_Rarities = {}

Shared_Rarities.Balance = {
	BaseIncome = {
		Common = { Min = 50, Max = 150 },
		Rare = { Min = 150, Max = 350 },
		Epic = { Min = 700, Max = 1300 },
		Legendary = { Min = 1000, Max = 1500 },
		Mythical = { Min = 1400, Max = 2100 },
		Secret = { Min = 2000, Max = 3000 },
		Divine = { Min = 2600, Max = 3900 },
		Superior = { Min = 3600, Max = 5400 },
	},
	MaxRequiredStrength = {
		Common = 4,
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

return Shared_Rarities
