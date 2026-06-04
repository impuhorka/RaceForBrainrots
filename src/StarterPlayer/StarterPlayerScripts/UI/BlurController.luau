local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local BLUR_SIZE = 20
local BLUR_IN_TIME = 1.5 * 0.65
local BLUR_OUT_TIME = BLUR_IN_TIME * 0.65
local BLUR_IN_INFO = TweenInfo.new(BLUR_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BLUR_OUT_INFO = TweenInfo.new(BLUR_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local BlurController = {}

local blur = Lighting:FindFirstChildOfClass("BlurEffect")
local desiredSize = 0
local activeTween: Tween? = nil

local function sync()
	local target = desiredSize

	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end

	if not blur then
		return
	end

	if target > 0 then
		blur.Enabled = true
	end

	local tweenInfo = if target > 0 then BLUR_IN_INFO else BLUR_OUT_INFO
	activeTween = TweenService:Create(blur, tweenInfo, { Size = target })
	activeTween:Play()
	activeTween.Completed:Once(function(state)
		activeTween = nil

		if desiredSize ~= target then
			sync()
			return
		end

		if state == Enum.PlaybackState.Cancelled then
			sync()
			return
		end

		if target == 0 then
			blur.Enabled = false
		end
	end)
end

function BlurController.setOpen(isOpen: boolean)
	local target = if isOpen then BLUR_SIZE else 0
	if desiredSize == target and not activeTween then
		return
	end

	desiredSize = target
	sync()
end

return BlurController
