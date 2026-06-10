local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local Workspace = game:GetService("Workspace")

local Shared_GameProcess = SharedModules.require("Shared_GameProcess")
local Shared_LuckyBlockBillboard = SharedModules.require("Shared_LuckyBlockBillboard")
local Shared_LuckyBlocks = SharedModules.require("Shared_LuckyBlocks")
local Shared_Rarities = SharedModules.require("Shared_Rarities")
local Shared_Weight = SharedModules.require("Shared_Weight")

local GameProcessService = require(script.Parent.GameProcessService)

type PlacedSpot = {
	X: number,
	Z: number,
	HalfX: number,
	HalfZ: number,
}

local GameProcessFloors = {}

local function getGameProcessAssets(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local gameProcessAssets = assets and assets:FindFirstChild("GameProcess")
	if gameProcessAssets and gameProcessAssets:IsA("Folder") then
		return gameProcessAssets
	end
	return nil
end

local function getFloorTemplate(): BasePart?
	local gameProcessAssets = getGameProcessAssets()
	local floorPart = gameProcessAssets and gameProcessAssets:FindFirstChild("FloorPart")
	if floorPart and floorPart:IsA("BasePart") then
		return floorPart
	end
	return nil
end

local function getWallTemplate(): BasePart?
	local gameProcessAssets = getGameProcessAssets()
	local wall = gameProcessAssets and gameProcessAssets:FindFirstChild("Wall")
	if wall and wall:IsA("BasePart") then
		return wall
	end
	return nil
end

local function getLeavesTemplates(): { Model }
	local gameProcessAssets = getGameProcessAssets()
	local leavesRoot = gameProcessAssets and gameProcessAssets:FindFirstChild("Leaves")
	if not leavesRoot then
		return {}
	end

	local templates: { Model } = {}
	if leavesRoot:IsA("Model") then
		table.insert(templates, leavesRoot)
	elseif leavesRoot:IsA("Folder") then
		for _, child in leavesRoot:GetChildren() do
			if child:IsA("Model") then
				table.insert(templates, child)
			end
		end
	end
	return templates
end

local function getDecorationTemplates(): { Model }
	local gameProcessAssets = getGameProcessAssets()
	local decorationsFolder = gameProcessAssets and gameProcessAssets:FindFirstChild("Decorations")
	if not decorationsFolder then
		return {}
	end

	local templates: { Model } = {}
	for _, child in decorationsFolder:GetChildren() do
		if child:IsA("Model") then
			table.insert(templates, child)
		end
	end
	return templates
end

local function getDecorationExtents(decoration: Model): Vector3
	local extents = decoration:GetExtentsSize()
	if extents.Magnitude > 0 then
		return extents
	end

	local _, size = decoration:GetBoundingBox()
	return size
end

local function applyDecorationScale(decoration: Model)
	local originScale = Shared_Weight.GetModelOriginScale(decoration)
	local minScale = Shared_GameProcess.DecorationScaleMin
	local maxScale = Shared_GameProcess.DecorationScaleMax
	local scaleMultiplier = minScale + math.random() * (maxScale - minScale)
	decoration:ScaleTo(originScale * scaleMultiplier)
end

local function prepareAnchoredModel(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
end

local function getModelFloorSpot(model: Model): PlacedSpot
	local bboxCF, bboxSize = model:GetBoundingBox()
	return {
		X = bboxCF.Position.X,
		Z = bboxCF.Position.Z,
		HalfX = bboxSize.X / 2,
		HalfZ = bboxSize.Z / 2,
	}
end

local function spotsOverlap(a: PlacedSpot, b: PlacedSpot, padding: number): boolean
	return math.abs(a.X - b.X) < (a.HalfX + b.HalfX + padding)
		and math.abs(a.Z - b.Z) < (a.HalfZ + b.HalfZ + padding)
end

local function canPlaceSpot(candidate: PlacedSpot, placedSpots: { PlacedSpot }, padding: number): boolean
	for _, spot in placedSpots do
		if spotsOverlap(candidate, spot, padding) then
			return false
		end
	end
	return true
end

local function shuffleArray(array: { any })
	for index = #array, 2, -1 do
		local swapIndex = math.random(1, index)
		array[index], array[swapIndex] = array[swapIndex], array[index]
	end
end

local function isLuckyBlockSpotValid(
	candidate: PlacedSpot,
	decorationSpots: { PlacedSpot },
	luckyBlockSpots: { PlacedSpot }
): boolean
	for _, spot in decorationSpots do
		if spotsOverlap(candidate, spot, Shared_GameProcess.PlacementOverlapPadding) then
			return false
		end
	end

	local luckyBlockPadding = Shared_GameProcess.LuckyBlockOverlapPadding
	for _, spot in luckyBlockSpots do
		if spotsOverlap(candidate, spot, luckyBlockPadding) then
			return false
		end
	end

	return true
end

local function generateLuckyBlockCandidatePositions(
	holeFloor: BasePart,
	count: number,
	modelHalfX: number,
	modelHalfZ: number
): { { X: number, Z: number } }
	local halfHoleX = holeFloor.Size.X / 2
	local halfHoleZ = holeFloor.Size.Z / 2
	local edgeMargin = Shared_GameProcess.DecorationEdgeMargin
	local usableX = math.max(holeFloor.Size.X - edgeMargin * 2 - modelHalfX * 2, 1)
	local usableZ = math.max(holeFloor.Size.Z - edgeMargin * 2 - modelHalfZ * 2, 1)
	local aspect = usableX / usableZ

	local columns = math.max(1, math.ceil(math.sqrt(count * aspect)))
	local rows = math.max(1, math.ceil(count / columns))

	local cells: { { Row: number, Column: number } } = {}
	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			table.insert(cells, { Row = row, Column = column })
		end
	end
	shuffleArray(cells)

	local cellWidth = usableX / columns
	local cellDepth = usableZ / rows
	local minX = holeFloor.Position.X - usableX / 2
	local minZ = holeFloor.Position.Z - usableZ / 2
	local candidates: { { X: number, Z: number } } = {}

	for index = 1, math.min(count, #cells) do
		local cell = cells[index]
		local jitterX = (math.random() - 0.5) * cellWidth * 0.45
		local jitterZ = (math.random() - 0.5) * cellDepth * 0.45
		table.insert(candidates, {
			X = minX + cellWidth * (cell.Column + 0.5) + jitterX,
			Z = minZ + cellDepth * (cell.Row + 0.5) + jitterZ,
		})
	end

	shuffleArray(candidates)
	return candidates
end

local function placeModelOnHoleFloorAt(
	holeFloor: BasePart,
	model: Model,
	worldX: number,
	worldZ: number
): PlacedSpot
	local floorTopY = holeFloor.Position.Y + holeFloor.Size.Y / 2
	local rotation = CFrame.Angles(0, math.random() * math.pi * 2, 0)

	model:PivotTo(CFrame.new(worldX, holeFloor.Position.Y, worldZ) * rotation)

	local bboxCF, bboxSize = model:GetBoundingBox()
	local bboxBottomY = bboxCF.Position.Y - bboxSize.Y / 2
	local yLift = floorTopY - bboxBottomY
	model:PivotTo(model:GetPivot() + Vector3.new(0, yLift, 0))

	return getModelFloorSpot(model)
end

local function tryPlaceLuckyBlockOnHoleFloor(
	holeFloor: BasePart,
	model: Model,
	decorationSpots: { PlacedSpot },
	luckyBlockSpots: { PlacedSpot },
	candidatePositions: { { X: number, Z: number } }
): boolean
	local maxAttempts = Shared_GameProcess.LuckyBlockPlacementMaxAttempts
	local halfHoleX = holeFloor.Size.X / 2
	local halfHoleZ = holeFloor.Size.Z / 2
	local edgeMargin = Shared_GameProcess.DecorationEdgeMargin

	model:PivotTo(CFrame.new(holeFloor.Position))
	local modelSize = getDecorationExtents(model)
	local halfModelX = modelSize.X / 2
	local halfModelZ = modelSize.Z / 2
	local maxOffsetX = math.max(halfHoleX - halfModelX - edgeMargin, 0)
	local maxOffsetZ = math.max(halfHoleZ - halfModelZ - edgeMargin, 0)

	local tryPositions: { { X: number, Z: number } } = {}
	for _, candidate in candidatePositions do
		table.insert(tryPositions, candidate)
	end

	for _ = 1, maxAttempts do
		local offsetX = if maxOffsetX > 0 then (math.random() * 2 - 1) * maxOffsetX else 0
		local offsetZ = if maxOffsetZ > 0 then (math.random() * 2 - 1) * maxOffsetZ else 0
		table.insert(tryPositions, {
			X = holeFloor.Position.X + offsetX,
			Z = holeFloor.Position.Z + offsetZ,
		})
	end

	for _, position in tryPositions do
		local spot = placeModelOnHoleFloorAt(holeFloor, model, position.X, position.Z)
		if isLuckyBlockSpotValid(spot, decorationSpots, luckyBlockSpots) then
			table.insert(luckyBlockSpots, spot)
			return true
		end
	end

	return false
end

local function tryPlaceModelOnHoleFloor(
	holeFloor: BasePart,
	model: Model,
	placedSpots: { PlacedSpot }
): boolean
	local halfHoleX = holeFloor.Size.X / 2
	local halfHoleZ = holeFloor.Size.Z / 2
	local edgeMargin = Shared_GameProcess.DecorationEdgeMargin
	local floorTopY = holeFloor.Position.Y + holeFloor.Size.Y / 2
	local overlapPadding = Shared_GameProcess.PlacementOverlapPadding
	local maxAttempts = Shared_GameProcess.PlacementMaxAttempts
	local rotation = CFrame.Angles(0, math.random() * math.pi * 2, 0)

	model:PivotTo(CFrame.new(holeFloor.Position) * rotation)

	local modelSize = getDecorationExtents(model)
	local halfModelX = modelSize.X / 2
	local halfModelZ = modelSize.Z / 2
	local maxOffsetX = math.max(halfHoleX - halfModelX - edgeMargin, 0)
	local maxOffsetZ = math.max(halfHoleZ - halfModelZ - edgeMargin, 0)

	for _ = 1, maxAttempts do
		local offsetX = if maxOffsetX > 0 then (math.random() * 2 - 1) * maxOffsetX else 0
		local offsetZ = if maxOffsetZ > 0 then (math.random() * 2 - 1) * maxOffsetZ else 0

		model:PivotTo(CFrame.new(holeFloor.Position) * rotation)

		local bboxCF, bboxSize = model:GetBoundingBox()
		local bboxBottomY = bboxCF.Position.Y - bboxSize.Y / 2
		local yLift = floorTopY - bboxBottomY
		local positionDelta = Vector3.new(
			holeFloor.Position.X + offsetX - bboxCF.Position.X,
			yLift,
			holeFloor.Position.Z + offsetZ - bboxCF.Position.Z
		)
		model:PivotTo(model:GetPivot() + positionDelta)

		local spot = getModelFloorSpot(model)
		if canPlaceSpot(spot, placedSpots, overlapPadding) then
			table.insert(placedSpots, spot)
			return true
		end
	end

	return false
end

local function getLuckyBlockTemplate(configName: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local luckyBlocks = assets and assets:FindFirstChild("LuckyBlocks")
	local template = luckyBlocks and luckyBlocks:FindFirstChild(configName)
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

local function prepareLuckyBlockModel(model: Model)
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
	end
	prepareAnchoredModel(model)
end

local function placeDecorationOnHoleFloor(
	holeFloor: BasePart,
	template: Model,
	rarityName: string,
	holeSide: string,
	index: number,
	placedSpots: { PlacedSpot },
	parent: Instance
)
	local decoration = template:Clone()
	decoration.Name = `{rarityName}{holeSide}Decoration{index}`
	prepareAnchoredModel(decoration)
	applyDecorationScale(decoration)

	if not tryPlaceModelOnHoleFloor(holeFloor, decoration, placedSpots) then
		decoration:Destroy()
		return
	end

	decoration:SetAttribute("Rarity", rarityName)
	decoration:SetAttribute("HoleSide", holeSide)
	decoration.Parent = parent
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
	luckyBlock:SetAttribute("FloatHeight", floatHeight)

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
	if #decorationTemplates == 0 then
		return placedSpots
	end

	local decorationCountRange = Shared_GameProcess.DecorationsPerHole
	local decorationCount = math.random(decorationCountRange.Min, decorationCountRange.Max)

	for index = 1, decorationCount do
		local template = decorationTemplates[math.random(1, #decorationTemplates)]
		placeDecorationOnHoleFloor(holeFloor, template, rarityName, holeSide, index, placedSpots, parent)
	end

	return placedSpots
end

local function placeLuckyBlocksForHoleFloor(
	holeFloor: BasePart,
	luckyBlockTemplate: Model,
	configName: string,
	rarityName: string,
	holeSide: string,
	decorationSpots: { PlacedSpot },
	parent: Instance
)
	local luckyBlockCountRange = Shared_GameProcess.LuckyBlocksPerHole
	local luckyBlockCount = math.random(luckyBlockCountRange.Min, luckyBlockCountRange.Max)
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
		luckyBlockCount,
		previewSize.X / 2,
		previewSize.Z / 2
	)

	for index = 1, luckyBlockCount do
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
	local halfWallY = wallSize.Y / 2
	local wallY = floor.Position.Y - floor.Size.Y + halfWallY
	local wallZ = floor.Position.Z + frontOpening / 2

	local leftWall = wallTemplate:Clone()
	leftWall.Name = `{rarityName}LeftWall`
	leftWall.Size = wallSize
	leftWall.Position = Vector3.new(
		floor.Position.X - halfFloorX,
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
		floor.Position.X + halfFloorX,
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
	wall.Parent = parent
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

local function placeLeafOnWall(
	wall: BasePart,
	template: Model,
	index: number,
	rarityName: string,
	parent: Instance
)
	local leaf = template:Clone()
	leaf.Name = `{rarityName}WallLeaf{index}`
	prepareAnchoredModel(leaf)

	local wallTopY = wall.Position.Y + wall.Size.Y / 2
	local edgeMargin = 1.5
	local runsAlongZ = wall.Size.Z > wall.Size.X
	local worldX: number
	local worldZ: number

	if runsAlongZ then
		worldX = wall.Position.X
		local halfRun = math.max(wall.Size.Z / 2 - edgeMargin, 0)
		worldZ = wall.Position.Z + (math.random() * 2 - 1) * halfRun
	else
		worldZ = wall.Position.Z
		local halfRun = math.max(wall.Size.X / 2 - edgeMargin, 0)
		worldX = wall.Position.X + (math.random() * 2 - 1) * halfRun
	end

	local interiorDir = getWallInteriorDirection(wall)
	local wallHalfThickness = if runsAlongZ then wall.Size.X / 2 else wall.Size.Z / 2
	local position = Vector3.new(worldX, wallTopY, worldZ) + interiorDir * wallHalfThickness
	local lookTarget = position + interiorDir
	leaf:PivotTo(CFrame.lookAt(position, lookTarget) * CFrame.Angles(0, -math.pi / 2, 0))

	local bboxCF, bboxSize = leaf:GetBoundingBox()
	local targetBottomY = wallTopY - bboxSize.Y
	local bboxBottomY = bboxCF.Position.Y - bboxSize.Y / 2
	leaf:PivotTo(leaf:GetPivot() + Vector3.new(0, targetBottomY - bboxBottomY, 0))
	leaf:SetAttribute("Rarity", rarityName)
	leaf.Parent = parent
end

local function placeLeavesOnRarityWalls(
	parent: Instance,
	rarityName: string,
	leavesTemplates: { Model }
)
	if #leavesTemplates == 0 then
		return
	end

	local leafChance = Shared_GameProcess.LeavesOnWallChance
	local leafIndex = 0

	for _, child in parent:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end
		if child:GetAttribute("IsGameProcessWall") ~= true then
			continue
		end
		if child:GetAttribute("Rarity") ~= rarityName then
			continue
		end
		if math.random() > leafChance then
			continue
		end

		leafIndex += 1
		local template = leavesTemplates[math.random(1, #leavesTemplates)]
		placeLeafOnWall(child, template, leafIndex, rarityName, parent)
	end
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

local function placeHoleFloorsForFloor(
	floor: BasePart,
	floorTemplate: BasePart,
	wallTemplate: BasePart,
	decorationTemplates: { Model },
	rarityName: string,
	parent: Instance
): (BasePart, BasePart)
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
	placeWallsForHoleFloor(
		leftHoleFloor,
		wallTemplate,
		rarityName,
		"Left",
		leftFootprintCenterX,
		holeWidthX,
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
	placeWallsForHoleFloor(
		rightHoleFloor,
		wallTemplate,
		rarityName,
		"Right",
		rightFootprintCenterX,
		holeWidthX,
		parent
	)
	placeEntranceFloor(rightHoleFloor, floorTemplate, rarityName, "Right", parent)

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

	local luckyBlockConfigName = Shared_LuckyBlocks.GetConfigNameForRarity(rarityName)
	local luckyBlockTemplate = if luckyBlockConfigName then getLuckyBlockTemplate(luckyBlockConfigName) else nil
	if luckyBlockConfigName and not luckyBlockTemplate then
		warn(`Missing ReplicatedStorage.Assets.LuckyBlocks.{luckyBlockConfigName}`)
	elseif luckyBlockTemplate and luckyBlockConfigName then
		placeLuckyBlocksForHoleFloor(
			leftHoleFloor,
			luckyBlockTemplate,
			luckyBlockConfigName,
			rarityName,
			"Left",
			leftPlacedSpots,
			parent
		)
		placeLuckyBlocksForHoleFloor(
			rightHoleFloor,
			luckyBlockTemplate,
			luckyBlockConfigName,
			rarityName,
			"Right",
			rightPlacedSpots,
			parent
		)
	end

	return leftHoleFloor, rightHoleFloor
end

local function getSortedRarities(): { string }
	local rarities: { { Name: string, LayoutOrder: number } } = {}
	for rarityName, rarityData in Shared_Rarities.Data do
		table.insert(rarities, {
			Name = rarityName,
			LayoutOrder = rarityData.LayoutOrder or 0,
		})
	end

	table.sort(rarities, function(a, b)
		if a.LayoutOrder == b.LayoutOrder then
			return a.Name < b.Name
		end
		return a.LayoutOrder < b.LayoutOrder
	end)

	local orderedNames: { string } = {}
	for _, rarity in rarities do
		table.insert(orderedNames, rarity.Name)
	end
	return orderedNames
end

function GameProcessFloors.Setup()
	local zones = Workspace:FindFirstChild("Zones")
	local enterPart = zones and zones:FindFirstChild("EnterPart")
	if not enterPart or not enterPart:IsA("BasePart") then
		warn("Missing workspace.Zones.EnterPart")
		return
	end

	local floorTemplate = getFloorTemplate()
	if not floorTemplate then
		warn("Missing ReplicatedStorage.Assets.GameProcess.FloorPart")
		return
	end

	local wallTemplate = getWallTemplate()
	if not wallTemplate then
		warn("Missing ReplicatedStorage.Assets.GameProcess.Wall")
		return
	end

	local decorationTemplates = getDecorationTemplates()
	if #decorationTemplates == 0 then
		warn("Missing ReplicatedStorage.Assets.GameProcess.Decorations models")
	end

	local leavesTemplates = getLeavesTemplates()
	if #leavesTemplates == 0 then
		warn("Missing ReplicatedStorage.Assets.GameProcess.Leaves models")
	end

	local floorsFolder = zones:FindFirstChild("Floors")
	if not floorsFolder then
		floorsFolder = Instance.new("Folder")
		floorsFolder.Name = "Floors"
		floorsFolder.Parent = zones
	end

	for _, child in floorsFolder:GetChildren() do
		child:Destroy()
	end

	local enterPosition = enterPart.Position
	local enterSize = enterPart.Size
	local originFloorHeight = floorTemplate.Size.Y
	local cursorZ = enterPosition.Z + enterSize.Z / 2

	for _, rarityName in getSortedRarities() do
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
		floor.Parent = floorsFolder

		placeWallsForFloor(floor, wallTemplate, rarityName, floorsFolder)
		placeHoleFloorsForFloor(floor, floorTemplate, wallTemplate, decorationTemplates, rarityName, floorsFolder)
		placeLeavesOnRarityWalls(floorsFolder, rarityName, leavesTemplates)

		cursorZ -= floorSize
	end
end

return GameProcessFloors