local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SharedModules = require(ReplicatedStorage.Modules.Loader)
local ClientLoader = require(script.Parent.Parent.Loader)
local Shared_GameProcess = SharedModules.require("Shared_GameProcess")
local Shared_Sounds = SharedModules.require("Shared_Sounds")
local Client_AudioSettings = ClientLoader.require("Client_AudioSettings")
local Client_Messaging = ClientLoader.require("Client_Messaging")
local Client_SoundPreload = ClientLoader.require("Client_SoundPreload")

local Client_GameProcess = {}

local PHASES = {
	Shared_GameProcess.ProcessPhase.NewMap,
	Shared_GameProcess.ProcessPhase.RaceStarts,
	Shared_GameProcess.ProcessPhase.RaceEnds,
	Shared_GameProcess.ProcessPhase.Relax,
}

local ENTRANCE_WALL_NAME = "EntranceWall"

type EntranceWallUi = {
	surfaceGui: SurfaceGui?,
	frame: Frame?,
	messageLabel: TextLabel?,
	timeLabel: TextLabel?,
	newMapGradient: UIGradient?,
	raceStartsGradient: UIGradient?,
	relaxMapGradient: UIGradient?,
}

local localPlayer = Players.LocalPlayer
local gameProcessGui: GuiObject?
local phaseFrames: { [string]: GuiObject } = {}
local phaseGradients: { [string]: UIGradient? } = {}
local timeLeftLabels: { [string]: TextLabel } = {}
local entranceWallUi: EntranceWallUi = {}
local lastEntranceWallUiPhase: string? = nil
local lastProcessPhase: string? = nil
local lastUiUpdateAt = 0
local UI_UPDATE_INTERVAL = 0.1
local baseGameProcessSize: UDim2? = nil
local carrySizeTween: Tween? = nil
local CARRY_SIZE_Y_MULTIPLIER = 1.3
local CARRY_SIZE_TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function formatTimeLeft(seconds: number): string
	return string.format("%.1f seconds", math.max(0, seconds))
end

local function playSuccessSfx()
	if Client_AudioSettings.GetSfxVolume() <= 0 then
		return
	end

	local soundId = Shared_Sounds.SFX and Shared_Sounds.SFX.Success
	if type(soundId) ~= "string" or soundId == "" then
		return
	end

	Client_SoundPreload.Play(soundId, Shared_Sounds.SFXVolume.Success or 0.65)
end

local function getGameProcessCarrySize(carrying: boolean): UDim2?
	if not baseGameProcessSize then
		return nil
	end

	local yMultiplier = if carrying then CARRY_SIZE_Y_MULTIPLIER else 1
	local base = baseGameProcessSize
	return UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale * yMultiplier, base.Y.Offset * yMultiplier)
end

local function updateGameProcessCarrySize(carrying: boolean)
	if not gameProcessGui or not gameProcessGui:IsA("GuiObject") then
		return
	end

	if not baseGameProcessSize then
		baseGameProcessSize = gameProcessGui.Size
	end

	local targetSize = getGameProcessCarrySize(carrying)
	if not targetSize then
		return
	end

	if carrySizeTween then
		carrySizeTween:Cancel()
		carrySizeTween = nil
	end

	carrySizeTween = TweenService:Create(gameProcessGui, CARRY_SIZE_TWEEN_INFO, { Size = targetSize })
	carrySizeTween:Play()
end

local function bindCarrySizeScaling()
	local function onCarryChanged()
		updateGameProcessCarrySize(localPlayer:GetAttribute("CarryingLuckyBlock") == true)
	end

	localPlayer:GetAttributeChangedSignal("CarryingLuckyBlock"):Connect(onCarryChanged)
	onCarryChanged()
end

local function findTimeLeftLabel(frame: Instance): TextLabel?
	local label = frame:FindFirstChild("TimeLeft", true)
	if label and label:IsA("TextLabel") then
		return label
	end
	return nil
end

local function findMainUiChild(main: Instance, name: string): Instance?
	local topFrames = main:FindFirstChild("TopFrames")
	if topFrames then
		local direct = topFrames:FindFirstChild(name)
		if direct then
			return direct
		end
	end

	return main:FindFirstChild(name, true)
end

local function waitForMainUiChild(main: Instance, name: string): Instance?
	local topFrames = main:WaitForChild("TopFrames", 30)
	if topFrames then
		local direct = topFrames:WaitForChild(name, 30)
		if direct then
			return direct
		end
	end

	return main:FindFirstChild(name, true)
end

local function findGradient(root: Instance, gradientName: string): UIGradient?
	local direct = root:FindFirstChild(gradientName)
	if direct and direct:IsA("UIGradient") then
		return direct
	end

	for _, descendant in root:GetDescendants() do
		if descendant.Name == gradientName and descendant:IsA("UIGradient") then
			return descendant
		end
	end

	return nil
