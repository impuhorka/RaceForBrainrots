local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientLoader = require(script.Parent.Parent.Loader)

local Client_Equip = ClientLoader.require("Client_Equip")

local localPlayer = Players.LocalPlayer

local Client_BrainrotDrop = {}

local actionButton: GuiObject?
local dropButton: ImageButton?

local function isCarryingLuckyBlock(): boolean
	return localPlayer:GetAttribute("CarryingLuckyBlock") == true
end

local function hasEquippedBrainrot(): boolean
	if isCarryingLuckyBlock() then
		return false
	end

	local inventoryIndex = Client_Equip.GetEquippedIndex()
	if not inventoryIndex then
		return false
	end

	local Client_Data = ClientLoader.require("Client_Data")
	local inventory = Client_Data:GetValue("Inventory") or {}
	local item = inventory[inventoryIndex]
	return item ~= nil and item.ItemType == "Brainrot"
end

local function resolveActionUi()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	local main = playerGui and playerGui:FindFirstChild("Main")
	if not main then
		return
	end

	local foundActionButton = main:FindFirstChild("ActionButton")
	if foundActionButton and foundActionButton:IsA("GuiObject") then
		actionButton = foundActionButton
	end

	if actionButton then
		local foundDrop = actionButton:FindFirstChild("DropBrainrot", true)
		if foundDrop and foundDrop:IsA("ImageButton") then
			dropButton = foundDrop
		end
	end
end

local function updateActionButtonVisibility()
	local carryingLuckyBlock = isCarryingLuckyBlock()
	local showBrainrotDrop = hasEquippedBrainrot()

	if dropButton then
		dropButton.Visible = showBrainrotDrop
	end
	if actionButton then
		actionButton.Visible = carryingLuckyBlock or showBrainrotDrop
	end
end

local function refreshDropVisibility()
	task.defer(updateActionButtonVisibility)
end

local function onDropClicked()
	if not hasEquippedBrainrot() then
		return
	end

	local inventoryIndex = Client_Equip.GetEquippedIndex()
	if not inventoryIndex then
		return
	end

	local events = ReplicatedStorage:FindFirstChild("Events")
	local gameProcessHandler = events and events:FindFirstChild("GameProcessHandler")
	if not gameProcessHandler or not gameProcessHandler:IsA("RemoteEvent") then
		return
	end

	Client_Equip.Unequip()
	gameProcessHandler:FireServer("DropEquippedBrainrot", inventoryIndex)
end

local function bindEquippedListeners()
	local function onEquippedChanged()
		refreshDropVisibility()
	end

	Client_Equip.OnChanged(onEquippedChanged)
	localPlayer:GetAttributeChangedSignal("CarryingLuckyBlock"):Connect(onEquippedChanged)

	local Client_Data = ClientLoader.require("Client_Data")
	Client_Data:ListenToChange("Inventory", onEquippedChanged)
end

local dropButtonConnected = false

local function bindDropButton()
	if dropButton and not dropButtonConnected then
		dropButtonConnected = true
		dropButton.Activated:Connect(onDropClicked)
	end
end

local function tryInitializeActionUi(): boolean
	resolveActionUi()
	bindDropButton()
	refreshDropVisibility()
	return dropButton ~= nil
end

function Client_BrainrotDrop.Init()
	task.spawn(function()
		local playerGui = localPlayer:WaitForChild("PlayerGui", 30)
		if not playerGui then
			return
		end

		bindEquippedListeners()

		if not tryInitializeActionUi() then
			local main = playerGui:WaitForChild("Main", 30)
			if main then
				tryInitializeActionUi()
			end
		end

		if not dropButton then
			local connection: RBXScriptConnection?
			connection = playerGui.ChildAdded:Connect(function(child)
				if child.Name ~= "Main" then
					return
				end
				if tryInitializeActionUi() and connection then
					connection:Disconnect()
				end
			end)
		end

		refreshDropVisibility()

		local events = ReplicatedStorage:WaitForChild("Events", 10)
		local gameProcessHandler = events and events:WaitForChild("GameProcessHandler", 10)
		if gameProcessHandler and gameProcessHandler:IsA("RemoteEvent") then
			gameProcessHandler.OnClientEvent:Connect(function(action: string, inventoryIndex: any)
				if action == "BrainrotPickedUp" and type(inventoryIndex) == "number" then
					Client_Equip.Equip(inventoryIndex)
					refreshDropVisibility()
				end
			end)
		end
	end)
end

return Client_BrainrotDrop
