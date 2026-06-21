local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local RunService = game:GetService("RunService")

local ProfileStore = require(ReplicatedStorage.Core.ProfileStore)
local ReplicaService = require(script.Parent.ReplicaService)
require(script.Parent.ReplicaServiceListeners)

local Shared_Abbreviation = SharedModules.require("Shared_Abbreviation")
local Shared_Brainrots = SharedModules.require("Shared_Brainrots")
local Shared_Carry = SharedModules.require("Shared_Carry")
local Shared_DataConfig = SharedModules.require("Shared_DataConfig")
local Shared_LuckyBlocks = SharedModules.require("Shared_LuckyBlocks")
local Shared_Marketplace = SharedModules.require("Shared_Marketplace")
local Shared_Modifiers = SharedModules.require("Shared_Modifiers")
local Shared_SpeedStore = SharedModules.require("Shared_SpeedStore")
local Shared_StrengthStore = SharedModules.require("Shared_StrengthStore")
local Shared_Rebirth = SharedModules.require("Shared_Rebirth")
local Shared_Weight = SharedModules.require("Shared_Weight")

local Module = {}
Module.Profiles = {}
Module.Replicas = {}
Module.OnLeaderboardStatChanged = nil

local DEFAULT_WALK_SPEED = Shared_SpeedStore.DefaultSpeed

local function resolveMaxSpeed(rawSpeed: any): number
	local speed = tonumber(rawSpeed) or DEFAULT_WALK_SPEED
	return math.max(1, math.floor(speed))
end

local function notifyLeaderboardStats(player: Player)
	if Module.OnLeaderboardStatChanged then
		task.defer(Module.OnLeaderboardStatChanged, player)
	end
end

local function reconcileLeaderboardStats(data: { [string]: any })
	local speed = resolveMaxSpeed(data.Speed)
	data.MaxSpeedRecorded = math.max(math.floor(tonumber(data.MaxSpeedRecorded) or 0), speed)
	data.TotalCashEarned = math.max(0, math.floor(tonumber(data.TotalCashEarned) or 0))
end

local function reconcileFreeStrength(data: { [string]: any })
	if Shared_Rebirth.GetRebirthCount(data.Rebirths) > 0 then
		data.FreeStrengthPointsUsed = Shared_StrengthStore.FreeStrengthPoints
		return
	end

	local used = math.clamp(math.floor(tonumber(data.FreeStrengthPointsUsed) or 0), 0, Shared_StrengthStore.FreeStrengthPoints)
	data.FreeStrengthPointsUsed = used

	local strength = math.max(Shared_StrengthStore.DefaultValue, math.floor(tonumber(data.Strength) or Shared_StrengthStore.DefaultValue))
	local freeThreshold = Shared_StrengthStore.DefaultValue + Shared_StrengthStore.FreeStrengthPoints
	if strength >= freeThreshold and used < Shared_StrengthStore.FreeStrengthPoints then
		data.FreeStrengthPointsUsed = Shared_StrengthStore.FreeStrengthPoints
	end
end

local function updateMaxSpeedRecorded(player: Player, speedValue: any)
	local data = Module:GetData(player)
	if not data then
		return
	end

	local speed = resolveMaxSpeed(speedValue)
	local recorded = math.max(0, math.floor(tonumber(data.MaxSpeedRecorded) or 0))
	if speed <= recorded then
		return
	end

	data.MaxSpeedRecorded = speed
	local replica = Module:GetReplica(player)
	if replica then
		replica:SetValue({ "MaxSpeedRecorded" }, speed)
	end
	notifyLeaderboardStats(player)
end

local function addTotalCashEarned(player: Player, amount: number)
	if amount <= 0 then
		return
	end

	local data = Module:GetData(player)
	if not data then
		return
	end

	local earned = math.max(0, math.floor(tonumber(data.TotalCashEarned) or 0)) + math.floor(amount)
	data.TotalCashEarned = earned

	local replica = Module:GetReplica(player)
	if replica then
		replica:SetValue({ "TotalCashEarned" }, earned)
	end
	notifyLeaderboardStats(player)
end

