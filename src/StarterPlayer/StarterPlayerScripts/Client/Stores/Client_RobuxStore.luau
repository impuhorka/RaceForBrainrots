local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local SharedModules = require(game:GetService("ReplicatedStorage").Modules.Loader)

local ClientLoader = require(script.Parent.Parent.Loader)
local Shared_Marketplace = SharedModules.require("Shared_Marketplace")
local Shared_Abbreviation = SharedModules.require("Shared_Abbreviation")

local Client_RobuxStore = {}

local GAMEPASS_TAG = "gamepass"
local localPlayer = Players.LocalPlayer
local UNIT_CONFIG_KEY = Shared_Marketplace.GetVIPLuckyBlockProductKey(1)

local luckyBlockSection: GuiObject?
local bannerBack1: TextLabel?
local bannerUp1: TextLabel?
local luckyBlockCostLabels: { [number]: TextLabel? } = {}
local luckyBlockDiscountLabels: { [number]: TextLabel? } = {}
local cashBonusLabels: { [number]: TextLabel? } = {}
local cashCostLabels: { [number]: TextLabel? } = {}
local gamePassUis: { [string]: {
	configKey: string,
	buyButton: ImageButton,
	costLabel: TextLabel,
	costGradient: UIGradient?,
} } = {}
local hookedGamePassFrames: { [Instance]: boolean } = {}
local purchasePending = false

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

local function formatRobux(amount: number): string
	return tostring(math.max(0, math.floor(amount)))
end

local function formatCash(amount: number): string
	return Shared_Abbreviation:CashDisplay(math.max(0, math.floor(amount)))
end

local function getPurchaseSuccessMessage(configKey: string): string
	if Shared_Marketplace.IsGamePass(configKey) then
		local config = Shared_Marketplace.GetProduct(configKey)
		return `Purchased {config and config.DisplayName or "game pass"}!`
	end

	if Shared_Marketplace.IsCashProduct(configKey) then
		return string.format("Purchased $%s!", formatCash(Shared_Marketplace.GetGrantCash(configKey)))
	end

	local grantAmount = Shared_Marketplace.GetGrantAmount(configKey)
	if grantAmount == 1 then
		return "Purchased 1 VIP Lucky Block!"
	end
	return `Purchased {grantAmount} VIP Lucky Blocks!`
end

local function updateLuckyBlockVisibility()
	if not luckyBlockSection then
		return
	end

	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	luckyBlockSection.Visible = Client_Marketplace.CanPurchasePaidRandomItems()
end

local function updateLuckyBlockBundleUi(bundleAmount: number)
	local configKey = Shared_Marketplace.GetVIPLuckyBlockProductKey(bundleAmount)
	if not configKey then
		return
	end

	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	local price = Client_Marketplace.GetUserPriceInRobux(configKey)
	local costLabel = luckyBlockCostLabels[bundleAmount]
	if costLabel and price then
		costLabel.Text = `{formatRobux(price)} R$`
	end

	local discountLabel = luckyBlockDiscountLabels[bundleAmount]
	if not discountLabel or bundleAmount <= 1 or not UNIT_CONFIG_KEY then
		return
	end

	local discount = Client_Marketplace.GetBundleDiscount(configKey, UNIT_CONFIG_KEY)
	if discount > 0 then
		discountLabel.Text = `-{formatRobux(discount)}R$`
	else
		discountLabel.Text = ""
	end
end

local function updateCashTierUi(tier: number)
	local configKey = Shared_Marketplace.GetRobuxCashProductKey(tier)
	if not configKey then
		return
	end

	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	local cashAmount = Shared_Marketplace.GetGrantCash(configKey)
	local bonusLabel = cashBonusLabels[tier]
	if bonusLabel then
		bonusLabel.Text = string.format("$%s", formatCash(cashAmount))
	end

	local price = Client_Marketplace.GetUserPriceInRobux(configKey)
	local costLabel = cashCostLabels[tier]
	if costLabel and price then
		costLabel.Text = `{formatRobux(price)} R$`
	end
end

