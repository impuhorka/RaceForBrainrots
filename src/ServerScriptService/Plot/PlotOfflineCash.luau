local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Server_Data = require(script.Parent.Parent.Core.Server_Data)
local Shared_Brainrots = SharedModules.require("Shared_Brainrots")
local Shared_Rebirth = SharedModules.require("Shared_Rebirth")

local PlotOfflineCash = {}

local MIN_OFFLINE_SECONDS = 5 * 60
local MAX_OFFLINE_SECONDS = 24 * 60 * 60
local OFFLINE_TO_PLAY_RATIO = 1 / 8

local function getTotalCashPerSecond(player: Player): number
	local plot = Server_Data:GetValue(player, "Plot") or {}
	local total = 0

	for _, slotData in plot do
		if type(slotData) ~= "table" then
			continue
		end

		local configName = slotData.ConfigName
		if type(configName) ~= "string" or configName == "" then
			continue
		end

		local level = slotData.Level or 1
		local modifier = slotData.Modifier or "Normal"
		total += Shared_Brainrots.GetCashPerSecond(
			configName,
			level,
			modifier,
			slotData.BaseWeight,
			slotData.Weight
		)
	end

	return total
end

local function calculateOfflineReward(player: Player, offlineSeconds: number): (number, number)
	if offlineSeconds < MIN_OFFLINE_SECONDS then
		return 0, 0
	end

	local cappedOffline = math.min(offlineSeconds, MAX_OFFLINE_SECONDS)
	local playSeconds = cappedOffline * OFFLINE_TO_PLAY_RATIO
	local cashPerSecond = getTotalCashPerSecond(player)
	local multiplier = Shared_Rebirth.GetCashMultiplier(Server_Data:GetValue(player, "Rebirths"))
	local cash = math.floor(playSeconds * cashPerSecond * multiplier)

	return cash, cappedOffline
end

function PlotOfflineCash.ProcessJoin(player: Player, plotHandler: RemoteEvent)
	local lastLeaveTime = Server_Data:GetValue(player, "LastLeaveTime") or 0
	local now = os.time()

	if lastLeaveTime > 0 and lastLeaveTime < now then
		local offlineSeconds = now - lastLeaveTime
		local newCash, cappedOffline = calculateOfflineReward(player, offlineSeconds)

		if newCash > 0 then
			local pendingCash = Server_Data:GetValue(player, "PendingOfflineCash") or 0
			local pendingSeconds = Server_Data:GetValue(player, "PendingOfflineSeconds") or 0
			Server_Data:SetValue(player, "PendingOfflineCash", pendingCash + newCash)
			Server_Data:SetValue(
				player,
				"PendingOfflineSeconds",
				math.min(pendingSeconds + cappedOffline, MAX_OFFLINE_SECONDS)
			)
		end
	end

	Server_Data:SetValue(player, "LastLeaveTime", now)

	local pendingCash = Server_Data:GetValue(player, "PendingOfflineCash") or 0
	if pendingCash > 0 then
		local pendingSeconds = Server_Data:GetValue(player, "PendingOfflineSeconds") or 0
		plotHandler:FireClient(player, "OfflineCash", pendingCash, pendingSeconds)
	end
end

function PlotOfflineCash.OnPlayerLeave(player: Player)
	Server_Data:SetValue(player, "LastLeaveTime", os.time())
end

function PlotOfflineCash.Collect(player: Player, plotHandler: RemoteEvent): boolean
	local pendingCash = Server_Data:GetValue(player, "PendingOfflineCash") or 0
	if pendingCash <= 0 then
		plotHandler:FireClient(player, "OfflineCashCollected", 0)
		return false
	end

	Server_Data:AddValue(player, "Cash", pendingCash)
	Server_Data:SetValue(player, "PendingOfflineCash", 0)
	Server_Data:SetValue(player, "PendingOfflineSeconds", 0)
	plotHandler:FireClient(player, "OfflineCashCollected", pendingCash)
	return true
end

return PlotOfflineCash