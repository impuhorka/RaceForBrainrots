local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_GameProcess = SharedModules.require("Shared_GameProcess")

local MapProcessBuildTiming = require(script.Parent.MapProcessBuildTiming)
local MapProcessDecorationQuery = require(script.Parent.MapProcessDecorationQuery)
local MapProcessMapContent = require(script.Parent.MapProcessMapContent)

local GameProcessFloors = {}

local mapDecorationsSpawned = false

function GameProcessFloors.SpawnPersistentMapDecorations()
	if mapDecorationsSpawned then
		return
	end

	local floorsFolder = MapProcessMapContent.getFloorsFolder()
	if not MapProcessMapContent.hasMapGeometry(floorsFolder) then
		return
	end

	local context, buildEntries = MapProcessMapContent.getLayoutGenerationInputs()
	if not context or not buildEntries then
		return
	end

	for index, entry in buildEntries do
		MapProcessMapContent.placeHoleFloorDecorationsForFloor(
			entry.holeLayout,
			context.decorationTemplates,
			context.flowerTemplates,
			context.grassTemplates,
			context.mushroomTemplates,
			entry.rarityName,
			floorsFolder
		)
		MapProcessMapContent.placeVIPHoleFloorDecorationsForFloor(
			entry.holeLayout,
			context.decorationTemplates,
			context.flowerTemplates,
			context.grassTemplates,
			context.mushroomTemplates,
			entry.rarityName,
			floorsFolder
		)
		if index % 2 == 0 then
			task.wait()
		end
	end

	for index, entry in buildEntries do
		MapProcessMapContent.placeLianasOnRarityWalls(floorsFolder, entry.rarityName, context.lianaTemplates, floorsFolder)
		MapProcessMapContent.placeLiliesOnRarityWalls(floorsFolder, entry.rarityName, context.lilyTemplate, floorsFolder)
		if index % 2 == 0 then
			task.wait()
		end
	end

	mapDecorationsSpawned = true
end

function GameProcessFloors.PrepareNextMapDuringRelax()
	if not mapDecorationsSpawned then
		GameProcessFloors.SpawnPersistentMapDecorations()
	end

	local floorsFolder = MapProcessMapContent.getFloorsFolder()
	local context, buildEntries = MapProcessMapContent.getLayoutGenerationInputs()
	if not context or not buildEntries then
		return
	end

	for _, luckyBlock in MapProcessMapContent.collectLuckyBlocks(floorsFolder) do
		luckyBlock:Destroy()
	end

	local decorationModels = MapProcessDecorationQuery.collectMapDecorationModels(floorsFolder)
	local zoneIndex = MapProcessDecorationQuery.buildZoneDecorationIndex(decorationModels)

	local buildStartTime, buildEndTime =
		MapProcessBuildTiming.beginBuildWindow(Shared_GameProcess.RelaxDuration)
	local buildId = math.floor(buildStartTime * 1000)
	local zoneCount = #buildEntries * 2
	local totalSlots = math.max(
		MapProcessDecorationQuery.countNonTreeDecorationSteps(decorationModels)
			+ zoneCount * Shared_GameProcess.TreesPerMinimap.Max,
		1
	)
	MapProcessBuildTiming.setMapBuildAttributes(buildId, buildStartTime, buildEndTime, totalSlots)

	local stepper = MapProcessBuildTiming.makePacedStepper(buildStartTime, buildEndTime, totalSlots)

	for _, entry in buildEntries do
		local zones = {
			{ holeFloor = entry.holeLayout.leftHoleFloor, holeSide = "Left" },
			{ holeFloor = entry.holeLayout.rightHoleFloor, holeSide = "Right" },
		}

		for _, zone in zones do
			local zoneModels = MapProcessDecorationQuery.getZoneModels(zoneIndex, entry.rarityName, zone.holeSide)
			local placedSpots =
				MapProcessMapContent.repositionMinimapDecorationsOnly(zone.holeFloor, zoneModels, stepper.pace)
			MapProcessMapContent.refreshMinimapTreesRandom(
				zone.holeFloor,
				context.decorationTemplates,
				entry.rarityName,
				zone.holeSide,
				floorsFolder,
				zoneModels,
				placedSpots,
				stepper.pace
			)
		end
	end
end

function GameProcessFloors.ExecuteNewMapLuckyBlockSpawn()
	if not mapDecorationsSpawned then
		GameProcessFloors.SpawnPersistentMapDecorations()
	end

	local floorsFolder = MapProcessMapContent.getFloorsFolder()
	local _context, buildEntries = MapProcessMapContent.getLayoutGenerationInputs()
	if not buildEntries then
		return
	end

	local decorationModels = MapProcessDecorationQuery.collectMapDecorationModels(floorsFolder)
	local zoneIndex = MapProcessDecorationQuery.buildZoneDecorationIndex(decorationModels)
	local spawnPlans, totalSlots = MapProcessMapContent.buildLuckyZoneSpawnPlans(buildEntries, floorsFolder, zoneIndex)
	totalSlots = math.max(totalSlots, 1)

	local buildStartTime, buildEndTime =
		MapProcessBuildTiming.beginBuildWindow(Shared_GameProcess.NewMapBuildDuration)
	local buildId = math.floor(buildStartTime * 1000)
	MapProcessBuildTiming.setMapBuildAttributes(buildId, buildStartTime, buildEndTime, totalSlots)

	for _, luckyBlock in MapProcessMapContent.collectLuckyBlocks(floorsFolder) do
		luckyBlock:Destroy()
	end

	local stepper = MapProcessBuildTiming.makePacedStepper(buildStartTime, buildEndTime, totalSlots)

	for _, plan in spawnPlans do
		MapProcessMapContent.spawnLuckyBlocksForHoleFloor(
			plan.holeFloor,
			plan.luckyBlockTemplate,
			plan.configName,
			plan.rarityName,
			plan.holeSide,
			plan.decorationSpots,
			plan.parent,
			plan.luckyBlockCount,
			stepper.pace
		)
	end
end

function GameProcessFloors.EnsureMapGeometry(): boolean
	local floorsFolder = MapProcessMapContent.getFloorsFolder()
	if MapProcessMapContent.hasMapGeometry(floorsFolder) then
		MapProcessMapContent.ensureJumpBarrier()
		return true
	end
	return MapProcessMapContent.buildMapGeometry(floorsFolder)
end

return GameProcessFloors
