local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local PlotBrainrotVisuals = require(ServerScriptService.Plot.PlotBrainrotVisuals)
local Server_Data = require(ServerScriptService.Core.Server_Data)
local Shared_BrainrotBillboard = SharedModules.require("Shared_BrainrotBillboard")
local Shared_BrainrotAssets = SharedModules.require("Shared_BrainrotAssets")
local Shared_Carry = SharedModules.require("Shared_Carry")
local Shared_GameProcess = SharedModules.require("Shared_GameProcess")
local Shared_LuckyBlocks = SharedModules.require("Shared_LuckyBlocks")
local Shared_LuckyBlockBillboard = SharedModules.require("Shared_LuckyBlockBillboard")
local Shared_ProximityPrompt = SharedModules.require("Shared_ProximityPrompt")
local Shared_RoadGradient = SharedModules.require("Shared_RoadGradient")
local Shared_Weight = SharedModules.require("Shared_Weight")

local GameProcessService = {}

local collecting: { [Model]: boolean } = {}
local carriedByPlayer: { [Player]: Model } = {}
local delivering: { [Player]: boolean } = {}
local pickupLocks: { [Player]: boolean } = {}
local roadFrontZ: number? = nil
local gameProcessHandler: RemoteEvent? = nil
local despawnTimers: { [Model]: thread } = {}
local brainrotDropLocks: { [Player]: boolean } = {}
local plotService: any = nil

local TORSO_HEIGHT_OFFSET = 0.75
local LUCKYBLOCK_HEIGHT_OFFSET_DELTA = -1

local function getProcessPhase(): string?
	local gameFolder = Workspace:FindFirstChild("Game")
	if not gameFolder then
		return nil
	end
	local phase = gameFolder:GetAttribute("ProcessPhase")
	if type(phase) == "string" then
		return phase
	end
	return nil
end

local function isLuckyBlockRaceActive(): boolean
	return getProcessPhase() == Shared_GameProcess.ProcessPhase.RaceEnds
end

local function clearEquippedVisual(player: Player)
	player:SetAttribute("EquippedItemType", nil)
	player:SetAttribute("EquippedConfigName", nil)
	player:SetAttribute("EquippedModifier", nil)
	player:SetAttribute("EquippedLevel", nil)
	player:SetAttribute("EquippedBaseWeight", nil)
	player:SetAttribute("EquippedWeight", nil)
end

local function setCarryingAttributes(player: Player, luckyBlock: Model?)
	if luckyBlock then
		player:SetAttribute("CarryingLuckyBlock", true)
		player:SetAttribute("CarriedLuckyBlockConfigName", luckyBlock:GetAttribute("ConfigName"))
		player:SetAttribute("CarriedLuckyBlockBaseWeight", luckyBlock:GetAttribute("BaseWeight"))
		player:SetAttribute("CarriedLuckyBlockWeight", luckyBlock:GetAttribute("Weight"))
		player:SetAttribute("CarriedLuckyBlockRarity", luckyBlock:GetAttribute("Rarity"))
	else
		player:SetAttribute("CarryingLuckyBlock", nil)
		player:SetAttribute("CarriedLuckyBlockConfigName", nil)
		player:SetAttribute("CarriedLuckyBlockBaseWeight", nil)
		player:SetAttribute("CarriedLuckyBlockWeight", nil)
		player:SetAttribute("CarriedLuckyBlockRarity", nil)
	end
end

local function getTorsoPart(character: Model): BasePart?
	return character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
		or character.PrimaryPart
end

local function getCarryAttachPart(character: Model): BasePart?
	return character:FindFirstChild("Head")
		or getTorsoPart(character)
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

local function attachCarriedLuckyBlockToCharacter(player: Player, luckyBlock: Model): boolean
	local character = player.Character
	if not character then
		return false
	end

	local primaryPart = Shared_Weight.SyncLuckyBlockPivot(luckyBlock)
	local attachPart = getCarryAttachPart(character)
	if not primaryPart or not attachPart then
		return false
	end

	primaryPart.Anchored = false

	for _, descendant in luckyBlock:GetDescendants() do
		if descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			local part = descendant
			part.CanCollide = false
			part.Massless = true
			if part ~= primaryPart then
				part.Anchored = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primaryPart
				weld.Part1 = part
				weld.Parent = primaryPart
			end
		end
	end

	local scaleRatio = getLuckyBlockHoldScaleRatio(luckyBlock)
	local resolvedHeightOffset = (TORSO_HEIGHT_OFFSET + LUCKYBLOCK_HEIGHT_OFFSET_DELTA) * scaleRatio

	local _, boundsSize = luckyBlock:GetBoundingBox()
	local halfHeight = boundsSize.Y * 0.5
	local attachHalfHeight = attachPart.Size.Y * 0.5

	local topOffset = Shared_GameProcess.CarriedLuckyBlockTopOffset
	local offset = CFrame.new(
		0,
		attachHalfHeight + halfHeight + resolvedHeightOffset + topOffset,
		0
	)
	luckyBlock:PivotTo(attachPart.CFrame * offset)

	local torsoWeld = Instance.new("WeldConstraint")
	torsoWeld.Part0 = attachPart
	torsoWeld.Part1 = primaryPart
	torsoWeld.Parent = primaryPart

	luckyBlock.Name = `CarriedLuckyBlock_{player.UserId}`
	luckyBlock.Parent = character
	luckyBlock:SetAttribute("IsWorldLuckyBlock", false)

	return true
