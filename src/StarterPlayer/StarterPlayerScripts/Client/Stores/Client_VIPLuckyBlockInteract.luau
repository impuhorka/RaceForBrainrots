local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local ClientLoader = require(script.Parent.Parent.Loader)
local Shared_GameProcess = SharedModules.require("Shared_GameProcess")
local Shared_Marketplace = SharedModules.require("Shared_Marketplace")
local Shared_ProximityPrompt = SharedModules.require("Shared_ProximityPrompt")
local Shared_SixSevenReward = SharedModules.require("Shared_SixSevenReward")
local Shared_Weight = SharedModules.require("Shared_Weight")

local Client_VIPLuckyBlockInteract = {}

local VIP_MODEL_NAME = "VIPLuckyBlock"
local VIP_PROMPT_NAME = "VIPLuckyBlockBuyPrompt"
local UNIT_CONFIG_KEY = Shared_Marketplace.GetVIPLuckyBlockProductKey(1)

local SIX_SEVEN_MODEL_NAME = "SixSevenLuckyBlock"
local SIX_SEVEN_PROMPT_NAME = "SixSevenLuckyBlockLikePrompt"
local SIX_SEVEN_MODEL_ALIASES = {
	SixSevenLuckyBlock = true,
	["67LuckyBlock"] = true,
	SixSeven = true,
	["67"] = true,
}
local GROUP_ID = Shared_SixSevenReward.GroupId
local CLAIM_WAIT_SECONDS = Shared_SixSevenReward.ClaimWaitSeconds
local SERVER_RESPONSE_GRACE_SECONDS = Shared_SixSevenReward.ServerResponseGraceSeconds

local localPlayer = Players.LocalPlayer

local hookedVipModel: Model? = nil
local hookedSixSevenModel: Model? = nil
local sixSevenPrompt: ProximityPrompt? = nil
local floatConnections: { [Model]: RBXScriptConnection } = {}
local claimInProgress = false
local waitingForServerClaim = false
local claimSessionResolved = false
local plotHandler: RemoteEvent? = nil
local boundInteractFolders: { [Instance]: boolean } = {}

local function getPlotHandler(): RemoteEvent
	if plotHandler then
		return plotHandler
	end

	plotHandler = ReplicatedStorage:WaitForChild("Events"):WaitForChild("PlotHandler") :: RemoteEvent
	return plotHandler
end

local function hasClaimedSixSevenReward(): boolean
	local Client_Data = ClientLoader.require("Client_Data")
	return Client_Data:GetValue("SixSevenGroupRewardClaimed") == true
end

local function refreshSixSevenPromptState()
	if not sixSevenPrompt then
		return
	end

	local Client_Data = ClientLoader.require("Client_Data")
	if not Client_Data.IsReady then
		sixSevenPrompt.Enabled = true
		return
	end

	sixSevenPrompt.Enabled = not claimInProgress
end

local function isSixSevenModel(instance: Instance): boolean
	if not instance:IsA("Model") then
		return false
	end

	if SIX_SEVEN_MODEL_ALIASES[instance.Name] then
		return true
	end

	local normalized = string.lower(string.gsub(instance.Name, "[^%w]", ""))
	return normalized == "sixsevenluckyblock" or normalized == "67luckyblock" or normalized == "sixseven"
end

local function resolveModelPrimary(model: Model): BasePart?
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end

	local primary = model:FindFirstChildWhichIsA("BasePart", true)
	if primary then
		model.PrimaryPart = primary
	end

	return primary
end

local function findInteractModel(root: Instance, matcher: (Instance) -> boolean): Model?
	if matcher(root) then
		return root :: Model
	end

	for _, descendant in root:GetDescendants() do
		if matcher(descendant) then
			return descendant :: Model
		end
	end

	return nil
end

local function isLocalPlayerInGroup(): boolean
	local ok, inGroup = pcall(function()
		return localPlayer:IsInGroup(GROUP_ID)
	end)
	return ok and inGroup == true
