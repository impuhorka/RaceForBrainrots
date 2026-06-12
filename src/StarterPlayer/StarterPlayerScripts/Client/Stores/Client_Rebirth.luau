local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local ClientLoader = require(script.Parent.Parent.Loader)

local Shared_Abbreviation = SharedModules.require("Shared_Abbreviation")
local Shared_Rebirth = SharedModules.require("Shared_Rebirth")
local Client_Data = ClientLoader.require("Client_Data")
local Client_Messaging = ClientLoader.require("Client_Messaging")
local Client_TadaEffect = ClientLoader.require("Client_TadaEffect")
local Client_FOV = ClientLoader.require("Client_FOV")
local Client_GuideBeam = require(script.Parent.Parent.Core.Client_GuideBeam)
local Client_Tutorial = ClientLoader.require("Client_Tutorial")

local Client_Rebirth = {}

local REBIRTH_READY_MESSAGE = "You can rebirth now!"
local REBIRTH_BEAM_MAX_COUNT = 3

local PROXIMITY_PART_NAMES = {
	ProximityPart = true,
	ProximityPrompt = true,
}

local FRAME_ATTACHED_TAG = "FrameAttached"
local REBIRTH_FRAME_NAME = "Rebirth"

local plotHandler: RemoteEvent?
local rebirthOpenButtons: { [ImageButton]: boolean } = {}
local rebirthFrame: GuiObject?
local cashBeforeLabel: TextLabel?
local cashAfterLabel: TextLabel?
local spdBeforeLabel: TextLabel?
local spdAfterLabel: TextLabel?
local strBeforeLabel: TextLabel?
local strAfterLabel: TextLabel?
local costLabel: TextLabel?
local buyButton: ImageButton?
local characterConn: RBXScriptConnection? = nil
local wasAffordRebirth = false

local function isProximityAnchorPart(instance: Instance): boolean
	return instance:IsA("BasePart") and PROXIMITY_PART_NAMES[instance.Name] == true
end

local function findRebirthProximityPart(): BasePart?
	local gameFolder = Workspace:FindFirstChild("Game")
	local interactFolder = gameFolder and gameFolder:FindFirstChild("Interact")
	if not interactFolder then
		return nil
	end

	for _, descendant in interactFolder:GetDescendants() do
		if descendant:IsA("Model") and descendant.Name == "Rebirth" then
			for _, part in descendant:GetDescendants() do
				if isProximityAnchorPart(part) then
					return part
				end
			end
		end
	end

	return nil
end

local function canAffordRebirth(): boolean
	local rebirths = Shared_Rebirth.GetRebirthCount(Client_Data:GetValue("Rebirths"))
	local cost = Shared_Rebirth.GetCost(rebirths)
	local cash = tonumber(Client_Data:GetValue("Cash")) or 0
	return cash >= cost
end

local function getRebirthCount(): number
	return Shared_Rebirth.GetRebirthCount(Client_Data:GetValue("Rebirths"))
end

local function isFirstRebirth(): boolean
	return getRebirthCount() == 0
end

local function shouldShowRebirthBeam(): boolean
	if getRebirthCount() >= REBIRTH_BEAM_MAX_COUNT or not canAffordRebirth() then
		return false
	end

	if Client_Tutorial.IsGuiding and Client_Tutorial.IsGuiding() then
		return false
	end

	if rebirthFrame and rebirthFrame.Visible then
		return false
	end

	return true
end

local function refreshRebirthBeam()
	if not shouldShowRebirthBeam() then
		Client_GuideBeam.Clear()
		return
	end

	local targetPart = findRebirthProximityPart()
	if targetPart then
		Client_GuideBeam.AttachToTarget(targetPart)
	else
		Client_GuideBeam.Clear()
	end
end

local function notifyRebirthReady()
	Client_Messaging.Show(REBIRTH_READY_MESSAGE, "green")

	if isFirstRebirth() then
		ClientLoader.require("Client_LuckyBlockCarry").PlayRaceFinishSuccessSfx()
	end
end

local function refreshRebirthGuidance()
	local afford = canAffordRebirth()
	local justBecameEligible = afford and not wasAffordRebirth
	wasAffordRebirth = afford

	if justBecameEligible then
		notifyRebirthReady()
	end

	refreshRebirthBeam()
end

local function bindCharacterBeamRefresh()
	if characterConn then
		characterConn:Disconnect()
	end

	characterConn = Players.LocalPlayer.CharacterAdded:Connect(function()
		task.defer(refreshRebirthGuidance)
	end)
end

local function getValueLabel(root: Instance): TextLabel?
	local label = root:FindFirstChild("Value")
	if label and label:IsA("TextLabel") then
		return label
	end
	return nil
end

local function updateRebirthOpenButtons(rebirths: number)
	local text = tostring(rebirths)

	for button in rebirthOpenButtons do
		local label = button:FindFirstChild("TotalRebirths", true)
		if label and label:IsA("TextLabel") then
			label.Text = text
		end
	end
end

local function isRebirthOpenButton(instance: Instance): boolean
	return instance:IsA("ImageButton") and instance:GetAttribute("AttachedFrame") == REBIRTH_FRAME_NAME
end