local function updateGamePassUi(configKey: string)
	local ui = gamePassUis[configKey]
	if not ui then
		return
	end

	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	local owned = Client_Marketplace.PlayerOwnsGamepass(configKey)

	if owned then
		ui.costLabel.Text = "OWNED"
		if ui.costGradient then
			ui.costGradient.Enabled = true
		end
		ui.buyButton.Active = false
		return
	end

	local price = Client_Marketplace.GetUserPriceInRobux(configKey)
	if price then
		ui.costLabel.Text = `{formatRobux(price)} R$`
	end
	if ui.costGradient then
		ui.costGradient.Enabled = false
	end
	ui.buyButton.Active = true
end

local function refreshGamePassUi()
	for configKey in gamePassUis do
		updateGamePassUi(configKey)
	end
end

local function updateBannerDiscount()
	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	local percent = Client_Marketplace.GetRobloxPlusDiscountPercent()
	local text = if percent and percent > 0 then `{percent}% OFF!` else ""

	if bannerBack1 then
		bannerBack1.Text = text
	end
	if bannerUp1 then
		bannerUp1.Text = text
	end
end

local function refreshRobuxStoreUi()
	updateLuckyBlockVisibility()
	updateBannerDiscount()

	for _, bundleAmount in Shared_Marketplace.VIPLuckyBlockBundleAmounts do
		updateLuckyBlockBundleUi(bundleAmount)
	end

	for _, tier in Shared_Marketplace.RobuxCashTiers do
		updateCashTierUi(tier)
	end

	refreshGamePassUi()
end

local function onGamePassBuyClicked(configKey: string)
	if purchasePending then
		return
	end

	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	if Client_Marketplace.PlayerOwnsGamepass(configKey) then
		return
	end

	purchasePending = true
	Client_Marketplace.PromptGamePassPurchase(configKey)
	purchasePending = false
end

local function bindGamePassFrame(frame: Instance)
	if hookedGamePassFrames[frame] then
		return
	end
	if not frame:IsA("GuiObject") then
		return
	end

	local configKey = Shared_Marketplace.GetGamePassConfigKeyFromFrameName(frame.Name)
	if not configKey then
		return
	end

	local buyButton = frame:FindFirstChild("Buy", true)
	if not buyButton or not buyButton:IsA("ImageButton") then
		return
	end

	local costLabel = findTextLabel(buyButton, "Cost")
	if not costLabel then
		return
	end

	hookedGamePassFrames[frame] = true
	gamePassUis[configKey] = {
		configKey = configKey,
		buyButton = buyButton,
		costLabel = costLabel,
		costGradient = costLabel:FindFirstChildOfClass("UIGradient"),
	}

	if gamePassUis[configKey].costGradient then
		gamePassUis[configKey].costGradient.Enabled = false
	end

	buyButton.Activated:Connect(function()
		onGamePassBuyClicked(configKey)
	end)

	updateGamePassUi(configKey)
end

local function setupGamePassUi()
	for _, frame in CollectionService:GetTagged(GAMEPASS_TAG) do
		bindGamePassFrame(frame)
	end

	CollectionService:GetInstanceAddedSignal(GAMEPASS_TAG):Connect(bindGamePassFrame)
end

local function onProductPurchaseClicked(configKey: string, requiresPaidRandomItems: boolean)
	if purchasePending then
		return
	end

	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	local Client_Messaging = ClientLoader.require("Client_Messaging")

	if requiresPaidRandomItems and not Client_Marketplace.CanPurchasePaidRandomItems() then
		Client_Messaging.Show("Paid random items are not available in your region.", "red")
		return
	end

	purchasePending = true
	local allowed = Client_Marketplace.RequestServerCanPurchase(configKey)
	purchasePending = false

	if not allowed then
		Client_Messaging.Show("You cannot purchase this right now.", "red")
		return
	end

	Client_Marketplace.PromptProductPurchase(configKey)
end

local function bindLuckyBlockButton(bundleAmount: number, frame: Instance)
	local imageButton = frame:FindFirstChildWhichIsA("ImageButton", true)
	if not imageButton then
		return
	end

	luckyBlockCostLabels[bundleAmount] = findTextLabel(imageButton, "Cost")
	luckyBlockDiscountLabels[bundleAmount] = findTextLabel(imageButton, "Discount")

	local configKey = Shared_Marketplace.GetVIPLuckyBlockProductKey(bundleAmount)
	if not configKey then
		return
	end

	imageButton.Activated:Connect(function()
		onProductPurchaseClicked(configKey, true)
	end)
