local RunService = game:GetService("RunService")

local Client_StatStoreFreeHighlight = {}

local HIGHLIGHT_TAG = "TutorialFreeCostHighlight"

type HighlightState = {
	costLabel: TextLabel?,
	pulseTarget: GuiObject,
	gradient: UIGradient?,
	stroke: UIStroke?,
	buttonStroke: UIStroke?,
	originalTextColor: Color3?,
}

local activeByTarget: { [GuiObject]: HighlightState } = {}
local heartbeatConn: RBXScriptConnection? = nil

local function ensureHeartbeat()
	if heartbeatConn then
		return
	end

	heartbeatConn = RunService.Heartbeat:Connect(function()
		if next(activeByTarget) == nil then
			if heartbeatConn then
				heartbeatConn:Disconnect()
				heartbeatConn = nil
			end
			return
		end

		local rotation = (os.clock() * 95) % 360
		for _, state in activeByTarget do
			if state.gradient then
				state.gradient.Rotation = rotation
			end
		end
	end)
end

local function clearHighlight(pulseTarget: GuiObject)
	local state = activeByTarget[pulseTarget]
	if not state then
		return
	end

	activeByTarget[pulseTarget] = nil

	if state.gradient and state.gradient.Parent then
		state.gradient:Destroy()
	end
	if state.stroke and state.stroke.Parent then
		state.stroke:Destroy()
	end
	if state.buttonStroke and state.buttonStroke.Parent then
		state.buttonStroke:Destroy()
	end

	if state.costLabel and state.originalTextColor then
		state.costLabel.TextColor3 = state.originalTextColor
	end

	pulseTarget:SetAttribute(HIGHLIGHT_TAG, nil)
end

function Client_StatStoreFreeHighlight.setPurchaseHighlight(
	costLabel: TextLabel?,
	pulseTarget: GuiObject?,
	button: GuiButton?,
	active: boolean
)
	if not pulseTarget or not pulseTarget:IsA("GuiObject") then
		return
	end

	if not active then
		clearHighlight(pulseTarget)
		return
	end

	local existing = activeByTarget[pulseTarget]
	if existing then
		if costLabel and not existing.gradient then
			existing.originalTextColor = costLabel.TextColor3
			costLabel.TextColor3 = Color3.new(1, 1, 1)

			local gradient = Instance.new("UIGradient")
			gradient.Name = "TutorialFreeGradient"
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(72, 255, 132)),
				ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 244, 92)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(72, 220, 255)),
			})
			gradient.Parent = costLabel
			existing.gradient = gradient

			local stroke = Instance.new("UIStroke")
			stroke.Name = "TutorialFreeStroke"
			stroke.Color = Color3.fromRGB(255, 255, 200)
			stroke.Thickness = 2
			stroke.Transparency = 0.1
			stroke.Parent = costLabel
			existing.stroke = stroke
			existing.costLabel = costLabel
		end
		return
	end

	local gradient: UIGradient? = nil
	local stroke: UIStroke? = nil
	local originalTextColor: Color3? = nil

	if costLabel and costLabel:IsA("TextLabel") then
		originalTextColor = costLabel.TextColor3
		costLabel.TextColor3 = Color3.new(1, 1, 1)

		gradient = Instance.new("UIGradient")
		gradient.Name = "TutorialFreeGradient"
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(72, 255, 132)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 244, 92)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(72, 220, 255)),
		})
		gradient.Parent = costLabel

		stroke = Instance.new("UIStroke")
		stroke.Name = "TutorialFreeStroke"
		stroke.Color = Color3.fromRGB(255, 255, 200)
		stroke.Thickness = 2
		stroke.Transparency = 0.1
		stroke.Parent = costLabel
	end

	local buttonStroke: UIStroke? = nil
	if button and button:IsA("GuiButton") then
		buttonStroke = Instance.new("UIStroke")
		buttonStroke.Name = "TutorialFreeButtonStroke"
		buttonStroke.Color = Color3.fromRGB(120, 255, 160)
		buttonStroke.Thickness = 3
		buttonStroke.Transparency = 0.05
		buttonStroke.Parent = button
	end

	local state: HighlightState = {
		costLabel = costLabel,
		pulseTarget = pulseTarget,
		gradient = gradient,
		stroke = stroke,
		buttonStroke = buttonStroke,
		originalTextColor = originalTextColor,
	}

	activeByTarget[pulseTarget] = state
	pulseTarget:SetAttribute(HIGHLIGHT_TAG, true)
	ensureHeartbeat()
end

function Client_StatStoreFreeHighlight.clearAll()
	for pulseTarget in activeByTarget do
		clearHighlight(pulseTarget)
	end
end

return Client_StatStoreFreeHighlight