local function trackRebirthOpenButton(instance: Instance)
	if not isRebirthOpenButton(instance) then
		return
	end

	local button = instance :: ImageButton
	if rebirthOpenButtons[button] then
		return
	end

	rebirthOpenButtons[button] = true
	button.Destroying:Connect(function()
		rebirthOpenButtons[button] = nil
	end)

	updateRebirthOpenButtons(Shared_Rebirth.GetRebirthCount(Client_Data:GetValue("Rebirths")))
end

local function hookRebirthOpenButtons()
	CollectionService:GetInstanceAddedSignal(FRAME_ATTACHED_TAG):Connect(trackRebirthOpenButton)

	for _, instance in CollectionService:GetTagged(FRAME_ATTACHED_TAG) do
		trackRebirthOpenButton(instance)
	end
end

local function render()
	local rebirths = Shared_Rebirth.GetRebirthCount(Client_Data:GetValue("Rebirths"))

	updateRebirthOpenButtons(rebirths)

	if cashBeforeLabel then
		cashBeforeLabel.Text = Shared_Rebirth.FormatMultiplier(rebirths)
	end
	if cashAfterLabel then
		cashAfterLabel.Text = Shared_Rebirth.FormatMultiplier(rebirths + 1)
	end
	if spdBeforeLabel then
		spdBeforeLabel.Text = tostring(Shared_Rebirth.GetMaxSpeedCap(rebirths))
	end
	if spdAfterLabel then
		spdAfterLabel.Text = tostring(Shared_Rebirth.GetMaxSpeedCap(rebirths + 1))
	end
	if strBeforeLabel then
		strBeforeLabel.Text = tostring(Shared_Rebirth.GetMaxStrengthCap(rebirths))
	end
	if strAfterLabel then
		strAfterLabel.Text = tostring(Shared_Rebirth.GetMaxStrengthCap(rebirths + 1))
	end
	if costLabel then
		costLabel.Text = ("$%s"):format(Shared_Abbreviation:Number(Shared_Rebirth.GetCost(rebirths)))
	end
end

local function bindUi()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local main = playerGui:WaitForChild("Main")
	local frames = main:WaitForChild("Frames")
	rebirthFrame = frames:WaitForChild("Rebirth") :: GuiObject
	local holder = rebirthFrame:WaitForChild("Holder")

	cashBeforeLabel = getValueLabel(holder:WaitForChild("CashBefore"))
	cashAfterLabel = getValueLabel(holder:WaitForChild("CashAfter"))
	spdBeforeLabel = getValueLabel(holder:WaitForChild("SpdBefore"))
	spdAfterLabel = getValueLabel(holder:WaitForChild("SpdAfter"))
	strBeforeLabel = getValueLabel(holder:WaitForChild("StrBefore"))
	strAfterLabel = getValueLabel(holder:WaitForChild("StrAfter"))

	local buyRoot = holder:WaitForChild("Buy")
	buyButton = buyRoot:WaitForChild("ImageButton") :: ImageButton
	costLabel = buyRoot:FindFirstChild("Cost", true) :: TextLabel?
	if costLabel and not costLabel:IsA("TextLabel") then
		costLabel = nil
	end

	buyButton.MouseButton1Click:Connect(function()
		if plotHandler then
			plotHandler:FireServer("Rebirth")
		end
	end)

	rebirthFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if rebirthFrame.Visible then
			render()
		end
		refreshRebirthGuidance()
	end)

	render()
end

local function hookReplicaChanges()
	Client_Data:ListenToChange("Rebirths", function()
		render()
		wasAffordRebirth = false
		refreshRebirthGuidance()
	end)
	Client_Data:ListenToChange("Cash", function()
		render()
		refreshRebirthGuidance()
	end)
end

local function hookPurchaseResponses()
	if not plotHandler then
		return
	end

	plotHandler.OnClientEvent:Connect(function(action: string, arg1: any, arg2: any)
		if action == "RebirthSuccess" then
			Client_GuideBeam.Clear()
			wasAffordRebirth = false
			Client_FOV.playPulse()
			Client_TadaEffect.Play()
			Client_Messaging.Show("Rebirth complete!", "green")
			render()
			refreshRebirthGuidance()
			return
		end

		if action == "RebirthFailed" then
			local reason = type(arg1) == "string" and arg1 or ""
			if reason == "NotEnoughCash" then
				Client_Messaging.Show("You need more cash to rebirth!", "red")
			else
				Client_Messaging.Show("Could not rebirth right now.", "red")
			end
		end
	end)
end

function Client_Rebirth.Init()
	Client_Data.WaitUntilReady()

	local events = ReplicatedStorage:WaitForChild("Events")
	plotHandler = events:WaitForChild("PlotHandler") :: RemoteEvent

	hookRebirthOpenButtons()
	bindUi()
	hookReplicaChanges()
	hookPurchaseResponses()
	bindCharacterBeamRefresh()

	task.spawn(function()
		local gameFolder = Workspace:WaitForChild("Game", 30)
		if not gameFolder then
			return
		end

		local interactFolder = gameFolder:WaitForChild("Interact", 30)
		if interactFolder then
			interactFolder.DescendantAdded:Connect(function()
				task.defer(refreshRebirthGuidance)
			end)
		end

		while true do
			refreshRebirthGuidance()
			task.wait(1)
		end
	end)
end

return Client_Rebirth