local Shared_StatStore = require(script.Parent.Shared_StatStore)

local Shared_SpeedStore = Shared_StatStore.create({
	DefaultValue = 16,
	PurchaseOptions = { 1, 5, 10 },
	Economy = {
		BaseCostPerPoint = 50,
		GrowthPerPoint = 1.07,
		RoundTo = 10,
	},
})

Shared_SpeedStore.DefaultSpeed = Shared_SpeedStore.DefaultValue

function Shared_SpeedStore.GetSpeedAfterPurchase(currentSpeed: number, amount: number): number
	return Shared_SpeedStore.GetValueAfterPurchase(currentSpeed, amount)
end

return Shared_SpeedStore