end

local function detachCarriedLuckyBlockFromCharacter(luckyBlock: Model, worldParent: Instance)
	for _, descendant in luckyBlock:GetDescendants() do
		if descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			local part = descendant
			part.Anchored = true
			part.CanCollide = false
			part.Massless = true
		end
	end

	luckyBlock.Parent = worldParent
end

local function removePickupPrompt(luckyBlock: Model)
	if not luckyBlock.PrimaryPart then
		luckyBlock.PrimaryPart = luckyBlock:FindFirstChildWhichIsA("BasePart", true)
	end

	local primaryPart = luckyBlock.PrimaryPart
	if not primaryPart then
		return
	end

	local attachment = primaryPart:FindFirstChild("CollectAttachment")
	if not attachment then
		return
	end

	for _, child in attachment:GetChildren() do
		if child:IsA("ProximityPrompt") then
			child:Destroy()
		end
	end
end

local function createCarriedCloneFromWorld(worldLuckyBlock: Model): Model
	local carriedBlock = worldLuckyBlock:Clone()
	carriedBlock.Name = "CarriedLuckyBlock"
	carriedBlock:SetAttribute("IsWorldLuckyBlock", false)
	carriedBlock:SetAttribute("IsCarriedLuckyBlock", true)
	removePickupPrompt(carriedBlock)
	return carriedBlock
end

local function getLuckyBlockWorldParent(): Instance?
	local gameFolder = Workspace:FindFirstChild("Game")
	local mapFolder = gameFolder and gameFolder:FindFirstChild("Map")
	return mapFolder and mapFolder:FindFirstChild("Floors")
end

local function getModelLowestWorldY(model: Model): number
	local bboxCF, bboxSize = model:GetBoundingBox()
	return bboxCF.Position.Y - bboxSize.Y / 2
end

local function snapModelBottomToY(model: Model, targetBottomY: number)
	local lowestY = getModelLowestWorldY(model)
	local lift = targetBottomY - lowestY
	if math.abs(lift) > 1e-4 then
		model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
	end
end

local function raycastFloorTopY(worldX: number, worldZ: number, exclude: { Instance }): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude

	local origin = Vector3.new(worldX, 500, worldZ)
	local result = Workspace:Raycast(origin, Vector3.new(0, -1000, 0), params)
	if result then
		return result.Position.Y
	end
	return nil
end

local function getBrainrotTemplate(configName: string, modifier: string): Model?
	return Shared_BrainrotAssets.GetTemplate(configName, modifier)
end

local function getFlatLookVectorFromCFrame(cframe: CFrame): Vector3
	local look = cframe.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return flatLook.Unit
end

local function getFlatLookVector(root: BasePart): Vector3
	return getFlatLookVectorFromCFrame(root.CFrame)
end

local function validateClientDropRootCFrame(player: Player, clientRootCFrame: CFrame?): CFrame?
	if typeof(clientRootCFrame) ~= "CFrame" then
		return nil
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end

	local maxError = Shared_GameProcess.WorldDropMaxClientPositionError
	if (clientRootCFrame.Position - root.Position).Magnitude > maxError then
		return nil
	end

	return clientRootCFrame
end

local function isDropTargetReachable(
	origin: Vector3,
	dropX: number,
	dropZ: number,
	exclude: { Instance }
): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true

	local wallClearance = Shared_GameProcess.WorldDropWallClearance
	local probeHeights = { 0.75, 1.75, 3 }

	for _, probeHeight in probeHeights do
		local start = Vector3.new(origin.X, origin.Y + probeHeight, origin.Z)
		local target = Vector3.new(dropX, start.Y, dropZ)
		local delta = target - start
		local distance = delta.Magnitude
		if distance < 0.25 then
			continue
		end

		local result = Workspace:Raycast(start, delta.Unit * math.max(0, distance - wallClearance), params)
		if result then
			return false
		end
	end

	return true
end

