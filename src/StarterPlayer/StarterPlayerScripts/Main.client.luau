local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

local ReplicaController = require(ReplicatedStorage.Modules.Dependencies.ReplicaController)
local Client_Data = require(script.Parent.Client.Client_Data)

ReplicaController.RequestData()

local maxWait = 30
local waited = 0

while not ReplicaController.InitialDataReceived and waited < maxWait do
	task.wait(0.1)
	waited += 0.1
end

if not ReplicaController.InitialDataReceived then
	Player:Kick("Failed to load game data. Please rejoin.")
	return
end

repeat
	task.wait()
until Player:FindFirstChild("leaderstats")

local playerReplica = nil

for _, replica in pairs(ReplicaController._replicas) do
	if replica.Class == "PlayerData" and replica.Tags.UserId == Player.UserId then
		playerReplica = replica
		break
	end
end

if not playerReplica then
	local replicaReceived = false

	ReplicaController.ReplicaOfClassCreated("PlayerData", function(replica)
		if replica.Tags.UserId == Player.UserId then
			playerReplica = replica
			replicaReceived = true
		end
	end)

	waited = 0
	while not replicaReceived and waited < maxWait do
		task.wait(0.1)
		waited += 0.1
	end

	if not playerReplica then
		Player:Kick("Failed to load player data. Please rejoin.")
		return
	end
end

Client_Data:Init()

require(script.Parent.Animations)
require(script.Parent.UI)
