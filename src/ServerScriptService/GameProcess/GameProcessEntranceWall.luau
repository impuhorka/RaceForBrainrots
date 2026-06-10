local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local GameProcessEntranceWall = {}

local STAGING_FOLDER_NAME = "GameProcessStaging"
local WALL_NAME = "EntranceWall"

local originTransparency: number?

local function getOriginTransparencyFromAsset(): number?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local gameProcessAssets = assets and assets:FindFirstChild("GameProcess")
	local assetWall = gameProcessAssets and gameProcessAssets:FindFirstChild(WALL_NAME)
	if assetWall and assetWall:IsA("BasePart") then
		return assetWall.Transparency
	end
	return nil
end

local function ensureOriginTransparency(wall: BasePart)
	if originTransparency == nil then
		originTransparency = getOriginTransparencyFromAsset() or wall.Transparency
	end
end

local function getStagingFolder(): Folder
	local staging = ServerStorage:FindFirstChild(STAGING_FOLDER_NAME)
	if not staging then
		staging = Instance.new("Folder")
		staging.Name = STAGING_FOLDER_NAME
		staging.Parent = ServerStorage
	end
	return staging
end

local function getMapFolder(): Folder
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

	return mapFolder
end

local function getEntranceWallTemplate(): BasePart?
	local staging = getStagingFolder()
	local stagedWall = staging:FindFirstChild(WALL_NAME)
	if stagedWall and stagedWall:IsA("BasePart") then
		ensureOriginTransparency(stagedWall)
		return stagedWall
	end

	local mapFolder = getMapFolder()
	local mapWall = mapFolder:FindFirstChild(WALL_NAME)
	if mapWall and mapWall:IsA("BasePart") then
		ensureOriginTransparency(mapWall)
		return mapWall
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local gameProcessAssets = assets and assets:FindFirstChild("GameProcess")
	local assetWall = gameProcessAssets and gameProcessAssets:FindFirstChild(WALL_NAME)
	if assetWall and assetWall:IsA("BasePart") then
		local clone = assetWall:Clone()
		clone.Name = WALL_NAME
		clone.Parent = staging
		ensureOriginTransparency(clone)
		return clone
	end

	warn("Missing EntranceWall template in Workspace.Game.Map, ServerStorage, or ReplicatedStorage.Assets.GameProcess")
	return nil
end

function GameProcessEntranceWall.EnsureGameFolder(): Folder
	local gameFolder = Workspace:FindFirstChild("Game")
	if not gameFolder then
		gameFolder = Instance.new("Folder")
		gameFolder.Name = "Game"
		gameFolder.Parent = Workspace
	end
	return gameFolder
end

function GameProcessEntranceWall.Show()
	local wall = getEntranceWallTemplate()
	if not wall then
		return
	end

	ensureOriginTransparency(wall)
	wall.Transparency = originTransparency :: number
	wall.CanCollide = true
	wall.Parent = getMapFolder()
end

function GameProcessEntranceWall.Hide()
	local mapFolder = getMapFolder()
	local wall = mapFolder:FindFirstChild(WALL_NAME)
	if wall and wall:IsA("BasePart") then
		wall.Parent = getStagingFolder()
	end
end

function GameProcessEntranceWall.Init()
	getMapFolder()
	local wall = getEntranceWallTemplate()
	if wall and wall.Parent ~= getStagingFolder() then
		wall.Parent = getStagingFolder()
	end
end

return GameProcessEntranceWall
