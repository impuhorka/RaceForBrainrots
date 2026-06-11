local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Client_AntiFling = {}

local HARD_FALL_SPEED = 55
local GROUND_RAY_DISTANCE = 10
local GROUND_RAY_START_OFFSET = 1.5
local MAX_LAND_VERTICAL_SPEED = 28
local UPRIGHT_LOCK_DURATION = 0.2

local localPlayer = Players.LocalPlayer
local characterConnections: { RBXScriptConnection } = {}
local uprightLockUntil = 0

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function disconnectCharacterConnections()
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	table.clear(characterConnections)
end

local function getCharacterParts(character: Model): (Humanoid?, BasePart?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = if humanoid and humanoid.RootPart
		then humanoid.RootPart
		else character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return humanoid, root
end

local function disableFlingStates(humanoid: Humanoid)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
end

local function dampenHardLanding(root: BasePart, verticalSpeed: number)
	local velocity = root.AssemblyLinearVelocity
	local clampedY = math.max(verticalSpeed, -MAX_LAND_VERTICAL_SPEED)
	if velocity.Y < clampedY then
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, clampedY, velocity.Z)
	end
	root.AssemblyAngularVelocity = Vector3.zero
	uprightLockUntil = os.clock() + UPRIGHT_LOCK_DURATION
end

local function getGroundDistance(root: BasePart, character: Model): number?
	raycastParams.FilterDescendantsInstances = { character }
	local origin = root.Position + Vector3.new(0, GROUND_RAY_START_OFFSET, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -GROUND_RAY_DISTANCE, 0), raycastParams)
	if not result then
		return nil
	end
	return result.Distance - GROUND_RAY_START_OFFSET
end

local function maintainUprightOrientation(root: BasePart)
	if os.clock() > uprightLockUntil then
		return
	end

	local position = root.Position
	local lookVector = root.CFrame.LookVector
	local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)
	if flatLook.Magnitude < 0.05 then
		flatLook = Vector3.new(0, 0, -1)
	else
		flatLook = flatLook.Unit
	end

	root.CFrame = CFrame.lookAt(position, position + flatLook)
	root.AssemblyAngularVelocity = Vector3.zero
end

local function onCharacterStateChanged(
	humanoid: Humanoid,
	root: BasePart,
	_oldState: Enum.HumanoidStateType,
	newState: Enum.HumanoidStateType
)
	if
		newState ~= Enum.HumanoidStateType.Landed
		and newState ~= Enum.HumanoidStateType.Running
		and newState ~= Enum.HumanoidStateType.RunningNoPhysics
	then
		return
	end

	local verticalSpeed = root.AssemblyLinearVelocity.Y
	if verticalSpeed <= -HARD_FALL_SPEED then
		dampenHardLanding(root, verticalSpeed)
	end
end

local function onHeartbeat(humanoid: Humanoid, root: BasePart)
	maintainUprightOrientation(root)

	if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
		return
	end

	local verticalSpeed = root.AssemblyLinearVelocity.Y
	if verticalSpeed > -HARD_FALL_SPEED then
		return
	end

	local character = humanoid.Parent
	if not character or not character:IsA("Model") then
		return
	end

	local groundDistance = getGroundDistance(root, character)
	if groundDistance ~= nil and groundDistance <= 2.5 then
		dampenHardLanding(root, verticalSpeed)
	end
end

local function bindCharacter(character: Model)
	disconnectCharacterConnections()

	local humanoid, root = getCharacterParts(character)
	if not humanoid or not root then
		return
	end

	disableFlingStates(humanoid)

	table.insert(
		characterConnections,
		humanoid.StateChanged:Connect(function(oldState, newState)
			onCharacterStateChanged(humanoid, root, oldState, newState)
		end)
	)

	table.insert(
		characterConnections,
		RunService.Heartbeat:Connect(function()
			if not character.Parent or humanoid.Parent ~= character or root.Parent ~= character then
				return
			end
			onHeartbeat(humanoid, root)
		end)
	)
end

function Client_AntiFling.Init()
	local function onCharacterAdded(character: Model)
		task.defer(bindCharacter, character)
	end

	localPlayer.CharacterAdded:Connect(onCharacterAdded)
	if localPlayer.Character then
		onCharacterAdded(localPlayer.Character)
	end
end

return Client_AntiFling
