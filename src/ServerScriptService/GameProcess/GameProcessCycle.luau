local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_GameProcess = SharedModules.require("Shared_GameProcess")
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

local function setPhase(phase: string, duration: number)
	local gameFolder = GameProcessEntranceWall.EnsureGameFolder()
	gameFolder:SetAttribute("ProcessPhase", phase)
	gameFolder:SetAttribute("ProcessPhaseEndTime", Workspace:GetServerTimeNow() + duration)
end

local function runNewMapPhase()
	GameProcessEntranceWall.Show()
	GameProcessService.ClearForMapReset()
	GameProcessFloors.ClearMapContent()
	GameProcessFloors.EnsureMapGeometry()

	local duration = Shared_GameProcess.NewMapDuration
	local buildDuration = Shared_GameProcess.NewMapBuildDuration
	setPhase(Shared_GameProcess.ProcessPhase.NewMap, duration)

	local phaseStart = os.clock()
	GameProcessFloors.BuildMapContentAsync(buildDuration)
	local remaining = duration - (os.clock() - phaseStart)
	if remaining > 0 then
		task.wait(remaining)
	end
end

local function runRaceStartsPhase()
	GameProcessEntranceWall.Show()

	local duration = Shared_GameProcess.RaceStartsDuration
	setPhase(Shared_GameProcess.ProcessPhase.RaceStarts, duration)
	task.wait(duration)
end

local function teleportAllPlayersHome()
	if not plotService then
		return
	end

	for _, player in Players:GetPlayers() do
		plotService:TeleportPlayerToPlot(player)
	end
end

local function runRaceEndsPhase()
	GameProcessEntranceWall.Hide()

	local duration = Shared_GameProcess.RaceEndsDuration
	setPhase(Shared_GameProcess.ProcessPhase.RaceEnds, duration)
	task.wait(duration)

	GameProcessService.OnRaceEnded()
	teleportAllPlayersHome()
end

local function runRelaxPhase()
	GameProcessEntranceWall.Show()
	GameProcessService.ClearForMapReset()
	GameProcessFloors.ClearMapContent()

	local duration = Shared_GameProcess.RelaxDuration
	setPhase(Shared_GameProcess.ProcessPhase.Relax, duration)
	task.wait(duration)
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
	task.spawn(runCycleLoop)
end

return GameProcessCycle
