local Players = game:GetService("Players")
local SharedModules = require(game:GetService("ReplicatedStorage").Modules.Loader)

local ClientLoader = require(script.Parent.Parent.Loader)
local Shared_Marketplace = SharedModules.require("Shared_Marketplace")

local Client_VIPButton = {}

local VIP_CONFIG_KEY = "VIP"
local OWNED_TEXT = "OWNED!"

local localPlayer = Players.LocalPlayer

local buyButton: ImageButton?
local costLabel: TextLabel?
local robuxGradient: UIGradient?
local purchasedGradient: UIGradient?

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

local function findNamedGradient(root: Instance, name: string): UIGradient?
	local child = root:FindFirstChild(name)
	if child and child:IsA("UIGradient") then
		return child
	end
	return nil
end

local function ownsVIP(): boolean
	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	return Client_Marketplace.PlayerOwnsGamepass(VIP_CONFIG_KEY)
end

local function setOwnedGradients(owned: boolean)
	if robuxGradient then
		robuxGradient.Enabled = not owned
	end
	if purchasedGradient then
		purchasedGradient.Enabled = owned
	end
end

local function refreshVIPButtonUi()
	if not costLabel or not buyButton then
		return
	end

	if ownsVIP() then
		costLabel.Text = OWNED_TEXT
		setOwnedGradients(true)
		buyButton.Active = false
		return
	end

	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	local price = Client_Marketplace.GetUserPriceInRobux(VIP_CONFIG_KEY)
	if price then
		costLabel.Text = Shared_Marketplace.FormatRobuxPrice(price)
	end

	setOwnedGradients(false)
	buyButton.Active = true
end

local function onBuyClicked()
	if ownsVIP() then
		return
	end

	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	Client_Marketplace.PromptGamePassPurchase(VIP_CONFIG_KEY)
end

local function bindUi()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local main = playerGui:WaitForChild("Main")
	local vipButtonRoot = main:WaitForChild("VIPButton")
	local frame = vipButtonRoot:WaitForChild("Frame")
	local imageButton = frame:WaitForChild("ImageButton")

	if not imageButton:IsA("ImageButton") then
		return
	end

	local label = findTextLabel(imageButton, "Cost")
	if not label then
		return
	end

	buyButton = imageButton
	costLabel = label
	robuxGradient = findNamedGradient(label, "UIGradient")
	purchasedGradient = findNamedGradient(label, "PurchasedGradient")

	buyButton.Activated:Connect(onBuyClicked)
	refreshVIPButtonUi()
end

function Client_VIPButton.Init()
	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	local Client_Data = ClientLoader.require("Client_Data")

	bindUi()

	Client_Marketplace.OnGamepassOwnershipChanged(refreshVIPButtonUi)
	Client_Marketplace.OnPricesChanged(refreshVIPButtonUi)

	task.spawn(function()
		Client_Data.WaitUntilReady()
		Client_Data:ListenToChange("DataGamepasses", refreshVIPButtonUi)
	end)

	task.spawn(function()
		Client_Marketplace.WaitUntilReady()
		refreshVIPButtonUi()
	end)
end

return Client_VIPButton
