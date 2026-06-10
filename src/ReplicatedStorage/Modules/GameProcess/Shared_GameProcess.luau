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
Shared_GameProcess.FlowersPerMinimap = { Min = 8, Max = 10 }
Shared_GameProcess.GroundFlowersPerStack = { Min = 2, Max = 5 }
Shared_GameProcess.GroundFlowerStackSpread = 2
Shared_GameProcess.GrassStacksPerMinimap = { Min = 14, Max = 22 }
Shared_GameProcess.GrassPerStack = { Min = 2, Max = 5 }
Shared_GameProcess.GrassStackSpread = 2
Shared_GameProcess.LuckyBlocksPerHole = { Min = 5, Max = 7 }
Shared_GameProcess.DecorationScaleMin = 0.8
Shared_GameProcess.DecorationScaleMax = 1
Shared_GameProcess.DecorationEdgeMargin = 1
Shared_GameProcess.PlacementOverlapPadding = 3
Shared_GameProcess.PlacementMaxAttempts = 30
Shared_GameProcess.LuckyBlockOverlapPadding = 8
Shared_GameProcess.LuckyBlockPlacementMaxAttempts = 60
Shared_GameProcess.LianasOnWallChance = 0.5
Shared_GameProcess.LianasRoadWallChanceMultiplier = 2
Shared_GameProcess.LianasMinimapWallChanceMultiplier = 1.3
Shared_GameProcess.LianaScaleMin = 0.75
Shared_GameProcess.LianaScaleMax = 0.9
Shared_GameProcess.WorldLuckyBlockFloatHeight = 0.6
Shared_GameProcess.WorldLuckyBlockFloatHeightScale = 0.08
Shared_GameProcess.WorldLuckyBlockMinFloorClearance = 0.35
Shared_GameProcess.WorldLuckyBlockMinClearanceScale = 0.06
Shared_GameProcess.WorldLuckyBlockFloatSpeed = 1.25
Shared_GameProcess.WorldLuckyBlockRotateSpeed = 25

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

Shared_GameProcess.FloorSizeByRarity = {
	Common = 300,
	Rare = 350,
	Epic = 500,
	Legendary = 600,
	Mythical = 700,
	Secret = 800,
	Divine = 900,
	Superior = 1000,
}

function Shared_GameProcess.GetFloorSize(rarity: string): number?
	local size = Shared_GameProcess.FloorSizeByRarity[rarity]
	if type(size) == "number" and size > 0 then
		return size
	end
	return nil
end

return Shared_GameProcess
