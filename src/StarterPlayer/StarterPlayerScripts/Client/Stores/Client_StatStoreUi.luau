local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_Abbreviation = SharedModules.require("Shared_Abbreviation")
local ClientLoader = require(script.Parent.Parent.Loader)
local Client_StatStoreFreeHighlight = require(script.Parent.Client_StatStoreFreeHighlight)
local Client_TutorialState = require(script.Parent.Parent.Core.Client_TutorialState)

type StatStoreUiConfig = {
	statName: string,
	frameName: string,
	sharedStore: any,
	buyRemoteAction: string,
	successRemoteAction: string,
	failedRemoteAction: string,
	successMessage: (addedAmount: number, paidCost: number) -> string,
	purchaseCostContextKeys: { string }?,
	getPurchaseCostContext: (() -> any)?,
}

type PurchaseUi = {
	amount: number,
	root: GuiObject,
	button: GuiButton,
	costLabel: TextLabel?,
	beforeLabel: TextLabel?,
	afterLabel: TextLabel?,
}

local ROBUX_PURCHASE_ROOT_NAMES = {
	RobuxButton = true,
	RobuxBuy = true,
}

local function isUnderRobuxPurchaseRoot(instance: Instance): boolean
	local current = instance.Parent
	while current do
		if ROBUX_PURCHASE_ROOT_NAMES[current.Name] then
			return true
		end
		current = current.Parent
	end
	return false
end

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

local function findCashButtonRoot(root: Instance): Instance?
	local buttonRoot = root:FindFirstChild("Button")
	if buttonRoot then
		return buttonRoot
	end
	return root:FindFirstChild("Buy")
end

local function findCostLabelInGuiButton(button: GuiButton): TextLabel?
	local direct = button:FindFirstChild("Cost")
	if direct and direct:IsA("TextLabel") then
		return direct
	end

	local nested = button:FindFirstChild("Cost", true)
	if nested and nested:IsA("TextLabel") then
		return nested
	end

	return nil
end

local function findCashPurchaseButton(root: Instance): (Instance?, GuiButton?)
	local buttonRoot = findCashButtonRoot(root)
	if buttonRoot then
		if buttonRoot:IsA("GuiButton") and not isUnderRobuxPurchaseRoot(buttonRoot) then
			return buttonRoot.Parent, buttonRoot
		end

		local button = buttonRoot:FindFirstChildWhichIsA("GuiButton", true)
		if button and not isUnderRobuxPurchaseRoot(button) then
			return buttonRoot, button
		end
	end

	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiButton") and not isUnderRobuxPurchaseRoot(descendant) then
			return descendant.Parent, descendant
		end
	end

	return nil, nil
end

