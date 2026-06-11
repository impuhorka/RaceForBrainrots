local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_GameProcess = SharedModules.require("Shared_GameProcess")
local Shared_Weight = SharedModules.require("Shared_Weight")
local MapProcessAssets = require(script.Parent.MapProcessAssets)

local Assets = MapProcessAssets
local MapProcessPlacement = {}

export type PlacedSpot = {
	X: number,
	Z: number,
	HalfX: number,
	HalfZ: number,
}

function MapProcessPlacement.getModelFloorSpot(model: Model): PlacedSpot
	local bboxCF, bboxSize = model:GetBoundingBox()
	return {
		X = bboxCF.Position.X,
		Z = bboxCF.Position.Z,
		HalfX = bboxSize.X / 2,
		HalfZ = bboxSize.Z / 2,
	}
end

function MapProcessPlacement.getModelsClusterSpot(models: { Model }): PlacedSpot
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

function MapProcessPlacement.getModelLowestWorldY(model: Model): number
	local bboxCF, bboxSize = model:GetBoundingBox()
	return bboxCF.Position.Y - bboxSize.Y / 2
end

function MapProcessPlacement.snapModelBottomToY(model: Model, targetBottomY: number)
	local lowestY = MapProcessPlacement.getModelLowestWorldY(model)
	local lift = targetBottomY - lowestY
	if math.abs(lift) > 1e-4 then
		model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
	end
end

function MapProcessPlacement.spotsOverlap(a: PlacedSpot, b: PlacedSpot, padding: number): boolean
	return math.abs(a.X - b.X) < (a.HalfX + b.HalfX + padding)
		and math.abs(a.Z - b.Z) < (a.HalfZ + b.HalfZ + padding)
end

function MapProcessPlacement.canPlaceSpot(candidate: PlacedSpot, placedSpots: { PlacedSpot }, padding: number): boolean
	for _, spot in placedSpots do
		if MapProcessPlacement.spotsOverlap(candidate, spot, padding) then
			return false
		end
	end
	return true
end

function MapProcessPlacement.shuffleArray(array: { any })
	for index = #array, 2, -1 do
		local swapIndex = math.random(1, index)
		array[index], array[swapIndex] = array[swapIndex], array[index]
	end
end

function MapProcessPlacement.isLuckyBlockSpotValid(
	candidate: PlacedSpot,
	decorationSpots: { PlacedSpot },
	luckyBlockSpots: { PlacedSpot }
): boolean
	for _, spot in decorationSpots do
		if MapProcessPlacement.spotsOverlap(candidate, spot, Shared_GameProcess.PlacementOverlapPadding) then
			return false
		end
	end

	local luckyBlockPadding = Shared_GameProcess.LuckyBlockOverlapPadding
	for _, spot in luckyBlockSpots do
		if MapProcessPlacement.spotsOverlap(candidate, spot, luckyBlockPadding) then
			return false
		end
	end

	return true
end

function MapProcessPlacement.generateLuckyBlockCandidatePositions(
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
	MapProcessPlacement.shuffleArray(cells)

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

	MapProcessPlacement.shuffleArray(candidates)
	return candidates
end

function MapProcessPlacement.placeModelOnHoleFloorAt(
	holeFloor: BasePart,
	model: Model,
	worldX: number,
	worldZ: number
): PlacedSpot
	local floorTopY = holeFloor.Position.Y + holeFloor.Size.Y / 2
	Shared_Weight.SyncLuckyBlockPivot(model)
	local rotation = CFrame.Angles(0, math.random() * math.pi * 2, 0)

	model:PivotTo(CFrame.new(worldX, holeFloor.Position.Y, worldZ) * rotation)

	local bboxCF, bboxSize = model:GetBoundingBox()
	local bboxBottomY = bboxCF.Position.Y - bboxSize.Y / 2
	local yLift = floorTopY - bboxBottomY
	model:PivotTo(model:GetPivot() + Vector3.new(0, yLift, 0))

	return MapProcessPlacement.getModelFloorSpot(model)
end

function MapProcessPlacement.tryPlaceLuckyBlockOnHoleFloor(
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

	Shared_Weight.SyncLuckyBlockPivot(model)
	local modelSize = Assets.getDecorationExtents(model)
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
		local spot = MapProcessPlacement.placeModelOnHoleFloorAt(holeFloor, model, position.X, position.Z)
		if MapProcessPlacement.isLuckyBlockSpotValid(spot, decorationSpots, luckyBlockSpots) then
			table.insert(luckyBlockSpots, spot)
			return true
		end
	end

	return false
end

function MapProcessPlacement.getFlowerStandRotation(model: Model, templateName: string): CFrame
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

function MapProcessPlacement.tryPlaceModelOnHoleFloor(
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
			return MapProcessPlacement.getFlowerStandRotation(model, flowerTemplateName)
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
		local modelSize = Assets.getDecorationExtents(model)
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
		MapProcessPlacement.snapModelBottomToY(model, floorTopY)

		halfModelX, halfModelZ = getWorldFootprintHalfSize()
		maxOffsetX = math.max(halfHoleX - halfModelX - edgeMargin, 0)
		maxOffsetZ = math.max(halfHoleZ - halfModelZ - edgeMargin, 0)

		local spot = MapProcessPlacement.getModelFloorSpot(model)
		if MapProcessPlacement.canPlaceSpot(spot, placedSpots, overlapPadding) then
			table.insert(placedSpots, spot)
			return true
		end
	end

	return false
end

return MapProcessPlacement
