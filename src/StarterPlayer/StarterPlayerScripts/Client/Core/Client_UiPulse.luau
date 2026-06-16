local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Client_UiPulse = {}

local PULSE_TAG = "pulse"
local PULSE_SIZING_ATTRIBUTE = "PulseSizing"
local PULSE_MIN_SCALE = 1
local DEFAULT_PULSE_MAX_SCALE = 1.15
local PULSE_SPEED = 2

type PulseEntry = {
	instance: GuiObject,
	originSize: UDim2,
	phase: number,
}

local pulses: { [GuiObject]: PulseEntry } = {}
local cleanupConns: { [GuiObject]: RBXScriptConnection } = {}
local heartbeatConnection: RBXScriptConnection? = nil
local initialized = false

local function scaleUdim2(size: UDim2, factor: number): UDim2
	return UDim2.new(
		size.X.Scale * factor,
		math.floor(size.X.Offset * factor + 0.5),
		size.Y.Scale * factor,
		math.floor(size.Y.Offset * factor + 0.5)
	)
end

local function getPulseMaxScale(instance: GuiObject): number
	local value = instance:GetAttribute(PULSE_SIZING_ATTRIBUTE)
	if type(value) == "number" and value > PULSE_MIN_SCALE then
		return value
	end

	if type(value) == "string" then
		local cleaned = string.gsub(value, "^[xX]", "")
		local parsed = tonumber(cleaned)
		if parsed and parsed > PULSE_MIN_SCALE then
			return parsed
		end
	end

	return DEFAULT_PULSE_MAX_SCALE
end

local function getPulseScale(alpha: number, maxScale: number): number
	local normalized = (math.sin(alpha) + 1) * 0.5
	return PULSE_MIN_SCALE + (maxScale - PULSE_MIN_SCALE) * normalized
end

local function untrackPulse(instance: GuiObject)
	pulses[instance] = nil

	local conn = cleanupConns[instance]
	if conn then
		conn:Disconnect()
		cleanupConns[instance] = nil
	end
end

local function trackPulse(instance: Instance)
	if not instance:IsA("GuiObject") then
		return
	end
	if pulses[instance] then
		return
	end

	pulses[instance] = {
		instance = instance,
		originSize = instance.Size,
		phase = math.random() * math.pi * 2,
	}

	cleanupConns[instance] = instance.AncestryChanged:Connect(function(_, parent)
		if not parent then
			untrackPulse(instance)
		end
	end)
end

local function onPulseTagAdded(instance: Instance)
	trackPulse(instance)
end

local function onPulseTagRemoved(instance: Instance)
	if instance:IsA("GuiObject") then
		untrackPulse(instance)
	end
end

local function startHeartbeat()
	if heartbeatConnection then
		return
	end

	heartbeatConnection = RunService.Heartbeat:Connect(function()
		local baseT = os.clock() * PULSE_SPEED

		for instance, entry in pulses do
			if not instance.Parent then
				untrackPulse(instance)
				continue
			end

			local maxScale = getPulseMaxScale(entry.instance)
			local scaleFactor = getPulseScale(baseT + entry.phase, maxScale)
			entry.instance.Size = scaleUdim2(entry.originSize, scaleFactor)
		end
	end)
end

function Client_UiPulse.Init()
	if initialized then
		return
	end
	initialized = true

	for _, instance in CollectionService:GetTagged(PULSE_TAG) do
		trackPulse(instance)
	end

	CollectionService:GetInstanceAddedSignal(PULSE_TAG):Connect(onPulseTagAdded)
	CollectionService:GetInstanceRemovedSignal(PULSE_TAG):Connect(onPulseTagRemoved)
	startHeartbeat()
end

return Client_UiPulse
