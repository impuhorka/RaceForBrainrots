local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local ClientLoader = require(script.Parent.Parent.Loader)
local Shared_GameProcess = SharedModules.require("Shared_GameProcess")
local Client_WorldDropAnimation = {}

local ANIM_DURATION_SCALE = 1.5
local WINDUP_DURATION = 0.07 * ANIM_DURATION_SCALE
local SPIN_START_RADIANS_PER_SECOND = math.rad(120)
local SPIN_STOP_DURATION = 2.5

export type DropAnimationConfig = {
	launchOrigin: Vector3,
	landingPosition: Vector3,
	lookAtUserId: number?,
	sizeScale: number?,
	floatAmplitude: number?,
}

export type DropAnimationResult = {
	spinYaw: number,
	spinStartTime: number,
	spinStartSpeed: number,
	spinStopDuration: number,
	endRotation: CFrame,
}

type SpinState = {
	yaw: number,
	startTime: number,
	lastTick: number,
	signedSpinSpeed: number,
}

local playGenerations: { [Model]: number } = {}

local function ensurePrimaryPart(model: Model): BasePart?
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
	end
	return model.PrimaryPart
end

local function easeOutCubic(t: number): number
	local u = 1 - t
	return 1 - u * u * u
end

local function easeInCubic(t: number): number
	return t * t * t
end

local function easeOutQuart(t: number): number
	local u = 1 - t
	return 1 - u * u * u * u
end

function Client_WorldDropAnimation.GetSpinStopDuration(): number
	return SPIN_STOP_DURATION
end

local function isPlayActive(model: Model, generation: number): boolean
	return model.Parent ~= nil and playGenerations[model] == generation
end

function Client_WorldDropAnimation.stop(model: Model)
	playGenerations[model] = (playGenerations[model] or 0) + 1
end

function Client_WorldDropAnimation.getLocalPlayerLaunchOrigin(): Vector3?
	local player = Players.LocalPlayer
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position + root.CFrame.UpVector * 2 + root.CFrame.LookVector
	end
	return nil
end

local function getSpinSpeedMultiplier(elapsed: number): number
	local stopT = math.min(elapsed / SPIN_STOP_DURATION, 1)
	return 1 - easeOutQuart(stopT)
end

local function createSpinState(startTime: number): SpinState
	local spinDirection = if math.random() < 0.5 then -1 else 1
	return {
		yaw = 0,
		startTime = startTime,
		lastTick = startTime,
		signedSpinSpeed = SPIN_START_RADIANS_PER_SECOND * spinDirection,
	}
end

local function stepSpinState(spinState: SpinState)
	local now = os.clock()
	local dt = math.max(now - spinState.lastTick, 1 / 240)
	spinState.lastTick = now

	local elapsed = now - spinState.startTime
	local speedMul = getSpinSpeedMultiplier(elapsed)
	spinState.yaw += spinState.signedSpinSpeed * speedMul * dt
end

local function getSpinRotation(endRotation: CFrame, spinState: SpinState): CFrame
	local flatBase = Shared_GameProcess.GetFlatYawRotation(endRotation)
	return CFrame.Angles(0, spinState.yaw, 0) * flatBase
end

local function getLookAtRotation(atPos: Vector3, userId: number?): CFrame
	if userId then
		local dropper = Players:GetPlayerByUserId(userId)
		local character = dropper and dropper.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local lookTarget = Vector3.new(root.Position.X, atPos.Y, root.Position.Z)
			if (lookTarget - atPos).Magnitude > 0.01 then
				local cf = CFrame.lookAt(atPos, lookTarget)
				return Shared_GameProcess.GetFlatYawRotation(cf)
			end
		end
	end
	return CFrame.new()
end

local function prepareModel(model: Model)
	for _, inst in model:GetDescendants() do
		if inst:IsA("WeldConstraint") then
			inst:Destroy()
		elseif inst:IsA("BasePart") then
			inst.Massless = true
			inst.CanCollide = false
			inst.Anchored = true
		end
	end
end

local function getHorizontalDistance(a: Vector3, b: Vector3): number
	local delta = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	return delta.Magnitude
end

local function quadraticBezier(p0: Vector3, p1: Vector3, p2: Vector3, t: number): Vector3
	local u = 1 - t
	return u * u * p0 + 2 * u * t * p1 + t * t * p2
end

local function createThrowTrail(primaryPart: BasePart)
	if not ClientLoader.require("Client_VisualSettings").AreEffectsEnabled() then
		return nil, nil
	end

	local trail = Instance.new("Trail")
	local a0 = Instance.new("Attachment")
	a0.Name = "DropTrailA0"
	a0.Position = Vector3.new(0, 0, 0.6)
	a0.Parent = primaryPart
	local a1 = Instance.new("Attachment")
	a1.Name = "DropTrailA1"
	a1.Position = Vector3.new(0, 0, -0.6)
	a1.Parent = primaryPart
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 245, 200))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.22
	trail.MinLength = 0
	trail.LightEmission = 0.4
	trail.Parent = primaryPart
	return trail, { a0, a1 }
end

