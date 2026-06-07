--[[
	Shared ProximityPrompt styling (from RedLight).
	Use Shared_ProximityPrompt.Create(parent, { Preset = "PickUp", ... }) for all game prompts.
]]

export type PresetName = "PickUp" | "PickUpWorld" | "Place" | "Sell" | "Steal" | "Gift"

export type CreateOptions = {
	Preset: PresetName?,
	Name: string?,
	ActionText: string?,
	ObjectText: string?,
	Style: Enum.ProximityPromptStyle?,
	RequiresLineOfSight: boolean?,
	HoldDuration: number?,
	MaxActivationDistance: number?,
	UIOffset: Vector2?,
	KeyboardKeyCode: Enum.KeyCode?,
	GamepadKeyCode: Enum.KeyCode?,
	ClickablePrompt: boolean?,
	Enabled: boolean?,
	ReplaceExisting: boolean?,
}

local PRESETS: { [PresetName]: { [string]: any } } = {
	PickUp = {
		Name = "PickUpPrompt",
		ActionText = "Pick Up",
		RequiresLineOfSight = false,
		HoldDuration = 2,
		MaxActivationDistance = 10,
		UIOffset = Vector2.new(0, -10),
	},
	PickUpWorld = {
		Name = "PickUpPrompt",
		ActionText = "Pick Up",
		ObjectText = "",
		RequiresLineOfSight = false,
		HoldDuration = 0.5,
		MaxActivationDistance = 6,
	},
	Place = {
		Name = "PlaceBrainrotPrompt",
		ActionText = "Place Here",
		RequiresLineOfSight = false,
		HoldDuration = 0.5,
		MaxActivationDistance = 10,
	},
	Sell = {
		Name = "SellBrainrotPrompt",
		ActionText = "Sell",
		RequiresLineOfSight = false,
		HoldDuration = 0.5,
		MaxActivationDistance = 10,
		UIOffset = Vector2.new(0, 70),
		KeyboardKeyCode = Enum.KeyCode.F,
		GamepadKeyCode = Enum.KeyCode.ButtonX,
	},
	Steal = {
		Name = "StealBrainrotPrompt",
		ActionText = "Steal Brainrot!",
		RequiresLineOfSight = false,
		HoldDuration = 0.5,
		MaxActivationDistance = 10,
	},
	Gift = {
		Name = "GiftBrainrotPrompt",
		ActionText = "Gift",
		RequiresLineOfSight = false,
		HoldDuration = 0.75,
		MaxActivationDistance = 10,
	},
}

local APPLY_KEYS = {
	"ActionText",
	"ObjectText",
	"Style",
	"RequiresLineOfSight",
	"HoldDuration",
	"MaxActivationDistance",
	"UIOffset",
	"KeyboardKeyCode",
	"GamepadKeyCode",
	"ClickablePrompt",
	"Enabled",
}

local Shared_ProximityPrompt = {}

function Shared_ProximityPrompt.GetPreset(preset: PresetName): { [string]: any }
	return PRESETS[preset]
end

local function resolveConfig(options: CreateOptions): { [string]: any }
	local config: { [string]: any } = {}

	if options.Preset then
		local preset = PRESETS[options.Preset]
		if preset then
			for key, value in preset do
				config[key] = value
			end
		end
	end

	for _, key in APPLY_KEYS do
		local value = options[key]
		if value ~= nil then
			config[key] = value
		end
	end

	if options.Name then
		config.Name = options.Name
	end

	if config.Style == nil then
		config.Style = Enum.ProximityPromptStyle.Custom
	end

	if config.ClickablePrompt == nil then
		config.ClickablePrompt = true
	end

	return config
end

function Shared_ProximityPrompt.Apply(prompt: ProximityPrompt, options: CreateOptions)
	local config = resolveConfig(options)

	for _, key in APPLY_KEYS do
		local value = config[key]
		if value ~= nil then
			(prompt :: any)[key] = value
		end
	end

	if config.Name then
		prompt.Name = config.Name
	end
end

function Shared_ProximityPrompt.Create(parent: Instance, options: CreateOptions?): ProximityPrompt
	options = options or {}

	local config = resolveConfig(options)
	local promptName = config.Name or "ProximityPrompt"

	if options.ReplaceExisting ~= false then
		local existing = parent:FindFirstChild(promptName)
		if existing then
			existing:Destroy()
		end
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = promptName
	prompt.Parent = parent

	Shared_ProximityPrompt.Apply(prompt, options)

	return prompt
end

return Shared_ProximityPrompt