end

local function promptJoinGroupIfNeeded()
	if isLocalPlayerInGroup() then
		return
	end

	pcall(function()
		GroupService:PromptJoinAsync(GROUP_ID)
	end)
end

local function findCostLabel(model: Model): TextLabel?
	for _, descendant in model:GetDescendants() do
		if descendant.Name == "Cost" and descendant:IsA("TextLabel") then
			return descendant
		end
	end

	return nil
end

local function refreshCostLabel(costLabel: TextLabel?)
	if not costLabel then
		return
	end

	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	local price = Client_Marketplace.GetUserPriceInRobux(UNIT_CONFIG_KEY)
	if price then
		costLabel.Text = Shared_Marketplace.FormatRobuxPrice(price)
	end
end

local function stopFloatAnimation(model: Model)
	local connection = floatConnections[model]
	if connection then
		connection:Disconnect()
		floatConnections[model] = nil
	end
end

local function startFloatAnimation(model: Model)
	stopFloatAnimation(model)

	local primary = resolveModelPrimary(model)
	if not primary then
		return
	end

	Shared_Weight.SyncLuckyBlockPivot(model)
	Shared_Weight.PrepareLuckyBlockForWorld(model)

	local basePosition = model:GetPivot().Position
	local baseRotation = Shared_GameProcess.GetFlatYawRotation(model:GetPivot())
	local _, bboxSize = model:GetBoundingBox()
	local floatHeight = math.max(
		Shared_GameProcess.GetWorldLuckyBlockFloatHeight(bboxSize.Y),
		1.25
	)
	local floatSpeed = Shared_GameProcess.WorldLuckyBlockFloatSpeed
	local idleSpinSpeed = math.rad(Shared_GameProcess.WorldLuckyBlockRotateSpeed)
	local spinDirection = if math.random() < 0.5 then -1 else 1

	local phase = math.pi
	local startTime = os.clock()
	local idleSpinYaw = 0
	local lastTick = os.clock()

	floatConnections[model] = RunService.RenderStepped:Connect(function()
		if not model.Parent then
			stopFloatAnimation(model)
			return
		end

		local now = os.clock()
		local dt = now - lastTick
		lastTick = now

		local elapsed = now - startTime
		local yOffset = math.sin(elapsed * floatSpeed + phase) * floatHeight
		idleSpinYaw += idleSpinSpeed * spinDirection * dt

		local rotation = CFrame.Angles(0, idleSpinYaw, 0) * baseRotation
		model:PivotTo(CFrame.new(basePosition + Vector3.new(0, yOffset, 0)) * rotation)
	end)

	model.Destroying:Once(function()
		stopFloatAnimation(model)
	end)
end

local function requestSixSevenRewardClaim()
	waitingForServerClaim = true
	getPlotHandler():FireServer("ClaimSixSevenGroupReward")
end

local function finishSixSevenClaimSession(showTimeoutMessage: boolean?)
	claimInProgress = false
	waitingForServerClaim = false

	if showTimeoutMessage and not claimSessionResolved and not hasClaimedSixSevenReward() then
		local Client_Messaging = ClientLoader.require("Client_Messaging")
		Client_Messaging.Show(Shared_SixSevenReward.TimeoutMessage, "red")
	end

	refreshSixSevenPromptState()
end

