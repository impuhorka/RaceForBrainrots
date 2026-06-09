local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared_Abbreviation = require(ReplicatedStorage.Modules.Utilities.Shared_Abbreviation)
local Shared_Sounds = require(ReplicatedStorage.Modules.Shared_Sounds)
local Client_Data = require(script.Parent.Client_Data)
local Client_SoundPreload = require(script.Parent.Client_SoundPreload)
local Client_Visuals = require(script.Parent.Client_Visuals)

local Client_CashAddingPopups = {}

local POPUP_COUNT = 3
local SPIRAL_DEGREES_PER_SECOND = 90
local POPUP_STAY_TIME = 1.5
local POPUP_GROW_TIME = 0.18
local POPUP_SHRINK_TIME = 0.22
local POPUP_FLY_TIME = 0.28
local POPUP_SPAWN_STAGGER = 0.1
local SPAWN_Y_OFFSET_MIN_RATIO = 0.10
local SPAWN_Y_OFFSET_MAX_RATIO = 0.30
local STATIC_PULSE_SCALE_AMPLITUDE = 0.06
local STATIC_PULSE_ROTATION_AMPLITUDE = 4
local STATIC_PULSE_SPEED = 5.5

local popupFrame: Frame?
local template: GuiObject?
local cashVisualFrame: GuiObject?

local function shouldPlaySfx(): boolean
	local value = Client_Data:GetValue("SFX")
	if value == nil then
		return true
	end
	return value == true
end

local function playCashAddSfx()
	local soundId = Shared_Sounds.SFX and Shared_Sounds.SFX.CashAdd or ""
	if type(soundId) ~= "string" or soundId == "" then
		return
	end
	if not shouldPlaySfx() then
		return
	end
	Client_SoundPreload.PlayUi(soundId, 1, 1)
end

local function playPopupAppearSfx()
	local soundId = Shared_Sounds.SFX and Shared_Sounds.SFX.CashPopupAppear or ""
	if type(soundId) ~= "string" or soundId == "" then
		return
	end
	if not shouldPlaySfx() then
		return
	end
	Client_SoundPreload.PlayUi(soundId, 1, 1)
end

local function setPopupAmountText(popup: GuiObject, amount: number)
	local textLabel = popup:FindFirstChildWhichIsA("TextLabel", true)
	if not textLabel then
		return
	end
	textLabel.Text = ("+$%s"):format(Shared_Abbreviation:Number(math.max(0, amount)))
end

local function getRandomAppearPositions(popup: GuiObject): (UDim2?, UDim2?)
	if not popupFrame then
		return nil, nil
	end
	local frameSize = popupFrame.AbsoluteSize
	local targetX = frameSize.X * (0.15 + math.random() * 0.7)
	local targetY = frameSize.Y * (0.2 + math.random() * 0.6)

	local offsetY = frameSize.Y
		* (SPAWN_Y_OFFSET_MIN_RATIO + math.random() * (SPAWN_Y_OFFSET_MAX_RATIO - SPAWN_Y_OFFSET_MIN_RATIO))

	local startX = targetX
	local startY = targetY + offsetY
	return UDim2.fromOffset(startX, startY), UDim2.fromOffset(targetX, targetY)
end

local function getCashTargetPosition(): UDim2?
	if not popupFrame or not cashVisualFrame then
		return nil
	end

	local cashAbsCenter = cashVisualFrame.AbsolutePosition + (cashVisualFrame.AbsoluteSize * 0.5)
	local localPos = cashAbsCenter - popupFrame.AbsolutePosition
	return UDim2.fromOffset(localPos.X, localPos.Y)
end

local function startSpiralRotation(popup: GuiObject): RBXScriptConnection?
	local spiral = popup:FindFirstChild("Spiral", true)
	if not spiral or not spiral:IsA("ImageLabel") then
		return nil
	end

	return RunService.Heartbeat:Connect(function(dt)
		if not popup.Parent then
			return
		end
		spiral.Rotation += SPIRAL_DEGREES_PER_SECOND * dt
	end)
end

