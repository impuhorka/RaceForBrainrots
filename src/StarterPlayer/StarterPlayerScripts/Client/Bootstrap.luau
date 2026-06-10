local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local ReplicaController = SharedModules.require("ReplicaController")
local ClientLoader = require(script.Parent.Loader)

local Bootstrap = {}

local DATA_WAIT_SECONDS = 30

local function waitForPlayerReplica(player: Player)
	for _, replica in pairs(ReplicaController._replicas) do
		if replica.Class == "PlayerData" and replica.Tags.UserId == player.UserId then
			return replica
		end
	end

	local playerReplica = nil
	local replicaReceived = false

	ReplicaController.ReplicaOfClassCreated("PlayerData", function(replica)
		if replica.Tags.UserId == player.UserId then
			playerReplica = replica
			replicaReceived = true
		end
	end)

	local waited = 0
	while not replicaReceived and waited < DATA_WAIT_SECONDS do
		task.wait(0.1)
		waited += 0.1
	end

	return playerReplica
end

local COLON_INIT_MODULES = {
	Client_Data = true,
	Client_PlotBillboards = true,
}

local function initModule(moduleName: string, methodName: string?)
	local module = ClientLoader.require(moduleName)
	local initMethod = methodName or "Init"
	local init = module[initMethod]
	if type(init) ~= "function" then
		return
	end

	if COLON_INIT_MODULES[moduleName] then
		init(module)
	else
		init()
	end
end

local function runPostDataSystems()
	local postDataModules = {
		{ "Client_Data", "Init" },
		{ "Client_PlotBillboards", "Init" },
		{ "Client_Visuals" },
		{ "Client_Hotbar" },
		{ "Client_Inventory" },
		{ "Client_EquipHold" },
		{ "Client_PlotSlotPlace" },
		{ "Client_PlotBrainrotAnimations" },
		{ "Client_PlotUpgradeVfx" },
		{ "Client_CashAddingPopups" },
		{ "Client_PlotCashCollect" },
		{ "Client_PlotSpawnAnimation" },
		{ "Client_SellBillboard" },
		{ "Client_PlotUpgradeSign" },
		{ "Client_InteractStorePrompts" },
		{ "Client_SpeedStore" },
		{ "Client_StrengthStore" },
		{ "Client_SlowModeButton" },
		{ "Client_BackgroundMusic" },
		{ "Client_LuckyBlockOpening" },
		{ "Client_GameProcessLuckyBlocks" },
		{ "Client_Index" },
		{ "Client_RainbowBrainrots" },
		{ "Client_OfflineCash" },
		{ "Client_Rebirth" },
		{ "Client_Settings" },
	}

	for _, entry in postDataModules do
		initModule(entry[1], entry[2])
	end

	require(script.Parent.Parent.Animations)
	require(script.Parent.Parent.UI)
end

function Bootstrap.start()
	local player = Players.LocalPlayer

	task.spawn(function()
		ClientLoader.require("Client_SoundPreload").Init()
	end)

	ClientLoader.require("Client_Messaging").Init()
	ClientLoader.require("Client_ProximityPrompts").Init()
	ClientLoader.require("Client_PlotSlotSurfaces").Init()
	ClientLoader.require("Client_FOV").init()

	ReplicaController.RequestData()

	local waited = 0
	while not ReplicaController.InitialDataReceived and waited < DATA_WAIT_SECONDS do
		task.wait(0.1)
		waited += 0.1
	end

	if not ReplicaController.InitialDataReceived then
		player:Kick("Failed to load game data. Please rejoin.")
		return
	end

	repeat
		task.wait()
	until player:FindFirstChild("leaderstats")

	if not waitForPlayerReplica(player) then
		player:Kick("Failed to load player data. Please rejoin.")
		return
	end

	runPostDataSystems()
end

return Bootstrap