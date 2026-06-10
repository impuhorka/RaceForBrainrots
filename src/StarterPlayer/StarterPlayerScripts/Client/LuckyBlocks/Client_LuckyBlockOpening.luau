--[[
	Client_LuckyBlockOpening
	Plays the full lucky block opening animation when the server fires "LuckyBlockOpen".

	Expected RemoteEvent payload (table):
	  openId          string  - unique id for this open session
	  openingUserId   number  - UserId of the player who opened it
	  configName      string  - key into Shared_LuckyBlocks.Data
	  launchOrigin    Vector3 - where the block starts (above player hands)
	  landingPosition Vector3 - where the block lands
	  pickedConfigName string  - brainrot/luckyblock rewarded (for show after)
	  pickedItemType  string  - "Brainrot" | "LuckyBlock"
	  blockBaseWeight number? - origin lucky block weight (kg)
	  blockWeight     number? - lucky block weight when thrown (kg)
	  pickedBaseWeight number? - brainrot origin weight (kg)
	  pickedWeight    number? - brainrot weight from lucky block (kg)
]]

local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local RunService      = game:GetService("RunService")
local TweenService    = game:GetService("TweenService")
local ClientLoader = require(script.Parent.Parent.Loader)
local Shared_LuckyBlocks = SharedModules.require("Shared_LuckyBlocks")
local Shared_Weight = SharedModules.require("Shared_Weight")
local Shared_BrainrotAnimations = SharedModules.require("Shared_BrainrotAnimations")
local Shared_BrainrotBillboard = SharedModules.require("Shared_BrainrotBillboard")
local Shared_Sounds = SharedModules.require("Shared_Sounds")
local Client_Data = ClientLoader.require("Client_Data")
local Client_SoundPreload = ClientLoader.require("Client_SoundPreload")
local Client_LuckyBlockRevealState = ClientLoader.require("Client_LuckyBlockRevealState")
local Client_TadaEffect = ClientLoader.require("Client_TadaEffect")

local Client_LuckyBlockOpening = {}

-- ── Tweakable constants ───────────────────────────────────────────────────────
local THROW_DURATION        = 0.8
local HOVER_HEIGHT          = 0.25
local LANDING_PAUSE         = 0.15
local WIGGLE_ANGLE          = 20
local WIGGLE_COUNT          = 4
local EXPLOSION_SCALE       = 3
local EXPLOSION_DURATION    = 0.2
local REVEAL_POP_DURATION   = 0.25
local REVEAL_ROTATE_DURATION = 2
local REVEAL_SHRINK_DURATION = 0.4
local REVEAL_BOUNCE_HEIGHT  = 0.8
local REVEAL_Y_ROTATION_DEGREES = 360
-- Disabled invalid/unauthorized asset ids to avoid output spam.
local THROW_SOUND_ID: string? = nil
local WIGGLE_SOUND_ID: string? = "rbxassetid://131713031201598"
local EXPLOSION_SOUND_ID: string? = nil
local ROLLOUT_FIRST_TICK_SOUND_ID: string = "rbxassetid://88777016324165"
local ROLLOUT_SUCCESS_SOUND_ID: string = "rbxassetid://91024772071405"
local ROLLOUT_EXTRA_SOUND_ID: string = "rbxassetid://9048767983"
local ROLLOUT_SUCCESS_REPEAT_INTERVAL = 0.1
local WIGGLE_SOUND_START_INTERVAL = 0.2
local WIGGLE_SOUND_END_INTERVAL = 0.065
local WIGGLE_SOUND_START_VOLUME = 0.42
local WIGGLE_SOUND_END_VOLUME = 0.55
local WIGGLE_SOUND_START_SPEED = 0.95
local WIGGLE_SOUND_END_SPEED = 1.3

local localOpeningInProgress = false
local localPlayer = Players.LocalPlayer