local function createStatStoreUi(config: StatStoreUiConfig)
	local Client_Data = ClientLoader.require("Client_Data")
	local Client_Messaging = ClientLoader.require("Client_Messaging")

	local purchaseUis: { PurchaseUi } = {}
	local plotHandler: RemoteEvent?
	local storeFrame: GuiObject?

	local function getCurrentValue(): number
		local defaultValue = config.sharedStore.DefaultValue
		return math.max(1, math.floor(Client_Data:GetValue(config.statName) or defaultValue))
	end

	local function findCostLabel(
		root: Instance,
		buttonRoot: Instance?,
		button: GuiButton,
		excludeLabels: { TextLabel? }
	): TextLabel?
		local function isExcluded(label: TextLabel): boolean
			for _, excluded in excludeLabels do
				if excluded == label then
					return true
				end
			end
			if isUnderRobuxPurchaseRoot(label) then
				return true
			end
			return false
		end

		if button then
			local costInButton = findCostLabelInGuiButton(button)
			if costInButton and not isExcluded(costInButton) then
				return costInButton
			end
		end

		if buttonRoot then
			local directCost = buttonRoot:FindFirstChild("Cost")
			if directCost and directCost:IsA("TextLabel") and not isExcluded(directCost) then
				return directCost
			end
		end

		return nil
	end

	local function shouldHighlightPurchase(option: PurchaseUi, cost: number): boolean
		if cost > 0 or config.frameName ~= "StrengthStore" then
			return false
		end
		if not Client_TutorialState.highlightStrengthStoreFree then
			return false
		end
		return option.amount == 1
	end

	local function getPurchaseCostContext(): any
		if config.getPurchaseCostContext then
			return config.getPurchaseCostContext()
		end
		return nil
	end

	local function renderOption(option: PurchaseUi, currentValue: number)
		local nextValue = config.sharedStore.GetValueAfterPurchase(currentValue, option.amount)
		local cost = config.sharedStore.GetPurchaseCost(currentValue, option.amount, getPurchaseCostContext())
		local highlight = shouldHighlightPurchase(option, cost)

		local buttonRoot = findCashButtonRoot(option.root)
		option.costLabel = findCostLabel(
			option.root,
			buttonRoot,
			option.button,
			{ option.beforeLabel, option.afterLabel }
		)

		if option.costLabel then
			option.costLabel.Text = if cost <= 0 then "FREE" else ("$%s"):format(Shared_Abbreviation:Number(cost))
		end

		Client_StatStoreFreeHighlight.setPurchaseHighlight(
			option.costLabel,
			option.button,
			option.button,
			highlight
		)
		if option.beforeLabel then
			option.beforeLabel.Text = tostring(currentValue)
		end
		if option.afterLabel then
			option.afterLabel.Text = tostring(nextValue)
		end
	end

	local function renderAll()
		local currentValue = getCurrentValue()
		for _, option in purchaseUis do
			renderOption(option, currentValue)
		end
	end

	local function setupPurchaseUi(amount: number, root: Instance)
		if not root:IsA("GuiObject") then
			return
		end

		local buttonRoot, button = findCashPurchaseButton(root)
		if not button then
			return
		end

		local numbersRoot = root:FindFirstChild("Numbers")
		local beforeLabel = if numbersRoot then findTextLabel(numbersRoot, "Before") else nil
		local afterLabel = if numbersRoot then findTextLabel(numbersRoot, "After") else nil
		local option: PurchaseUi = {
			amount = amount,
			root = root,
			button = button,
			costLabel = findCostLabel(root, buttonRoot, button, { beforeLabel, afterLabel }),
			beforeLabel = beforeLabel,
			afterLabel = afterLabel,
		}

		table.insert(purchaseUis, option)
		button.MouseButton1Click:Connect(function()
			if plotHandler then
				plotHandler:FireServer(config.buyRemoteAction, amount)
			end
		end)
	end

	local function setupUi()
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		local frames = playerGui:WaitForChild("Main"):WaitForChild("Frames")
		storeFrame = frames:WaitForChild(config.frameName) :: GuiObject
		local holder = storeFrame:WaitForChild("Holder")

		table.clear(purchaseUis)
		for _, amount in config.sharedStore.PurchaseOptions do
			local frame = holder:FindFirstChild(tostring(amount))
			if frame then
				setupPurchaseUi(amount, frame)
			end
		end

		renderAll()
	end

	local function hookPurchaseResponses()
		if not plotHandler then
			return
		end

		plotHandler.OnClientEvent:Connect(function(action: string, arg1: any, arg2: any)
			if action == config.successRemoteAction then
				local addedAmount = type(arg1) == "number" and math.floor(arg1) or 0
				local paidCost = type(arg2) == "number" and arg2 or 0
				if addedAmount > 0 then
					Client_Messaging.Show(config.successMessage(addedAmount, paidCost), "green")
				end
				return
			end

			if action == config.failedRemoteAction then
				local reason = type(arg1) == "string" and arg1 or ""
				local requiredCost = type(arg2) == "number" and arg2 or 0
				if reason == "NotEnoughCash" and requiredCost > 0 then
					Client_Messaging.Show("You need more cash to purchase this!", "red")
				elseif reason == "AtCap" then
					Client_Messaging.Show("Rebirth to raise your cap!", "red")
				elseif reason == "InvalidAmount" then
					Client_Messaging.Show("Invalid purchase amount.", "red")
				else
					Client_Messaging.Show("Could not complete purchase right now.", "red")
				end
			end
		end)
	end

	return {
		Init = function()
			Client_Data.WaitUntilReady()

			local events = ReplicatedStorage:WaitForChild("Events")
			plotHandler = events:WaitForChild("PlotHandler") :: RemoteEvent

			setupUi()
			Client_Data:ListenToChange(config.statName, renderAll)
			if config.purchaseCostContextKeys then
				for _, key in config.purchaseCostContextKeys do
					Client_Data:ListenToChange(key, renderAll)
				end
			end
			hookPurchaseResponses()

			if storeFrame then
				storeFrame:GetPropertyChangedSignal("Visible"):Connect(function()
					if storeFrame and storeFrame.Visible then
						renderAll()
					end
				end)
			end

			task.defer(renderAll)
		end,
		Refresh = renderAll,
	}
end

return {
	create = createStatStoreUi,
}