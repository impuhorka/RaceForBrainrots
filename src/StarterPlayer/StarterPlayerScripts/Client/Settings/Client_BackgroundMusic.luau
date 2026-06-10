local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ClientLoader = require(script.Parent.Parent.Loader)

local Shared_Sounds = SharedModules.require("Shared_Sounds")
local Shared_RoadGradient = SharedModules.require("Shared_RoadGradient")
local Client_AudioSettings = ClientLoader.require("Client_AudioSettings")
local Client_Data = ClientLoader.require("Client_Data")

local Client_BackgroundMusic = {}

local localPlayer = Players.LocalPlayer
local BACKGROUND_MUSIC_VOLUME = 0.24
local ROAD_MUSIC_VOLUME = 0.24
local CROSSFADE_DURATION = 0.4
local CROSSFADE_TWEEN_INFO = TweenInfo.new(CROSSFADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local backgroundSound: Sound?
local roadSound: Sound?
local isOnRoad = false
local roadNearZ = 0
local roadFarZ = 0
local roadBoundsReady = false
local backgroundFadeTween: Tween?
local roadFadeTween: Tween?
local zoneConnection: RBXScriptConnection?

local function cancelFadeTweens()
	if backgroundFadeTween then
		backgroundFadeTween:Cancel()
		backgroundFadeTween = nil
	end
	if roadFadeTween then
		roadFadeTween:Cancel()
		roadFadeTween = nil
	end
end

local function getMusicMultiplier(): number
	return Client_AudioSettings.GetMusicVolume()
end

local function ensureBackgroundSound(): Sound?
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

local function ensureRoadSound(): Sound?
	if roadSound and roadSound.Parent then
		return roadSound
	end

	local soundId = Shared_Sounds.Music and Shared_Sounds.Music.Road or ""
	if type(soundId) ~= "string" or soundId == "" then
		return nil
	end

	local sound = Instance.new("Sound")
	sound.Name = "RoadMusic"
	sound.SoundId = soundId
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	roadSound = sound
	return sound
end

local function tryInitRoadBounds(): boolean
	local zones = Workspace:FindFirstChild("Zones")
	local enterPart = zones and zones:FindFirstChild("EnterPart")
	if not enterPart or not enterPart:IsA("BasePart") then
		return false
	end

	if Shared_RoadGradient.GetRoadTotalLength() <= 0 then
		return false
	end

	roadNearZ, roadFarZ = Shared_RoadGradient.GetRoadBounds(enterPart)
	roadBoundsReady = true
	return true
end

local function isPlayerOnRoad(): boolean
	if not roadBoundsReady then
		return false
	end

	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	return Shared_RoadGradient.IsOnRoad(root.Position.Z, roadNearZ, roadFarZ)
end

local function applyImmediateVolumes()
	local background = ensureBackgroundSound()
	local road = ensureRoadSound()
	if not background or not road then
		return
	end

	local musicMultiplier = getMusicMultiplier()
	if isOnRoad then
		background.Volume = 0
		road.Volume = ROAD_MUSIC_VOLUME * musicMultiplier
		if not road.IsPlaying then
			road:Play()
		end
		if not background.IsPlaying then
			background:Play()
		end
	else
		background.Volume = BACKGROUND_MUSIC_VOLUME * musicMultiplier
		road.Volume = 0
		if not background.IsPlaying then
			background:Play()
		end
		if road.IsPlaying then
			road:Stop()
		end
	end
end

local function crossfadeToRoadState(onRoad: boolean)
	local background = ensureBackgroundSound()
	local road = ensureRoadSound()
	if not background or not road then
		return
	end

	cancelFadeTweens()

	local musicMultiplier = getMusicMultiplier()
	local targetBackgroundVolume = if onRoad then 0 else BACKGROUND_MUSIC_VOLUME * musicMultiplier
	local targetRoadVolume = if onRoad then ROAD_MUSIC_VOLUME * musicMultiplier else 0

	if not background.IsPlaying then
		background:Play()
	end

	if onRoad and not road.IsPlaying then
		road:Play()
	end

	backgroundFadeTween = TweenService:Create(background, CROSSFADE_TWEEN_INFO, {
		Volume = targetBackgroundVolume,
	})
	roadFadeTween = TweenService:Create(road, CROSSFADE_TWEEN_INFO, {
		Volume = targetRoadVolume,
	})

	backgroundFadeTween:Play()
	roadFadeTween:Play()

	if not onRoad then
		roadFadeTween.Completed:Once(function(playbackState)
			if playbackState ~= Enum.PlaybackState.Completed or isOnRoad then
				return
			end
			if roadSound and roadSound.IsPlaying then
				roadSound:Stop()
			end
		end)
	end
end

local function setRoadMusicActive(onRoad: boolean)
	if onRoad == isOnRoad then
		return
	end
	isOnRoad = onRoad
	crossfadeToRoadState(onRoad)
end

local function updateRoadZone()
	if not roadBoundsReady then
		tryInitRoadBounds()
	end
	setRoadMusicActive(isPlayerOnRoad())
end

local function refreshState()
	if not Client_Data.IsReady then
		return
	end

	local background = ensureBackgroundSound()
	if not background then
		return
	end

	ensureRoadSound()

	if isOnRoad then
		cancelFadeTweens()
		applyImmediateVolumes()
		return
	end

	cancelFadeTweens()
	background.Volume = BACKGROUND_MUSIC_VOLUME * getMusicMultiplier()
	if not background.IsPlaying then
		background:Play()
	end

	if roadSound then
		roadSound.Volume = 0
		if roadSound.IsPlaying then
			roadSound:Stop()
		end
	end
end

function Client_BackgroundMusic.Refresh()
	refreshState()
end

function Client_BackgroundMusic.Init()
	Client_Data.WaitUntilReady()
	tryInitRoadBounds()

	if not roadBoundsReady then
		task.spawn(function()
			local zones = Workspace:WaitForChild("Zones", 30)
			if zones then
				zones:WaitForChild("EnterPart", 30)
				tryInitRoadBounds()
			end
		end)
	end

	refreshState()

	Client_Data:ListenToChange("Music", function()
		if isOnRoad then
			cancelFadeTweens()
			applyImmediateVolumes()
		else
			refreshState()
		end
	end)

	if zoneConnection then
		zoneConnection:Disconnect()
	end

	zoneConnection = RunService.Heartbeat:Connect(updateRoadZone)
end

return Client_BackgroundMusic
