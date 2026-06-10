local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local RunService = game:GetService("RunService")
local ClientLoader = require(script.Parent.Parent.Loader)

local Shared_BrainrotAnimations = SharedModules.require("Shared_BrainrotAnimations")
local Shared_BrainrotBillboard = SharedModules.require("Shared_BrainrotBillboard")
local Shared_LuckyBlockBillboard = SharedModules.require("Shared_LuckyBlockBillboard")
local Shared_LuckyBlocks = SharedModules.require("Shared_LuckyBlocks")
local Shared_Weight = SharedModules.require("Shared_Weight")

local Client_Data = ClientLoader.require("Client_Data")
local Client_Equip = ClientLoader.require("Client_Equip")

local localPlayer = Players.LocalPlayer

local Client_EquipHold = {}

local HELD_MODEL_NAME = "EquippedBrainrot"
local HOLD_ANIMATION_NAME = "TwoHandsHolding"
local TORSO_FORWARD_OFFSET = 1
local TORSO_HEIGHT_OFFSET = 0.75
local LUCKYBLOCK_FORWARD_OFFSET_DELTA = 0.25
local LUCKYBLOCK_HEIGHT_OFFSET_DELTA = -1
local HOLD_ANIMATION_FADE_TIME = 0.1
local HOLD_ANIMATION_WEIGHT = 1
local HOLD_ANIMATION_SPEED = 1

type EquipVisualItem = {
	ItemType: string,
	ConfigName: string,
	Modifier: string,
	Level: number,
	BaseWeight: number?,
	Weight: number?,
}

type HoldAnimState = {
	track: AnimationTrack?,
	watchdog: RBXScriptConnection?,
	movementConn: RBXScriptConnection?,
	stateConn: RBXScriptConnection?,
	aggressive: boolean,
}

local heldModel: Model? = nil
local remoteHeldModels: { [Player]: Model } = {}
local holdAnimByCharacter: { [Model]: HoldAnimState } = {}

local EQUIPPED_ATTRS = {
	"EquippedItemType",
	"EquippedConfigName",
	"EquippedModifier",
	"EquippedLevel",
	"EquippedBaseWeight",
	"EquippedWeight",
}

local function shouldPlayAnimations(): boolean
	return Client_Data:GetValue("Animations") ~= false
end

local function getHoldAnimation(): Animation?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local otherAnimations = assets and assets:FindFirstChild("OtherAnimations")
	local anim = otherAnimations and otherAnimations:FindFirstChild(HOLD_ANIMATION_NAME)
	if anim and anim:IsA("Animation") then
		return anim
	end
	return nil
end

