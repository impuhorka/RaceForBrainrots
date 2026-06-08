local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Client_RainbowBrainrots = {}

local TAG = "Rainbow"
local RAINBOW_MODEL_TAG = "RainbowModel"
local RAINBOW_PERIOD = 6
local UPDATE_HZ = 12
local UPDATE_DT = 1 / UPDATE_HZ

local trackedSAs: { [SurfaceAppearance]: boolean } = {}
local connsByRoot: { [Instance]: { RBXScriptConnection } } = {}
local rainbowModelAncestryConns: { [Instance]: RBXScriptConnection } = {}
local heartbeatConnection: RBXScriptConnection? = nil
local initialized = false
local acc = 0
local t = 0

local function syncRainbowTagFromRainbowModel(inst: Instance)
	if not inst.Parent then
		if CollectionService:HasTag(inst, TAG) then
			CollectionService:RemoveTag(inst, TAG)
		end
		return
	end

	if inst:IsDescendantOf(ReplicatedStorage) then
		if CollectionService:HasTag(inst, TAG) then
			CollectionService:RemoveTag(inst, TAG)
		end
	else
		if not CollectionService:HasTag(inst, TAG) then
			CollectionService:AddTag(inst, TAG)
		end
	end
end

local function hookRainbowModel(inst: Instance)
	local old = rainbowModelAncestryConns[inst]
	if old then
		old:Disconnect()
	end

	syncRainbowTagFromRainbowModel(inst)
	rainbowModelAncestryConns[inst] = inst.AncestryChanged:Connect(function()
		syncRainbowTagFromRainbowModel(inst)
	end)
end

local function unhookRainbowModel(inst: Instance)
	local c = rainbowModelAncestryConns[inst]
	if c then
		c:Disconnect()
	end
	rainbowModelAncestryConns[inst] = nil

	if CollectionService:HasTag(inst, TAG) then
		CollectionService:RemoveTag(inst, TAG)
	end
end

local function isMesh(inst: Instance): boolean
	return inst:IsA("MeshPart") or inst:IsA("SkinnedMeshPart")
end

local function ensureSA(mesh: Instance): SurfaceAppearance
	local sa = mesh:FindFirstChildOfClass("SurfaceAppearance")
	if not sa then
		sa = Instance.new("SurfaceAppearance")
		sa.Name = "AutoRainbowSA"
		sa.Parent = mesh
	end
	return sa
end

local function trackSA(sa: SurfaceAppearance)
	trackedSAs[sa] = true
	if not connsByRoot[sa] then
		connsByRoot[sa] = {}
	end

	table.insert(connsByRoot[sa], sa.AncestryChanged:Connect(function(_, parent)
		if parent then
			return
		end

		trackedSAs[sa] = nil
		for _, c in connsByRoot[sa] or {} do
			pcall(function()
				c:Disconnect()
			end)
		end
		connsByRoot[sa] = nil
	end))
end

local function addMesh(mesh: Instance)
	if not isMesh(mesh) then
		return
	end

	local sa = ensureSA(mesh)
	trackSA(sa)
end

local function startForModel(model: Model)
	for _, inst in model:GetDescendants() do
		if isMesh(inst) then
			addMesh(inst)
		end
	end

	if not connsByRoot[model] then
		connsByRoot[model] = {}
	end

	table.insert(connsByRoot[model], model.DescendantAdded:Connect(function(inst)
		if isMesh(inst) then
			addMesh(inst)
		end
	end))

	table.insert(connsByRoot[model], model.AncestryChanged:Connect(function(_, parent)
		if parent then
			return
		end
		for _, c in connsByRoot[model] or {} do
			pcall(function()
				c:Disconnect()
			end)
		end
		connsByRoot[model] = nil
	end))
end

local function stopForRoot(root: Instance)
	for _, c in connsByRoot[root] or {} do
		pcall(function()
			c:Disconnect()
		end)
	end
	connsByRoot[root] = nil

	if root:IsA("SurfaceAppearance") then
		root.Color = Color3.fromRGB(255, 255, 255)
		trackedSAs[root] = nil
	end
end

function Client_RainbowBrainrots.Init()
	if initialized then
		return
	end
	initialized = true

	for _, inst in CollectionService:GetTagged(RAINBOW_MODEL_TAG) do
		hookRainbowModel(inst)
	end

	CollectionService:GetInstanceAddedSignal(RAINBOW_MODEL_TAG):Connect(hookRainbowModel)
	CollectionService:GetInstanceRemovedSignal(RAINBOW_MODEL_TAG):Connect(unhookRainbowModel)

	for _, inst in CollectionService:GetTagged(TAG) do
		if inst:IsA("Model") then
			startForModel(inst)
		elseif isMesh(inst) then
			addMesh(inst)
		end
	end

	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
		if inst:IsA("Model") then
			startForModel(inst)
		elseif isMesh(inst) then
			addMesh(inst)
		end
	end)

	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
		stopForRoot(inst)
	end)

	heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		if not heartbeatConnection then
			return
		end

		acc += dt
		if acc < UPDATE_DT then
			return
		end

		t += acc
		acc = 0
		local h = (t / RAINBOW_PERIOD) % 1
		local tint = Color3.fromHSV(h, 1, 1)

		for sa in trackedSAs do
			if sa.Parent then
				sa.Color = tint
			else
				trackedSAs[sa] = nil
			end
		end
	end)
end

return Client_RainbowBrainrots
