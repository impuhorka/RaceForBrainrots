local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local UserInputService = game:GetService("UserInputService")

local Shared_Sounds = require(ReplicatedStorage.Modules.Shared_Sounds)
local Client_Data = require(script.Parent.Client_Data)
local Client_Hotbar = require(script.Parent.Client_Hotbar)
local Client_LuckyBlockOpening = require(script.Parent.Client_LuckyBlockOpening)
local Client_LuckyBlockRevealState = require(script.Parent.Client_LuckyBlockRevealState)
local Client_Messaging = require(script.Parent.Client_Messaging)
local Client_SoundPreload = require(script.Parent.Client_SoundPreload)

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

local MOBILE_CONTROL_NAME_HINTS = {
	"thumbstick",
	"joystick",
	"touchcontrol",
	"jumpbutton",
}

local Client_Equip = {}
local luckyBlockOpenCooldownUntil = 0
local LUCKYBLOCK_OPEN_COOLDOWN = 0.35

local equippedInventoryIndex: number? = nil
local strokeTemplate: UIStroke?
local slotStrokes: { [ImageButton]: UIStroke } = {}
local equipListeners: { () -> () } = {}
local refreshAll: (() -> ())?
local cashAddingFrame: GuiObject? = nil

local function shouldPlaySfx(): boolean
	local value = Client_Data:GetValue("SFX")
	if value == nil then
		return true
	end
	return value == true
end

local function playUiPopSfx()
	local soundId = Shared_Sounds.SFX and Shared_Sounds.SFX.UiPop or ""
	if type(soundId) ~= "string" or soundId == "" then
		return
	end
	if not shouldPlaySfx() then
		return
	end
	Client_SoundPreload.PlayUi(soundId, 1, 1)
end

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
	playUiPopSfx()
	notifyEquipChanged()
end

function Client_Equip.Unequip()
	if not equippedInventoryIndex then
		return
	end
	equippedInventoryIndex = nil
	playUiPopSfx()
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
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if playerGui then
		local main = playerGui:FindFirstChild("Main")
		if main and main:IsA("GuiObject") then
			local foundCashAdding = main:FindFirstChild("CashAdding")
			if foundCashAdding and foundCashAdding:IsA("GuiObject") then
				cashAddingFrame = foundCashAdding
			end
		end
	end

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

		local function isIgnorableUi(gui: GuiObject): boolean
			return cashAddingFrame ~= nil and gui:IsDescendantOf(cashAddingFrame)
		end

		local function isInteractiveControl(gui: GuiObject): boolean
			if isIgnorableUi(gui) then
				return false
			end
			return gui:IsA("TextButton") or gui:IsA("ImageButton") or gui:IsA("TextBox")
		end

		local function hasInteractiveControlAt(x: number, y: number): boolean
			for _, gui in playerGui:GetGuiObjectsAtPosition(x, y) do
				if isInteractiveControl(gui) then
					return true
				end
			end
			return false
		end

		local pointer = getPointerPosition(input)
		local inset = GuiService:GetGuiInset()
		local guiPointer = Vector2.new(pointer.X - inset.X, pointer.Y - inset.Y)

		if hasInteractiveControlAt(pointer.X, pointer.Y) then
			return true
		end

		if hasInteractiveControlAt(guiPointer.X, guiPointer.Y) then
			return true
		end

		return false
	end

	local function isTouchOnMobileMovementControl(input: InputObject): boolean
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return false
		end

		local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
		if not playerGui then
			return false
		end

		local pointer = getPointerPosition(input)
		local inset = GuiService:GetGuiInset()
		local guiPointer = Vector2.new(pointer.X - inset.X, pointer.Y - inset.Y)

		local function hasControlHintsAt(x: number, y: number): boolean
			for _, gui in playerGui:GetGuiObjectsAtPosition(x, y) do
				local current: Instance? = gui
				while current and current ~= playerGui do
					local lowerName = string.lower(current.Name)
					for _, hint in MOBILE_CONTROL_NAME_HINTS do
						if string.find(lowerName, hint, 1, true) then
							return true
						end
					end
					current = current.Parent
				end
			end
			return false
		end

		if hasControlHintsAt(pointer.X, pointer.Y) then
			return true
		end
		if hasControlHintsAt(guiPointer.X, guiPointer.Y) then
			return true
		end

		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.MoveDirection.Magnitude > 0 then
			local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(0, 0)
			-- Fallback for dynamic thumbstick: movement touch usually starts bottom-left.
			if pointer.X <= viewport.X * 0.45 and pointer.Y >= viewport.Y * 0.5 then
				return true
			end
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

		if inputType == Enum.UserInputType.Touch and isTouchOnMobileMovementControl(input) then
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

		if Client_LuckyBlockOpening.IsOpeningBusy() then
			Client_Messaging.Show("Lucky block is already opening.", "red")
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
