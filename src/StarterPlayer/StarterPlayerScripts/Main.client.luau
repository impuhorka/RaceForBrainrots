local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

local ReplicaController = require(ReplicatedStorage.Modules.Dependencies.ReplicaController)
local Client_Data = require(script.Parent.Client.Client_Data)
local Client_FOV = require(script.Parent.Client.Client_FOV)
local Client_Messaging = require(script.Parent.Client.Client_Messaging)
local Client_PlotBillboards = require(script.Parent.Client.Client_PlotBillboards)
local Client_ProximityPrompts = require(script.Parent.Client.Client_ProximityPrompts)
local Client_SoundPreload = require(script.Parent.Client.Client_SoundPreload)

task.spawn(Client_SoundPreload.Init)

Client_Messaging.Init()
Client_ProximityPrompts.Init()

Client_PlotBillboards:Init()

local Client_PlotSlotSurfaces = require(script.Parent.Client.Client_PlotSlotSurfaces)
Client_PlotSlotSurfaces.Init()

Client_FOV.init()

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

local Client_Visuals = require(script.Parent.Client.Client_Visuals)
Client_Visuals.Init()

local Client_Hotbar = require(script.Parent.Client.Client_Hotbar)
Client_Hotbar.Init()

local Client_Inventory = require(script.Parent.Client.Client_Inventory)
Client_Inventory.Init()

local Client_EquipHold = require(script.Parent.Client.Client_EquipHold)
Client_EquipHold.Init()

local Client_PlotSlotPlace = require(script.Parent.Client.Client_PlotSlotPlace)
Client_PlotSlotPlace.Init()

local Client_PlotBrainrotAnimations = require(script.Parent.Client.Client_PlotBrainrotAnimations)
Client_PlotBrainrotAnimations.Init()

local Client_PlotUpgradeVfx = require(script.Parent.Client.Client_PlotUpgradeVfx)
Client_PlotUpgradeVfx.Init()

local Client_CashAddingPopups = require(script.Parent.Client.Client_CashAddingPopups)
Client_CashAddingPopups.Init()

local Client_PlotCashCollect = require(script.Parent.Client.Client_PlotCashCollect)
Client_PlotCashCollect.Init()

local Client_PlotSpawnAnimation = require(script.Parent.Client.Client_PlotSpawnAnimation)
Client_PlotSpawnAnimation.Init()

local Client_SellBillboard = require(script.Parent.Client.Client_SellBillboard)
Client_SellBillboard.Init()

local Client_PlotUpgradeSign = require(script.Parent.Client.Client_PlotUpgradeSign)
Client_PlotUpgradeSign.Init()

local Client_InteractStorePrompts = require(script.Parent.Client.Client_InteractStorePrompts)
Client_InteractStorePrompts.Init()

local Client_SpeedStore = require(script.Parent.Client.Client_SpeedStore)
Client_SpeedStore.Init()

local Client_StrengthStore = require(script.Parent.Client.Client_StrengthStore)
Client_StrengthStore.Init()

local Client_SlowModeButton = require(script.Parent.Client.Client_SlowModeButton)
Client_SlowModeButton.Init()

local Client_BackgroundMusic = require(script.Parent.Client.Client_BackgroundMusic)
Client_BackgroundMusic.Init()

local Client_LuckyBlockOpening = require(script.Parent.Client.Client_LuckyBlockOpening)
Client_LuckyBlockOpening.Init()

local Client_Index = require(script.Parent.Client.Client_Index)
Client_Index.Init()

local Client_RainbowBrainrots = require(script.Parent.Client.Client_RainbowBrainrots)
Client_RainbowBrainrots.Init()

require(script.Parent.Animations)
require(script.Parent.UI)
