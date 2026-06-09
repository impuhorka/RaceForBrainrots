local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared_Sounds = require(ReplicatedStorage.Modules.Shared_Sounds)

local Client_AudioSettings = require(script.Parent.Client_AudioSettings)
local Client_BackgroundMusic = require(script.Parent.Client_BackgroundMusic)
local Client_Data = require(script.Parent.Client_Data)
local Client_SoundPreload = require(script.Parent.Client_SoundPreload)

local Client_Settings = {}

local SETTINGS_CONFIG = {
	{ key = "Music", displayName = "Music", kind = "Scroll", layoutOrder = 1 },
	{ key = "SFX", displayName = "Sound Effects", kind = "Scroll", layoutOrder = 2 },
	{ key = "Animations", displayName = "Animations", kind = "Button", layoutOrder = 3 },
	{ key = "PopUps", displayName = "Pop Ups", kind = "Button", layoutOrder = 4 },
}

local BAR_GREEN = Color3.fromRGB(80, 220, 120)
local BAR_GRAY = Color3.fromRGB(90, 90, 90)
local PERCENT_RED = Color3.fromRGB(255, 80, 80)
local PERCENT_GREEN = Color3.fromRGB(80, 220, 120)
local PERCENT_DEFAULT = Color3.fromRGB(255, 255, 255)

local settingsHandler: RemoteEvent?
local scrollingFrame: ScrollingFrame?
local barTemplate: GuiObject?
local buttonTemplate: GuiObject?
local optimisticValues: { [string]: boolean? } = {}
local optimisticVolumes: { [string]: number? } = {}
local draggingVolumeKey: string? = nil

type VolumeDragState = {
	key: string,
	trackX: number,
	trackWidth: number,
	applyVisual: (number) -> (),
	connection: RBXScriptConnection?,
}

local activeVolumeDrag: VolumeDragState? = nil
local settingsFrame: GuiObject?
local volumeTrackHits: { TextButton } = {}

local function setGradientEnabled(root: Instance, gradientName: string, enabled: boolean)
	local gradient = root:FindFirstChild(gradientName, true)
	if gradient and gradient:IsA("UIGradient") then
		gradient.Enabled = enabled
	end
end

local function applyToggleState(root: Instance, statusLabel: TextLabel?, enabled: boolean)
	setGradientEnabled(root, "GreenGradient", enabled)
	setGradientEnabled(root, "RedGradient", not enabled)
	if statusLabel then
		statusLabel.Text = if enabled then "ON" else "OFF"
	end
end

local function getSettingEnabled(key: string): boolean
	local optimistic = optimisticValues[key]
	if optimistic ~= nil then
		return optimistic
	end
	local value = Client_Data:GetValue(key)
	if value == nil then
		return true
	end
	return value == true
end

local function getSettingVolume(key: string): number
	local optimistic = optimisticVolumes[key]
	if optimistic ~= nil then
		return optimistic
	end
	if key == "Music" then
		return Client_AudioSettings.GetMusicVolume()
	end
	if key == "SFX" then
		return Client_AudioSettings.GetSfxVolume()
	end
	return 1
end

local function playUiPopSfx()
	local soundId = Shared_Sounds.SFX and Shared_Sounds.SFX.UiPop or ""
	if type(soundId) ~= "string" or soundId == "" then
		return
	end
	Client_SoundPreload.PlayUi(soundId, 1, 1)
end

local function requestSetting(key: string, value: boolean | number)
	if settingsHandler then
		settingsHandler:FireServer("Set", key, value)
	end
end

local function setSettingName(row: Instance, displayName: string)
	local innerFrame = row:FindFirstChild("Frame")
	if not innerFrame then
		return
	end
	local settingName = innerFrame:FindFirstChild("SettingName")
	if settingName and settingName:IsA("TextLabel") then
		settingName.Text = displayName
	end
end

local function getPercentTextColor(percent: number): Color3
	if percent <= 0 then
		return PERCENT_RED
	end
	if percent >= 1 then
		return PERCENT_GREEN
	end
	return PERCENT_DEFAULT
end

local function applyBarGradient(gradient: UIGradient, percent: number)
	if percent <= 0 then
		gradient.Color = ColorSequence.new(BAR_GRAY)
		return
	end
	if percent >= 1 then
		gradient.Color = ColorSequence.new(BAR_GREEN)
		return
	end
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, BAR_GREEN),
		ColorSequenceKeypoint.new(percent, BAR_GREEN),
		ColorSequenceKeypoint.new(math.min(percent + 0.001, 1), BAR_GRAY),
		ColorSequenceKeypoint.new(1, BAR_GRAY),
	})