local function playWindup(
	model: Model,
	generation: number,
	launchOrigin: Vector3,
	landingPosition: Vector3,
	endRotation: CFrame,
	spinState: SpinState
): boolean
	local flatDelta = Vector3.new(landingPosition.X - launchOrigin.X, 0, landingPosition.Z - launchOrigin.Z)
	local backDir = if flatDelta.Magnitude > 0.05 then -flatDelta.Unit else -Vector3.zAxis
	local windupTarget = launchOrigin + backDir * 0.55 + Vector3.new(0, 0.35, 0)
	local windupStart = os.clock()

	stepSpinState(spinState)
	model:PivotTo(CFrame.new(launchOrigin) * getSpinRotation(endRotation, spinState))

	while isPlayActive(model, generation) do
		local t = math.min((os.clock() - windupStart) / WINDUP_DURATION, 1)
		local eased = easeInCubic(t)
		local pos = launchOrigin:Lerp(windupTarget, eased)
		local tilt = CFrame.Angles(math.rad(-3 * (1 - t)), 0, 0)
		stepSpinState(spinState)
		model:PivotTo(CFrame.new(pos) * getSpinRotation(endRotation, spinState) * tilt)
		if t >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end

	return isPlayActive(model, generation)
end

local function playThrowArc(
	model: Model,
	generation: number,
	launchOrigin: Vector3,
	landingPosition: Vector3,
	endRotation: CFrame,
	sizeScale: number,
	spinState: SpinState
): boolean
	local primaryPart = ensurePrimaryPart(model)
	if not primaryPart then
		return false
	end

	local horizontalDistance = getHorizontalDistance(launchOrigin, landingPosition)
	local throwDuration = math.clamp(
		(0.26 + horizontalDistance * 0.028 + sizeScale * 0.035) * ANIM_DURATION_SCALE,
		0.3 * ANIM_DURATION_SCALE,
		0.68 * ANIM_DURATION_SCALE
	)
	local arcHeight = math.clamp(
		horizontalDistance * (0.34 + sizeScale * 0.1) + 1.2 + sizeScale * 0.35,
		2.8,
		14
	)
	local flatDelta = Vector3.new(landingPosition.X - launchOrigin.X, 0, landingPosition.Z - launchOrigin.Z)
	local sideBias = Vector3.new(0, 0, 0)
	if flatDelta.Magnitude > 0.1 then
		sideBias = flatDelta:Cross(Vector3.yAxis).Unit * math.clamp(flatDelta.Magnitude * 0.08, 0.2, 1.4)
	end

	local midPoint = launchOrigin:Lerp(landingPosition, 0.5)
	local controlPoint = midPoint + Vector3.new(0, arcHeight, 0) + sideBias

	local flatDeltaUnit = if flatDelta.Magnitude > 0.05 then flatDelta.Unit else Vector3.zAxis
	local windupOrigin = launchOrigin + (-flatDeltaUnit * 0.55) + Vector3.new(0, 0.35, 0)

	local trail, trailAttachments = createThrowTrail(primaryPart)
	local throwStart = os.clock()

	while isPlayActive(model, generation) do
		local t = math.min((os.clock() - throwStart) / throwDuration, 1)
		local moveT = easeOutCubic(t)
		local pos = quadraticBezier(windupOrigin, controlPoint, landingPosition, moveT)
		stepSpinState(spinState)
		model:PivotTo(CFrame.new(pos) * getSpinRotation(endRotation, spinState))

		if t >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end

	if trail then
		trail:Destroy()
	end
	if trailAttachments then
		for _, attachment in trailAttachments do
			attachment:Destroy()
		end
	end

	if isPlayActive(model, generation) then
		stepSpinState(spinState)
		model:PivotTo(CFrame.new(landingPosition) * getSpinRotation(endRotation, spinState))
	end

	return isPlayActive(model, generation)
end

function Client_WorldDropAnimation.play(
	model: Model,
	config: DropAnimationConfig,
	onComplete: ((DropAnimationResult?) -> ())?
)
	if not model.Parent then
		if onComplete then
			onComplete(nil)
		end
		return
	end

	task.spawn(function()
		local generation = (playGenerations[model] or 0) + 1
		playGenerations[model] = generation

		local sizeScale = if type(config.sizeScale) == "number" and config.sizeScale > 0 then config.sizeScale else 1

		prepareModel(model)

		local endRotation = getLookAtRotation(config.landingPosition, config.lookAtUserId)
		local spinStartTime = os.clock()
		local spinState = createSpinState(spinStartTime)

		local ok = playWindup(model, generation, config.launchOrigin, config.landingPosition, endRotation, spinState)
		if ok and isPlayActive(model, generation) then
			ok = playThrowArc(
				model,
				generation,
				config.launchOrigin,
				config.landingPosition,
				endRotation,
				sizeScale,
				spinState
			)
		end

		if onComplete then
			if ok and isPlayActive(model, generation) then
				onComplete({
					spinYaw = spinState.yaw,
					spinStartTime = spinStartTime,
					spinStartSpeed = spinState.signedSpinSpeed,
					spinStopDuration = SPIN_STOP_DURATION,
					endRotation = endRotation,
				})
			else
				onComplete(nil)
			end
		end
	end)
end

return Client_WorldDropAnimation
