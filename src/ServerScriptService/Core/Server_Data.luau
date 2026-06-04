local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProfileStore = require(ReplicatedStorage.Core.ProfileStore)
local ReplicaService = require(script.Parent.ReplicaService)
require(script.Parent.ReplicaServiceListeners)

local Shared_Abbreviation = require(ReplicatedStorage.Modules.Utilities.Shared_Abbreviation)

local DataTemplate = {
	Cash = 0,

	Speed = 16,
	Strength = 1,

	Rebirths = 0,

	-- Inventory: owned items only. Each entry is one item.
	-- ItemType = "Brainrot" | "LuckyBlock" | ... (which config table to use)
	-- ConfigName = string key from Shared_Brainrots / Shared_LuckyBlocks / etc.
	-- Data.Level = brainrot level (and similar per-item stats)
	-- Data.Modifier = variant string e.g. "Normal", "Golden"
	-- Example entry:
	-- {
	--   ItemType = "Brainrot",
	--   ConfigName = "Skibidi",
	--   Data = { Level = 1, Modifier = "Normal" },
	-- }
	Inventory = {},

	-- Total unlocked plot slots. Plot table stores ONLY occupied slots.
	TotalPlotSlots = 10,
	ActivePlotSkin = "Normal",

	-- Plot: keys are occupied slot ids as strings ("2", "8", ...). Missing key = empty slot.
	-- Example when slots 2 and 8 are occupied:
	-- Plot = {
	--   ["2"] = {
	--     CashToCollect = 0,
	--     ConfigName = "Skibidi",
	--     Level = 1,
	--     Modifier = "Normal",
	--   },
	--   ["8"] = {
	--     CashToCollect = 150,
	--     ConfigName = "Tralala",
	--     Level = 3,
	--     Modifier = "Golden",
	--   },
	-- }
	Plot = {},

	-- Index: collection/discovery tracker per modifier. {[Modifier] = {ConfigName, ...}}
	Index = {},

	Music = true,
	SFX = true,
	PopUps = true,

	PurchasesLogs = {},
	DataGamepasses = {},

	TutorialCompleted = false,
}

local Module = {}
Module.Profiles = {}
Module.Replicas = {}

local PlayerStore = ProfileStore.New("RunForBrainrots_v1", DataTemplate)
local ReplicaClassToken = ReplicaService.NewClassToken("PlayerData")

local function getStore()
	if RunService:IsStudio() then
		return PlayerStore.Mock
	end
	return PlayerStore
end

local function getValueByPath(data, path)
	if not data or type(path) ~= "string" then
		return nil
	end

	local current = data
	for _, key in string.split(path, ".") do
		if type(current) ~= "table" then
			return nil
		end
		current = current[key]
	end

	return current
end

local function setValueByPath(data, path, value)
	if not data or type(path) ~= "string" then
		return
	end

	local parts = string.split(path, ".")
	local current = data

	for i = 1, #parts - 1 do
		if type(current[parts[i]]) ~= "table" then
			current[parts[i]] = {}
		end
		current = current[parts[i]]
	end

	current[parts[#parts]] = value
end

function Module:GetProfile(player)
	return self.Profiles[player]
end

function Module:GetReplica(player)
	return self.Replicas[player]
end

function Module:GetData(player)
	local profile = self.Profiles[player]
	return profile and profile.Data or nil
end

function Module:GetValue(player, path)
	return getValueByPath(self:GetData(player), path)
end

function Module:SetValue(player, path, value)
	local data = self:GetData(player)
	if not data then
		return
	end

	local replica = self:GetReplica(player)
	if replica then
		local pathArray = {}
		for part in string.gmatch(path, "[^.]+") do
			table.insert(pathArray, part)
		end
		replica:SetValue(pathArray, value)
	else
		setValueByPath(data, path, value)
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	if path == "Cash" then
		local cash = leaderstats:FindFirstChild("Cash")
		if cash then
			cash.Value = Shared_Abbreviation:Number(value)
		end
	elseif path == "Rebirths" then
		local rebirths = leaderstats:FindFirstChild("Rebirths")
		if rebirths then
			rebirths.Value = value
		end
	end
end

function Module:AddValue(player, path, amount)
	local current = self:GetValue(player, path) or 0
	self:SetValue(player, path, current + amount)
end

function Module:SubValue(player, path, amount)
	local current = self:GetValue(player, path) or 0
	self:SetValue(player, path, math.max(0, current - amount))
end

local function createLeaderstats(player, profile)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Value = Shared_Abbreviation:Number(profile.Data.Cash or 0)
	cash.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = profile.Data.Rebirths or 0
	rebirths.Parent = leaderstats

	local replica = Module.Replicas[player]
	if not replica then
		return
	end

	replica:ListenToChange({ "Cash" }, function(newValue)
		cash.Value = Shared_Abbreviation:Number(newValue)
	end)

	replica:ListenToChange({ "Rebirths" }, function(newValue)
		rebirths.Value = newValue
	end)
end

local function onPlayerAdded(player)
	local store = getStore()
	local profile = store:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		player:Kick("Failed to load data. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		Module.Profiles[player] = nil
		Module.Replicas[player] = nil
		if player.Parent then
			player:Kick("Profile session ended. Please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	Module.Profiles[player] = profile

	local replica = ReplicaService.NewReplica({
		ClassToken = ReplicaClassToken,
		Data = profile.Data,
		Tags = { UserId = player.UserId },
		Replication = player,
	})

	Module.Replicas[player] = replica
	createLeaderstats(player, profile)
end

local function onPlayerRemoving(player)
	local profile = Module.Profiles[player]
	if profile then
		profile:EndSession()
		Module.Profiles[player] = nil
	end

	local replica = Module.Replicas[player]
	if replica then
		replica:Destroy()
		Module.Replicas[player] = nil
	end
end

function Module:Init()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = Module.Profiles[player]
			if profile then
				profile:EndSession()
			end
		end
	end)
end

return Module
