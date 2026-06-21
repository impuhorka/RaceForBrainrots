local Shared_StatStore = require(script.Parent.Shared_StatStore)

local Shared_SpeedStore = Shared_StatStore.create({
	DefaultValue = 26,
	PurchaseOptions = { 1, 5, 10 },
	Economy = {
		BaseCostPerPoint = 500,
		GrowthPerPoint = 1.095,
		RoundTo = 50,
	},
})

Shared_SpeedStore.DefaultSpeed = Shared_SpeedStore.DefaultValue

Shared_SpeedStore.RobuxTierByAmount = {
	[1] = 1,
	[5] = 2,
	[10] = 3,
}

-- Seconds needed to afford the cash purchase; higher thresholds map to higher Robux product types.
Shared_SpeedStore.RobuxTimeThresholds = {
	[1] = { 10, 30, 120 },
	[2] = { 30, 60, 120 },
	[3] = { 30, 90, 210 },
}

function Shared_SpeedStore.GetSpeedAfterPurchase(currentSpeed: number, amount: number): number
	return Shared_SpeedStore.GetValueAfterPurchase(currentSpeed, amount)
end

function Shared_SpeedStore.GetSecondsToAfford(cashCost: number, currentCash: number, incomePerSecond: number): number
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

function Shared_SpeedStore.GetRobuxProductType(purchaseAmount: number, secondsNeeded: number): number
	local tier = Shared_SpeedStore.RobuxTierByAmount[purchaseAmount]
	if not tier then
		return 1
	end

	local thresholds = Shared_SpeedStore.RobuxTimeThresholds[tier]
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

function Shared_SpeedStore.GetRobuxProductConfigKey(purchaseAmount: number, secondsNeeded: number): string?
	local tier = Shared_SpeedStore.RobuxTierByAmount[purchaseAmount]
	if not tier then
		return nil
	end

	local productType = Shared_SpeedStore.GetRobuxProductType(purchaseAmount, secondsNeeded)
	return `SpeedRobuxT{tier}_{productType}`
end

return Shared_SpeedStore
