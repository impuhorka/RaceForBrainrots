local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Server_Data = require(script.Parent.Server_Data)
local Shared_AntiCheat = SharedModules.require("Shared_AntiCheat")

local Server_AntiCheat = {}

type PlayerWatch = {
	lastPosition: Vector3?,
	lastValidPosition: Vector3?,
	lastCheckAt: number,
	teleportGraceUntil: number,
	violations: number,
	violationWindowStart: number,
	airborneSince: number?,
	insideSolidSince: number?,
}

local watches: { [Player]: PlayerWatch } = {}
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude
overlapParams.RespectCanCollide = true

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.RespectCanCollide = true

local function isAdmin(player: Player): boolean
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		if ok and type(rank) == "number" then
			return rank >= 254
		end
		return false
	end
	return player.UserId == game.CreatorId
end

local function getWatch(player: Player): PlayerWatch
	local watch = watches[player]
	if not watch then
		watch = {
			lastPosition = nil,
			lastValidPosition = nil,
			lastCheckAt = os.clock(),
			teleportGraceUntil = 0,
			violations = 0,
			violationWindowStart = os.clock(),
			airborneSince = nil,
			insideSolidSince = nil,
		}
		watches[player] = watch
	end
	return watch
end

function Server_AntiCheat.GrantTeleportGrace(player: Player, duration: number?)
	local watch = getWatch(player)
	watch.teleportGraceUntil = math.max(
		watch.teleportGraceUntil,
		os.clock() + (duration or Shared_AntiCheat.TeleportGraceDuration)
	)

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		watch.lastPosition = root.Position
		watch.lastValidPosition = root.Position
		watch.lastCheckAt = os.clock()
	end
end

local function decayViolations(watch: PlayerWatch)
	local now = os.clock()
	if now - watch.violationWindowStart > Shared_AntiCheat.ViolationWindow then
		watch.violations = 0
		watch.violationWindowStart = now
	end
end

local function registerViolation(player: Player, watch: PlayerWatch, _reason: string)
	decayViolations(watch)
	watch.violations += 1

	if watch.violations >= Shared_AntiCheat.KickThreshold then
		player:Kick(Shared_AntiCheat.KickMessage)
	end
end

local function getCharacterParts(character: Model): (Humanoid?, BasePart?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = if humanoid and humanoid.RootPart
		then humanoid.RootPart
		else character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return humanoid, root
end

local function hardenHumanoid(humanoid: Humanoid)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
end

local function enforceWalkSpeed(player: Player, humanoid: Humanoid)
	local expected = Server_Data:GetExpectedWalkSpeed(player)
	if math.abs(humanoid.WalkSpeed - expected) > Shared_AntiCheat.WalkSpeedTolerance then
		humanoid.WalkSpeed = expected
		return false
	end
	return true
end

local function getGroundDistance(character: Model, root: BasePart): number?
	raycastParams.FilterDescendantsInstances = { character }
	local origin = root.Position + Vector3.new(0, 2, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -28, 0), raycastParams)
	if not result then
		return nil
	end
	return result.Distance - 2
end

local function isInsideSolid(character: Model, root: BasePart): boolean
	overlapParams.FilterDescendantsInstances = { character }
	local touching = workspace:GetPartBoundsInBox(root.CFrame, Vector3.new(2.2, 4.8, 2.2), overlapParams)
	for _, part in touching do
		if not part:IsA("BasePart") or not part.CanCollide or part.Transparency >= 1 then
			continue
		end
		if part:IsDescendantOf(character) then
			continue
		end

		local localPos = part.CFrame:PointToObjectSpace(root.Position)
		local half = part.Size * 0.5
		if math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z then
			return true
		end
	end
	return false
end

local function snapToLastValid(character: Model, root: BasePart, watch: PlayerWatch)
	local target = watch.lastValidPosition or watch.lastPosition
	if not target then
		return
	end

	character:PivotTo(CFrame.new(target + Vector3.new(0, 3, 0)))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	watch.lastPosition = target
end

