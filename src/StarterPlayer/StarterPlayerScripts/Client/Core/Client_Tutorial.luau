local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SharedModules = require(ReplicatedStorage.Modules.Loader)
local ClientLoader = require(script.Parent.Parent.Loader)

local Shared_Tutorial = SharedModules.require("Shared_Tutorial")
local Shared_Abbreviation = SharedModules.require("Shared_Abbreviation")
local Shared_GameProcess = SharedModules.require("Shared_GameProcess")
local Shared_SpeedStore = SharedModules.require("Shared_SpeedStore")
local Client_Data = ClientLoader.require("Client_Data")
local Client_Messaging = ClientLoader.require("Client_Messaging")
local Client_TutorialState = require(script.Parent.Client_TutorialState)

local Client_Tutorial = {}

local localPlayer = Players.LocalPlayer
local ENTRANCE_WALL_NAME = "EntranceWall"
local BLOCK_SEARCH_INTERVAL = 1

function Client_Tutorial.ShouldHighlightStrengthStore(): boolean
	return Client_TutorialState.highlightStrengthStoreFree
end

local PROXIMITY_PART_NAMES = {
	ProximityPart = true,
	ProximityPrompt = true,
}

type BeamState = {
	startAttachment: Attachment?,
	endAttachment: Attachment?,
	beam: Beam?,
	targetPart: BasePart?,
}

local currentStepIndex: number? = nil
local beamState: BeamState = {}
local characterConn: RBXScriptConnection? = nil
local completionConn: RBXScriptConnection? = nil
local tutorialHandler: RemoteEvent? = nil
local entranceStepPhaseConn: RBXScriptConnection? = nil
local entranceStepCarryConn: RBXScriptConnection? = nil
local entranceStepPollToken = 0
local speedStepCashConn: RBXScriptConnection? = nil
local lastBlockSearchAt = 0
local cachedRaceLuckyBlock: Model? = nil
local trackedBeamTarget: BasePart? = nil
local tutorialHandlerConnected = false

function Client_Tutorial.IsGuiding(): boolean
	return currentStepIndex ~= nil
end

local function refreshStrengthStoreUi()
	pcall(function()
		local store = ClientLoader.require("Client_StrengthStore")
		if store.Refresh then
			store.Refresh()
		end
	end)
end

local function setStrengthStoreHighlightActive(active: boolean)
	Client_TutorialState.highlightStrengthStoreFree = active
	refreshStrengthStoreUi()
end

local function isProximityAnchorPart(instance: Instance): boolean
	return instance:IsA("BasePart") and PROXIMITY_PART_NAMES[instance.Name] == true
end

local function findProximityPart(root: Instance): BasePart?
	for _, descendant in root:GetDescendants() do
		if isProximityAnchorPart(descendant) then
			return descendant
		end
	end
	return nil
end

local function findSpeedStoreProximityPart(): BasePart?
	local gameFolder = Workspace:FindFirstChild("Game")
	local interactFolder = gameFolder and gameFolder:FindFirstChild("Interact")
	if not interactFolder then
		return nil
	end

	for _, descendant in interactFolder:GetDescendants() do
		if descendant:IsA("Model") and descendant.Name == "SpeedStore" then
			local proximityPart = findProximityPart(descendant)
			if proximityPart then
				return proximityPart
			end
		end
	end

	return nil
end

local function findStrengthStoreProximityPart(): BasePart?
	local gameFolder = Workspace:FindFirstChild("Game")
	local interactFolder = gameFolder and gameFolder:FindFirstChild("Interact")
	if not interactFolder then
		return nil
	end

	for _, descendant in interactFolder:GetDescendants() do
		if descendant:IsA("Model") and descendant.Name == "StrengthStore" then
			local proximityPart = findProximityPart(descendant)
			if proximityPart then
				return proximityPart
			end
		end
	end

	return nil
end

local function findEntranceWall(): BasePart?
	local gameFolder = Workspace:FindFirstChild("Game")
	local mapFolder = gameFolder and gameFolder:FindFirstChild("Map")
	local wall = mapFolder and mapFolder:FindFirstChild(ENTRANCE_WALL_NAME)
	if wall and wall:IsA("BasePart") then
		return wall
	end
	return nil
