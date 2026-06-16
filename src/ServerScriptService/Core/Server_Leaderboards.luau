local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Server_Data = require(ServerScriptService.Core.Server_Data)
local Shared_Abbreviation = SharedModules.require("Shared_Abbreviation")
local Shared_Leaderboards = SharedModules.require("Shared_Leaderboards")

local Server_Leaderboards = {}

local USE_MOCK_IN_STUDIO = false
local SUBMIT_COOLDOWN_SECONDS = 10

local leaderboardHandler: RemoteEvent? = nil
local orderedStores: { [string]: OrderedDataStore } = {}
local cachedSnapshot: { [string]: { any } } = {}
local nameCache: { [number]: string } = {}
local lastSubmitAt: { [Player]: number } = {}
local initialized = false

local function getOrderedStore(boardId: string): OrderedDataStore?
	local config = Shared_Leaderboards.BoardConfig[boardId]
	if not config then
		return nil
	end

	local cached = orderedStores[boardId]
	if cached then
		return cached
	end

	if RunService:IsStudio() and USE_MOCK_IN_STUDIO then
		return nil
	end

	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(config.orderedStoreName)
	end)
	if ok and store then
		orderedStores[boardId] = store
		return store
	end

	warn(`[Server_Leaderboards] Failed to open OrderedDataStore for {boardId}`)
	return nil
end

local function getDisplayName(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end

	local onlinePlayer = Players:GetPlayerByUserId(userId)
	if onlinePlayer then
		nameCache[userId] = onlinePlayer.DisplayName
		return onlinePlayer.DisplayName
	end

	local ok, username = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and type(username) == "string" and username ~= "" then
		nameCache[userId] = username
		return username
	end

	return `Player {userId}`
end

local function formatDisplayValue(boardId: string, value: number): string
	if boardId == Shared_Leaderboards.BoardIds.MaxSpeed then
		return (`%d Speed`):format(math.floor(value))
	end
	return ("$%s"):format(Shared_Abbreviation:Number(value))
end

local function getScoreForBoard(boardId: string, player: Player): number
	if boardId == Shared_Leaderboards.BoardIds.MaxSpeed then
		return math.max(0, math.floor(Server_Data:GetValue(player, "MaxSpeedRecorded") or 0))
	end
	return math.max(0, math.floor(Server_Data:GetValue(player, "TotalCashEarned") or 0))
end

local function buildEntry(boardId: string, place: number, userId: number, value: number)
	return {
		place = place,
		userId = userId,
		name = getDisplayName(userId),
		value = value,
		displayValue = formatDisplayValue(boardId, value),
	}
end

local function buildMockBoard(boardId: string): { any }
	local rows: { { userId: number, value: number } } = {}

	for player, profile in Server_Data.Profiles do
		if player.Parent == Players and profile and profile.Data then
			local value = 0
			if boardId == Shared_Leaderboards.BoardIds.MaxSpeed then
				value = math.max(0, math.floor(profile.Data.MaxSpeedRecorded or profile.Data.Speed or 0))
			else
				value = math.max(0, math.floor(profile.Data.TotalCashEarned or 0))
			end
			if value > 0 then
				table.insert(rows, { userId = player.UserId, value = value })
			end
		end
	end

	table.sort(rows, function(a, b)
		if a.value == b.value then
			return a.userId < b.userId
		end
		return a.value > b.value
	end)

	local entries: { any } = {}
	local limit = math.min(Shared_Leaderboards.EntryCount, #rows)
	for index = 1, limit do
		local row = rows[index]
		table.insert(entries, buildEntry(boardId, index, row.userId, row.value))
	end
	return entries
end

local function fetchBoard(boardId: string): { any }
	local store = getOrderedStore(boardId)
	if not store then
		return buildMockBoard(boardId)
	end

	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, Shared_Leaderboards.EntryCount)
	end)
	if not ok or not pages then
		warn(`[Server_Leaderboards] Failed to fetch {boardId}`)
		return cachedSnapshot[boardId] or {}
	end

	local pageEntries = pages:GetCurrentPage()
	local entries: { any } = {}
	for _, item in pageEntries do
		local userId = tonumber(item.key)
		local storedValue = tonumber(item.value)
		if not userId or not storedValue or storedValue < 1 then
			continue
		end

		local displayValue = storedValue
		local onlinePlayer = Players:GetPlayerByUserId(userId)
		if onlinePlayer then
			local liveScore = getScoreForBoard(boardId, onlinePlayer)
			if liveScore >= 1 then
				displayValue = liveScore
			end
		end

		if displayValue < 1 then
			continue
		end

		table.insert(entries, buildEntry(boardId, #entries + 1, userId, displayValue))
	end

	return entries
end

local function refreshSnapshot()
	for boardId in Shared_Leaderboards.BoardConfig do
		cachedSnapshot[boardId] = fetchBoard(boardId)
	end
end

local function sendSnapshotToPlayer(player: Player)
	if not leaderboardHandler then
		return
	end
	leaderboardHandler:FireClient(player, "Update", cachedSnapshot)
end

local function broadcastSnapshot()
	if not leaderboardHandler then
		return
	end
	leaderboardHandler:FireAllClients("Update", cachedSnapshot)
end

function Server_Leaderboards.SubmitPlayer(player: Player)
	if not player.Parent then
		return
	end

	local now = os.clock()
	local lastSubmit = lastSubmitAt[player] or 0
	if now - lastSubmit < SUBMIT_COOLDOWN_SECONDS then
		return
	end
	lastSubmitAt[player] = now

	for boardId in Shared_Leaderboards.BoardConfig do
		local store = getOrderedStore(boardId)
		if not store then
			continue
		end

		local score = getScoreForBoard(boardId, player)
		local key = tostring(player.UserId)

		if score < 1 then
			pcall(function()
				store:RemoveAsync(key)
			end)
			continue
		end

		pcall(function()
			store:SetAsync(key, score)
		end)
	end
end

local function waitForProfile(player: Player): boolean
	for _ = 1, 100 do
		if Server_Data:GetProfile(player) then
			return true
		end
		if not player.Parent then
			return false
		end
		task.wait(0.1)
	end
	return false
end

local function onPlayerAdded(player: Player)
	task.spawn(function()
		if not waitForProfile(player) then
			return
		end

		sendSnapshotToPlayer(player)
		Server_Leaderboards.SubmitPlayer(player)
	end)
end

local function onPlayerRemoving(player: Player)
	lastSubmitAt[player] = nil
end

function Server_Leaderboards.Init()
	if initialized then
		return
	end
	initialized = true

	local events = ReplicatedStorage:WaitForChild("Events")
	leaderboardHandler = events:WaitForChild("LeaderboardHandler") :: RemoteEvent

	Server_Data.OnLeaderboardStatChanged = function(player: Player)
		Server_Leaderboards.SubmitPlayer(player)
	end

	refreshSnapshot()
	broadcastSnapshot()

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	task.spawn(function()
		while true do
			task.wait(Shared_Leaderboards.UpdateIntervalSeconds)
			refreshSnapshot()
			broadcastSnapshot()
		end
	end)
end

return Server_Leaderboards
