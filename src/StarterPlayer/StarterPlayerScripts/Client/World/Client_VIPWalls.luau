local Workspace = game:GetService("Workspace")

local ClientLoader = require(script.Parent.Parent.Loader)

local Client_VIPWalls = {}

local hookedWalls: { [BasePart]: boolean } = {}

local function ownsVIP(): boolean
	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	return Client_Marketplace.PlayerOwnsGamepass("VIP")
end

local function applyVIPWallState(wall: BasePart)
	local passThrough = ownsVIP()
	wall.CanCollide = not passThrough
	wall.LocalTransparencyModifier = if passThrough then 1 else 0
end

local function refreshVIPWalls()
	for wall in hookedWalls do
		if wall.Parent then
			applyVIPWallState(wall)
		end
	end
end

local function isVIPWall(instance: Instance): boolean
	return instance:IsA("BasePart") and instance:GetAttribute("IsVIPWall") == true
end

local function hookVIPWall(wall: BasePart)
	if hookedWalls[wall] then
		return
	end
	hookedWalls[wall] = true
	applyVIPWallState(wall)
end

local function scanFloorsRoot(root: Instance)
	for _, descendant in root:GetDescendants() do
		if isVIPWall(descendant) then
			hookVIPWall(descendant)
		end
	end
end

local function bindFloorsFolder(floorsFolder: Instance)
	scanFloorsRoot(floorsFolder)
	floorsFolder.DescendantAdded:Connect(function(descendant)
		if isVIPWall(descendant) then
			hookVIPWall(descendant)
		end
	end)
end

function Client_VIPWalls.Init()
	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	local Client_Data = ClientLoader.require("Client_Data")

	Client_Marketplace.OnGamepassOwnershipChanged(refreshVIPWalls)

	task.spawn(function()
		Client_Data.WaitUntilReady()
		Client_Data:ListenToChange("DataGamepasses", refreshVIPWalls)
	end)

	local gameFolder = Workspace:WaitForChild("Game", 30)
	if not gameFolder then
		return
	end

	local mapFolder = gameFolder:WaitForChild("Map", 30)
	if not mapFolder then
		return
	end

	local floorsFolder = mapFolder:WaitForChild("Floors", 30)
	if floorsFolder then
		bindFloorsFolder(floorsFolder)
	end
end

return Client_VIPWalls
