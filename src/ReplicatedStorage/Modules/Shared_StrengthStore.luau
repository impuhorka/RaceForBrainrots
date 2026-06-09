local Shared_StrengthStore = {}

Shared_StrengthStore.DefaultStrength = 1
Shared_StrengthStore.PurchaseOptions = { 1, 5, 10 }

Shared_StrengthStore.Economy = {
	BaseCostPerPoint = 50,
	GrowthPerStrength = 1.07,
	RoundTo = 10,
}

local function roundToStep(value: number, step: number): number
	if step <= 1 then
		return math.max(1, math.floor(value + 0.5))
	end
	return math.max(step, math.floor(value / step + 0.5) * step)
end

function Shared_StrengthStore.IsValidPurchaseAmount(amount: number): boolean
	for _, option in Shared_StrengthStore.PurchaseOptions do
		if option == amount then
			return true
		end
	end
	return false
end

function Shared_StrengthStore.GetSinglePointCost(currentStrength: number): number
	local base = Shared_StrengthStore.Economy.BaseCostPerPoint
	local growth = Shared_StrengthStore.Economy.GrowthPerStrength
	local rounding = Shared_StrengthStore.Economy.RoundTo
	local strengthDelta = math.max(0, math.floor(currentStrength) - Shared_StrengthStore.DefaultStrength)
	local rawCost = base * (growth ^ strengthDelta)
	return roundToStep(rawCost, rounding)
end

function Shared_StrengthStore.GetPurchaseCost(currentStrength: number, amount: number): number
	local safeStrength = math.max(1, math.floor(currentStrength))
	local safeAmount = math.max(1, math.floor(amount))
	local totalCost = 0
	for index = 0, safeAmount - 1 do
		totalCost += Shared_StrengthStore.GetSinglePointCost(safeStrength + index)
	end
	return math.max(1, math.floor(totalCost + 0.5))
end

function Shared_StrengthStore.GetStrengthAfterPurchase(currentStrength: number, amount: number): number
	return math.max(1, math.floor(currentStrength) + math.max(1, math.floor(amount)))
end

return Shared_StrengthStore
