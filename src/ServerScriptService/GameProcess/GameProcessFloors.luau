local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared_GameProcess = require(ReplicatedStorage.Modules.Shared_GameProcess)
local Shared_Rarities = require(ReplicatedStorage.Modules.Utilities.Shared_Rarities)

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
	wall.Parent = parent
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
	holeFloor.Color = floor.Color
	holeFloor:SetAttribute("Rarity", rarityName)
	holeFloor:SetAttribute("IsHoleFloor", true)
	holeFloor:SetAttribute("HoleSide", side)
	holeFloor.Parent = parent
	return holeFloor
end

local function placeWallsForHoleFloor(
	holeFloor: BasePart,
	wallTemplate: BasePart,
	rarityName: string,
	holeSide: string,
	parent: Instance
)
	local originWallSize = wallTemplate.Size
	local halfHoleX = holeFloor.Size.X / 2
	local halfHoleZ = holeFloor.Size.Z / 2
	local wallY = getWallY(holeFloor, originWallSize.Y)
	local wallPrefix = `{rarityName}{holeSide}Hole`

	if holeSide == "Left" then
		placeWall(
			wallTemplate,
			`{wallPrefix}OuterWall`,
			Vector3.new(holeFloor.Position.X - halfHoleX, wallY, holeFloor.Position.Z),
			Vector3.new(originWallSize.X, originWallSize.Y, holeFloor.Size.Z),
			rarityName,
			"Outer",
			parent
		)
	elseif holeSide == "Right" then
		placeWall(
			wallTemplate,
			`{wallPrefix}OuterWall`,
			Vector3.new(holeFloor.Position.X + halfHoleX, wallY, holeFloor.Position.Z),
			Vector3.new(originWallSize.X, originWallSize.Y, holeFloor.Size.Z),
			rarityName,
			"Outer",
			parent
		)
	end

	placeWall(
		wallTemplate,
		`{wallPrefix}BackWall`,
		Vector3.new(holeFloor.Position.X, wallY, holeFloor.Position.Z - halfHoleZ),
		Vector3.new(holeFloor.Size.X, originWallSize.Y, originWallSize.X),
		rarityName,
		"Back",
		parent
	)
	placeWall(
		wallTemplate,
		`{wallPrefix}FrontWall`,
		Vector3.new(holeFloor.Position.X, wallY, holeFloor.Position.Z + halfHoleZ),
		Vector3.new(holeFloor.Size.X, originWallSize.Y, originWallSize.X),
		rarityName,
		"Front",
		parent
	)
end

local function placeHoleFloorsForFloor(
	floor: BasePart,
	floorTemplate: BasePart,
	wallTemplate: BasePart,
	rarityName: string,
	parent: Instance
)
	local holeWidthX = Shared_GameProcess.HoleFloorSize
	local holeDepthZ = Shared_GameProcess.WallFrontOpening
	local halfHoleWidthX = holeWidthX / 2
	local halfHoleDepthZ = holeDepthZ / 2
	local halfFloorX = floor.Size.X / 2
	local floorBackZ = floor.Position.Z - floor.Size.Z / 2
	local holeCenterZ = floorBackZ + halfHoleDepthZ

	local holeFloorSize = Vector3.new(holeWidthX, floor.Size.Y, holeDepthZ)

	local leftHoleFloor = placeHoleFloor(
		floor,
		floorTemplate,
		rarityName,
		"Left",
		floor.Position.X - halfFloorX - halfHoleWidthX,
		holeCenterZ,
		holeFloorSize,
		parent
	)
	placeWallsForHoleFloor(leftHoleFloor, wallTemplate, rarityName, "Left", parent)

	local rightHoleFloor = placeHoleFloor(
		floor,
		floorTemplate,
		rarityName,
		"Right",
		floor.Position.X + halfFloorX + halfHoleWidthX,
		holeCenterZ,
		holeFloorSize,
		parent
	)
	placeWallsForHoleFloor(rightHoleFloor, wallTemplate, rarityName, "Right", parent)
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
		placeHoleFloorsForFloor(floor, floorTemplate, wallTemplate, rarityName, floorsFolder)

		cursorZ -= floorSize
	end
end

return GameProcessFloors