local function monitorPlayer(player: Player, character: Model, humanoid: Humanoid, root: BasePart)
	local watch = getWatch(player)
	watch.lastCheckAt = os.clock()
	watch.lastPosition = root.Position
	watch.lastValidPosition = root.Position

	hardenHumanoid(humanoid)
	enforceWalkSpeed(player, humanoid)

	humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if not enforceWalkSpeed(player, humanoid) then
			registerViolation(player, watch, "WalkSpeed")
		end
	end)

	humanoid.StateChanged:Connect(function(_oldState, newState)
		if newState == Enum.HumanoidStateType.Flying then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			registerViolation(player, watch, "Flying")
		end
	end)
end

local function tickPlayer(player: Player)
	if isAdmin(player) then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local humanoid, root = getCharacterParts(character)
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local watch = getWatch(player)
	local now = os.clock()
	local delta = math.max(now - watch.lastCheckAt, Shared_AntiCheat.CheckInterval)
	watch.lastCheckAt = now

	enforceWalkSpeed(player, humanoid)

	local position = root.Position
	local velocity = root.AssemblyLinearVelocity
	local expectedSpeed = Server_Data:GetExpectedWalkSpeed(player)
	local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local maxHorizontalSpeed = expectedSpeed * Shared_AntiCheat.HorizontalSpeedMultiplier
		+ Shared_AntiCheat.HorizontalSpeedBuffer

	local groundDistance = getGroundDistance(character, root)
	local onGround = groundDistance ~= nil and groundDistance <= 3.5
	if onGround then
		watch.airborneSince = nil
	else
		watch.airborneSince = watch.airborneSince or now
	end

	if
		not onGround
		and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping
		and velocity.Y > 12
		and (now - (watch.airborneSince or now)) > Shared_AntiCheat.MaxAirTimeWithoutGround
	then
		registerViolation(player, watch, "Airborne")
		snapToLastValid(character, root, watch)
		return
	end

	if math.abs(velocity.Y) > Shared_AntiCheat.MaxVerticalSpeed then
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.clamp(velocity.Y, -80, 80), velocity.Z)
		registerViolation(player, watch, "VerticalSpeed")
	end

	if onGround and horizontalSpeed > maxHorizontalSpeed then
		root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
		registerViolation(player, watch, "HorizontalSpeed")
	end

	if isInsideSolid(character, root) then
		watch.insideSolidSince = watch.insideSolidSince or now
		if now - watch.insideSolidSince >= Shared_AntiCheat.InsideSolidStrikeDelay then
			registerViolation(player, watch, "Noclip")
			snapToLastValid(character, root, watch)
			watch.insideSolidSince = nil
			return
		end
	else
		watch.insideSolidSince = nil
	end

	if watch.lastPosition and now < watch.teleportGraceUntil then
		watch.lastPosition = position
		watch.lastValidPosition = position
		return
	end

	if watch.lastPosition then
		local moved = (position - watch.lastPosition).Magnitude
		local maxMove = expectedSpeed * delta * Shared_AntiCheat.TeleportSpeedMultiplier
			+ Shared_AntiCheat.TeleportDistanceBuffer
		if moved > maxMove then
			registerViolation(player, watch, "Teleport")
			snapToLastValid(character, root, watch)
			return
		end
	end

	watch.lastPosition = position
	watch.lastValidPosition = position
end

local function bindPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		Server_AntiCheat.GrantTeleportGrace(player, Shared_AntiCheat.SpawnGraceDuration)
		task.defer(function()
			local humanoid, root = getCharacterParts(character)
			if humanoid and root then
				monitorPlayer(player, character, humanoid, root)
			end
		end)
	end)

	if player.Character then
		Server_AntiCheat.GrantTeleportGrace(player, Shared_AntiCheat.SpawnGraceDuration)
	end
end

function Server_AntiCheat.Init()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < Shared_AntiCheat.CheckInterval then
			return
		end
		elapsed = 0

		for _, player in Players:GetPlayers() do
			tickPlayer(player)
		end
	end)

	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(player)
		watches[player] = nil
	end)
end

return Server_AntiCheat
