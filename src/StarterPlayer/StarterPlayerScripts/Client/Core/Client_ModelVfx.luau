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

local savedEnabled: { [Instance]: boolean } = {}
local descendantConnections: { [Model]: RBXScriptConnection } = {}
local destroyHooked: { [Model]: boolean } = {}
local modelEffectsEnabled: { [Model]: boolean } = {}

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

function Client_ModelVfx.ApplyToModel(model: Model, effectsEnabled: boolean)
	if descendantConnections[model] then
		modelEffectsEnabled[model] = effectsEnabled
	end

	for _, descendant in model:GetDescendants() do
		applyVfxInstance(descendant, effectsEnabled)
	end
end

function Client_ModelVfx.TrackModel(model: Model, effectsEnabled: boolean)
	modelEffectsEnabled[model] = effectsEnabled
	Client_ModelVfx.ApplyToModel(model, effectsEnabled)

	local existingConnection = descendantConnections[model]
	if existingConnection then
		existingConnection:Disconnect()
	end

	descendantConnections[model] = model.DescendantAdded:Connect(function(descendant)
		local enabled = modelEffectsEnabled[model] == true
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