end

local function findEnterPart(): BasePart?
	local zones = Workspace:FindFirstChild("Zones")
	local enterPart = zones and zones:FindFirstChild("EnterPart")
	if enterPart and enterPart:IsA("BasePart") then
		return enterPart
	end
	return nil
end

local function findCarryReturnBeamTarget(): BasePart?
	return findEntranceWall() or findEnterPart()
end

local function slotIsEmpty(slotModel: Model): boolean
	local configName = slotModel:GetAttribute("ConfigName")
	return type(configName) ~= "string" or configName == ""
end

local function getPlotSlotStandingPart(slotModel: Model): BasePart?
	local standingPart = slotModel:FindFirstChild("StandingPart", true)
	if standingPart and standingPart:IsA("BasePart") then
		return standingPart
	end
	return nil
end

local function findFirstEmptyPlotSlotStandingPart(): BasePart?
	local gameFolder = Workspace:FindFirstChild("Game")
	local plotsFolder = gameFolder and gameFolder:FindFirstChild("Plots")
	if not plotsFolder then
		return nil
	end

	for _, plotModel in plotsFolder:GetChildren() do
		if not plotModel:IsA("Model") then
			continue
		end
		if plotModel:GetAttribute("OwnerUserId") ~= localPlayer.UserId then
			continue
		end

		local slotsFolder = plotModel:FindFirstChild("Slots")
		if not slotsFolder then
			continue
		end

		local slotModels: { Model } = {}
		for _, child in slotsFolder:GetChildren() do
			if child:IsA("Model") then
				table.insert(slotModels, child)
			end
		end
		table.sort(slotModels, function(a, b)
			return a.Name < b.Name
		end)

		for _, slotModel in slotModels do
			if slotIsEmpty(slotModel) then
				local standingPart = getPlotSlotStandingPart(slotModel)
				if standingPart then
					return standingPart
				end
			end
		end
	end

	return nil
end

local function findLocalPlotTeleportPart(): BasePart?
	local gameFolder = Workspace:FindFirstChild("Game")
	local plotsFolder = gameFolder and gameFolder:FindFirstChild("Plots")
	if not plotsFolder then
		return nil
	end

	for _, plotModel in plotsFolder:GetChildren() do
		if not plotModel:IsA("Model") then
			continue
		end
		if plotModel:GetAttribute("OwnerUserId") ~= localPlayer.UserId then
			continue
		end

		local teleportPart = plotModel:FindFirstChild("TeleportPart", true)
		if teleportPart and teleportPart:IsA("BasePart") then
			return teleportPart
		end
	end

	return nil
end

local function findStepTargetPart(step: any): BasePart?
	if step.Target == "StrengthStore" then
		return findStrengthStoreProximityPart()
	end
	if step.Target == "SpeedStore" then
		return findSpeedStoreProximityPart()
	end
	if step.Target == "EntranceWall" then
		return findEntranceWall() or findEnterPart()
	end
	if step.Target == "PlotSlot" then
		return findFirstEmptyPlotSlotStandingPart() or findLocalPlotTeleportPart()
	end
	return nil
end

local function waitForStepTargetPart(step: any): BasePart?
	local deadline = os.clock() + 60
	while os.clock() < deadline do
		local targetPart = findStepTargetPart(step)
		if targetPart then
			return targetPart
		end
		task.wait(0.25)
	end
	return nil
end

local function getGameFolder(): Instance?
	return Workspace:FindFirstChild("Game")
end

local function getProcessPhase(): string?
	local gameFolder = getGameFolder()
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

local function getModelAnchorPart(model: Model): BasePart?
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function getFloorsFolder(): Folder?
	local gameFolder = getGameFolder()
	local mapFolder = gameFolder and gameFolder:FindFirstChild("Map")
	local floorsFolder = mapFolder and mapFolder:FindFirstChild("Floors")
	if floorsFolder and floorsFolder:IsA("Folder") then
		return floorsFolder
	end
	return nil
end