local DataTemplate = {
	Cash = 0,

	Speed = Shared_SpeedStore.DefaultSpeed,
	Strength = 1,
	FreeStrengthPointsUsed = 0,
	MaxSpeedRecorded = Shared_SpeedStore.DefaultSpeed,
	TotalCashEarned = 0,

	Rebirths = 0,

	-- Inventory: owned items only. Each entry is one item.
	-- ItemType = "Brainrot" | "LuckyBlock" | ... (which config table to use)
	-- ConfigName = string key from Shared_Brainrots / Shared_LuckyBlocks / etc.
	-- Data.Level = brainrot level (and similar per-item stats)
	-- Data.Modifier = variant string e.g. "Normal", "Golden"
	-- Data.BaseWeight / Data.Weight = lucky block origin weight and rolled brainrot weight (kg)
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

	Music = 1,
	SFX = 1,
	Animations = true,
	VisualEffects = true,
	PopUps = true,
	SlowMode = false,

	PurchasesLogs = {},
	DataGamepasses = {},

	TutorialCompleted = false,

	LastLeaveTime = 0,
	PendingOfflineCash = 0,
	PendingOfflineSeconds = 0,
}

local USE_MOCK_DATASTORE_IN_STUDIO = false
local INVENTORY_MAX_SLOTS = 60
local SLOW_MODE_SPEED_CAP = 50

local function resolveSlowModeEnabled(rawSlowMode: any): boolean
	return rawSlowMode == true
end

local function getPlayerStrength(player: Player): number
	local profile = Module.Profiles[player]
	if profile then
		return math.max(1, math.floor(tonumber(profile.Data.Strength) or 1))
	end

	local replica = Module.Replicas[player]
	if replica and type(replica.Data) == "table" then
		return math.max(1, math.floor(tonumber(replica.Data.Strength) or 1))
	end

	return 1
end

local function resolveAppliedWalkSpeed(player: Player, rawMaxSpeed: any, rawSlowMode: any): number
	local maxSpeed = resolveMaxSpeed(rawMaxSpeed)
	if resolveSlowModeEnabled(rawSlowMode) then
		maxSpeed = math.min(maxSpeed, SLOW_MODE_SPEED_CAP)
	end

	local carryWeight = player:GetAttribute("CarriedLuckyBlockWeight")
	if type(carryWeight) == "number" and carryWeight > 0 then
		local strength = getPlayerStrength(player)
		return Shared_Carry.GetCarryWalkSpeed(maxSpeed, carryWeight, strength, maxSpeed)
	end

	return maxSpeed
end

local function applyWalkSpeedToCharacter(character: Model, player: Player, maxSpeed: any, slowMode: any)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.WalkSpeed = resolveAppliedWalkSpeed(player, maxSpeed, slowMode)
	end
end

local function applyWalkSpeed(player: Player, maxSpeed: any, slowMode: any)
	local character = player.Character
	if not character then
		return
	end
	applyWalkSpeedToCharacter(character, player, maxSpeed, slowMode)
end

local PlayerStore = ProfileStore.New(Shared_DataConfig.PlayerStoreName, DataTemplate)
local ReplicaClassToken = ReplicaService.NewClassToken("PlayerData")

local function getStore()
	if RunService:IsStudio() and USE_MOCK_DATASTORE_IN_STUDIO then
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

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, nestedValue in value do
		copy[key] = deepCopy(nestedValue)
	end
	return copy
end

local function addBrainrotToIndex(data: { [string]: any }, item: any): boolean
	if not item or item.ItemType ~= "Brainrot" or type(item.ConfigName) ~= "string" then
		return false
	end

	if not Shared_Brainrots.Data[item.ConfigName] then
		return false
	end

	local modifier = if type(item.Data) == "table" and type(item.Data.Modifier) == "string" and item.Data.Modifier ~= ""
		then item.Data.Modifier
		else "Normal"

	if type(data.Index) ~= "table" then
		data.Index = {}
	end

	local modifierEntries = data.Index[modifier]
	if type(modifierEntries) ~= "table" then
		modifierEntries = {}
		data.Index[modifier] = modifierEntries
	end

	for _, configName in modifierEntries do
		if configName == item.ConfigName then
			return false
		end
	end

	table.insert(modifierEntries, item.ConfigName)
	return true
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

