local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared_Sounds = require(ReplicatedStorage.Modules.Shared_Sounds)
local Client_Data = require(script.Parent.Client_Data)

local Client_BackgroundMusic = {}

local BACKGROUND_MUSIC_VOLUME = 0.12

local backgroundSound: Sound?

local function shouldPlayMusic(): boolean
	local musicEnabled = Client_Data:GetValue("Music")
	if musicEnabled == nil then
		return true
	end
	return musicEnabled == true
end

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

	if shouldPlayMusic() then
		if not sound.IsPlaying then
			sound:Play()
		end
	else
		if sound.IsPlaying then
			sound:Pause()
		end
	end
end

function Client_BackgroundMusic.Init()
	Client_Data.WaitUntilReady()
	refreshState()

	Client_Data:ListenToChange("Music", function()
		refreshState()
	end)
end

return Client_BackgroundMusic
