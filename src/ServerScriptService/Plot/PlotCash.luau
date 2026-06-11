local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Server_Data = require(script.Parent.Parent.Core.Server_Data)
local Shared_Brainrots = SharedModules.require("Shared_Brainrots")
local Shared_Rebirth = SharedModules.require("Shared_Rebirth")

local PlotCash = {}

local CASH_TICK_INTERVAL = 1

local function slotHasBrainrot(slotModel: Model): boolean
	local configName = slotModel:GetAttribute("ConfigName")
	return type(configName) == "string" and configName ~= ""
end

local function getIncomePerSecond(slotModel: Model, configName: string): number
	local level = slotModel:GetAttribute("Level") or 1
	local modifier = slotModel:GetAttribute("Modifier") or "Normal"
	local baseWeight = slotModel:GetAttribute("BaseWeight")
	local weight = slotModel:GetAttribute("Weight")
	return Shared_Brainrots.GetCashPerSecond(configName, level, modifier, baseWeight, weight)
end

function PlotCash.GetSlotId(slotModel: Model): number
	return tonumber(string.match(slotModel.Name, "%d+")) or 0
end

function PlotCash.SyncSlotCashToData(player: Player, slotId: number, slotModel: Model)
	local slotData = Server_Data:GetPlotSlot(player, slotId)
	if not slotData then
		return
	end

	slotData.CashToCollect = slotModel:GetAttribute("CashToCollect") or 0
	Server_Data:SetPlotSlot(player, slotId, slotData)
end

function PlotCash.SyncPlotCashToData(player: Player, plot)
	if not plot then
		return
	end

	for slotId, slotModel in plot.Slots do
		if slotHasBrainrot(slotModel) then
			PlotCash.SyncSlotCashToData(player, slotId, slotModel)
		end
	end
end

function PlotCash.Collect(player: Player, plot, slotId: number): boolean
	if not plot or plot.Owner ~= player then
		return false
	end

	local slotModel = plot:GetSlot(slotId)
	if not slotModel or not slotHasBrainrot(slotModel) then
		return false
	end

	local cashToCollect = slotModel:GetAttribute("CashToCollect") or 0
	if cashToCollect <= 0 then
		return false
	end

	Server_Data:AddValue(player, "Cash", cashToCollect)
	slotModel:SetAttribute("CashToCollect", 0)

	local slotData = Server_Data:GetPlotSlot(player, slotId)
	if slotData then
		slotData.CashToCollect = 0
		Server_Data:SetPlotSlot(player, slotId, slotData)
	end

	return true
end

function PlotCash.TickPlot(plot)
	if not plot or not plot.Owner then
		return
	end

	local rebirths = Server_Data:GetValue(plot.Owner, "Rebirths")
	local rebirthMultiplier = Shared_Rebirth.GetCashMultiplier(rebirths)

	for _, slotModel in plot.Slots do
		if not slotHasBrainrot(slotModel) then
			continue
		end

		local configName = slotModel:GetAttribute("ConfigName")
		if type(configName) ~= "string" then
			continue
		end

		local income = getIncomePerSecond(slotModel, configName)
		if income <= 0 then
			continue
		end

		income = math.floor(income * rebirthMultiplier + 0.5)

		local currentCash = slotModel:GetAttribute("CashToCollect") or 0
		slotModel:SetAttribute("CashToCollect", currentCash + income)
	end
end

function PlotCash.StartGenerationLoop(getPlots: () -> { any })
	task.spawn(function()
		while true do
			task.wait(CASH_TICK_INTERVAL)

			for _, plot in getPlots() do
				PlotCash.TickPlot(plot)
			end
		end
	end)
end

return PlotCash