local function findClosestWorldLuckyBlock(origin: Vector3, rarity: string): Model?
	local floorsFolder = getFloorsFolder()
	if not floorsFolder then
		return nil
	end

	local closest: Model? = nil
	local closestDistance = math.huge

	for _, descendant in floorsFolder:GetDescendants() do
		if not descendant:IsA("Model") then
			continue
		end
		if descendant:GetAttribute("IsWorldLuckyBlock") ~= true then
			continue
		end
		if descendant:GetAttribute("Rarity") ~= rarity then
			continue
		end

		local anchorPart = getModelAnchorPart(descendant)
		if not anchorPart then
			continue
		end

		local distance = (anchorPart.Position - origin).Magnitude
		if distance < closestDistance then
			closestDistance = distance
			closest = descendant
		end
	end

	return closest
end

local function clearBeam()
	if beamState.beam then
		beamState.beam:Destroy()
	end
	if beamState.startAttachment then
		beamState.startAttachment:Destroy()
	end
	if beamState.endAttachment then
		beamState.endAttachment:Destroy()
	end

	beamState = {}
	trackedBeamTarget = nil
end

local function getTutorialBeamTemplate(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local vfx = assets and assets:FindFirstChild("VFX")
	return vfx and vfx:FindFirstChild("TutorialBeam")
end

local function attachBeamToCharacter(character: Model, targetPart: BasePart)
	if trackedBeamTarget == targetPart and beamState.beam and beamState.beam.Parent then
		return
	end

	clearBeam()

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local template = getTutorialBeamTemplate()
	if not template then
		warn("[Client_Tutorial] Assets.VFX.TutorialBeam not found")
		return
	end

	local templateStart = template:FindFirstChild("Start")
	local templateEnd = template:FindFirstChild("End")
	local templateBeam = template:FindFirstChild("Beam")
	if not templateStart or not templateStart:IsA("Attachment") then
		warn("[Client_Tutorial] TutorialBeam missing Start attachment")
		return
	end
	if not templateEnd or not templateEnd:IsA("Attachment") then
		warn("[Client_Tutorial] TutorialBeam missing End attachment")
		return
	end
	if not templateBeam or not templateBeam:IsA("Beam") then
		warn("[Client_Tutorial] TutorialBeam missing Beam")
		return
	end

	local startAttachment = templateStart:Clone()
	startAttachment.Name = "TutorialBeamStart"
	startAttachment.Parent = root

	local endAttachment = templateEnd:Clone()
	endAttachment.Name = "TutorialBeamEnd"
	endAttachment.Parent = targetPart

	local beam = templateBeam:Clone()
	beam.Name = "TutorialBeam"
	beam.Attachment0 = startAttachment
	beam.Attachment1 = endAttachment
	beam.Parent = root

	beamState = {
		startAttachment = startAttachment,
		endAttachment = endAttachment,
		beam = beam,
		targetPart = targetPart,
	}
	trackedBeamTarget = targetPart
end

local function updateBeamToTarget(targetPart: BasePart?)
	if not targetPart or not targetPart.Parent then
		clearBeam()
		return
	end

	local character = localPlayer.Character
	if not character then
		return
	end

	attachBeamToCharacter(character, targetPart)
end

local function hideStepMessage(stepIndex: number)
	Client_Messaging.HidePersistent(("TutorialStep_%d"):format(stepIndex))
end

local function showTutorialMessage(stepIndex: number, message: string, color: string?)
	local step = Shared_Tutorial.GetStep(stepIndex)
	if not step then
		return
	end

	Client_Messaging.ShowPersistent(
		("TutorialStep_%d"):format(stepIndex),
		message,
		color or step.MessageColor
	)
end

local function showStepMessage(stepIndex: number)
	local step = Shared_Tutorial.GetStep(stepIndex)
	if not step then
		return
	end

	showTutorialMessage(stepIndex, step.Message, step.MessageColor)
end

local function clearCachedRaceLuckyBlock()
	cachedRaceLuckyBlock = nil
	lastBlockSearchAt = 0
end

local function isCachedRaceLuckyBlockValid(): boolean
	if not cachedRaceLuckyBlock or not cachedRaceLuckyBlock.Parent then
		return false
	end
	return cachedRaceLuckyBlock:GetAttribute("IsWorldLuckyBlock") == true
end

local function findOrUpdateRaceLuckyBlock(origin: Vector3, rarity: string, forceSearch: boolean): Model?
	if not forceSearch and isCachedRaceLuckyBlockValid() then
		return cachedRaceLuckyBlock
	end

	if not forceSearch and (os.clock() - lastBlockSearchAt) < BLOCK_SEARCH_INTERVAL then
		return if isCachedRaceLuckyBlockValid() then cachedRaceLuckyBlock else nil
	end

	lastBlockSearchAt = os.clock()
	local found = findClosestWorldLuckyBlock(origin, rarity)
	if found then
		cachedRaceLuckyBlock = found
	elseif not isCachedRaceLuckyBlockValid() then
		cachedRaceLuckyBlock = nil
	end

	return cachedRaceLuckyBlock
end

local function disconnectSpeedStoreMonitor()
	if speedStepCashConn then
		speedStepCashConn:Disconnect()
		speedStepCashConn = nil
	end
end

local function disconnectEntranceStepMonitor()
	entranceStepPollToken += 1

	if entranceStepPhaseConn then
		entranceStepPhaseConn:Disconnect()
		entranceStepPhaseConn = nil
	end
	if entranceStepCarryConn then
		entranceStepCarryConn:Disconnect()
		entranceStepCarryConn = nil
	end

	clearCachedRaceLuckyBlock()
end

local function disconnectCompletion()
	if completionConn then
		completionConn:Disconnect()
		completionConn = nil
	end
end

local function completeCurrentStep()
	local stepIndex = currentStepIndex
	if not stepIndex then
		return
	end

	hideStepMessage(stepIndex)
	clearBeam()
	disconnectEntranceStepMonitor()
	disconnectSpeedStoreMonitor()

	if characterConn then
		characterConn:Disconnect()
		characterConn = nil
	end
	disconnectCompletion()

	currentStepIndex = nil
	setStrengthStoreHighlightActive(false)

	if tutorialHandler then
		tutorialHandler:FireServer("CompleteStep", stepIndex)
	end
end

local function isStrengthStepRequirementMet(stepIndex: number, strength: number?): boolean
	local step = Shared_Tutorial.GetStep(stepIndex)
	if not step or type(step.RequiredStrength) ~= "number" then
		return false
	end

	local resolvedStrength = strength
	if resolvedStrength == nil then
		resolvedStrength = tonumber(Client_Data:GetValue("Strength")) or 1
	end

	return resolvedStrength >= step.RequiredStrength
end

local function getSpeedPurchaseAmount(step: any): number
	if type(step.PurchaseAmount) == "number" and step.PurchaseAmount > 0 then
		return math.floor(step.PurchaseAmount)
	end
	return 1
end

local function getSpeedPurchaseCost(step: any, speed: number?): number
	local currentSpeed = speed
	if currentSpeed == nil then
		currentSpeed = math.max(
			1,
			math.floor(tonumber(Client_Data:GetValue("Speed")) or Shared_SpeedStore.DefaultSpeed)
		)
	end

	return Shared_SpeedStore.GetPurchaseCost(currentSpeed, getSpeedPurchaseAmount(step))
end

local function isSpeedStepRequirementMet(stepIndex: number, speed: number?): boolean
	local step = Shared_Tutorial.GetStep(stepIndex)
	if not step or type(step.RequiredSpeed) ~= "number" then
		return false
	end

	local resolvedSpeed = speed
	if resolvedSpeed == nil then
		resolvedSpeed = math.max(
			1,
			math.floor(tonumber(Client_Data:GetValue("Speed")) or Shared_SpeedStore.DefaultSpeed)
		)
	end

	return resolvedSpeed >= step.RequiredSpeed
end

local function isCashReadyForSpeedPurchase(stepIndex: number): boolean
	local step = Shared_Tutorial.GetStep(stepIndex)
	if not step then
		return false
	end

	local cash = tonumber(Client_Data:GetValue("Cash")) or 0
	return cash >= getSpeedPurchaseCost(step)
end

local function getSpeedStoreStepBeamTarget(stepIndex: number): BasePart?
	if not isCashReadyForSpeedPurchase(stepIndex) then
		return nil
	end

	local step = Shared_Tutorial.GetStep(stepIndex)
	if not step then
		return nil
	end

	return findStepTargetPart(step)
end

local function getSpeedStoreCollectMessage(stepIndex: number): string
	local step = Shared_Tutorial.GetStep(stepIndex)
	if not step then
		return "Collect $0/$0"
	end

	local cash = math.max(0, math.floor(tonumber(Client_Data:GetValue("Cash")) or 0))
	local cost = getSpeedPurchaseCost(step)
	return ("Collect $%s/$%s"):format(Shared_Abbreviation:Number(cash), Shared_Abbreviation:Number(cost))
end

local function refreshSpeedStoreStep(stepIndex: number)
	local step = Shared_Tutorial.GetStep(stepIndex)
	if not step or currentStepIndex ~= stepIndex or step.Target ~= "SpeedStore" then
		return
	end

	if isCashReadyForSpeedPurchase(stepIndex) then
		showTutorialMessage(stepIndex, step.ReadyMessage or "Purchase +1 Speed!", step.MessageColor)
		local targetPart = findSpeedStoreProximityPart()
		if targetPart then
			updateBeamToTarget(targetPart)
		else
			clearBeam()
		end
		return
	end

	showTutorialMessage(stepIndex, getSpeedStoreCollectMessage(stepIndex), step.MessageColor)
	clearBeam()
end

local function getEntranceStepBeamTarget(stepIndex: number): BasePart?
	local step = Shared_Tutorial.GetStep(stepIndex)
	if not step then
		return nil
	end

	if localPlayer:GetAttribute("CarryingLuckyBlock") == true then
		return findCarryReturnBeamTarget()
	end

	if not isLuckyBlockRaceActive() then
		return findEntranceWall() or findEnterPart()
	end

	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local origin = if root and root:IsA("BasePart") then root.Position else Vector3.zero
	local rarity = if type(step.PickupRarity) == "string" then step.PickupRarity else "Common"
	local luckyBlock = findOrUpdateRaceLuckyBlock(origin, rarity, false)
	if luckyBlock then
		return getModelAnchorPart(luckyBlock)
	end

	return nil
end

local function refreshEntranceStep(stepIndex: number, forceBlockSearch: boolean?)
	local step = Shared_Tutorial.GetStep(stepIndex)
	if not step or currentStepIndex ~= stepIndex or step.Target ~= "EntranceWall" then
		return
	end

	local carrying = localPlayer:GetAttribute("CarryingLuckyBlock") == true
	local returnTarget = findCarryReturnBeamTarget()
	local entranceTarget = findEntranceWall() or findEnterPart()

	if carrying then
		clearCachedRaceLuckyBlock()
		showTutorialMessage(stepIndex, step.CarryingMessage or step.Message, step.MessageColor)
		if returnTarget then
			updateBeamToTarget(returnTarget)
		end
		return
	end

	if not isLuckyBlockRaceActive() then
		clearCachedRaceLuckyBlock()
		showTutorialMessage(stepIndex, step.WaitForRaceMessage or step.Message, step.MessageColor)
		if entranceTarget then
			updateBeamToTarget(entranceTarget)
		end
		return
	end

	showTutorialMessage(stepIndex, step.RaceActiveMessage or step.Message, step.MessageColor)

	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local origin = if root and root:IsA("BasePart") then root.Position else Vector3.zero
	local rarity = if type(step.PickupRarity) == "string" then step.PickupRarity else "Common"
	local luckyBlock = findOrUpdateRaceLuckyBlock(origin, rarity, forceBlockSearch == true)
	if luckyBlock then
		local targetPart = getModelAnchorPart(luckyBlock)
		if targetPart then
			updateBeamToTarget(targetPart)
		end
		return
	end

	clearBeam()
end

local function bindStrengthStepCompletion(stepIndex: number)
	disconnectCompletion()

	if isStrengthStepRequirementMet(stepIndex) then
		completeCurrentStep()
		return
	end

	local events = ReplicatedStorage:FindFirstChild("Events")
	local plotHandler = events and events:FindFirstChild("PlotHandler")
	if not plotHandler or not plotHandler:IsA("RemoteEvent") then
		return
	end

	completionConn = plotHandler.OnClientEvent:Connect(function(action: string, _amount: any, _cost: any, newStrength: any)
		if currentStepIndex ~= stepIndex then
			return
		end

		if action == "StrengthPurchaseSuccess" and type(newStrength) == "number" then
			if isStrengthStepRequirementMet(stepIndex, newStrength) then
				completeCurrentStep()
			end
		end
	end)
end

local function bindEntranceStepCompletion(stepIndex: number)
	disconnectCompletion()

	local step = Shared_Tutorial.GetStep(stepIndex)
	if not step then
		return
	end

	local events = ReplicatedStorage:FindFirstChild("Events")
	local gameProcessHandler = events and events:FindFirstChild("GameProcessHandler")
	if not gameProcessHandler or not gameProcessHandler:IsA("RemoteEvent") then
		return
	end

	completionConn = gameProcessHandler.OnClientEvent:Connect(function(action: string)
		if currentStepIndex ~= stepIndex then
			return
		end

		if action == "LuckyBlockDelivered" then
			completeCurrentStep()
			return
		end

		if action == "UnluckyMapClose" then
			clearCachedRaceLuckyBlock()
			showTutorialMessage(
				stepIndex,
				step.FailedRaceMessage or step.WaitForRaceMessage or step.Message,
				step.MessageColor
			)
			refreshEntranceStep(stepIndex, true)
		end
	end)
end

local function bindOpenLuckyBlockStepCompletion(stepIndex: number)
	disconnectCompletion()

	local events = ReplicatedStorage:FindFirstChild("Events")
	local plotHandler = events and events:FindFirstChild("PlotHandler")
	if not plotHandler or not plotHandler:IsA("RemoteEvent") then
		return
	end

	completionConn = plotHandler.OnClientEvent:Connect(function(action: string, data: any)
		if currentStepIndex ~= stepIndex then
			return
		end

		if action ~= "LuckyBlockOpen" or type(data) ~= "table" then
			return
		end

		if data.openingUserId == localPlayer.UserId then
			completeCurrentStep()
		end
	end)
end

local function bindSpeedStoreStepCompletion(stepIndex: number)
	disconnectCompletion()

	if isSpeedStepRequirementMet(stepIndex) then
		completeCurrentStep()
		return
	end

	local step = Shared_Tutorial.GetStep(stepIndex)
	if not step then
		return
	end

	local events = ReplicatedStorage:FindFirstChild("Events")
	local plotHandler = events and events:FindFirstChild("PlotHandler")
	if not plotHandler or not plotHandler:IsA("RemoteEvent") then
		return
	end

	local purchaseAmount = getSpeedPurchaseAmount(step)

	completionConn = plotHandler.OnClientEvent:Connect(function(action: string, amount: any, _cost: any, newSpeed: any)
		if currentStepIndex ~= stepIndex then
			return
		end

		if action ~= "SpeedPurchaseSuccess" then
			return
		end

		if type(amount) == "number" and amount >= purchaseAmount then
			completeCurrentStep()
			return
		end

		if type(newSpeed) == "number" and isSpeedStepRequirementMet(stepIndex, newSpeed) then
			completeCurrentStep()
		end
	end)
end

local function bindPlaceBrainrotStepCompletion(stepIndex: number)
	disconnectCompletion()

	local events = ReplicatedStorage:FindFirstChild("Events")
	local plotHandler = events and events:FindFirstChild("PlotHandler")
	if not plotHandler or not plotHandler:IsA("RemoteEvent") then
		return
	end

	completionConn = plotHandler.OnClientEvent:Connect(function(action: string)
		if currentStepIndex ~= stepIndex then
			return
		end

		if action == "PlaceSuccess" then
			completeCurrentStep()
		end
	end)
end

local function bindStepCompletion(stepIndex: number)
	local step = Shared_Tutorial.GetStep(stepIndex)
	if not step then
		return
	end

	if step.Target == "StrengthStore" then
		bindStrengthStepCompletion(stepIndex)
		return
	end

	if step.Target == "EntranceWall" then
		bindEntranceStepCompletion(stepIndex)
		return
	end

	if step.Target == "OpenLuckyBlock" then
		bindOpenLuckyBlockStepCompletion(stepIndex)
		return
	end

	if step.Target == "PlotSlot" then
		bindPlaceBrainrotStepCompletion(stepIndex)
		return
	end

	if step.Target == "SpeedStore" then
		bindSpeedStoreStepCompletion(stepIndex)
	end
end

local function bindCharacterBeamRefresh(stepIndex: number, getTarget: () -> BasePart?)
	if characterConn then
		characterConn:Disconnect()
	end

	characterConn = localPlayer.CharacterAdded:Connect(function(character)
		if currentStepIndex ~= stepIndex then
			return
		end

		local targetPart = getTarget()
		if targetPart then
			attachBeamToCharacter(character, targetPart)
		end
	end)
end

local function startEntranceStep(stepIndex: number)
	disconnectEntranceStepMonitor()
	showStepMessage(stepIndex)

	task.spawn(function()
		waitForStepTargetPart(Shared_Tutorial.GetStep(stepIndex))
		if currentStepIndex ~= stepIndex then
			return
		end
		refreshEntranceStep(stepIndex, true)
	end)

	local gameFolder = getGameFolder()
	if gameFolder then
		entranceStepPhaseConn = gameFolder:GetAttributeChangedSignal("ProcessPhase"):Connect(function()
			refreshEntranceStep(stepIndex, true)
		end)
	end

	entranceStepCarryConn = localPlayer:GetAttributeChangedSignal("CarryingLuckyBlock"):Connect(function()
		refreshEntranceStep(stepIndex, true)
	end)

	entranceStepPollToken += 1
	local pollToken = entranceStepPollToken
	task.spawn(function()
		while pollToken == entranceStepPollToken and currentStepIndex == stepIndex do
			if isLuckyBlockRaceActive() and localPlayer:GetAttribute("CarryingLuckyBlock") ~= true then
				refreshEntranceStep(stepIndex, true)
			end
			task.wait(BLOCK_SEARCH_INTERVAL)
		end
	end)

	bindCharacterBeamRefresh(stepIndex, function()
		return getEntranceStepBeamTarget(stepIndex)
	end)

	refreshEntranceStep(stepIndex, true)
end

local function startOpenLuckyBlockStep(stepIndex: number)
	clearBeam()
	showStepMessage(stepIndex)
end

local function startPlaceBrainrotStep(stepIndex: number)
	local step = Shared_Tutorial.GetStep(stepIndex)

	task.spawn(function()
		local luckyBlockOpening = ClientLoader.require("Client_LuckyBlockOpening")
		while currentStepIndex == stepIndex and luckyBlockOpening.IsOpeningBusy() do
			task.wait(0.1)
		end
		if currentStepIndex ~= stepIndex then
			return
		end

		showStepMessage(stepIndex)

		local targetPart = waitForStepTargetPart(step)
		if currentStepIndex ~= stepIndex or not targetPart then
			return
		end

		local character = localPlayer.Character
		if character then
			attachBeamToCharacter(character, targetPart)
		end
	end)

	bindCharacterBeamRefresh(stepIndex, function()
		if not step then
			return nil
		end
		return findStepTargetPart(step)
	end)
end

local function startSpeedStoreStep(stepIndex: number)
	disconnectSpeedStoreMonitor()
	refreshSpeedStoreStep(stepIndex)

	speedStepCashConn = Client_Data:ListenToChange("Cash", function()
		refreshSpeedStoreStep(stepIndex)
	end)

	bindCharacterBeamRefresh(stepIndex, function()
		return getSpeedStoreStepBeamTarget(stepIndex)
	end)
end

local function startStaticTargetStep(stepIndex: number, step: any)
	setStrengthStoreHighlightActive(step.Target == "StrengthStore")

	task.spawn(function()
		local targetPart = waitForStepTargetPart(step)
		if currentStepIndex ~= stepIndex or not targetPart then
			return
		end

		local character = localPlayer.Character
		if character then
			attachBeamToCharacter(character, targetPart)
		end

		bindCharacterBeamRefresh(stepIndex, function()
			return findStepTargetPart(step)
		end)
	end)
end

local function startStep(stepIndex: number)
	local step = Shared_Tutorial.GetStep(stepIndex)
	if not step then
		return
	end

	if step.Target == "StrengthStore" and isStrengthStepRequirementMet(stepIndex) then
		if tutorialHandler then
			tutorialHandler:FireServer("CompleteStep", stepIndex)
		end
		return
	end

	if step.Target == "SpeedStore" and isSpeedStepRequirementMet(stepIndex) then
		if tutorialHandler then
			tutorialHandler:FireServer("CompleteStep", stepIndex)
		end
		return
	end

	currentStepIndex = stepIndex
	bindStepCompletion(stepIndex)
	setStrengthStoreHighlightActive(step.Target == "StrengthStore")

	if step.Target == "EntranceWall" then
		startEntranceStep(stepIndex)
		return
	end

	if step.Target == "OpenLuckyBlock" then
		startOpenLuckyBlockStep(stepIndex)
		return
	end

	if step.Target == "PlotSlot" then
		startPlaceBrainrotStep(stepIndex)
		return
	end

	if step.Target == "SpeedStore" then
		startSpeedStoreStep(stepIndex)
		return
	end

	showStepMessage(stepIndex)
	startStaticTargetStep(stepIndex, step)
end

local function finishTutorial()
	clearBeam()
	disconnectEntranceStepMonitor()
	disconnectSpeedStoreMonitor()
	if characterConn then
		characterConn:Disconnect()
		characterConn = nil
	end
	disconnectCompletion()
	if currentStepIndex then
		hideStepMessage(currentStepIndex)
		currentStepIndex = nil
	end
	setStrengthStoreHighlightActive(false)
end

local function onStepCompleted(stepId: number)
	if stepId >= Shared_Tutorial.GetStepCount() then
		local completedStep = Shared_Tutorial.GetStep(stepId)
		finishTutorial()
		Client_Messaging.Show(
			(completedStep and completedStep.CompletedMessage) or "Tutorial is completed!",
			"green"
		)
		ClientLoader.require("Client_LuckyBlockCarry").PlayRaceFinishSuccessSfx()
		return
	end

	startStep(stepId + 1)
end

local function shouldRunTutorial(): boolean
	if Client_Data:GetValue("TutorialCompleted") == true then
		return false
	end
	return Shared_Tutorial.GetStepCount() > 0
end

local tryStartTutorial: () -> ()

local function connectTutorialHandler()
	if tutorialHandlerConnected then
		return
	end

	local events = ReplicatedStorage:FindFirstChild("Events")
	tutorialHandler = events and events:FindFirstChild("TutorialHandler") :: RemoteEvent?
	if not tutorialHandler or not tutorialHandler:IsA("RemoteEvent") then
		return
	end

	tutorialHandlerConnected = true
	tutorialHandler.OnClientEvent:Connect(function(action: string, stepId: any)
		if action == "Restart" then
			finishTutorial()
			task.defer(function()
				tryStartTutorial()
			end)
			return
		end

		if action == "StepCompleted" and type(stepId) == "number" then
			onStepCompleted(stepId)
		end
	end)
end

tryStartTutorial = function()
	if currentStepIndex ~= nil then
		return
	end
	if not shouldRunTutorial() then
		return
	end

	connectTutorialHandler()
	startStep(1)
end

function Client_Tutorial.Init()
	Client_Data.WaitUntilReady()
	connectTutorialHandler()

	Client_Data:ListenToChange("TutorialCompleted", function(value)
		if value == true then
			finishTutorial()
			return
		end

		finishTutorial()
		task.defer(function()
			tryStartTutorial()
		end)
	end)

	tryStartTutorial()
end

return Client_Tutorial
