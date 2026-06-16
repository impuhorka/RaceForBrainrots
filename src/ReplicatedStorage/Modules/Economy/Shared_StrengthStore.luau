local Shared_StatStore = require(script.Parent.Shared_StatStore)

local Shared_Carry = require(script.Parent.Shared_Carry)

local Shared_StrengthStore = Shared_StatStore.create({
	DefaultValue = 1,
	PurchaseOptions = { 1, 5, 10 },
	Economy = {
		BaseCostPerPoint = 10,
		GrowthPerPoint = 1.018,
		SoftCapStrength = 100,
		GrowthPerPointAfterSoftCap = 1.005,
		RoundTo = 50,
	},
})

Shared_StrengthStore.DefaultStrength = Shared_StrengthStore.DefaultValue
Shared_StrengthStore.FreeStrengthPoints = 3

local function roundToStep(value: number, step: number): number
	if step <= 1 then
		return math.max(1, math.floor(value + 0.5))
	end
	return math.max(step, math.floor(value / step + 0.5) * step)
end

local function getPaidSinglePointCost(currentValue: number): number
	local economy = Shared_StrengthStore.Economy
	local softCap = economy.SoftCapStrength or Shared_StrengthStore.DefaultValue
	local safeValue = math.max(Shared_StrengthStore.DefaultValue, math.floor(currentValue))
	local valueDelta = math.max(0, safeValue - Shared_StrengthStore.DefaultValue)
	local softCapDelta = math.max(0, softCap - Shared_StrengthStore.DefaultValue)

	local rawCost: number
	if valueDelta <= softCapDelta then
		rawCost = economy.BaseCostPerPoint * (economy.GrowthPerPoint ^ valueDelta)
	else
		local costAtSoftCap = economy.BaseCostPerPoint * (economy.GrowthPerPoint ^ softCapDelta)
		local excessDelta = valueDelta - softCapDelta
		local afterGrowth = economy.GrowthPerPointAfterSoftCap or economy.GrowthPerPoint
		rawCost = costAtSoftCap * (afterGrowth ^ excessDelta)
	end

	return roundToStep(rawCost, economy.RoundTo)
end

function Shared_StrengthStore.GetRemainingFreeStrengthPoints(freePointsUsed: number?): number
	local used = math.clamp(math.floor(freePointsUsed or 0), 0, Shared_StrengthStore.FreeStrengthPoints)
	return Shared_StrengthStore.FreeStrengthPoints - used
end

function Shared_StrengthStore.IsFreeStrengthPoint(freePointsUsed: number?): boolean
	return Shared_StrengthStore.GetRemainingFreeStrengthPoints(freePointsUsed) > 0
end

function Shared_StrengthStore.GetFreePointsInPurchase(currentValue: number, amount: number, freePointsUsed: number?): number
	local safeAmount = math.max(1, math.floor(amount))
	local remaining = Shared_StrengthStore.GetRemainingFreeStrengthPoints(freePointsUsed)
	return math.min(safeAmount, remaining)
end

function Shared_StrengthStore.GetSinglePointCost(currentValue: number, freePointsUsed: number?): number
	if Shared_StrengthStore.IsFreeStrengthPoint(freePointsUsed) then
		return 0
	end
	return getPaidSinglePointCost(currentValue)
end

function Shared_StrengthStore.GetPurchaseCost(currentValue: number, amount: number, freePointsUsed: number?): number
	local safeValue = math.max(Shared_StrengthStore.DefaultValue, math.floor(currentValue))
	local safeAmount = math.max(1, math.floor(amount))
	local used = math.clamp(math.floor(freePointsUsed or 0), 0, Shared_StrengthStore.FreeStrengthPoints)
	local totalCost = 0

	for index = 0, safeAmount - 1 do
		if used < Shared_StrengthStore.FreeStrengthPoints then
			used += 1
		else
			totalCost += getPaidSinglePointCost(safeValue + index)
		end
	end

	return math.max(0, math.floor(totalCost + 0.5))
end

function Shared_StrengthStore.GetStrengthAfterPurchase(currentStrength: number, amount: number): number
	return Shared_StrengthStore.GetValueAfterPurchase(currentStrength, amount)
end

function Shared_StrengthStore.GetMaxCarryWeight(strength: number): number
	return Shared_Carry.GetMaxCarryWeight(strength)
end

return Shared_StrengthStore
