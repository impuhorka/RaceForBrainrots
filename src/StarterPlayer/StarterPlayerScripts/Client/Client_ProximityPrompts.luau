local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer

local Client_ProximityPrompts = {}
local progressGradientFuzz = 0.01
local promptGuiRoot: ScreenGui?

type PromptEntry = {
	gui: BillboardGui,
	connections: { RBXScriptConnection },
}

local activePrompts: { [ProximityPrompt]: PromptEntry } = {}

local function getPromptGuiRoot(): ScreenGui
	if promptGuiRoot and promptGuiRoot.Parent then
		return promptGuiRoot
	end

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("ProximityPrompts")
	if existing and existing:IsA("ScreenGui") then
		promptGuiRoot = existing
		return existing
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ProximityPrompts"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 20
	screenGui.Parent = playerGui
	promptGuiRoot = screenGui
	return screenGui
end

local function getInputLabel(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "Tap"
	end

	if inputType == Enum.ProximityPromptInputType.Gamepad then
		local gamepadMap = {
			[Enum.KeyCode.ButtonA] = "A",
			[Enum.KeyCode.ButtonB] = "B",
			[Enum.KeyCode.ButtonX] = "X",
			[Enum.KeyCode.ButtonY] = "Y",
		}
		return gamepadMap[prompt.GamepadKeyCode] or "X"
	end

	local keyboardKey = prompt.KeyboardKeyCode
	if keyboardKey == Enum.KeyCode.Unknown then
		return "E"
	end
	return keyboardKey.Name
end

local function cleanupPrompt(prompt: ProximityPrompt)
	local entry = activePrompts[prompt]
	if not entry then
		return
	end

	for _, connection in entry.connections do
		connection:Disconnect()
	end

	if entry.gui.Parent then
		entry.gui:Destroy()
	end

	activePrompts[prompt] = nil
end

local function buildPromptGui(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): PromptEntry
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CustomPrompt_" .. prompt.Name
	billboard.Size = UDim2.fromOffset(220, 64)
	billboard.AlwaysOnTop = true
	billboard.Active = true
	billboard.LightInfluence = 0
	billboard.DistanceLowerLimit = 12
	billboard.DistanceUpperLimit = 12
	billboard.ResetOnSpawn = false
	billboard.Adornee = prompt.Parent
	billboard.Parent = getPromptGuiRoot()

	local yOffset = prompt.UIOffset.Y
	billboard.StudsOffset = Vector3.new(0, yOffset * 0.01, 0)

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.Active = true
	card.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	card.BackgroundTransparency = 0.65
	card.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 2)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.Thickness = 0.06
	stroke.Transparency = 0
	stroke.Parent = card

	local objectLabel = Instance.new("TextLabel")
	objectLabel.Name = "ObjectText"
	objectLabel.BackgroundTransparency = 1
	objectLabel.Position = UDim2.fromOffset(12, 8)
	objectLabel.Size = UDim2.fromOffset(160, 20)
	objectLabel.Font = Enum.Font.GothamSemibold
	objectLabel.TextSize = 13
	objectLabel.TextXAlignment = Enum.TextXAlignment.Left
	objectLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
	objectLabel.Text = prompt.ObjectText
	objectLabel.Visible = prompt.ObjectText ~= ""
	objectLabel.Parent = card

	local actionLabel = Instance.new("TextLabel")
	actionLabel.Name = "ActionText"
	actionLabel.BackgroundTransparency = 1
	actionLabel.Position = UDim2.fromOffset(12, if objectLabel.Visible then 28 else 20)
	actionLabel.Size = UDim2.fromOffset(145, 24)
	actionLabel.Font = Enum.Font.GothamBold
	actionLabel.TextSize = 19
	actionLabel.TextXAlignment = Enum.TextXAlignment.Left
	actionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	actionLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	actionLabel.TextStrokeTransparency = 0
	actionLabel.Text = prompt.ActionText
	actionLabel.Parent = card

	local keyBadge = Instance.new("TextLabel")
	keyBadge.Name = "KeyBadge"
	keyBadge.AnchorPoint = Vector2.new(1, 0.5)
	keyBadge.Position = UDim2.fromScale(0.89, 0.5)
	keyBadge.Size = UDim2.fromOffset(47, 47)
	keyBadge.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	keyBadge.BackgroundTransparency = 0.25
	keyBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	keyBadge.Font = Enum.Font.GothamBold
	keyBadge.TextSize = 18
	keyBadge.Text = getInputLabel(prompt, inputType)
	keyBadge.ZIndex = 3
	keyBadge.Active = true
	keyBadge.Parent = card

	local keyButton = Instance.new("TextButton")
	keyButton.Name = "KeyButton"
	keyButton.Size = UDim2.fromScale(1, 1)
	keyButton.BackgroundTransparency = 1
	keyButton.Text = ""
	keyButton.AutoButtonColor = false
	keyButton.Active = true
	keyButton.ZIndex = 6
	keyButton.Parent = keyBadge

	local keyCorner = Instance.new("UICorner")
	keyCorner.CornerRadius = UDim.new(1, 0)
	keyCorner.Parent = keyBadge

	local keyStroke = Instance.new("UIStroke")
	keyStroke.Color = Color3.fromRGB(255, 255, 255)
	keyStroke.Transparency = 0.2
	keyStroke.Thickness = 1
	keyStroke.Parent = keyBadge

	local progressContainer = Instance.new("Frame")
	progressContainer.Name = "ProgressRing"
	progressContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	progressContainer.Position = UDim2.fromScale(0.5, 0.5)
	progressContainer.Size = UDim2.fromOffset(53, 53)
	progressContainer.BackgroundTransparency = 1
	progressContainer.ZIndex = 4
	progressContainer.Parent = keyBadge

	local function createProgressBarGradient(leftSide: boolean): (UIGradient, Frame)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(0.5, 1)
		frame.Position = UDim2.fromScale(leftSide and 0 or 0.5, 0)
		frame.BackgroundTransparency = 1
		frame.ClipsDescendants = true
		frame.Visible = false
		frame.Parent = progressContainer

		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(2, 1)
		image.Position = UDim2.fromScale(leftSide and 0 or -1, 0)
		image.Image = "rbxasset://textures/ui/Controls/RadialFill.png"
		image.ImageColor3 = Color3.fromRGB(255, 255, 255)
		image.Parent = frame

		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(0.5 + progressGradientFuzz, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Rotation = leftSide and 180 or 0
		gradient.Parent = image

		return gradient, frame
	end

	local leftGradient, leftFrame = createProgressBarGradient(true)
	local rightGradient, rightFrame = createProgressBarGradient(false)
	local holdProgress = Instance.new("NumberValue")
	holdProgress.Value = 0
	holdProgress.Parent = progressContainer

	local connections: { RBXScriptConnection } = {}
	local holdTween: Tween?
	local buttonHolding = false

	local function setProgress(value: number)
		local clamped = math.clamp(value, 0, 1)
		local angle = clamped * 360
		rightFrame.Visible = clamped > 0
		leftFrame.Visible = clamped > 0.5 + progressGradientFuzz
		rightGradient.Rotation = math.clamp(angle, 0, 180)
		leftGradient.Rotation = math.clamp(angle, 180, 360)
	end

	setProgress(0)

	table.insert(connections, holdProgress:GetPropertyChangedSignal("Value"):Connect(function()
		setProgress(holdProgress.Value)
	end))

	local function resetHoldProgress()
		if holdTween then
			holdTween:Cancel()
			holdTween = nil
		end
		holdProgress.Value = 0
	end

	local function beginPromptHold()
		if buttonHolding then
			return
		end
		buttonHolding = true
		prompt:InputHoldBegin()
	end

	local function endPromptHold()
		if not buttonHolding then
			return
		end
		buttonHolding = false
		prompt:InputHoldEnd()
	end

	table.insert(connections, prompt:GetPropertyChangedSignal("ObjectText"):Connect(function()
		objectLabel.Text = prompt.ObjectText
		objectLabel.Visible = prompt.ObjectText ~= ""
		actionLabel.Position = UDim2.fromOffset(12, if objectLabel.Visible then 28 else 20)
	end))

	table.insert(connections, prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
		actionLabel.Text = prompt.ActionText
	end))

	table.insert(connections, prompt:GetPropertyChangedSignal("KeyboardKeyCode"):Connect(function()
		keyBadge.Text = getInputLabel(prompt, inputType)
	end))

	table.insert(connections, prompt:GetPropertyChangedSignal("GamepadKeyCode"):Connect(function()
		keyBadge.Text = getInputLabel(prompt, inputType)
	end))

	table.insert(connections, prompt:GetPropertyChangedSignal("UIOffset"):Connect(function()
		billboard.StudsOffset = Vector3.new(0, prompt.UIOffset.Y * 0.01, 0)
	end))

	table.insert(connections, keyButton.MouseButton1Down:Connect(function()
		beginPromptHold()
	end))

	table.insert(connections, keyButton.MouseButton1Up:Connect(function()
		endPromptHold()
	end))

	table.insert(connections, keyButton.MouseLeave:Connect(function()
		endPromptHold()
	end))

	table.insert(connections, keyButton.InputBegan:Connect(function(inputObject: InputObject)
		local inputTypeLocal = inputObject.UserInputType
		if inputTypeLocal == Enum.UserInputType.Touch then
			beginPromptHold()
		end
	end))

	table.insert(connections, keyButton.InputEnded:Connect(function(inputObject: InputObject)
		local inputTypeLocal = inputObject.UserInputType
		if inputTypeLocal == Enum.UserInputType.Touch then
			endPromptHold()
		end
	end))

	table.insert(connections, keyButton.Activated:Connect(function()
		if prompt.HoldDuration <= 0 then
			prompt:InputHoldBegin()
			prompt:InputHoldEnd()
		end
	end))

	table.insert(connections, UserInputService.InputEnded:Connect(function(inputObject: InputObject)
		local inputTypeLocal = inputObject.UserInputType
		if inputTypeLocal == Enum.UserInputType.MouseButton1 or inputTypeLocal == Enum.UserInputType.Touch then
			endPromptHold()
		end
	end))

	table.insert(connections, prompt.PromptButtonHoldBegan:Connect(function()
		resetHoldProgress()
		if prompt.HoldDuration <= 0 then
			return
		end
		holdTween = TweenService:Create(holdProgress, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), {
			Value = 1,
		})
		holdTween:Play()
	end))

	table.insert(connections, prompt.PromptButtonHoldEnded:Connect(function()
		resetHoldProgress()
	end))

	table.insert(connections, prompt.Triggered:Connect(function()
		if prompt.HoldDuration <= 0 then
			holdProgress.Value = 1
			task.delay(0.08, function()
				if holdProgress.Parent then
					holdProgress.Value = 0
				end
			end)
		end
	end))

	table.insert(connections, prompt.Destroying:Connect(function()
		endPromptHold()
		resetHoldProgress()
		cleanupPrompt(prompt)
	end))

	return {
		gui = billboard,
		connections = connections,
	}
end

function Client_ProximityPrompts.Init()
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end

		cleanupPrompt(prompt)
		activePrompts[prompt] = buildPromptGui(prompt, inputType)
	end)

	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		cleanupPrompt(prompt)
	end)
end

return Client_ProximityPrompts
