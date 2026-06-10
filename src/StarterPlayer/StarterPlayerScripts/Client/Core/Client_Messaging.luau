local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local TweenService = game:GetService("TweenService")
local ClientLoader = require(script.Parent.Parent.Loader)

local Shared_Sounds = SharedModules.require("Shared_Sounds")
local Client_Data = ClientLoader.require("Client_Data")
local Client_SoundPreload = ClientLoader.require("Client_SoundPreload")

local Client_Messaging = {}

local MAX_MESSAGES = 3
local DISPLAY_TIME = 4
local FADE_TIME = 0.45
local POP_UP_SCALE = 1.08
local POP_UP_TIME = 0.06
local POP_DOWN_TIME = 0.08
local POP_LINEAR_UP = TweenInfo.new(POP_UP_TIME, Enum.EasingStyle.Linear)
local POP_LINEAR_DOWN = TweenInfo.new(POP_DOWN_TIME, Enum.EasingStyle.Linear)

local COLOR_TEMPLATES = {
	red = "RedMessage",
	green = "GreenMessage",
	yellow = "YellowMessage",
	white = "WhiteMessage",
}

type ActiveMessage = {
	key: string,
	baseText: string,
	color: string,
	count: number,
	clone: TextLabel,
	lifecycleId: number,
	fadeTweens: { Tween }?,
	popTweens: { Tween }?,
	popToken: number,
}

local messagingFrame: Frame?
local messageTemplates: Folder?
local activeMessages: { ActiveMessage } = {}
local messagesByKey: { [string]: ActiveMessage } = {}
local adminFeedbackConnected = false

local function playSfx(soundId: string, volume: number)
	if soundId == "" then
		return
	end

	Client_SoundPreload.PlayUi(soundId, volume, 2)
end

local function getMessageKey(color: string, text: string): string
	return color .. "\0" .. text
end

local function formatMessageText(baseText: string, count: number): string
	if count <= 1 then
		return baseText
	end
	return ("%s (x%s)"):format(baseText, count)
end

local function getNextLayoutOrder(): number
	if #activeMessages == 0 then
		return 0
	end

	local minOrder = activeMessages[1].clone.LayoutOrder
	for index = 2, #activeMessages do
		minOrder = math.min(minOrder, activeMessages[index].clone.LayoutOrder)
	end

	return minOrder - 1
end

local function removeEntry(entry: ActiveMessage)
	messagesByKey[entry.key] = nil

	local index = table.find(activeMessages, entry)
	if index then
		table.remove(activeMessages, index)
	end

	if entry.clone.Parent then
		entry.clone:Destroy()
	end
end

local function setLabelOpaque(label: TextLabel)
	label.TextTransparency = 0

	for _, descendant in label:GetDescendants() do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			descendant.TextTransparency = 0
		elseif descendant:IsA("UIStroke") then
			descendant.Transparency = 0
		end
	end
end

local function cancelFadeTweens(entry: ActiveMessage)
	if not entry.fadeTweens then
		return
	end

	for _, tween in entry.fadeTweens do
		tween:Cancel()
	end

	table.clear(entry.fadeTweens)
	entry.fadeTweens = nil
end

local function cancelPopTweens(entry: ActiveMessage)
	if not entry.popTweens then
		return
	end

	for _, tween in entry.popTweens do
		tween:Cancel()
	end

	table.clear(entry.popTweens)
	entry.popTweens = nil
end

local function ensureUiScale(label: TextLabel): UIScale
	local uiScale = label:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Scale = 1
		uiScale.Parent = label
	end
	return uiScale
end

local function playPopAnimation(entry: ActiveMessage)
	local label = entry.clone
	if not label or not label.Parent then
		return
	end

	cancelPopTweens(entry)
	entry.popTweens = {}

	entry.popToken = (entry.popToken or 0) + 1
	local popToken = entry.popToken

	local uiScale = ensureUiScale(label)
	uiScale.Scale = 1

	local popUp = TweenService:Create(uiScale, POP_LINEAR_UP, { Scale = POP_UP_SCALE })
	local popDown = TweenService:Create(uiScale, POP_LINEAR_DOWN, { Scale = 1 })

	table.insert(entry.popTweens, popUp)
	table.insert(entry.popTweens, popDown)

	popUp:Play()
	popUp.Completed:Once(function()
		if entry.popToken ~= popToken or not label.Parent then
			return
		end

		popDown:Play()
	end)

	popDown.Completed:Once(function()
		if entry.popToken ~= popToken then
			return
		end

		uiScale.Scale = 1
		cancelPopTweens(entry)
	end)
end

