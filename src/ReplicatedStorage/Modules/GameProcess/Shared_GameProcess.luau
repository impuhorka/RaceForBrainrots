local Workspace = game:GetService("Workspace")

local Shared_GameProcess = {}

Shared_GameProcess.WallFrontOpening = 125
Shared_GameProcess.HoleFloorSize = 80
Shared_GameProcess.MinimapFloorColor = Color3.fromRGB(74, 154, 56)
Shared_GameProcess.EntranceFloorColor = Color3.fromRGB(15, 32, 10)
Shared_GameProcess.EntranceDepth = 2
Shared_GameProcess.TreesPerMinimap = { Min = 3, Max = 6 }
Shared_GameProcess.TreeOverlapPadding = 14
Shared_GameProcess.MinRocksPerMinimap = 4
Shared_GameProcess.RockScaleMin = 0.9
Shared_GameProcess.RockScaleMax = 1.35
Shared_GameProcess.BushScaleMin = 0.9
Shared_GameProcess.BushScaleMax = 1.15
Shared_GameProcess.TreeScaleMin = 0.85
Shared_GameProcess.TreeScaleMax = 1.1
Shared_GameProcess.MinBushesPerMinimap = 3
Shared_GameProcess.BushOverlapPadding = 10
Shared_GameProcess.FlowersPerMinimap = { Min = 4, Max = 6 }
Shared_GameProcess.GroundFlowersPerStack = { Min = 1, Max = 3 }
Shared_GameProcess.GroundFlowerStackSpread = 2
Shared_GameProcess.GrassStacksPerMinimap = { Min = 3, Max = 6 }
Shared_GameProcess.GrassPerStack = { Min = 1, Max = 2 }
Shared_GameProcess.GrassStackSpread = 2
Shared_GameProcess.MushroomsPerMinimap = { Min = 2, Max = 5 }
Shared_GameProcess.LuckyBlocksPerHole = { Min = 5, Max = 7 }
Shared_GameProcess.DecorationScaleMin = 0.8
Shared_GameProcess.DecorationScaleMax = 1
Shared_GameProcess.DecorationEdgeMargin = 1
Shared_GameProcess.PlacementOverlapPadding = 3
Shared_GameProcess.PlacementMaxAttempts = 30
Shared_GameProcess.LuckyBlockOverlapPadding = 8
Shared_GameProcess.LuckyBlockPlacementMaxAttempts = 60
Shared_GameProcess.LianasRoadWallSegmentLength = 100
Shared_GameProcess.LianasMinimapWallSegmentLength = 140
Shared_GameProcess.LianasMaxPerRoadWall = 10
Shared_GameProcess.LianasMaxPerMinimapWall = 2
Shared_GameProcess.LianaWallEdgeMargin = 1.5
Shared_GameProcess.LianaMinSpacing = 32
Shared_GameProcess.LianaScaleMin = 0.75
Shared_GameProcess.LianaScaleMax = 0.9
Shared_GameProcess.LiliesRoadWallSegmentLength = 120
Shared_GameProcess.LiliesMinimapWallSegmentLength = 160
Shared_GameProcess.LiliesMaxPerRoadWall = 6
Shared_GameProcess.LiliesMaxPerMinimapWall = 2
Shared_GameProcess.LilyMinSpacing = 24
Shared_GameProcess.LilyScaleMin = 0.9
Shared_GameProcess.LilyScaleMax = 1.1
Shared_GameProcess.LilyWallClearance = 0.08
Shared_GameProcess.MinimapLilyYawFlipDegrees = 180
Shared_GameProcess.WorldLuckyBlockFloatHeight = 0.6
Shared_GameProcess.WorldLuckyBlockFloatHeightScale = 0.08
Shared_GameProcess.WorldLuckyBlockMinFloorClearance = 0.35
Shared_GameProcess.WorldLuckyBlockMinClearanceScale = 0.06
Shared_GameProcess.WorldLuckyBlockFloatSpeed = 1.25
Shared_GameProcess.WorldLuckyBlockRotateSpeed = 25
Shared_GameProcess.CarriedLuckyBlockTopOffset = .5
Shared_GameProcess.LuckyBlockDeliverZLead = 4
Shared_GameProcess.DroppedLuckyBlockDespawnSeconds = 15
Shared_GameProcess.WorldDropMinRadius = 10
Shared_GameProcess.WorldDropMaxRadius = 12
Shared_GameProcess.WorldDropMaxAttempts = 16
Shared_GameProcess.WorldDropForwardConeDegrees = 140
Shared_GameProcess.WorldDropWallClearance = 0.45
Shared_GameProcess.WorldDropMaxFloorDelta = 8
Shared_GameProcess.WorldDropMaxClientPositionError = 25
Shared_GameProcess.WorldDropSizeReferenceHeight = 4
Shared_GameProcess.WorldDropRadiusScaleMin = 0.85
Shared_GameProcess.WorldDropRadiusScaleMax = 2.25

