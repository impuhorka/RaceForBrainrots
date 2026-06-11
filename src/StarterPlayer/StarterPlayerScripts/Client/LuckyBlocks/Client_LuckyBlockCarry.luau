local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local ClientLoader = require(script.Parent.Parent.Loader)

local Shared_GameProcess = SharedModules.require("Shared_GameProcess")
local Shared_RoadGradient = SharedModules.require("Shared_RoadGradient")
local Shared_LuckyBlocks = SharedModules.require("Shared_LuckyBlocks")
local Shared_Rarities = SharedModules.require("Shared_Rarities")
local Shared_Sounds = SharedModules.require("Shared_Sounds")
local Client_Data = ClientLoader.require("Client_Data")
local Client_Equip = ClientLoader.require("Client_Equip")
local Client_FOV = ClientLoader.require("Client_FOV")
local Client_Hotbar = ClientLoader.require("Client_Hotbar")
local Client_AudioSettings = ClientLoader.require("Client_AudioSettings")
local Client_SoundPreload = ClientLoader.require("Client_SoundPreload")
local Client_Messaging = ClientLoader.require("Client_Messaging")
local Client_TadaEffect = ClientLoader.require("Client_TadaEffect")

local localPlayer = Players.LocalPlayer

local Client_LuckyBlockCarry = {}

local CARRY_ANIMATION_ID = "rbxassetid://70677894867741"
local HOLD_ANIMATION_FADE_TIME = 0.1
local HOLD_ANIMATION_WEIGHT = 1
local HOLD_ANIMATION_SPEED = 1

type HoldAnimState = {
	track: AnimationTrack?,
	watchdog: RBXScriptConnection?,
	movementConn: RBXScriptConnection?,
	stateConn: RBXScriptConnection?,
}

local holdAnimByCharacter: { [Model]: HoldAnimState } = {}
local actionButton: GuiObject?
local dropButton: ImageButton?
local dropButtonConnected = false
local roadFrontZ: number? = nil
local roadFrontCheckConn: RBXScriptConnection? = nil
local INVENTORY_WAIT_SECONDS = 2
local deliveryCelebrationPlayed = false

local function getCarryAnimation(): Animation
	local animation = Instance.new("Animation")
	animation.AnimationId = CARRY_ANIMATION_ID
	return animation
end

local function tryInitRoadFrontZ(): boolean
	local zones = Workspace:FindFirstChild("Zones")
	local enterPart = zones and zones:FindFirstChild("EnterPart")
	if not enterPart or not enterPart:IsA("BasePart") then
		return false
	end

	roadFrontZ = Shared_RoadGradient.GetRoadFrontZ(enterPart)
	return true
end

local function enforceHoldTrackPriority(state: HoldAnimState)
	local track = state.track
	if not track then
		return
	end

	track.Priority = Enum.AnimationPriority.Action4
	if not track.IsPlaying then
		track:Play(HOLD_ANIMATION_FADE_TIME, HOLD_ANIMATION_WEIGHT, HOLD_ANIMATION_SPEED)
	end
	track:AdjustWeight(HOLD_ANIMATION_WEIGHT, 0)
	track:AdjustSpeed(HOLD_ANIMATION_SPEED)
end

local function stopHoldAnimation(character: Model?)
	if not character then
		for trackedCharacter, state in holdAnimByCharacter do
			if state.watchdog then
				state.watchdog:Disconnect()
			end
			if state.movementConn then
				state.movementConn:Disconnect()
			end
			if state.stateConn then
				state.stateConn:Disconnect()
			end
			if state.track then
				state.track:Stop(0)
			end
			holdAnimByCharacter[trackedCharacter] = nil
		end
		return
	end

	local state = holdAnimByCharacter[character]
	if not state then
		return
	end

	if state.watchdog then
		state.watchdog:Disconnect()
	end
	if state.movementConn then
		state.movementConn:Disconnect()
	end
	if state.stateConn then
		state.stateConn:Disconnect()
	end
	if state.track then
		state.track:Stop(0)
	end

	holdAnimByCharacter[character] = nil
end

