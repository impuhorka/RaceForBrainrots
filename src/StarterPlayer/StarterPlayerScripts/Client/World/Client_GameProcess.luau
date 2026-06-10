local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SharedModules = require(game:GetService("ReplicatedStorage").Modules.Loader)
local Shared_GameProcess = SharedModules.require("Shared_GameProcess")

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
local timeLeftLabels: { [string]: TextLabel } = {}
local entranceWallUi: EntranceWallUi = {}

local function formatTimeLeft(seconds: number): string
	return string.format("%.1f seconds", math.max(0, seconds))
end

local function findTimeLeftLabel(frame: Instance): TextLabel?
	local label = frame:FindFirstChild("TimeLeft", true)
	if label and label:IsA("TextLabel") then
		return label
	end
	return nil
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
	entranceWallUi.relaxMapGradient = findGradient(frame, "RelaxMapGradient")

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

	local foundGui = main:FindFirstChild("GameProcess")
	if not foundGui or not foundGui:IsA("GuiObject") then
		return false
	end

	gameProcessGui = foundGui

	for _, phaseName in PHASES do
		local frame = foundGui:FindFirstChild(phaseName, true)
		if frame and frame:IsA("GuiObject") then
			phaseFrames[phaseName] = frame
			local timeLeft = findTimeLeftLabel(frame)
			if timeLeft then
				timeLeftLabels[phaseName] = timeLeft
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

local function updateUi()
	local phase, timeLeft = getPhaseTimeLeft()
	local formattedTime = formatTimeLeft(timeLeft)

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
		end
	end

	updateEntranceWallUi(phase, timeLeft)
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
			updateUi()
		end
	end)

	mapFolder.ChildRemoved:Connect(function(child)
		if child.Name == ENTRANCE_WALL_NAME then
			entranceWallUi = {}
		end
	end)
end

function Client_GameProcess.Init()
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
			local connection: RBXScriptConnection?
			connection = main.ChildAdded:Connect(function(child)
				if child.Name ~= "GameProcess" then
					return
				end
				if resolveUi() and connection then
					connection:Disconnect()
					updateUi()
				end
			end)
		end

		bindEntranceWallWatcher()

		local gameFolder = Workspace:WaitForChild("Game", 30)
		if gameFolder then
			gameFolder:GetAttributeChangedSignal("ProcessPhase"):Connect(updateUi)
			gameFolder:GetAttributeChangedSignal("ProcessPhaseEndTime"):Connect(updateUi)
		end

		RunService.RenderStepped:Connect(updateUi)
		updateUi()
	end)
end

return Client_GameProcess