end

local function bindCashFrame(tier: number, frame: Instance)
	cashBonusLabels[tier] = findTextLabel(frame, "Bonus")

	local imageButton = frame:FindFirstChildWhichIsA("ImageButton", true)
	if not imageButton then
		return
	end

	cashCostLabels[tier] = findTextLabel(imageButton, "Cost")

	local configKey = Shared_Marketplace.GetRobuxCashProductKey(tier)
	if not configKey then
		return
	end

	imageButton.Activated:Connect(function()
		onProductPurchaseClicked(configKey, false)
	end)
end

local function setupRobuxStoreUi()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local main = playerGui:WaitForChild("Main")
	local frames = main:WaitForChild("Frames")
	local robuxStore = frames:WaitForChild("RobuxStore")
	local banner = robuxStore:WaitForChild("Banner")
	bannerBack1 = findTextLabel(banner, "Back1")
	bannerUp1 = findTextLabel(banner, "Up1")

	local scrollingFrame = robuxStore:WaitForChild("ScrollingFrame")
	luckyBlockSection = scrollingFrame:WaitForChild("LuckyBlock") :: GuiObject

	local luckyButtonsFrame = luckyBlockSection:WaitForChild("Frame"):WaitForChild("Buttons")
	for _, bundleAmount in Shared_Marketplace.VIPLuckyBlockBundleAmounts do
		local frame = luckyButtonsFrame:FindFirstChild(tostring(bundleAmount))
		if frame then
			bindLuckyBlockButton(bundleAmount, frame)
		end
	end

	local cash1 = scrollingFrame:WaitForChild("Cash1")
	for _, tier in { 1, 2, 3 } do
		local frame = cash1:FindFirstChild(tostring(tier))
		if frame then
			bindCashFrame(tier, frame)
		end
	end

	local cash2 = scrollingFrame:WaitForChild("Cash2")
	local frame4 = cash2:FindFirstChild("4")
	if frame4 then
		bindCashFrame(4, frame4)
	end
end

local function setupPurchaseCallbacks()
	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	local Client_Messaging = ClientLoader.require("Client_Messaging")

	Client_Marketplace.OnPurchaseSuccess = function(configKey: string)
		Client_Messaging.Show(getPurchaseSuccessMessage(configKey), "green")

		if Shared_Marketplace.IsGamePass(configKey) then
			refreshGamePassUi()
			return
		end

		if Shared_Marketplace.IsCashProduct(configKey) then
			local Client_CashAddingPopups = ClientLoader.require("Client_CashAddingPopups")
			Client_CashAddingPopups.Show(
				Shared_Marketplace.GetGrantCash(configKey),
				Shared_Marketplace.GetCashPopupCount(configKey),
				Shared_Marketplace.GetCashPopupTemplate(configKey)
			)
		end
	end

	Client_Marketplace.OnPurchaseFailed = function(_configKey: string, reason: string?)
		Client_Messaging.Show(reason or "Purchase failed.", "red")
	end
end

function Client_RobuxStore.Init()
	local Client_Marketplace = ClientLoader.require("Client_Marketplace")

	setupRobuxStoreUi()
	setupGamePassUi()
	setupPurchaseCallbacks()

	Client_Marketplace.OnPolicyChanged(refreshRobuxStoreUi)
	Client_Marketplace.OnCatalogChanged(refreshRobuxStoreUi)
	Client_Marketplace.OnPricesChanged(refreshRobuxStoreUi)
	Client_Marketplace.OnGamepassOwnershipChanged(refreshGamePassUi)

	local Client_Data = ClientLoader.require("Client_Data")
	task.spawn(function()
		Client_Data.WaitUntilReady()
		Client_Data:ListenToChange("DataGamepasses", refreshGamePassUi)
	end)

	task.spawn(function()
		Client_Marketplace.WaitUntilReady()
		refreshRobuxStoreUi()
	end)
end

return Client_RobuxStore
