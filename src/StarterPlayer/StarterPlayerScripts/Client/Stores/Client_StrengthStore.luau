local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_Abbreviation = SharedModules.require("Shared_Abbreviation")
local Shared_Brainrots = SharedModules.require("Shared_Brainrots")
local Shared_Marketplace = SharedModules.require("Shared_Marketplace")
local Shared_Rebirth = SharedModules.require("Shared_Rebirth")
local Shared_StrengthStore = SharedModules.require("Shared_StrengthStore")
local Client_StatStoreUi = require(script.Parent.Client_StatStoreUi)
local ClientLoader = require(script.Parent.Parent.Loader)

local Client_Data = ClientLoader.require("Client_Data")

type RobuxPurchaseUi = {
	amount: number,
	imageButton: ImageButton,
	priceLabel: TextLabel?,
}

local function getPurchaseCostContext()
	return {
		freePointsUsed = math.clamp(
			math.floor(Client_Data:GetValue("FreeStrengthPointsUsed") or 0),
			0,
			Shared_StrengthStore.FreeStrengthPoints
		),
		rebirths = Client_Data:GetValue("Rebirths") or 0,
	}
end

local baseStore = Client_StatStoreUi.create({
	statName = "Strength",
	frameName = "StrengthStore",
	sharedStore = Shared_StrengthStore,
	buyRemoteAction = "BuyStrength",
	successRemoteAction = "StrengthPurchaseSuccess",
	failedRemoteAction = "StrengthPurchaseFailed",
	purchaseCostContextKeys = { "FreeStrengthPointsUsed", "Rebirths" },
	getPurchaseCostContext = getPurchaseCostContext,
	successMessage = function(addedAmount, paidCost)
		if paidCost <= 0 then
			return ("Bought +%d strength for free!"):format(addedAmount)
		end
		return ("Bought +%d strength for $%s."):format(addedAmount, Shared_Abbreviation:Number(paidCost))
	end,
})

local robuxPurchaseUis: { RobuxPurchaseUi } = {}
local storeFrame: GuiObject?

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

local function getPlotIncomePerSecond(): number
	local plot = Client_Data:GetValue("Plot")
	if type(plot) ~= "table" then
		return 0
	end

	local total = 0
	for _, slotData in plot do
		if type(slotData) ~= "table" then
			continue
		end

		local configName = slotData.ConfigName
		if type(configName) ~= "string" or configName == "" then
			continue
		end

		total += Shared_Brainrots.GetCashPerSecond(
			configName,
			slotData.Level or 1,
			slotData.Modifier or "Normal",
			slotData.BaseWeight,
			slotData.Weight
		)
	end

	local rebirths = Client_Data:GetValue("Rebirths") or 0
	return math.floor(total * Shared_Rebirth.GetCashMultiplier(rebirths) + 0.5)
end

local function getCurrentStrength(): number
	return math.max(1, math.floor(Client_Data:GetValue("Strength") or Shared_StrengthStore.DefaultStrength))
end

local function getRobuxProductConfigKey(purchaseAmount: number): string?
	local currentStrength = getCurrentStrength()
	local purchaseContext = getPurchaseCostContext()
	local cashCost = Shared_StrengthStore.GetPurchaseCost(currentStrength, purchaseAmount, purchaseContext)
	local currentCash = math.floor(Client_Data:GetValue("Cash") or 0)
	local incomePerSecond = getPlotIncomePerSecond()
	local secondsNeeded = Shared_StrengthStore.GetSecondsToAfford(cashCost, currentCash, incomePerSecond)
	return Shared_StrengthStore.GetRobuxProductConfigKey(purchaseAmount, secondsNeeded)
end

local function renderRobuxPurchase(option: RobuxPurchaseUi)
	local configKey = getRobuxProductConfigKey(option.amount)
	if not configKey then
		return
	end

	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	local robuxPrice = Client_Marketplace.GetRobuxDisplayPrice(configKey)
	if option.priceLabel and robuxPrice then
		option.priceLabel.Text = Shared_Marketplace.FormatRobuxPrice(robuxPrice)
	end
end

local function renderAllRobuxPurchases()
	for _, option in robuxPurchaseUis do
		renderRobuxPurchase(option)
	end
end

local function setupRobuxPurchaseUi(amount: number, root: Instance)
	local robuxButtonRoot = root:FindFirstChild("RobuxButton") or root:FindFirstChild("RobuxBuy")
	if not robuxButtonRoot then
		return
	end

	local imageButton: ImageButton?
	if robuxButtonRoot:IsA("GuiButton") then
		imageButton = robuxButtonRoot :: ImageButton
	else
		imageButton = robuxButtonRoot:FindFirstChildWhichIsA("ImageButton", true)
	end
	if not imageButton then
		return
	end

	local priceLabel = findTextLabel(imageButton, "Cost") or findTextLabel(robuxButtonRoot, "Cost")

	local option: RobuxPurchaseUi = {
		amount = amount,
		imageButton = imageButton,
		priceLabel = priceLabel,
	}
	table.insert(robuxPurchaseUis, option)

	imageButton.MouseButton1Click:Connect(function()
		local configKey = getRobuxProductConfigKey(amount)
		if not configKey then
			return
		end

		local Client_Marketplace = ClientLoader.require("Client_Marketplace")
		Client_Marketplace.PromptProductPurchase(configKey)
	end)
end

local function setupRobuxUi()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local frames = playerGui:WaitForChild("Main"):WaitForChild("Frames")
	storeFrame = frames:WaitForChild("StrengthStore") :: GuiObject
	local holder = storeFrame:WaitForChild("Holder")

	table.clear(robuxPurchaseUis)
	for _, amount in Shared_StrengthStore.PurchaseOptions do
		local frame = holder:FindFirstChild(tostring(amount))
		if frame then
			setupRobuxPurchaseUi(amount, frame)
		end
	end

	renderAllRobuxPurchases()
end

local Client_StrengthStore = {
	Init = function()
		baseStore.Init()
		setupRobuxUi()

		local Client_Marketplace = ClientLoader.require("Client_Marketplace")

		Client_Data:ListenToChange("Cash", renderAllRobuxPurchases)
		Client_Data:ListenToChange("Strength", renderAllRobuxPurchases)
		Client_Data:ListenToChange("Plot", renderAllRobuxPurchases)
		Client_Data:ListenToChange("Rebirths", renderAllRobuxPurchases)
		Client_Data:ListenToChange("FreeStrengthPointsUsed", renderAllRobuxPurchases)
		Client_Marketplace.OnPricesChanged(renderAllRobuxPurchases)

		if storeFrame then
			storeFrame:GetPropertyChangedSignal("Visible"):Connect(function()
				if storeFrame and storeFrame.Visible then
					renderAllRobuxPurchases()
				end
			end)
		end

		task.spawn(function()
			Client_Marketplace.WaitUntilReady()
			renderAllRobuxPurchases()
		end)
	end,
	Refresh = function()
		baseStore.Refresh()
		renderAllRobuxPurchases()
	end,
}

return Client_StrengthStore