local function hideCarriedLuckyBlockModel(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Model") and string.find(child.Name, "CarriedLuckyBlock", 1, true) then
			for _, desc in child:GetDescendants() do
				if desc:IsA("BasePart") then
					desc.LocalTransparencyModifier = 1
				elseif desc:IsA("BillboardGui") then
					desc.Enabled = false
				end
			end
		end
	end
end

local function resolveActionUi()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	local main = playerGui and playerGui:FindFirstChild("Main")
	if not main then
		return
	end

	local foundActionButton = main:FindFirstChild("ActionButton")
	if foundActionButton and foundActionButton:IsA("GuiObject") then
		actionButton = foundActionButton
	end

	if actionButton then
		local foundDrop = actionButton:FindFirstChild("DropLuckyBlock", true)
		if foundDrop and foundDrop:IsA("ImageButton") then
			dropButton = foundDrop
		end
	end
end

local function getLocalDropRootCFrame(): CFrame?
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.CFrame
	end
	return nil
end

local function onDropClicked()
	local events = ReplicatedStorage:FindFirstChild("Events")
	local gameProcessHandler = events and events:FindFirstChild("GameProcessHandler")
	if gameProcessHandler and gameProcessHandler:IsA("RemoteEvent") then
		gameProcessHandler:FireServer("DropCarriedLuckyBlock", getLocalDropRootCFrame())
	end
end

local function bindDropButton()
	if dropButton and not dropButtonConnected then
		dropButtonConnected = true
		dropButton.Activated:Connect(onDropClicked)
	end
end

local function updateActionButtonVisibility(carrying: boolean)
	if not actionButton then
		resolveActionUi()
		bindDropButton()
	end
	if actionButton then
		actionButton.Visible = carrying
	end
	if dropButton then
		dropButton.Visible = carrying
	end
end

local function tryInitializeActionUi(): boolean
	resolveActionUi()
	bindDropButton()
	updateActionButtonVisibility(Client_LuckyBlockCarry.IsCarrying())
	return actionButton ~= nil
end

local function playLuckyBlockDeliveredSfx()
	if Client_AudioSettings.GetSfxVolume() <= 0 then
		return
	end

	local sfx = Shared_Sounds.SFX or {}
	local volumes = Shared_Sounds.SFXVolume or {}

	local function play(soundId: string?, volume: number)
		if type(soundId) == "string" and soundId ~= "" then
			Client_SoundPreload.Play(soundId, volume)
		end
	end

	play(sfx.LuckyBlockCollect, volumes.LuckyBlockCollect or 1)
	play(sfx.LuckyBlockCollected, volumes.LuckyBlockCollected or 1)
end

local function getRarityDisplayName(rarity: string?): string
	if type(rarity) ~= "string" or rarity == "" then
		return "Unknown"
	end

	local rarityData = Shared_Rarities.Data[rarity]
	if rarityData and type(rarityData.DisplayName) == "string" and rarityData.DisplayName ~= "" then
		return rarityData.DisplayName
	end

	return rarity
end

local function resolveCollectedLuckyBlockRarity(rarity: string?): string
	if type(rarity) == "string" and rarity ~= "" then
		return rarity
	end

	local carriedRarity = localPlayer:GetAttribute("CarriedLuckyBlockRarity")
	if type(carriedRarity) == "string" and carriedRarity ~= "" then
		return carriedRarity
	end

	local configName = localPlayer:GetAttribute("CarriedLuckyBlockConfigName")
	if type(configName) == "string" then
		local config = Shared_LuckyBlocks.Data[configName]
		if config and type(config.Rarity) == "string" and config.Rarity ~= "" then
			return config.Rarity
		end
	end

	return "Unknown"
end

local function showLuckyBlockCollectedMessage(rarity: string?)
	local displayName = getRarityDisplayName(resolveCollectedLuckyBlockRarity(rarity))
	Client_Messaging.Show(("%s Lucky Block Collected!"):format(displayName), "green")
end

local function playDeliveryCelebration(rarity: string?)
	if deliveryCelebrationPlayed then
		return
	end
	deliveryCelebrationPlayed = true

	playLuckyBlockDeliveredSfx()
	showLuckyBlockCollectedMessage(rarity)
	Client_FOV.playPulse(1.15)
	Client_TadaEffect.Play()
end

local function clearLocalCarryVisualsImmediately()
	local character = localPlayer.Character
	updateActionButtonVisibility(false)
	stopHoldAnimation(character)
	if character then
		hideCarriedLuckyBlockModel(character)
	end
end

local function playCarryAnimation(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	stopHoldAnimation(character)

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local track = animator:LoadAnimation(getCarryAnimation())
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = true
	track:Play(HOLD_ANIMATION_FADE_TIME, HOLD_ANIMATION_WEIGHT, HOLD_ANIMATION_SPEED)

	local state: HoldAnimState = {
		track = track,
	}

	holdAnimByCharacter[character] = state
	enforceHoldTrackPriority(state)

	state.watchdog = RunService.Heartbeat:Connect(function()
		if not state.track or not character.Parent then
			return
		end
		enforceHoldTrackPriority(state)
	end)

	state.movementConn = humanoid.Running:Connect(function(_speed)
		enforceHoldTrackPriority(state)
	end)
	state.stateConn = humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Running
			or newState == Enum.HumanoidStateType.RunningNoPhysics then
			enforceHoldTrackPriority(state)
		end
	end)
end

local function tryDeliverLocalCarryVisual()
	if localPlayer:GetAttribute("CarryingLuckyBlock") ~= true then
		return
	end

	if roadFrontZ == nil and not tryInitRoadFrontZ() then
		return
	end

	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	if Shared_RoadGradient.HasPassedRoadFront(
		root.Position.Z,
		roadFrontZ,
		Shared_GameProcess.LuckyBlockDeliverZLead
	) then
		clearLocalCarryVisualsImmediately()
		playDeliveryCelebration()
	end
end

local function updateRoadFrontCheck()
	if roadFrontCheckConn then
		roadFrontCheckConn:Disconnect()
		roadFrontCheckConn = nil
	end

	if localPlayer:GetAttribute("CarryingLuckyBlock") ~= true then
		return
	end

	roadFrontCheckConn = RunService.RenderStepped:Connect(function()
		tryDeliverLocalCarryVisual()
	end)
	tryDeliverLocalCarryVisual()
end

local function refreshPlayerCarryVisual(player: Player)
	local carrying = player:GetAttribute("CarryingLuckyBlock") == true
	local character = player.Character

	if player == localPlayer then
		updateActionButtonVisibility(carrying)
		if carrying then
			deliveryCelebrationPlayed = false
			Client_Equip.Unequip()
			updateRoadFrontCheck()
		elseif roadFrontCheckConn then
			roadFrontCheckConn:Disconnect()
			roadFrontCheckConn = nil
		end
	end

	if not character then
		stopHoldAnimation(character)
		return
	end

	if carrying then
		playCarryAnimation(character)
	else
		stopHoldAnimation(character)
	end
end

local function bindPlayer(player: Player)
	player:GetAttributeChangedSignal("CarryingLuckyBlock"):Connect(function()
		refreshPlayerCarryVisual(player)
	end)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			refreshPlayerCarryVisual(player)
		end)
	end)

	player.CharacterRemoving:Connect(function()
		stopHoldAnimation(player.Character)
	end)

	refreshPlayerCarryVisual(player)
