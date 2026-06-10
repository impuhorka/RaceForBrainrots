local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local SoundService = game:GetService("SoundService")
local ClientLoader = require(script.Parent.Parent.Loader)

local Shared_Sounds = SharedModules.require("Shared_Sounds")
local Client_AudioSettings = ClientLoader.require("Client_AudioSettings")
local Client_Data = ClientLoader.require("Client_Data")

local Client_BackgroundMusic = {}

local BACKGROUND_MUSIC_VOLUME = 0.24

local backgroundSound: Sound?

local function ensureSound(): Sound?
	if backgroundSound and backgroundSound.Parent then
		return backgroundSound
	end

	local soundId = Shared_Sounds.Music and Shared_Sounds.Music.Background or ""
	if type(soundId) ~= "string" or soundId == "" then
		return nil
	end

	local sound = Instance.new("Sound")
	sound.Name = "BackgroundMusic"
	sound.SoundId = soundId
	sound.Looped = true
	sound.Volume = BACKGROUND_MUSIC_VOLUME
	sound.Parent = SoundService
	backgroundSound = sound
	return sound
end

local function refreshState()
	local sound = ensureSound()
	if not sound then
		return
	end

	sound.Volume = BACKGROUND_MUSIC_VOLUME * Client_AudioSettings.GetMusicVolume()

	if not sound.IsPlaying then
		sound:Play()
	end
end

function Client_BackgroundMusic.Refresh()
	refreshState()
end

function Client_BackgroundMusic.Init()
	Client_Data.WaitUntilReady()
	refreshState()

	Client_Data:ListenToChange("Music", function()
		refreshState()
	end)
end

return Client_BackgroundMusic