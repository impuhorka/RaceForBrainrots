local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotBrainrotVisuals = require(script.Parent.PlotBrainrotVisuals)
local Server_Data = require(script.Parent.Parent.Core.Server_Data)
local Shared_Brainrots = require(ReplicatedStorage.Modules.Shared_Brainrots)

local PlotPlacement = {}

local placingLocks: { [Player]: boolean } = {}
local pickupLocks: { [Player]: boolean } = {}
local slotUpgradeLocks: { [string]: boolean } = {}

local function getUpgradeCooldownKey(player: Player, slotId: number): string
	return ("%d:%d"):format(player.UserId, slotId)
end

local function getPlotHandlerEvent()
	local events = ReplicatedStorage:WaitForChild("Events")
	return events:WaitForChild("PlotHandler") :: RemoteEvent
end

local function slotHasBrainrot(slotModel: Model): boolean
	local configName = slotModel:GetAttribute("ConfigName")
	return type(configName) == "string" and configName ~= ""
end

function PlotPlacement.ApplySlotData(plot, slotId: number, slotModel: Model, slotData: any)
	slotModel:SetAttribute("ConfigName", slotData.ConfigName)
	slotModel:SetAttribute("Level", slotData.Level or 1)
	slotModel:SetAttribute("Modifier", slotData.Modifier or "Normal")
	slotModel:SetAttribute("CashToCollect", slotData.CashToCollect or 0)

	local function onPickup(triggerPlayer: Player)
		PlotPlacement.PickupBrainrot(triggerPlayer, plot, slotId)
	end

	PlotBrainrotVisuals.PlaceOnSlot(
		slotModel,
		slotData.ConfigName,
		slotData.Modifier or "Normal",
		slotData.Level or 1,
		onPickup
	)
end

function PlotPlacement.ClearSlot(slotModel: Model)
	slotModel:SetAttribute("ConfigName", nil)
	slotModel:SetAttribute("Level", nil)
	slotModel:SetAttribute("Modifier", nil)
	slotModel:SetAttribute("CashToCollect", nil)
	PlotBrainrotVisuals.ClearSlot(slotModel)
end

function PlotPlacement.LoadPlotData(plot, plotData: { [string]: any })
	for slotIdStr, slotData in plotData do
		local slotId = tonumber(slotIdStr)
		local slotModel = slotId and plot:GetSlot(slotId)
		if slotModel and slotData then
			PlotPlacement.ApplySlotData(plot, slotId, slotModel, slotData)
		end
	end
end

function PlotPlacement.PickupBrainrot(player: Player, plot, slotId: number): boolean
	if pickupLocks[player] then
		return false
	end
	pickupLocks[player] = true

	local function finish()
		pickupLocks[player] = nil
	end

	if not plot or plot.Owner ~= player then
		finish()
		return false
	end

	local slotModel = plot:GetSlot(slotId)
	if not slotModel or not slotHasBrainrot(slotModel) then
		finish()
		return false
	end

	local slotData = Server_Data:GetPlotSlot(player, slotId)
	if not slotData then
		finish()
		return false
	end

	local item = {
		ItemType = "Brainrot",
		ConfigName = slotData.ConfigName,
		Data = {
			Level = slotData.Level or 1,
			Modifier = slotData.Modifier or "Normal",
		},
	}

	if not Server_Data:RemovePlotSlot(player, slotId) then
		finish()
		return false
	end

	local newIndex = Server_Data:AddInventoryItem(player, item)
	if not newIndex then
		Server_Data:SetPlotSlot(player, slotId, slotData)
		finish()
		return false
	end

	PlotPlacement.ClearSlot(slotModel)
	getPlotHandlerEvent():FireClient(player, "PickupSuccess", newIndex)
	finish()
	return true
end

function PlotPlacement.PlaceBrainrot(player: Player, plot, slotId: number, inventoryIndex: number): boolean
	if placingLocks[player] then
		return false
	end
	placingLocks[player] = true

	local function finish()
		placingLocks[player] = nil
	end

	if not plot or plot.Owner ~= player then
		finish()
		return false
	end

	local slotModel = plot:GetSlot(slotId)
	if not slotModel or slotHasBrainrot(slotModel) then
		finish()
		return false
	end

	local item = Server_Data:RemoveInventoryAt(player, inventoryIndex)
	if not item or item.ItemType ~= "Brainrot" or type(item.ConfigName) ~= "string" then
		finish()
		return false
	end

	local slotData = {
		CashToCollect = 0,
		ConfigName = item.ConfigName,
		Level = item.Data and item.Data.Level or 1,
		Modifier = item.Data and item.Data.Modifier or "Normal",
	}

	if not Server_Data:SetPlotSlot(player, slotId, slotData) then
		local inventory = Server_Data:GetValue(player, "Inventory") or {}
		table.insert(inventory, inventoryIndex, item)
		local replica = Server_Data:GetReplica(player)
		if replica then
			replica:SetValue({ "Inventory" }, inventory)
		end
		finish()
		return false
	end

	PlotPlacement.ApplySlotData(plot, slotId, slotModel, slotData)

	getPlotHandlerEvent():FireClient(player, "PlaceSuccess", slotId, inventoryIndex)
	finish()
	return true
end

function PlotPlacement.UpgradeBrainrot(player: Player, plot, slotId: number): boolean
	local cooldownKey = getUpgradeCooldownKey(player, slotId)

	if slotUpgradeLocks[cooldownKey] then
		return false
	end
	slotUpgradeLocks[cooldownKey] = true

	local function finish()
		slotUpgradeLocks[cooldownKey] = nil
	end

	if not plot or plot.Owner ~= player then
		finish()
		return false
	end

	local slotModel = plot:GetSlot(slotId)
	if not slotModel or not slotHasBrainrot(slotModel) then
		finish()
		return false
	end

	local slotData = Server_Data:GetPlotSlot(player, slotId)
	if not slotData or type(slotData.ConfigName) ~= "string" then
		finish()
		return false
	end

	local configName = slotData.ConfigName
	local modifier = slotData.Modifier or "Normal"
	local level = math.max(1, slotData.Level or 1)
	local maxLevel = Shared_Brainrots.MaxLevel or 150

	if level >= maxLevel then
		finish()
		return false
	end

	local upgradeCost = Shared_Brainrots.GetUpgradeCost(configName, level, modifier)
	if upgradeCost <= 0 then
		finish()
		return false
	end

	local cash = Server_Data:GetValue(player, "Cash") or 0
	if cash < upgradeCost then
		finish()
		return false
	end

	Server_Data:SubValue(player, "Cash", upgradeCost)

	slotData.Level = level + 1
	if not Server_Data:SetPlotSlot(player, slotId, slotData) then
		Server_Data:AddValue(player, "Cash", upgradeCost)
		finish()
		return false
	end

	slotModel:SetAttribute("Level", slotData.Level)

	local brainrotModel = slotModel:FindFirstChild("PlacedBrainrot")
	local newLevel = slotData.Level

	getPlotHandlerEvent():FireClient(player, "UpgradeSuccess", slotId, newLevel)
	finish()

	if brainrotModel and brainrotModel:IsA("Model") then
		task.defer(function()
			if not brainrotModel.Parent then
				return
			end
			PlotBrainrotVisuals.ApplyScaleAndPosition(brainrotModel, slotModel, newLevel)
			PlotBrainrotVisuals.UpdateBillboardIncome(brainrotModel, configName, modifier, newLevel)
		end)
	end

	return true
end

return PlotPlacement
