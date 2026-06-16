local Shared_SpeedStore = require(script.Parent.Shared_SpeedStore)

local Shared_Carry = {}

Shared_Carry.DefaultWalkSpeed = Shared_SpeedStore.DefaultSpeed
-- 10 kg per strength: Common 10kg at str 1, Superior 1000kg at str 100, max rolls scale with tier.
Shared_Carry.CarryKgPerStrength = 10
Shared_Carry.MaxSlowPercent = 0.72
Shared_Carry.MinWalkSpeedMultiplier = 0.18
Shared_Carry.SpeedReliefMin = 0.35
Shared_Carry.SpeedReliefMax = 1

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
