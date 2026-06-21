local Shared_SpeedStore = require(script.Parent.Shared_SpeedStore)

local Shared_Carry = {}

Shared_Carry.DefaultWalkSpeed = Shared_SpeedStore.DefaultSpeed
-- 5 kg per strength: str 16 = 80 kg cap, epic zone min pickup str 30, max epic roll str 45 = 225 kg.
Shared_Carry.CarryKgPerStrength = 5
Shared_Carry.MaxSlowPercent = 0.9
Shared_Carry.MinWalkSpeedMultiplier = 0.06
Shared_Carry.SpeedReliefMin = 0.72
Shared_Carry.SpeedReliefMax = 1
Shared_Carry.MinPickupCarryWalkSpeed = 2.5
Shared_Carry.TooWeakPickupMessage = "You need more strength!"

function Shared_Carry.GetMaxCarryWeight(strength: number): number
	local safeStrength = math.max(1, tonumber(strength) or 1)
	return safeStrength * Shared_Carry.CarryKgPerStrength
end

function Shared_Carry.GetBurdenRatio(weightKg: number, strength: number): number
	local capacity = Shared_Carry.GetMaxCarryWeight(strength)
	if capacity <= 0 then
		return 1
	end
	return math.max(0, tonumber(weightKg) or 0) / capacity
end

function Shared_Carry.CanCarryWeight(weightKg: number, strength: number): (boolean, string?)
	local weight = math.max(0, tonumber(weightKg) or 0)
	local capacity = Shared_Carry.GetMaxCarryWeight(strength)
	if weight <= capacity then
		return true, nil
	end

	local neededStrength = math.ceil(weight / Shared_Carry.CarryKgPerStrength)
	return false, `You need more strength! ({neededStrength} required)`
end

function Shared_Carry.CanPickupLuckyBlock(
	weightKg: number,
	strength: number,
	speed: number
): (boolean, string?)
	local safeSpeed = math.max(Shared_Carry.DefaultWalkSpeed, tonumber(speed) or Shared_Carry.DefaultWalkSpeed)
	local carrySpeed = Shared_Carry.GetCarryWalkSpeed(safeSpeed, weightKg, strength, safeSpeed)
	if carrySpeed > Shared_Carry.MinPickupCarryWalkSpeed then
		return true, nil
	end

	return false, Shared_Carry.TooWeakPickupMessage
end

function Shared_Carry.GetSpeedRelief(speed: number): number
	local safeSpeed = math.max(Shared_Carry.DefaultWalkSpeed, tonumber(speed) or Shared_Carry.DefaultWalkSpeed)
	local relief = Shared_Carry.DefaultWalkSpeed / safeSpeed
	return math.clamp(relief, Shared_Carry.SpeedReliefMin, Shared_Carry.SpeedReliefMax)
end

function Shared_Carry.GetCarryWalkSpeedMultiplier(weightKg: number, strength: number, speed: number): number
	local burden = Shared_Carry.GetBurdenRatio(weightKg, strength)
	if burden <= 0 then
		return 1
	end

	local relievedBurden = burden * Shared_Carry.GetSpeedRelief(speed)
	local multiplier = 1 - relievedBurden * Shared_Carry.MaxSlowPercent
	if burden > 1 then
		multiplier /= burden
	end
	return math.clamp(multiplier, Shared_Carry.MinWalkSpeedMultiplier, 1)
end

function Shared_Carry.GetCarryWalkSpeed(
	baseWalkSpeed: number,
	weightKg: number,
	strength: number,
	speed: number
): number
	local safeBase = math.max(1, tonumber(baseWalkSpeed) or Shared_Carry.DefaultWalkSpeed)
	if (tonumber(weightKg) or 0) <= 0 then
		return safeBase
	end

	return math.max(1, safeBase * Shared_Carry.GetCarryWalkSpeedMultiplier(weightKg, strength, speed))
end

return Shared_Carry
