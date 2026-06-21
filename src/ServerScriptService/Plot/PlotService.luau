local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Plot = require(script.Parent.Plot)
local Shared_PlotConfig = SharedModules.require("Shared_PlotConfig")
local PlotCash = require(script.Parent.PlotCash)
local Server_Marketplace = require(script.Parent.Parent.Core.Server_Marketplace)
local PlotOfflineCash = require(script.Parent.PlotOfflineCash)
local PlotPlacement = require(script.Parent.PlotPlacement)
local PlotSlotPurchase = require(script.Parent.PlotSlotPurchase)
local GameProcessService = require(ServerScriptService.GameProcess.GameProcessService)
local Server_Data = require(ServerScriptService.Core.Server_Data)
local Shared_Brainrots = SharedModules.require("Shared_Brainrots")
local Shared_LuckyBlocks = SharedModules.require("Shared_LuckyBlocks")
local Shared_Modifiers = SharedModules.require("Shared_Modifiers")
local Shared_Weight = SharedModules.require("Shared_Weight")
local Shared_SpeedStore = SharedModules.require("Shared_SpeedStore")
local Shared_StrengthStore = SharedModules.require("Shared_StrengthStore")
local Shared_Rebirth = SharedModules.require("Shared_Rebirth")

local luckyBlockOpenLocks: { [Player]: boolean } = {}
local collectAllCooldowns: { [Player]: number } = {}
local activePlotService: any = nil
local COLLECT_ALL_COOLDOWN = 1
local plotHandler: RemoteEvent

local function clearEquippedVisual(player: Player)
	player:SetAttribute("EquippedItemType", nil)
	player:SetAttribute("EquippedConfigName", nil)
	player:SetAttribute("EquippedModifier", nil)
	player:SetAttribute("EquippedLevel", nil)
	player:SetAttribute("EquippedBaseWeight", nil)
	player:SetAttribute("EquippedWeight", nil)
end

local function setEquippedVisual(player: Player, inventoryIndex: any)
	if inventoryIndex == nil then
		clearEquippedVisual(player)
		return
	end

	if type(inventoryIndex) ~= "number" then
		return
	end

	if GameProcessService.IsPlayerCarrying(player) then
		return
	end

	local inventory = Server_Data:GetValue(player, "Inventory") or {}
	local item = inventory[inventoryIndex]
	if not item or type(item.ConfigName) ~= "string" then
		clearEquippedVisual(player)
		return
	end

	if item.ItemType ~= "Brainrot" and item.ItemType ~= "LuckyBlock" then
		clearEquippedVisual(player)
		return
	end

	local data = item.Data or {}
	player:SetAttribute("EquippedItemType", item.ItemType)
	player:SetAttribute("EquippedConfigName", item.ConfigName)
	player:SetAttribute("EquippedModifier", data.Modifier or "Normal")
	player:SetAttribute("EquippedLevel", math.max(1, tonumber(data.Level) or 1))
	player:SetAttribute("EquippedBaseWeight", tonumber(data.BaseWeight))
	player:SetAttribute("EquippedWeight", tonumber(data.Weight))
end

local function normalizeName(name: string): string
	return string.lower(string.gsub(name, "[^%w]", ""))
end

local function buildBlacklistSet(rawList: any): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if type(rawList) ~= "table" then
		return set
	end

	for _, value in rawList do
		if type(value) == "string" and value ~= "" then
			set[normalizeName(value)] = true
		end
	end
	return set
end