end

local function resolveEntranceWallUi(): EntranceWallUi
	local gameFolder = Workspace:FindFirstChild("Game")
	local mapFolder = gameFolder and gameFolder:FindFirstChild("Map")
	local wall = mapFolder and mapFolder:FindFirstChild(ENTRANCE_WALL_NAME)
	if not wall or not wall:IsA("BasePart") then
		entranceWallUi = {}
		return entranceWallUi
	end

	if entranceWallUi.surfaceGui and entranceWallUi.surfaceGui:IsDescendantOf(wall) then
		return entranceWallUi
	end

	entranceWallUi = {}

	local surfaceGui = wall:FindFirstChildOfClass("SurfaceGui")
	if not surfaceGui then
		return entranceWallUi
	end

	local frame = surfaceGui:FindFirstChild("Frame")
	if not frame or not frame:IsA("Frame") then
		entranceWallUi.surfaceGui = surfaceGui
		return entranceWallUi
	end

	local messageLabel = frame:FindFirstChild("TextLabel")
	if messageLabel and messageLabel:IsA("TextLabel") then
		entranceWallUi.messageLabel = messageLabel
	end

	local timeLabel = frame:FindFirstChild("Time")
	if timeLabel and timeLabel:IsA("TextLabel") then
		entranceWallUi.timeLabel = timeLabel
	end

	entranceWallUi.surfaceGui = surfaceGui
	entranceWallUi.frame = frame
	entranceWallUi.newMapGradient = findGradient(frame, "NewMapGradient")
	entranceWallUi.raceStartsGradient = findGradient(frame, "RaceStartsGradient")
	entranceWallUi.relaxMapGradient = findGradient(frame, "RelaxGradient")
		or findGradient(frame, "RelaxMapGradient")
		or findGradient(frame, "RelaxTimeGradient")

	return entranceWallUi
end

local function setGradientEnabled(gradient: UIGradient?, enabled: boolean)
	if gradient then
		gradient.Enabled = enabled
	end
end

local function updateEntranceWallUi(phase: string?, timeLeft: number)
	local ui = resolveEntranceWallUi()
	if not ui.surfaceGui then
		return
	end

	local isNewMap = phase == Shared_GameProcess.ProcessPhase.NewMap
	local isRaceStarts = phase == Shared_GameProcess.ProcessPhase.RaceStarts
	local isRelax = phase == Shared_GameProcess.ProcessPhase.Relax
	local showStatus = isNewMap or isRaceStarts or isRelax

	ui.surfaceGui.Enabled = showStatus
	if ui.frame then
		ui.frame.Visible = showStatus
	end

	setGradientEnabled(ui.newMapGradient, false)
	setGradientEnabled(ui.raceStartsGradient, false)
	setGradientEnabled(ui.relaxMapGradient, false)

	if not showStatus then
		return
	end

	local formattedTime = formatTimeLeft(timeLeft)
	if ui.timeLabel then
		ui.timeLabel.Text = formattedTime
	end

	if isNewMap then
		if ui.messageLabel then
			ui.messageLabel.Text = Shared_GameProcess.EntranceWallNewMapMessage
		end
		setGradientEnabled(ui.newMapGradient, true)
	elseif isRaceStarts then
		if ui.messageLabel then
			ui.messageLabel.Text = Shared_GameProcess.EntranceWallRaceStartsMessage
		end
		setGradientEnabled(ui.raceStartsGradient, true)
	elseif isRelax then
		if ui.messageLabel then
			ui.messageLabel.Text = Shared_GameProcess.EntranceWallRelaxMessage
		end
		setGradientEnabled(ui.relaxMapGradient, true)
	end
end

local function resolveUi()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	local main = playerGui and playerGui:FindFirstChild("Main")
	if not main then
		return false
	end

	local foundGui = findMainUiChild(main, "GameProcess")
	if not foundGui or not foundGui:IsA("GuiObject") then
		return false
	end

	gameProcessGui = foundGui
	if not baseGameProcessSize then
		baseGameProcessSize = foundGui.Size
	end

	for _, phaseName in PHASES do
		local frame = foundGui:FindFirstChild(phaseName, true)
		if frame and frame:IsA("GuiObject") then
			phaseFrames[phaseName] = frame
			local timeLeft = findTimeLeftLabel(frame)
			if timeLeft then
				timeLeftLabels[phaseName] = timeLeft
			end
			if phaseName == Shared_GameProcess.ProcessPhase.Relax then
				phaseGradients[phaseName] = findGradient(frame, "RelaxGradient")
					or findGradient(frame, "RelaxMapGradient")
					or findGradient(frame, "RelaxTimeGradient")
			else
				phaseGradients[phaseName] = findGradient(frame, `{phaseName}Gradient`)
			end
		end
	end

	return next(phaseFrames) ~= nil