end

local function getPercentFromX(x: number, trackX: number, trackWidth: number): number
	if trackWidth <= 0 then
		return 0
	end
	return math.clamp((x - trackX) / trackWidth, 0, 1)
end

local function stopVolumeDrag()
	local drag = activeVolumeDrag
	if not drag then
		return
	end

	if drag.connection then
		drag.connection:Disconnect()
	end

	local finalPercent = optimisticVolumes[drag.key]
	if finalPercent ~= nil then
		requestSetting(drag.key, finalPercent)
	end

	Client_AudioSettings.ClearPreviewVolume(drag.key)

	if scrollingFrame then
		scrollingFrame.ScrollingEnabled = true
	end

	activeVolumeDrag = nil
	draggingVolumeKey = nil
end

local function syncSettingsInputEnabled()
	local enabled = settingsFrame ~= nil and settingsFrame.Visible
	for _, trackHit in volumeTrackHits do
		trackHit.Active = enabled
	end
	if not enabled and activeVolumeDrag then
		stopVolumeDrag()
	end
end

local function startVolumeDrag(
	key: string,
	track: GuiObject,
	applyVisual: (number) -> (),
	input: InputObject
)
	stopVolumeDrag()

	local trackX = track.AbsolutePosition.X
	local trackWidth = track.AbsoluteSize.X
	local percent = getPercentFromX(input.Position.X, trackX, trackWidth)

	optimisticVolumes[key] = percent
	Client_AudioSettings.SetPreviewVolume(key, percent)
	draggingVolumeKey = key
	applyVisual(percent)

	if key == "Music" then
		Client_BackgroundMusic.Refresh()
	end

	if scrollingFrame then
		scrollingFrame.ScrollingEnabled = false
	end

	local function updateFromInput(inputObject: InputObject)
		if
			inputObject.UserInputType ~= Enum.UserInputType.MouseMovement
			and inputObject.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		local nextPercent = getPercentFromX(inputObject.Position.X, trackX, trackWidth)
		optimisticVolumes[key] = nextPercent
		Client_AudioSettings.SetPreviewVolume(key, nextPercent)
		applyVisual(nextPercent)

		if key == "Music" then
			Client_BackgroundMusic.Refresh()
		end
	end

	activeVolumeDrag = {
		key = key,
		trackX = trackX,
		trackWidth = trackWidth,
		applyVisual = applyVisual,
		connection = UserInputService.InputChanged:Connect(updateFromInput),
	}
end