local function scaleUdim2(size: UDim2, factor: number): UDim2
	return UDim2.new(
		size.X.Scale * factor,
		math.floor(size.X.Offset * factor + 0.5),
		size.Y.Scale * factor,
		math.floor(size.Y.Offset * factor + 0.5)
	)
end

local function startStaticPulse(
	popup: GuiObject,
	baseSize: UDim2,
	rotationDirection: number,
	startPhase: number
): RBXScriptConnection
	local startTime = os.clock()
	return RunService.Heartbeat:Connect(function()
		if not popup.Parent then
			return
		end

		local t = (os.clock() - startTime) * STATIC_PULSE_SPEED + startPhase
		local pulseAlpha = math.sin(t)
		local scaleFactor = 1 + pulseAlpha * STATIC_PULSE_SCALE_AMPLITUDE
		popup.Size = scaleUdim2(baseSize, scaleFactor)
		popup.Rotation = pulseAlpha * STATIC_PULSE_ROTATION_AMPLITUDE * rotationDirection
	end)
end

local function spawnPopup(amount: number)
	if not popupFrame or not template then
		return
	end

	local popup = template:Clone()
	popup.Visible = true
	popup.Parent = popupFrame

	local originSize = template.Size
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.Size = UDim2.fromOffset(0, 0)
	local startPosition, targetPosition = getRandomAppearPositions(popup)
	if startPosition and targetPosition then
		popup.Position = startPosition
	end
	setPopupAmountText(popup, amount)

	local spinConn = startSpiralRotation(popup)
	local pulseConn: RBXScriptConnection? = nil
	local pulseRotationDirection = if math.random() < 0.5 then -1 else 1
	local pulseStartPhase = math.random() * math.pi * 2
	popup.Destroying:Once(function()
		if spinConn then
			spinConn:Disconnect()
			spinConn = nil
		end
		if pulseConn then
			pulseConn:Disconnect()
			pulseConn = nil
		end
	end)

	local growTween = TweenService:Create(
		popup,
		TweenInfo.new(POPUP_GROW_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = originSize,
			Position = targetPosition or popup.Position,
		}
	)
	playPopupAppearSfx()
	growTween:Play()
	growTween.Completed:Once(function()
		if popup.Parent then
			pulseConn = startStaticPulse(popup, originSize, pulseRotationDirection, pulseStartPhase)
		end
	end)

	task.delay(POPUP_STAY_TIME, function()
		if not popup.Parent then
			return
		end

		local flyTarget = getCashTargetPosition()
		if flyTarget then
			if pulseConn then
				pulseConn:Disconnect()
				pulseConn = nil
			end
			local flyTween = TweenService:Create(
				popup,
				TweenInfo.new(POPUP_FLY_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					Position = flyTarget,
					Size = UDim2.fromOffset(0, 0),
				}
			)
			flyTween:Play()
			flyTween.Completed:Wait()
			if popup.Parent then
				playCashAddSfx()
				Client_Visuals.PlayCashCollectPulse()
			end
			if popup.Parent then
				popup:Destroy()
			end
			return
		end

		if popup.Parent then
			local shrinkTween = TweenService:Create(
				popup,
				TweenInfo.new(POPUP_SHRINK_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.In),
				{ Size = UDim2.fromOffset(0, 0) }
			)
			shrinkTween:Play()
			shrinkTween.Completed:Once(function()
				if popup.Parent then
					popup:Destroy()
				end
			end)
		end
	end)
end

function Client_CashAddingPopups.Show(amount: number)
	for index = 1, POPUP_COUNT do
		task.delay((index - 1) * POPUP_SPAWN_STAGGER, function()
			spawnPopup(amount)
		end)
	end
end

function Client_CashAddingPopups.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local main = playerGui:WaitForChild("Main")
	popupFrame = main:WaitForChild("CashAdding") :: Frame
	template = popupFrame:WaitForChild("Template") :: GuiObject
	template.Visible = false
	cashVisualFrame = main:WaitForChild("Visuals"):WaitForChild("Cash") :: GuiObject
end

return Client_CashAddingPopups
