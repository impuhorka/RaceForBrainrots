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

local function getLianaTemplates(): { Model }
	local gameProcessAssets = getGameProcessAssets()
	local lianasFolder = gameProcessAssets and gameProcessAssets:FindFirstChild("Lianas")
	if not lianasFolder then
		return {}
	end

	local templates: { Model } = {}
	for _, child in lianasFolder:GetChildren() do
		if child:IsA("Model") then
			table.insert(templates, child)
		end
	end
	return templates
end

local MINIMAP_TREE_NAMES = { "Tree1", "Tree2", "Tree3" }
local MINIMAP_ROCK_NAMES = { "Rock1", "Rock2" }
local MINIMAP_BUSH_NAMES = { "Bush1", "Bush2" }

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

local function findDecorationTemplate(templates: { Model }, name: string): Model?
	for _, template in templates do
		if template.Name == name then
			return template
		end
	end
	return nil
end

local function getMinimapDecorationTemplates(decorationTemplates: { Model }, names: { string }): { Model }
	local templates: { Model } = {}
	for _, decorationName in names do
		local template = findDecorationTemplate(decorationTemplates, decorationName)
		if template then
			table.insert(templates, template)
		end
	end
	return templates
end

local function getMinimapTreeTemplates(decorationTemplates: { Model }): { Model }
	return getMinimapDecorationTemplates(decorationTemplates, MINIMAP_TREE_NAMES)
end

local function getMinimapRockTemplates(decorationTemplates: { Model }): { Model }
	return getMinimapDecorationTemplates(decorationTemplates, MINIMAP_ROCK_NAMES)
end

local function getMinimapBushTemplates(decorationTemplates: { Model }): { Model }
	return getMinimapDecorationTemplates(decorationTemplates, MINIMAP_BUSH_NAMES)
end

local function getFlowerTemplates(): { Model }
	local gameProcessAssets = getGameProcessAssets()
	local flowersFolder = gameProcessAssets and gameProcessAssets:FindFirstChild("Flowers")
	if not flowersFolder then
		return {}
	end

	local templates: { Model } = {}
	for _, child in flowersFolder:GetChildren() do
		if child:IsA("Model") then
			table.insert(templates, child)
		end
	end
	return templates
end

local function getGrassTemplates(): { Model }
	local gameProcessAssets = getGameProcessAssets()
	local grassFolder = gameProcessAssets and gameProcessAssets:FindFirstChild("Grass")
	if not grassFolder then
		return {}
	end

	local templates: { Model } = {}
	for _, child in grassFolder:GetChildren() do
		if child:IsA("Model") then
			table.insert(templates, child)
		end
	end
	return templates
end

