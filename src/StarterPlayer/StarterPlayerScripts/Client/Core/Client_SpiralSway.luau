local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Client_SpiralSway = {}

local SPIRAL_TAG = "spiral"
local SPIRAL_SWAY_AMPLITUDE = 18
local SPIRAL_SWAY_SPEED = 5.5

type SpiralEntry = {
	instance: GuiObject,
	phase: number,
}

local spirals: { [GuiObject]: SpiralEntry } = {}
local cleanupConns: { [GuiObject]: RBXScriptConnection } = {}
local heartbeatConnection: RBXScriptConnection? = nil
local initialized = false

local function untrackSpiral(instance: GuiObject)
	spirals[instance] = nil

	local conn = cleanupConns[instance]
	if conn then
		conn:Disconnect()
		cleanupConns[instance] = nil
	end
end

local function trackSpiral(instance: Instance)
	if not instance:IsA("GuiObject") then
		return
	end
	if spirals[instance] then
		return
	end

	spirals[instance] = {
		instance = instance,
		phase = math.random() * math.pi * 2,
	}

	cleanupConns[instance] = instance.AncestryChanged:Connect(function(_, parent)
		if not parent then
			untrackSpiral(instance)
		end
	end)
end

local function onSpiralTagAdded(instance: Instance)
	trackSpiral(instance)
end

local function onSpiralTagRemoved(instance: Instance)
	if instance:IsA("GuiObject") then
		untrackSpiral(instance)
	end
end

local function startHeartbeat()
	if heartbeatConnection then
		return
	end

	heartbeatConnection = RunService.Heartbeat:Connect(function()
		local baseT = os.clock() * SPIRAL_SWAY_SPEED

		for instance, entry in spirals do
			if not instance.Parent then
				untrackSpiral(instance)
				continue
			end

			entry.instance.Rotation = math.sin(baseT + entry.phase) * SPIRAL_SWAY_AMPLITUDE
		end
	end)
end

function Client_SpiralSway.Init()
	if initialized then
		return
	end
	initialized = true

	for _, instance in CollectionService:GetTagged(SPIRAL_TAG) do
		trackSpiral(instance)
	end

	CollectionService:GetInstanceAddedSignal(SPIRAL_TAG):Connect(onSpiralTagAdded)
	CollectionService:GetInstanceRemovedSignal(SPIRAL_TAG):Connect(onSpiralTagRemoved)
	startHeartbeat()
end

return Client_SpiralSway
