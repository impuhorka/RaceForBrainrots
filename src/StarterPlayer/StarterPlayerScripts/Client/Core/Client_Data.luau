local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local ReplicaController = SharedModules.require("ReplicaController")

local Player = Players.LocalPlayer

local Module = {}

Module.PlayerData = nil
Module.PlayerReplica = nil
Module.IsReady = false

function Module.WaitUntilReady()
	while not Module.IsReady do
		task.wait()
	end
end

function Module:GetData()
	return Module.PlayerData or {}
end

function Module:GetReplica()
	return Module.PlayerReplica
end

function Module:GetValue(path)
	local data = Module.PlayerData
	if not data then
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

function Module:ListenToChange(path, listener)
	local replica = Module.PlayerReplica
	if not replica then
		return nil
	end

	local pathArray = {}
	for part in string.gmatch(path, "[^.]+") do
		table.insert(pathArray, part)
	end

	return replica:ListenToChange(pathArray, listener)
end

function Module:Init()
	local function setPlayerReplica(replica)
		if replica.Tags.UserId and replica.Tags.UserId == Player.UserId then
			Module.PlayerReplica = replica
			Module.PlayerData = replica.Data
			Module.IsReady = true
			return true
		end
		return false
	end

	if ReplicaController.InitialDataReceived then
		for _, replica in pairs(ReplicaController._replicas) do
			if replica.Class == "PlayerData" and setPlayerReplica(replica) then
				break
			end
		end
	end

	ReplicaController.ReplicaOfClassCreated("PlayerData", function(replica)
		setPlayerReplica(replica)
	end)
end

return Module