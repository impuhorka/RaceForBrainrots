local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_PlotConfig = SharedModules.require("Shared_PlotConfig")
local Shared_Rebirth = SharedModules.require("Shared_Rebirth")
local Server_Data = require(script.Parent.Parent.Core.Server_Data)

local PlotSlotPurchase = {}

local purchaseLocks: { [Player]: boolean } = {}

local function getPlotHandlerEvent()
	local events = ReplicatedStorage:WaitForChild("Events")
	return events:WaitForChild("PlotHandler") :: RemoteEvent
end

function PlotSlotPurchase.TryPurchase(player: Player, plot): boolean
	if purchaseLocks[player] then
		return false
	end
	purchaseLocks[player] = true

	local function finish()
		purchaseLocks[player] = nil
	end

	if not plot or plot.Owner ~= player then
		finish()
		return false
	end

	local currentSlots = Server_Data:GetValue(player, "TotalPlotSlots") or Shared_PlotConfig.DefaultPlotSlots
	local rebirths = Server_Data:GetValue(player, "Rebirths")
	local maxAllowed = Shared_Rebirth.GetMaxPlotSlots(rebirths)

	if currentSlots >= Shared_PlotConfig.MaxPlotSlots or currentSlots >= maxAllowed then
		finish()
		return false
	end

	local cost = Shared_PlotConfig.getNextSlotCost(currentSlots)
	if cost <= 0 then
		finish()
		return false
	end

	local cash = Server_Data:GetValue(player, "Cash") or 0
	if cash < cost then
		finish()
		return false
	end

	Server_Data:SubValue(player, "Cash", cost)

	local newTotal = currentSlots + 1
	Server_Data:SetValue(player, "TotalPlotSlots", newTotal)

	local slotModel = plot:AddSlot()
	if not slotModel then
		Server_Data:AddValue(player, "Cash", cost)
		Server_Data:SetValue(player, "TotalPlotSlots", currentSlots)
		finish()
		return false
	end

	getPlotHandlerEvent():FireClient(player, "SlotPurchaseSuccess", newTotal)
	finish()
	return true
end

return PlotSlotPurchase