local FLOWER_TOP_COLORS = {
	Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(255, 130, 210),
	Color3.fromRGB(170, 90, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(90, 150, 255),
	Color3.fromRGB(255, 150, 40),
}

local function applyFlowerTopColor(flower: Model)
	local colorPart = flower:FindFirstChild("ColorPart")
	if colorPart and colorPart:IsA("BasePart") then
		colorPart.Color = FLOWER_TOP_COLORS[math.random(1, #FLOWER_TOP_COLORS)]
	end
end

local function applyLianaFlowerColors(liana: Model)
	local flowersContainer = liana:FindFirstChild("Flowers")
	if not flowersContainer then
		return
	end

	for _, flower in flowersContainer:GetChildren() do
		if flower:IsA("Model") then
			applyFlowerTopColor(flower)
		end
	end
end

local function getDecorationExtents(decoration: Model): Vector3
	local extents = decoration:GetExtentsSize()
	if extents.Magnitude > 0 then
		return extents
	end

	local _, size = decoration:GetBoundingBox()
	return size
end

local function applyModelScaleRange(model: Model, minScale: number, maxScale: number)
	local originScale = Shared_Weight.GetModelOriginScale(model)
	local scaleMultiplier = minScale + math.random() * (maxScale - minScale)
	model:ScaleTo(originScale * scaleMultiplier)
end

local function applyDecorationScale(decoration: Model)
	applyModelScaleRange(decoration, Shared_GameProcess.DecorationScaleMin, Shared_GameProcess.DecorationScaleMax)
end

local function applyDecorationScaleKind(decoration: Model, scaleKind: string?)
	if scaleKind == "rock" then
		applyModelScaleRange(decoration, Shared_GameProcess.RockScaleMin, Shared_GameProcess.RockScaleMax)
	elseif scaleKind == "bush" then
		applyModelScaleRange(decoration, Shared_GameProcess.BushScaleMin, Shared_GameProcess.BushScaleMax)
	elseif scaleKind == "tree" then
		applyModelScaleRange(decoration, Shared_GameProcess.TreeScaleMin, Shared_GameProcess.TreeScaleMax)
	else
		applyDecorationScale(decoration)
	end
end

local function applyLianaScale(liana: Model)
	local originScale = Shared_Weight.GetModelOriginScale(liana)
	local minScale = Shared_GameProcess.LianaScaleMin
	local maxScale = Shared_GameProcess.LianaScaleMax
	local scaleMultiplier = minScale + math.random() * (maxScale - minScale)
	liana:ScaleTo(originScale * scaleMultiplier)
end

local function getLianaSpawnChance(wall: BasePart): number
	local baseChance = Shared_GameProcess.LianasOnWallChance
	local side = wall:GetAttribute("Side")
	if side == "Left" or side == "Right" then
		return math.min(baseChance * Shared_GameProcess.LianasRoadWallChanceMultiplier, 1)
	end
	if side == "Front" or side == "Back" or side == "Outer" then
		return math.min(baseChance * Shared_GameProcess.LianasMinimapWallChanceMultiplier, 1)
	end
	return baseChance
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

local function getModelsClusterSpot(models: { Model }): PlacedSpot
	local minX = math.huge
	local maxX = -math.huge
	local minZ = math.huge
	local maxZ = -math.huge

	for _, model in models do
		local bboxCF, bboxSize = model:GetBoundingBox()
		local halfX = bboxSize.X / 2
		local halfZ = bboxSize.Z / 2
		minX = math.min(minX, bboxCF.Position.X - halfX)
		maxX = math.max(maxX, bboxCF.Position.X + halfX)
		minZ = math.min(minZ, bboxCF.Position.Z - halfZ)
		maxZ = math.max(maxZ, bboxCF.Position.Z + halfZ)
	end

	return {
		X = (minX + maxX) / 2,
		Z = (minZ + maxZ) / 2,
		HalfX = (maxX - minX) / 2,
		HalfZ = (maxZ - minZ) / 2,
	}
end

local function getModelLowestWorldY(model: Model): number
	local lowest = math.huge
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			local cf = part.CFrame
			local halfSize = part.Size / 2
			for sx = -1, 1, 2 do
				for sy = -1, 1, 2 do
					for sz = -1, 1, 2 do
						local cornerY = cf:PointToWorldSpace(
							Vector3.new(halfSize.X * sx, halfSize.Y * sy, halfSize.Z * sz)
						).Y
						if cornerY < lowest then
							lowest = cornerY
						end
					end
				end
			end
		end
	end

	if lowest == math.huge then
		local bboxCF, bboxSize = model:GetBoundingBox()
		return bboxCF.Position.Y - bboxSize.Y / 2
	end

	return lowest
end

local function snapModelBottomToY(model: Model, targetBottomY: number)
	local lowestY = getModelLowestWorldY(model)
	local lift = targetBottomY - lowestY
	if math.abs(lift) > 1e-4 then
		model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
	end
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

local function getFlowerStandRotation(model: Model, templateName: string): CFrame
	local yaw = math.random() * math.pi * 2

	if templateName == "GroundFlower" then
		return CFrame.Angles(0, yaw, math.rad(-90))
	end

	local extents = model:GetExtentsSize()
	local longestAxis = "Y"
	local longestSize = extents.Y
	if extents.X > longestSize then
		longestAxis = "X"
		longestSize = extents.X
	end
	if extents.Z > longestSize then
		longestAxis = "Z"
	end

	local upright: CFrame
	if longestAxis == "Y" then
		upright = CFrame.Angles(0, yaw, 0)
	elseif longestAxis == "X" then
		upright = CFrame.Angles(0, yaw, math.rad(90))
	else
		upright = CFrame.Angles(math.rad(-90), yaw, 0)
	end

	return upright * CFrame.Angles(0, 0, math.rad(180))
end

local function tryPlaceModelOnHoleFloor(
	holeFloor: BasePart,
	model: Model,
	placedSpots: { PlacedSpot },
	flowerTemplateName: string?,
	useWorldFootprint: boolean?,
	overlapPaddingOverride: number?
): boolean
	local halfHoleX = holeFloor.Size.X / 2
	local halfHoleZ = holeFloor.Size.Z / 2
	local edgeMargin = Shared_GameProcess.DecorationEdgeMargin
	local floorTopY = holeFloor.Position.Y + holeFloor.Size.Y / 2
	local overlapPadding = overlapPaddingOverride or Shared_GameProcess.PlacementOverlapPadding
	local maxAttempts = Shared_GameProcess.PlacementMaxAttempts

	local function nextRotation(): CFrame
		if flowerTemplateName then
			return getFlowerStandRotation(model, flowerTemplateName)
		end
		return CFrame.Angles(0, math.random() * math.pi * 2, 0)
	end

	local rotation = nextRotation()
	model:PivotTo(CFrame.new(holeFloor.Position) * rotation)

	local function getWorldFootprintHalfSize(): (number, number)
		if flowerTemplateName or useWorldFootprint then
			local _, bboxSize = model:GetBoundingBox()
			return bboxSize.X / 2, bboxSize.Z / 2
		end
		local modelSize = getDecorationExtents(model)
		return modelSize.X / 2, modelSize.Z / 2
	end

	local halfModelX, halfModelZ = getWorldFootprintHalfSize()
	local maxOffsetX = math.max(halfHoleX - halfModelX - edgeMargin, 0)
	local maxOffsetZ = math.max(halfHoleZ - halfModelZ - edgeMargin, 0)

	for _ = 1, maxAttempts do
		local offsetX = if maxOffsetX > 0 then (math.random() * 2 - 1) * maxOffsetX else 0
		local offsetZ = if maxOffsetZ > 0 then (math.random() * 2 - 1) * maxOffsetZ else 0

		rotation = nextRotation()
		model:PivotTo(CFrame.new(holeFloor.Position) * rotation)

		local bboxCF, _bboxSize = model:GetBoundingBox()
		local positionDelta = Vector3.new(
			holeFloor.Position.X + offsetX - bboxCF.Position.X,
			0,
			holeFloor.Position.Z + offsetZ - bboxCF.Position.Z
		)
		model:PivotTo(model:GetPivot() + positionDelta)
		snapModelBottomToY(model, floorTopY)

		halfModelX, halfModelZ = getWorldFootprintHalfSize()
		maxOffsetX = math.max(halfHoleX - halfModelX - edgeMargin, 0)
		maxOffsetZ = math.max(halfHoleZ - halfModelZ - edgeMargin, 0)

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
	decoration.Parent = parent
	return true
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
		nil,
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
	rarityName: string,
	holeSide: string,
	index: number,
	parent: Instance
)
	flower.Name = `{rarityName}{holeSide}Flower{index}`
	flower:SetAttribute("Rarity", rarityName)
	flower:SetAttribute("HoleSide", holeSide)
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

	finalizeFlowerOnHoleFloor(flower, rarityName, holeSide, index, parent)
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
				placeFlowerAt(holeFloor, flower, template.Name, anchorSpot.X, anchorSpot.Z)
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
				finalizeFlowerOnHoleFloor(flower, rarityName, holeSide, flowerIndex, parent)
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

local function placeLianaOnWall(
	wall: BasePart,
	template: Model,
	index: number,
	rarityName: string,
	parent: Instance
)
	local liana = template:Clone()
	liana.Name = `{rarityName}WallLiana{index}`
	prepareAnchoredModel(liana)
	applyLianaScale(liana)
	applyLianaFlowerColors(liana)

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
	liana:PivotTo(CFrame.lookAt(position, lookTarget) * CFrame.Angles(0, -math.pi / 2, 0))

	local _bboxCF, bboxSize = liana:GetBoundingBox()
	local lianaHalfThickness = if runsAlongZ then bboxSize.X / 2 else bboxSize.Z / 2
	liana:PivotTo(liana:GetPivot() + interiorDir * lianaHalfThickness)

	local bboxCF, bboxSize = liana:GetBoundingBox()
	local targetBottomY = wallTopY - bboxSize.Y
	local bboxBottomY = bboxCF.Position.Y - bboxSize.Y / 2
	liana:PivotTo(liana:GetPivot() + Vector3.new(0, targetBottomY - bboxBottomY, 0))
	liana:SetAttribute("Rarity", rarityName)
	liana.Parent = parent
end

local function placeLianasOnRarityWalls(
	parent: Instance,
	rarityName: string,
	lianaTemplates: { Model }
)
	if #lianaTemplates == 0 then
		return
	end

	local lianaIndex = 0

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
		if math.random() > getLianaSpawnChance(child) then
			continue
		end

		lianaIndex += 1
		local template = lianaTemplates[math.random(1, #lianaTemplates)]
		placeLianaOnWall(child, template, lianaIndex, rarityName, parent)
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
	flowerTemplates: { Model },
	grassTemplates: { Model },
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

	placeFlowersForHoleFloor(leftHoleFloor, flowerTemplates, rarityName, "Left", leftPlacedSpots, parent)
	placeFlowersForHoleFloor(rightHoleFloor, flowerTemplates, rarityName, "Right", rightPlacedSpots, parent)

	placeGrassForHoleFloor(leftHoleFloor, grassTemplates, rarityName, "Left", leftPlacedSpots, parent)
	placeGrassForHoleFloor(rightHoleFloor, grassTemplates, rarityName, "Right", rightPlacedSpots, parent)

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

	local flowerTemplates = getFlowerTemplates()
	if #flowerTemplates == 0 then
		warn("Missing ReplicatedStorage.Assets.GameProcess.Flowers models")
	end

	local grassTemplates = getGrassTemplates()
	if #grassTemplates == 0 then
		warn("Missing ReplicatedStorage.Assets.GameProcess.Grass models")
	end

	local lianaTemplates = getLianaTemplates()
	if #lianaTemplates == 0 then
		warn("Missing ReplicatedStorage.Assets.GameProcess.Lianas models")
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
		placeHoleFloorsForFloor(
			floor,
			floorTemplate,
			wallTemplate,
			decorationTemplates,
			flowerTemplates,
			grassTemplates,
			rarityName,
			floorsFolder
		)
		placeLianasOnRarityWalls(floorsFolder, rarityName, lianaTemplates)

		cursorZ -= floorSize
	end
end

return GameProcessFloors