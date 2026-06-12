local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_GameProcess = SharedModules.require("Shared_GameProcess")
local Shared_RoadGradient = SharedModules.require("Shared_RoadGradient")
local GameProcessEntranceWall = require(script.Parent.GameProcessEntranceWall)
local GameProcessFloors = require(script.Parent.GameProcessFloors)
local GameProcessService = require(script.Parent.GameProcessService)

local GameProcessCycle = {}

local plotService: any = nil

local PHASE_ORDER = {
	Shared_GameProcess.ProcessPhase.NewMap,
	Shared_GameProcess.ProcessPhase.RaceStarts,
	Shared_GameProcess.ProcessPhase.RaceEnds,
	Shared_GameProcess.ProcessPhase.Relax,
}

local function waitForPhaseEnd()
	while true do
		local gameFolder = Workspace:FindFirstChild("Game")
		local phaseEndTime = gameFolder and gameFolder:GetAttribute("ProcessPhaseEndTime")
		if type(phaseEndTime) ~= "number" then
			break
		end

		local remaining = phaseEndTime - Workspace:GetServerTimeNow()
		if remaining <= 0 then
			break
		end

		task.wait(math.min(remaining, 0.25))
	end
end

local function setPhase(phase: string, duration: number)
	local gameFolder = GameProcessEntranceWall.EnsureGameFolder()
	local now = Workspace:GetServerTimeNow()
	local phaseEndTime = now + duration
	gameFolder:SetAttribute("ProcessPhase", phase)
	gameFolder:SetAttribute("ProcessPhaseStartTime", now)
	gameFolder:SetAttribute("ProcessPhaseEndTime", phaseEndTime)

	if phase == Shared_GameProcess.ProcessPhase.NewMap then
		gameFolder:SetAttribute("MapBuildStartTime", now)
		gameFolder:SetAttribute("MapBuildEndTime", now + Shared_GameProcess.NewMapBuildDuration)
	elseif phase == Shared_GameProcess.ProcessPhase.Relax then
		gameFolder:SetAttribute("MapBuildStartTime", now)
		gameFolder:SetAttribute("MapBuildEndTime", phaseEndTime)
	else
		gameFolder:SetAttribute("MapBuildStartTime", nil)
		gameFolder:SetAttribute("MapBuildEndTime", nil)
	end
end

local function runNewMapPhase()
	GameProcessEntranceWall.Show()
	GameProcessService.ClearForMapReset()
	GameProcessFloors.EnsureMapGeometry()

	setPhase(Shared_GameProcess.ProcessPhase.NewMap, Shared_GameProcess.NewMapBuildDuration)

	task.spawn(function()
		GameProcessFloors.ExecuteNewMapLuckyBlockSpawn()
	end)

	waitForPhaseEnd()
end

local function runRaceStartsPhase()
	GameProcessEntranceWall.Show()

	setPhase(Shared_GameProcess.ProcessPhase.RaceStarts, Shared_GameProcess.RaceStartsDuration)
	waitForPhaseEnd()
end

local function isPlayerOnRoad(player: Player): boolean
	local zones = Workspace:FindFirstChild("Zones")
	local enterPart = zones and zones:FindFirstChild("EnterPart")
	if not enterPart or not enterPart:IsA("BasePart") then
		return false
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	local roadNearZ, roadFarZ = Shared_RoadGradient.GetRoadBounds(enterPart)
	return Shared_RoadGradient.IsOnRoad(root.Position.Z, roadNearZ, roadFarZ)
end

local function getRoadPlayersCarryingAtRaceEnd(): ({ Player }, { [Player]: boolean })
	local roadPlayers: { Player } = {}
	local carryingPlayers: { [Player]: boolean } = {}

	for _, player in Players:GetPlayers() do
		if GameProcessService.IsPlayerCarrying(player) or player:GetAttribute("CarryingLuckyBlock") == true then
			carryingPlayers[player] = true
		end

		if isPlayerOnRoad(player) then
			table.insert(roadPlayers, player)
		end
	end

	return roadPlayers, carryingPlayers
end

local function teleportRoadPlayersHome(roadPlayers: { Player }, carryingPlayers: { [Player]: boolean })
	if not plotService then
		return
	end

	for _, player in roadPlayers do
		plotService:TeleportPlayerToPlot(player)
		if not carryingPlayers[player] then
			GameProcessService.NotifyRaceTimeRanOut(player)
		end
	end
end

local function runRaceEndsPhase()
	GameProcessEntranceWall.Hide()

	setPhase(Shared_GameProcess.ProcessPhase.RaceEnds, Shared_GameProcess.RaceEndsDuration)
	waitForPhaseEnd()

	task.spawn(function()
		local roadPlayers, carryingPlayers = getRoadPlayersCarryingAtRaceEnd()
		GameProcessService.OnRaceEnded()
		teleportRoadPlayersHome(roadPlayers, carryingPlayers)
	end)
end

local function runRelaxPhase()
	GameProcessEntranceWall.Show()
	GameProcessService.ClearForMapReset()

	setPhase(Shared_GameProcess.ProcessPhase.Relax, Shared_GameProcess.RelaxDuration)

	task.spawn(function()
		GameProcessFloors.PrepareNextMapDuringRelax()
	end)

	waitForPhaseEnd()
end

local PHASE_RUNNERS = {
	[Shared_GameProcess.ProcessPhase.NewMap] = runNewMapPhase,
	[Shared_GameProcess.ProcessPhase.RaceStarts] = runRaceStartsPhase,
	[Shared_GameProcess.ProcessPhase.RaceEnds] = runRaceEndsPhase,
	[Shared_GameProcess.ProcessPhase.Relax] = runRelaxPhase,
}

local function runCycleLoop()
	while true do
		for _, phase in PHASE_ORDER do
			local runner = PHASE_RUNNERS[phase]
			if runner then
				runner()
			end
		end
	end
end

function GameProcessCycle.SetPlotService(service: any)
	plotService = service
end

function GameProcessCycle.Init()
	GameProcessEntranceWall.Init()
	GameProcessFloors.EnsureMapGeometry()
	GameProcessFloors.SpawnPersistentMapDecorations()
	task.spawn(runCycleLoop)
end

return GameProcessCycle