function Module:RefreshWalkSpeed(player: Player)
	applyWalkSpeed(player, self:GetValue(player, "Speed"), self:GetValue(player, "SlowMode"))
end

function Module:GetExpectedWalkSpeed(player: Player): number
	return resolveAppliedWalkSpeed(player, self:GetValue(player, "Speed"), self:GetValue(player, "SlowMode"))
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
		if path == "Speed" then
			updateMaxSpeedRecorded(player, value)
		end
		return
	end

	setValueByPath(data, path, value)

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	if path == "Cash" then
		local cash = leaderstats:FindFirstChild("Cash")
		if cash then
			cash.Value = Shared_Abbreviation:Number(value)
		end
	elseif path == "Speed" then
		local speed = leaderstats:FindFirstChild("Speed")
		if speed and speed:IsA("IntValue") then
			speed.Value = math.max(1, math.floor(tonumber(value) or 1))
		end
		updateMaxSpeedRecorded(player, value)
	elseif path == "Strength" then
		local strength = leaderstats:FindFirstChild("Strength")
		if strength and strength:IsA("IntValue") then
			strength.Value = math.max(1, math.floor(tonumber(value) or 1))
		end
	end
end

function Module:AddValue(player, path, amount)
	local safeAmount = tonumber(amount) or 0
	local current = self:GetValue(player, path) or 0
	self:SetValue(player, path, current + safeAmount)

	if path == "Cash" and safeAmount > 0 then
		addTotalCashEarned(player, safeAmount)
	end
end

function Module:SubValue(player, path, amount)
	local current = self:GetValue(player, path) or 0
	self:SetValue(player, path, math.max(0, current - amount))
end

function Module:SetInventory(player: Player, inventory: { any })
	local data = self:GetData(player)
	if not data then
		return false
	end

	data.Inventory = inventory

	local replica = self:GetReplica(player)
	if replica then
		replica:SetValue({ "Inventory" }, inventory)
	end

	return true
end

function Module:RemoveInventoryAt(player: Player, index: number): any?
	local data = self:GetData(player)
	if not data then
		return nil
	end

	local inventory = data.Inventory
	if type(inventory) ~= "table" or not inventory[index] then
		return nil
	end

	local item = inventory[index]
	table.remove(inventory, index)

	local replica = self:GetReplica(player)
	if replica then
		replica:SetValue({ "Inventory" }, inventory)
	end

	return item
end

function Module:SetPlotSlot(player: Player, slotId: number, slotData: any)
	local data = self:GetData(player)
	if not data then
		return false
	end

	if type(data.Plot) ~= "table" then
		data.Plot = {}
	end

	local replica = self:GetReplica(player)
	if replica then
		replica:SetValues({ "Plot" }, { [tostring(slotId)] = slotData })
	else
		data.Plot[tostring(slotId)] = slotData
	end

	return true
end

function Module:RemovePlotSlot(player: Player, slotId: number): boolean
	local data = self:GetData(player)
	if not data or type(data.Plot) ~= "table" then
		return false
	end

	data.Plot[tostring(slotId)] = nil

	local replica = self:GetReplica(player)
	if replica then
		replica:SetValue({ "Plot", tostring(slotId) }, nil)
	end

	return true
end

