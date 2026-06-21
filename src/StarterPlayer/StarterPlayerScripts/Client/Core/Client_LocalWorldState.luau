local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SharedModules = require(ReplicatedStorage.Modules.Loader)
local Shared_RoadGradient = SharedModules.require("Shared_RoadGradient")

local Client_LocalWorldState = {}

local EFFECTS_MAX_DISTANCE = 150

local localPlayer = Players.LocalPlayer
local roadNearZ = 0
local roadFarZ = 0
local roadBoundsReady = false
local isOnRoad = false
local roadStateCallbacks: { (onRoad: boolean) -> () } = {}

local function tryInitRoadBounds(): boolean
	if roadBoundsReady then
		return true
	end

	local zones = Workspace:FindFirstChild("Zones")
	local enterPart = zones and zones:FindFirstChild("EnterPart")
	if not enterPart or not enterPart:IsA("BasePart") then
		return false
	end

	if Shared_RoadGradient.GetRoadTotalLength() <= 0 then
		return false
	end

	roadNearZ, roadFarZ = Shared_RoadGradient.GetRoadBounds(enterPart)
	roadBoundsReady = true
	return true
end

local function getPlayerRoot(): BasePart?
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function computeIsPlayerOnRoad(): boolean
	if not tryInitRoadBounds() then
		return false
	end

	local root = getPlayerRoot()
	if not root then
		return false
	end

	return Shared_RoadGradient.IsOnRoad(root.Position.Z, roadNearZ, roadFarZ)
end

local function setRoadState(onRoad: boolean)
	if onRoad == isOnRoad then
		return
	end

	isOnRoad = onRoad
	for _, callback in roadStateCallbacks do
		callback(onRoad)
	end
end

local function updateRoadState()
	setRoadState(computeIsPlayerOnRoad())
end

function Client_LocalWorldState.GetEffectsMaxDistance(): number
	return EFFECTS_MAX_DISTANCE
end

function Client_LocalWorldState.IsWithinEffectsRange(worldPosition: Vector3): boolean
	local root = getPlayerRoot()
	if not root then
		return false
	end

	return (worldPosition - root.Position).Magnitude <= EFFECTS_MAX_DISTANCE
end

function Client_LocalWorldState.IsPlayerOnRoad(): boolean
	return isOnRoad
end

function Client_LocalWorldState.OnRoadStateChanged(callback: (onRoad: boolean) -> ())
	table.insert(roadStateCallbacks, callback)
	callback(isOnRoad)
end

function Client_LocalWorldState.Init()
	updateRoadState()
	RunService.Heartbeat:Connect(updateRoadState)
end

return Client_LocalWorldState
