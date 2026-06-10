local Shared_GameProcess = require(script.Parent.Shared_GameProcess)
local Shared_Rarities = require(script.Parent.Parent.Game.Shared_Rarities)

export type RoadSegment = {
	Rarity: string,
	WidthScale: number,
	ColorGradient: ColorSequence,
}

local Shared_RoadGradient = {}

local HOLE_WIDTH_SCALE = 0.005

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

function Shared_RoadGradient.GetHoleWidthScale(): number
	return HOLE_WIDTH_SCALE
end

function Shared_RoadGradient.GetRoadTotalLength(): number
	local totalSize = 0
	for _, rarityName in getSortedRarities() do
		local floorSize = Shared_GameProcess.GetFloorSize(rarityName)
		if floorSize then
			totalSize += floorSize
		end
	end
	return totalSize
end

function Shared_RoadGradient.GetRoadBounds(enterPart: BasePart): (number, number)
	local totalLength = Shared_RoadGradient.GetRoadTotalLength()
	local roadNearZ = enterPart.Position.Z + enterPart.Size.Z / 2
	local roadFarZ = roadNearZ - totalLength
	return roadNearZ, roadFarZ
end

function Shared_RoadGradient.IsOnRoad(worldZ: number, roadNearZ: number, roadFarZ: number): boolean
	return worldZ <= roadNearZ and worldZ >= roadFarZ
end

function Shared_RoadGradient.GetRoadFrontZ(enterPart: BasePart): number
	return enterPart.Position.Z + enterPart.Size.Z / 2
end

-- Home/plot is past the road front (+Z). Holes/road extend toward -Z from the front.
function Shared_RoadGradient.HasPassedRoadFront(worldZ: number, roadFrontZ: number, deliverLead: number?): boolean
	local lead = deliverLead or 0
	return worldZ > roadFrontZ - lead
end

function Shared_RoadGradient.GetRoadAlphaFromWorldZ(worldZ: number, roadNearZ: number, roadFarZ: number): number
	local totalLength = roadNearZ - roadFarZ
	if totalLength <= 0 then
		return 0
	end
	return math.clamp((roadNearZ - worldZ) / totalLength, 0, 1)
end

function Shared_RoadGradient.GetBarScaleFromRoadAlpha(roadAlpha: number): number
	local segments = Shared_RoadGradient.GetSegments()
	if #segments == 0 then
		return 0
	end

	roadAlpha = math.clamp(roadAlpha, 0, 1)

	local dividerWidth = HOLE_WIDTH_SCALE
	local dividerCount = math.max(0, #segments - 1)
	local colorScale = math.max(0, 1 - dividerCount * dividerWidth)

	local cursor = 0
	local roadCursor = 0

	for index, segment in segments do
		local segmentWidth = segment.WidthScale * colorScale
		local segRoadEnd = roadCursor + segment.WidthScale

		if roadAlpha <= segRoadEnd or index == #segments then
			local segmentAlpha = 0
			if segment.WidthScale > 0 then
				segmentAlpha = (roadAlpha - roadCursor) / segment.WidthScale
			end
			segmentAlpha = math.clamp(segmentAlpha, 0, 1)
			return cursor + segmentAlpha * segmentWidth
		end

		cursor += segmentWidth
		roadCursor = segRoadEnd

		if index < #segments then
			cursor += dividerWidth
		end
	end

	return 1
end

function Shared_RoadGradient.GetSegments(): { RoadSegment }
	local segments: { RoadSegment } = {}
	local totalSize = 0

	for _, rarityName in getSortedRarities() do
		local floorSize = Shared_GameProcess.GetFloorSize(rarityName)
		if floorSize then
			totalSize += floorSize
		end
	end

	if totalSize <= 0 then
		return segments
	end

	for _, rarityName in getSortedRarities() do
		local floorSize = Shared_GameProcess.GetFloorSize(rarityName)
		if not floorSize then
			continue
		end

		local rarityData = Shared_Rarities.Data[rarityName]
		local colorGradient = rarityData and rarityData.ColorGradient
		if not colorGradient then
			local fallbackColor = rarityData and rarityData.Color or Color3.new(1, 1, 1)
			colorGradient = ColorSequence.new(fallbackColor)
		end

		table.insert(segments, {
			Rarity = rarityName,
			WidthScale = floorSize / totalSize,
			ColorGradient = colorGradient,
		})
	end

	return segments
end

return Shared_RoadGradient
