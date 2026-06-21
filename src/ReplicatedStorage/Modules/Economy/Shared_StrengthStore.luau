local Shared_StatStore = require(script.Parent.Shared_StatStore)

local Shared_Carry = require(script.Parent.Shared_Carry)
local Shared_Rebirth = require(script.Parent.Parent.Plot.Shared_Rebirth)

local Shared_StrengthStore = Shared_StatStore.create({
	DefaultValue = 1,
	PurchaseOptions = { 1, 5, 10 },
	Economy = {
		-- Scaled to match speed store / plot income (was base 22 — showed $50 in mid-game).
		BaseCostPerPoint = 5000,
		GrowthPerPoint = 1.046,
		SoftCapStrength = 100,
		GrowthPerPointAfterSoftCap = 1.004,
		RoundTo = 100,
	},
})

Shared_StrengthStore.DefaultStrength = Shared_StrengthStore.DefaultValue
Shared_StrengthStore.FreeStrengthPoints = 3

export type PurchaseContext = {
	freePointsUsed: number?,
	rebirths: number?,
}

local function resolvePurchaseContext(
	freePointsUsedOrContext: number | PurchaseContext?,
	rebirths: number?
): (number, number)
	if type(freePointsUsedOrContext) == "table" then
		return math.clamp(
			math.floor(freePointsUsedOrContext.freePointsUsed or 0),
			0,
			Shared_StrengthStore.FreeStrengthPoints
		), Shared_Rebirth.GetRebirthCount(freePointsUsedOrContext.rebirths)
	end

	return math.clamp(math.floor(freePointsUsedOrContext or 0), 0, Shared_StrengthStore.FreeStrengthPoints),
		Shared_Rebirth.GetRebirthCount(rebirths)
end

function Shared_StrengthStore.CanUseFreeStrengthPoints(rebirths: any): boolean
	return Shared_Rebirth.GetRebirthCount(rebirths) <= 0
end

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

function Shared_StrengthStore.GetRemainingFreeStrengthPoints(
	freePointsUsed: number?,
	rebirths: any?
): number
	if not Shared_StrengthStore.CanUseFreeStrengthPoints(rebirths) then
		return 0
	end

	local used = math.clamp(math.floor(freePointsUsed or 0), 0, Shared_StrengthStore.FreeStrengthPoints)
	return Shared_StrengthStore.FreeStrengthPoints - used
end

function Shared_StrengthStore.IsFreeStrengthPoint(freePointsUsed: number?, rebirths: any?): boolean
	return Shared_StrengthStore.GetRemainingFreeStrengthPoints(freePointsUsed, rebirths) > 0
end

function Shared_StrengthStore.GetFreePointsInPurchase(
	currentValue: number,
	amount: number,
	freePointsUsed: number?,
	rebirths: any?
): number
	local safeAmount = math.max(1, math.floor(amount))
	local remaining = Shared_StrengthStore.GetRemainingFreeStrengthPoints(freePointsUsed, rebirths)
	return math.min(safeAmount, remaining)
end

function Shared_StrengthStore.GetSinglePointCost(
	currentValue: number,
	freePointsUsed: number?,
	rebirths: any?
): number
	if Shared_StrengthStore.IsFreeStrengthPoint(freePointsUsed, rebirths) then
		return 0
	end
	return getPaidSinglePointCost(currentValue)
end

function Shared_StrengthStore.GetPurchaseCost(
	currentValue: number,
	amount: number,
	freePointsUsedOrContext: number | PurchaseContext?,
	rebirths: number?
): number
	local freePointsUsed, resolvedRebirths = resolvePurchaseContext(freePointsUsedOrContext, rebirths)
	local safeValue = math.max(Shared_StrengthStore.DefaultValue, math.floor(currentValue))
	local safeAmount = math.max(1, math.floor(amount))
	local used = math.clamp(freePointsUsed, 0, Shared_StrengthStore.FreeStrengthPoints)
	local totalCost = 0
	local canUseFree = Shared_StrengthStore.CanUseFreeStrengthPoints(resolvedRebirths)

	for index = 0, safeAmount - 1 do
		if canUseFree and used < Shared_StrengthStore.FreeStrengthPoints then
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

Shared_StrengthStore.RobuxTierByAmount = {
	[1] = 1,
	[5] = 2,
	[10] = 3,
}

Shared_StrengthStore.RobuxTimeThresholds = {
	[1] = { 10, 30, 120 },
	[2] = { 30, 60, 120 },
	[3] = { 30, 90, 210 },
}

function Shared_StrengthStore.GetSecondsToAfford(cashCost: number, currentCash: number, incomePerSecond: number): number
	local shortfall = math.max(0, math.floor(cashCost) - math.floor(currentCash))
	if shortfall <= 0 then
		return 0
	end

	local income = math.max(0, incomePerSecond)
	if income <= 0 then
		return math.huge
	end

	return shortfall / income
end

function Shared_StrengthStore.GetRobuxProductType(purchaseAmount: number, secondsNeeded: number): number
	local tier = Shared_StrengthStore.RobuxTierByAmount[purchaseAmount]
	if not tier then
		return 1
	end

	local thresholds = Shared_StrengthStore.RobuxTimeThresholds[tier]
	if not thresholds then
		return 1
	end

	local safeSeconds = math.max(0, tonumber(secondsNeeded) or 0)
	for index = #thresholds, 1, -1 do
		if safeSeconds > thresholds[index] then
			return index
		end
	end

	return 1
end

function Shared_StrengthStore.GetRobuxProductConfigKey(purchaseAmount: number, secondsNeeded: number): string?
	local tier = Shared_StrengthStore.RobuxTierByAmount[purchaseAmount]
	if not tier then
		return nil
	end

	local productType = Shared_StrengthStore.GetRobuxProductType(purchaseAmount, secondsNeeded)
	return `StrengthRobuxT{tier}_{productType}`
end

return Shared_StrengthStore