local function normalizeInventoryItem(item: any, weightLuckMultiplier: number?)
	if type(item) ~= "table" or type(item.ConfigName) ~= "string" then
		return
	end

	item.Data = if type(item.Data) == "table" then item.Data else {}
	local luckMultiplier = math.max(1, tonumber(weightLuckMultiplier) or 1)

	if item.ItemType == "LuckyBlock" then
		if type(item.Data.BaseWeight) ~= "number" then
			item.Data.BaseWeight = Shared_LuckyBlocks.GetBaseWeight(item.ConfigName)
		end
		if type(item.Data.Weight) ~= "number" then
			if Shared_LuckyBlocks.IsDonateBlock(item.ConfigName) then
				item.Data.Weight = Shared_Weight.RollWeight(item.Data.BaseWeight, luckMultiplier)
			else
				local config = Shared_LuckyBlocks.Data[item.ConfigName]
				local rarity = if config and type(config.Rarity) == "string" then config.Rarity else "Common"
				item.Data.Weight =
					Shared_Weight.RollLuckyBlockWeight(item.Data.BaseWeight, rarity, luckMultiplier)
			end
		end
		return
	end

	if item.ItemType == "Brainrot" then
		local baseWeight, rolledWeight = Shared_Weight.ResolveBrainrotWeights(item.Data, item.ConfigName)
		if type(item.Data.Weight) ~= "number" then
			local config = Shared_Brainrots.Data[item.ConfigName]
			local rarity = config and config.Rarity
			if type(rarity) == "string" then
				rolledWeight = Shared_Weight.RollLuckyBlockWeight(baseWeight, rarity, luckMultiplier)
			else
				rolledWeight = Shared_Weight.RollWeight(baseWeight, luckMultiplier)
			end
		end
		item.Data.BaseWeight = baseWeight
		item.Data.Weight = rolledWeight
	end
end

local function migrateInventoryWeights(profile)
	local inventory = profile.Data.Inventory
	if type(inventory) ~= "table" then
		return
	end

	for _, item in inventory do
		normalizeInventoryItem(item)
	end
end

local function isValidInventoryItem(item: any): boolean
	if type(item) ~= "table" or type(item.ConfigName) ~= "string" or item.ConfigName == "" then
		return false
	end

	if item.ItemType == "Brainrot" then
		return Shared_Brainrots.Data[item.ConfigName] ~= nil
	end

	if item.ItemType == "LuckyBlock" then
		return Shared_LuckyBlocks.Data[item.ConfigName] ~= nil
	end

	return false
end

local function sanitizeInventory(data: { [string]: any })
	if type(data.Inventory) ~= "table" then
		data.Inventory = {}
		return
	end

	local cleaned: { any } = {}
	for _, item in data.Inventory do
		if isValidInventoryItem(item) then
			table.insert(cleaned, item)
		end
	end

	data.Inventory = cleaned
end

local function sanitizePlot(data: { [string]: any })
	if type(data.Plot) ~= "table" then
		data.Plot = {}
		return
	end

	for slotId, slotData in data.Plot do
		if
			type(slotData) ~= "table"
			or type(slotData.ConfigName) ~= "string"
			or not Shared_Brainrots.Data[slotData.ConfigName]
		then
			data.Plot[slotId] = nil
			continue
		end

		slotData.CashToCollect = math.max(0, math.floor(tonumber(slotData.CashToCollect) or 0))
		slotData.Level = math.max(1, math.floor(tonumber(slotData.Level) or 1))

		local modifier = slotData.Modifier
		if type(modifier) ~= "string" or not Shared_Modifiers.Data[modifier] then
			slotData.Modifier = "Normal"
		end
	end
end

local function sanitizeIndex(data: { [string]: any })
	if type(data.Index) ~= "table" then
		data.Index = {}
		return
	end

	for modifier, entries in data.Index do
		if type(modifier) ~= "string" or not Shared_Modifiers.Data[modifier] then
			data.Index[modifier] = nil
			continue
		end

		if type(entries) ~= "table" then
			data.Index[modifier] = {}
			continue
		end

		local cleaned: { string } = {}
		local seen: { [string]: boolean } = {}
		for _, configName in entries do
			if type(configName) == "string" and Shared_Brainrots.Data[configName] and not seen[configName] then
				seen[configName] = true
				table.insert(cleaned, configName)
			end
		end

		data.Index[modifier] = cleaned
	end
end

