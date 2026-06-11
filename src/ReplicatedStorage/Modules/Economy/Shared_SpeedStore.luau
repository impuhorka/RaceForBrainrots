local Shared_StatStore = require(script.Parent.Shared_StatStore)

local Shared_SpeedStore = Shared_StatStore.create({
	DefaultValue = 26,
	PurchaseOptions = { 1, 5, 10 },
	Economy = {
		BaseCostPerPoint = 250,
		GrowthPerPoint = 1.082,
		RoundTo = 50,
	},
})

Shared_SpeedStore.DefaultSpeed = Shared_SpeedStore.DefaultValue

function Shared_SpeedStore.GetSpeedAfterPurchase(currentSpeed: number, amount: number): number
	return Shared_SpeedStore.GetValueAfterPurchase(currentSpeed, amount)
end

return Shared_SpeedStore