local function findWorldDropTarget(
	root: BasePart,
	exclude: { Instance },
	radiusScale: number?,
	dropOriginOverride: Vector3?,
	flatLookOverride: Vector3?
): (number?, number?, number?)
	local origin = dropOriginOverride or root.Position
	local flatLook = flatLookOverride or getFlatLookVector(root)
	local baseAngle = math.atan2(flatLook.X, flatLook.Z)
	local resolvedRadiusScale = if type(radiusScale) == "number" and radiusScale > 0 then radiusScale else 1
	local minRadius = Shared_GameProcess.WorldDropMinRadius * resolvedRadiusScale
	local maxRadius = Shared_GameProcess.WorldDropMaxRadius * resolvedRadiusScale
	local maxAttempts = Shared_GameProcess.WorldDropMaxAttempts
	local forwardCone = math.rad(Shared_GameProcess.WorldDropForwardConeDegrees * 0.5)
	local maxFloorDelta = Shared_GameProcess.WorldDropMaxFloorDelta

	local function tryCandidate(dropX: number, dropZ: number): number?
		if not isDropTargetReachable(origin, dropX, dropZ, exclude) then
			return nil
		end

		local floorTopY = raycastFloorTopY(dropX, dropZ, exclude)
		if not floorTopY then
			return nil
		end

		if math.abs(floorTopY - origin.Y) > maxFloorDelta then
			return nil
		end

		return floorTopY
	end

	for attempt = 1, maxAttempts do
		local radius: number
		local angle: number

		if attempt <= maxAttempts - 4 then
			radius = minRadius + math.random() * (maxRadius - minRadius)
			angle = baseAngle + (math.random() * 2 - 1) * forwardCone
		else
			radius = minRadius + (attempt - (maxAttempts - 4)) * 0.35
			angle = baseAngle + (math.random() * 2 - 1) * math.rad(30)
		end

		local dropX = origin.X + math.sin(angle) * radius
		local dropZ = origin.Z + math.cos(angle) * radius
		local floorTopY = tryCandidate(dropX, dropZ)
		if floorTopY then
			return dropX, dropZ, floorTopY
		end
	end

	local fallbackX = origin.X + flatLook.X * minRadius
	local fallbackZ = origin.Z + flatLook.Z * minRadius
	local fallbackFloorY = tryCandidate(fallbackX, fallbackZ)
	if fallbackFloorY then
		return fallbackX, fallbackZ, fallbackFloorY
	end

	local floorTopY = raycastFloorTopY(origin.X, origin.Z, exclude)
	if floorTopY then
		return origin.X, origin.Z, floorTopY
	end

	return nil, nil, nil
end

local function getDropFacingRotation(
	root: BasePart,
	dropX: number,
	dropZ: number,
	floorTopY: number,
	overrideRootCFrame: CFrame?
): CFrame
	local dropPos = Vector3.new(dropX, floorTopY, dropZ)
	local rootPosition = if overrideRootCFrame then overrideRootCFrame.Position else root.Position
	local lookTarget = Vector3.new(rootPosition.X, floorTopY, rootPosition.Z)
	if (lookTarget - dropPos).Magnitude > 0.01 then
		local facing = CFrame.lookAt(dropPos, lookTarget)
		return facing - facing.Position
	end
	return CFrame.new()
end

local function getDropLaunchOrigin(character: Model, overrideRootCFrame: CFrame?): Vector3
	if overrideRootCFrame then
		return overrideRootCFrame.Position + overrideRootCFrame.UpVector * 2 + overrideRootCFrame.LookVector
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart.Position + rootPart.CFrame.UpVector * 2 + rootPart.CFrame.LookVector
	end

	local attachPart = character:FindFirstChild("Head")
		or character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
	if attachPart and attachPart:IsA("BasePart") then
		return attachPart.Position + attachPart.CFrame.UpVector * 1.5
	end

	return character:GetPivot().Position + Vector3.new(0, 2, 0)
end

local function placeWorldModelAtDropPosition(
	worldModel: Model,
	character: Model,
	worldParent: Instance,
	radiusScale: number?,
	overrideRootCFrame: CFrame?
): Vector3?
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end

	local dropOrigin = if overrideRootCFrame then overrideRootCFrame.Position else root.Position
	local flatLook = if overrideRootCFrame
		then getFlatLookVectorFromCFrame(overrideRootCFrame)
		else getFlatLookVector(root)

	local exclude: { Instance } = { character, worldModel }
	local dropX, dropZ, floorTopY = findWorldDropTarget(root, exclude, radiusScale, dropOrigin, flatLook)
	if not dropX or not dropZ or not floorTopY then
		return nil
	end

	if not worldModel.PrimaryPart then
		worldModel.PrimaryPart = worldModel:FindFirstChildWhichIsA("BasePart", true)
	end
	if not worldModel.PrimaryPart then
		return nil
	end

	local dropRotation = getDropFacingRotation(root, dropX, dropZ, floorTopY, overrideRootCFrame)

	worldModel.Parent = worldParent

	Shared_Weight.SyncLuckyBlockPivot(worldModel)
	worldModel:PivotTo(CFrame.new(dropX, floorTopY, dropZ) * dropRotation)
	snapModelBottomToY(worldModel, floorTopY)

	local _, bboxSize = worldModel:GetBoundingBox()
	local spawnLift = Shared_GameProcess.GetWorldLuckyBlockSpawnLift(bboxSize.Y)
	worldModel:PivotTo(worldModel:GetPivot() + Vector3.new(0, spawnLift, 0))

	local flatYaw = Shared_GameProcess.GetFlatYaw(worldModel:GetPivot())
	worldModel:PivotTo(
		CFrame.new(worldModel:GetPivot().Position) * Shared_GameProcess.YawRotation(flatYaw)
	)
	Shared_Weight.PrepareLuckyBlockForWorld(worldModel)
	worldModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	return worldModel:GetPivot().Position
