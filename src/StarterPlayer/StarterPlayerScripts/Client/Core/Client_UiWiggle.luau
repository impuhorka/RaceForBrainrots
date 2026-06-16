local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Client_UiWiggle = {}

local WIGGLE_TAG = "wiggle"
local WIGGLE_ANGLE_ATTRIBUTE = "WiggleAngle"
local WIGGLE_SPEED_ATTRIBUTE = "WiggleSpeed"
local WIGGLE_OVERDRIVE_ATTRIBUTE = "WiggleOverdrive"
local DEFAULT_WIGGLE_ANGLE = 10
local DEFAULT_WIGGLE_SPEED = 14
local DEFAULT_WIGGLE_OVERDRIVE = 1
local WIGGLE_DURATION = 0.45

type WiggleEntry = {
	instance: GuiObject,
	originRotation: number,
	animating: boolean,
	animStartTime: number,
	runId: number,
	mouseEnterConn: RBXScriptConnection?,
}

local wiggles: { [GuiObject]: WiggleEntry } = {}
local ancestryConns: { [GuiObject]: RBXScriptConnection } = {}
local heartbeatConnection: RBXScriptConnection? = nil
local initialized = false

local function parsePositiveNumber(value: any): number?
	if type(value) == "number" and value > 0 then
		return value
	end

	if type(value) == "string" then
		local cleaned = string.gsub(value, "^[xX]", "")
		local parsed = tonumber(cleaned)
		if parsed and parsed > 0 then
			return parsed
		end
	end

	return nil
end

local function getWiggleAngle(instance: GuiObject): number
	return parsePositiveNumber(instance:GetAttribute(WIGGLE_ANGLE_ATTRIBUTE)) or DEFAULT_WIGGLE_ANGLE
end

local function getWiggleSpeed(instance: GuiObject): number
	return parsePositiveNumber(instance:GetAttribute(WIGGLE_SPEED_ATTRIBUTE)) or DEFAULT_WIGGLE_SPEED
end

local function getWiggleOverdrive(instance: GuiObject): number
	return parsePositiveNumber(instance:GetAttribute(WIGGLE_OVERDRIVE_ATTRIBUTE)) or DEFAULT_WIGGLE_OVERDRIVE
end

local function getWiggleDuration(instance: GuiObject): number
	local speed = getWiggleSpeed(instance)
	return WIGGLE_DURATION * (DEFAULT_WIGGLE_SPEED / speed)
end

local function finishWiggle(entry: WiggleEntry)
	entry.animating = false
	if entry.instance.Parent then
		entry.instance.Rotation = entry.originRotation
	end
end

local function hasAnimatingWiggle(): boolean
	for _, entry in wiggles do
		if entry.animating then
			return true
		end
	end
	return false
end

local function stopHeartbeatIfIdle()
	if hasAnimatingWiggle() then
		return
	end

	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end

local function startHeartbeatIfNeeded()
	if heartbeatConnection then
		return
	end

	heartbeatConnection = RunService.Heartbeat:Connect(function()
		if not hasAnimatingWiggle() then
			stopHeartbeatIfIdle()
			return
		end

		local now = os.clock()

		for instance, entry in wiggles do
			if not entry.animating or not instance.Parent then
				continue
			end

			local duration = getWiggleDuration(instance)
			local elapsed = now - entry.animStartTime
			if elapsed >= duration then
				finishWiggle(entry)
				continue
			end

			local progress = elapsed / duration
			local angle = getWiggleAngle(instance) * getWiggleOverdrive(instance)
			instance.Rotation = entry.originRotation + math.sin(progress * math.pi * 2) * angle
		end

		stopHeartbeatIfIdle()
	end)
end

local function playWiggle(entry: WiggleEntry)
	if not entry.animating then
		entry.originRotation = entry.instance.Rotation
	end

	entry.instance.Rotation = entry.originRotation
	entry.animating = true
	entry.animStartTime = os.clock()
	entry.runId += 1

	local runId = entry.runId
	local duration = getWiggleDuration(entry.instance)

	task.delay(duration, function()
		if entry.runId ~= runId or not entry.animating then
			return
		end
		finishWiggle(entry)
		stopHeartbeatIfIdle()
	end)

	startHeartbeatIfNeeded()
end

local function untrackWiggle(instance: GuiObject)
	local entry = wiggles[instance]
	if entry then
		entry.runId += 1
		if entry.mouseEnterConn then
			entry.mouseEnterConn:Disconnect()
		end
		finishWiggle(entry)
	end

	wiggles[instance] = nil

	local ancestryConn = ancestryConns[instance]
	if ancestryConn then
		ancestryConn:Disconnect()
		ancestryConns[instance] = nil
	end

	stopHeartbeatIfIdle()
end

local function trackWiggle(instance: Instance)
	if not instance:IsA("GuiObject") then
		return
	end
	if wiggles[instance] then
		return
	end

	if not instance:IsA("GuiButton") and not instance.Active then
		instance.Active = true
	end

	local entry: WiggleEntry = {
		instance = instance,
		originRotation = instance.Rotation,
		animating = false,
		animStartTime = 0,
		runId = 0,
	}

	entry.mouseEnterConn = instance.MouseEnter:Connect(function()
		playWiggle(entry)
	end)

	wiggles[instance] = entry

	ancestryConns[instance] = instance.AncestryChanged:Connect(function(_, parent)
		if not parent then
			untrackWiggle(instance)
		end
	end)
end

local function onWiggleTagAdded(instance: Instance)
	trackWiggle(instance)
end

local function onWiggleTagRemoved(instance: Instance)
	if instance:IsA("GuiObject") then
		untrackWiggle(instance)
	end
end

function Client_UiWiggle.Init()
	if initialized then
		return
	end
	initialized = true

	for _, instance in CollectionService:GetTagged(WIGGLE_TAG) do
		trackWiggle(instance)
	end

	CollectionService:GetInstanceAddedSignal(WIGGLE_TAG):Connect(onWiggleTagAdded)
	CollectionService:GetInstanceRemovedSignal(WIGGLE_TAG):Connect(onWiggleTagRemoved)
end

return Client_UiWiggle
