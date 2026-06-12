local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local SoundService = game:GetService("SoundService")
local ClientLoader = require(script.Parent.Parent.Loader)

local Shared_Sounds = SharedModules.require("Shared_Sounds")
local Client_AudioSettings = ClientLoader.require("Client_AudioSettings")

local Client_SoundPreload = {}
local templatesById: { [string]: Sound } = {}
local pendingLowPriorityId = 0
local lastUiPlayAt = -math.huge
local lastUiPriority = -math.huge
local lastNonLowUiPlayAt = -math.huge

local SAME_ACTION_WINDOW_SECONDS = 0.08
local LOW_PRIORITY_BLOCK_WINDOW_SECONDS = 0.2
local LOW_PRIORITY_DELAY_SECONDS = 0.05

local function collectSoundIds(container: any, results: { string }, seen: { [string]: boolean })
	if type(container) ~= "table" then
		return
	end

	for _, value in container do
		if type(value) == "string" and string.match(value, "^rbxassetid://") then
			if not seen[value] then
				seen[value] = true
				table.insert(results, value)
			end
		elseif type(value) == "table" then
			collectSoundIds(value, results, seen)
		end
	end
end

local function ensureTemplate(soundId: string): Sound
	local existing = templatesById[soundId]
	if existing and existing.Parent then
		return existing
	end

	local template = Instance.new("Sound")
	template.Name = "PreloadedSound_" .. string.gsub(soundId, "[^%w]", "_")
	template.SoundId = soundId
	template.Volume = 1
	template.Parent = SoundService
	templatesById[soundId] = template
	return template
end

function Client_SoundPreload.Init()
	local ids: { string } = {}
	collectSoundIds(Shared_Sounds, ids, {})
	if #ids == 0 then
		return
	end

	local sounds: { Sound } = {}
	for _, id in ids do
		table.insert(sounds, ensureTemplate(id))
	end

	pcall(function()
		ContentProvider:PreloadAsync(sounds)
	end)
end

function Client_SoundPreload.Play(
	soundId: string,
	volume: number?,
	startTime: number?,
	playbackSpeed: number?
)
	if soundId == "" then
		return
	end

	local template = ensureTemplate(soundId)
	local clone = template:Clone()
	local resolvedVolume = (if type(volume) == "number" then volume else 1) * Client_AudioSettings.GetSfxVolume()
	clone.Volume = resolvedVolume
	if type(startTime) == "number" and startTime > 0 then
		clone.TimePosition = startTime
	end
	if type(playbackSpeed) == "number" and playbackSpeed > 0 then
		clone.PlaybackSpeed = playbackSpeed
	end
	clone.Parent = SoundService
	clone:Play()
	clone.Ended:Once(function()
		clone:Destroy()
	end)
end

local function shouldSuppressUiPlay(priority: number): boolean
	local now = os.clock()
	if priority <= 0 and now - lastNonLowUiPlayAt <= LOW_PRIORITY_BLOCK_WINDOW_SECONDS then
		return true
	end
	if now - lastUiPlayAt <= SAME_ACTION_WINDOW_SECONDS and priority <= lastUiPriority then
		return true
	end
	return false
end

local function commitUiPlay(
	soundId: string,
	volume: number?,
	priority: number,
	startTime: number?,
	playbackSpeed: number?
)
	Client_SoundPreload.Play(soundId, volume, startTime, playbackSpeed)
	local now = os.clock()
	lastUiPlayAt = now
	lastUiPriority = priority
	if priority > 0 then
		lastNonLowUiPlayAt = now
	end
end

function Client_SoundPreload.PlayUi(
	soundId: string,
	volume: number?,
	priority: number?,
	startTime: number?,
	playbackSpeed: number?
)
	if soundId == "" then
		return
	end

	volume = (if type(volume) == "number" then volume else 1) * Client_AudioSettings.GetSfxVolume()

	local resolvedPriority = priority or 0
	if resolvedPriority <= 0 then
		pendingLowPriorityId += 1
		local requestId = pendingLowPriorityId
		task.delay(LOW_PRIORITY_DELAY_SECONDS, function()
			if requestId ~= pendingLowPriorityId then
				return
			end
			if shouldSuppressUiPlay(0) then
				return
			end
			commitUiPlay(soundId, volume, 0, startTime, playbackSpeed)
		end)
		return
	end

	-- Higher-priority UI sounds cancel pending low-priority click sounds.
	pendingLowPriorityId += 1
	if shouldSuppressUiPlay(resolvedPriority) then
		return
	end
	commitUiPlay(soundId, volume, resolvedPriority, startTime, playbackSpeed)
end

function Client_SoundPreload.Destroy()
	for _, sound in templatesById do
		if sound.Parent then
			sound:Destroy()
		end
	end
	table.clear(templatesById)
end

return Client_SoundPreload