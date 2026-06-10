local Shared_StatStore = require(script.Parent.Shared_StatStore)

local Shared_StrengthStore = Shared_StatStore.create({
	DefaultValue = 1,
	PurchaseOptions = { 1, 5, 10 },
	Economy = {
		BaseCostPerPoint = 50,
		GrowthPerPoint = 1.07,
		RoundTo = 10,
	},
})

Shared_StrengthStore.DefaultStrength = Shared_StrengthStore.DefaultValue

function Shared_StrengthStore.GetStrengthAfterPurchase(currentStrength: number, amount: number): number
	return Shared_StrengthStore.GetValueAfterPurchase(currentStrength, amount)
end

return Shared_StrengthStore
