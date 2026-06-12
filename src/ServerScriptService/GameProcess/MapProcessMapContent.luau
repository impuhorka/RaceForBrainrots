local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_GameProcess = SharedModules.require("Shared_GameProcess")
local Shared_MapDecorationBlueprint = SharedModules.require("Shared_MapDecorationBlueprint")
local Shared_LuckyBlockBillboard = SharedModules.require("Shared_LuckyBlockBillboard")
local Shared_LuckyBlocks = SharedModules.require("Shared_LuckyBlocks")
local Shared_Rarities = SharedModules.require("Shared_Rarities")
local Shared_Weight = SharedModules.require("Shared_Weight")

local GameProcessService = require(script.Parent.GameProcessService)
local MapProcessAssets = require(script.Parent.MapProcessAssets)
local MapProcessDecorationQuery = require(script.Parent.MapProcessDecorationQuery)
local MapProcessPlacement = require(script.Parent.MapProcessPlacement)

type PlacedSpot = MapProcessPlacement.PlacedSpot

local Assets = MapProcessAssets
local getDecorationExtents = Assets.getDecorationExtents
local prepareAnchoredModel = Assets.prepareAnchoredModel
local applyFlowerTopColor = Assets.applyFlowerTopColor
local applyLianaFlowerColors = Assets.applyLianaFlowerColors
local applyDecorationScale = Assets.applyDecorationScale
local applyDecorationScaleKind = Assets.applyDecorationScaleKind
local applyLianaScale = Assets.applyLianaScale
local applyLilyScale = Assets.applyLilyScale
local getMinimapTreeTemplates = Assets.getMinimapTreeTemplates
local getMinimapRockTemplates = Assets.getMinimapRockTemplates
local getMinimapBushTemplates = Assets.getMinimapBushTemplates
local getLuckyBlockTemplate = Assets.getLuckyBlockTemplate
local prepareLuckyBlockModel = Assets.prepareLuckyBlockModel
local getBuildContext = Assets.getBuildContext
local getSortedRarities = Assets.getSortedRarities

local getModelFloorSpot = MapProcessPlacement.getModelFloorSpot
local getModelsClusterSpot = MapProcessPlacement.getModelsClusterSpot
local snapModelBottomToY = MapProcessPlacement.snapModelBottomToY
local canPlaceSpot = MapProcessPlacement.canPlaceSpot
local shuffleArray = MapProcessPlacement.shuffleArray
local generateLuckyBlockCandidatePositions = MapProcessPlacement.generateLuckyBlockCandidatePositions
local tryPlaceLuckyBlockOnHoleFloor = MapProcessPlacement.tryPlaceLuckyBlockOnHoleFloor
local tryPlaceModelOnHoleFloor = MapProcessPlacement.tryPlaceModelOnHoleFloor
local getFlowerStandRotation = MapProcessPlacement.getFlowerStandRotation

local MapProcessMapContent = {}

local function getWallRunLength(wall: BasePart): number
	if wall.Size.Z > wall.Size.X then
		return wall.Size.Z
	end
	return wall.Size.X
end

local function wallRunsAlongZ(wall: BasePart): boolean
	return wall.Size.Z > wall.Size.X
end

local function isRoadWall(wall: BasePart): boolean
	local side = wall:GetAttribute("Side")
	return side == "Left" or side == "Right"
end

local function getWallAttachmentCount(
	wall: BasePart,
	roadSegmentLength: number,
	minimapSegmentLength: number,
	roadMaxCount: number,
	minimapMaxCount: number
): number
	local runLength = getWallRunLength(wall)
	local segmentLength = if isRoadWall(wall) then roadSegmentLength else minimapSegmentLength
	local maxCount = if isRoadWall(wall) then roadMaxCount else minimapMaxCount

	if segmentLength <= 0 or runLength <= 0 then
		return 0
	end

	local count = math.floor(runLength / segmentLength)
	local remainder = runLength - count * segmentLength
	if remainder >= segmentLength * 0.45 and math.random() < remainder / segmentLength then
		count += 1
	end

	return math.clamp(count, 0, maxCount)
end

local function getLianaCountForWall(wall: BasePart): number
	return getWallAttachmentCount(
		wall,
		Shared_GameProcess.LianasRoadWallSegmentLength,
		Shared_GameProcess.LianasMinimapWallSegmentLength,
		Shared_GameProcess.LianasMaxPerRoadWall,
		Shared_GameProcess.LianasMaxPerMinimapWall
	)
end

local function getLilyCountForWall(wall: BasePart): number
	return getWallAttachmentCount(
		wall,
		Shared_GameProcess.LiliesRoadWallSegmentLength,
		Shared_GameProcess.LiliesMinimapWallSegmentLength,
		Shared_GameProcess.LiliesMaxPerRoadWall,
		Shared_GameProcess.LiliesMaxPerMinimapWall
	)
end

local function pickAlongWallOffsets(wall: BasePart, count: number, minSpacing: number): { number }
	local edgeMargin = Shared_GameProcess.LianaWallEdgeMargin
	local runLength = getWallRunLength(wall)
	local halfRun = math.max(runLength / 2 - edgeMargin, 0)
	if count <= 0 or halfRun <= 0 then
		return {}
	end

	if count == 1 then
		return { (math.random() * 2 - 1) * halfRun }
	end

	local maxFitCount = math.max(1, math.floor((halfRun * 2) / minSpacing) + 1)
	local targetCount = math.min(count, maxFitCount)
	local offsets: { number } = {}
	local maxAttempts = targetCount * 25

	for _ = 1, maxAttempts do
		if #offsets >= targetCount then
			break
		end

		local offset = (math.random() * 2 - 1) * halfRun
		local isFarEnough = true
		for _, existingOffset in offsets do
			if math.abs(offset - existingOffset) < minSpacing then
				isFarEnough = false
				break
			end
		end

		if isFarEnough then
			table.insert(offsets, offset)
		end
	end

	return offsets
end

local function forEachRarityWall(
	parent: Instance,
	rarityName: string,
	callback: (wall: BasePart) -> ()
)
	for _, child in parent:GetChildren() do
		if child:IsA("BasePart")
			and child:GetAttribute("IsGameProcessWall") == true
			and child:GetAttribute("Rarity") == rarityName
		then
			callback(child)
		end
	end
end

local function getWallAlongWallOffsetPosition(wall: BasePart, alongWallOffset: number?): (number, number)
	local edgeMargin = Shared_GameProcess.LianaWallEdgeMargin
	local runsAlongZ = wallRunsAlongZ(wall)
	local halfRun = math.max(getWallRunLength(wall) / 2 - edgeMargin, 0)
	local offset = if alongWallOffset
		then math.clamp(alongWallOffset, -halfRun, halfRun)
		else (math.random() * 2 - 1) * halfRun

	if runsAlongZ then
		return wall.Position.X, wall.Position.Z + offset
	end
	return wall.Position.X + offset, wall.Position.Z
end

local function getWallInteriorDirection(wall: BasePart): Vector3
	local side = wall:GetAttribute("Side")
	if side == "Left" then
		return Vector3.new(1, 0, 0)
	elseif side == "Right" then
		return Vector3.new(-1, 0, 0)
	elseif side == "Front" then
		return Vector3.new(0, 0, -1)
	elseif side == "Back" then
		return Vector3.new(0, 0, 1)
	elseif side == "Outer" then
		if string.find(wall.Name, "LeftHole", 1, true) then
			return Vector3.new(1, 0, 0)
		end
		if string.find(wall.Name, "RightHole", 1, true) then
			return Vector3.new(-1, 0, 0)
		end
	end
	return Vector3.new(1, 0, 0)
end

