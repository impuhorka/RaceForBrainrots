local TweenService = game:GetService("TweenService")

local AnimationBase = require(script.Parent.AnimationBase)
local ClickRipple = require(script.Parent.ClickRipple)

local TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local AnimatedButton0 = {}
AnimatedButton0.__index = AnimatedButton0
setmetatable(AnimatedButton0, { __index = AnimationBase })

function AnimatedButton0.new(instance: ImageButton)
	local self = AnimationBase.new(instance)

	local uiScale = instance:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Scale = 1
		uiScale.Parent = instance
	end

	self._uiScale = uiScale
	self._originalScale = uiScale.Scale
	self._tween = nil

	setmetatable(self, {
		__index = function(_, key)
			local method = AnimatedButton0[key]
			if method ~= nil then
				return method
			end
			return AnimationBase[key]
		end,
	})

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
