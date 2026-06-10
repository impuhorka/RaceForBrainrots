local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_GameProcess = SharedModules.require("Shared_GameProcess")

local Client_GameProcessLuckyBlocks = {}

local hookedModels: { [Model]: boolean } = {}
local animationConnections: { [Model]: RBXScriptConnection } = {}

local function stopAnimation(model: Model)
	local connection = animationConnections[model]
	if connection then
		connection:Disconnect()
		animationConnections[model] = nil
	end
	hookedModels[model] = nil
end

local function startAnimation(model: Model)
	if hookedModels[model] then
		return
	end
	hookedModels[model] = true

	local basePivot = model:GetPivot()
	local basePosition = basePivot.Position
	local baseRotation = basePivot - basePivot.Position
	local phase = math.random() * math.pi * 2
	local startTime = os.clock()

	local floatHeight = model:GetAttribute("FloatHeight")
	if type(floatHeight) ~= "number" or floatHeight <= 0 then
		local _, bboxSize = model:GetBoundingBox()
		floatHeight = Shared_GameProcess.GetWorldLuckyBlockFloatHeight(bboxSize.Y)
	end
	local floatSpeed = Shared_GameProcess.WorldLuckyBlockFloatSpeed
	local rotateSpeed = math.rad(Shared_GameProcess.WorldLuckyBlockRotateSpeed)

	animationConnections[model] = RunService.RenderStepped:Connect(function()
		if not model.Parent then
			stopAnimation(model)
			return
		end

		local elapsed = os.clock() - startTime
		local yOffset = math.sin(elapsed * floatSpeed + phase) * floatHeight
		local spin = CFrame.Angles(0, rotateSpeed * elapsed, 0)
		model:PivotTo(CFrame.new(basePosition + Vector3.new(0, yOffset, 0)) * baseRotation * spin)
	end)

	model.Destroying:Once(function()
		stopAnimation(model)
	end)
end

local function tryHookModel(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	if instance:GetAttribute("IsWorldLuckyBlock") == true then
		startAnimation(instance)
	end
end

local function watchModel(instance: Instance)
	tryHookModel(instance)

	if instance:IsA("Model") then
		instance:GetAttributeChangedSignal("IsWorldLuckyBlock"):Connect(function()
			tryHookModel(instance)
		end)
	end
end

function Client_GameProcessLuckyBlocks.Init()
	local zones = Workspace:WaitForChild("Zones", 30)
	if not zones then
		return
	end

	local floorsFolder = zones:WaitForChild("Floors", 30)
	if not floorsFolder then
		return
	end

	for _, descendant in floorsFolder:GetDescendants() do
		watchModel(descendant)
	end

	floorsFolder.DescendantAdded:Connect(watchModel)
end

return Client_GameProcessLuckyBlocks