local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared_Abbreviation = require(ReplicatedStorage.Modules.Utilities.Shared_Abbreviation)
local Shared_StrengthStore = require(ReplicatedStorage.Modules.Shared_StrengthStore)

local Client_Data = require(script.Parent.Client_Data)
local Client_Messaging = require(script.Parent.Client_Messaging)

local Client_StrengthStore = {}

type PurchaseUi = {
	amount: number,
	button: ImageButton,
	costLabel: TextLabel?,
	beforeLabel: TextLabel?,
	afterLabel: TextLabel?,
}

local purchaseUis: { PurchaseUi } = {}
local plotHandler: RemoteEvent?

local function findTextLabel(root: Instance, name: string): TextLabel?
	local direct = root:FindFirstChild(name)
	if direct and direct:IsA("TextLabel") then
		return direct
	end

	local nested = root:FindFirstChild(name, true)
	if nested and nested:IsA("TextLabel") then
		return nested
	end

	return nil
end

local function renderOption(option: PurchaseUi, currentStrength: number)
	local nextStrength = Shared_StrengthStore.GetStrengthAfterPurchase(currentStrength, option.amount)
	local cost = Shared_StrengthStore.GetPurchaseCost(currentStrength, option.amount)

	if option.costLabel then
		option.costLabel.Text = ("$%s"):format(Shared_Abbreviation:Number(cost))
	end

	if option.beforeLabel then
		option.beforeLabel.Text = tostring(currentStrength)
	end

	if option.afterLabel then
		option.afterLabel.Text = tostring(nextStrength)
	end
end

local function renderAll()
	local currentStrength = math.max(1, math.floor(Client_Data:GetValue("Strength") or Shared_StrengthStore.DefaultStrength))
	for _, option in purchaseUis do
		renderOption(option, currentStrength)
	end
end

local function setupPurchaseUi(amount: number, root: Instance)
	local buttonRoot = root:FindFirstChild("Button")
	local imageButton = if buttonRoot then buttonRoot:FindFirstChildWhichIsA("ImageButton", true) else nil
	if not imageButton then
		return
	end

	local numbersRoot = root:FindFirstChild("Numbers")
	local beforeLabel = if numbersRoot then findTextLabel(numbersRoot, "Before") else nil
	local afterLabel = if numbersRoot then findTextLabel(numbersRoot, "After") else nil
	local costLabel = findTextLabel(imageButton, "Cost") or (if buttonRoot then findTextLabel(buttonRoot, "Cost") else nil)

	local option: PurchaseUi = {
		amount = amount,
		button = imageButton,
		costLabel = costLabel,
		beforeLabel = beforeLabel,
		afterLabel = afterLabel,
	}

	table.insert(purchaseUis, option)

	imageButton.MouseButton1Click:Connect(function()
		if not plotHandler then
			return
		end
		plotHandler:FireServer("BuyStrength", amount)
	end)
end

local function setupUi()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local main = playerGui:WaitForChild("Main")
	local frames = main:WaitForChild("Frames")
	local strengthStoreFrame = frames:WaitForChild("StrengthStore")
	local holder = strengthStoreFrame:WaitForChild("Holder")

	table.clear(purchaseUis)

	for _, amount in Shared_StrengthStore.PurchaseOptions do
		local frame = holder:FindFirstChild(tostring(amount))
		if frame then
			setupPurchaseUi(amount, frame)
		end
	end

	renderAll()
end

local function hookReplicaChanges()
	Client_Data:ListenToChange("Strength", function()
		renderAll()
	end)
end

local function hookPurchaseResponses()
	if not plotHandler then
		return
	end

	plotHandler.OnClientEvent:Connect(function(action: string, arg1: any, arg2: any)
		if action == "StrengthPurchaseSuccess" then
			local addedAmount = type(arg1) == "number" and math.floor(arg1) or 0
			local paidCost = type(arg2) == "number" and arg2 or 0
			if addedAmount > 0 and paidCost > 0 then
				Client_Messaging.Show(
					("Bought +%d strength for $%s."):format(
						addedAmount,
						Shared_Abbreviation:Number(paidCost)
					),
					"green"
				)
			end
			return
		end

		if action == "StrengthPurchaseFailed" then
			local reason = type(arg1) == "string" and arg1 or ""
			local requiredCost = type(arg2) == "number" and arg2 or 0
			if reason == "NotEnoughCash" and requiredCost > 0 then
				Client_Messaging.Show("You need more cash to purchase this!", "red")
			elseif reason == "InvalidAmount" then
				Client_Messaging.Show("Invalid strength purchase amount.", "red")
			else
				Client_Messaging.Show("Could not buy strength right now.", "red")
			end
		end
	end)
end

function Client_StrengthStore.Init()
	Client_Data.WaitUntilReady()

	local events = ReplicatedStorage:WaitForChild("Events")
	plotHandler = events:WaitForChild("PlotHandler") :: RemoteEvent

	setupUi()
	hookReplicaChanges()
	hookPurchaseResponses()
end

return Client_StrengthStore