local HOP_HEIGHTS       = { 0.8, 1, 1.5, 2 }
local HOP_UP_DURATIONS  = { 0.15, 0.14, 0.13, 0.12 }
local HOP_DOWN_DURATIONS = { 0.12, 0.11, 0.10, 0.09 }
local WIGGLE_DURATIONS  = { 0.08, 0.075, 0.07, 0.065 }

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function getLuckyBlockModel(configName: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("LuckyBlocks")
	local template = folder and folder:FindFirstChild(configName)
	if not template or not template:IsA("Model") then
		return nil
	end
	return template:Clone()
end

local function getBrainrotModel(configName: string, modifier: string?): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Brainrots")
	local sub = folder and folder:FindFirstChild(configName)
	if not sub then return nil end
	local template = sub:FindFirstChild(modifier or "Normal") or sub:FindFirstChild("Normal") or sub:FindFirstChildWhichIsA("Model")
	if not template or not template:IsA("Model") then return nil end
	return template:Clone()
end

local function getRewardedLuckyBlockModel(configName: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("LuckyBlocks")
	local template = folder and folder:FindFirstChild(configName)
	if not template or not template:IsA("Model") then return nil end
	return template:Clone()
end

local function prepareModel(model: Model)
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") then
			inst.Massless   = true
			inst.CanCollide = false
			inst.Anchored   = false
		end
	end
	if model.PrimaryPart then
		model.PrimaryPart.Anchored = true
	end
end

local function bounceEase(t: number): number
	if t < 1/2.75 then
		return 7.5625 * t * t
	elseif t < 2/2.75 then
		local t2 = t - 1.5/2.75
		return 7.5625 * t2 * t2 + 0.75
	elseif t < 2.5/2.75 then
		local t2 = t - 2.25/2.75
		return 7.5625 * t2 * t2 + 0.9375
	else
		local t2 = t - 2.625/2.75
		return 7.5625 * t2 * t2 + 0.984375
	end
end

local function playSound(parent: Instance, soundId: string, volume: number, playbackSpeed: number?)
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume
	s.RollOffMinDistance = 20
	s.RollOffMaxDistance = 180
	if playbackSpeed then
		s.PlaybackSpeed = playbackSpeed
	end
	s.Parent = parent
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
	return s
end

local function playWiggleSoundLoop(parent: Instance, totalDuration: number)
	if not WIGGLE_SOUND_ID or totalDuration <= 0 then
		return
	end

	task.spawn(function()
		local startedAt = os.clock()
		while parent.Parent do
			local elapsed = os.clock() - startedAt
			if elapsed >= totalDuration then
				break
			end

			local alpha = math.clamp(elapsed / totalDuration, 0, 1)
			local interval = WIGGLE_SOUND_START_INTERVAL
				+ (WIGGLE_SOUND_END_INTERVAL - WIGGLE_SOUND_START_INTERVAL) * alpha
			local volume = WIGGLE_SOUND_START_VOLUME
				+ (WIGGLE_SOUND_END_VOLUME - WIGGLE_SOUND_START_VOLUME) * alpha
			local speed = WIGGLE_SOUND_START_SPEED
				+ (WIGGLE_SOUND_END_SPEED - WIGGLE_SOUND_START_SPEED) * alpha

			playSound(parent, WIGGLE_SOUND_ID, volume, speed)
			task.wait(math.max(interval, 0.02))
		end
	end)
end

local function playSuccessRolloutSfx()
	local firstTickId = ROLLOUT_FIRST_TICK_SOUND_ID
	local successTickId = ROLLOUT_SUCCESS_SOUND_ID
	local extraRolloutId = ROLLOUT_EXTRA_SOUND_ID
	if type(firstTickId) ~= "string" or firstTickId == "" then
		return
	end
	if type(successTickId) ~= "string" or successTickId == "" then
		return
	end
	if type(extraRolloutId) ~= "string" or extraRolloutId == "" then
		return
	end

	task.spawn(function()
		Client_SoundPreload.PlayUi(extraRolloutId, 1, 2)
		Client_SoundPreload.PlayUi(firstTickId, 1, 2)
		task.wait(ROLLOUT_SUCCESS_REPEAT_INTERVAL)
		Client_SoundPreload.PlayUi(successTickId, 1, 2)
	end)
end

local function emitParticlesInContainer(container: Instance, emitCount: number)
	for _, desc in container:GetDescendants() do
		if desc:IsA("ParticleEmitter") then
			desc:Emit(emitCount)
		end
	end
end

local function scaleEmitterSizeWithReward(emitter: ParticleEmitter, rewardScale: number)
	local original = emitter.Size

	local keypoints = {}
	for _, keypoint in original.Keypoints do
		local value = keypoint.Value
		-- Keep the initial minimum size (time 0) unchanged, scale the rest.
		if keypoint.Time > 0 then
			value *= rewardScale
		end
		table.insert(keypoints, NumberSequenceKeypoint.new(keypoint.Time, value, keypoint.Envelope))
	end
	emitter.Size = NumberSequence.new(keypoints)
end

local function playLuckyBlockResultVfx(targetModel: Model, rewardScale: number)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local vfxFolder = assets and assets:FindFirstChild("VFX")
	local template = vfxFolder and vfxFolder:FindFirstChild("LuckyBlockResult")
	if not template then
		return
	end

	local vfx = template:Clone()
	vfx.Parent = workspace

	local targetPivot = targetModel:GetPivot()
	if vfx:IsA("Model") then
		vfx:PivotTo(targetPivot)
	elseif vfx:IsA("BasePart") then
		vfx.CFrame = targetPivot
	elseif vfx:IsA("Attachment") then
		local host = Instance.new("Part")
		host.Name = "LuckyBlockResultVfxHost"
		host.Anchored = true
		host.CanCollide = false
		host.Transparency = 1
		host.Size = Vector3.new(0.2, 0.2, 0.2)
		host.CFrame = targetPivot
		host.Parent = workspace
		vfx.Parent = host
		task.delay(3, function()
			if host.Parent then
				host:Destroy()
			end
		end)
	end

	task.spawn(function()
		for _, desc in vfx:GetDescendants() do
			if desc:IsA("ParticleEmitter") then
				scaleEmitterSizeWithReward(desc, rewardScale)
			end
		end

		for burst = 1, 4 do
			if not vfx.Parent then
				break
			end
			emitParticlesInContainer(vfx, 1)
			if burst < 4 then
				task.wait(0.1)
			end
		end
	end)

	task.delay(3, function()
		if vfx.Parent then
			vfx:Destroy()
		end
	end)
end

-- ── Main animation ─────────────────────────────────────────────────────────────

local function playOpening(data: {
	openId: string,
	openingUserId: number,
	configName: string,
	launchOrigin: Vector3,
	landingPosition: Vector3,
	pickedConfigName: string,
	pickedItemType: string,
	pickedLevel: number?,
	pickedModifier: string?,
	_onRewardPoppedOut: (() -> ())?,
})
	local Assets = ReplicatedStorage:FindFirstChild("Assets")
	if not Assets then return end

	local lbModel = getLuckyBlockModel(data.configName)
	if not lbModel then
		warn("[LuckyBlockOpening] No model for", data.configName)
		return
	end

	if not lbModel.PrimaryPart then
		lbModel.PrimaryPart = lbModel:FindFirstChildWhichIsA("BasePart", true)
	end
	prepareModel(lbModel)

	local defaultBaseWeight = Shared_LuckyBlocks.GetBaseWeight(data.configName)
	local blockBaseWeight = tonumber(data.blockBaseWeight) or tonumber(data.pickedBaseWeight) or defaultBaseWeight
	local blockWeight = tonumber(data.blockWeight) or tonumber(data.pickedWeight) or blockBaseWeight
	Shared_Weight.ApplyLuckyBlockScale(lbModel, blockBaseWeight, blockWeight)

	lbModel.Parent = workspace
	local primary = lbModel.PrimaryPart
	if not primary then
		lbModel:Destroy()
		return
	end

	-- Pre-resolve revealed model and its scaled half-height so opening and reveal
	-- can share the exact same air position.
	local revealedModel: Model? = nil
	local targetRevealScale = 1
	local revealedHalfHeight = primary.Size.Y * 0.5
	if data.pickedItemType == "Brainrot" then
		revealedModel = getBrainrotModel(data.pickedConfigName, data.pickedModifier or "Normal")
		local pickedBaseWeight = tonumber(data.pickedBaseWeight)
		local pickedWeight = tonumber(data.pickedWeight)
		if revealedModel then
			targetRevealScale = Shared_Weight.ApplyBrainrotScale(
				revealedModel,
				pickedBaseWeight or Shared_LuckyBlocks.GetBaseWeight(data.configName),
				pickedWeight or pickedBaseWeight
			)
		end
	elseif data.pickedItemType == "LuckyBlock" then
		revealedModel = getRewardedLuckyBlockModel(data.pickedConfigName)
	end

	if revealedModel then
		if not revealedModel.PrimaryPart then
			revealedModel.PrimaryPart = revealedModel:FindFirstChildWhichIsA("BasePart", true)
		end
		if revealedModel.PrimaryPart then
			revealedHalfHeight = revealedModel.PrimaryPart.Size.Y * 0.5
		end
	end

	local revealPreloadDone = data.pickedItemType ~= "Brainrot" or revealedModel == nil
	if not revealPreloadDone and revealedModel then
		task.spawn(function()
			Shared_BrainrotAnimations.PreloadModelAssets(
				revealedModel,
				data.pickedConfigName,
				data.pickedModifier or "Normal"
			)
			revealPreloadDone = true
		end)
	end

	-- Find floor Y at landing
	local rayResult = workspace:Raycast(
		data.landingPosition + Vector3.new(0, 10, 0),
		Vector3.new(0, -50, 0)
	)
	local groundY = rayResult and rayResult.Position.Y or (data.landingPosition.Y - 5)
	local floorHalfY = 0
	if rayResult and rayResult.Instance and rayResult.Instance:IsA("BasePart") then
		floorHalfY = rayResult.Instance.Size.Y * 0.5
	end
	-- Requested formula:
	-- floor + half_floor_Y + half_primarypart_brainrot + 1.5
	local landingY = groundY + floorHalfY + revealedHalfHeight + 1.5
	local finalLanding = Vector3.new(data.landingPosition.X, landingY, data.landingPosition.Z)

	local function getOpeningPlayer(): Player?
		return Players:GetPlayerByUserId(data.openingUserId)
	end

	local function getLookAtRotation(atPos: Vector3): CFrame
		local op = getOpeningPlayer()
		if op and op.Character then
			local root = op.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local lookTarget = Vector3.new(root.Position.X, atPos.Y, root.Position.Z)
				if (lookTarget - atPos).Magnitude > 0.01 then
					local cf = CFrame.lookAt(atPos, lookTarget)
					return cf - cf.Position
				end
			end
		end
		return CFrame.new()
	end

	-- ── FOV zoom-in: gradually shrinks during the whole pre-reveal animation ──
	local camera = workspace.CurrentCamera
	local originalFOV = camera and camera.FieldOfView or 70
	local fovZoomTween: Tween? = nil
	if camera and data.openingUserId == localPlayer.UserId then
		local totalPreRevealTime = THROW_DURATION + 0.2 + 1.8 + 0.5  -- throw + settle + phase3 + buffer
		fovZoomTween = TweenService:Create(
			camera,
			TweenInfo.new(totalPreRevealTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ FieldOfView = originalFOV - 18 }
		)
		fovZoomTween:Play()
	end

	-- ── PHASE 1: Throw arc ────────────────────────────────────────────────────
	primary.CFrame = CFrame.new(data.launchOrigin)

	local trail = Instance.new("Trail")
	local a0 = Instance.new("Attachment", primary); a0.Position = Vector3.new(0, 0, 1)
	local a1 = Instance.new("Attachment", primary); a1.Position = Vector3.new(0, 0, -1)
	trail.Attachment0 = a0; trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.3
	trail.MinLength = 0
	trail.Parent = primary

	if THROW_SOUND_ID then
		playSound(primary, THROW_SOUND_ID, 2)
	end

	local startRotation = primary.CFrame - primary.CFrame.Position
	local endRotation   = getLookAtRotation(finalLanding)
	local arcHeight     = math.min((finalLanding - data.launchOrigin).Magnitude * 0.4, 8)
	local spinAxis      = Vector3.new(1, 1, 0).Unit
	local throwStart    = os.clock()

	local throwConn
	throwConn = RunService.Heartbeat:Connect(function()
		if not lbModel.Parent then
			throwConn:Disconnect()
			return
		end
		local t = math.min((os.clock() - throwStart) / THROW_DURATION, 1)
		local hPos = data.launchOrigin:Lerp(finalLanding, t)
		local arcY = -4 * arcHeight * (t - 0.5)^2 + arcHeight
		local pos = Vector3.new(hPos.X, hPos.Y + arcY, hPos.Z)
		local baseRot = startRotation:Lerp(endRotation, t)
		local spinT = t * t * (3 - 2 * t)
		local spin = CFrame.fromAxisAngle(spinAxis, math.rad(spinT * 360))
		primary.CFrame = CFrame.new(pos) * baseRot * spin
		if t >= 1 then
			throwConn:Disconnect()
			primary.CFrame = CFrame.new(finalLanding) * endRotation
			trail:Destroy()
		end
	end)

	task.wait(THROW_DURATION)

	-- ── PHASE 2: Immediate hover lock ──────────────────────────────────────────
	local orientation = primary.CFrame - primary.CFrame.Position
	local hoverPos    = Vector3.new(finalLanding.X, finalLanding.Y, finalLanding.Z)
	primary.CFrame = CFrame.new(hoverPos) * orientation

	local lookAtCFrame = primary.CFrame

	-- ── PHASE 3: Continuous float up/down + shake ─────────────────────────────
	local phaseDuration = 1.8
	local floatAmplitude = 1.2
	local floatCycles = 2.8
	local shakeCycles = 12
	local shakeXAmplitude = WIGGLE_ANGLE * (0.45 + math.random() * 0.35)
	local shakeYAmplitude = 5
	local shakeZAmplitude = WIGGLE_ANGLE * (0.85 + math.random() * 0.3)
	local shakeXPhase = math.random() * math.pi * 2
	local shakeYPhase = math.random() * math.pi * 2
	local shakeZPhase = math.random() * math.pi * 2
	local maxScaleMultiplier = 1.35
	local scalePulseCycles = 4.2
	local scalePulsePhase = math.random() * math.pi * 2
	local minShakeSpeedMultiplier = 0.25
	local maxShakeSpeedMultiplier = 1
	local shakeSpeedRampEndT = 0.5
	local minShakeSizeMultiplier = 0.25
	local maxShakeSizeMultiplier = 1
	local shakeSizeRampEndT = 0.5
	local baseModelScale = 1
	do
		local ok, scale = pcall(function()
			return lbModel:GetScale()
		end)
		if ok and type(scale) == "number" and scale > 0 then
			baseModelScale = scale
		end
	end

	playWiggleSoundLoop(primary, phaseDuration)

	local phaseStart = os.clock()
	local lastStepTime = phaseStart
	local shakePhase = 0
	local scalePhase = 0
	local phaseConn
	phaseConn = RunService.Heartbeat:Connect(function()
		if not lbModel.Parent then
			phaseConn:Disconnect()
			return
		end

		local now = os.clock()
		local dt = math.max(0, now - lastStepTime)
		lastStepTime = now

		local elapsed = now - phaseStart
		local t = math.min(elapsed / phaseDuration, 1)
		local smoothT = t * t * (3 - 2 * t)
		local speedRampAlpha = math.clamp(t / shakeSpeedRampEndT, 0, 1)
		local speedMultiplier = minShakeSpeedMultiplier + (maxShakeSpeedMultiplier - minShakeSpeedMultiplier) * speedRampAlpha
		local sizeRampAlpha = math.clamp(t / shakeSizeRampEndT, 0, 1)
		local sizeMultiplier = minShakeSizeMultiplier + (maxShakeSizeMultiplier - minShakeSizeMultiplier) * sizeRampAlpha

		local baseShakeAngularSpeed = math.pi * 2 * shakeCycles / phaseDuration
		local baseScaleAngularSpeed = math.pi * 2 * scalePulseCycles / phaseDuration
		shakePhase += dt * baseShakeAngularSpeed * speedMultiplier
		scalePhase += dt * baseScaleAngularSpeed * speedMultiplier

		-- Real up/down around center (positive and negative).
		local floatY = math.sin(smoothT * math.pi * 2 * floatCycles) * floatAmplitude
		local angleX = math.sin(shakePhase + shakeXPhase) * shakeXAmplitude * sizeMultiplier
		local angleY = math.sin(shakePhase * 0.6 + shakeYPhase) * shakeYAmplitude * sizeMultiplier
		local angleZ = math.sin(shakePhase + shakeZPhase) * shakeZAmplitude * sizeMultiplier
		primary.CFrame = (lookAtCFrame + Vector3.new(0, floatY, 0))
			* CFrame.Angles(math.rad(angleX), math.rad(angleY), math.rad(angleZ))

		-- Always pulse upward in the requested [1.0x .. 1.35x] range.
		local pulseAlpha = (math.sin(scalePhase + scalePulsePhase) + 1) * 0.5
		local currentMaxMultiplier = 1 + (maxScaleMultiplier - 1) * sizeMultiplier
		local pulseMultiplier = 1 + (currentMaxMultiplier - 1) * pulseAlpha
		local pulseScale = baseModelScale * pulseMultiplier
		lbModel:ScaleTo(math.max(0.01, pulseScale))

		if t >= 1 then
			phaseConn:Disconnect()
		end
	end)

	task.wait(phaseDuration)
	if phaseConn.Connected then
		phaseConn:Disconnect()
	end
	primary.CFrame = lookAtCFrame
	lbModel:ScaleTo(baseModelScale)

	-- Explosion sound
	local soundHost = Instance.new("Part")
	soundHost.Anchored = true
	soundHost.CanCollide = false
	soundHost.Transparency = 1
	soundHost.Size = Vector3.new(0.1, 0.1, 0.1)
	soundHost.CFrame = primary.CFrame
	soundHost.Parent = workspace
	if EXPLOSION_SOUND_ID then
		playSound(soundHost, EXPLOSION_SOUND_ID, 0.6)
	end
	task.delay(3, function()
		if soundHost.Parent then soundHost:Destroy() end
	end)

	-- ── PHASE 4: Explosion + item pop ─────────────────────────────────────────
	if data.openingUserId == localPlayer.UserId then
		-- Stop zoom-in and snap FOV back to normal with a bouncy Back ease
		if fovZoomTween then
			fovZoomTween:Cancel()
		end
		if camera then
			TweenService:Create(
				camera,
				TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ FieldOfView = originalFOV }
			):Play()
		end
		Client_TadaEffect.Play()
	end

	while not revealPreloadDone do
		task.wait()
	end

	if revealedModel then
		if data._onRewardPoppedOut then
			data._onRewardPoppedOut()
			data._onRewardPoppedOut = nil
		end
		if data.openingUserId == localPlayer.UserId then
			playSuccessRolloutSfx()
		end

		if not revealedModel.PrimaryPart then
			revealedModel.PrimaryPart = revealedModel:FindFirstChildWhichIsA("BasePart", true)
		end
		prepareModel(revealedModel)
		revealedModel.Parent = workspace

		local fp = revealedModel.PrimaryPart
		if fp then
			local targetPos = Vector3.new(finalLanding.X, finalLanding.Y, finalLanding.Z)
			local facingCF = CFrame.new(targetPos)
			local op = getOpeningPlayer()
			if op and op.Character then
				local root = op.Character:FindFirstChild("HumanoidRootPart")
				if root then
					facingCF = CFrame.lookAt(targetPos, Vector3.new(root.Position.X, targetPos.Y, root.Position.Z))
				end
			end
			revealedModel:PivotTo(facingCF)
			revealedModel:ScaleTo(0.01)

			playLuckyBlockResultVfx(revealedModel, targetRevealScale)
		end
	end

	-- Explosion flash part
	local explosionPart = primary:Clone()
	explosionPart.Parent = workspace
	explosionPart.CFrame = primary.CFrame
	explosionPart.Anchored = true
	explosionPart.Material = Enum.Material.Neon
	explosionPart.Color = Color3.new(1, 1, 1)
	explosionPart.Transparency = 0
	for _, ch in explosionPart:GetChildren() do
		if ch:IsA("Decal") or ch:IsA("Texture") or ch:IsA("SurfaceAppearance") then
			ch:Destroy()
		end
	end
	local origSize = explosionPart.Size
	explosionPart.Size = origSize * 0.5

	-- Hide LB model
	for _, p in lbModel:GetDescendants() do
		if p:IsA("BasePart") then p.Transparency = 1 end
	end

	local exStart = os.clock()
	local exConn
	exConn = RunService.Heartbeat:Connect(function()
		if not explosionPart.Parent then exConn:Disconnect(); return end
		local t = (os.clock() - exStart) / EXPLOSION_DURATION
		if t >= 1 then
			exConn:Disconnect()
			explosionPart:Destroy()
			return
		end
		explosionPart.Size = origSize * (0.5 + t * (EXPLOSION_SCALE - 0.5))
		explosionPart.Transparency = 1 - (1 - t)^3
	end)

	lbModel:Destroy()

	-- Pop animation for revealed model
	task.spawn(function()
		if not revealedModel or not revealedModel.Parent then return end

		local popStart = os.clock()
		local popConn
		popConn = RunService.Heartbeat:Connect(function()
			if not revealedModel.Parent then popConn:Disconnect(); return end
			local t = math.min((os.clock() - popStart) / REVEAL_POP_DURATION, 1)
			local scale
			if t < 0.7 then
				local st = t / 0.7
				local e = st * st * (3 - 2 * st)
				scale = 0.01 + e * (targetRevealScale * 1.1 - 0.01)
			else
				local st = (t - 0.7) / 0.3
				local e = 1 - (1 - st)^2
				scale = targetRevealScale * (1.1 - e * 0.1)
			end
			revealedModel:ScaleTo(scale)
			if t >= 1 then
				popConn:Disconnect()
				revealedModel:ScaleTo(targetRevealScale)
			end
		end)
		task.wait(REVEAL_POP_DURATION)
		if popConn.Connected then popConn:Disconnect() end
		revealedModel:ScaleTo(targetRevealScale)

		if data.pickedItemType == "Brainrot" and revealedModel.Parent then
			local pickedLevel = math.max(1, math.floor(data.pickedLevel or 1))
			Shared_BrainrotBillboard.Setup(
				revealedModel,
				data.pickedConfigName,
				data.pickedModifier or "Normal",
				pickedLevel,
				data.pickedBaseWeight,
				data.pickedWeight
			)
		end
	end)

	task.wait(EXPLOSION_DURATION)

	-- ── PHASE 5: Rotating reveal ───────────────────────────────────────────────
	if revealedModel and revealedModel.Parent then
		local pivotPos     = revealedModel:GetPivot().Position
		local baseRotation = revealedModel:GetPivot() - pivotPos
		local totalReveal  = REVEAL_ROTATE_DURATION + REVEAL_SHRINK_DURATION
		local revealStart  = os.clock()

		local revConn
		revConn = RunService.Heartbeat:Connect(function()
			if not revealedModel.Parent then revConn:Disconnect(); return end
			local elapsed = os.clock() - revealStart
			local t = elapsed / totalReveal
			if t >= 1 then
				revConn:Disconnect()
				revealedModel:Destroy()
				return
			end

			local bounce = math.sin(t * math.pi * 2) * REVEAL_BOUNCE_HEIGHT
			local pos = Vector3.new(pivotPos.X, pivotPos.Y + bounce, pivotPos.Z)
			local baseCF = CFrame.new(pos) * baseRotation
			revealedModel:PivotTo(baseCF * CFrame.Angles(0, math.rad(t * REVEAL_Y_ROTATION_DEGREES), 0))

			if elapsed > REVEAL_ROTATE_DURATION then
				local st = (elapsed - REVEAL_ROTATE_DURATION) / REVEAL_SHRINK_DURATION
				revealedModel:ScaleTo(math.max(targetRevealScale * (1 - st), 0.01))
			end
		end)

		task.wait(totalReveal)
		if revConn.Connected then revConn:Disconnect() end
		if revealedModel.Parent then revealedModel:Destroy() end
	end
end

-- ── Init ──────────────────────────────────────────────────────────────────────

function Client_LuckyBlockOpening.Init()
	local events = ReplicatedStorage:WaitForChild("Events")
	local remote = events:WaitForChild("PlotHandler", 10)
	if not remote or not remote:IsA("RemoteEvent") then
		warn("[Client_LuckyBlockOpening] PlotHandler RemoteEvent not found")
		return
	end

	remote.OnClientEvent:Connect(function(action, data)
		if action ~= "LuckyBlockOpen" then
			return
		end
		if type(data) ~= "table" then
			return
		end
		local isLocalOpen = data.openingUserId == localPlayer.UserId
		if isLocalOpen and localOpeningInProgress then
			return
		end

		local rewardIndex = if isLocalOpen then data.rewardInventoryIndex else nil
		if isLocalOpen and type(rewardIndex) == "number" then
			Client_LuckyBlockRevealState.MaskIndex(rewardIndex)
		end

		if isLocalOpen then
			localOpeningInProgress = true
		end

		task.spawn(function()
			local rewardUnmasked = false
			local function unmaskReward()
				if rewardUnmasked or not isLocalOpen then
					return
				end
				rewardUnmasked = true
				if type(rewardIndex) == "number" then
					Client_LuckyBlockRevealState.UnmaskIndex(rewardIndex)
				end
			end

			if isLocalOpen then
				data._onRewardPoppedOut = unmaskReward
			end

			local ok, err = pcall(function()
				playOpening(data :: any)
			end)
			if isLocalOpen then
				localOpeningInProgress = false
			end
			unmaskReward()
			if not ok then
				warn("[Client_LuckyBlockOpening] Animation failed:", err)
			end
		end)
	end)
end

function Client_LuckyBlockOpening.IsOpeningBusy(): boolean
	return localOpeningInProgress
end

return Client_LuckyBlockOpening