end

local function clearDroppedLuckyBlockDespawnDisplay(luckyBlock: Model)
	if luckyBlock.Parent then
		luckyBlock:SetAttribute("DespawnSecondsRemaining", nil)
		Shared_LuckyBlockBillboard.UpdateDespawnCountdown(luckyBlock, nil)
	end
end

local function stopDroppedLuckyBlockDespawn(luckyBlock: Model)
	local timerThread = despawnTimers[luckyBlock]
	despawnTimers[luckyBlock] = nil

	if timerThread and timerThread ~= coroutine.running() then
		pcall(task.cancel, timerThread)
	end

	clearDroppedLuckyBlockDespawnDisplay(luckyBlock)
end

local function startDroppedLuckyBlockDespawn(luckyBlock: Model)
	stopDroppedLuckyBlockDespawn(luckyBlock)

	local despawnSeconds = Shared_GameProcess.DroppedLuckyBlockDespawnSeconds
	luckyBlock:SetAttribute("IsDroppedLuckyBlock", true)

	despawnTimers[luckyBlock] = task.spawn(function()
		for remaining = despawnSeconds, 1, -1 do
			if not luckyBlock.Parent or luckyBlock:GetAttribute("IsWorldLuckyBlock") ~= true then
				despawnTimers[luckyBlock] = nil
				clearDroppedLuckyBlockDespawnDisplay(luckyBlock)
				return
			end

			luckyBlock:SetAttribute("DespawnSecondsRemaining", remaining)
			Shared_LuckyBlockBillboard.UpdateDespawnCountdown(luckyBlock, remaining)
			task.wait(1)
		end

		if luckyBlock.Parent and luckyBlock:GetAttribute("IsWorldLuckyBlock") == true then
			despawnTimers[luckyBlock] = nil
			clearDroppedLuckyBlockDespawnDisplay(luckyBlock)
			luckyBlock:Destroy()
		else
			despawnTimers[luckyBlock] = nil
		end
	end)
end

local function stopRoadFrontCheck(_player: Player) end

local function forfeitCarriedLuckyBlock(
	player: Player,
	feedbackMessage: string?,
	useUnluckyFx: boolean?
): boolean
	local luckyBlock = carriedByPlayer[player]
	local wasCarrying = luckyBlock ~= nil or player:GetAttribute("CarryingLuckyBlock") == true
	if not wasCarrying then
		return false
	end

	stopRoadFrontCheck(player)
	if luckyBlock and luckyBlock.Parent then
		luckyBlock:Destroy()
	end
	carriedByPlayer[player] = nil
	delivering[player] = nil
	setCarryingAttributes(player, nil)
	Server_Data:RefreshWalkSpeed(player)

	if feedbackMessage and gameProcessHandler then
		local action = if useUnluckyFx then "UnluckyMapClose" else "CarryFeedback"
		gameProcessHandler:FireClient(player, action, feedbackMessage)
	end

	return true
end

local function forfeitAllCarryingPlayers(feedbackMessage: string?, useUnluckyFx: boolean?)
	local forfeitedPlayers: { [Player]: boolean } = {}

	for player in carriedByPlayer do
		forfeitCarriedLuckyBlock(player, feedbackMessage, useUnluckyFx)
		forfeitedPlayers[player] = true
	end

	for _, player in Players:GetPlayers() do
		if not forfeitedPlayers[player] and player:GetAttribute("CarryingLuckyBlock") == true then
			forfeitCarriedLuckyBlock(player, feedbackMessage, useUnluckyFx)
		end
	end
end

local function tryDeliverPlayerPastRoadFront(player: Player)
	if roadFrontZ == nil or not carriedByPlayer[player] then
		return
	end

	if not isLuckyBlockRaceActive() then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	if Shared_RoadGradient.HasPassedRoadFront(
		root.Position.Z,
		roadFrontZ,
		Shared_GameProcess.LuckyBlockDeliverZLead
	) then
		GameProcessService.DeliverCarriedLuckyBlock(player)
	end
end

local function startRoadFrontCheck(player: Player)
	if roadFrontZ == nil or not carriedByPlayer[player] then
		return
	end
	tryDeliverPlayerPastRoadFront(player)
end