local function sanitizeScalars(data: { [string]: any })
	data.Cash = math.max(0, math.floor(tonumber(data.Cash) or 0))
	data.Speed = resolveMaxSpeed(data.Speed)
	data.Strength = math.max(Shared_StrengthStore.DefaultValue, math.floor(tonumber(data.Strength) or 1))
	data.Rebirths = math.max(0, math.floor(tonumber(data.Rebirths) or 0))
	data.TotalPlotSlots = math.max(1, math.floor(tonumber(data.TotalPlotSlots) or DataTemplate.TotalPlotSlots))
	data.PendingOfflineCash = math.max(0, math.floor(tonumber(data.PendingOfflineCash) or 0))
	data.PendingOfflineSeconds = math.max(0, math.floor(tonumber(data.PendingOfflineSeconds) or 0))
	data.LastLeaveTime = math.max(0, math.floor(tonumber(data.LastLeaveTime) or 0))
	data.Music = math.clamp(tonumber(data.Music) or 1, 0, 1)
	data.SFX = math.clamp(tonumber(data.SFX) or 1, 0, 1)
	data.Animations = data.Animations ~= false
	data.VisualEffects = data.VisualEffects ~= false
	data.PopUps = data.PopUps ~= false
	data.SlowMode = data.SlowMode == true
	data.TutorialCompleted = data.TutorialCompleted == true

	if type(data.ActivePlotSkin) ~= "string" or data.ActivePlotSkin == "" then
		data.ActivePlotSkin = DataTemplate.ActivePlotSkin
	end

	if type(data.PurchasesLogs) ~= "table" then
		data.PurchasesLogs = {}
	end

	if type(data.DataGamepasses) ~= "table" then
		data.DataGamepasses = {}
	end
end

local function removeStaleDataKeys(data: { [string]: any })
	for key in data do
		if DataTemplate[key] == nil then
			data[key] = nil
		end
	end
end

local function sanitizePlayerData(data: { [string]: any })
	removeStaleDataKeys(data)
	sanitizeScalars(data)
	sanitizeInventory(data)
	sanitizePlot(data)
	sanitizeIndex(data)
	migrateInventoryWeights({ Data = data })
	reconcileLeaderboardStats(data)
	reconcileFreeStrength(data)
end

local function getPlayerWeightLuckMultiplier(player: Player): number
	local data = Module:GetData(player)
	if not data then
		return 1
	end
	return Shared_Marketplace.GetWeightLuckMultiplierFromGamepasses(data.DataGamepasses)
end

function Module:AddInventoryItem(player: Player, item: any): number?
	local data = self:GetData(player)
	if not data then
		return nil
	end

	if type(data.Inventory) ~= "table" then
		data.Inventory = {}
	end

	if #data.Inventory >= INVENTORY_MAX_SLOTS then
		return nil
	end

	normalizeInventoryItem(item, getPlayerWeightLuckMultiplier(player))
	table.insert(data.Inventory, item)
	local newIndex = #data.Inventory
	local indexChanged = addBrainrotToIndex(data, item)

	local replica = self:GetReplica(player)
	if replica then
		replica:SetValue({ "Inventory" }, data.Inventory)
		if indexChanged then
			replica:SetValue({ "Index" }, data.Index)
		end
	end

	return newIndex
end

function Module:GetPlotSlot(player: Player, slotId: number): any?
	local data = self:GetData(player)
	if not data or type(data.Plot) ~= "table" then
		return nil
	end
	return data.Plot[tostring(slotId)]
end

function Module:ResetPlayerData(player: Player): boolean
	local profile = self:GetProfile(player)
	if not profile then
		return false
	end

	local data = profile.Data
	local oldKeys: { [string]: boolean } = {}
	for key in data do
		if type(key) == "string" then
			oldKeys[key] = true
		end
	end

	table.clear(data)
	for key, templateValue in DataTemplate do
		data[key] = deepCopy(templateValue)
		oldKeys[key] = nil
	end
	sanitizePlayerData(data)

	local replica = self:GetReplica(player)
	if replica then
		for key in oldKeys do
			replica:SetValue({ key }, nil)
		end

		for key, value in data do
			replica:SetValue({ key }, value)
		end
	end

	self:SetValue(player, "Cash", data.Cash or 0)
	self:SetValue(player, "Speed", data.Speed or Shared_SpeedStore.DefaultSpeed)
	self:SetValue(player, "Strength", data.Strength or 1)
	self:SetValue(player, "SlowMode", data.SlowMode == true)

	local replica = self:GetReplica(player)
	if replica then
		replica:SetValue({ "MaxSpeedRecorded" }, data.MaxSpeedRecorded or Shared_SpeedStore.DefaultSpeed)
		replica:SetValue({ "TotalCashEarned" }, data.TotalCashEarned or 0)
	end

	player:SetAttribute("CarryingLuckyBlock", nil)
	player:SetAttribute("CarriedLuckyBlockConfigName", nil)
	player:SetAttribute("CarriedLuckyBlockBaseWeight", nil)
	player:SetAttribute("CarriedLuckyBlockWeight", nil)
	player:SetAttribute("CarriedLuckyBlockRarity", nil)

	local resetSpeed = resolveMaxSpeed(data.Speed)
	local slowMode = resolveSlowModeEnabled(data.SlowMode)
	applyWalkSpeed(player, resetSpeed, slowMode)

	local events = ReplicatedStorage:FindFirstChild("Events")
	local tutorialHandler = events and events:FindFirstChild("TutorialHandler")
	if tutorialHandler and tutorialHandler:IsA("RemoteEvent") then
		tutorialHandler:FireClient(player, "Restart")
	end

	return true
