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
local roadCarryingSound: Sound?
local isOnRoad = false
local isCarryingLuckyBlock = false
local roadNearZ = 0
local roadFarZ = 0
local roadBoundsReady = false
local activeFadeTweens: { Tween } = {}
local zoneConnection: RBXScriptConnection?

local function cancelFadeTweens()
	for _, tween in activeFadeTweens do
		tween:Cancel()
	end
	table.clear(activeFadeTweens)
end

local function trackFadeTween(tween: Tween)
	table.insert(activeFadeTweens, tween)
	tween.Completed:Once(function()
		local index = table.find(activeFadeTweens, tween)
		if index then
			table.remove(activeFadeTweens, index)
		end
	end)
	tween:Play()
end

local function getMusicMultiplier(): number
	return Client_AudioSettings.GetMusicVolume()
end

local function createLoopedMusicSound(name: string, soundId: string, volume: number): Sound?
	if type(soundId) ~= "string" or soundId == "" then
		return nil
	end

	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Looped = true
	sound.Volume = volume
	sound.Parent = SoundService
	return sound
end

local function ensureBackgroundSound(): Sound?
	if backgroundSound and backgroundSound.Parent then
		return backgroundSound
	end

	local soundId = Shared_Sounds.Music and Shared_Sounds.Music.Background or ""
	local sound = createLoopedMusicSound("BackgroundMusic", soundId, BACKGROUND_MUSIC_VOLUME)
	backgroundSound = sound
	return sound
end

local function ensureRoadSound(): Sound?
	if roadSound and roadSound.Parent then
		return roadSound
	end

	local soundId = Shared_Sounds.Music and Shared_Sounds.Music.Road or ""
	local sound = createLoopedMusicSound("RoadMusic", soundId, 0)
	roadSound = sound
	return sound
end

local function ensureRoadCarryingSound(): Sound?
	if roadCarryingSound and roadCarryingSound.Parent then
		return roadCarryingSound
	end

	local soundId = Shared_Sounds.Music and Shared_Sounds.Music.RoadCarryingLuckyBlock or ""
	local sound = createLoopedMusicSound("RoadCarryingLuckyBlockMusic", soundId, 0)
	roadCarryingSound = sound
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

local function isPlayerCarryingLuckyBlock(): boolean
	return localPlayer:GetAttribute("CarryingLuckyBlock") == true
end

local function getTargetVolumes(onRoad: boolean, carrying: boolean): (number, number, number)
	local musicMultiplier = getMusicMultiplier()
	if not onRoad then
		return BACKGROUND_MUSIC_VOLUME * musicMultiplier, 0, 0
	end

	if carrying then
		return 0, 0, ROAD_MUSIC_VOLUME * musicMultiplier
	end

	return 0, ROAD_MUSIC_VOLUME * musicMultiplier, 0
end

local function ensureSoundsPlaying(background: Sound, road: Sound, roadCarrying: Sound)
	if not background.IsPlaying then
		background:Play()
	end
	if not road.IsPlaying then
		road:Play()
	end
	if not roadCarrying.IsPlaying then
		roadCarrying:Play()
	end
end

local function stopInactiveRoadSounds(onRoad: boolean, carrying: boolean)
	if onRoad and carrying then
		if roadSound and roadSound.IsPlaying then
			roadSound:Stop()
		end
		return
	end

	if onRoad and not carrying then
		if roadCarryingSound and roadCarryingSound.IsPlaying then
			roadCarryingSound:Stop()
		end
		return
	end

	if roadSound and roadSound.IsPlaying then
		roadSound:Stop()
	end
	if roadCarryingSound and roadCarryingSound.IsPlaying then
		roadCarryingSound:Stop()
	end
end

local function applyImmediateVolumes()
	local background = ensureBackgroundSound()
	local road = ensureRoadSound()
	local roadCarrying = ensureRoadCarryingSound()
	if not background or not road or not roadCarrying then
		return
	end

	local targetBackgroundVolume, targetRoadVolume, targetCarryingVolume =
		getTargetVolumes(isOnRoad, isCarryingLuckyBlock)

	ensureSoundsPlaying(background, road, roadCarrying)

	background.Volume = targetBackgroundVolume
	road.Volume = targetRoadVolume
	roadCarrying.Volume = targetCarryingVolume

	stopInactiveRoadSounds(isOnRoad, isCarryingLuckyBlock)
end

local function scheduleStopInactiveRoadSoundsAfterFade(expectedOnRoad: boolean, expectedCarrying: boolean)
	task.delay(CROSSFADE_DURATION + 0.05, function()
		if isOnRoad ~= expectedOnRoad or isCarryingLuckyBlock ~= expectedCarrying then
			return
		end
		stopInactiveRoadSounds(expectedOnRoad, expectedCarrying)
	end)
end

local function crossfadeMusicState(onRoad: boolean, carrying: boolean)
	local background = ensureBackgroundSound()
	local road = ensureRoadSound()
	local roadCarrying = ensureRoadCarryingSound()
	if not background or not road or not roadCarrying then
		return
	end

	cancelFadeTweens()

	local targetBackgroundVolume, targetRoadVolume, targetCarryingVolume =
		getTargetVolumes(onRoad, carrying)

	ensureSoundsPlaying(background, road, roadCarrying)

	trackFadeTween(TweenService:Create(background, CROSSFADE_TWEEN_INFO, {
		Volume = targetBackgroundVolume,
	}))
	trackFadeTween(TweenService:Create(road, CROSSFADE_TWEEN_INFO, {
		Volume = targetRoadVolume,
	}))
	trackFadeTween(TweenService:Create(roadCarrying, CROSSFADE_TWEEN_INFO, {
		Volume = targetCarryingVolume,
	}))

	scheduleStopInactiveRoadSoundsAfterFade(onRoad, carrying)
end

local function setMusicZoneState(onRoad: boolean, carrying: boolean)
	if onRoad == isOnRoad and carrying == isCarryingLuckyBlock then
		return
	end

	isOnRoad = onRoad
	isCarryingLuckyBlock = carrying
	crossfadeMusicState(onRoad, carrying)
end

local function updateRoadZone()
	if not roadBoundsReady then
		tryInitRoadBounds()
	end
	setMusicZoneState(isPlayerOnRoad(), isPlayerCarryingLuckyBlock())
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
	ensureRoadCarryingSound()

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

	stopInactiveRoadSounds(false, false)
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

	localPlayer:GetAttributeChangedSignal("CarryingLuckyBlock"):Connect(function()
		updateRoadZone()
	end)

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
