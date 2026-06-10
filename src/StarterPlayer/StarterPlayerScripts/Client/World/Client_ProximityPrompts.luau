local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ClientLoader = require(script.Parent.Parent.Loader)

local localPlayer = Players.LocalPlayer
local Shared_Sounds = SharedModules.require("Shared_Sounds")
local Client_Data = ClientLoader.require("Client_Data")
local Client_SoundPreload = ClientLoader.require("Client_SoundPreload")
local FrameController = require(script.Parent.Parent.UI.FrameController)

local Client_ProximityPrompts = {}
local progressGradientFuzz = 0.01
local ENABLE_KEYBADGE_PROGRESS_RING = false
local PROXIMITY_ACTIVATE_SOUND_START_TIME = 0.3
local PROXIMITY_ACTIVATE_SOUND_VOLUME = 0.6
local PROMPT_POP_IN_TIME = 0.25
local PROMPT_POP_IN_TWEEN_INFO = TweenInfo.new(PROMPT_POP_IN_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local promptGuiRoot: ScreenGui?
local promptTemplate: BillboardGui

type PromptEntry = {
	gui: BillboardGui,
	connections: { RBXScriptConnection },
	popTween: Tween?,
}

type PromptElements = {
	card: GuiObject?,
	objectLabel: TextLabel?,
	actionLabel: TextLabel?,
	keyButton: TextButton?,
	cursorIcon: ImageLabel?,
	borderTop: Frame?,
	borderRight: Frame?,
	borderBottom: Frame?,
	borderLeft: Frame?,
	leftFrame: Frame?,
	rightFrame: Frame?,
	leftGradient: UIGradient?,
	rightGradient: UIGradient?,
	holdProgress: NumberValue?,
}

local activePrompts: { [ProximityPrompt]: PromptEntry } = {}
local promptsSuppressed = false
local watchedFrameVisibility: { [GuiObject]: boolean } = {}

local function playProximityActivateSfx()
	local soundId = Shared_Sounds.SFX and Shared_Sounds.SFX.ProximityActivate or ""
	if type(soundId) ~= "string" or soundId == "" then
		return
	end
	Client_SoundPreload.PlayUi(soundId, PROXIMITY_ACTIVATE_SOUND_VOLUME, 1, PROXIMITY_ACTIVATE_SOUND_START_TIME)
end

local function applyPromptVisibility(entry: PromptEntry)
	if entry.gui then
		entry.gui.Enabled = not promptsSuppressed
	end
end

local function refreshAllPromptVisibility()
	for _, entry in activePrompts do
		applyPromptVisibility(entry)
	end
end

local function isAnyNonInventoryFrameOpen(): boolean
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return false
	end

	local main = playerGui:FindFirstChild("Main")
	if not main then
		return false
	end

	local frames = main:FindFirstChild("Frames")
	if not frames or not frames:IsA("Folder") then
		return false
	end

	for _, child in frames:GetChildren() do
		if child:IsA("GuiObject")
			and FrameController.countsForBlur(child)
			and FrameController.isOpenForBlur(child)
		then
			return true
		end
	end

	return false
end

local function setPromptSuppressed(suppressed: boolean)
	if promptsSuppressed == suppressed then
		return
	end
	promptsSuppressed = suppressed
	refreshAllPromptVisibility()
end

local function refreshSuppressionNow()
	setPromptSuppressed(isAnyNonInventoryFrameOpen())
end

local function getPromptTemplate(): BillboardGui
	if promptTemplate and promptTemplate.Parent then
		return promptTemplate
	end

	local assets = ReplicatedStorage:WaitForChild("Assets")
	local billboards = assets:WaitForChild("Billboards")
	promptTemplate = billboards:WaitForChild("ProximityPrompt") :: BillboardGui
	return promptTemplate
end

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

local function mapUserInputToPromptInputType(userInputType: Enum.UserInputType): Enum.ProximityPromptInputType
	if userInputType == Enum.UserInputType.Touch then
		return Enum.ProximityPromptInputType.Touch
	end

	if tostring(userInputType):match("^Gamepad") then
		return Enum.ProximityPromptInputType.Gamepad
	end

	return Enum.ProximityPromptInputType.Keyboard
end

local function updateInputDisplay(
	prompt: ProximityPrompt,
	elements: PromptElements,
	inputType: Enum.ProximityPromptInputType
)
	local isTouch = inputType == Enum.ProximityPromptInputType.Touch

	if elements.cursorIcon then
		elements.cursorIcon.Visible = isTouch
	end

	if elements.keyButton then
		if isTouch then
			elements.keyButton.Text = ""
		else
			elements.keyButton.Text = getInputLabel(prompt, inputType)
		end
	end
end

local function getPromptElements(billboard: BillboardGui): PromptElements
	local card = billboard:WaitForChild("Card")
	local keyBadge = card:FindFirstChild("KeyBadge")
	local progressRing = keyBadge and keyBadge:FindFirstChild("ProgressRing")
	local cursorIcon: Instance? = nil
	if keyBadge then
		cursorIcon = keyBadge:FindFirstChild("CursorIcon")
		if not cursorIcon then
			cursorIcon = keyBadge:FindFirstChildWhichIsA("ImageLabel")
		end
	end
	if not cursorIcon then
		cursorIcon = card:FindFirstChild("CursorIcon")
	end

	local leftFrame = progressRing and progressRing:FindFirstChild("LeftHalf")
	local rightFrame = progressRing and progressRing:FindFirstChild("RightHalf")
	local progressBorder = card:FindFirstChild("ProgressBorder")
	local borderTop = progressBorder and progressBorder:FindFirstChild("Top")
	local borderRight = progressBorder and progressBorder:FindFirstChild("Right")
	local borderBottom = progressBorder and progressBorder:FindFirstChild("Bottom")
	local borderLeft = progressBorder and progressBorder:FindFirstChild("Left")

	local leftImage = leftFrame and leftFrame:FindFirstChildWhichIsA("ImageLabel")
	local rightImage = rightFrame and rightFrame:FindFirstChildWhichIsA("ImageLabel")

	local leftFrameTyped: Frame? = nil
	if leftFrame and leftFrame:IsA("Frame") then
		leftFrameTyped = leftFrame
	end

	local rightFrameTyped: Frame? = nil
	if rightFrame and rightFrame:IsA("Frame") then
		rightFrameTyped = rightFrame
	end

	local cardTyped: GuiObject? = nil
	if card:IsA("GuiObject") then
		cardTyped = card
	end

	local cursorIconTyped: ImageLabel? = nil
	if cursorIcon and cursorIcon:IsA("ImageLabel") then
		cursorIconTyped = cursorIcon
	end

	local objectLabel: TextLabel? = nil
	local objectLabelRaw = card:FindFirstChild("ObjectText")
	if objectLabelRaw and objectLabelRaw:IsA("TextLabel") then
		objectLabel = objectLabelRaw
	end

	local actionLabel: TextLabel? = nil
	local actionLabelRaw = card:FindFirstChild("ActionText")
	if actionLabelRaw and actionLabelRaw:IsA("TextLabel") then
		actionLabel = actionLabelRaw
	end

	local keyButton: TextButton? = nil
	if keyBadge then
		local keyButtonRaw = keyBadge:FindFirstChild("KeyButton")
		if keyButtonRaw and keyButtonRaw:IsA("TextButton") then
			keyButton = keyButtonRaw
		end
	end

	local leftGradient: UIGradient? = nil
	local leftGradientRaw = leftImage and leftImage:FindFirstChildWhichIsA("UIGradient")
	if leftGradientRaw and leftGradientRaw:IsA("UIGradient") then
		leftGradient = leftGradientRaw
	end

	local rightGradient: UIGradient? = nil
	local rightGradientRaw = rightImage and rightImage:FindFirstChildWhichIsA("UIGradient")
	if rightGradientRaw and rightGradientRaw:IsA("UIGradient") then
		rightGradient = rightGradientRaw
	end

	local holdProgress: NumberValue? = nil
	if progressRing then
		local holdProgressRaw = progressRing:FindFirstChild("HoldProgress")
		if holdProgressRaw and holdProgressRaw:IsA("NumberValue") then
			holdProgress = holdProgressRaw
		end
	end

	local borderTopTyped: Frame? = nil
	if borderTop and borderTop:IsA("Frame") then
		borderTopTyped = borderTop
	end

	local borderRightTyped: Frame? = nil
	if borderRight and borderRight:IsA("Frame") then
		borderRightTyped = borderRight
	end

	local borderBottomTyped: Frame? = nil
	if borderBottom and borderBottom:IsA("Frame") then
		borderBottomTyped = borderBottom
	end

	local borderLeftTyped: Frame? = nil
	if borderLeft and borderLeft:IsA("Frame") then
		borderLeftTyped = borderLeft
	end

	return {
		card = cardTyped,
		objectLabel = objectLabel,
		actionLabel = actionLabel,
		keyButton = keyButton,
		cursorIcon = cursorIconTyped,
		borderTop = borderTopTyped,
		borderRight = borderRightTyped,
		borderBottom = borderBottomTyped,
		borderLeft = borderLeftTyped,
		leftFrame = leftFrameTyped,
		rightFrame = rightFrameTyped,
		leftGradient = leftGradient,
		rightGradient = rightGradient,
		holdProgress = holdProgress,
	}
end

local function applyBorderProgress(elements: PromptElements, value: number)
	local top = elements.borderTop
	local right = elements.borderRight
	local bottom = elements.borderBottom
	local left = elements.borderLeft
	local card = elements.card
	if not top or not right or not bottom or not left or not card then
		return
	end

	local clamped = math.clamp(value, 0, 1)
	-- Use stable card dimensions instead of live border segment sizes.
	-- This avoids feedback/jitter while the segment sizes themselves animate.
	local topLength = math.max(card.AbsoluteSize.X, 0)
	local rightLength = math.max(card.AbsoluteSize.Y, 0)
	local bottomLength = topLength
	local leftLength = rightLength

	local totalLength = topLength + rightLength + bottomLength + leftLength

	local topFill = 0
	local rightFill = 0
	local bottomFill = 0
	local leftFill = 0

	if totalLength <= 0 then
		-- Fallback for first frame before UI has AbsoluteSize values.
		topFill = math.clamp(clamped * 4, 0, 1)
		rightFill = math.clamp(clamped * 4 - 1, 0, 1)
		bottomFill = math.clamp(clamped * 4 - 2, 0, 1)
		leftFill = math.clamp(clamped * 4 - 3, 0, 1)
	else
		local travelled = clamped * totalLength

		local function consume(segmentLength: number): number
			if segmentLength <= 0 then
				return 1
			end
			local fill = math.clamp(travelled / segmentLength, 0, 1)
			travelled -= segmentLength
			return fill
		end

		topFill = consume(topLength)
		rightFill = consume(rightLength)
		bottomFill = consume(bottomLength)
		leftFill = consume(leftLength)
	end

	top.Visible = topFill > 0
	right.Visible = rightFill > 0
	bottom.Visible = bottomFill > 0
	left.Visible = leftFill > 0

	top.Size = UDim2.fromScale(topFill, top.Size.Y.Scale)
	right.Size = UDim2.fromScale(right.Size.X.Scale, rightFill)
	bottom.Size = UDim2.fromScale(bottomFill, bottom.Size.Y.Scale)
	left.Size = UDim2.fromScale(left.Size.X.Scale, leftFill)
end

local function applyRadialProgress(elements: PromptElements, value: number)
	applyBorderProgress(elements, value)

	if not ENABLE_KEYBADGE_PROGRESS_RING then
		if elements.rightFrame then
			elements.rightFrame.Visible = false
		end
		if elements.leftFrame then
			elements.leftFrame.Visible = false
		end
		return
	end

	if not elements.leftFrame or not elements.rightFrame or not elements.leftGradient or not elements.rightGradient then
		return
	end

	local clamped = math.clamp(value, 0, 1)
	local angle = clamped * 360

	elements.rightFrame.Visible = clamped > 0
	elements.leftFrame.Visible = clamped > 0.5 + progressGradientFuzz
	elements.rightGradient.Rotation = math.clamp(angle, 0, 180)
	elements.leftGradient.Rotation = math.clamp(angle, 180, 360)
end

local function updatePromptLabels(prompt: ProximityPrompt, elements: PromptElements)
	if elements.objectLabel then
		elements.objectLabel.Text = prompt.ObjectText
		elements.objectLabel.Visible = prompt.ObjectText ~= ""
	end

	if elements.actionLabel then
		elements.actionLabel.Text = prompt.ActionText
	end
end

local function playPromptPopIn(card: GuiObject): Tween?
	local uiScale = card:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Scale = 1
		uiScale.Parent = card
	end

	uiScale.Scale = 0
	local tween = TweenService:Create(uiScale, PROMPT_POP_IN_TWEEN_INFO, { Scale = 1 })
	tween:Play()
	return tween
end

local function cleanupPrompt(prompt: ProximityPrompt)
	local entry = activePrompts[prompt]
	if not entry then
		return
	end

	if entry.popTween then
		entry.popTween:Cancel()
		entry.popTween = nil
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
	local billboard = getPromptTemplate():Clone()
	billboard.Name = "CustomPrompt_" .. prompt.Name
	billboard.Adornee = prompt.Parent
	billboard.Parent = getPromptGuiRoot()
	billboard.StudsOffset = Vector3.new(0, prompt.UIOffset.Y * 0.01, 0)

	local elements = getPromptElements(billboard)
	updatePromptLabels(prompt, elements)
	local currentInputType = mapUserInputToPromptInputType(UserInputService:GetLastInputType())
	if currentInputType ~= Enum.ProximityPromptInputType.Touch then
		currentInputType = inputType
	end

	local popTween: Tween? = nil
	if elements.card then
		elements.card.Active = true
		popTween = playPromptPopIn(elements.card)
	end

	updateInputDisplay(prompt, elements, currentInputType)

	if elements.holdProgress then
		elements.holdProgress.Value = 0
	end

	applyRadialProgress(elements, 0)

	local connections: { RBXScriptConnection } = {}
	local holdTween: Tween?
	local buttonHolding = false

	local function resetHoldProgress()
		if holdTween then
			holdTween:Cancel()
			holdTween = nil
		end
		if elements.holdProgress then
			elements.holdProgress.Value = 0
		end
		applyRadialProgress(elements, 0)
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

	if elements.holdProgress then
		local holdProgress = elements.holdProgress
		table.insert(connections, holdProgress:GetPropertyChangedSignal("Value"):Connect(function()
			applyRadialProgress(elements, holdProgress.Value)
		end))
	end

	table.insert(connections, prompt:GetPropertyChangedSignal("ObjectText"):Connect(function()
		updatePromptLabels(prompt, elements)
	end))

	table.insert(connections, prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
		updatePromptLabels(prompt, elements)
	end))

	if elements.keyButton then
		table.insert(connections, prompt:GetPropertyChangedSignal("KeyboardKeyCode"):Connect(function()
			updateInputDisplay(prompt, elements, currentInputType)
		end))

		table.insert(connections, prompt:GetPropertyChangedSignal("GamepadKeyCode"):Connect(function()
			updateInputDisplay(prompt, elements, currentInputType)
		end))

		table.insert(connections, elements.keyButton.MouseButton1Down:Connect(beginPromptHold))
		table.insert(connections, elements.keyButton.MouseButton1Up:Connect(endPromptHold))
		table.insert(connections, elements.keyButton.MouseLeave:Connect(endPromptHold))

		table.insert(connections, elements.keyButton.InputBegan:Connect(function(inputObject: InputObject)
			if inputObject.UserInputType == Enum.UserInputType.Touch then
				beginPromptHold()
			end
		end))

		table.insert(connections, elements.keyButton.InputEnded:Connect(function(inputObject: InputObject)
			if inputObject.UserInputType == Enum.UserInputType.Touch then
				endPromptHold()
			end
		end))
	end

	table.insert(connections, UserInputService.LastInputTypeChanged:Connect(function(lastInputType: Enum.UserInputType)
		currentInputType = mapUserInputToPromptInputType(lastInputType)
		updateInputDisplay(prompt, elements, currentInputType)
	end))

	if elements.card then
		table.insert(connections, elements.card.InputBegan:Connect(function(inputObject: InputObject)
			local inputTypeLocal = inputObject.UserInputType
			if inputTypeLocal == Enum.UserInputType.MouseButton1 or inputTypeLocal == Enum.UserInputType.Touch then
				beginPromptHold()
			end
		end))

		table.insert(connections, elements.card.InputEnded:Connect(function(inputObject: InputObject)
			local inputTypeLocal = inputObject.UserInputType
			if inputTypeLocal == Enum.UserInputType.MouseButton1 or inputTypeLocal == Enum.UserInputType.Touch then
				endPromptHold()
			end
		end))

		table.insert(connections, elements.card.MouseLeave:Connect(function()
			endPromptHold()
		end))
	end

	table.insert(connections, prompt:GetPropertyChangedSignal("UIOffset"):Connect(function()
		billboard.StudsOffset = Vector3.new(0, prompt.UIOffset.Y * 0.01, 0)
	end))

	table.insert(connections, UserInputService.InputEnded:Connect(function(inputObject: InputObject)
		local inputTypeLocal = inputObject.UserInputType
		if inputTypeLocal == Enum.UserInputType.MouseButton1 or inputTypeLocal == Enum.UserInputType.Touch then
			endPromptHold()
		end
	end))

	table.insert(connections, prompt.PromptButtonHoldBegan:Connect(function()
		resetHoldProgress()
		if prompt.HoldDuration <= 0 or not elements.holdProgress then
			return
		end
		holdTween = TweenService:Create(elements.holdProgress, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), {
			Value = 1,
		})
		holdTween:Play()
	end))

	table.insert(connections, prompt.PromptButtonHoldEnded:Connect(function()
		resetHoldProgress()
	end))

	table.insert(connections, prompt.Triggered:Connect(function()
		playProximityActivateSfx()
		if prompt.HoldDuration <= 0 and elements.holdProgress then
			elements.holdProgress.Value = 1
			task.delay(0.08, function()
				if elements.holdProgress and elements.holdProgress.Parent then
					elements.holdProgress.Value = 0
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
		popTween = popTween,
	}
end

function Client_ProximityPrompts.Init()
	getPromptTemplate()

	task.spawn(function()
		local playerGui = localPlayer:WaitForChild("PlayerGui")
		local main = playerGui:WaitForChild("Main")
		local frames = main:WaitForChild("Frames")
		local function hookFrameVisibility(frame: GuiObject)
			if watchedFrameVisibility[frame] then
				return
			end
			watchedFrameVisibility[frame] = true
			frame:GetPropertyChangedSignal("Visible"):Connect(function()
				refreshSuppressionNow()
			end)
			frame.Destroying:Connect(function()
				watchedFrameVisibility[frame] = nil
				refreshSuppressionNow()
			end)
		end

		FrameController.onBlurChanged(refreshSuppressionNow)
		for _, child in frames:GetChildren() do
			if child:IsA("GuiObject") then
				hookFrameVisibility(child)
			end
		end
		frames.ChildAdded:Connect(function(child)
			if child:IsA("GuiObject") then
				hookFrameVisibility(child)
			end
			refreshSuppressionNow()
		end)
		frames.ChildRemoved:Connect(refreshSuppressionNow)
		refreshSuppressionNow()
	end)

	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end

		refreshSuppressionNow()
		cleanupPrompt(prompt)
		local entry = buildPromptGui(prompt, inputType)
		activePrompts[prompt] = entry
		applyPromptVisibility(entry)
	end)

	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		cleanupPrompt(prompt)
		refreshSuppressionNow()
	end)
end

return Client_ProximityPrompts