end

local function createLeaderstats(player, profile)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Value = Shared_Abbreviation:Number(profile.Data.Cash or 0)
	cash.Parent = leaderstats

	local speed = Instance.new("IntValue")
	speed.Name = "Speed"
	speed.Value = math.max(1, math.floor(tonumber(profile.Data.Speed) or Shared_SpeedStore.DefaultSpeed))
	speed.Parent = leaderstats

	local strength = Instance.new("IntValue")
	strength.Name = "Strength"
	strength.Value = math.max(1, math.floor(tonumber(profile.Data.Strength) or 1))
	strength.Parent = leaderstats

	local replica = Module.Replicas[player]
	if not replica then
		return
	end

	replica:ListenToChange({ "Cash" }, function(newValue)
		cash.Value = Shared_Abbreviation:Number(newValue)
	end)

	replica:ListenToChange({ "Speed" }, function(newValue)
		speed.Value = math.max(1, math.floor(tonumber(newValue) or 1))
	end)

	replica:ListenToChange({ "Strength" }, function(newValue)
		strength.Value = math.max(1, math.floor(tonumber(newValue) or 1))
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
	sanitizePlayerData(profile.Data)

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

	profile.Data.Speed = resolveMaxSpeed(profile.Data.Speed)
	profile.Data.SlowMode = resolveSlowModeEnabled(profile.Data.SlowMode)
	replica:SetValue({ "Speed" }, profile.Data.Speed)
	replica:SetValue({ "SlowMode" }, profile.Data.SlowMode)
	replica:SetValue({ "MaxSpeedRecorded" }, profile.Data.MaxSpeedRecorded)
	replica:SetValue({ "TotalCashEarned" }, profile.Data.TotalCashEarned)

	player.CharacterAdded:Connect(function(character)
		local currentSpeed = Module:GetValue(player, "Speed") or profile.Data.Speed
		local slowModeEnabled = Module:GetValue(player, "SlowMode")
		if slowModeEnabled == nil then
			slowModeEnabled = profile.Data.SlowMode
		end
		applyWalkSpeedToCharacter(character, player, currentSpeed, slowModeEnabled)
	end)
	if player.Character then
		local currentSpeed = Module:GetValue(player, "Speed") or profile.Data.Speed
		local slowModeEnabled = Module:GetValue(player, "SlowMode")
		if slowModeEnabled == nil then
			slowModeEnabled = profile.Data.SlowMode
		end
		task.defer(applyWalkSpeedToCharacter, player.Character, player, currentSpeed, slowModeEnabled)
	end

	player:GetAttributeChangedSignal("CarriedLuckyBlockWeight"):Connect(function()
		Module:RefreshWalkSpeed(player)
	end)

	replica:ListenToChange({ "Speed" }, function(newSpeed)
		applyWalkSpeed(player, newSpeed, Module:GetValue(player, "SlowMode"))
	end)

	replica:ListenToChange({ "Strength" }, function()
		Module:RefreshWalkSpeed(player)
	end)

	replica:ListenToChange({ "SlowMode" }, function(newSlowMode)
		applyWalkSpeed(player, Module:GetValue(player, "Speed"), newSlowMode)
	end)

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