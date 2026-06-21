local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local PlotCash = require(script.Parent.PlotCash)
local PlotPlacement = require(script.Parent.PlotPlacement)
local Server_Data = require(script.Parent.Parent.Core.Server_Data)
local Shared_Brainrots = SharedModules.require("Shared_Brainrots")
local Shared_Marketplace = SharedModules.require("Shared_Marketplace")

local PlotSteal = {}

type PlotServiceRef = {
	GetPlotByPlayer: (self: any, player: Player) -> any?,
}

type PendingSteal = {
	victimUserId: number,
	slotId: number,
	rarity: string,
	configName: string,
	modifier: string,
	level: number,
	baseWeight: number?,
	weight: number?,
}

local activePlotService: PlotServiceRef? = nil
local pendingSteals: { [Player]: PendingSteal } = {}
local slotStealLocks: { [string]: Player } = {}

local INVENTORY_MAX_SLOTS = 100

local function getSlotLockKey(victimUserId: number, slotId: number): string
	return (`%d:%d`):format(victimUserId, slotId)
end

local function getInventoryFreeSlots(player: Player): number
	local data = Server_Data:GetData(player)
	if not data or type(data.Inventory) ~= "table" then
		return 0
	end
	return math.max(0, INVENTORY_MAX_SLOTS - #data.Inventory)
end

local function slotHasBrainrot(slotModel: Model): boolean
	local configName = slotModel:GetAttribute("ConfigName")
	return type(configName) == "string" and configName ~= ""
end

local function slotMatchesPending(slotModel: Model, slotData: any, pending: PendingSteal): boolean
	if not slotHasBrainrot(slotModel) then
		return false
	end

	if slotData.ConfigName ~= pending.configName then
		return false
	end

	local modifier = slotData.Modifier or "Normal"
	local level = slotData.Level or 1
	if modifier ~= pending.modifier or level ~= pending.level then
		return false
	end

	local baseWeight = slotModel:GetAttribute("BaseWeight")
	local weight = slotModel:GetAttribute("Weight")
	if baseWeight ~= pending.baseWeight or weight ~= pending.weight then
		return false
	end

	return true
end

local function releaseSlotLock(pending: PendingSteal, thief: Player)
	local lockKey = getSlotLockKey(pending.victimUserId, pending.slotId)
	if slotStealLocks[lockKey] == thief then
		slotStealLocks[lockKey] = nil
	end
end

local function clearPendingSteal(thief: Player)
	local pending = pendingSteals[thief]
	if not pending then
		return
	end

	releaseSlotLock(pending, thief)
	pendingSteals[thief] = nil
end

local function getVictimPlot(victimUserId: number)
	if not activePlotService then
		return nil, nil
	end

	local victim = Players:GetPlayerByUserId(victimUserId)
	if not victim or not victim.Parent then
		return nil, nil
	end

	return victim, activePlotService:GetPlotByPlayer(victim)
end

local function validatePendingSteal(thief: Player, expectedRarity: string): (boolean, string?, PendingSteal?, Player?, any?)
	local pending = pendingSteals[thief]
	if not pending then
		return false, "No steal in progress", nil, nil, nil
	end

	if pending.rarity ~= expectedRarity then
		return false, "Steal target changed", nil, nil, nil
	end

	local victim, plot = getVictimPlot(pending.victimUserId)
	if not victim or not plot then
		return false, "That player left.", pending, nil, nil
	end

	if thief.UserId == pending.victimUserId then
		return false, "You cannot steal from yourself", pending, victim, plot
	end

	local slotModel = plot:GetSlot(pending.slotId)
	if not slotModel then
		return false, "That brainrot is no longer there.", pending, victim, plot
	end

	local slotData = Server_Data:GetPlotSlot(victim, pending.slotId)
	if not slotData or not slotMatchesPending(slotModel, slotData, pending) then
		return false, "That brainrot is no longer there.", pending, victim, plot
	end

	if getInventoryFreeSlots(thief) < 1 then
		return false, "Inventory is full", pending, victim, plot
	end

	return true, nil, pending, victim, plot
end

function PlotSteal.SetPlotService(plotService: PlotServiceRef)
	activePlotService = plotService
end

function PlotSteal.ClearPlayer(player: Player)
	clearPendingSteal(player)

	for lockKey, thief in slotStealLocks do
		if thief == player then
			slotStealLocks[lockKey] = nil
		end
	end
end

function PlotSteal.OnVictimLeft(victim: Player)
	local victimUserId = victim.UserId
	local prefix = (`%d:`):format(victimUserId)

	for lockKey in slotStealLocks do
		if string.sub(lockKey, 1, #prefix) == prefix then
			slotStealLocks[lockKey] = nil
		end
	end

	local marketplaceHandler = (ReplicatedStorage.Events :: Folder):FindFirstChild("MarketplaceHandler") :: RemoteEvent?

	for thief, pending in pendingSteals do
		if pending.victimUserId ~= victimUserId then
			continue
		end

		local productKey = Shared_Marketplace.GetStealBrainrotProductKey(pending.rarity)
		clearPendingSteal(thief)
		if marketplaceHandler and thief.Parent and productKey then
			marketplaceHandler:FireClient(thief, "PurchaseFailed", productKey, "That player left.")
		end
	end
end

function PlotSteal.CancelSteal(thief: Player)
	clearPendingSteal(thief)
end

function PlotSteal.BeginSteal(thief: Player, victimUserId: number, slotId: number): (boolean, string?, string?)
	if thief.UserId == victimUserId then
		return false, "You cannot steal from yourself", nil
	end

	local victim, plot = getVictimPlot(victimUserId)
	if not victim or not plot then
		return false, "That player left.", nil
	end

	local slotModel = plot:GetSlot(slotId)
	if not slotModel or not slotHasBrainrot(slotModel) then
		return false, "That brainrot is no longer there.", nil
	end

	local slotData = Server_Data:GetPlotSlot(victim, slotId)
	if not slotData or type(slotData.ConfigName) ~= "string" then
		return false, "That brainrot is no longer there.", nil
	end

	local brainrotConfig = Shared_Brainrots.Data[slotData.ConfigName]
	local rarity = brainrotConfig and brainrotConfig.Rarity
	if type(rarity) ~= "string" or rarity == "" then
		return false, "Product is unavailable", nil
	end

	local productConfigKey = Shared_Marketplace.GetStealBrainrotProductKey(rarity)
	if not productConfigKey then
		return false, "Product is unavailable", nil
	end

	if getInventoryFreeSlots(thief) < 1 then
		return false, "Inventory is full", nil
	end

	local lockKey = getSlotLockKey(victimUserId, slotId)
	local existingThief = slotStealLocks[lockKey]
	if existingThief and existingThief ~= thief then
		return false, "Someone is already stealing this brainrot.", nil
	end

	clearPendingSteal(thief)

	local pending: PendingSteal = {
		victimUserId = victimUserId,
		slotId = slotId,
		rarity = rarity,
		configName = slotData.ConfigName,
		modifier = slotData.Modifier or "Normal",
		level = slotData.Level or 1,
		baseWeight = slotModel:GetAttribute("BaseWeight"),
		weight = slotModel:GetAttribute("Weight"),
	}

	pendingSteals[thief] = pending
	slotStealLocks[lockKey] = thief

	return true, nil, productConfigKey
end

function PlotSteal.CanGrantSteal(thief: Player, configKey: string): (boolean, string?)
	local expectedRarity = Shared_Marketplace.GetStealBrainrotRarity(configKey)
	if not expectedRarity then
		return false, "Product is unavailable"
	end

	local allowed, reason = validatePendingSteal(thief, expectedRarity)
	return allowed, reason
end

function PlotSteal.GrantSteal(thief: Player, configKey: string): (boolean, string?)
	local expectedRarity = Shared_Marketplace.GetStealBrainrotRarity(configKey)
	if not expectedRarity then
		return false, "Product is unavailable"
	end

	local allowed, reason, pending, victim, plot = validatePendingSteal(thief, expectedRarity)
	if not allowed or not pending or not victim or not plot then
		if reason == "That player left." or reason == "That brainrot is no longer there." then
			clearPendingSteal(thief)
		end
		return false, reason or "Steal failed"
	end

	local slotModel = plot:GetSlot(pending.slotId)
	if not slotModel then
		clearPendingSteal(thief)
		return false, "That brainrot is no longer there."
	end

	local slotData = Server_Data:GetPlotSlot(victim, pending.slotId)
	if not slotData then
		clearPendingSteal(thief)
		return false, "That brainrot is no longer there."
	end

	local collectedCash = slotModel:GetAttribute("CashToCollect") or 0
	if collectedCash > 0 then
		PlotCash.Collect(victim, plot, pending.slotId)
	end

	local item = {
		ItemType = "Brainrot",
		ConfigName = slotData.ConfigName,
		Data = {
			Level = slotData.Level or 1,
			Modifier = slotData.Modifier or "Normal",
			BaseWeight = slotData.BaseWeight,
			Weight = slotData.Weight,
		},
	}

	if not Server_Data:RemovePlotSlot(victim, pending.slotId) then
		return false, "That brainrot is no longer there."
	end

	local newIndex = Server_Data:AddInventoryItem(thief, item)
	if not newIndex then
		Server_Data:SetPlotSlot(victim, pending.slotId, slotData)
		return false, "Inventory is full"
	end

	PlotPlacement.ClearSlot(slotModel)
	clearPendingSteal(thief)

	local plotHandler = (ReplicatedStorage.Events :: Folder):FindFirstChild("PlotHandler") :: RemoteEvent?
	if plotHandler then
		plotHandler:FireClient(thief, "StealBrainrotSuccess", newIndex)
		plotHandler:FireClient(victim, "BrainrotStolen", pending.configName)
	end

	return true, nil
end

return PlotSteal
