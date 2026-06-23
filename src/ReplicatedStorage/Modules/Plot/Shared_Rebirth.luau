local Shared_PlotConfig = require(script.Parent.Shared_PlotConfig)

local Shared_Rebirth = {}

Shared_Rebirth.SlotUnlockPerRebirth = { 4, 4, 3, 3, 3, 2, 2, 2, 2, 2 }
Shared_Rebirth.SlotUnlockPerRebirthAfterFourth = 1

Shared_Rebirth.CashMultiplierPerRebirth = 0.5
Shared_Rebirth.SpeedCapPerRebirth = 50
Shared_Rebirth.StrengthCapPerRebirth = 50
Shared_Rebirth.BaseSpeedCap = 80
Shared_Rebirth.BaseStrengthCap = 100

Shared_Rebirth.Economy = {
	BaseCost = 250_000,
	GrowthPerRebirth = 5.75,
	CostAcceleration = 0.2,
	SecondRebirthCostMultiplier = 2.0,
	RoundTo = 25_000,
}

-- Robux tiers: cheap early rebirths (T1), mid wall (T2), late grind (T3).
Shared_Rebirth.RobuxTierByRebirthCount = {
	EasyMaxRebirth = 2,
	MidMaxRebirth = 8,
}

local function roundToStep(value: number, step: number): number
	if step <= 1 then
		return math.max(1, math.floor(value + 0.5))
	end
	return math.max(step, math.floor(value / step + 0.5) * step)
end

function Shared_Rebirth.GetRebirthCount(rebirths: any): number
	return math.max(0, math.floor(tonumber(rebirths) or 0))
end

function Shared_Rebirth.GetSlotUnlockBonus(rebirthCount: number): number
	local bonus = 0
	local tiers = Shared_Rebirth.SlotUnlockPerRebirth

	for index = 1, math.min(rebirthCount, #tiers) do
		bonus += tiers[index]
	end

	if rebirthCount > #tiers then
		bonus += (rebirthCount - #tiers) * Shared_Rebirth.SlotUnlockPerRebirthAfterFourth
	end

	return bonus
end

function Shared_Rebirth.GetMaxPlotSlots(rebirths: any): number
	local rebirthCount = Shared_Rebirth.GetRebirthCount(rebirths)
	local unlocked = Shared_PlotConfig.DefaultPlotSlots + Shared_Rebirth.GetSlotUnlockBonus(rebirthCount)
	return math.min(Shared_PlotConfig.MaxPlotSlots, unlocked)
end

function Shared_Rebirth.GetRebirthsRequiredForNextSlot(currentSlots: number, rebirths: any): number?
	if currentSlots >= Shared_PlotConfig.MaxPlotSlots then
		return nil
	end

	local rebirthCount = Shared_Rebirth.GetRebirthCount(rebirths)
	if currentSlots < Shared_Rebirth.GetMaxPlotSlots(rebirthCount) then
		return rebirthCount
	end

	for required = rebirthCount + 1, 200 do
		if Shared_Rebirth.GetMaxPlotSlots(required) > currentSlots then
			return required
		end
	end

	return nil
end

function Shared_Rebirth.GetCashMultiplier(rebirths: any): number
	local count = Shared_Rebirth.GetRebirthCount(rebirths)
	return 1 + count * Shared_Rebirth.CashMultiplierPerRebirth
end

function Shared_Rebirth.GetMaxSpeedCap(rebirths: any): number
	local count = Shared_Rebirth.GetRebirthCount(rebirths)
	return Shared_Rebirth.BaseSpeedCap + count * Shared_Rebirth.SpeedCapPerRebirth
end

function Shared_Rebirth.GetMaxStrengthCap(rebirths: any): number
	local count = Shared_Rebirth.GetRebirthCount(rebirths)
	return Shared_Rebirth.BaseStrengthCap + count * Shared_Rebirth.StrengthCapPerRebirth
end

function Shared_Rebirth.FormatMultiplier(rebirths: any): string
	local multiplier = Shared_Rebirth.GetCashMultiplier(rebirths)
	if multiplier == math.floor(multiplier) then
		return ("x%d"):format(multiplier)
	end
	return ("x%.1f"):format(multiplier)
end

function Shared_Rebirth.FormatCashLabel(rebirths: any): string
	return Shared_Rebirth.FormatMultiplier(rebirths) .. " Cash"
end

function Shared_Rebirth.GetCost(rebirths: any): number
	local count = Shared_Rebirth.GetRebirthCount(rebirths)
	local economy = Shared_Rebirth.Economy
	local acceleration = economy.CostAcceleration or 0
	local effectiveExponent = count * (1 + count * acceleration)
	local rawCost = economy.BaseCost * (economy.GrowthPerRebirth ^ effectiveExponent)
	if count >= 1 then
		rawCost *= economy.SecondRebirthCostMultiplier or 1
	end
	return roundToStep(rawCost, economy.RoundTo)
end

function Shared_Rebirth.GetRobuxTier(rebirths: any): number
	local count = Shared_Rebirth.GetRebirthCount(rebirths)
	local tiers = Shared_Rebirth.RobuxTierByRebirthCount
	if count <= (tiers.EasyMaxRebirth or 2) then
		return 1
	end
	if count <= (tiers.MidMaxRebirth or 5) then
		return 2
	end
	return 3
end

function Shared_Rebirth.GetRobuxProductConfigKey(rebirths: any): string
	return `RebirthT{Shared_Rebirth.GetRobuxTier(rebirths)}`
end

return Shared_Rebirth