Shared_GameProcess.ProcessPhase = {
	NewMap = "NewMap",
	RaceStarts = "RaceStarts",
	RaceEnds = "RaceEnds",
	Relax = "Relax",
}

Shared_GameProcess.NewMapBuildDuration = 10
Shared_GameProcess.RaceStartsDuration = 5
Shared_GameProcess.RaceEndsDuration = 60
Shared_GameProcess.RelaxDuration = 10

function Shared_GameProcess.IsRaceActivePhase(phase: string?): boolean
	if type(phase) ~= "string" then
		return false
	end
	return phase == Shared_GameProcess.ProcessPhase.RaceStarts
		or phase == Shared_GameProcess.ProcessPhase.RaceEnds
end

Shared_GameProcess.EntranceWallNewMapMessage = "Map is building!"
Shared_GameProcess.EntranceWallRaceStartsMessage = "Race starting!"
Shared_GameProcess.EntranceWallRelaxMessage = "Relax"
Shared_GameProcess.UnluckyMapCloseMessage = "Unlucky! The map closed — your Lucky Block is gone!"
Shared_GameProcess.UnluckyRaceEndMessage = "Unlucky! Next time maybe."
Shared_GameProcess.RaceTimeRanOutMessage = "Time ran out!"
Shared_GameProcess.AlreadyCarryingLuckyBlockMessage = "You're already carrying a Lucky Block!"
Shared_GameProcess.VIPMinimapExtensionDepth = 75
Shared_GameProcess.VIPMinimapCloserOffset = 20
Shared_GameProcess.VIPGamepassConfigKey = "VIP"
Shared_GameProcess.VIPLuckyBlocksPerHole = 4
Shared_GameProcess.VIPMinimapWeightLuckMultiplier = 2.5
Shared_GameProcess.VIPDecorationsPerHole = {
	Rocks = 1,
	Bushes = 1,
	GrassStacks = 1,
	Flowers = 1,
}
Shared_GameProcess.VIPRequiredPickupMessage = "You need VIP to collect lucky blocks from this area!"

function Shared_GameProcess.HasVIPMinimapExtension(rarityName: string): boolean
	return rarityName ~= "Common" and rarityName ~= "Rare"
end

function Shared_GameProcess.GetScheduledSlotTime(
	phaseStartTime: number,
	slotIndex: number,
	totalSlots: number,
	activeDuration: number
): number
	if totalSlots <= 0 or slotIndex <= 0 then
		return phaseStartTime
	end
	local clampedSlot = math.clamp(slotIndex, 1, totalSlots)
	return phaseStartTime + (clampedSlot / totalSlots) * activeDuration
end

function Shared_GameProcess.GetMapRevealInterval(totalSlots: number, buildDuration: number): number
	if totalSlots <= 0 or buildDuration <= 0 then
		return buildDuration
	end
	return buildDuration / totalSlots
