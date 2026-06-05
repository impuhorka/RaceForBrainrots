local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer

local BASE_FOV = 70
local FRAME_FOV = 60

local TWEEN_OPEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_CLOSE = TweenInfo.new(0.15, Enum.EasingStyle.Linear)

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