local function runSixSevenClaimSession()
	local Client_Messaging = ClientLoader.require("Client_Messaging")

	promptJoinGroupIfNeeded()

	if not isLocalPlayerInGroup() then
		Client_Messaging.Show(Shared_SixSevenReward.JoinMessage, "green")
	end

	local joinDeadline = os.clock() + CLAIM_WAIT_SECONDS

	while os.clock() < joinDeadline do
		if claimSessionResolved or hasClaimedSixSevenReward() then
			finishSixSevenClaimSession(false)
			return
		end

		if isLocalPlayerInGroup() and not waitingForServerClaim then
			requestSixSevenRewardClaim()
		end

		task.wait(0.25)
	end

	local responseDeadline = os.clock() + SERVER_RESPONSE_GRACE_SECONDS
	while os.clock() < responseDeadline do
		if claimSessionResolved or hasClaimedSixSevenReward() then
			finishSixSevenClaimSession(false)
			return
		end

		if isLocalPlayerInGroup() and not waitingForServerClaim then
			requestSixSevenRewardClaim()
		end

		task.wait(0.25)
	end

	finishSixSevenClaimSession(true)
end

local function onSixSevenLikeTriggered()
	if claimInProgress then
		return
	end

	if hasClaimedSixSevenReward() then
		local Client_Messaging = ClientLoader.require("Client_Messaging")
		Client_Messaging.Show(Shared_SixSevenReward.AlreadyClaimedMessage, "red")
		return
	end

	claimInProgress = true
	claimSessionResolved = false
	waitingForServerClaim = false
	refreshSixSevenPromptState()

	task.spawn(runSixSevenClaimSession)
end

local function onSixSevenClaimFailed(reason: string)
	local Client_Messaging = ClientLoader.require("Client_Messaging")

	if reason == "Not in group" or reason == "Already processing" then
		waitingForServerClaim = false
		return
	end

	if reason == "Already claimed" then
		claimSessionResolved = true
		finishSixSevenClaimSession(false)
		Client_Messaging.Show(Shared_SixSevenReward.AlreadyClaimedMessage, "red")
		return
	end

	claimSessionResolved = true
	finishSixSevenClaimSession(false)

	if reason == "Inventory is full" then
		Client_Messaging.Show(reason, "red")
	end
end

local function onVipBuyTriggered()
	local Client_RobuxStore = ClientLoader.require("Client_RobuxStore")
	Client_RobuxStore.OpenToVIPLuckyBlock()
end

local function setupVipPrompt(model: Model)
	local primary = resolveModelPrimary(model)
	if not primary then
		return
	end

	local prompt = Shared_ProximityPrompt.Create(primary, {
		Name = VIP_PROMPT_NAME,
		ActionText = "Buy now!",
		ObjectText = "",
		HoldDuration = 0.5,
		MaxActivationDistance = 16,
		RequiresLineOfSight = false,
	})

	prompt.Triggered:Connect(onVipBuyTriggered)
end

local function setupSixSevenPrompt(model: Model)
	local primary = resolveModelPrimary(model)
	if not primary then
		warn(`[Client_VIPLuckyBlockInteract] SixSeven model has no BasePart: {model:GetFullName()}`)
		return
	end

	local prompt = Shared_ProximityPrompt.Create(primary, {
		Name = SIX_SEVEN_PROMPT_NAME,
		ActionText = "I've Liked!",
		ObjectText = "",
		HoldDuration = 0.5,
		MaxActivationDistance = 16,
		RequiresLineOfSight = false,
	})

	prompt.Triggered:Connect(onSixSevenLikeTriggered)
	prompt.Enabled = true
	sixSevenPrompt = prompt
	refreshSixSevenPromptState()
end

local function hookVipModel(model: Model)
	if hookedVipModel == model then
		return
	end

	hookedVipModel = model
	setupVipPrompt(model)
	refreshCostLabel(findCostLabel(model))
	startFloatAnimation(model)

	model.Destroying:Connect(function()
		if hookedVipModel == model then
			hookedVipModel = nil
		end
		stopFloatAnimation(model)
	end)
end

local function hookSixSevenModel(model: Model)
	if hookedSixSevenModel == model then
		return
	end

	hookedSixSevenModel = model
	setupSixSevenPrompt(model)
	startFloatAnimation(model)

	model.Destroying:Connect(function()
		if hookedSixSevenModel == model then
			hookedSixSevenModel = nil
			sixSevenPrompt = nil
		end
		stopFloatAnimation(model)
	end)
