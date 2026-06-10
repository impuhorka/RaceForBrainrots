local ClientLoader = require(script.Parent.Parent.Loader)
local Client_Data = ClientLoader.require("Client_Data")

local Client_AudioSettings = {}

local previewVolumes: { [string]: number } = {}

local function resolveVolume(value: any): number
	if type(value) == "number" then
		return math.clamp(value, 0, 1)
	end
	if value == false then
		return 0
	end
	return 1
end

local function getVolume(key: string): number
	local preview = previewVolumes[key]
	if preview ~= nil then
		return preview
	end
	return resolveVolume(Client_Data:GetValue(key))
end

function Client_AudioSettings.SetPreviewVolume(key: string, volume: number)
	previewVolumes[key] = math.clamp(volume, 0, 1)
end

function Client_AudioSettings.ClearPreviewVolume(key: string)
	previewVolumes[key] = nil
end

function Client_AudioSettings.GetMusicVolume(): number
	return getVolume("Music")
end

function Client_AudioSettings.GetSfxVolume(): number
	return getVolume("SFX")
end

return Client_AudioSettings