local function getBrainrotModel(configName: string, modifier: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local brainrots = assets and assets:FindFirstChild("Brainrots")
	local folder = brainrots and brainrots:FindFirstChild(configName)
	if not folder then
		return nil
	end

	local template = folder:FindFirstChild(modifier) or folder:FindFirstChild("Normal")
	if not template or not template:IsA("Model") then
		return nil
	end

	return template:Clone()
end

local function getLuckyBlockModel(configName: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local luckyBlocks = assets and assets:FindFirstChild("LuckyBlocks")
	local template = luckyBlocks and luckyBlocks:FindFirstChild(configName)
	if not template or not template:IsA("Model") then
		return nil
	end

	return template:Clone()
end

local function getTorsoPart(character: Model): BasePart?
	return character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
		or character.PrimaryPart
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
				state.track:Stop(0.2)
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
		state.track:Stop(0.2)
	end

	holdAnimByCharacter[character] = nil
end

local function playHoldAnimation(character: Model, aggressiveForMovement: boolean)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animation = getHoldAnimation()
	if not humanoid or not animation then
		return
	end

	stopHoldAnimation(character)

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = true
	track:Play(HOLD_ANIMATION_FADE_TIME, HOLD_ANIMATION_WEIGHT, HOLD_ANIMATION_SPEED)

	local state: HoldAnimState = {
		track = track,
		aggressive = aggressiveForMovement,
	}

	holdAnimByCharacter[character] = state
	enforceHoldTrackPriority(state)

	state.watchdog = RunService.Heartbeat:Connect(function()
		if not state.track or not character.Parent then
			return
		end
		enforceHoldTrackPriority(state)
	end)

	if aggressiveForMovement then
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
end

local function getLuckyBlockHoldScaleRatio(model: Model): number
	local originScale = Shared_Weight.GetLuckyBlockModelOriginScale(model)
	local ok, currentScale = pcall(function()
		return model:GetScale()
	end)
	if ok and type(currentScale) == "number" and originScale > 0 then
		return math.max(1, currentScale / originScale)
	end
	return 1
end

local function attachItemToTorso(
	model: Model,
	character: Model,
	modelName: string,
	forwardOffsetDelta: number?,
	heightOffsetDelta: number?,
	useLuckyBlockSizing: boolean?
): boolean
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
	end

	local primaryPart = model.PrimaryPart
	local attachPart = getTorsoPart(character)
	if not primaryPart or not attachPart then
		return false
	end

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
		end
	end

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= primaryPart then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = primaryPart
			weld.Part1 = part
			weld.Parent = primaryPart
		end
	end

	local scaleRatio = if useLuckyBlockSizing then getLuckyBlockHoldScaleRatio(model) else 1
	local resolvedForwardOffset = (TORSO_FORWARD_OFFSET + (forwardOffsetDelta or 0)) * scaleRatio
	local resolvedHeightOffset = (TORSO_HEIGHT_OFFSET + (heightOffsetDelta or 0)) * scaleRatio

	local halfDepth: number
	local heightLift: number
	if useLuckyBlockSizing then
		local _, boundsSize = model:GetBoundingBox()
		halfDepth = boundsSize.Z * 0.5
		heightLift = boundsSize.Y * 0.35
	else
		halfDepth = primaryPart.Size.Z / 2
		heightLift = primaryPart.Size.Y * 0.3
	end

	local offset = CFrame.new(
		0,
		heightLift + resolvedHeightOffset,
		-halfDepth - resolvedForwardOffset
	)
	model:PivotTo(attachPart.CFrame * offset)

	local torsoWeld = Instance.new("WeldConstraint")
	torsoWeld.Part0 = attachPart
	torsoWeld.Part1 = primaryPart
	torsoWeld.Parent = primaryPart

	model.Name = modelName
	model.Parent = character

	return true
end

local function resolveItemWeights(item: EquipVisualItem): (number?, number?)
	if item.ItemType == "Brainrot" then
		return Shared_Weight.ResolveBrainrotWeights({
			BaseWeight = item.BaseWeight,
			Weight = item.Weight,
		}, item.ConfigName)
	end

	local defaultBase = Shared_LuckyBlocks.GetBaseWeight(item.ConfigName)
	return Shared_Weight.ResolveLuckyBlockWeights({
		BaseWeight = item.BaseWeight,
		Weight = item.Weight,
	}, defaultBase)
end

local function buildHeldModel(item: EquipVisualItem): Model?
	local forwardOffsetDelta = 0
	local heightOffsetDelta = 0
	local model: Model? = nil

	if item.ItemType == "Brainrot" then
		model = getBrainrotModel(item.ConfigName, item.Modifier)
	elseif item.ItemType == "LuckyBlock" then
		if not Shared_LuckyBlocks.Data[item.ConfigName] then
			return nil
		end
		model = getLuckyBlockModel(item.ConfigName)
		forwardOffsetDelta = LUCKYBLOCK_FORWARD_OFFSET_DELTA
		heightOffsetDelta = LUCKYBLOCK_HEIGHT_OFFSET_DELTA
	else
		return nil
	end

	if not model then
		return nil
	end

	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
	end

	local baseWeight, rolledWeight = resolveItemWeights(item)
	if item.ItemType == "Brainrot" then
		Shared_Weight.ApplyBrainrotScale(model, baseWeight, rolledWeight)
	else
		Shared_Weight.ApplyLuckyBlockScale(model, baseWeight, rolledWeight)
	end

	model:SetAttribute("ConfigName", item.ConfigName)
	model:SetAttribute("_ForwardOffsetDelta", forwardOffsetDelta)
	model:SetAttribute("_HeightOffsetDelta", heightOffsetDelta)
	model:SetAttribute("_UseLuckyBlockSizing", item.ItemType == "LuckyBlock")

	if item.ItemType == "Brainrot" then
		Shared_BrainrotBillboard.Setup(model, item.ConfigName, item.Modifier, item.Level, baseWeight, rolledWeight)
	else
		Shared_LuckyBlockBillboard.Setup(model, item.ConfigName, baseWeight, rolledWeight)
	end

	return model
end

local function mountHeldModel(
	model: Model,
	character: Model,
	modelName: string,
	itemType: string,
	playCharacterAnimations: boolean
): boolean
	local forwardOffsetDelta = model:GetAttribute("_ForwardOffsetDelta")
	local heightOffsetDelta = model:GetAttribute("_HeightOffsetDelta")
	local useLuckyBlockSizing = model:GetAttribute("_UseLuckyBlockSizing") == true

	if not attachItemToTorso(
		model,
		character,
		modelName,
		if type(forwardOffsetDelta) == "number" then forwardOffsetDelta else 0,
		if type(heightOffsetDelta) == "number" then heightOffsetDelta else 0,
		useLuckyBlockSizing
	) then
		return false
	end

	if playCharacterAnimations then
		playHoldAnimation(character, itemType == "LuckyBlock")
		if itemType == "Brainrot" then
			local configName = model:GetAttribute("ConfigName")
			if type(configName) == "string" and configName ~= "" then
				Shared_BrainrotAnimations.PlayIdle(model, configName)
			end
		end
	end

	return true
end

local function clearHeldModel(model: Model?, character: Model?)
	if model then
		Shared_BrainrotAnimations.StopIdle(model)
		model:Destroy()
	end
	if character then
		stopHoldAnimation(character)
	end
end

local function clearLocalHeldVisual()
	local character = localPlayer.Character
	clearHeldModel(heldModel, character)
	heldModel = nil
end

local function clearRemoteHeldVisual(player: Player)
	local character = player.Character
	clearHeldModel(remoteHeldModels[player], character)
	remoteHeldModels[player] = nil
end

local function getLocalEquipItem(): EquipVisualItem?
	local inventoryIndex = Client_Equip.GetEquippedIndex()
	if not inventoryIndex then
		return nil
	end

	local inventory = Client_Data:GetValue("Inventory") or {}
	local item = inventory[inventoryIndex]
	if not item or type(item.ConfigName) ~= "string" then
		return nil
	end

	if item.ItemType ~= "Brainrot" and item.ItemType ~= "LuckyBlock" then
		return nil
	end

	local data = item.Data or {}
	return {
		ItemType = item.ItemType,
		ConfigName = item.ConfigName,
		Modifier = data.Modifier or "Normal",
		Level = math.max(1, tonumber(data.Level) or 1),
		BaseWeight = tonumber(data.BaseWeight),
		Weight = tonumber(data.Weight),
	}
end

local function getRemoteEquipItem(player: Player): EquipVisualItem?
	local itemType = player:GetAttribute("EquippedItemType")
	if type(itemType) ~= "string" or itemType == "" then
		return nil
	end

	local configName = player:GetAttribute("EquippedConfigName")
	if type(configName) ~= "string" or configName == "" then
		return nil
	end

	return {
		ItemType = itemType,
		ConfigName = configName,
		Modifier = player:GetAttribute("EquippedModifier") or "Normal",
		Level = math.max(1, tonumber(player:GetAttribute("EquippedLevel")) or 1),
		BaseWeight = tonumber(player:GetAttribute("EquippedBaseWeight")),
		Weight = tonumber(player:GetAttribute("EquippedWeight")),
	}
end

local function refreshLocalHeldVisual()
	clearLocalHeldVisual()

	local item = getLocalEquipItem()
	local character = localPlayer.Character
	if not item or not character then
		return
	end

	local model = buildHeldModel(item)
	if not model then
		return
	end

	if not mountHeldModel(model, character, HELD_MODEL_NAME, item.ItemType, shouldPlayAnimations()) then
		model:Destroy()
		return
	end

	heldModel = model
end

local function refreshRemoteHeldVisual(player: Player)
	if player == localPlayer then
		return
	end

	clearRemoteHeldVisual(player)

	local item = getRemoteEquipItem(player)
	local character = player.Character
	if not item or not character then
		return
	end

	local model = buildHeldModel(item)
	if not model then
		return
	end

	local modelName = `EquippedItem_{player.UserId}`
	if not mountHeldModel(model, character, modelName, item.ItemType, true) then
		model:Destroy()
		return
	end

	remoteHeldModels[player] = model
end

local function refreshHeldAnimations()
	local character = localPlayer.Character
	if not character or not heldModel then
		return
	end

	if not shouldPlayAnimations() then
		stopHoldAnimation(character)
		Shared_BrainrotAnimations.StopIdle(heldModel)
		return
	end

	local itemType = heldModel:GetAttribute("_UseLuckyBlockSizing") == true and "LuckyBlock" or "Brainrot"
	playHoldAnimation(character, itemType == "LuckyBlock")

	local configName = heldModel:GetAttribute("ConfigName")
	if type(configName) == "string" and configName ~= "" then
		Shared_BrainrotAnimations.PlayIdle(heldModel, configName)
	end
end

local function bindRemotePlayer(player: Player)
	if player == localPlayer then
		return
	end

	for _, attrName in EQUIPPED_ATTRS do
		player:GetAttributeChangedSignal(attrName):Connect(function()
			refreshRemoteHeldVisual(player)
		end)
	end

	player.CharacterAdded:Connect(function()
		task.defer(function()
			refreshRemoteHeldVisual(player)
		end)
	end)

	player.CharacterRemoving:Connect(function()
		clearRemoteHeldVisual(player)
	end)

	refreshRemoteHeldVisual(player)
end

function Client_EquipHold.Init()
	Client_Data.WaitUntilReady()

	Client_Equip.OnChanged(refreshLocalHeldVisual)

	localPlayer.CharacterRemoving:Connect(clearLocalHeldVisual)
	localPlayer.CharacterAdded:Connect(function()
		task.defer(refreshLocalHeldVisual)
	end)

	for _, player in Players:GetPlayers() do
		bindRemotePlayer(player)
	end
	Players.PlayerAdded:Connect(bindRemotePlayer)
	Players.PlayerRemoving:Connect(function(player)
		clearRemoteHeldVisual(player)
	end)

	refreshLocalHeldVisual()

	Client_Data:ListenToChange("Animations", refreshHeldAnimations)
end

return Client_EquipHold