local function getWallInteriorSurfacePosition(wall: BasePart, worldX: number, worldY: number, worldZ: number): (Vector3, Vector3)
	local interiorDir = getWallInteriorDirection(wall)
	local wallHalfThickness = if wallRunsAlongZ(wall) then wall.Size.X / 2 else wall.Size.Z / 2
	local surfacePosition = Vector3.new(worldX, worldY, worldZ) + interiorDir * wallHalfThickness
	return surfacePosition, interiorDir
end

local function flushModelToInteriorWallSurface(
	model: Model,
	surfacePosition: Vector3,
	interiorDir: Vector3,
	clearance: number
)
	local interior = interiorDir.Unit
	local bboxCF, bboxSize = model:GetBoundingBox()
	local half = bboxSize / 2
	local minOffset = math.huge

	for sx = -1, 1, 2 do
		for sy = -1, 1, 2 do
			for sz = -1, 1, 2 do
				local corner = bboxCF.Position
					+ bboxCF.RightVector * half.X * sx
					+ bboxCF.UpVector * half.Y * sy
					+ bboxCF.LookVector * half.Z * sz
				local offset = (corner - surfacePosition):Dot(interior)
				minOffset = math.min(minOffset, offset)
			end
		end
	end

	if minOffset == math.huge then
		return
	end

	local shift = clearance - minOffset
	if math.abs(shift) > 0.001 then
		model:PivotTo(model:GetPivot() + interior * shift)
	end
end

local function placeDecorationOnHoleFloor(
	holeFloor: BasePart,
	template: Model,
	rarityName: string,
	holeSide: string,
	index: number,
	placedSpots: { PlacedSpot },
	parent: Instance,
	overlapPadding: number?,
	scaleKind: string?
)
	local decoration = template:Clone()
	decoration.Name = `{rarityName}{holeSide}Decoration{index}`
	prepareAnchoredModel(decoration)
	applyDecorationScaleKind(decoration, scaleKind)

	if not tryPlaceModelOnHoleFloor(holeFloor, decoration, placedSpots, nil, nil, overlapPadding) then
		decoration:Destroy()
		return false
	end

	decoration:SetAttribute("Rarity", rarityName)
	decoration:SetAttribute("HoleSide", holeSide)
	Shared_MapDecorationBlueprint.MarkModel(decoration, "Decorations", template.Name)
	decoration.Parent = parent
	return true
end

local function repositionExistingDecorationOnHoleFloor(
	holeFloor: BasePart,
	model: Model,
	placedSpots: { PlacedSpot },
	flowerTemplateName: string?,
	useWorldFootprint: boolean?,
	overlapPadding: number?
): boolean
	return tryPlaceModelOnHoleFloor(
		holeFloor,
		model,
		placedSpots,
		flowerTemplateName,
		useWorldFootprint,
		overlapPadding
	)
end

