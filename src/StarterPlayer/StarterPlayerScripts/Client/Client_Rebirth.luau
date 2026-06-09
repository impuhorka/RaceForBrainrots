local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared_Abbreviation = require(ReplicatedStorage.Modules.Utilities.Shared_Abbreviation)
local Shared_Rebirth = require(ReplicatedStorage.Modules.Shared_Rebirth)
local Client_Data = require(script.Parent.Client_Data)
local Client_Messaging = require(script.Parent.Client_Messaging)
local Client_TadaEffect = require(script.Parent.Client_TadaEffect)
local Client_FOV = require(script.Parent.Client_FOV)

local Client_Rebirth = {}

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
	end)

	render()
end

local function hookReplicaChanges()
	Client_Data:ListenToChange("Rebirths", render)
	Client_Data:ListenToChange("Cash", render)
end

local function hookPurchaseResponses()
	if not plotHandler then
		return
	end

	plotHandler.OnClientEvent:Connect(function(action: string, arg1: any, arg2: any)
		if action == "RebirthSuccess" then
			Client_FOV.playPulse()
			Client_TadaEffect.Play()
			Client_Messaging.Show("Rebirth complete!", "green")
			render()
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
end

return Client_Rebirth
