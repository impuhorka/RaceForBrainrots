local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local ClientLoader = require(script.Parent.Parent.Loader)
local Shared_GameProcess = SharedModules.require("Shared_GameProcess")
local Shared_LuckyBlockBillboard = SharedModules.require("Shared_LuckyBlockBillboard")
local Shared_Weight = SharedModules.require("Shared_Weight")
local Client_WorldDropAnimation = ClientLoader.require("Client_WorldDropAnimation")

local Client_GameProcessLuckyBlocks = {}

type DropSpinState = {
	spinYaw: number,
	spinStartTime: number,
	spinStartSpeed: number,
	spinStopDuration: number,
	endRotation: CFrame,
}

local MODEL_LOAD_STABLE_FRAMES = 3
local MODEL_LOAD_TIMEOUT = 4

local hookedModels: { [Model]: boolean } = {}
local animationConnections: { [Model]: RBXScriptConnection } = {}
local descendantConnections: { [Model]: RBXScriptConnection } = {}
local dropAnimPlayed: { [Model]: boolean } = {}
local resyncScheduled: { [Model]: boolean } = {}
local activeDropSpin: { [Model]: DropSpinState? } = {}

local function easeOutQuart(t: number): number
	local u = 1 - t
	return 1 - u * u * u * u
end

local function countBaseParts(model: Model): number
	local count = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

local function waitForStableModel(model: Model): boolean
	local deadline = os.clock() + MODEL_LOAD_TIMEOUT
	local lastCount = -1
	local stableFrames = 0

	while model.Parent and os.clock() < deadline do
		local count = countBaseParts(model)
		if count > 0 and count == lastCount then
			stableFrames += 1
			if stableFrames >= MODEL_LOAD_STABLE_FRAMES then
				return true
			end
		else
			stableFrames = 0
		end

		lastCount = count
		RunService.Heartbeat:Wait()
	end

	return lastCount > 0
end

local function stopAnimation(model: Model)
	local connection = animationConnections[model]
	if connection then
		connection:Disconnect()
		animationConnections[model] = nil
	end

	local descendantConnection = descendantConnections[model]
	if descendantConnection then
		descendantConnection:Disconnect()
		descendantConnections[model] = nil
	end

	hookedModels[model] = nil
	activeDropSpin[model] = nil
	resyncScheduled[model] = nil
end

local function getModelBaseRotation(model: Model): CFrame
	local primaryPart = Shared_Weight.EnsureLuckyBlockPrimaryPart(model)
	if primaryPart then
		local primaryCFrame = primaryPart.CFrame
		return primaryCFrame - primaryCFrame.Position
	end

	local basePivot = model:GetPivot()
	return basePivot - basePivot.Position
end

local function getFloatBasePosition(model: Model): Vector3
	local storedBase = model:GetAttribute("WorldFloatBasePosition")
	if typeof(storedBase) == "Vector3" then
		return storedBase
	end
	return model:GetPivot().Position
end

local function getIdleSpinDirection(model: Model, dropSpin: DropSpinState?): number
	if dropSpin and math.abs(dropSpin.spinStartSpeed) > 0 then
		return if dropSpin.spinStartSpeed > 0 then 1 else -1
	end

	local stored = model:GetAttribute("FloatSpinDirection")
	if type(stored) == "number" and stored ~= 0 then
		return if stored > 0 then 1 else -1
	end

	return if math.random() < 0.5 then -1 else 1
end