local function clearScrollingFrame()
	table.clear(volumeTrackHits)

	if not scrollingFrame then
		return
	end

	for _, child in scrollingFrame:GetChildren() do
		if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function addScrollRow(key: string, displayName: string, layoutOrder: number)
	if not scrollingFrame or not barTemplate then
		return
	end

	local row = barTemplate:Clone()
	row.Name = key
	row.LayoutOrder = layoutOrder
	row.Visible = true
	row.Parent = scrollingFrame
	setSettingName(row, displayName)

	local innerFrame = row:WaitForChild("Frame") :: Instance
	local scroll = innerFrame:WaitForChild("Scroll") :: GuiObject
	local bar = scroll:WaitForChild("Bar") :: Frame
	local percentLabel = scroll:WaitForChild("Percent") :: TextLabel
	local gradient = bar:FindFirstChildOfClass("UIGradient")
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Parent = bar
	end

	local imageButton = bar:FindFirstChildWhichIsA("ImageButton", true)
	if not imageButton then
		return
	end

	imageButton.AnchorPoint = Vector2.new(0.5, 0.5)

	local function isVolumeInput(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
	end

	local function applyVisual(percent: number)
		percent = math.clamp(percent, 0, 1)
		imageButton.Position = UDim2.new(percent, 0, 0.5, 0)
		applyBarGradient(gradient, percent)

		local display = math.floor(percent * 100 + 0.5)
		percentLabel.Text = display .. "%"
		percentLabel.TextColor3 = getPercentTextColor(percent)
	end

	local function refresh()
		applyVisual(getSettingVolume(key))
	end

	refresh()

	local trackHit = Instance.new("TextButton")
	trackHit.Name = "TrackHit"
	trackHit.Size = UDim2.fromScale(1, 1)
	trackHit.BackgroundTransparency = 1
	trackHit.Text = ""
	trackHit.AutoButtonColor = false
	trackHit.BorderSizePixel = 0
	trackHit.ZIndex = 1
	trackHit.Parent = bar
	table.insert(volumeTrackHits, trackHit)

	for _, child in bar:GetDescendants() do
		if
			child:IsA("GuiObject")
			and child ~= trackHit
			and child ~= imageButton
			and not imageButton:IsAncestorOf(child)
		then
			child.Active = false
		end
	end

	imageButton.ZIndex = math.max(imageButton.ZIndex, trackHit.ZIndex + 1)

	local function beginVolumeInput(input: InputObject)
		if not isVolumeInput(input) then
			return
		end
		if not settingsFrame or not settingsFrame.Visible then
			return
		end
		startVolumeDrag(key, bar, applyVisual, input)
	end

	trackHit.InputBegan:Connect(beginVolumeInput)
	imageButton.InputBegan:Connect(beginVolumeInput)

	Client_Data:ListenToChange(key, function()
		if draggingVolumeKey == key then
			return
		end
		optimisticVolumes[key] = nil
		Client_AudioSettings.ClearPreviewVolume(key)
		refresh()
	end)
end

local function addButtonRow(key: string, displayName: string, layoutOrder: number)
	if not scrollingFrame or not buttonTemplate then
		return
	end

	local row = buttonTemplate:Clone()
	row.Name = key
	row.LayoutOrder = layoutOrder
	row.Visible = true
	row.Parent = scrollingFrame
	setSettingName(row, displayName)

	local innerFrame = row:WaitForChild("Frame") :: Instance
	local buttonRoot = innerFrame:WaitForChild("Button")
	local imageButton = if buttonRoot:IsA("ImageButton")
		then buttonRoot
		else buttonRoot:FindFirstChildWhichIsA("ImageButton", true)
	if not imageButton then
		return
	end
	local statusLabel = innerFrame:FindFirstChild("Status", true)
	local status = if statusLabel and statusLabel:IsA("TextLabel") then statusLabel else nil

	local function refresh()
		applyToggleState(innerFrame, status, getSettingEnabled(key))
	end

	refresh()

	imageButton.MouseButton1Click:Connect(function()
		playUiPopSfx()
		local newEnabled = not getSettingEnabled(key)
		optimisticValues[key] = newEnabled
		refresh()
		requestSetting(key, newEnabled)
	end)

	Client_Data:ListenToChange(key, function()
		optimisticValues[key] = nil
		refresh()
	end)
end

local function buildSettingsRows()
	clearScrollingFrame()

	for _, entry in SETTINGS_CONFIG do
		if entry.kind == "Scroll" then
			addScrollRow(entry.key, entry.displayName, entry.layoutOrder)
		elseif entry.kind == "Button" then
			addButtonRow(entry.key, entry.displayName, entry.layoutOrder)
		end
	end
end

local function bindUi()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local main = playerGui:WaitForChild("Main")
	settingsFrame = main:WaitForChild("Frames"):WaitForChild("Settings") :: GuiObject
	scrollingFrame = settingsFrame:WaitForChild("ScrollingFrame") :: ScrollingFrame

	local assets = ReplicatedStorage:WaitForChild("Assets")
	local settingsAssets = assets:WaitForChild("UI"):WaitForChild("Settings")
	barTemplate = settingsAssets:WaitForChild("BarFrame") :: GuiObject
	buttonTemplate = settingsAssets:WaitForChild("ButtonFrame") :: GuiObject
	barTemplate.Visible = false
	buttonTemplate.Visible = false

	buildSettingsRows()

	settingsFrame:GetPropertyChangedSignal("Visible"):Connect(syncSettingsInputEnabled)
	syncSettingsInputEnabled()
end

function Client_Settings.Init()
	Client_Data.WaitUntilReady()

	local events = ReplicatedStorage:WaitForChild("Events")
	settingsHandler = events:WaitForChild("SettingsHandler") :: RemoteEvent

	UserInputService.InputEnded:Connect(function(input)
		if not activeVolumeDrag then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			stopVolumeDrag()
		end
	end)

	bindUi()
end

return Client_Settings