function GameProcessService.IsPlayerCarrying(player: Player): boolean
	return carriedByPlayer[player] ~= nil
end

local function playerOwnsVIP(player: Player): boolean
	local Server_Marketplace = require(script.Parent.Parent.Core.Server_Marketplace)
	return Server_Marketplace.PlayerOwnsGamepass(player, Shared_GameProcess.VIPGamepassConfigKey)
end

local function getPickupMaxDistance(): number
	local pickUpPreset = Shared_ProximityPrompt.GetPreset("PickUpWorld")
	return (pickUpPreset.MaxActivationDistance or 6) * 2 + 6
end

function GameProcessService.PlayerCanPickupLuckyBlock(player: Player, worldLuckyBlock: Model): (boolean, string?)
	if worldLuckyBlock:GetAttribute("IsWorldLuckyBlock") ~= true or not worldLuckyBlock.Parent then
		return false, nil
	end

	if Shared_GameProcess.IsVipLuckyBlockModel(worldLuckyBlock) and not playerOwnsVIP(player) then
		return false, Shared_GameProcess.VIPRequiredPickupMessage
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false, nil
	end

	local blockPosition = worldLuckyBlock:GetPivot().Position
	if (root.Position - blockPosition).Magnitude > getPickupMaxDistance() then
		return false, nil
	end

	return true, nil
end

function GameProcessService.PickupWorldLuckyBlock(player: Player, worldLuckyBlock: Model)
	if collecting[worldLuckyBlock] or not worldLuckyBlock.Parent then
		return
	end
	if carriedByPlayer[player] then
		if gameProcessHandler then
			gameProcessHandler:FireClient(
				player,
				"CarryFeedback",
				Shared_GameProcess.AlreadyCarryingLuckyBlockMessage
			)
		end
		return
	end
	if pickupLocks[player] then
		return
	end

	local configName = worldLuckyBlock:GetAttribute("ConfigName")
	if type(configName) ~= "string" or configName == "" then
		return
	end

	local canAccess, accessMessage = GameProcessService.PlayerCanPickupLuckyBlock(player, worldLuckyBlock)
	if not canAccess then
		if accessMessage and gameProcessHandler then
			gameProcessHandler:FireClient(player, "CarryFeedback", accessMessage)
		end
		return
	end

	local blockWeight = tonumber(worldLuckyBlock:GetAttribute("Weight"))
	if not blockWeight then
		local defaultBaseWeight = Shared_LuckyBlocks.GetBaseWeight(configName)
		local _, rolledWeight = Shared_Weight.ResolveLuckyBlockWeights(nil, defaultBaseWeight)
		blockWeight = rolledWeight
	end

	local strength = Server_Data:GetValue(player, "Strength") or 1
	local speed = Server_Data:GetValue(player, "Speed") or Shared_Carry.DefaultWalkSpeed

	local canPickup, pickupMessage = Shared_Carry.CanPickupLuckyBlock(blockWeight, strength, speed)
	if not canPickup then
		if pickupMessage and gameProcessHandler then
			gameProcessHandler:FireClient(player, "CarryFeedback", pickupMessage)
		end
		return
	end

	pickupLocks[player] = true
	collecting[worldLuckyBlock] = true
	stopDroppedLuckyBlockDespawn(worldLuckyBlock)

	clearEquippedVisual(player)
	Shared_Weight.SyncLuckyBlockPivot(worldLuckyBlock)

	local carriedBlock = createCarriedCloneFromWorld(worldLuckyBlock)
	worldLuckyBlock:Destroy()

	if not attachCarriedLuckyBlockToCharacter(player, carriedBlock) then
		carriedBlock:Destroy()
		pickupLocks[player] = nil
		collecting[worldLuckyBlock] = nil
		return
	end

	carriedByPlayer[player] = carriedBlock
	setCarryingAttributes(player, carriedBlock)
	startRoadFrontCheck(player)

	pickupLocks[player] = nil
	collecting[worldLuckyBlock] = nil
end

