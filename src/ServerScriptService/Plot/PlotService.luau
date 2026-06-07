local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Plot = require(script.Parent.Plot)
local PlotConfig = require(script.Parent.PlotConfig)
local PlotCash = require(script.Parent.PlotCash)
local PlotPlacement = require(script.Parent.PlotPlacement)
local PlotSlotPurchase = require(script.Parent.PlotSlotPurchase)
local Server_Data = require(ServerScriptService.Core.Server_Data)
local Shared_Brainrots = require(ReplicatedStorage.Modules.Shared_Brainrots)
local Shared_LuckyBlocks = require(ReplicatedStorage.Modules.Shared_LuckyBlocks)

local luckyBlockOpenLocks: { [Player]: boolean } = {}

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

	local rarity = luckyBlockData.Rarity
	if type(rarity) ~= "string" or rarity == "" then
		return nil
	end

	local blacklistSet = buildBlacklistSet(luckyBlockData.Blacklist)
	local candidates = {}
	for configName, brainrotData in Shared_Brainrots.Data do
		if brainrotData.Rarity == rarity and not blacklistSet[normalizeName(configName)] then
			table.insert(candidates, configName)
		end
	end

	if #candidates == 0 then
		return nil
	end

	return candidates[math.random(1, #candidates)]
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

	local minLevel = math.max(1, math.floor(luckyBlockData.MinLevel or 1))
	local maxLevel = math.max(minLevel, math.floor(luckyBlockData.MaxLevel or minLevel))
	local rewardedLevel = math.random(minLevel, maxLevel)

	local rewardIndex = Server_Data:AddInventoryItem(player, {
		ItemType = "Brainrot",
		ConfigName = rewardedConfigName,
		Data = {
			Level = rewardedLevel,
			Modifier = "Normal",
		},
	})

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
		rewardInventoryIndex = rewardIndex,
	}

	finish()
	return animationData
end

local function getPlayerSlotCount(player: Player): number
	return Server_Data:GetValue(player, "TotalPlotSlots") or PlotConfig.DefaultPlotSlots
end

local PlotService = {}
PlotService.__index = PlotService

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

		local plot = self:GetAvailablePlot()
		if not plot then
			warn(("No free plots for %s"):format(player.Name))
			return
		end

		plot:Assign(player, getPlayerSlotCount(player))
		self.PlayerToPlot[player] = plot

		PlotPlacement.LoadPlotData(plot, Server_Data:GetValue(player, "Plot") or {})
		self:TeleportPlayerToPlot(player)
	end)
end

function PlotService:DetachPlayer(player: Player)
	local plot = self.PlayerToPlot[player]
	if not plot then
		return
	end

	PlotCash.SyncPlotCashToData(player, plot)
	plot:Release()
	self.PlayerToPlot[player] = nil
end

function PlotService:GetSlotCount(player: Player): number
	local plot = self:GetPlotByPlayer(player)
	if not plot then
		return 0
	end
	return plot:GetSlotCount()
end

function PlotService:AddSlot(player: Player): Model?
	local plot = self:GetPlotByPlayer(player)
	if not plot then
		return nil
	end
	return plot:AddSlot()
end

function PlotService:RemoveSlot(player: Player, slotId: number): boolean
	local plot = self:GetPlotByPlayer(player)
	if not plot then
		return false
	end
	return plot:RemoveSlot(slotId)
end

function PlotService:Init()
	self:LoadPlots()

	local plotHandler = ReplicatedStorage:WaitForChild("Events"):WaitForChild("PlotHandler") :: RemoteEvent
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

		if action == "OpenLuckyBlock" then
			if type(slotId) ~= "number" then
				return
			end
			local animationData = openLuckyBlock(player, slotId)
			if animationData then
				plotHandler:FireClient(player, "LuckyBlockOpen", animationData)
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
		self:DetachPlayer(player)
	end)
end

return PlotService