local function prepareModelForClientAnimation(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end
end

local function capturePartOffsets(model: Model, pivotCF: CFrame): { [BasePart]: CFrame }
	local offsets: { [BasePart]: CFrame } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			offsets[descendant] = pivotCF:ToObjectSpace(descendant.CFrame)
		end
	end
	return offsets
end

local function applyModelPose(model: Model, pivotCF: CFrame, partOffsets: { [BasePart]: CFrame })
	for part, offset in partOffsets do
		if part.Parent and part:IsDescendantOf(model) then
			part.CFrame = pivotCF:ToWorldSpace(offset)
		end
	end
end

local startAnimation: (Model, DropSpinState?) -> ()

local function scheduleAnimationResync(model: Model)
	if resyncScheduled[model] or not model.Parent then
		return
	end

	resyncScheduled[model] = true
	local dropSpin = activeDropSpin[model]

	task.spawn(function()
		task.wait()
		resyncScheduled[model] = nil

		if not model.Parent or model:GetAttribute("IsWorldLuckyBlock") ~= true then
			return
		end

		if dropAnimPlayed[model] then
			return
		end

		if not waitForStableModel(model) then
			return
		end

		startAnimation(model, dropSpin)
	end)
end

function startAnimation(model: Model, dropSpin: DropSpinState?)
	stopAnimation(model)
	hookedModels[model] = true
	activeDropSpin[model] = dropSpin

	Shared_Weight.SyncLuckyBlockPivot(model)
	prepareModelForClientAnimation(model)

	local basePosition = getFloatBasePosition(model)
	local baseRotation = if dropSpin then dropSpin.endRotation else getModelBaseRotation(model)
	-- Start at rest height; sin(pi) == 0 with downward velocity so idle float does not pop up on land.
	local phase = math.pi
	local startTime = os.clock()
	local spinYaw = dropSpin and dropSpin.spinYaw or 0
	local spinStartTime = dropSpin and dropSpin.spinStartTime or 0
	local spinStartSpeed = dropSpin and dropSpin.spinStartSpeed or 0
	local spinStopDuration = dropSpin and dropSpin.spinStopDuration or 0
	local idleSpinYaw = 0
	local idleSpinDirection = getIdleSpinDirection(model, dropSpin)
	local idleSpinSpeed = math.rad(Shared_GameProcess.WorldLuckyBlockRotateSpeed)
	local lastTick = os.clock()

	local floatHeight = model:GetAttribute("FloatHeight")
	if type(floatHeight) ~= "number" or floatHeight <= 0 then
		local _, bboxSize = model:GetBoundingBox()
		floatHeight = Shared_GameProcess.GetWorldLuckyBlockFloatHeight(bboxSize.Y)
	end
	local floatSpeed = Shared_GameProcess.WorldLuckyBlockFloatSpeed

	local restPivot = CFrame.new(basePosition) * baseRotation
	local partOffsets = capturePartOffsets(model, restPivot)
	applyModelPose(model, restPivot, partOffsets)

	descendantConnections[model] = model.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			scheduleAnimationResync(model)
		end
	end)

	animationConnections[model] = RunService.RenderStepped:Connect(function()
		if not model.Parent then
			stopAnimation(model)
			return
		end

		local now = os.clock()
		local dt = now - lastTick
		lastTick = now

		local elapsed = now - startTime
		local yOffset = math.sin(elapsed * floatSpeed + phase) * floatHeight

		local dropSpinActive = dropSpin ~= nil and math.abs(spinStartSpeed) > 0
		local dropSpeedMul = 0
		if dropSpinActive then
			local spinElapsed = now - spinStartTime
			dropSpeedMul = 1 - easeOutQuart(math.min(spinElapsed / spinStopDuration, 1))
		end

		if not dropSpinActive or dropSpeedMul <= 0 then
			idleSpinYaw += idleSpinSpeed * idleSpinDirection * dt
		end

		local totalYaw = idleSpinYaw
		if dropSpinActive and dropSpeedMul > 0 then
			spinYaw += spinStartSpeed * dropSpeedMul * dt
			totalYaw += spinYaw
		end

		local rotation = CFrame.Angles(0, totalYaw, 0) * baseRotation
		local pivotCF = CFrame.new(basePosition + Vector3.new(0, yOffset, 0)) * rotation
		applyModelPose(model, pivotCF, partOffsets)
	end)

	model.Destroying:Once(function()
		stopAnimation(model)
		dropAnimPlayed[model] = nil
	end)
end