function GameProcessService.DropCarriedLuckyBlock(player: Player, clientRootCFrame: CFrame?)
	local luckyBlock = carriedByPlayer[player]
	if not luckyBlock or collecting[luckyBlock] then
		return
	end

	collecting[luckyBlock] = true

	local character = player.Character
	if not character then
		collecting[luckyBlock] = nil
		return
	end

	local validatedRootCFrame = validateClientDropRootCFrame(player, clientRootCFrame)
	local worldParent = getLuckyBlockWorldParent() or Workspace
	detachCarriedLuckyBlockFromCharacter(luckyBlock, worldParent)
	local launchOrigin = getDropLaunchOrigin(character, validatedRootCFrame)
	local _, bboxSize = luckyBlock:GetBoundingBox()
	local dropRadiusScale = Shared_GameProcess.GetWorldDropRadiusScale(bboxSize.Y)
	local dropPosition = placeWorldModelAtDropPosition(
		luckyBlock,
		character,
		worldParent,
		dropRadiusScale,
		validatedRootCFrame
	)
	if not dropPosition then
		if luckyBlock.Parent and not luckyBlock:IsDescendantOf(character) then
			attachCarriedLuckyBlockToCharacter(player, luckyBlock)
		end
		collecting[luckyBlock] = nil
		return
	end

	local floatHeight = Shared_GameProcess.GetWorldLuckyBlockFloatHeight(bboxSize.Y)
	luckyBlock:SetAttribute("FloatHeight", floatHeight)
	luckyBlock:SetAttribute("WorldFloatBasePosition", dropPosition)
	luckyBlock:SetAttribute("WorldBaseYaw", Shared_GameProcess.GetFlatYaw(luckyBlock:GetPivot()))
	luckyBlock:SetAttribute("DropLaunchOrigin", launchOrigin)
	luckyBlock:SetAttribute("DropSizeScale", dropRadiusScale)
	luckyBlock:SetAttribute("DroppedByUserId", player.UserId)
	luckyBlock:SetAttribute("IsCarriedLuckyBlock", nil)

	carriedByPlayer[player] = nil
	setCarryingAttributes(player, nil)
	stopRoadFrontCheck(player)
	GameProcessService.SetupWorldLuckyBlock(luckyBlock)
	startDroppedLuckyBlockDespawn(luckyBlock)

	collecting[luckyBlock] = nil
end

function GameProcessService.DeliverCarriedLuckyBlock(player: Player)
	if delivering[player] then
		return
	end

	local luckyBlock = carriedByPlayer[player]
	if not luckyBlock then
		return
	end

	delivering[player] = true

	local configName = luckyBlock:GetAttribute("ConfigName")
	local baseWeight = luckyBlock:GetAttribute("BaseWeight")
	local rarity = luckyBlock:GetAttribute("Rarity")
	if type(rarity) ~= "string" or rarity == "" then
		if type(configName) == "string" then
			local config = Shared_LuckyBlocks.Data[configName]
			rarity = config and config.Rarity or "Unknown"
		else
			rarity = "Unknown"
		end
	end

	stopRoadFrontCheck(player)
	carriedByPlayer[player] = nil
	setCarryingAttributes(player, nil)
	luckyBlock:Destroy()

	if type(configName) == "string" and configName ~= "" then
		local itemData: { [string]: number } = {}
		if type(baseWeight) == "number" then
			itemData.BaseWeight = baseWeight
		end

		local newIndex = Server_Data:AddInventoryItem(player, {
			ItemType = "LuckyBlock",
			ConfigName = configName,
			Data = itemData,
		})

		if newIndex and gameProcessHandler then
			gameProcessHandler:FireClient(player, "LuckyBlockDelivered", newIndex, rarity)
		end
	end

	delivering[player] = nil
end

function GameProcessService.SetPlotService(service: any)
	plotService = service
end

local function getCarriedLuckyBlockRarity(luckyBlock: Model): string?
	local rarity = luckyBlock:GetAttribute("Rarity")
	if type(rarity) == "string" and rarity ~= "" then
		return rarity
	end

	local configName = luckyBlock:GetAttribute("ConfigName")
	if type(configName) == "string" then
		local config = Shared_LuckyBlocks.Data[configName]
		if config and type(config.Rarity) == "string" and config.Rarity ~= "" then
			return config.Rarity
		end
	end

	return nil
end

function GameProcessService.CanPurchaseTeleportHome(player: Player, expectedRarity: string): boolean
	local luckyBlock = carriedByPlayer[player]
	if not luckyBlock then
		return false
	end

	local rarity = getCarriedLuckyBlockRarity(luckyBlock)
	return type(rarity) == "string" and rarity == expectedRarity
end

function GameProcessService.GrantTeleportHome(player: Player, expectedRarity: string): (boolean, string?)
	if not GameProcessService.CanPurchaseTeleportHome(player, expectedRarity) then
		return false, "Not carrying lucky block"
	end

	GameProcessService.DeliverCarriedLuckyBlock(player)

	if plotService and plotService.TeleportPlayerToPlot then
		plotService:TeleportPlayerToPlot(player)
	end

	return true, nil
end