local function rollLuckyBlockRewardConfigName(luckyBlockConfigName: string): string?
	local luckyBlockData = Shared_LuckyBlocks.Data[luckyBlockConfigName]
	if not luckyBlockData then
		return nil
	end

	local blacklistSet = buildBlacklistSet(luckyBlockData.Blacklist)

	local weightedReward = Shared_LuckyBlocks.RollRewardBrainrot(luckyBlockConfigName)
	if weightedReward then
		return weightedReward
	end

	local rewardBrainrots = Shared_LuckyBlocks.GetRewardBrainrots(luckyBlockConfigName)
	if rewardBrainrots then
		local candidates = {}
		for _, configName in rewardBrainrots do
			if not blacklistSet[normalizeName(configName)] and not Shared_Brainrots.IsVIPExclusive(configName) then
				table.insert(candidates, configName)
			end
		end

		if #candidates > 0 then
			return candidates[math.random(1, #candidates)]
		end
	end

	local rewardRarities = Shared_LuckyBlocks.GetRewardRarities(luckyBlockConfigName)
	if rewardRarities then
		local rarity = rewardRarities[math.random(1, #rewardRarities)]
		local candidates = {}
		for _, configName in Shared_Brainrots.GetConfigNamesForRarity(rarity) do
			if not blacklistSet[normalizeName(configName)] and not Shared_Brainrots.IsVIPExclusive(configName) then
				table.insert(candidates, configName)
			end
		end

		if #candidates > 0 then
			return candidates[math.random(1, #candidates)]
		end
	end

	local rarity = luckyBlockData.Rarity
	if type(rarity) ~= "string" or rarity == "" then
		return nil
	end

	local candidates = {}
	for _, configName in Shared_Brainrots.GetConfigNamesForRarity(rarity) do
		if not blacklistSet[normalizeName(configName)] and not Shared_Brainrots.IsVIPExclusive(configName) then
			table.insert(candidates, configName)
		end
	end

	if #candidates == 0 then
		return nil
	end

	return candidates[math.random(1, #candidates)]
end

local function rollLuckyBlockModifier(luckyBlockData: { [string]: any }): string
	local rarityChances = nil
	if type(luckyBlockData.Rarity) == "string" then
		rarityChances = Shared_LuckyBlocks.ModifierChancesByRarity
			and Shared_LuckyBlocks.ModifierChancesByRarity[luckyBlockData.Rarity]
	end

	local rawChances = luckyBlockData.ModifierChances or rarityChances or Shared_LuckyBlocks.DefaultModifierChances
	if type(rawChances) ~= "table" then
		return "Normal"
	end

	local totalWeight = 0
	for modifierName, weight in rawChances do
		if Shared_Modifiers.Data[modifierName] and type(weight) == "number" and weight > 0 then
			totalWeight += weight
		end
	end

	if totalWeight <= 0 then
		return "Normal"
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for modifierName, weight in rawChances do
		if Shared_Modifiers.Data[modifierName] and type(weight) == "number" and weight > 0 then
			cumulative += weight
			if roll <= cumulative then
				return modifierName
			end
		end
	end

	return "Normal"
end

local function openLuckyBlock(player: Player, inventoryIndex: number): { [string]: any }?
	if luckyBlockOpenLocks[player] then
		return nil
	end
	luckyBlockOpenLocks[player] = true

	local function finish()
		luckyBlockOpenLocks[player] = nil
	end

	local inventory = Server_Data:GetValue(player, "Inventory") or {}
	local item = inventory[inventoryIndex]
	if not item or item.ItemType ~= "LuckyBlock" or type(item.ConfigName) ~= "string" then
		finish()
		return nil
	end

	local luckyBlockConfigName = item.ConfigName
	local luckyBlockData = Shared_LuckyBlocks.Data[luckyBlockConfigName]
	if not luckyBlockData then
		finish()
		return nil
	end

	local removedItem = Server_Data:RemoveInventoryAt(player, inventoryIndex)
	if not removedItem then
		finish()
		return nil
	end

	local rewardedConfigName = rollLuckyBlockRewardConfigName(luckyBlockConfigName)
	if not rewardedConfigName then
		-- Roll failed: restore consumed lucky block back to same index.
		local newInventory = Server_Data:GetValue(player, "Inventory") or {}
		table.insert(newInventory, math.clamp(inventoryIndex, 1, #newInventory + 1), removedItem)
		local replica = Server_Data:GetReplica(player)
		if replica then
			replica:SetValue({ "Inventory" }, newInventory)
		end
		finish()
		return nil
	end

	local rewardedLevel = Shared_LuckyBlocks.RollRewardLevel(luckyBlockConfigName)
	local rewardedModifier = rollLuckyBlockModifier(luckyBlockData)
	local defaultBaseWeight = Shared_LuckyBlocks.GetBaseWeight(luckyBlockConfigName)
	local baseWeight, luckyBlockWeight = Shared_Weight.ResolveLuckyBlockWeights(removedItem.Data, defaultBaseWeight)

	local rewardIndex = Server_Data:AddInventoryItem(player, {
		ItemType = "Brainrot",
		ConfigName = rewardedConfigName,
		Data = {
			Level = rewardedLevel,
			Modifier = rewardedModifier,
			BaseWeight = baseWeight,
			Weight = luckyBlockWeight,
		},
	})

	local rolledWeight = luckyBlockWeight
	if rewardIndex then
		local inventory = Server_Data:GetValue(player, "Inventory") or {}
		local rewardedItem = inventory[rewardIndex]
		if rewardedItem and type(rewardedItem.Data) == "table" and type(rewardedItem.Data.Weight) == "number" then
			rolledWeight = rewardedItem.Data.Weight
		end
	end

	if not rewardIndex then
		local newInventory = Server_Data:GetValue(player, "Inventory") or {}
		table.insert(newInventory, math.clamp(inventoryIndex, 1, #newInventory + 1), removedItem)
		local replica = Server_Data:GetReplica(player)
		if replica then
			replica:SetValue({ "Inventory" }, newInventory)
		end
		finish()
		return nil
	end

	local launchOrigin = Vector3.new(0, 8, 0)
	local landingPosition = Vector3.new(0, 4, -6)
	local character = player.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			launchOrigin = rootPart.Position + rootPart.CFrame.UpVector * 2 + rootPart.CFrame.LookVector
			landingPosition = rootPart.Position + rootPart.CFrame.LookVector * 8
		end
	end

	local animationData = {
		openId = tostring(os.clock()) .. ":" .. tostring(player.UserId),
		openingUserId = player.UserId,
		configName = luckyBlockConfigName,
		launchOrigin = launchOrigin,
		landingPosition = landingPosition,
		pickedConfigName = rewardedConfigName,
		pickedItemType = "Brainrot",
		pickedLevel = rewardedLevel,
		pickedModifier = rewardedModifier,
		blockBaseWeight = baseWeight,
		blockWeight = rolledWeight,
		pickedBaseWeight = baseWeight,
		pickedWeight = rolledWeight,
		rewardInventoryIndex = rewardIndex,
	}

	finish()
	return animationData
end

local function sellEquippedBrainrot(player: Player, inventoryIndex: number): (boolean, number?)
	local inventory = Server_Data:GetValue(player, "Inventory") or {}
	local item = inventory[inventoryIndex]
	if not item or item.ItemType ~= "Brainrot" or type(item.ConfigName) ~= "string" then
		return false, nil
	end

	local level = math.max(1, tonumber(item.Data and item.Data.Level) or 1)
	local modifier = item.Data and item.Data.Modifier or "Normal"
	local baseWeight = item.Data and tonumber(item.Data.BaseWeight)
	local rolledWeight = item.Data and tonumber(item.Data.Weight)
	local sellWorth = Shared_Brainrots.GetSellWorth(item.ConfigName, level, modifier, baseWeight, rolledWeight)
	if sellWorth <= 0 then
		return false, nil
	end

	local removedItem = Server_Data:RemoveInventoryAt(player, inventoryIndex)
	if not removedItem then
		return false, nil
	end

	Server_Data:AddValue(player, "Cash", sellWorth)
	return true, sellWorth
end

local function sellAllBrainrots(player: Player): (number, number)
	local inventory = Server_Data:GetValue(player, "Inventory") or {}
	local keptInventory: { any } = {}
	local soldCount = 0
	local totalWorth = 0

	for _, item in inventory do
		if item and item.ItemType == "Brainrot" and type(item.ConfigName) == "string" then
			local level = math.max(1, tonumber(item.Data and item.Data.Level) or 1)
			local modifier = item.Data and item.Data.Modifier or "Normal"
			local baseWeight = item.Data and tonumber(item.Data.BaseWeight)
			local rolledWeight = item.Data and tonumber(item.Data.Weight)
			local sellWorth = Shared_Brainrots.GetSellWorth(item.ConfigName, level, modifier, baseWeight, rolledWeight)
			if sellWorth > 0 then
				soldCount += 1
				totalWorth += sellWorth
			else
				table.insert(keptInventory, item)
			end
		else
			table.insert(keptInventory, item)
		end
	end

	if soldCount > 0 then
		Server_Data:SetInventory(player, keptInventory)
		Server_Data:AddValue(player, "Cash", totalWorth)
	end

	return soldCount, totalWorth
end

local function tryBuySpeed(player: Player, amount: number): (boolean, string?, number?, number?)
	local safeAmount = math.floor(amount)
	if not Shared_SpeedStore.IsValidPurchaseAmount(safeAmount) then
		return false, "InvalidAmount", nil, nil
	end

	local rebirths = Server_Data:GetValue(player, "Rebirths")
	local maxSpeed = Shared_Rebirth.GetMaxSpeedCap(rebirths)
	local currentSpeed = math.max(1, math.floor(Server_Data:GetValue(player, "Speed") or Shared_SpeedStore.DefaultSpeed))

	if currentSpeed >= maxSpeed then
		return false, "AtCap", nil, currentSpeed
	end

	if currentSpeed + safeAmount > maxSpeed then
		return false, "AtCap", nil, currentSpeed
	end

	local cost = Shared_SpeedStore.GetPurchaseCost(currentSpeed, safeAmount)
	local currentCash = Server_Data:GetValue(player, "Cash") or 0

	if currentCash < cost then
		return false, "NotEnoughCash", cost, currentSpeed
	end

	Server_Data:SubValue(player, "Cash", cost)

	local newSpeed = Shared_SpeedStore.GetSpeedAfterPurchase(currentSpeed, safeAmount)
	Server_Data:SetValue(player, "Speed", newSpeed)

	return true, nil, cost, newSpeed
end

local function tryBuyStrength(player: Player, amount: number): (boolean, string?, number?, number?)
	local safeAmount = math.floor(amount)
	if not Shared_StrengthStore.IsValidPurchaseAmount(safeAmount) then
		return false, "InvalidAmount", nil, nil
	end

	local rebirths = Server_Data:GetValue(player, "Rebirths")
	local maxStrength = Shared_Rebirth.GetMaxStrengthCap(rebirths)
	local currentStrength = math.max(1, math.floor(Server_Data:GetValue(player, "Strength") or Shared_StrengthStore.DefaultStrength))

	if currentStrength >= maxStrength then
		return false, "AtCap", nil, currentStrength
	end

	if currentStrength + safeAmount > maxStrength then
		return false, "AtCap", nil, currentStrength
	end

	local freePointsUsed = math.clamp(
		math.floor(Server_Data:GetValue(player, "FreeStrengthPointsUsed") or 0),
		0,
		Shared_StrengthStore.FreeStrengthPoints
	)
	local rebirths = Server_Data:GetValue(player, "Rebirths")
	local cost = Shared_StrengthStore.GetPurchaseCost(currentStrength, safeAmount, freePointsUsed, rebirths)
	local currentCash = Server_Data:GetValue(player, "Cash") or 0

	if currentCash < cost then
		return false, "NotEnoughCash", cost, currentStrength
	end

	Server_Data:SubValue(player, "Cash", cost)

	local newStrength = Shared_StrengthStore.GetStrengthAfterPurchase(currentStrength, safeAmount)
	Server_Data:SetValue(player, "Strength", newStrength)

	local freePointsGranted = Shared_StrengthStore.GetFreePointsInPurchase(
		currentStrength,
		safeAmount,
		freePointsUsed,
		rebirths
	)
	if freePointsGranted > 0 then
		Server_Data:SetValue(
			player,
			"FreeStrengthPointsUsed",
			math.min(Shared_StrengthStore.FreeStrengthPoints, freePointsUsed + freePointsGranted)
		)
	end

	return true, nil, cost, newStrength
end

local function setSlowMode(player: Player, enabled: boolean): boolean
	Server_Data:SetValue(player, "SlowMode", enabled == true)
	return true
end

local function applyRebirthState(player: Player)
	local rebirths = Shared_Rebirth.GetRebirthCount(Server_Data:GetValue(player, "Rebirths"))
	Server_Data:SetValue(player, "Rebirths", rebirths + 1)
	Server_Data:SetValue(player, "Cash", 0)
	Server_Data:SetValue(player, "Speed", Shared_SpeedStore.DefaultSpeed)
	Server_Data:SetValue(player, "Strength", Shared_StrengthStore.DefaultStrength)
	Server_Data:SetValue(player, "FreeStrengthPointsUsed", Shared_StrengthStore.FreeStrengthPoints)

	local plot = if activePlotService then activePlotService:GetPlotByPlayer(player) else nil
	PlotCash.ClearAllUncollectedCash(player, plot)
end

local function tryRebirth(player: Player): (boolean, string?, number?)
	local rebirths = Shared_Rebirth.GetRebirthCount(Server_Data:GetValue(player, "Rebirths"))
	local cost = Shared_Rebirth.GetCost(rebirths)
	local cash = Server_Data:GetValue(player, "Cash") or 0

	if cash < cost then
		return false, "NotEnoughCash", cost
	end

	applyRebirthState(player)

	return true, nil, cost
end

local function getPlayerSlotCount(player: Player): number
	return Server_Data:GetValue(player, "TotalPlotSlots") or Shared_PlotConfig.DefaultPlotSlots
end

local PlotService = {}
PlotService.__index = PlotService

function PlotService:CompleteRebirth(player: Player, cost: number?)
	local plot = self:GetPlotByPlayer(player)
	if plot then
		plot.Model:SetAttribute(
			"OwnerRebirths",
			Shared_Rebirth.GetRebirthCount(Server_Data:GetValue(player, "Rebirths"))
		)
	end

	local plotHandler = ReplicatedStorage:FindFirstChild("Events")
		and (ReplicatedStorage.Events :: Folder):FindFirstChild("PlotHandler")
	if plotHandler and plotHandler:IsA("RemoteEvent") then
		local remote = plotHandler :: RemoteEvent
		remote:FireClient(player, "RebirthSuccess", cost or 0)
		remote:FireClient(player, "OfflineCash", 0, 0)
	end
end

function PlotService:GrantRobuxRebirth(player: Player): boolean
	applyRebirthState(player)
	self:CompleteRebirth(player, 0)
	return true
end

function PlotService.new()
	local self = setmetatable({}, PlotService)
	self.Plots = {}
	self.PlayerToPlot = {}
	return self
end

function PlotService:LoadPlots()
	local gameFolder = Workspace:WaitForChild("Game")
	local plotsFolder = gameFolder:WaitForChild("Plots")

	local plotModels = plotsFolder:GetChildren()
	table.sort(plotModels, function(a, b)
		return a.Name < b.Name
	end)

	for _, child in plotModels do
		if child:IsA("Model") then
			local plot = Plot.new(child)
			table.insert(self.Plots, plot)
		end
	end
end

function PlotService:GetPlotByPlayer(player: Player)
	return self.PlayerToPlot[player]
end

function PlotService:GetAvailablePlot()
	for _, plot in self.Plots do
		if plot:IsAvailable() then
			return plot
		end
	end
	return nil
end

function PlotService:TeleportPlayerToPlot(player: Player)
	local plot = self:GetPlotByPlayer(player)
	if not plot then
		return
	end
	plot:TeleportPlayer(player)
end

function PlotService:ResetPlayerPlotFromData(player: Player): boolean
	local plot = self:GetPlotByPlayer(player)
	if not plot then
		return false
	end

	local totalSlots = getPlayerSlotCount(player)
	plot:Build(totalSlots)
	PlotPlacement.LoadPlotData(plot, Server_Data:GetValue(player, "Plot") or {})
	self:TeleportPlayerToPlot(player)
	return true
end

function PlotService:AttachPlayer(player: Player)
	if self.PlayerToPlot[player] then
		return
	end

	player.CharacterAdded:Connect(function(character)
		local currentPlot = self:GetPlotByPlayer(player)
		if not currentPlot then
			return
		end
		task.defer(function()
			currentPlot:TeleportCharacter(character)
		end)
	end)

	task.spawn(function()
		while not Server_Data:GetProfile(player) do
			if player.Parent ~= Players then
				return
			end
			task.wait(0.1)
		end

		if self.PlayerToPlot[player] then
			return
		end

		PlotOfflineCash.ProcessJoin(player, plotHandler)

		local plot = self:GetAvailablePlot()
		if not plot then
			warn(("No free plots for %s"):format(player.Name))
			return
		end

		plot:Assign(player, getPlayerSlotCount(player), Server_Data:GetValue(player, "Rebirths"))
		self.PlayerToPlot[player] = plot

		PlotPlacement.LoadPlotData(plot, Server_Data:GetValue(player, "Plot") or {})
		self:TeleportPlayerToPlot(player)
	end)
end

function PlotService:DetachPlayer(player: Player)
	PlotOfflineCash.OnPlayerLeave(player)
	luckyBlockOpenLocks[player] = nil
	PlotPlacement.ClearPlayerLocks(player)
	PlotSlotPurchase.ClearPlayerLocks(player)

	local plot = self.PlayerToPlot[player]
	if not plot then
		return
	end

	PlotCash.SyncPlotCashToData(player, plot)
	plot:Release()
	self.PlayerToPlot[player] = nil
end

function PlotService:AddSlot(player: Player): Model?
	local plot = self:GetPlotByPlayer(player)
	if not plot then
		return nil
	end
	return plot:AddSlot()
end

function PlotService:Init()
	activePlotService = self
	self:LoadPlots()

	plotHandler = ReplicatedStorage:WaitForChild("Events"):WaitForChild("PlotHandler") :: RemoteEvent
	plotHandler.OnServerEvent:Connect(function(player: Player, action: string, slotId: any, inventoryIndex: any)
		if action == "Place" then
			if type(slotId) ~= "number" or type(inventoryIndex) ~= "number" then
				return
			end

			local plot = self:GetPlotByPlayer(player)
			PlotPlacement.PlaceBrainrot(player, plot, slotId, inventoryIndex)
			return
		end

		if action == "Collect" then
			if type(slotId) ~= "number" then
				return
			end

			local plot = self:GetPlotByPlayer(player)
			PlotCash.Collect(player, plot, slotId)
			return
		end

		if action == "CollectAll" then
			if not Server_Marketplace.PlayerOwnsFastCollect(player) then
				return
			end

			local now = os.clock()
			local lastCollect = collectAllCooldowns[player]
			if lastCollect and now - lastCollect < COLLECT_ALL_COOLDOWN then
				return
			end
			collectAllCooldowns[player] = now

			local plot = self:GetPlotByPlayer(player)
			local totalCollected = PlotCash.CollectAll(player, plot)
			if totalCollected > 0 then
				plotHandler:FireClient(player, "CollectAllSuccess", totalCollected)
			end
			return
		end

		if action == "Upgrade" then
			if type(slotId) ~= "number" then
				return
			end

			local plot = self:GetPlotByPlayer(player)
			PlotPlacement.UpgradeBrainrot(player, plot, slotId)
			return
		end

		if action == "BuySlot" then
			local plot = self:GetPlotByPlayer(player)
			PlotSlotPurchase.TryPurchase(player, plot)
			return
		end

		if action == "SetEquipped" then
			setEquippedVisual(player, slotId)
			return
		end

		if action == "OpenLuckyBlock" then
			if type(slotId) ~= "number" then
				return
			end
			local animationData = openLuckyBlock(player, slotId)
			if animationData then
				clearEquippedVisual(player)
				plotHandler:FireAllClients("LuckyBlockOpen", animationData)
			end
			return
		end

		if action == "SellEquipped" then
			if type(slotId) ~= "number" then
				return
			end
			local sold, sellWorth = sellEquippedBrainrot(player, slotId)
			if sold and sellWorth then
				plotHandler:FireClient(player, "SellEquippedSuccess", sellWorth)
			else
				plotHandler:FireClient(player, "SellEquippedFailed")
			end
			return
		end

		if action == "SellAllBrainrots" then
			local soldCount, totalWorth = sellAllBrainrots(player)
			if soldCount > 0 and totalWorth > 0 then
				plotHandler:FireClient(player, "SellAllBrainrotsSuccess", soldCount, totalWorth)
			else
				plotHandler:FireClient(player, "SellAllBrainrotsFailed")
			end
			return
		end

		if action == "BuySpeed" then
			if type(slotId) ~= "number" then
				return
			end
			local bought, reason, cost, newSpeed = tryBuySpeed(player, slotId)
			if bought then
				plotHandler:FireClient(player, "SpeedPurchaseSuccess", math.floor(slotId), cost, newSpeed)
			else
				plotHandler:FireClient(player, "SpeedPurchaseFailed", reason, cost)
			end
			return
		end

		if action == "BuyStrength" then
			if type(slotId) ~= "number" then
				return
			end
			local bought, reason, cost, newStrength = tryBuyStrength(player, slotId)
			if bought then
				plotHandler:FireClient(player, "StrengthPurchaseSuccess", math.floor(slotId), cost, newStrength)
			else
				plotHandler:FireClient(player, "StrengthPurchaseFailed", reason, cost)
			end
			return
		end

		if action == "SetSlowMode" then
			if type(slotId) ~= "boolean" then
				return
			end
			setSlowMode(player, slotId)
			return
		end

		if action == "CollectOfflineCash" then
			PlotOfflineCash.Collect(player, plotHandler)
			return
		end

		if action == "Rebirth" then
			local rebirthed, reason, cost = tryRebirth(player)
			if rebirthed then
				self:CompleteRebirth(player, cost)
			else
				plotHandler:FireClient(player, "RebirthFailed", reason, cost)
			end
		end
	end)

	PlotCash.StartGenerationLoop(function()
		return self.Plots
	end)

	for _, player in Players:GetPlayers() do
		self:AttachPlayer(player)
	end

	Players.PlayerAdded:Connect(function(player)
		self:AttachPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		collectAllCooldowns[player] = nil
		self:DetachPlayer(player)
	end)
end

return PlotService