end

local function getGameFolder(): Instance?
	return Workspace:FindFirstChild("Game")
end

local function getPhaseTimeLeft(): (string?, number)
	local gameFolder = getGameFolder()
	if not gameFolder then
		return nil, 0
	end

	local phase = gameFolder:GetAttribute("ProcessPhase")
	local endTime = gameFolder:GetAttribute("ProcessPhaseEndTime")
	if type(phase) ~= "string" or type(endTime) ~= "number" then
		return nil, 0
	end

	local timeLeft = endTime - Workspace:GetServerTimeNow()
	return phase, timeLeft
end

local function updateUi(force: boolean?)
	local now = os.clock()
	if not force and now - lastUiUpdateAt < UI_UPDATE_INTERVAL then
		return
	end
	lastUiUpdateAt = now

	local phase, timeLeft = getPhaseTimeLeft()
	local formattedTime = formatTimeLeft(timeLeft)

	if phase == Shared_GameProcess.ProcessPhase.RaceEnds and lastProcessPhase ~= phase then
		playSuccessSfx()
	end
	if phase ~= lastProcessPhase then
		lastProcessPhase = phase
	end

	if gameProcessGui then
		local hasActivePhase = phase ~= nil and phaseFrames[phase] ~= nil
		gameProcessGui.Visible = hasActivePhase

		for phaseName, frame in phaseFrames do
			local isActive = phaseName == phase
			frame.Visible = isActive

			local label = timeLeftLabels[phaseName]
			if label and isActive then
				label.Text = formattedTime
			end

			local gradient = phaseGradients[phaseName]
			if gradient then
				gradient.Enabled = isActive
			end
		end
	end

	if phase ~= lastEntranceWallUiPhase then
		lastEntranceWallUiPhase = phase
		updateEntranceWallUi(phase, timeLeft)
	elseif entranceWallUi.timeLabel and phase ~= nil then
		local formattedTime = formatTimeLeft(timeLeft)
		entranceWallUi.timeLabel.Text = formattedTime
	end
end

local function bindEntranceWallWatcher()
	local gameFolder = Workspace:WaitForChild("Game", 30)
	if not gameFolder then
		return
	end

	local mapFolder = gameFolder:WaitForChild("Map", 30)
	if not mapFolder then
		return
	end

	mapFolder.ChildAdded:Connect(function(child)
		if child.Name == ENTRANCE_WALL_NAME then
			entranceWallUi = {}
			lastEntranceWallUiPhase = nil
			updateUi(true)
		end
	end)

	mapFolder.ChildRemoved:Connect(function(child)
		if child.Name == ENTRANCE_WALL_NAME then
			entranceWallUi = {}
		end
	end)
end

local function bindRaceTimeRanOutHandler()
	local events = ReplicatedStorage:WaitForChild("Events", 10)
	local gameProcessHandler = events and events:WaitForChild("GameProcessHandler", 10)
	if not gameProcessHandler or not gameProcessHandler:IsA("RemoteEvent") then
		return
	end

	gameProcessHandler.OnClientEvent:Connect(function(action: string, message: any)
		if action == "RaceTimeRanOut" and type(message) == "string" then
			Client_Messaging.Show(message, "red")
		end
	end)
end

function Client_GameProcess.Init()
	bindRaceTimeRanOutHandler()

	task.spawn(function()
		local playerGui = localPlayer:WaitForChild("PlayerGui", 30)
		if not playerGui then
			return
		end

		local main = playerGui:WaitForChild("Main", 30)
		if not main then
			return
		end

		if not resolveUi() then
			waitForMainUiChild(main, "GameProcess")
			if not resolveUi() then
				local connection: RBXScriptConnection?
				connection = main.DescendantAdded:Connect(function(descendant)
					if descendant.Name ~= "GameProcess" or not descendant:IsA("GuiObject") then
						return
					end
					if resolveUi() and connection then
						connection:Disconnect()
						updateUi()
					end
				end)
			else
				updateUi()
			end
		end

		bindEntranceWallWatcher()
		bindCarrySizeScaling()

		local gameFolder = Workspace:WaitForChild("Game", 30)
		if gameFolder then
			gameFolder:GetAttributeChangedSignal("ProcessPhase"):Connect(function()
				updateUi(true)
			end)
			gameFolder:GetAttributeChangedSignal("ProcessPhaseEndTime"):Connect(function()
				updateUi(true)
			end)
		end

		RunService.Heartbeat:Connect(updateUi)
		updateUi(true)
	end)
end

return Client_GameProcess
