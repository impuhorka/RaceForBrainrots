local Modifiers = {}

Modifiers.Data = {
	Normal = {
		DisplayName = "Normal",
		IncomeMultiplier = 1.0,
		UpgradeCostMultiplier = 1.0,

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 235, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 40, 0)),
		}),
		GradientRotation = 90,
	},
	Golden = {
		DisplayName = "Golden",
		IncomeMultiplier = 1.5,
		UpgradeCostMultiplier = 1.1,

		ColorGradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 235, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 40, 0)),
		}),
		GradientRotation = 90,
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

return Modifiers
