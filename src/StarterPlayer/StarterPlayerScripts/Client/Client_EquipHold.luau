local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared_BrainrotBillboard = require(ReplicatedStorage.Modules.Shared_BrainrotBillboard)
local Shared_Brainrots = require(ReplicatedStorage.Modules.Shared_Brainrots)

local Client_Data = require(script.Parent.Client_Data)
local Client_Equip = require(script.Parent.Client_Equip)

local localPlayer = Players.LocalPlayer

local Client_EquipHold = {}

local HELD_MODEL_NAME = "EquippedBrainrot"
local HOLD_ANIMATION_NAME = "TwoHandsHolding"
local TORSO_FORWARD_OFFSET = 1
local TORSO_HEIGHT_OFFSET = 0.75

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
	holdTrack:Play(0.15, 1, 1)

	holdWatchdogConnection = RunService.Heartbeat:Connect(function()
		if not holdTrack or not holdAnimator or holdAnimator.Parent == nil then
			return
		end

		if not holdTrack.IsPlaying then
			holdTrack:Play(0.1, 1, 1)
		end
	end)
end

local function clearHeldVisual()
	stopHoldAnimation()

	if heldModel then
		heldModel:Destroy()
		heldModel = nil
	end
end

local function attachBrainrotToTorso(model: Model, character: Model): boolean
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

	local offset = CFrame.new(
		0,
		primaryPart.Size.Y * 0.3 + TORSO_HEIGHT_OFFSET,
		-primaryPart.Size.Z / 2 - TORSO_FORWARD_OFFSET
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
	if not item or item.ItemType ~= "Brainrot" or type(item.ConfigName) ~= "string" then
		return
	end

	local character = localPlayer.Character
	if not character then
		return
	end

	local configName = item.ConfigName
	local modifier = item.Data and item.Data.Modifier or "Normal"
	local level = math.max(1, item.Data and item.Data.Level or 1)

	local model = getBrainrotModel(configName, modifier)
	if not model then
		return
	end

	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
	end

	model:ScaleTo(Shared_Brainrots.GetScaleForLevel(level))

	if not attachBrainrotToTorso(model, character) then
		model:Destroy()
		return
	end

	heldModel = model
	model:SetAttribute("ConfigName", configName)

	Shared_BrainrotBillboard.Setup(model, configName, modifier, level)
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