local function createWorldBrainrotFromItem(item: any): Model?
	if type(item.ConfigName) ~= "string" or item.ItemType ~= "Brainrot" then
		return nil
	end

	local data = item.Data or {}
	local modifier = data.Modifier or "Normal"
	local level = math.max(1, tonumber(data.Level) or 1)
	local template = getBrainrotTemplate(item.ConfigName, modifier)
	if not template then
		return nil
	end

	local brainrot = template:Clone()
	brainrot.Name = "WorldBrainrot"

	if not brainrot.PrimaryPart then
		brainrot.PrimaryPart = brainrot:FindFirstChildWhichIsA("BasePart", true)
	end

	local baseWeight, rolledWeight = Shared_Weight.ResolveBrainrotWeights(data, item.ConfigName)
	Shared_Weight.ApplyBrainrotScale(brainrot, baseWeight, rolledWeight)
	Shared_Weight.SyncLuckyBlockPivot(brainrot)

	brainrot:SetAttribute("ItemType", "Brainrot")
	brainrot:SetAttribute("ConfigName", item.ConfigName)
	brainrot:SetAttribute("Modifier", modifier)
	brainrot:SetAttribute("Level", level)
	brainrot:SetAttribute("BaseWeight", baseWeight)
	brainrot:SetAttribute("Weight", rolledWeight)

	Shared_BrainrotBillboard.Setup(brainrot, item.ConfigName, modifier, level, baseWeight, rolledWeight)
	return brainrot
end

function GameProcessService.SetupWorldBrainrot(brainrot: Model)
	brainrot:SetAttribute("IsWorldBrainrot", true)

	for _, descendant in brainrot:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
		end
	end

	PlotBrainrotVisuals.SetupPickupPrompt(brainrot, function(triggerPlayer: Player)
		GameProcessService.PickupWorldBrainrot(triggerPlayer, brainrot)
	end)
end

function GameProcessService.PickupWorldBrainrot(player: Player, worldBrainrot: Model)
	if collecting[worldBrainrot] or not worldBrainrot.Parent then
		return
	end
	if worldBrainrot:GetAttribute("IsWorldBrainrot") ~= true then
		return
	end
	if carriedByPlayer[player] or brainrotDropLocks[player] then
		return
	end

	collecting[worldBrainrot] = true

	local configName = worldBrainrot:GetAttribute("ConfigName")
	local modifier = worldBrainrot:GetAttribute("Modifier")
	local level = worldBrainrot:GetAttribute("Level")
	local baseWeight = worldBrainrot:GetAttribute("BaseWeight")
	local weight = worldBrainrot:GetAttribute("Weight")
	if type(configName) ~= "string" or configName == "" then
		collecting[worldBrainrot] = nil
		return
	end

	local itemData: { [string]: any } = {
		Level = math.max(1, tonumber(level) or 1),
		Modifier = if type(modifier) == "string" then modifier else "Normal",
	}
	if type(baseWeight) == "number" then
		itemData.BaseWeight = baseWeight
	end
	if type(weight) == "number" then
		itemData.Weight = weight
	end

	worldBrainrot:Destroy()

	local newIndex = Server_Data:AddInventoryItem(player, {
		ItemType = "Brainrot",
		ConfigName = configName,
		Data = itemData,
	})

	collecting[worldBrainrot] = nil

	if newIndex and gameProcessHandler then
		gameProcessHandler:FireClient(player, "BrainrotPickedUp", newIndex)
	end
end

function GameProcessService.DropEquippedBrainrot(player: Player, inventoryIndex: any)
	if brainrotDropLocks[player] or carriedByPlayer[player] then
		return
	end
	if type(inventoryIndex) ~= "number" then
		return
	end

	local inventory = Server_Data:GetValue(player, "Inventory") or {}
	local item = inventory[inventoryIndex]
	if not item or item.ItemType ~= "Brainrot" or type(item.ConfigName) ~= "string" then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	brainrotDropLocks[player] = true

	local removedItem = Server_Data:RemoveInventoryAt(player, inventoryIndex)
	if not removedItem then
		brainrotDropLocks[player] = nil
		return
	end

	clearEquippedVisual(player)

	local brainrot = createWorldBrainrotFromItem(removedItem)
	if not brainrot then
		Server_Data:AddInventoryItem(player, removedItem)
		brainrotDropLocks[player] = nil
		return
	end

	local worldParent = getLuckyBlockWorldParent() or Workspace
	local launchOrigin = getDropLaunchOrigin(character)
	local _, bboxSize = brainrot:GetBoundingBox()
	local dropRadiusScale = Shared_GameProcess.GetWorldDropRadiusScale(bboxSize.Y)
	local dropPosition = placeWorldModelAtDropPosition(brainrot, character, worldParent, dropRadiusScale)
	if not dropPosition then
		brainrot:Destroy()
		Server_Data:AddInventoryItem(player, removedItem)
		brainrotDropLocks[player] = nil
		return
	end

	brainrot:SetAttribute("FloatHeight", Shared_GameProcess.GetWorldLuckyBlockFloatHeight(bboxSize.Y))
	brainrot:SetAttribute("WorldFloatBasePosition", dropPosition)
	brainrot:SetAttribute("DropLaunchOrigin", launchOrigin)
	brainrot:SetAttribute("DropSizeScale", dropRadiusScale)
	brainrot:SetAttribute("DroppedByUserId", player.UserId)

	GameProcessService.SetupWorldBrainrot(brainrot)
	brainrot.Parent = worldParent

	brainrotDropLocks[player] = nil
end

