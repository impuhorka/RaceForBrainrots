local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer

local BASE_FOV = 70
local FRAME_FOV = 60

local TWEEN_OPEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_CLOSE = TweenInfo.new(0.15, Enum.EasingStyle.Linear)
local TWEEN_PULSE_IN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_PULSE_OUT = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local PULSE_FOV_OFFSET = 18

local Client_FOV = {}

local camera = Workspace.CurrentCamera
local baseFov = BASE_FOV
local frameZoomActive = false
local activeTween: Tween? = nil

local function tweenFov(target: number, tweenInfo: TweenInfo)
	if not camera then
		return
	end

	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end

	activeTween = TweenService:Create(camera, tweenInfo, { FieldOfView = target })
	activeTween:Play()
end

function Client_FOV.init()
	if camera then
		baseFov = camera.FieldOfView
	end

	Player.CharacterAdded:Connect(function()
		task.defer(function()
			if not camera then
				return
			end

			if frameZoomActive then
				camera.FieldOfView = FRAME_FOV
			else
				baseFov = camera.FieldOfView
			end
		end)
	end)
end

local function getPulseTweenInfo(baseInfo: TweenInfo, durationScale: number): TweenInfo
	return TweenInfo.new(
		baseInfo.Time * durationScale,
		baseInfo.EasingStyle,
		baseInfo.EasingDirection,
		baseInfo.RepeatCount,
		baseInfo.Reverses,
		baseInfo.DelayTime
	)
end

local UNLUCKY_FORFEIT_FOV_OFFSET = 24

function Client_FOV.playUnluckyForfeit(fovOffset: number?)
	local offset = if type(fovOffset) == "number" and fovOffset > 0 then fovOffset else UNLUCKY_FORFEIT_FOV_OFFSET

	if not camera then
		return
	end

	local returnFov = camera.FieldOfView
	local pulseFov = math.max(35, returnFov - offset)

	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end

	local inTween = TweenService:Create(
		camera,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = pulseFov }
	)
	activeTween = inTween
	inTween:Play()
	inTween.Completed:Once(function()
		if not camera then
			return
		end

		task.wait(0.08)

		local outTween = TweenService:Create(
			camera,
			TweenInfo.new(0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ FieldOfView = returnFov }
		)
		activeTween = outTween
		outTween:Play()
		outTween.Completed:Once(function()
			if activeTween == outTween then
				activeTween = nil
			end
		end)
	end)
end

function Client_FOV.playPulse(durationScale: number?, fovOffset: number?)
	local scale = if type(durationScale) == "number" and durationScale > 0 then durationScale else 1
	local offset = if type(fovOffset) == "number" and fovOffset > 0 then fovOffset else PULSE_FOV_OFFSET

	if not camera then
		return
	end

	local returnFov = camera.FieldOfView
	local pulseFov = math.max(40, returnFov - offset)

	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end

	local inTween = TweenService:Create(
		camera,
		getPulseTweenInfo(TWEEN_PULSE_IN, scale),
		{ FieldOfView = pulseFov }
	)
	activeTween = inTween
	inTween:Play()
	inTween.Completed:Once(function()
		if not camera then
			return
		end

		local outTween = TweenService:Create(
			camera,
			getPulseTweenInfo(TWEEN_PULSE_OUT, scale),
			{ FieldOfView = returnFov }
		)
		activeTween = outTween
		outTween:Play()
		outTween.Completed:Once(function()
			if activeTween == outTween then
				activeTween = nil
			end
		end)
	end)
end

function Client_FOV.setFrameZoomActive(active: boolean)
	if frameZoomActive == active then
		return
	end

	frameZoomActive = active

	if active then
		if camera then
			baseFov = camera.FieldOfView
		end
		tweenFov(FRAME_FOV, TWEEN_OPEN)
	else
		tweenFov(baseFov, TWEEN_CLOSE)
	end
end

return Client_FOV
