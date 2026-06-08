local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local UserInputService = game:GetService("UserInputService")

local Client_Data = require(script.Parent.Client_Data)
local Client_Hotbar = require(script.Parent.Client_Hotbar)
local Client_LuckyBlockOpening = require(script.Parent.Client_LuckyBlockOpening)
local Client_LuckyBlockRevealState = require(script.Parent.Client_LuckyBlockRevealState)
local Client_Messaging = require(script.Parent.Client_Messaging)

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
local luckyBlockOpenCooldownUntil = 0
local LUCKYBLOCK_OPEN_COOLDOWN = 0.35

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

	if Client_LuckyBlockRevealState.IsMaskedIndex(inventoryIndex) then
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

	if Client_LuckyBlockRevealState.IsMaskedIndex(inventoryIndex) then
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

	local function getPointerPosition(input: InputObject): Vector2
		if input.UserInputType == Enum.UserInputType.Touch then
			return Vector2.new(input.Position.X, input.Position.Y)
		end
		return UserInputService:GetMouseLocation()
	end

	local function isClickOverAnyUi(input: InputObject): boolean
		local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
		if not playerGui then
			return false
		end

		local pointer = getPointerPosition(input)
		local inset = GuiService:GetGuiInset()
		local guiPointer = Vector2.new(pointer.X - inset.X, pointer.Y - inset.Y)

		local rawObjects = playerGui:GetGuiObjectsAtPosition(pointer.X, pointer.Y)
		if #rawObjects > 0 then
			-- On touch devices there are often fullscreen helper layers in PlayerGui.
			-- Only block when touching actually interactive UI controls.
			if input.UserInputType == Enum.UserInputType.Touch then
				for _, gui in rawObjects do
					if gui:IsA("TextButton") or gui:IsA("ImageButton") or gui:IsA("TextBox") then
						return true
					end
				end
			else
				return true
			end
		end

		local insetObjects = playerGui:GetGuiObjectsAtPosition(guiPointer.X, guiPointer.Y)
		if input.UserInputType == Enum.UserInputType.Touch then
			for _, gui in insetObjects do
				if gui:IsA("TextButton") or gui:IsA("ImageButton") or gui:IsA("TextBox") then
					return true
				end
			end
			return false
		end
		if #insetObjects > 0 then
			return true
		end
		return false
	end

	local function tryOpenEquippedLuckyBlock(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		local inputType = input.UserInputType
		if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
			return
		end

		if tick() < luckyBlockOpenCooldownUntil then
			return
		end

		if Client_LuckyBlockOpening.IsOpeningBusy() then
			Client_Messaging.Show("Lucky block is already opening.", "red")
			return
		end

		if isClickOverAnyUi(input) then
			return
		end

		local equippedIndex = equippedInventoryIndex
		if not equippedIndex then
			return
		end

		local inventory = Client_Data:GetValue("Inventory") or {}
		local item = inventory[equippedIndex]
		if not item or item.ItemType ~= "LuckyBlock" then
			return
		end

		local events = ReplicatedStorage:FindFirstChild("Events")
		local plotHandler = events and events:FindFirstChild("PlotHandler")
		if not plotHandler or not plotHandler:IsA("RemoteEvent") then
			return
		end

		-- Remove held lucky block visual immediately when opening starts.
		Client_Equip.Unequip()

		luckyBlockOpenCooldownUntil = tick() + LUCKYBLOCK_OPEN_COOLDOWN
		plotHandler:FireServer("OpenLuckyBlock", equippedIndex)
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		tryOpenEquippedLuckyBlock(input, gameProcessed)

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
