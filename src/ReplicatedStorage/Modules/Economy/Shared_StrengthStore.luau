local Shared_StatStore = require(script.Parent.Shared_StatStore)

local Shared_Carry = require(script.Parent.Shared_Carry)

local Shared_StrengthStore = Shared_StatStore.create({
	DefaultValue = 1,
	PurchaseOptions = { 1, 5, 10 },
	Economy = {
		BaseCostPerPoint = 450,
		GrowthPerPoint = 1.092,
		RoundTo = 100,
	},
})

Shared_StrengthStore.DefaultStrength = Shared_StrengthStore.DefaultValue

function Shared_StrengthStore.GetStrengthAfterPurchase(currentStrength: number, amount: number): number
	return Shared_StrengthStore.GetValueAfterPurchase(currentStrength, amount)
end

function Shared_StrengthStore.GetMaxCarryWeight(strength: number): number
	return Shared_Carry.GetMaxCarryWeight(strength)
end

return Shared_StrengthStore
