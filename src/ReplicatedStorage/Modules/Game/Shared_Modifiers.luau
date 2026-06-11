local Modifiers = {}

Modifiers.Data = {
	Normal = {
		DisplayName = "Normal",
		LayoutOrder = 1,
		IncomeMultiplier = 1.0,
		UpgradeCostMultiplier = 1.0,

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(178, 178, 178)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(73, 73, 73)),
		}),
		GradientRotation = 90,
	},
	Golden = {
		DisplayName = "Golden",
		LayoutOrder = 2,
		IncomeMultiplier = 1.5,
		UpgradeCostMultiplier = 1.02,

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 125, 15)),
		}),
		GradientRotation = 90,
	},
	Diamond = {
		DisplayName = "Diamond",
		LayoutOrder = 3,
		IncomeMultiplier = 2.0,
		UpgradeCostMultiplier = 1.04,

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 240, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 150, 255)),
		}),
		GradientRotation = 90,
	},
	Galaxy = {
		DisplayName = "Galaxy",
		LayoutOrder = 4,
		IncomeMultiplier = 2.5,
		UpgradeCostMultiplier = 1.06,

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 150, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 0, 255)),
		}),
		GradientRotation = 90,
	},
	Lava = {
		DisplayName = "Lava",
		LayoutOrder = 5,
		IncomeMultiplier = 3.0,
		UpgradeCostMultiplier = 1.08,

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 140, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 0, 0)),
		}),
		GradientRotation = 90,
	},
	Rainbow = {
		DisplayName = "Rainbow",
		LayoutOrder = 6,
		IncomeMultiplier = 3.5,
		UpgradeCostMultiplier = 1.1,

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(.2, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(.4, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(.6, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(.8, Color3.fromRGB(255, 55, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
		}),
		GradientRotation = 0,
	},
}

function Modifiers.GetIncomeMultiplier(modifier: string): number
	local config = Modifiers.Data[modifier or "Normal"]
	return config and config.IncomeMultiplier or 1
end

function Modifiers.GetUpgradeCostMultiplier(modifier: string): number
	local config = Modifiers.Data[modifier or "Normal"]
	return config and config.UpgradeCostMultiplier or 1
end

-- Only part of modifier income bonus affects upgrade cost (income still uses full multiplier).
local UPGRADE_COST_INCOME_INFLUENCE = 0.35

function Modifiers.GetUpgradeIncomeInfluence(modifier: string): number
	local incomeMultiplier = Modifiers.GetIncomeMultiplier(modifier)
	return 1 + (incomeMultiplier - 1) * UPGRADE_COST_INCOME_INFLUENCE
end

return Modifiers
