local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Server_Data = require(script.Parent.Server_Data)
local Shared_SixSevenReward = SharedModules.require("Shared_SixSevenReward")

local Server_SixSevenReward = {}

local INVENTORY_MAX_SLOTS = 60
local claimLocks: { [Player]: boolean } = {}

local function isPlayerInGroup(player: Player): boolean
	local groupId = Shared_SixSevenReward.GroupId

	local ok, inGroup = pcall(function()
		return player:IsInGroup(groupId)
	end)
	if ok and inGroup == true then
		return true
	end

	local okRank, rank = pcall(function()
		return player:GetRankInGroup(groupId)
	end)
	return okRank and type(rank) == "number" and rank > 0
end

function Server_SixSevenReward.TryClaim(player: Player): (boolean, string?)
	if claimLocks[player] then
		return false, "Already processing"
	end
	claimLocks[player] = true

	local function finish()
		claimLocks[player] = nil
	end

	local data = Server_Data:GetData(player)
	if not data then
		finish()
		return false, "No data"
	end

	if data.SixSevenGroupRewardClaimed == true then
		finish()
		return false, "Already claimed"
	end

	if not isPlayerInGroup(player) then
		finish()
		return false, "Not in group"
	end

	local inventory = data.Inventory
	if type(inventory) ~= "table" or #inventory >= INVENTORY_MAX_SLOTS then
		finish()
		return false, "Inventory is full"
	end

	local newIndex = Server_Data:AddInventoryItem(player, {
		ItemType = "LuckyBlock",
		ConfigName = Shared_SixSevenReward.LuckyBlockConfigName,
		Data = {},
	})
	if not newIndex then
		finish()
		return false, "Inventory is full"
	end

	data.SixSevenGroupRewardClaimed = true
	local replica = Server_Data:GetReplica(player)
	if replica then
		replica:SetValue({ "SixSevenGroupRewardClaimed" }, true)
	end

	finish()
	return true, nil
end

function Server_SixSevenReward.ClearPlayer(player: Player)
	claimLocks[player] = nil
end

return Server_SixSevenReward
