local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared_BrainrotBillboard = require(ReplicatedStorage.Modules.Shared_BrainrotBillboard)
local Shared_Brainrots = require(ReplicatedStorage.Modules.Shared_Brainrots)
local Shared_LuckyBlocks = require(ReplicatedStorage.Modules.Shared_LuckyBlocks)

local Client_Data = require(script.Parent.Client_Data)
local Client_Equip = require(script.Parent.Client_Equip)

local localPlayer = Players.LocalPlayer

local Client_EquipHold = {}

local HELD_MODEL_NAME = "EquippedBrainrot"
local HOLD_ANIMATION_NAME = "TwoHandsHolding"
local TORSO_FORWARD_OFFSET = 1
local TORSO_HEIGHT_OFFSET = 0.75
local LUCKYBLOCK_FORWARD_OFFSET_DELTA = 0.25
local LUCKYBLOCK_HEIGHT_OFFSET_DELTA = -1
local HOLD_ANIMATION_FADE_TIME = 0.1
local HOLD_ANIMATION_WEIGHT = 10
local HOLD_ANIMATION_SPEED = 1

local holdTrack: AnimationTrack? = nil
local holdAnimator: Animator? = nil
local heldModel: Model? = nil
local holdWatchdogConnection: RBXScriptConnection? = nil

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

local function stopHoldAnimation()
	if holdWatchdogConnection then
		holdWatchdogConnection:Disconnect()
		holdWatchdogConnection = nil
	end

	if holdTrack then
		holdTrack:Stop(0.2)
		holdTrack = nil
	end

	holdAnimator = nil
end

local function playHoldAnimation(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animation = getHoldAnimation()
	if not humanoid or not animation then
		return
	end

	stopHoldAnimation()

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	holdAnimator = animator
	holdTrack = animator:LoadAnimation(animation)
	holdTrack.Priority = Enum.AnimationPriority.Action4
	holdTrack.Looped = true
	holdTrack:Play(HOLD_ANIMATION_FADE_TIME, HOLD_ANIMATION_WEIGHT, HOLD_ANIMATION_SPEED)
	holdTrack:AdjustWeight(HOLD_ANIMATION_WEIGHT, 0)
	holdTrack:AdjustSpeed(HOLD_ANIMATION_SPEED)

	holdWatchdogConnection = RunService.Heartbeat:Connect(function()
		if not holdTrack or not holdAnimator or holdAnimator.Parent == nil then
			return
		end

		if not holdTrack.IsPlaying then
			holdTrack.Priority = Enum.AnimationPriority.Action4
			holdTrack:Play(HOLD_ANIMATION_FADE_TIME, HOLD_ANIMATION_WEIGHT, HOLD_ANIMATION_SPEED)
		end

		-- Keep arm pose dominant against locomotion tracks.
		holdTrack.Priority = Enum.AnimationPriority.Action4
		holdTrack:AdjustWeight(HOLD_ANIMATION_WEIGHT, 0)
		holdTrack:AdjustSpeed(HOLD_ANIMATION_SPEED)
	end)
end

local function clearHeldVisual()
	stopHoldAnimation()

	if heldModel then
		heldModel:Destroy()
		heldModel = nil
	end
end

local function attachBrainrotToTorso(model: Model, character: Model, forwardOffsetDelta: number?, heightOffsetDelta: number?): boolean
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

	local resolvedForwardOffset = TORSO_FORWARD_OFFSET + (forwardOffsetDelta or 0)
	local resolvedHeightOffset = TORSO_HEIGHT_OFFSET + (heightOffsetDelta or 0)

	local offset = CFrame.new(
		0,
		primaryPart.Size.Y * 0.3 + resolvedHeightOffset,
		-primaryPart.Size.Z / 2 - resolvedForwardOffset
	)
	model:PivotTo(attachPart.CFrame * offset)

	local torsoWeld = Instance.new("WeldConstraint")
	torsoWeld.Part0 = attachPart
	torsoWeld.Part1 = primaryPart
	torsoWeld.Parent = primaryPart

	model.Name = HELD_MODEL_NAME
	model.Parent = character

	return true
end

local function refreshHeldVisual()
	clearHeldVisual()

	local inventoryIndex = Client_Equip.GetEquippedIndex()
	if not inventoryIndex then
		return
	end

	local inventory = Client_Data:GetValue("Inventory") or {}
	local item = inventory[inventoryIndex]
	if not item or type(item.ConfigName) ~= "string" then
		return
	end

	local character = localPlayer.Character
	if not character then
		return
	end

	local configName = item.ConfigName
	local itemType = item.ItemType
	local model: Model? = nil
	local modifier = item.Data and item.Data.Modifier or "Normal"
	local level = math.max(1, item.Data and item.Data.Level or 1)
	local forwardOffsetDelta = 0
	local heightOffsetDelta = 0

	if itemType == "Brainrot" then
		model = getBrainrotModel(configName, modifier)
	elseif itemType == "LuckyBlock" then
		if not Shared_LuckyBlocks.Data[configName] then
			return
		end
		model = getLuckyBlockModel(configName)
		forwardOffsetDelta = LUCKYBLOCK_FORWARD_OFFSET_DELTA
		heightOffsetDelta = LUCKYBLOCK_HEIGHT_OFFSET_DELTA
	else
		return
	end

	if not model then
		return
	end

	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
	end

	if itemType == "Brainrot" then
		model:ScaleTo(Shared_Brainrots.GetScaleForLevel(level))
	end

	if not attachBrainrotToTorso(model, character, forwardOffsetDelta, heightOffsetDelta) then
		model:Destroy()
		return
	end

	heldModel = model
	model:SetAttribute("ConfigName", configName)

	if itemType == "Brainrot" then
		Shared_BrainrotBillboard.Setup(model, configName, modifier, level)
	end
	playHoldAnimation(character)
end

function Client_EquipHold.Init()
	Client_Data.WaitUntilReady()

	Client_Equip.OnChanged(refreshHeldVisual)

	localPlayer.CharacterRemoving:Connect(clearHeldVisual)
	localPlayer.CharacterAdded:Connect(function()
		task.defer(refreshHeldVisual)
	end)

	refreshHeldVisual()
end

return Client_EquipHold