end

function Shared_GameProcess.GetMapRevealItemsPerSecond(totalSlots: number, buildDuration: number): number
	local interval = Shared_GameProcess.GetMapRevealInterval(totalSlots, buildDuration)
	if interval <= 0 then
		return totalSlots
	end
	return 1 / interval
end

-- Never burst past-due slots; keep at least one even interval between reveals.
function Shared_GameProcess.WaitForPacedReveal(
	buildStartTime: number,
	slotIndex: number,
	totalSlots: number,
	buildDuration: number,
	lastRevealAt: number?
): number
	if totalSlots <= 0 or slotIndex <= 0 then
		return Workspace:GetServerTimeNow()
	end

	local minInterval = Shared_GameProcess.GetMapRevealInterval(totalSlots, buildDuration)
	local targetTime = Shared_GameProcess.GetScheduledSlotTime(buildStartTime, slotIndex, totalSlots, buildDuration)
	local minTime = if type(lastRevealAt) == "number" then lastRevealAt + minInterval else buildStartTime
	local waitUntil = math.max(targetTime, minTime)
	local delay = waitUntil - Workspace:GetServerTimeNow()
	if delay > 0 then
		task.wait(delay)
	end
	return Workspace:GetServerTimeNow()
end

function Shared_GameProcess.GetWorldDropRadiusScale(modelHeight: number): number
	local referenceHeight = Shared_GameProcess.WorldDropSizeReferenceHeight
	local minScale = Shared_GameProcess.WorldDropRadiusScaleMin
	local maxScale = Shared_GameProcess.WorldDropRadiusScaleMax
	if referenceHeight <= 0 then
		return 1
	end
	return math.clamp(modelHeight / referenceHeight, minScale, maxScale)
end

function Shared_GameProcess.GetWorldLuckyBlockFloatHeight(modelHeight: number): number
	local baseHeight = Shared_GameProcess.WorldLuckyBlockFloatHeight
	local scaledHeight = modelHeight * Shared_GameProcess.WorldLuckyBlockFloatHeightScale
	return math.max(baseHeight, scaledHeight)
end

function Shared_GameProcess.GetWorldLuckyBlockMinFloorClearance(modelHeight: number): number
	local baseClearance = Shared_GameProcess.WorldLuckyBlockMinFloorClearance
	local scaledClearance = modelHeight * Shared_GameProcess.WorldLuckyBlockMinClearanceScale
	return math.max(baseClearance, scaledClearance)
end

function Shared_GameProcess.GetWorldLuckyBlockSpawnLift(modelHeight: number): number
	return Shared_GameProcess.GetWorldLuckyBlockFloatHeight(modelHeight)
		+ Shared_GameProcess.GetWorldLuckyBlockMinFloorClearance(modelHeight)
end

function Shared_GameProcess.GetFlatYaw(rotation: CFrame): number
	local _, yaw, _ = rotation:ToEulerAnglesYXZ()
	return yaw
end

function Shared_GameProcess.GetFlatYawRotation(rotation: CFrame): CFrame
	return CFrame.Angles(0, Shared_GameProcess.GetFlatYaw(rotation), 0)
end

function Shared_GameProcess.YawRotation(yaw: number): CFrame
	return CFrame.Angles(0, yaw, 0)
end

-- Road segment length per rarity (-Z). Keep each size >= WallFrontOpening so minimaps fit.
Shared_GameProcess.FloorSizeByRarity = {
	Common = 200,
	Rare = 260,
	Epic = 340,
	Legendary = 420,
	Mythical = 500,
	Secret = 580,
	Divine = 660,
	Superior = 740,
}

function Shared_GameProcess.GetFloorSize(rarity: string): number?
	local size = Shared_GameProcess.FloorSizeByRarity[rarity]
	if type(size) == "number" and size > 0 then
		return size
	end
	return nil
end

return Shared_GameProcess