local function updateDespawnDisplay(model: Model)
	local remaining = model:GetAttribute("DespawnSecondsRemaining")
	if type(remaining) == "number" and remaining > 0 then
		Shared_LuckyBlockBillboard.UpdateDespawnCountdown(model, remaining)
	else
		Shared_LuckyBlockBillboard.UpdateDespawnCountdown(model, nil)
	end
end

local function tryPlayDropAnimation(model: Model): boolean
	if dropAnimPlayed[model] then
		return false
	end

	local launchOrigin = model:GetAttribute("DropLaunchOrigin")
	local landingPosition = model:GetAttribute("WorldFloatBasePosition")
	if typeof(launchOrigin) ~= "Vector3" or typeof(landingPosition) ~= "Vector3" then
		return false
	end

	stopAnimation(model)
	dropAnimPlayed[model] = true
	local droppedByUserId = model:GetAttribute("DroppedByUserId")
	if type(droppedByUserId) == "number" and droppedByUserId == Players.LocalPlayer.UserId then
		local localLaunchOrigin = Client_WorldDropAnimation.getLocalPlayerLaunchOrigin()
		if localLaunchOrigin then
			launchOrigin = localLaunchOrigin
		end
	end
	local sizeScale = model:GetAttribute("DropSizeScale")
	local floatHeight = model:GetAttribute("FloatHeight")

	Client_WorldDropAnimation.play(model, {
		launchOrigin = launchOrigin,
		landingPosition = landingPosition,
		lookAtUserId = if type(droppedByUserId) == "number" then droppedByUserId else nil,
		sizeScale = if type(sizeScale) == "number" then sizeScale else 1,
		floatAmplitude = if type(floatHeight) == "number" then floatHeight else nil,
	}, function(dropResult)
		if model.Parent and model:GetAttribute("IsWorldLuckyBlock") == true then
			task.spawn(function()
				waitForStableModel(model)
				startAnimation(model, dropResult)
			end)
		end
	end)

	return true
end

local function tryHookModel(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	if instance:GetAttribute("IsWorldLuckyBlock") ~= true then
		stopAnimation(instance)
		dropAnimPlayed[instance] = nil
		return
	end

	task.spawn(function()
		if not instance.Parent or instance:GetAttribute("IsWorldLuckyBlock") ~= true then
			return
		end

		if tryPlayDropAnimation(instance) then
			return
		end

		if dropAnimPlayed[instance] then
			return
		end

		if typeof(instance:GetAttribute("DropLaunchOrigin")) == "Vector3" then
			return
		end

		if not waitForStableModel(instance) then
			return
		end

		if not instance.Parent or instance:GetAttribute("IsWorldLuckyBlock") ~= true then
			return
		end

		if dropAnimPlayed[instance] or hookedModels[instance] then
			return
		end

		startAnimation(instance)
	end)
end

local function watchModel(instance: Instance)
	tryHookModel(instance)

	if instance:IsA("Model") then
		instance:GetAttributeChangedSignal("IsWorldLuckyBlock"):Connect(function()
			tryHookModel(instance)
		end)
		instance:GetAttributeChangedSignal("WorldFloatBasePosition"):Connect(function()
			tryHookModel(instance)
		end)
		instance:GetAttributeChangedSignal("DropLaunchOrigin"):Connect(function()
			tryHookModel(instance)
		end)
		instance:GetAttributeChangedSignal("DespawnSecondsRemaining"):Connect(function()
			updateDespawnDisplay(instance)
		end)
		task.defer(function()
			if instance.Parent then
				updateDespawnDisplay(instance)
			end
		end)
	end
end

function Client_GameProcessLuckyBlocks.Init()
	local gameFolder = Workspace:WaitForChild("Game", 30)
	if not gameFolder then
		return
	end

	local mapFolder = gameFolder:WaitForChild("Map", 30)
	if not mapFolder then
		return
	end

	local floorsFolder = mapFolder:WaitForChild("Floors", 30)
	if not floorsFolder then
		return
	end

	for _, descendant in floorsFolder:GetDescendants() do
		watchModel(descendant)
	end

	floorsFolder.DescendantAdded:Connect(watchModel)
end

return Client_GameProcessLuckyBlocks
