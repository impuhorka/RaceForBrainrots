local RunService = game:GetService("RunService")

local ClientLoader = require(script.Parent.Parent.Loader)

local Client_ModelVfx = {}

local VFX_CLASS_NAMES = {
	"ParticleEmitter",
	"Trail",
	"Beam",
	"Fire",
	"Smoke",
	"Sparkles",
	"PointLight",
	"SpotLight",
	"SurfaceLight",
}

local PROXIMITY_REFRESH_INTERVAL = 0.25

local savedEnabled: { [Instance]: boolean } = {}
local descendantConnections: { [Model]: RBXScriptConnection } = {}
local destroyHooked: { [Model]: boolean } = {}
local modelEffectsEnabled: { [Model]: boolean } = {}
local proximityAccumulator = 0
local proximityConnection: RBXScriptConnection?

local function getLocalWorldState()
	return ClientLoader.require("Client_LocalWorldState")
end

local function isVfxInstance(instance: Instance): boolean
	for _, className in VFX_CLASS_NAMES do
		if instance:IsA(className) then
			return true
		end
	end
	return false
end

local function setVfxEnabled(instance: Instance, enabled: boolean)
	if instance:IsA("ParticleEmitter")
		or instance:IsA("Trail")
		or instance:IsA("Beam")
		or instance:IsA("Fire")
		or instance:IsA("Smoke")
		or instance:IsA("Sparkles")
	then
		instance.Enabled = enabled
	elseif instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight") then
		instance.Enabled = enabled
	end
end

local function clearSavedStatesForModel(model: Model)
	for _, descendant in model:GetDescendants() do
		savedEnabled[descendant] = nil
	end
end

local function resolveEffectsEnabled(model: Model, settingsEnabled: boolean): boolean
	if not settingsEnabled then
		return false
	end

	return getLocalWorldState().IsWithinEffectsRange(model:GetPivot().Position)
end

local function applyVfxInstance(instance: Instance, effectsEnabled: boolean)
	if not isVfxInstance(instance) then
		return
	end

	if effectsEnabled then
		local saved = savedEnabled[instance]
		if saved ~= nil then
			setVfxEnabled(instance, saved)
			savedEnabled[instance] = nil
		end
		return
	end

	if savedEnabled[instance] == nil then
		if instance:IsA("ParticleEmitter")
			or instance:IsA("Trail")
			or instance:IsA("Beam")
			or instance:IsA("Fire")
			or instance:IsA("Smoke")
			or instance:IsA("Sparkles")
		then
			savedEnabled[instance] = instance.Enabled
		elseif instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight") then
			savedEnabled[instance] = instance.Enabled
		end
	end

	setVfxEnabled(instance, false)
end

local function refreshTrackedProximity()
	for model, settingsEnabled in modelEffectsEnabled do
		if model.Parent then
			Client_ModelVfx.ApplyToModel(model, settingsEnabled == true)
		end
	end
end

local function ensureProximityLoop()
	if proximityConnection then
		return
	end

	proximityConnection = RunService.Heartbeat:Connect(function(dt)
		if next(modelEffectsEnabled) == nil then
			return
		end

		proximityAccumulator += dt
		if proximityAccumulator < PROXIMITY_REFRESH_INTERVAL then
			return
		end

		proximityAccumulator = 0
		refreshTrackedProximity()
	end)
end

function Client_ModelVfx.ApplyToModel(model: Model, settingsEnabled: boolean)
	if descendantConnections[model] then
		modelEffectsEnabled[model] = settingsEnabled
	end

	local effectsEnabled = resolveEffectsEnabled(model, settingsEnabled)
	for _, descendant in model:GetDescendants() do
		applyVfxInstance(descendant, effectsEnabled)
	end
end

function Client_ModelVfx.TrackModel(model: Model, settingsEnabled: boolean)
	modelEffectsEnabled[model] = settingsEnabled
	Client_ModelVfx.ApplyToModel(model, settingsEnabled)
	ensureProximityLoop()

	local existingConnection = descendantConnections[model]
	if existingConnection then
		existingConnection:Disconnect()
	end

	descendantConnections[model] = model.DescendantAdded:Connect(function(descendant)
		local enabled = resolveEffectsEnabled(model, modelEffectsEnabled[model] == true)
		applyVfxInstance(descendant, enabled)
	end)

	if not destroyHooked[model] then
		destroyHooked[model] = true
		model.Destroying:Once(function()
			local connection = descendantConnections[model]
			if connection then
				connection:Disconnect()
				descendantConnections[model] = nil
			end
			destroyHooked[model] = nil
			modelEffectsEnabled[model] = nil
			clearSavedStatesForModel(model)
		end)
	end
end

function Client_ModelVfx.UntrackModel(model: Model)
	local connection = descendantConnections[model]
	if connection then
		connection:Disconnect()
		descendantConnections[model] = nil
	end
	modelEffectsEnabled[model] = nil
	clearSavedStatesForModel(model)
end

return Client_ModelVfx
