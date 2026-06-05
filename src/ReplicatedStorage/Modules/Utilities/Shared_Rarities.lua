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
	PaybackMultiplier = {
		Common = 1.0,
		Rare = 1.25,
		Epic = 1.5,
		Legendary = 1.75,
		Mythical = 2.0,
		Secret = 2.5,
		Divine = 4.0,
		Superior = 5.0,
	},
}

Shared_Rarities.Data = {
	Common = {
		DisplayName = "Common",

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 75)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 0)),
		}),
		GradientRotation = 90,

		Color = Color3.fromRGB(124, 255, 72),
	},
	Rare = {
		DisplayName = "Rare",

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 245, 210)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(55, 125, 240)),
		}),
		GradientRotation = 90,

		Color = Color3.fromRGB(95, 194, 255),
	},
	Epic = {
		DisplayName = "Epic",

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 175, 220)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 255)),
		}),
		GradientRotation = 90,

		Color = Color3.fromRGB(255, 99, 239),
	},
	Legendary = {
		DisplayName = "Legendary",

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 35, 0)),
		}),
		GradientRotation = 90,

		Color = Color3.fromRGB(255, 107, 107),
	},
	Mythical = {
		DisplayName = "Mythical",

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 235, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 40, 0)),
		}),
		GradientRotation = 90,

		Color = Color3.fromRGB(255, 123, 71),
	},
	Secret = {
		DisplayName = "Secret",

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 40)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 5, 0)),
		}),
		GradientRotation = 90,

		Color = Color3.fromRGB(130, 45, 45),
	},
	Divine = {
		DisplayName = "Divine",

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

return Shared_Rarities