function GameProcessService.SetupWorldLuckyBlock(luckyBlock: Model)
	luckyBlock:SetAttribute("IsWorldLuckyBlock", true)
	Shared_Weight.PrepareLuckyBlockForWorld(luckyBlock)
	luckyBlock.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local primaryPart = luckyBlock.PrimaryPart
	if not primaryPart then
		return
	end

	for _, descendant in luckyBlock:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
		end
	end

	local bboxCF, _ = luckyBlock:GetBoundingBox()
	local attachment = primaryPart:FindFirstChild("CollectAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		attachment = Instance.new("Attachment")
		attachment.Name = "CollectAttachment"
		attachment.Parent = primaryPart
	end
	attachment.Position = primaryPart.CFrame:PointToObjectSpace(bboxCF.Position)

	for _, child in attachment:GetChildren() do
		if child:IsA("ProximityPrompt") then
			child:Destroy()
		end
	end

	local pickUpPreset = Shared_ProximityPrompt.GetPreset("PickUpWorld")
	local pickupDistance = (pickUpPreset.MaxActivationDistance or 6) * 2

	local prompt = Shared_ProximityPrompt.Create(attachment, {
		Preset = "PickUpWorld",
		ActionText = "Pick Up",
		ObjectText = "",
		MaxActivationDistance = pickupDistance,
	})

	if Shared_GameProcess.IsVipLuckyBlockModel(luckyBlock) then
		prompt:SetAttribute("RequiresVIP", true)
	end

	prompt.Triggered:Connect(function(triggerPlayer)
		GameProcessService.PickupWorldLuckyBlock(triggerPlayer, luckyBlock)
	end)
end

local function bindPlayerCarry(player: Player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			local luckyBlock = carriedByPlayer[player]
			if luckyBlock and luckyBlock.Parent then
				attachCarriedLuckyBlockToCharacter(player, luckyBlock)
				startRoadFrontCheck(player)
			end
		end)
	end)

	player.CharacterRemoving:Connect(function()
		if not carriedByPlayer[player] then
			return
		end

		if isLuckyBlockRaceActive() then
			GameProcessService.DropCarriedLuckyBlock(player)
		else
			forfeitCarriedLuckyBlock(player, Shared_GameProcess.UnluckyMapCloseMessage, true)
		end
	end)
end

function GameProcessService.ForfeitCarriedLuckyBlock(player: Player, feedbackMessage: string?)
	return forfeitCarriedLuckyBlock(player, feedbackMessage, true)
end

function GameProcessService.OnRaceEnded()
	forfeitAllCarryingPlayers(Shared_GameProcess.UnluckyRaceEndMessage, true)
end

function GameProcessService.NotifyRaceTimeRanOut(player: Player)
	if not gameProcessHandler then
		return
	end

	gameProcessHandler:FireClient(player, "RaceTimeRanOut", Shared_GameProcess.RaceTimeRanOutMessage)
end

function GameProcessService.ClearForMapReset()
	forfeitAllCarryingPlayers(Shared_GameProcess.UnluckyMapCloseMessage, true)

	for luckyBlock in despawnTimers do
		stopDroppedLuckyBlockDespawn(luckyBlock)
	end

	table.clear(collecting)
	table.clear(delivering)
	table.clear(pickupLocks)
	table.clear(brainrotDropLocks)
end

function GameProcessService.Init()
	local events = ReplicatedStorage:WaitForChild("Events")
	gameProcessHandler = events:WaitForChild("GameProcessHandler") :: RemoteEvent

	gameProcessHandler.OnServerEvent:Connect(function(player: Player, action: string, ...)
		if action == "DropCarriedLuckyBlock" then
			local clientRootCFrame = select(1, ...)
			GameProcessService.DropCarriedLuckyBlock(player, clientRootCFrame)
			return
		end

		if action == "DropEquippedBrainrot" then
			local inventoryIndex = select(1, ...)
			GameProcessService.DropEquippedBrainrot(player, inventoryIndex)
			return
		end

	end)

	local zones = Workspace:WaitForChild("Zones", 30)
	local enterPart = zones and zones:WaitForChild("EnterPart", 30)
	if enterPart and enterPart:IsA("BasePart") then
		roadFrontZ = Shared_RoadGradient.GetRoadFrontZ(enterPart)
	end

	RunService.Stepped:Connect(function()
		if roadFrontZ == nil or not next(carriedByPlayer) then
			return
		end

		for player in carriedByPlayer do
			tryDeliverPlayerPastRoadFront(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		stopRoadFrontCheck(player)
		local luckyBlock = carriedByPlayer[player]
		if luckyBlock then
			luckyBlock:Destroy()
		end
		carriedByPlayer[player] = nil
		delivering[player] = nil
		brainrotDropLocks[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		bindPlayerCarry(player)
	end
	Players.PlayerAdded:Connect(bindPlayerCarry)
end

return GameProcessService
