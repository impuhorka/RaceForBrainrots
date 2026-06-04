local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local RIPPLE_COUNT = 12
local SPREAD = 36
local DURATION = 0.35
local START_SIZE = 8
local END_SIZE = 2

local MOVE_TWEEN_INFO = TweenInfo.new(DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_TWEEN_INFO = TweenInfo.new(DURATION * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local ClickRipple = {}

local function getOverlayPosition(absPos: Vector2, screenGui: ScreenGui): UDim2
	if screenGui.IgnoreGuiInset then
		return UDim2.fromOffset(absPos.X, absPos.Y)
	end

	local inset = GuiService:GetGuiInset()
	return UDim2.fromOffset(absPos.X - inset.X, absPos.Y - inset.Y)
end

function ClickRipple.play(button: ImageButton)
	local screenGui = button:FindFirstAncestorWhichIsA("ScreenGui")
	if not screenGui then
		return
	end

	local mouse = UserInputService:GetMouseLocation()
	local absPos = button.AbsolutePosition
	local absSize = button.AbsoluteSize
	local x = mouse.X - absPos.X
	local y = mouse.Y - absPos.Y

	local overlay = Instance.new("Frame")
	overlay.Name = "ClickRippleOverlay"
	overlay.BackgroundTransparency = 1
	overlay.Position = getOverlayPosition(absPos, screenGui)
	overlay.Size = UDim2.fromOffset(absSize.X, absSize.Y)
	overlay.ZIndex = button.ZIndex + 100
	overlay.Active = false
	overlay.Parent = screenGui

	local pending = RIPPLE_COUNT

	local function finish()
		pending -= 1
		if pending <= 0 then
			overlay:Destroy()
		end
	end

	for i = 1, RIPPLE_COUNT do
		local offsetX = (math.random() * 2 - 1) * SPREAD
		local offsetY = (math.random() * 2 - 1) * SPREAD
		local sizeScale = 0.9 + math.random() * 0.5
		local startSize = START_SIZE * sizeScale
		local endSize = END_SIZE * sizeScale

		local circle = Instance.new("Frame")
		circle.AnchorPoint = Vector2.new(0.5, 0.5)
		circle.BackgroundColor3 = Color3.new(1, 1, 1)
		circle.BackgroundTransparency = 0.05
		circle.BorderSizePixel = 0
		circle.Size = UDim2.fromOffset(startSize, startSize)
		circle.Position = UDim2.fromOffset(x, y)
		circle.ZIndex = overlay.ZIndex
		circle.Active = false
		circle.Parent = overlay

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = circle

		local targetX = x + offsetX
		local targetY = y + offsetY

		local moveTween = TweenService:Create(circle, MOVE_TWEEN_INFO, {
			Position = UDim2.fromOffset(targetX, targetY),
			Size = UDim2.fromOffset(endSize, endSize),
		})

		moveTween:Play()

		task.delay(DURATION * 0.5, function()
			if not circle.Parent then
				return
			end

			local fadeTween = TweenService:Create(circle, FADE_TWEEN_INFO, {
				BackgroundTransparency = 1,
			})

			fadeTween:Play()
			fadeTween.Completed:Once(function()
				circle:Destroy()
				finish()
			end)
		end)
	end
end

return ClickRipple
