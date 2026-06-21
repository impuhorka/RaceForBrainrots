local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local ClientLoader = require(script.Parent.Parent.Loader)
local Shared_LuckyBlocks = SharedModules.require("Shared_LuckyBlocks")
local Shared_Marketplace = SharedModules.require("Shared_Marketplace")

local Client_TeleportHome = {}

local localPlayer = Players.LocalPlayer

local teleportButton: ImageButton?
local costLabel: TextLabel?
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

local function isCarryingLuckyBlock(): boolean
	return localPlayer:GetAttribute("CarryingLuckyBlock") == true
end

local function getCarriedRarity(): string?
	local rarity = localPlayer:GetAttribute("CarriedLuckyBlockRarity")
	if type(rarity) == "string" and rarity ~= "" then
		return rarity
	end

	local configName = localPlayer:GetAttribute("CarriedLuckyBlockConfigName")
	if type(configName) == "string" then
		local config = Shared_LuckyBlocks.Data[configName]
		if config and type(config.Rarity) == "string" and config.Rarity ~= "" then
			return config.Rarity
		end
	end

	return nil
end

local function getProductConfigKey(): string?
	local rarity = getCarriedRarity()
	if not rarity then
		return nil
	end
	return Shared_Marketplace.GetTeleportHomeProductKey(rarity)
end

local function updateVisibility()
	if teleportButton then
		teleportButton.Visible = isCarryingLuckyBlock()
	end
end

local function refreshTeleportHomeUi()
	updateVisibility()

	if not costLabel or not isCarryingLuckyBlock() then
		return
	end

	local configKey = getProductConfigKey()
	if not configKey then
		return
	end

	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	local price = Client_Marketplace.GetUserPriceInRobux(configKey)
	if price then
		costLabel.Text = Shared_Marketplace.FormatRobuxPrice(price)
	end
end

local function onTeleportHomeClicked()
	if purchasePending or not isCarryingLuckyBlock() then
		return
	end

	local configKey = getProductConfigKey()
	if not configKey then
		return
	end

	local Client_Marketplace = ClientLoader.require("Client_Marketplace")
	local Client_Messaging = ClientLoader.require("Client_Messaging")

	purchasePending = true
	local allowed = Client_Marketplace.RequestServerCanPurchase(configKey)
	purchasePending = false

	if not allowed then
		Client_Messaging.Show("You cannot purchase this right now.", "red")
		return
	end

	Client_Marketplace.PromptProductPurchase(configKey)
end

local function bindUi()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local main = playerGui:WaitForChild("Main")
	local actionButton = main:WaitForChild("ActionButton")
	local teleportHome = actionButton:WaitForChild("TeleportHome")
	if not teleportHome:IsA("ImageButton") then
		return
	end

	teleportButton = teleportHome
	costLabel = findTextLabel(teleportButton, "Cost")

	teleportButton.Activated:Connect(onTeleportHomeClicked)
	refreshTeleportHomeUi()
end

local function bindPlayerAttributes(player: Player)
	if player ~= localPlayer then
		return
	end

	player:GetAttributeChangedSignal("CarryingLuckyBlock"):Connect(refreshTeleportHomeUi)
	player:GetAttributeChangedSignal("CarriedLuckyBlockRarity"):Connect(refreshTeleportHomeUi)
	player:GetAttributeChangedSignal("CarriedLuckyBlockConfigName"):Connect(refreshTeleportHomeUi)
end

function Client_TeleportHome.Init()
	local Client_Marketplace = ClientLoader.require("Client_Marketplace")

	task.spawn(function()
		bindUi()
	end)

	bindPlayerAttributes(localPlayer)
	Client_Marketplace.OnPricesChanged(refreshTeleportHomeUi)

	task.spawn(function()
		Client_Marketplace.WaitUntilReady()
		refreshTeleportHomeUi()
	end)
end

return Client_TeleportHome
