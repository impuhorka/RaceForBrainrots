local Shared_SpeedStore = {}

Shared_SpeedStore.DefaultSpeed = 16
Shared_SpeedStore.PurchaseOptions = { 1, 5, 10 }

Shared_SpeedStore.Economy = {
	BaseCostPerPoint = 50,
	GrowthPerSpeed = 1.07,
	RoundTo = 10,
}

local function roundToStep(value: number, step: number): number
	if step <= 1 then
		return math.max(1, math.floor(value + 0.5))
	end
	return math.max(step, math.floor(value / step + 0.5) * step)
end

function Shared_SpeedStore.IsValidPurchaseAmount(amount: number): boolean
	for _, option in Shared_SpeedStore.PurchaseOptions do
		if option == amount then
			return true
		end
	end
	return false
end

function Shared_SpeedStore.GetSinglePointCost(currentSpeed: number): number
	local base = Shared_SpeedStore.Economy.BaseCostPerPoint
	local growth = Shared_SpeedStore.Economy.GrowthPerSpeed
	local rounding = Shared_SpeedStore.Economy.RoundTo
	local speedDelta = math.max(0, math.floor(currentSpeed) - Shared_SpeedStore.DefaultSpeed)
	local rawCost = base * (growth ^ speedDelta)
	return roundToStep(rawCost, rounding)
end

function Shared_SpeedStore.GetPurchaseCost(currentSpeed: number, amount: number): number
	local safeSpeed = math.max(1, math.floor(currentSpeed))
	local safeAmount = math.max(1, math.floor(amount))
	local totalCost = 0
	for index = 0, safeAmount - 1 do
		totalCost += Shared_SpeedStore.GetSinglePointCost(safeSpeed + index)
	end
	return math.max(1, math.floor(totalCost + 0.5))
end

function Shared_SpeedStore.GetSpeedAfterPurchase(currentSpeed: number, amount: number): number
	return math.max(1, math.floor(currentSpeed) + math.max(1, math.floor(amount)))
end

return Shared_SpeedStore
