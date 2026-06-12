local Client_StreakSfx = {}

export type StreakKind = "Cash" | "Upgrade"

type StreakConfig = {
	windowSeconds: number,
	baseSpeed: number,
	speedPerStreak: number,
	maxSpeed: number,
	baseVolumeMul: number,
	volumePerStreak: number,
	maxVolumeMul: number,
}

type StreakState = {
	count: number,
	lastAt: number,
}

local STREAK_RESET_SECONDS = 1.25
local CASH_MAX_PLAYBACK_SPEED = 1.35
local UPGRADE_MAX_PLAYBACK_SPEED = 1.5

local CONFIG: { [StreakKind]: StreakConfig } = {
	Cash = {
		windowSeconds = STREAK_RESET_SECONDS,
		baseSpeed = 1,
		speedPerStreak = 0.065,
		maxSpeed = CASH_MAX_PLAYBACK_SPEED,
		baseVolumeMul = 1,
		volumePerStreak = 0.035,
		maxVolumeMul = 1.2,
	},
	Upgrade = {
		windowSeconds = STREAK_RESET_SECONDS,
		baseSpeed = 1,
		speedPerStreak = 0.08,
		maxSpeed = UPGRADE_MAX_PLAYBACK_SPEED,
		baseVolumeMul = 1,
		volumePerStreak = 0.04,
		maxVolumeMul = 1.25,
	},
}

local states: { [StreakKind]: StreakState } = {}

local function getState(kind: StreakKind): StreakState
	local state = states[kind]
	if not state then
		state = { count = 0, lastAt = 0 }
		states[kind] = state
	end
	return state
end

function Client_StreakSfx.Register(kind: StreakKind): (number, number)
	local config = CONFIG[kind]
	local state = getState(kind)
	local now = os.clock()

	if now - state.lastAt > config.windowSeconds then
		state.count = 0
	end

	state.count += 1
	state.lastAt = now

	local streakIndex = state.count - 1
	local playbackSpeed = math.min(
		config.baseSpeed + streakIndex * config.speedPerStreak,
		config.maxSpeed
	)
	local volumeMul = math.min(
		config.baseVolumeMul + streakIndex * config.volumePerStreak,
		config.maxVolumeMul
	)

	return playbackSpeed, volumeMul
end

function Client_StreakSfx.Reset(kind: StreakKind)
	states[kind] = nil
end

return Client_StreakSfx
