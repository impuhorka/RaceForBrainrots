local Shared_StatStore = require(script.Parent.Shared_StatStore)

local Shared_Carry = require(script.Parent.Shared_Carry)

local Shared_StrengthStore = Shared_StatStore.create({
	DefaultValue = 1,
	PurchaseOptions = { 1, 5, 10 },
	Economy = {
		BaseCostPerPoint = 380,
		GrowthPerPoint = 1.086,
		RoundTo = 100,
	},
})

Shared_StrengthStore.DefaultStrength = Shared_StrengthStore.DefaultValue
Shared_StrengthStore.FreeStrengthPoints = 3

local getBaseSinglePointCost = Shared_StrengthStore.GetSinglePointCost

function Shared_StrengthStore.IsFreeStrengthPoint(currentStrength: number): boolean
	local safeStrength = math.max(Shared_StrengthStore.DefaultValue, math.floor(currentStrength))
	return safeStrength < Shared_StrengthStore.DefaultValue + Shared_StrengthStore.FreeStrengthPoints
end

function Shared_StrengthStore.GetSinglePointCost(currentValue: number): number
	if Shared_StrengthStore.IsFreeStrengthPoint(currentValue) then
		return 0
	end
	return getBaseSinglePointCost(currentValue)
end

function Shared_StrengthStore.GetPurchaseCost(currentValue: number, amount: number): number
	local safeValue = math.max(Shared_StrengthStore.DefaultValue, math.floor(currentValue))
	local safeAmount = math.max(1, math.floor(amount))
	local totalCost = 0

	for index = 0, safeAmount - 1 do
		totalCost += Shared_StrengthStore.GetSinglePointCost(safeValue + index)
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
