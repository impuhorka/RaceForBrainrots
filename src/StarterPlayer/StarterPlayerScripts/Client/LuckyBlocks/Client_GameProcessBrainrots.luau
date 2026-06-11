local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local ClientLoader = require(script.Parent.Parent.Loader)

local Shared_GameProcess = SharedModules.require("Shared_GameProcess")
local Client_WorldDropAnimation = ClientLoader.require("Client_WorldDropAnimation")
local Client_VisualSettings = ClientLoader.require("Client_VisualSettings")

local Client_GameProcessBrainrots = {}

type DropSpinState = {
	spinYaw: number,
	spinStartTime: number,
	spinStartSpeed: number,
	spinStopDuration: number,
	endRotation: CFrame,
}

local hookedModels: { [Model]: boolean } = {}
local animationConnections: { [Model]: RBXScriptConnection } = {}
local dropAnimPlayed: { [Model]: boolean } = {}

local function ensurePrimaryPart(model: Model): BasePart?
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
	end
	return model.PrimaryPart
end

local function stopAnimation(model: Model)
	local connection = animationConnections[model]
	if connection then
		connection:Disconnect()
		animationConnections[model] = nil
	end
	hookedModels[model] = nil
end

local function getFloatBasePosition(model: Model): Vector3
	local storedBase = model:GetAttribute("WorldFloatBasePosition")
	if typeof(storedBase) == "Vector3" then
		return storedBase
	end
	return model:GetPivot().Position
end

local function getModelBaseRotation(model: Model): CFrame
	local primaryPart = ensurePrimaryPart(model)
	if primaryPart then
		local primaryCFrame = primaryPart.CFrame
		return primaryCFrame - primaryCFrame.Position
	end

	local basePivot = model:GetPivot()
	return basePivot - basePivot.Position
end

local function easeOutQuart(t: number): number
	local u = 1 - t
	return 1 - u * u * u * u
end

local function startIdleFloat(model: Model, dropSpin: DropSpinState?)
	stopAnimation(model)
	hookedModels[model] = true

	local basePosition = getFloatBasePosition(model)
	local baseRotation = if dropSpin then dropSpin.endRotation else getModelBaseRotation(model)
	local phase = math.pi
	local startTime = os.clock()
	local spinYaw = dropSpin and dropSpin.spinYaw or 0
	local spinStartTime = dropSpin and dropSpin.spinStartTime or 0
	local spinStartSpeed = dropSpin and dropSpin.spinStartSpeed or 0
	local spinStopDuration = dropSpin and dropSpin.spinStopDuration or 0
	local lastTick = os.clock()

	local floatHeight = model:GetAttribute("FloatHeight")
	if type(floatHeight) ~= "number" or floatHeight <= 0 then
		local _, bboxSize = model:GetBoundingBox()
		floatHeight = Shared_GameProcess.GetWorldLuckyBlockFloatHeight(bboxSize.Y)
	end
	local floatSpeed = Shared_GameProcess.WorldLuckyBlockFloatSpeed

	animationConnections[model] = RunService.RenderStepped:Connect(function()
		if not model.Parent then
			stopAnimation(model)
			return
		end

		if not Client_VisualSettings.AreEffectsEnabled() then
			return
		end

		local now = os.clock()
		local dt = now - lastTick
		lastTick = now

		local elapsed = now - startTime
		local yOffset = math.sin(elapsed * floatSpeed + phase) * floatHeight

		local rotation = baseRotation
		if dropSpin and math.abs(spinStartSpeed) > 0 then
			local elapsed = now - spinStartTime
			local stopT = math.min(elapsed / spinStopDuration, 1)
			local speedMul = 1 - easeOutQuart(stopT)
			if speedMul > 0 then
				spinYaw += spinStartSpeed * speedMul * dt
			end
			rotation = CFrame.Angles(0, spinYaw, 0) * baseRotation
		end

		model:PivotTo(CFrame.new(basePosition + Vector3.new(0, yOffset, 0)) * rotation)
	end)

	model.Destroying:Once(function()
		stopAnimation(model)
		dropAnimPlayed[model] = nil
	end)
end

local function tryPlayDropAnimation(model: Model)
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
	local sizeScale = model:GetAttribute("DropSizeScale")
	local floatHeight = model:GetAttribute("FloatHeight")

	Client_WorldDropAnimation.play(model, {
		launchOrigin = launchOrigin,
		landingPosition = landingPosition,
		lookAtUserId = if type(droppedByUserId) == "number" then droppedByUserId else nil,
		sizeScale = if type(sizeScale) == "number" then sizeScale else 1,
		floatAmplitude = if type(floatHeight) == "number" then floatHeight else nil,
	}, function(dropResult)
		if model.Parent and model:GetAttribute("IsWorldBrainrot") == true then
			startIdleFloat(model, dropResult)
		end
	end)

	return true
end

local function tryHookModel(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	if instance:GetAttribute("IsWorldBrainrot") ~= true then
		stopAnimation(instance)
		dropAnimPlayed[instance] = nil
		return
	end

	task.defer(function()
		if not instance.Parent or instance:GetAttribute("IsWorldBrainrot") ~= true then
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

		if not hookedModels[instance] then
			startIdleFloat(instance)
		end
	end)
end

local function watchModel(instance: Instance)
	tryHookModel(instance)

	if instance:IsA("Model") then
		instance:GetAttributeChangedSignal("IsWorldBrainrot"):Connect(function()
			tryHookModel(instance)
		end)
		instance:GetAttributeChangedSignal("WorldFloatBasePosition"):Connect(function()
			tryHookModel(instance)
		end)
		instance:GetAttributeChangedSignal("DropLaunchOrigin"):Connect(function()
			tryHookModel(instance)
		end)
	end
end

function Client_GameProcessBrainrots.Init()
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
		if descendant:IsA("Model") then
			watchModel(descendant)
		end
	end

	floorsFolder.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Model") then
			watchModel(descendant)
		end
	end)
end

return Client_GameProcessBrainrots