end

function Client_LuckyBlockCarry.IsCarrying(): boolean
	return localPlayer:GetAttribute("CarryingLuckyBlock") == true
end

local function waitForInventoryItem(inventoryIndex: number): boolean
	local deadline = os.clock() + INVENTORY_WAIT_SECONDS
	while os.clock() < deadline do
		local inventory = Client_Data:GetValue("Inventory") or {}
		if inventory[inventoryIndex] then
			return true
		end
		task.wait()
	end

	local inventory = Client_Data:GetValue("Inventory") or {}
	return inventory[inventoryIndex] ~= nil
end

local function onLuckyBlockDelivered(inventoryIndex: number, rarity: string?)
	if type(inventoryIndex) ~= "number" then
		return
	end

	task.spawn(function()
		if not waitForInventoryItem(inventoryIndex) then
			return
		end

		playDeliveryCelebration(rarity)
		Client_Hotbar.AssignItemToHotbar(inventoryIndex)
		Client_Equip.Equip(inventoryIndex, false)
	end)
end

function Client_LuckyBlockCarry.Init()
	tryInitRoadFrontZ()

	task.spawn(function()
		local playerGui = localPlayer:WaitForChild("PlayerGui", 30)
		if not playerGui then
			return
		end

		if not tryInitializeActionUi() then
			local main = playerGui:WaitForChild("Main", 30)
			if main then
				tryInitializeActionUi()
			end
		end

		if actionButton then
			return
		end

		local connection: RBXScriptConnection?
		connection = playerGui.ChildAdded:Connect(function(child)
			if child.Name ~= "Main" then
				return
			end
			if tryInitializeActionUi() and connection then
				connection:Disconnect()
			end
		end)
	end)

	Client_Equip.OnChanged(function()
		if Client_LuckyBlockCarry.IsCarrying() then
			updateActionButtonVisibility(true)
		end
	end)

	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(player)
		stopHoldAnimation(player.Character)
	end)

	local events = ReplicatedStorage:WaitForChild("Events", 10)
	local gameProcessHandler = events and events:WaitForChild("GameProcessHandler", 10)
	if gameProcessHandler and gameProcessHandler:IsA("RemoteEvent") then
		gameProcessHandler.OnClientEvent:Connect(function(action: string, inventoryIndex: any, rarity: any)
			if action == "LuckyBlockDelivered" then
				onLuckyBlockDelivered(inventoryIndex, rarity)
				return
			end

			if action == "UnluckyMapClose" and type(inventoryIndex) == "string" then
				clearLocalCarryVisualsImmediately()
				Client_Messaging.Show(inventoryIndex, "red")
				Client_FOV.playUnluckyForfeit()
				return
			end

			if action == "CarryFeedback" and type(inventoryIndex) == "string" then
				Client_Messaging.Show(inventoryIndex, "red")
			end
		end)
	end
end

return Client_LuckyBlockCarry
