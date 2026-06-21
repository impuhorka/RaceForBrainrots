local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SharedModules = require(ReplicatedStorage.Modules.Loader)
local ClientLoader = require(script.Parent.Parent.Loader)
local Shared_GameProcess = SharedModules.require("Shared_GameProcess")

local Client_VIPWalls = {}

local VIP_CONFIG_KEY = "VIP"
local PROMPT_COOLDOWN = 4

local localPlayer = Players.LocalPlayer
local hookedWalls: { [BasePart]: boolean } = {}
local wallTouchConnections: { [BasePart]: RBXScriptConnection } = {}
local lastPromptAt = 0

local function ownsVIP(): boolean
	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	return Client_Marketplace.PlayerOwnsGamepass(VIP_CONFIG_KEY)
end

local function isUnwantedVipSideRoadWall(instance: Instance): boolean
	return Shared_GameProcess.IsUnwantedVipSideRoadWall(instance)
end

local function hideUnwantedVipSideRoadWall(wall: BasePart)
	wall.CanCollide = false
	wall.LocalTransparencyModifier = 1
end

local function isVIPOuterMinimapWall(instance: Instance): boolean
	if not instance:IsA("BasePart") then
		return false
	end

	return instance:GetAttribute("IsVIPOuterWall") == true or instance:GetAttribute("Side") == "Outer"
end

-- Only VIPRoadWall + HoleVIPWall are disabled for VIP owners. Outer walls stay solid/visible.
local function isVipPurchaseBarrierWall(instance: Instance): boolean
	if not instance:IsA("BasePart") then
		return false
	end

	if instance:GetAttribute("IsVIPRoadWall") == true then
		return true
	end

	if instance:GetAttribute("IsVIPWall") == true and instance:GetAttribute("Side") == "VIP" then
		return true
	end

	return string.sub(instance.Name, -12) == "VIPRoadWall" or string.sub(instance.Name, -10) == "HoleVIPWall"
end

local function clearVIPWallDecorations(wall: BasePart)
	local root = wall.Parent
	if not root then
		return
	end

	for _, child in root:GetChildren() do
		if not child:IsA("Model") then
			continue
		end

		if child:GetAttribute("HostWallName") == wall.Name then
			child:Destroy()
		end
	end
end

local function isLocalCharacterPart(hit: BasePart): boolean
	local character = localPlayer.Character
	return character ~= nil and hit:IsDescendantOf(character)
end

local function tryPromptVIPPurchase()
	if ownsVIP() then
		return
	end

	local now = os.clock()
	if now - lastPromptAt < PROMPT_COOLDOWN then
		return
	end

	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	if Client_Marketplace.PromptGamePassPurchase(VIP_CONFIG_KEY) then
		lastPromptAt = now
	end
end

local function applyVIPWallSurfaceGuis(wall: BasePart, visible: boolean)
	for _, descendant in wall:GetDescendants() do
		if not descendant:IsA("SurfaceGui") then
			continue
		end

		if descendant:GetAttribute("OriginalSurfaceGuiEnabled") == nil then
			descendant:SetAttribute("OriginalSurfaceGuiEnabled", descendant.Enabled)
		end

		if visible then
			local enabled = descendant:GetAttribute("OriginalSurfaceGuiEnabled")
			if enabled ~= nil then
				descendant.Enabled = enabled
			end
		else
			descendant.Enabled = false
		end
	end
end

local function applyVIPBarrierWallState(wall: BasePart)
	local passThrough = ownsVIP()

	if passThrough then
		wall.CanCollide = false
		wall.LocalTransparencyModifier = 1
		applyVIPWallSurfaceGuis(wall, false)
		clearVIPWallDecorations(wall)
	else
		wall.CanCollide = true
		wall.LocalTransparencyModifier = 0
		applyVIPWallSurfaceGuis(wall, true)
	end
end

local function refreshVIPWalls()
	for wall in hookedWalls do
		if wall.Parent then
			applyVIPBarrierWallState(wall)
		end
	end
end

local function unhookVIPWall(wall: BasePart)
	hookedWalls[wall] = nil

	local touchConnection = wallTouchConnections[wall]
	if touchConnection then
		touchConnection:Disconnect()
		wallTouchConnections[wall] = nil
	end
end

local function hookVIPBarrierWall(wall: BasePart)
	if hookedWalls[wall] then
		applyVIPBarrierWallState(wall)
		return
	end

	hookedWalls[wall] = true
	applyVIPBarrierWallState(wall)

	wallTouchConnections[wall] = wall.Touched:Connect(function(hit)
		if not hit:IsA("BasePart") or not isLocalCharacterPart(hit) then
			return
		end

		tryPromptVIPPurchase()
	end)

	wall.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("SurfaceGui") then
			applyVIPBarrierWallState(wall)
		end
	end)

	wall.Destroying:Connect(function()
		unhookVIPWall(wall)
	end)
end

local function resetOuterMinimapWall(wall: BasePart)
	wall.LocalTransparencyModifier = 0
	wall.CanCollide = true
	if hookedWalls[wall] then
		unhookVIPWall(wall)
	end
end

local function scanFloorsRoot(root: Instance)
	for _, descendant in root:GetDescendants() do
		if isVIPOuterMinimapWall(descendant) then
			resetOuterMinimapWall(descendant)
		elseif isVipPurchaseBarrierWall(descendant) then
			hookVIPBarrierWall(descendant)
		elseif isUnwantedVipSideRoadWall(descendant) then
			hideUnwantedVipSideRoadWall(descendant)
		end
	end
end

local function bindFloorsFolder(floorsFolder: Instance)
	scanFloorsRoot(floorsFolder)
	floorsFolder.DescendantAdded:Connect(function(descendant)
		if isVIPOuterMinimapWall(descendant) then
			resetOuterMinimapWall(descendant)
		elseif isVipPurchaseBarrierWall(descendant) then
			hookVIPBarrierWall(descendant)
		elseif isUnwantedVipSideRoadWall(descendant) then
			hideUnwantedVipSideRoadWall(descendant)
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

	task.spawn(function()
		Client_Marketplace.WaitUntilReady()
		refreshVIPWalls()
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
