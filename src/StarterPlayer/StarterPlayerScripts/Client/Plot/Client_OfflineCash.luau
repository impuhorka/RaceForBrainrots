local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local RunService = game:GetService("RunService")
local ClientLoader = require(script.Parent.Parent.Loader)

local Shared_Abbreviation = SharedModules.require("Shared_Abbreviation")
local Client_CashAddingPopups = ClientLoader.require("Client_CashAddingPopups")
local Client_Messaging = ClientLoader.require("Client_Messaging")
local FrameController = require(script.Parent.Parent.UI.FrameController)
local Client_OfflineCash = {}

local OFFLINE_POPUP_COUNT = 12
local STATIC_PULSE_SCALE_AMPLITUDE = 0.06
local STATIC_PULSE_ROTATION_AMPLITUDE = 4
local STATIC_PULSE_SPEED = 5.5

type CashLabelPulse = {
	label: ImageLabel,
	baseSize: UDim2,
	baseRotation: number,
	startPhase: number,
	connection: RBXScriptConnection?,
}

local plotHandler: RemoteEvent?
local offlineFrame: GuiObject?
local timeLabel: TextLabel?
local cashLabel: TextLabel?
local collectButton: ImageButton?

local pendingCash = 0
local collected = false
local collecting = false
local cashLabelPulses: { CashLabelPulse } = {}

local function scaleUdim2(size: UDim2, factor: number): UDim2
	return UDim2.new(
		size.X.Scale * factor,
		math.floor(size.X.Offset * factor + 0.5),
		size.Y.Scale * factor,
		math.floor(size.Y.Offset * factor + 0.5)
	)
end

local function getCashImageLabels(): { ImageLabel }
	local labels: { ImageLabel } = {}
	if not offlineFrame then
		return labels
	end

	for _, child in offlineFrame:GetChildren() do
		if child:IsA("ImageLabel") then
			table.insert(labels, child)
		end
	end

	return labels
end

local function stopCashLabelPulse()
	for _, pulse in cashLabelPulses do
		if pulse.connection then
			pulse.connection:Disconnect()
			pulse.connection = nil
		end
		if pulse.label.Parent then
			pulse.label.Size = pulse.baseSize
			pulse.label.Rotation = pulse.baseRotation
		end
	end
	table.clear(cashLabelPulses)
end

local function startCashLabelPulse()
	stopCashLabelPulse()

	for _, label in getCashImageLabels() do
		local pulse: CashLabelPulse = {
			label = label,
			baseSize = label.Size,
			baseRotation = label.Rotation,
			startPhase = math.random() * math.pi * 2,
			connection = nil,
		}
		table.insert(cashLabelPulses, pulse)

		local startTime = os.clock()
		pulse.connection = RunService.Heartbeat:Connect(function()
			if not label.Parent or not offlineFrame or not offlineFrame.Visible then
				return
			end

			local t = (os.clock() - startTime) * STATIC_PULSE_SPEED + pulse.startPhase
			local scaleAlpha = math.sin(t)
			local rotationAlpha = math.sin(t + math.pi * 0.5)
			local scaleFactor = 1 + scaleAlpha * STATIC_PULSE_SCALE_AMPLITUDE
			label.Size = scaleUdim2(pulse.baseSize, scaleFactor)
			label.Rotation = pulse.baseRotation + rotationAlpha * STATIC_PULSE_ROTATION_AMPLITUDE
		end)
	end
end

local function formatDuration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60

	if hours > 0 then
		return ("%dh %dm"):format(hours, minutes)
	end
	if minutes > 0 then
		return ("%dm %ds"):format(minutes, secs)
	end
	return ("%ds"):format(secs)
end

local function collectParticleEmitters(root: Instance): { ParticleEmitter }
	local emitters: { ParticleEmitter } = {}

	for _, descendant in root:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			table.insert(emitters, descendant)
		end
	end

	if root:IsA("ParticleEmitter") then
		table.insert(emitters, root)
	end

	return emitters
end

local function playConfetti()
	local confettiRoot = offlineFrame and offlineFrame:FindFirstChild("Confetti", true)
	if not confettiRoot then
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local vfxFolder = assets and assets:FindFirstChild("VFX")
		confettiRoot = vfxFolder and vfxFolder:FindFirstChild("Confetti")
	end
	if not confettiRoot then
		return
	end

	for _, emitter in collectParticleEmitters(confettiRoot) do
		local emitCount = math.max(1, emitter:GetAttribute("EmitCount") or 20)
		emitter:Emit(emitCount)
	end
end

local function updateFrame(cash: number, offlineSeconds: number)
	if timeLabel then
		timeLabel.Text = formatDuration(offlineSeconds)
	end
	if cashLabel then
		cashLabel.Text = ("$%s"):format(Shared_Abbreviation:Number(math.max(0, cash)))
	end
end

local function playCollectRewards(cash: number)
	Client_CashAddingPopups.Show(cash, OFFLINE_POPUP_COUNT)
	playConfetti()
	Client_Messaging.Show(
		("Collected $%s offline cash!"):format(Shared_Abbreviation:Number(math.max(0, cash))),
		"green"
	)
end

local function requestCollect()
	if collected or collecting or pendingCash <= 0 or not plotHandler then
		return
	end

	collecting = true
	plotHandler:FireServer("CollectOfflineCash")
end

local function onCollected(cash: number)
	collected = true
	collecting = false
	pendingCash = 0
	playCollectRewards(cash)

	if offlineFrame and offlineFrame.Visible then
		FrameController.close(offlineFrame)
	end
end

local function showOfflineFrame(cash: number, offlineSeconds: number)
	if cash <= 0 or not offlineFrame then
		return
	end

	pendingCash = cash
	collected = false
	collecting = false
	updateFrame(cash, offlineSeconds)
	FrameController.open(offlineFrame)
end

local function bindUi()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local main = playerGui:WaitForChild("Main")
	local frames = main:WaitForChild("Frames")
	offlineFrame = frames:WaitForChild("OfflineCash") :: GuiObject

	local holder = offlineFrame:WaitForChild("Holder")
	local timeRoot = holder:WaitForChild("Time")
	local cashRoot = holder:WaitForChild("Cash")
	timeLabel = timeRoot:WaitForChild("TextLabel") :: TextLabel
	cashLabel = cashRoot:WaitForChild("TextLabel") :: TextLabel
	collectButton = holder:WaitForChild("Collect"):WaitForChild("ImageButton") :: ImageButton

	offlineFrame.Visible = false

	collectButton.MouseButton1Click:Connect(function()
		requestCollect()
	end)

	offlineFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if offlineFrame.Visible then
			startCashLabelPulse()
			return
		end

		stopCashLabelPulse()

		if not collected and not collecting and pendingCash > 0 then
			requestCollect()
		end
	end)
end

function Client_OfflineCash.Init()
	bindUi()

	local events = ReplicatedStorage:WaitForChild("Events")
	plotHandler = events:WaitForChild("PlotHandler") :: RemoteEvent

	plotHandler.OnClientEvent:Connect(function(action: string, arg1: any, arg2: any)
		if action == "OfflineCash" then
			local cash = tonumber(arg1) or 0
			local offlineSeconds = tonumber(arg2) or 0
			showOfflineFrame(cash, offlineSeconds)
			return
		end

		if action == "OfflineCashCollected" then
			local cash = tonumber(arg1) or 0
			if cash > 0 then
				onCollected(cash)
			else
				collecting = false
			end
		end
	end)
end

return Client_OfflineCash