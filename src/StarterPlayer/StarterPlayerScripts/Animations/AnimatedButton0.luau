local TweenService = game:GetService("TweenService")

local AnimationBase = require(script.Parent.AnimationBase)
local ClickRipple = require(script.Parent.ClickRipple)

local TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local AnimatedButton0 = setmetatable({}, { __index = AnimationBase })
AnimatedButton0.__index = AnimatedButton0

function AnimatedButton0.new(instance: ImageButton)
	local self = setmetatable(AnimationBase.new(instance), AnimatedButton0)

	local uiScale = instance:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Scale = 1
		uiScale.Parent = instance
	end

	self._uiScale = uiScale
	self._originalScale = uiScale.Scale
	self._tween = nil

	return self
end

function AnimatedButton0:_tweenScale(scale: number)
	if self._tween then
		self._tween:Cancel()
	end
	self._tween = TweenService:Create(self._uiScale, TWEEN_INFO, { Scale = scale })
	self._tween:Play()
end

function AnimatedButton0:Setup()
	local button = self.Instance :: ImageButton

	self:Connect(button.MouseEnter, function()
		self:_tweenScale(self._originalScale * 1.1)
	end)

	self:Connect(button.MouseLeave, function()
		self:_tweenScale(self._originalScale)
	end)

	self:Connect(button.MouseButton1Down, function()
		self:_tweenScale(self._originalScale * 0.95)
	end)

	self:Connect(button.MouseButton1Click, function()
		self:_tweenScale(self._originalScale * 1.1)
		ClickRipple.play(button)
	end)
end

return AnimatedButton0