local function fadeAndDestroy(entry: ActiveMessage, lifecycleId: number)
	local label = entry.clone
	if not label or not label.Parent then
		removeEntry(entry)
		return
	end

	if entry.lifecycleId ~= lifecycleId then
		return
	end

	local tweenInfo = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tweens: { Tween } = {}

	local function addTween(instance: Instance, props: { [string]: number })
		table.insert(tweens, TweenService:Create(instance, tweenInfo, props))
	end

	if label:IsA("GuiObject") then
		addTween(label, {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		})
	end

	for _, descendant in label:GetDescendants() do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			addTween(descendant, {
				TextTransparency = 1,
				BackgroundTransparency = 1,
			})
		elseif descendant:IsA("UIStroke") then
			addTween(descendant, { Transparency = 1 })
		end
	end

	for _, tween in tweens do
		tween:Play()
	end

	entry.fadeTweens = tweens

	if #tweens > 0 then
		tweens[1].Completed:Wait()
	end

	entry.fadeTweens = nil

	if entry.lifecycleId == lifecycleId then
		removeEntry(entry)
	end
end

local function scheduleLifecycle(entry: ActiveMessage)
	cancelFadeTweens(entry)
	entry.lifecycleId += 1
	local lifecycleId = entry.lifecycleId

	task.delay(DISPLAY_TIME, function()
		if entry.lifecycleId ~= lifecycleId or not entry.clone.Parent then
			return
		end
		fadeAndDestroy(entry, lifecycleId)
	end)
end

local function removeOldestMessage()
	if #activeMessages == 0 then
		return
	end

	local oldest = activeMessages[1]
	for index = 2, #activeMessages do
		if activeMessages[index].clone.LayoutOrder > oldest.clone.LayoutOrder then
			oldest = activeMessages[index]
		end
	end

	removeEntry(oldest)
end

local function getTemplate(color: string): TextLabel?
	if not messageTemplates then
		return nil
	end

	local templateName = COLOR_TEMPLATES[color] or COLOR_TEMPLATES.white
	local template = messageTemplates:FindFirstChild(templateName)
	if template and template:IsA("TextLabel") then
		return template
	end

	return nil
end

local function createMessageClone(text: string, color: string): TextLabel?
	local template = getTemplate(color)
	if not template or not messagingFrame then
		return nil
	end

	local clone = template:Clone()
	clone.Text = text
	clone.Visible = true
	clone.LayoutOrder = getNextLayoutOrder()
	clone.Parent = messagingFrame
	setLabelOpaque(clone)
	ensureUiScale(clone)
	return clone
end

function Client_Messaging.Show(message: string, color: string?)
	if not messagingFrame or not messageTemplates then
		return
	end

	local normalizedColor = string.lower(color or "white")
	if not COLOR_TEMPLATES[normalizedColor] then
		normalizedColor = "white"
	end

	if normalizedColor == "green" and type(Shared_Sounds.SFX.Success) == "string" then
		playSfx(Shared_Sounds.SFX.Success, Shared_Sounds.SFXVolume.Success)
	elseif normalizedColor == "red" and type(Shared_Sounds.SFX.Error) == "string" then
		playSfx(Shared_Sounds.SFX.Error, Shared_Sounds.SFXVolume.Error)
	end

	local trimmedMessage = string.gsub(message, "^%s*(.-)%s*$", "%1")
	if trimmedMessage == "" then
		return
	end

	local key = getMessageKey(normalizedColor, trimmedMessage)
	local existing = messagesByKey[key]

	if existing then
		existing.count += 1
		existing.clone.Text = formatMessageText(existing.baseText, existing.count)
		setLabelOpaque(existing.clone)
		scheduleLifecycle(existing)
		playPopAnimation(existing)
		return
	end

	while #activeMessages >= MAX_MESSAGES do
		removeOldestMessage()
	end

	local clone = createMessageClone(formatMessageText(trimmedMessage, 1), normalizedColor)
	if not clone then
		return
	end

	local entry: ActiveMessage = {
		key = key,
		baseText = trimmedMessage,
		color = normalizedColor,
		count = 1,
		clone = clone,
		lifecycleId = 0,
		popToken = 0,
	}

	table.insert(activeMessages, entry)
	messagesByKey[key] = entry
	scheduleLifecycle(entry)
	playPopAnimation(entry)
end

function Client_Messaging.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local main = playerGui:WaitForChild("Main")
	messagingFrame = main:WaitForChild("Messaging") :: Frame

	local assets = ReplicatedStorage:WaitForChild("Assets")
	local ui = assets:WaitForChild("UI")
	messageTemplates = ui:WaitForChild("Messages") :: Folder

	if not adminFeedbackConnected then
		adminFeedbackConnected = true
		local events = ReplicatedStorage:WaitForChild("Events")
		local adminFeedback = events:WaitForChild("AdminFeedback")
		if adminFeedback and adminFeedback:IsA("RemoteEvent") then
			adminFeedback.OnClientEvent:Connect(function(message: string, isError: boolean)
				Client_Messaging.Show(message, isError and "red" or "green")
			end)
		end
	end
end

return Client_Messaging