local function pickDiverseTreeTemplate(
	treeTemplates: { Model },
	typeCounts: { [string]: number },
	targetTreeCount: number,
	maxPerType: number
): Model?
	local available: { Model } = {}
	for _, template in treeTemplates do
		if (typeCounts[template.Name] or 0) < maxPerType then
			table.insert(available, template)
		end
	end

	if #available == 0 then
		return nil
	end

	return available[math.random(1, #available)]
end

local function placeLuckyBlockOnHoleFloor(
	holeFloor: BasePart,
	template: Model,
	configName: string,
	rarityName: string,
	holeSide: string,
	index: number,
	decorationSpots: { PlacedSpot },
	luckyBlockSpots: { PlacedSpot },
	candidatePositions: { { X: number, Z: number } },
	parent: Instance
)
	local luckyBlock = template:Clone()
	luckyBlock.Name = `{rarityName}{holeSide}LuckyBlock{index}`
	prepareLuckyBlockModel(luckyBlock)

	local baseWeight = Shared_LuckyBlocks.GetBaseWeight(configName)
	local rolledWeight = Shared_Weight.RollWeight(baseWeight)
	Shared_Weight.ApplyLuckyBlockScale(luckyBlock, baseWeight, rolledWeight)
	Shared_Weight.SyncLuckyBlockPivot(luckyBlock)

	if not tryPlaceLuckyBlockOnHoleFloor(
		holeFloor,
		luckyBlock,
		decorationSpots,
		luckyBlockSpots,
		candidatePositions
	) then
		luckyBlock:Destroy()
		return
	end

	local _, bboxSize = luckyBlock:GetBoundingBox()
	local floatHeight = Shared_GameProcess.GetWorldLuckyBlockFloatHeight(bboxSize.Y)
	local spawnLift = Shared_GameProcess.GetWorldLuckyBlockSpawnLift(bboxSize.Y)
	luckyBlock:PivotTo(luckyBlock:GetPivot() + Vector3.new(0, spawnLift, 0))
	luckyBlock:SetAttribute("WorldFloatBasePosition", luckyBlock:GetPivot().Position)
	luckyBlock:SetAttribute("WorldBaseYaw", Shared_GameProcess.GetFlatYaw(luckyBlock:GetPivot()))
	luckyBlock:SetAttribute("FloatHeight", floatHeight)
	luckyBlock:SetAttribute("FloatSpinDirection", if math.random() < 0.5 then -1 else 1)

	luckyBlock:SetAttribute("Rarity", rarityName)
	luckyBlock:SetAttribute("HoleSide", holeSide)
	luckyBlock:SetAttribute("ItemType", "LuckyBlock")
	luckyBlock:SetAttribute("ConfigName", configName)
	luckyBlock:SetAttribute("BaseWeight", baseWeight)
	luckyBlock:SetAttribute("Weight", rolledWeight)
	Shared_LuckyBlockBillboard.Setup(luckyBlock, configName, baseWeight, rolledWeight)
	GameProcessService.SetupWorldLuckyBlock(luckyBlock)
	luckyBlock.Parent = parent
end

local function placeDecorationsForHoleFloor(
	holeFloor: BasePart,
	decorationTemplates: { Model },
	rarityName: string,
	holeSide: string,
	parent: Instance
): { PlacedSpot }
	local placedSpots: { PlacedSpot } = {}
	local decorationIndex = 0

	local function placeRandomDecorations(
		templates: { Model },
		count: number,
		overlapPadding: number?,
		scaleKind: string?
	)
		for _ = 1, count do
			if #templates == 0 then
				break
			end
			decorationIndex += 1
			local template = templates[math.random(1, #templates)]
			placeDecorationOnHoleFloor(
				holeFloor,
				template,
				rarityName,
				holeSide,
				decorationIndex,
				placedSpots,
				parent,
				overlapPadding,
				scaleKind
			)
		end
	end

	placeRandomDecorations(
		getMinimapRockTemplates(decorationTemplates),
		Shared_GameProcess.MinRocksPerMinimap,
		nil,
		"rock"
	)
	placeRandomDecorations(
		getMinimapBushTemplates(decorationTemplates),
		Shared_GameProcess.MinBushesPerMinimap,
		Shared_GameProcess.BushOverlapPadding,
		"bush"
	)

	local treeCountRange = Shared_GameProcess.TreesPerMinimap
	local targetTreeCount = math.random(treeCountRange.Min, treeCountRange.Max)
	local treeTemplates = getMinimapTreeTemplates(decorationTemplates)
	local treeOverlapPadding = Shared_GameProcess.TreeOverlapPadding
	local treesPlaced = 0
	local treeTypeCounts: { [string]: number } = {}
	local maxPerTreeType = if targetTreeCount >= 3 then 2 else targetTreeCount
	local placementAttempts = 0
	local maxTreePlacementAttempts = targetTreeCount * Shared_GameProcess.PlacementMaxAttempts

	while treesPlaced < targetTreeCount and placementAttempts < maxTreePlacementAttempts do
		if #treeTemplates == 0 then
			break
		end

		placementAttempts += 1
		local treeTemplate = pickDiverseTreeTemplate(
			treeTemplates,
			treeTypeCounts,
			targetTreeCount,
			maxPerTreeType
		)
		if not treeTemplate then
			maxPerTreeType = targetTreeCount
			treeTemplate = pickDiverseTreeTemplate(
				treeTemplates,
				treeTypeCounts,
				targetTreeCount,
				maxPerTreeType
			)
			if not treeTemplate then
				break
			end
		end

		decorationIndex += 1
		local placed = placeDecorationOnHoleFloor(
			holeFloor,
			treeTemplate,
			rarityName,
			holeSide,
			decorationIndex,
			placedSpots,
			parent,
			treeOverlapPadding,
			"tree"
		)
		if placed then
			treesPlaced += 1
			treeTypeCounts[treeTemplate.Name] = (treeTypeCounts[treeTemplate.Name] or 0) + 1
		else
			decorationIndex -= 1
		end
	end

	return placedSpots
end

local GROUND_FLOWER_NAME = "GroundFlower"

local function finalizeFlowerOnHoleFloor(
	flower: Model,
	templateName: string,
	rarityName: string,
	holeSide: string,
	index: number,
	parent: Instance
)
	flower.Name = `{rarityName}{holeSide}Flower{index}`
	flower:SetAttribute("Rarity", rarityName)
	flower:SetAttribute("HoleSide", holeSide)
	Shared_MapDecorationBlueprint.MarkModel(flower, "Flowers", templateName)
	flower.Parent = parent
end

local function placeFlowerAt(
	holeFloor: BasePart,
	flower: Model,
	templateName: string,
	worldX: number,
	worldZ: number
)
	local floorTopY = holeFloor.Position.Y + holeFloor.Size.Y / 2
	local rotation = getFlowerStandRotation(flower, templateName)

	flower:PivotTo(CFrame.new(worldX, holeFloor.Position.Y, worldZ) * rotation)

	local bboxCF, _bboxSize = flower:GetBoundingBox()
	flower:PivotTo(flower:GetPivot() + Vector3.new(worldX - bboxCF.Position.X, 0, worldZ - bboxCF.Position.Z))
	snapModelBottomToY(flower, floorTopY)
end

local function placeFlowerOnHoleFloor(
	holeFloor: BasePart,
	template: Model,
	rarityName: string,
	holeSide: string,
	index: number,
	placedSpots: { PlacedSpot },
	parent: Instance
)
	local flower = template:Clone()
	prepareAnchoredModel(flower)
	applyFlowerTopColor(flower)

	if not tryPlaceModelOnHoleFloor(holeFloor, flower, placedSpots, template.Name) then
		flower:Destroy()
		return
	end

	finalizeFlowerOnHoleFloor(flower, template.Name, rarityName, holeSide, index, parent)
end

local function getFlowerWorldFootprintHalfSize(flower: Model): (number, number)
	local _, bboxSize = flower:GetBoundingBox()
	return bboxSize.X / 2, bboxSize.Z / 2
end

local function tryPlaceGroundFlowerStack(
	holeFloor: BasePart,
	template: Model,
	stackSize: number,
	placedSpots: { PlacedSpot }
): { Model }?
	local overlapPadding = Shared_GameProcess.PlacementOverlapPadding
	local stackSpread = Shared_GameProcess.GroundFlowerStackSpread
	local maxAttempts = Shared_GameProcess.PlacementMaxAttempts

	for _ = 1, maxAttempts do
		local stackModels: { Model } = {}
		local stackSpots: { PlacedSpot } = {}
		local anchorFlower = template:Clone()
		prepareAnchoredModel(anchorFlower)
		applyFlowerTopColor(anchorFlower)

		if not tryPlaceModelOnHoleFloor(holeFloor, anchorFlower, placedSpots, template.Name) then
			anchorFlower:Destroy()
			continue
		end

		table.insert(stackModels, anchorFlower)
		local anchorSpot = getModelFloorSpot(anchorFlower)
		table.insert(stackSpots, anchorSpot)

		local stackComplete = true
		for _ = 2, stackSize do
			local flower = template:Clone()
			prepareAnchoredModel(flower)
			applyFlowerTopColor(flower)

			local placedInStack = false
			for _ = 1, maxAttempts do
				local flowerHalfX, flowerHalfZ = getFlowerWorldFootprintHalfSize(flower)
				local spreadX = anchorSpot.HalfX + flowerHalfX + overlapPadding + stackSpread
				local spreadZ = anchorSpot.HalfZ + flowerHalfZ + overlapPadding + stackSpread
				local offsetX = (math.random() * 2 - 1) * spreadX
				local offsetZ = (math.random() * 2 - 1) * spreadZ
				placeFlowerAt(holeFloor, flower, template.Name, anchorSpot.X + offsetX, anchorSpot.Z + offsetZ)

				local spot = getModelFloorSpot(flower)
				if canPlaceSpot(spot, stackSpots, overlapPadding) then
					table.insert(stackSpots, spot)
					table.insert(stackModels, flower)
					placedInStack = true
					break
				end
			end

			if not placedInStack then
				flower:Destroy()
				stackComplete = false
				break
			end
		end

		if not stackComplete then
			for _, flower in stackModels do
				flower:Destroy()
			end
			continue
		end

		table.remove(placedSpots, #placedSpots)

		local clusterSpot = getModelsClusterSpot(stackModels)
		if canPlaceSpot(clusterSpot, placedSpots, overlapPadding) then
			table.insert(placedSpots, clusterSpot)
			return stackModels
		end

		for _, flower in stackModels do
			flower:Destroy()
		end
	end

	return nil
end

local function placeFlowersForHoleFloor(
	holeFloor: BasePart,
	flowerTemplates: { Model },
	rarityName: string,
	holeSide: string,
	placedSpots: { PlacedSpot },
	parent: Instance
)
	if #flowerTemplates == 0 then
		return
	end

	local flowerCountRange = Shared_GameProcess.FlowersPerMinimap
	local flowerCount = math.random(flowerCountRange.Min, flowerCountRange.Max)
	local stackSizeRange = Shared_GameProcess.GroundFlowersPerStack
	local flowerIndex = 0

	for _ = 1, flowerCount do
		local template = flowerTemplates[math.random(1, #flowerTemplates)]

		if template.Name == GROUND_FLOWER_NAME then
			local stackSize = math.random(stackSizeRange.Min, stackSizeRange.Max)
			local stackModels = tryPlaceGroundFlowerStack(holeFloor, template, stackSize, placedSpots)
			if not stackModels then
				continue
			end

			for _, flower in stackModels do
				flowerIndex += 1
				finalizeFlowerOnHoleFloor(flower, template.Name, rarityName, holeSide, flowerIndex, parent)
			end
		else
			flowerIndex += 1
			placeFlowerOnHoleFloor(holeFloor, template, rarityName, holeSide, flowerIndex, placedSpots, parent)
		end
	end
end

local function placeGrassAt(holeFloor: BasePart, grass: Model, worldX: number, worldZ: number)
	local floorTopY = holeFloor.Position.Y + holeFloor.Size.Y / 2
	local rotation = CFrame.Angles(0, math.random() * math.pi * 2, 0)

	grass:PivotTo(CFrame.new(worldX, holeFloor.Position.Y, worldZ) * rotation)

	local bboxCF, _bboxSize = grass:GetBoundingBox()
	grass:PivotTo(grass:GetPivot() + Vector3.new(worldX - bboxCF.Position.X, 0, worldZ - bboxCF.Position.Z))
	snapModelBottomToY(grass, floorTopY)
end

local function tryPlaceGrassStack(
	holeFloor: BasePart,
	grassTemplates: { Model },
	stackSize: number,
	placedSpots: { PlacedSpot }
): { Model }?
	local overlapPadding = Shared_GameProcess.PlacementOverlapPadding
	local stackSpread = Shared_GameProcess.GrassStackSpread
	local maxAttempts = Shared_GameProcess.PlacementMaxAttempts

	for _ = 1, maxAttempts do
		local stackModels: { Model } = {}
		local anchorTemplate = grassTemplates[math.random(1, #grassTemplates)]
		local anchorGrass = anchorTemplate:Clone()
		prepareAnchoredModel(anchorGrass)

		if not tryPlaceModelOnHoleFloor(holeFloor, anchorGrass, placedSpots, nil, true) then
			anchorGrass:Destroy()
			continue
		end

		table.insert(stackModels, anchorGrass)
		local anchorSpot = getModelFloorSpot(anchorGrass)
		local anchorX = anchorSpot.X
		local anchorZ = anchorSpot.Z

		for _ = 2, stackSize do
			local template = grassTemplates[math.random(1, #grassTemplates)]
			local grass = template:Clone()
			prepareAnchoredModel(grass)
			local offsetX = (math.random() * 2 - 1) * stackSpread
			local offsetZ = (math.random() * 2 - 1) * stackSpread
			placeGrassAt(holeFloor, grass, anchorX + offsetX, anchorZ + offsetZ)
			table.insert(stackModels, grass)
		end

		table.remove(placedSpots, #placedSpots)

		local clusterSpot = getModelsClusterSpot(stackModels)
		if canPlaceSpot(clusterSpot, placedSpots, overlapPadding) then
			table.insert(placedSpots, clusterSpot)
			for _, grass in stackModels do
				Shared_MapDecorationBlueprint.MarkModel(grass, "Grass", anchorTemplate.Name)
			end
			return stackModels
		end

		for _, grass in stackModels do
			grass:Destroy()
		end
	end

	return nil
end

local function placeGrassForHoleFloor(
	holeFloor: BasePart,
	grassTemplates: { Model },
	rarityName: string,
	holeSide: string,
	placedSpots: { PlacedSpot },
	parent: Instance
)
	if #grassTemplates == 0 then
		return
	end

	local stackCountRange = Shared_GameProcess.GrassStacksPerMinimap
	local stackCount = math.random(stackCountRange.Min, stackCountRange.Max)
	local stackSizeRange = Shared_GameProcess.GrassPerStack
	local grassIndex = 0

	for _ = 1, stackCount do
		local stackSize = math.random(stackSizeRange.Min, stackSizeRange.Max)
		local stackModels = tryPlaceGrassStack(holeFloor, grassTemplates, stackSize, placedSpots)
		if not stackModels then
			break
		end

		for _, grass in stackModels do
			grassIndex += 1
			grass.Name = `{rarityName}{holeSide}Grass{grassIndex}`
			grass:SetAttribute("Rarity", rarityName)
			grass:SetAttribute("HoleSide", holeSide)
			grass.Parent = parent
		end
	end
end

local function placeMushroomOnHoleFloor(
	holeFloor: BasePart,
	template: Model,
	rarityName: string,
	holeSide: string,
	index: number,
	placedSpots: { PlacedSpot },
	parent: Instance
)
	local mushroom = template:Clone()
	prepareAnchoredModel(mushroom)
	applyDecorationScale(mushroom)

	if not tryPlaceModelOnHoleFloor(holeFloor, mushroom, placedSpots) then
		mushroom:Destroy()
		return false
	end

	mushroom.Name = `{rarityName}{holeSide}Mushroom{index}`
	mushroom:SetAttribute("Rarity", rarityName)
	mushroom:SetAttribute("HoleSide", holeSide)
	Shared_MapDecorationBlueprint.MarkModel(mushroom, "Mushrooms", template.Name)
	mushroom.Parent = parent
	return true
end

local function placeMushroomsForHoleFloor(
	holeFloor: BasePart,
	mushroomTemplates: { Model },
	rarityName: string,
	holeSide: string,
	placedSpots: { PlacedSpot },
	parent: Instance
)
	if #mushroomTemplates == 0 then
		return
	end

	local mushroomCountRange = Shared_GameProcess.MushroomsPerMinimap
	local mushroomCount = math.random(mushroomCountRange.Min, mushroomCountRange.Max)
	local mushroomIndex = 0

	for _ = 1, mushroomCount do
		local template = mushroomTemplates[math.random(1, #mushroomTemplates)]
		if placeMushroomOnHoleFloor(holeFloor, template, rarityName, holeSide, mushroomIndex + 1, placedSpots, parent) then
			mushroomIndex += 1
		end
	end
end

local function spawnLuckyBlocksForHoleFloor(
	holeFloor: BasePart,
	luckyBlockTemplate: Model,
	configName: string,
	rarityName: string,
	holeSide: string,
	decorationSpots: { PlacedSpot },
	parent: Instance,
	luckyBlockCount: number?,
	pace: (() -> boolean)?
)
	local luckyBlockCountRange = Shared_GameProcess.LuckyBlocksPerHole
	local count = luckyBlockCount
		or math.random(luckyBlockCountRange.Min, luckyBlockCountRange.Max)
	local luckyBlockSpots: { PlacedSpot } = {}

	local previewBlock = luckyBlockTemplate:Clone()
	prepareLuckyBlockModel(previewBlock)
	local previewBaseWeight = Shared_LuckyBlocks.GetBaseWeight(configName)
	local previewMaxWeight = previewBaseWeight * 9
	Shared_Weight.ApplyLuckyBlockScale(previewBlock, previewBaseWeight, previewMaxWeight)
	local previewSize = getDecorationExtents(previewBlock)
	previewBlock:Destroy()

	local candidatePositions = generateLuckyBlockCandidatePositions(
		holeFloor,
		count,
		previewSize.X / 2,
		previewSize.Z / 2
	)

	for index = 1, count do
		if pace and not pace() then
			return
		end

		local blockCandidates: { { X: number, Z: number } } = {}
		local preferredPosition = candidatePositions[index]
		if preferredPosition then
			table.insert(blockCandidates, preferredPosition)
		end

		placeLuckyBlockOnHoleFloor(
			holeFloor,
			luckyBlockTemplate,
			configName,
			rarityName,
			holeSide,
			index,
			decorationSpots,
			luckyBlockSpots,
			blockCandidates,
			parent
		)
	end
end

local function placeWallsForFloor(
	floor: BasePart,
	wallTemplate: BasePart,
	rarityName: string,
	parent: Instance
)
	local originWallSize = wallTemplate.Size
	local halfFloorX = floor.Size.X / 2
	local frontOpening = Shared_GameProcess.WallFrontOpening
	local wallLengthZ = floor.Size.Z - frontOpening
	local wallSize = Vector3.new(originWallSize.X, originWallSize.Y, wallLengthZ)
	local halfWallThicknessX = wallSize.X / 2
	local halfWallY = wallSize.Y / 2
	local wallY = floor.Position.Y - floor.Size.Y + halfWallY
	local wallZ = floor.Position.Z + frontOpening / 2

	local leftWall = wallTemplate:Clone()
	leftWall.Name = `{rarityName}LeftWall`
	leftWall.Size = wallSize
	leftWall.Position = Vector3.new(
		floor.Position.X - halfFloorX - halfWallThicknessX,
		wallY,
		wallZ
	)
	leftWall:SetAttribute("Rarity", rarityName)
	leftWall:SetAttribute("Side", "Left")
	leftWall:SetAttribute("IsGameProcessWall", true)
	leftWall.Parent = parent

	local rightWall = wallTemplate:Clone()
	rightWall.Name = `{rarityName}RightWall`
	rightWall.Size = wallSize
	rightWall.Position = Vector3.new(
		floor.Position.X + halfFloorX + halfWallThicknessX,
		wallY,
		wallZ
	)
	rightWall:SetAttribute("Rarity", rarityName)
	rightWall:SetAttribute("Side", "Right")
	rightWall:SetAttribute("IsGameProcessWall", true)
	rightWall.Parent = parent
end

local function getWallY(floorPart: BasePart, wallHeight: number): number
	return floorPart.Position.Y - floorPart.Size.Y + wallHeight / 2
end

local function placeWall(
	wallTemplate: BasePart,
	name: string,
	position: Vector3,
	size: Vector3,
	rarityName: string,
	side: string,
	parent: Instance
)
	local wall = wallTemplate:Clone()
	wall.Name = name
	wall.Size = size
	wall.Position = position
	wall:SetAttribute("Rarity", rarityName)
	wall:SetAttribute("Side", side)
	wall:SetAttribute("IsGameProcessWall", true)
	wall:SetAttribute("IsMinimapWall", true)
	wall.Parent = parent
end

local function placeLianaOnWall(
	wall: BasePart,
	template: Model,
	index: number,
	rarityName: string,
	parent: Instance,
	alongWallOffset: number?
)
	local liana = template:Clone()
	liana.Name = `{rarityName}WallLiana{index}`
	prepareAnchoredModel(liana)
	applyLianaScale(liana)
	applyLianaFlowerColors(liana)

	local wallTopY = wall.Position.Y + wall.Size.Y / 2
	local worldX, worldZ = getWallAlongWallOffsetPosition(wall, alongWallOffset)
	local position, interiorDir = getWallInteriorSurfacePosition(wall, worldX, wallTopY, worldZ)
	local lookTarget = position + interiorDir
	liana:PivotTo(CFrame.lookAt(position, lookTarget) * CFrame.Angles(0, -math.pi / 2, 0))
	flushModelToInteriorWallSurface(liana, position, interiorDir, Shared_GameProcess.LilyWallClearance)

	local bboxCF, bboxSize = liana:GetBoundingBox()
	local targetBottomY = wallTopY - bboxSize.Y
	local bboxBottomY = bboxCF.Position.Y - bboxSize.Y / 2
	liana:PivotTo(liana:GetPivot() + Vector3.new(0, targetBottomY - bboxBottomY, 0))
	liana:SetAttribute("Rarity", rarityName)
	Shared_MapDecorationBlueprint.MarkModel(liana, "Lianas", template.Name)
	liana.Parent = parent
end

local function placeLianasOnRarityWalls(
	wallsRoot: Instance,
	rarityName: string,
	lianaTemplates: { Model },
	modelsParent: Instance
)
	if #lianaTemplates == 0 then
		return
	end

	local lianaIndex = 0

	forEachRarityWall(wallsRoot, rarityName, function(wall)
		local lianaCount = getLianaCountForWall(wall)
		if lianaCount <= 0 then
			return
		end

		local alongWallOffsets = pickAlongWallOffsets(wall, lianaCount, Shared_GameProcess.LianaMinSpacing)
		for _, alongWallOffset in alongWallOffsets do
			lianaIndex += 1
			local template = lianaTemplates[math.random(1, #lianaTemplates)]
			placeLianaOnWall(wall, template, lianaIndex, rarityName, modelsParent, alongWallOffset)
		end
	end)
end

local LILY_BASE_ROTATIONS: { [string]: CFrame } = {
	Front = CFrame.Angles(math.rad(90), math.rad(180), 0),
	Back = CFrame.Angles(math.rad(-90), 0, 0),
	Left = CFrame.Angles(0, 0, math.rad(-90)),
	Right = CFrame.Angles(0, 0, math.rad(90)),
}

local function getLilyBaseRotation(wall: BasePart): CFrame
	local side = wall:GetAttribute("Side")
	if side == "Outer" then
		if getWallInteriorDirection(wall).X > 0 then
			return CFrame.Angles(0, 0, math.rad(90))
		end
		return CFrame.Angles(0, 0, math.rad(-90))
	end

	local rotation = LILY_BASE_ROTATIONS[side :: string]
	if rotation then
		return rotation
	end
	return CFrame.identity
end

local function getLilyPivotRotation(wall: BasePart): CFrame
	local rotation = getLilyBaseRotation(wall)
	if wall:GetAttribute("IsMinimapWall") == true then
		local yawFlip = math.rad(Shared_GameProcess.MinimapLilyYawFlipDegrees)
		rotation = CFrame.Angles(0, yawFlip, 0) * rotation
	end
	return rotation
end

local function placeLilyOnWall(
	wall: BasePart,
	template: Model,
	index: number,
	rarityName: string,
	parent: Instance,
	alongWallOffset: number?
)
	local lily = template:Clone()
	lily.Name = `{rarityName}WallLily{index}`
	prepareAnchoredModel(lily)
	applyLilyScale(lily)
	applyFlowerTopColor(lily)

	local worldX, worldZ = getWallAlongWallOffsetPosition(wall, alongWallOffset)
	local wallBottomY = wall.Position.Y - wall.Size.Y / 2
	local attachY = wallBottomY + wall.Size.Y * (0.25 + math.random() * 0.5)
	local surfacePosition, interiorDir = getWallInteriorSurfacePosition(wall, worldX, attachY, worldZ)

	lily:PivotTo(CFrame.new(surfacePosition) * getLilyPivotRotation(wall))
	flushModelToInteriorWallSurface(lily, surfacePosition, interiorDir, Shared_GameProcess.LilyWallClearance)

	lily:SetAttribute("Rarity", rarityName)
	Shared_MapDecorationBlueprint.MarkModel(lily, "Lily", template.Name)
	lily.Parent = parent
end

local function placeLiliesOnRarityWalls(
	wallsRoot: Instance,
	rarityName: string,
	lilyTemplate: Model?,
	modelsParent: Instance
)
	if not lilyTemplate then
		return
	end

	local lilyIndex = 0

	forEachRarityWall(wallsRoot, rarityName, function(wall)
		local lilyCount = getLilyCountForWall(wall)
		if lilyCount <= 0 then
			return
		end

		local alongWallOffsets = pickAlongWallOffsets(wall, lilyCount, Shared_GameProcess.LilyMinSpacing)
		for _, alongWallOffset in alongWallOffsets do
			lilyIndex += 1
			placeLilyOnWall(wall, lilyTemplate, lilyIndex, rarityName, modelsParent, alongWallOffset)
		end
	end)
end

local function placeHoleFloor(
	floor: BasePart,
	floorTemplate: BasePart,
	rarityName: string,
	side: string,
	positionX: number,
	positionZ: number,
	holeFloorSize: Vector3,
	parent: Instance
): BasePart
	local holeFloor = floorTemplate:Clone()
	holeFloor.Name = `{rarityName}{side}HoleFloor`
	holeFloor.Size = holeFloorSize
	holeFloor.Position = Vector3.new(positionX, floor.Position.Y, positionZ)
	holeFloor.Color = Shared_GameProcess.MinimapFloorColor
	holeFloor:SetAttribute("Rarity", rarityName)
	holeFloor:SetAttribute("IsHoleFloor", true)
	holeFloor:SetAttribute("HoleSide", side)
	holeFloor.Parent = parent
	return holeFloor
end

local function placeEntranceFloor(
	holeFloor: BasePart,
	floorTemplate: BasePart,
	rarityName: string,
	holeSide: string,
	parent: Instance
)
	local entranceDepth = Shared_GameProcess.EntranceDepth
	local halfHoleX = holeFloor.Size.X / 2
	local entranceX = if holeSide == "Left"
		then holeFloor.Position.X + halfHoleX + entranceDepth / 2
		else holeFloor.Position.X - halfHoleX - entranceDepth / 2

	local entranceFloor = floorTemplate:Clone()
	entranceFloor.Name = `{rarityName}{holeSide}EntranceFloor`
	entranceFloor.Size = Vector3.new(entranceDepth, holeFloor.Size.Y, holeFloor.Size.Z)
	entranceFloor.Position = Vector3.new(entranceX, holeFloor.Position.Y, holeFloor.Position.Z)
	entranceFloor.Color = Shared_GameProcess.EntranceFloorColor
	entranceFloor:SetAttribute("Rarity", rarityName)
	entranceFloor:SetAttribute("IsEntranceFloor", true)
	entranceFloor:SetAttribute("HoleSide", holeSide)
	entranceFloor.Parent = parent
end

local function placeWallsForHoleFloor(
	holeFloor: BasePart,
	wallTemplate: BasePart,
	rarityName: string,
	holeSide: string,
	footprintCenterX: number,
	footprintWidthX: number,
	parent: Instance
)
	local originWallSize = wallTemplate.Size
	local halfHoleX = holeFloor.Size.X / 2
	local halfFootprintX = footprintWidthX / 2
	local halfHoleZ = holeFloor.Size.Z / 2
	local wallY = getWallY(holeFloor, originWallSize.Y)
	local wallPrefix = `{rarityName}{holeSide}Hole`

	if holeSide == "Left" then
		placeWall(
			wallTemplate,
			`{wallPrefix}OuterWall`,
			Vector3.new(footprintCenterX - halfFootprintX, wallY, holeFloor.Position.Z),
			Vector3.new(originWallSize.X, originWallSize.Y, holeFloor.Size.Z),
			rarityName,
			"Outer",
			parent
		)
	elseif holeSide == "Right" then
		placeWall(
			wallTemplate,
			`{wallPrefix}OuterWall`,
			Vector3.new(footprintCenterX + halfFootprintX, wallY, holeFloor.Position.Z),
			Vector3.new(originWallSize.X, originWallSize.Y, holeFloor.Size.Z),
			rarityName,
			"Outer",
			parent
		)
	end

	placeWall(
		wallTemplate,
		`{wallPrefix}BackWall`,
		Vector3.new(footprintCenterX, wallY, holeFloor.Position.Z - halfHoleZ),
		Vector3.new(footprintWidthX, originWallSize.Y, originWallSize.X),
		rarityName,
		"Back",
		parent
	)
	placeWall(
		wallTemplate,
		`{wallPrefix}FrontWall`,
		Vector3.new(footprintCenterX, wallY, holeFloor.Position.Z + halfHoleZ),
		Vector3.new(footprintWidthX, originWallSize.Y, originWallSize.X),
		rarityName,
		"Front",
		parent
	)
end

export type HoleFloorLayout = {
	leftHoleFloor: BasePart,
	rightHoleFloor: BasePart,
	leftFootprintCenterX: number,
	rightFootprintCenterX: number,
	holeWidthX: number,
}

local function placeHoleFloorsAndEntrancesForFloor(
	floor: BasePart,
	floorTemplate: BasePart,
	rarityName: string,
	parent: Instance
): HoleFloorLayout
	local holeWidthX = Shared_GameProcess.HoleFloorSize
	local entranceDepth = Shared_GameProcess.EntranceDepth
	local mainHoleWidthX = holeWidthX - entranceDepth
	local halfHoleWidthX = holeWidthX / 2
	local halfEntranceDepth = entranceDepth / 2
	local holeDepthZ = Shared_GameProcess.WallFrontOpening
	local halfHoleDepthZ = holeDepthZ / 2
	local halfFloorX = floor.Size.X / 2
	local floorBackZ = floor.Position.Z - floor.Size.Z / 2
	local holeCenterZ = floorBackZ + halfHoleDepthZ

	local mainHoleFloorSize = Vector3.new(mainHoleWidthX, floor.Size.Y, holeDepthZ)

	local leftFootprintCenterX = floor.Position.X - halfFloorX - halfHoleWidthX
	local leftMainCenterX = leftFootprintCenterX - halfEntranceDepth

	local leftHoleFloor = placeHoleFloor(
		floor,
		floorTemplate,
		rarityName,
		"Left",
		leftMainCenterX,
		holeCenterZ,
		mainHoleFloorSize,
		parent
	)
	placeEntranceFloor(leftHoleFloor, floorTemplate, rarityName, "Left", parent)

	local rightFootprintCenterX = floor.Position.X + halfFloorX + halfHoleWidthX
	local rightMainCenterX = rightFootprintCenterX + halfEntranceDepth

	local rightHoleFloor = placeHoleFloor(
		floor,
		floorTemplate,
		rarityName,
		"Right",
		rightMainCenterX,
		holeCenterZ,
		mainHoleFloorSize,
		parent
	)
	placeEntranceFloor(rightHoleFloor, floorTemplate, rarityName, "Right", parent)

	return {
		leftHoleFloor = leftHoleFloor,
		rightHoleFloor = rightHoleFloor,
		leftFootprintCenterX = leftFootprintCenterX,
		rightFootprintCenterX = rightFootprintCenterX,
		holeWidthX = holeWidthX,
	}
end

local function placeHoleFloorWallsForFloor(
	wallTemplate: BasePart,
	rarityName: string,
	layout: HoleFloorLayout,
	parent: Instance
)
	placeWallsForHoleFloor(
		layout.leftHoleFloor,
		wallTemplate,
		rarityName,
		"Left",
		layout.leftFootprintCenterX,
		layout.holeWidthX,
		parent
	)
	placeWallsForHoleFloor(
		layout.rightHoleFloor,
		wallTemplate,
		rarityName,
		"Right",
		layout.rightFootprintCenterX,
		layout.holeWidthX,
		parent
	)
end

local function placeHoleFloorDecorationsForFloor(
	layout: HoleFloorLayout,
	decorationTemplates: { Model },
	flowerTemplates: { Model },
	grassTemplates: { Model },
	mushroomTemplates: { Model },
	rarityName: string,
	parent: Instance
)
	local leftHoleFloor = layout.leftHoleFloor
	local rightHoleFloor = layout.rightHoleFloor

	local leftPlacedSpots = placeDecorationsForHoleFloor(
		leftHoleFloor,
		decorationTemplates,
		rarityName,
		"Left",
		parent
	)
	local rightPlacedSpots = placeDecorationsForHoleFloor(
		rightHoleFloor,
		decorationTemplates,
		rarityName,
		"Right",
		parent
	)

	placeFlowersForHoleFloor(leftHoleFloor, flowerTemplates, rarityName, "Left", leftPlacedSpots, parent)
	placeFlowersForHoleFloor(rightHoleFloor, flowerTemplates, rarityName, "Right", rightPlacedSpots, parent)

	placeGrassForHoleFloor(leftHoleFloor, grassTemplates, rarityName, "Left", leftPlacedSpots, parent)
	placeGrassForHoleFloor(rightHoleFloor, grassTemplates, rarityName, "Right", rightPlacedSpots, parent)

	placeMushroomsForHoleFloor(leftHoleFloor, mushroomTemplates, rarityName, "Left", leftPlacedSpots, parent)
	placeMushroomsForHoleFloor(rightHoleFloor, mushroomTemplates, rarityName, "Right", rightPlacedSpots, parent)
end

local function collectDecorationSpotsOnHoleFloor(holeFloor: BasePart, zoneModels: { Model }): { PlacedSpot }
	local spots: { PlacedSpot } = {}
	for _, model in zoneModels do
		if MapProcessDecorationQuery.modelOverlapsHoleFloor(model, holeFloor) then
			table.insert(spots, getModelFloorSpot(model))
		end
	end
	return spots
end

local function repositionMinimapDecorationsOnly(
	holeFloor: BasePart,
	zoneModels: { Model },
	pace: (() -> boolean)?
): { PlacedSpot }
	local function step(): boolean
		if pace then
			return pace()
		end
		return true
	end

	local rocks: { Model } = {}
	local bushes: { Model } = {}
	local flowers: { Model } = {}
	local grass: { Model } = {}
	local mushrooms: { Model } = {}

	for _, model in zoneModels do
		local folder = model:GetAttribute("MapDecorationFolder")
		local template = model:GetAttribute("MapDecorationTemplate")
		if folder == "Decorations"
			and Shared_MapDecorationBlueprint.TemplateInList(template, Shared_MapDecorationBlueprint.TreeTemplateNames)
		then
			continue
		elseif folder == "Decorations"
			and Shared_MapDecorationBlueprint.TemplateInList(template, Shared_MapDecorationBlueprint.RockTemplateNames)
		then
			table.insert(rocks, model)
		elseif folder == "Decorations"
			and Shared_MapDecorationBlueprint.TemplateInList(template, Shared_MapDecorationBlueprint.BushTemplateNames)
		then
			table.insert(bushes, model)
		elseif folder == "Flowers" then
			table.insert(flowers, model)
		elseif folder == "Grass" then
			table.insert(grass, model)
		elseif folder == "Mushrooms" then
			table.insert(mushrooms, model)
		end
	end

	local placedSpots: { PlacedSpot } = {}

	for _, model in rocks do
		if not step() then
			return placedSpots
		end
		repositionExistingDecorationOnHoleFloor(holeFloor, model, placedSpots)
	end
	for _, model in bushes do
		if not step() then
			return placedSpots
		end
		repositionExistingDecorationOnHoleFloor(
			holeFloor,
			model,
			placedSpots,
			nil,
			nil,
			Shared_GameProcess.BushOverlapPadding
		)
	end
	for _, model in flowers do
		if not step() then
			return placedSpots
		end
		local templateName = model:GetAttribute("MapDecorationTemplate")
		repositionExistingDecorationOnHoleFloor(
			holeFloor,
			model,
			placedSpots,
			if type(templateName) == "string" then templateName else nil
		)
	end
	for _, model in grass do
		if not step() then
			return placedSpots
		end
		repositionExistingDecorationOnHoleFloor(holeFloor, model, placedSpots, nil, true)
	end
	for _, model in mushrooms do
		if not step() then
			return placedSpots
		end
		repositionExistingDecorationOnHoleFloor(holeFloor, model, placedSpots)
	end

	return placedSpots
end

local function refreshMinimapTreesRandom(
	holeFloor: BasePart,
	decorationTemplates: { Model },
	rarityName: string,
	holeSide: string,
	floorsFolder: Folder,
	zoneModels: { Model },
	placedSpots: { PlacedSpot },
	pace: (() -> boolean)?
): { PlacedSpot }
	local function step(): boolean
		if pace then
			return pace()
		end
		return true
	end

	for _, model in zoneModels do
		local folder = model:GetAttribute("MapDecorationFolder")
		local template = model:GetAttribute("MapDecorationTemplate")
		if folder == "Decorations"
			and Shared_MapDecorationBlueprint.TemplateInList(template, Shared_MapDecorationBlueprint.TreeTemplateNames)
		then
			model:Destroy()
		end
	end

	local treeCountRange = Shared_GameProcess.TreesPerMinimap
	local minTrees = treeCountRange.Min
	local targetTreeCount = math.random(treeCountRange.Min, treeCountRange.Max)
	local treeTemplates = getMinimapTreeTemplates(decorationTemplates)
	if #treeTemplates == 0 then
		return placedSpots
	end

	local treeTypeCounts: { [string]: number } = {}
	local treesPlaced = 0
	local placementAttempts = 0
	local maxPerTreeType = if targetTreeCount >= 3 then 2 else targetTreeCount
	local maxTreePlacementAttempts = targetTreeCount * Shared_GameProcess.PlacementMaxAttempts
	local decorationIndex = 0

	local function tryPlaceTree(overlapPadding: number, usePace: boolean): boolean
		if usePace and not step() then
			return false
		end

		local treeTemplate = pickDiverseTreeTemplate(
			treeTemplates,
			treeTypeCounts,
			targetTreeCount,
			maxPerTreeType
		)
		if not treeTemplate then
			maxPerTreeType = targetTreeCount
			treeTemplate = pickDiverseTreeTemplate(
				treeTemplates,
				treeTypeCounts,
				targetTreeCount,
				maxPerTreeType
			)
			if not treeTemplate then
				treeTemplate = treeTemplates[math.random(1, #treeTemplates)]
			end
		end

		decorationIndex += 1
		local placed = placeDecorationOnHoleFloor(
			holeFloor,
			treeTemplate,
			rarityName,
			holeSide,
			decorationIndex,
			placedSpots,
			floorsFolder,
			overlapPadding,
			"tree"
		)
		if placed then
			treesPlaced += 1
			treeTypeCounts[treeTemplate.Name] = (treeTypeCounts[treeTemplate.Name] or 0) + 1
			return true
		end

		decorationIndex -= 1
		return true
	end

	while treesPlaced < targetTreeCount and placementAttempts < maxTreePlacementAttempts do
		placementAttempts += 1
		if not tryPlaceTree(Shared_GameProcess.TreeOverlapPadding, true) then
			break
		end
	end

	if treesPlaced < minTrees then
		local fallbackAttempts = 0
		local maxFallbackAttempts = minTrees * Shared_GameProcess.PlacementMaxAttempts * 3
		while treesPlaced < minTrees and fallbackAttempts < maxFallbackAttempts do
			fallbackAttempts += 1
			local relaxedPadding = math.max(
				Shared_GameProcess.TreeOverlapPadding
					- math.floor(fallbackAttempts / Shared_GameProcess.PlacementMaxAttempts) * 2,
				0
			)
			tryPlaceTree(relaxedPadding, false)
		end
	end

	return placedSpots
end
local function getFloorsFolder(): Folder
	local gameFolder = Workspace:FindFirstChild("Game")
	if not gameFolder then
		gameFolder = Instance.new("Folder")
		gameFolder.Name = "Game"
		gameFolder.Parent = Workspace
	end

	local mapFolder = gameFolder:FindFirstChild("Map")
	if not mapFolder then
		mapFolder = Instance.new("Folder")
		mapFolder.Name = "Map"
		mapFolder.Parent = gameFolder
	end

	local floorsFolder = mapFolder:FindFirstChild("Floors")
	if not floorsFolder then
		floorsFolder = Instance.new("Folder")
		floorsFolder.Name = "Floors"
		floorsFolder.Parent = mapFolder
	end

	return floorsFolder
end

type RarityBuildEntry = {
	floor: BasePart,
	rarityName: string,
	holeLayout: HoleFloorLayout,
}

local function isPersistentMapGeometry(instance: Instance): boolean
	if not instance:IsA("BasePart") then
		return false
	end

	if instance:GetAttribute("IsGameProcessWall") == true then
		return true
	end
	if instance:GetAttribute("IsHoleFloor") == true then
		return true
	end
	if instance:GetAttribute("IsEntranceFloor") == true then
		return true
	end
	if instance:GetAttribute("IsGameProcessRoadFloor") == true then
		return true
	end

	local rarity = instance:GetAttribute("Rarity")
	if type(rarity) == "string" and instance.Name == `{rarity}Floor` then
		return true
	end

	return false
end

local function hasMapGeometry(floorsFolder: Folder): boolean
	for _, child in floorsFolder:GetChildren() do
		if child:IsA("BasePart") and isPersistentMapGeometry(child) then
			local rarity = child:GetAttribute("Rarity")
			if type(rarity) == "string" and child.Name == `{rarity}Floor` then
				return true
			end
		end
	end
	return false
end

local function collectLiveMapEntries(floorsFolder: Folder): { RarityBuildEntry }
	local entries: { RarityBuildEntry } = {}

	for _, rarityName in getSortedRarities() do
		local floor = floorsFolder:FindFirstChild(`{rarityName}Floor`)
		if not floor or not floor:IsA("BasePart") then
			continue
		end

		local leftHoleFloor = floorsFolder:FindFirstChild(`{rarityName}LeftHoleFloor`)
		local rightHoleFloor = floorsFolder:FindFirstChild(`{rarityName}RightHoleFloor`)
		if not leftHoleFloor or not leftHoleFloor:IsA("BasePart") then
			continue
		end
		if not rightHoleFloor or not rightHoleFloor:IsA("BasePart") then
			continue
		end

		local holeWidthX = Shared_GameProcess.HoleFloorSize
		local halfHoleWidthX = holeWidthX / 2
		local halfFloorX = floor.Size.X / 2

		table.insert(entries, {
			floor = floor,
			rarityName = rarityName,
			holeLayout = {
				leftHoleFloor = leftHoleFloor,
				rightHoleFloor = rightHoleFloor,
				leftFootprintCenterX = floor.Position.X - halfFloorX - halfHoleWidthX,
				rightFootprintCenterX = floor.Position.X + halfFloorX + halfHoleWidthX,
				holeWidthX = holeWidthX,
			},
		})
	end

	return entries
end

local function buildMapGeometry(parent: Instance): boolean
	local context = getBuildContext()
	if not context then
		return false
	end

	local enterPart = context.enterPart
	local floorTemplate = context.floorTemplate
	local wallTemplate = context.wallTemplate
	local rarities = getSortedRarities()
	if #rarities == 0 then
		return false
	end

	local enterPosition = enterPart.Position
	local enterSize = enterPart.Size
	local originFloorHeight = floorTemplate.Size.Y
	local cursorZ = enterPosition.Z + enterSize.Z / 2
	local buildEntries: { RarityBuildEntry } = {}

	for _, rarityName in rarities do
		local floorSize = Shared_GameProcess.GetFloorSize(rarityName)
		if not floorSize then
			warn(`Missing floor size for rarity {rarityName}`)
			continue
		end

		local rarityData = Shared_Rarities.Data[rarityName]
		local floor = floorTemplate:Clone()
		floor.Name = `{rarityName}Floor`
		floor.Size = Vector3.new(enterSize.X, originFloorHeight, floorSize)
		floor.Position = Vector3.new(
			enterPosition.X,
			enterPosition.Y,
			cursorZ - floorSize / 2
		)
		local rarityColor = rarityData and rarityData.Color
		if rarityColor then
			floor.Color = rarityColor
		end
		floor:SetAttribute("Rarity", rarityName)
		floor:SetAttribute("IsGameProcessRoadFloor", true)
		floor.Parent = parent

		local holeLayout = placeHoleFloorsAndEntrancesForFloor(floor, floorTemplate, rarityName, parent)
		table.insert(buildEntries, {
			floor = floor,
			rarityName = rarityName,
			holeLayout = holeLayout,
		})

		cursorZ -= floorSize
	end

	for _, entry in buildEntries do
		placeWallsForFloor(entry.floor, wallTemplate, entry.rarityName, parent)
		placeHoleFloorWallsForFloor(wallTemplate, entry.rarityName, entry.holeLayout, parent)
	end

	return #buildEntries > 0
end

local function collectLuckyBlocks(root: Instance): { Model }
	local luckyBlocks: { Model } = {}
	for _, child in root:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("IsWorldLuckyBlock") == true then
			table.insert(luckyBlocks, child)
		end
	end
	return luckyBlocks
end

local function getLayoutGenerationInputs()
	local floorsFolder = getFloorsFolder()
	if not hasMapGeometry(floorsFolder) then
		if not buildMapGeometry(floorsFolder) then
			return nil
		end
	end

	local buildEntries = collectLiveMapEntries(floorsFolder)
	if #buildEntries == 0 then
		return nil
	end

	local context = getBuildContext()
	if not context then
		return nil
	end

	return context, buildEntries
end

export type LuckyZoneSpawnPlan = {
	holeFloor: BasePart,
	luckyBlockTemplate: Model,
	configName: string,
	rarityName: string,
	holeSide: string,
	luckyBlockCount: number,
	decorationSpots: { PlacedSpot },
	parent: Instance,
}

local function buildLuckyZoneSpawnPlans(
	buildEntries: { any },
	floorsFolder: Folder,
	zoneIndex: MapProcessDecorationQuery.ZoneDecorationIndex
): ({ LuckyZoneSpawnPlan }, number)
	local plans: { LuckyZoneSpawnPlan } = {}
	local totalSlots = 0
	local luckyBlockCountRange = Shared_GameProcess.LuckyBlocksPerHole

	for _, entry in buildEntries do
		local luckyBlockConfigName = Shared_LuckyBlocks.GetConfigNameForRarity(entry.rarityName)
		local luckyBlockTemplate = if luckyBlockConfigName
			then getLuckyBlockTemplate(luckyBlockConfigName)
			else nil
		if not luckyBlockConfigName or not luckyBlockTemplate then
			continue
		end

		local zones = {
			{ holeFloor = entry.holeLayout.leftHoleFloor, holeSide = "Left" },
			{ holeFloor = entry.holeLayout.rightHoleFloor, holeSide = "Right" },
		}

		for _, zone in zones do
			local luckyBlockCount = math.random(luckyBlockCountRange.Min, luckyBlockCountRange.Max)
			local zoneModels = MapProcessDecorationQuery.getZoneModels(zoneIndex, entry.rarityName, zone.holeSide)
			totalSlots += luckyBlockCount
			table.insert(plans, {
				holeFloor = zone.holeFloor,
				luckyBlockTemplate = luckyBlockTemplate,
				configName = luckyBlockConfigName,
				rarityName = entry.rarityName,
				holeSide = zone.holeSide,
				luckyBlockCount = luckyBlockCount,
				decorationSpots = collectDecorationSpotsOnHoleFloor(zone.holeFloor, zoneModels),
				parent = floorsFolder,
			})
		end
	end

	return plans, totalSlots
end

MapProcessMapContent.getFloorsFolder = getFloorsFolder
MapProcessMapContent.hasMapGeometry = hasMapGeometry
MapProcessMapContent.buildMapGeometry = buildMapGeometry
MapProcessMapContent.getLayoutGenerationInputs = getLayoutGenerationInputs
MapProcessMapContent.placeHoleFloorDecorationsForFloor = placeHoleFloorDecorationsForFloor
MapProcessMapContent.placeLianasOnRarityWalls = placeLianasOnRarityWalls
MapProcessMapContent.placeLiliesOnRarityWalls = placeLiliesOnRarityWalls
MapProcessMapContent.repositionMinimapDecorationsOnly = repositionMinimapDecorationsOnly
MapProcessMapContent.refreshMinimapTreesRandom = refreshMinimapTreesRandom
MapProcessMapContent.spawnLuckyBlocksForHoleFloor = spawnLuckyBlocksForHoleFloor
MapProcessMapContent.collectLuckyBlocks = collectLuckyBlocks
MapProcessMapContent.buildLuckyZoneSpawnPlans = buildLuckyZoneSpawnPlans

return MapProcessMapContent