end

local function tryHookInteractModels(interactFolder: Instance)
	local vipModel = interactFolder:FindFirstChild(VIP_MODEL_NAME)
	if vipModel and vipModel:IsA("Model") then
		hookVipModel(vipModel)
	else
		local nestedVip = findInteractModel(interactFolder, function(instance)
			return instance:IsA("Model") and instance.Name == VIP_MODEL_NAME
		end)
		if nestedVip then
			hookVipModel(nestedVip)
		end
	end

	if hookedSixSevenModel == nil then
		local sixSevenModel = findInteractModel(interactFolder, isSixSevenModel)
		if sixSevenModel then
			hookSixSevenModel(sixSevenModel)
		end
	end
end

local function onInteractDescendantAdded(descendant: Instance)
	if descendant:IsA("Model") and descendant.Name == VIP_MODEL_NAME then
		hookVipModel(descendant)
		return
	end

	if isSixSevenModel(descendant) then
		hookSixSevenModel(descendant)
	end
end

local function bindInteractFolder(interactFolder: Instance)
	if boundInteractFolders[interactFolder] then
		tryHookInteractModels(interactFolder)
		return
	end

	boundInteractFolders[interactFolder] = true
	tryHookInteractModels(interactFolder)

	interactFolder.ChildAdded:Connect(onInteractDescendantAdded)
	interactFolder.DescendantAdded:Connect(onInteractDescendantAdded)
end

local function tryBindInteractFolder()
	local gameFolder = Workspace:FindFirstChild("Game")
	local interactFolder = gameFolder and gameFolder:FindFirstChild("Interact")
	if interactFolder then
		bindInteractFolder(interactFolder)
	end
end

function Client_VIPLuckyBlockInteract.Init()
	local Client_Data = ClientLoader.require("Client_Data")
	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	local Client_Messaging = ClientLoader.require("Client_Messaging")

	local function refreshVipPrice()
		if hookedVipModel then
			refreshCostLabel(findCostLabel(hookedVipModel))
		end
	end

	Client_Marketplace.OnPricesChanged(refreshVipPrice)

	task.spawn(function()
		Client_Marketplace.WaitUntilReady()
		refreshVipPrice()
	end)

	getPlotHandler().OnClientEvent:Connect(function(action: string, arg1: any)
		if action == "SixSevenGroupRewardSuccess" then
			claimSessionResolved = true
			finishSixSevenClaimSession(false)
			Client_Messaging.Show(Shared_SixSevenReward.SuccessMessage, "green")
			return
		end

		if action == "SixSevenGroupRewardFailed" then
			local reason = if type(arg1) == "string" then arg1 else "Could not claim reward."
			onSixSevenClaimFailed(reason)
		end
	end)

	task.spawn(function()
		Client_Data.WaitUntilReady()
		refreshSixSevenPromptState()

		Client_Data:ListenToChange("SixSevenGroupRewardClaimed", function()
			claimSessionResolved = true
			finishSixSevenClaimSession(false)
		end)
	end)

	local gameFolder = Workspace:WaitForChild("Game")
	gameFolder.ChildAdded:Connect(function(child)
		if child.Name == "Interact" then
			bindInteractFolder(child)
		end
	end)

	task.spawn(function()
		local gameFolder = Workspace:WaitForChild("Game", 60)
		if not gameFolder then
			return
		end

		local interactFolder = gameFolder:WaitForChild("Interact", 60)
		if not interactFolder then
			return
		end

		bindInteractFolder(interactFolder)

		for _ = 1, 30 do
			if hookedSixSevenModel then
				break
			end

			tryHookInteractModels(interactFolder)
			task.wait(1)
		end
	end)

	tryBindInteractFolder()
end

return Client_VIPLuckyBlockInteract
