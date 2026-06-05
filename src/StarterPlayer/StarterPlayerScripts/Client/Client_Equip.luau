local Players = game:GetService("Players")

local UserInputService = game:GetService("UserInputService")

local Client_Data = require(script.Parent.Client_Data)
local Client_Hotbar = require(script.Parent.Client_Hotbar)

local SLOT_KEY_CODES = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

local Client_Equip = {}

local equippedInventoryIndex: number? = nil
local strokeTemplate: UIStroke?
local slotStrokes: { [ImageButton]: UIStroke } = {}
local equipListeners: { () -> () } = {}
local refreshAll: (() -> ())?

local function notifyEquipChanged()
	for _, listener in equipListeners do
		listener()
	end
end

local function findInventoryHotbarButton(): ImageButton?
	local main = Players.LocalPlayer:FindFirstChild("PlayerGui")
		and Players.LocalPlayer.PlayerGui:FindFirstChild("Main")
	local hotbar = main and main:FindFirstChild("Hotbar")
	if not hotbar then
		return nil
	end

	for _, child in hotbar:GetChildren() do
		if child:IsA("ImageButton") and child:GetAttribute("AttachedFrame") == "Inventory" then
			return child
		end
	end

	local named = hotbar:FindFirstChild("Inventory") or hotbar:FindFirstChild("Backpack")
	if named and named:IsA("ImageButton") then
		return named
	end

	return nil
end

local function getStrokeTemplate(): UIStroke?
	if strokeTemplate then
		return strokeTemplate
	end

	local inventoryButton = findInventoryHotbarButton()
	if not inventoryButton then
		return nil
	end

	local stroke = inventoryButton:FindFirstChild("WhiteStroke")
	if stroke and stroke:IsA("UIStroke") then
		strokeTemplate = stroke
	end

	return strokeTemplate
end

function Client_Equip.EnsureStroke(button: ImageButton): UIStroke?
	local existing = slotStrokes[button]
	if existing and existing.Parent then
		return existing
	end

	local template = getStrokeTemplate()
	if not template then
		return nil
	end

	local stroke = button:FindFirstChild("WhiteStroke")
	if not stroke or not stroke:IsA("UIStroke") then
		stroke = template:Clone()
		stroke.Name = "WhiteStroke"
		stroke.Parent = button
	end

	stroke.Enabled = false
	slotStrokes[button] = stroke
	return stroke
end

function Client_Equip.SetStroke(button: ImageButton?, inventoryIndex: number?)
	if not button then
		return
	end

	local stroke = Client_Equip.EnsureStroke(button)
	if not stroke then
		return
	end

	stroke.Enabled = inventoryIndex ~= nil and equippedInventoryIndex == inventoryIndex
end

function Client_Equip.SetStrokeEnabled(button: ImageButton?, enabled: boolean)
	if not button then
		return
	end

	local stroke = button:FindFirstChild("WhiteStroke")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Enabled = enabled
	end
end

function Client_Equip.GetEquippedIndex(): number?
	return equippedInventoryIndex
end

function Client_Equip.IsEquipped(inventoryIndex: number): boolean
	return equippedInventoryIndex == inventoryIndex
end

function Client_Equip.ValidateEquipped()
	if not equippedInventoryIndex then
		return
	end

	local inventory = Client_Data:GetValue("Inventory") or {}
	if not inventory[equippedInventoryIndex] then
		equippedInventoryIndex = nil
		notifyEquipChanged()
	end
end

function Client_Equip.SetRefreshAll(callback: () -> ())
	refreshAll = callback
end

function Client_Equip.ToggleHotbarSlot(slotIndex: number)
	if slotIndex < 1 or slotIndex > Client_Hotbar.GetSize() then
		return
	end

	local inventoryIndex = Client_Hotbar.GetSlotInventoryIndex(slotIndex)
	if not inventoryIndex then
		return
	end

	Client_Equip.Toggle(inventoryIndex)

	if refreshAll then
		refreshAll()
	end
end

function Client_Equip.OnChanged(listener: () -> ())
	table.insert(equipListeners, listener)
end

function Client_Equip.Toggle(inventoryIndex: number?)
	if not inventoryIndex then
		return
	end

	if equippedInventoryIndex == inventoryIndex then
		equippedInventoryIndex = nil
	else
		equippedInventoryIndex = inventoryIndex
	end
	notifyEquipChanged()
end

function Client_Equip.Unequip()
	equippedInventoryIndex = nil
	notifyEquipChanged()
end

function Client_Equip.Refresh(scrollingFrame: ScrollingFrame?, itemTemplate: Instance?)
	Client_Equip.ValidateEquipped()

	for slotIndex = 1, Client_Hotbar.GetSize() do
		local button = Client_Hotbar.GetSlotButton(slotIndex)
		local inventoryIndex = Client_Hotbar.GetSlotInventoryIndex(slotIndex)
		Client_Equip.SetStroke(button, inventoryIndex)
	end

	if not scrollingFrame or not itemTemplate then
		return
	end

	for _, child in scrollingFrame:GetChildren() do
		if child == itemTemplate or not child:IsA("GuiObject") then
			continue
		end

		local inventoryIndex = tonumber(string.match(child.Name, "%d+"))
		local button = child:IsA("ImageButton") and child or child:FindFirstChildWhichIsA("ImageButton", true)
		if button and button:IsA("ImageButton") and inventoryIndex then
			Client_Equip.SetStroke(button, inventoryIndex)
		end
	end
end

function Client_Equip.Init()
	getStrokeTemplate()

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		local slotIndex = table.find(SLOT_KEY_CODES, input.KeyCode)
		if not slotIndex or slotIndex > Client_Hotbar.GetSize() then
			return
		end

		Client_Equip.ToggleHotbarSlot(slotIndex)
	end)
end

return Client_Equip
