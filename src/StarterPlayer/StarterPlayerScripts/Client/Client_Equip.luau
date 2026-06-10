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

-- Never treat these UI roots as blocking lucky-block screen taps.
local LUCKY_BLOCK_INPUT_BLACKLIST = {
	CashAdding = true,
	Messaging = true,
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

local function playUiPopSfx()
	local soundId = Shared_Sounds.SFX and Shared_Sounds.SFX.UiPop or ""
	if type(soundId) ~= "string" or soundId == "" then
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

local function isUnderBlacklistedUi(gui: Instance?): boolean
	local current = gui
	while current do
		if LUCKY_BLOCK_INPUT_BLACKLIST[current.Name] then
			return true
		end
		if current:GetAttribute("LuckyBlockInputBlacklist") == true then
			return true
		end
		if cashAddingFrame ~= nil and (current == cashAddingFrame or current:IsDescendantOf(cashAddingFrame)) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function resolveCashAddingFrame()
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	local main = playerGui:FindFirstChild("Main")
	if not main or not main:IsA("GuiObject") then
		return
	end

	local foundCashAdding = main:FindFirstChild("CashAdding")
	if foundCashAdding and foundCashAdding:IsA("GuiObject") then
		cashAddingFrame = foundCashAdding
	end
end

function Client_Equip.Init()
	getStrokeTemplate()
	resolveCashAddingFrame()
	task.defer(function()
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		local main = playerGui:WaitForChild("Main")
		local foundCashAdding = main:WaitForChild("CashAdding", 10)
		if foundCashAdding and foundCashAdding:IsA("GuiObject") then
			cashAddingFrame = foundCashAdding
		end
	end)

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

		local function isGuiVisibleForInput(gui: GuiObject): boolean
			local current: Instance? = gui
			while current do
				if current:IsA("GuiObject") and not current.Visible then
					return false
				end
				current = current.Parent
			end
			return true
		end

		local function isIgnorableUi(gui: GuiObject): boolean
			if isUnderBlacklistedUi(gui) then
				return true
			end
			if gui.Name == "TrackHit" then
				return true
			end
			return false
		end

		local function isBlockingInteractiveControl(gui: GuiObject): boolean
			if isIgnorableUi(gui) then
				return false
			end
			if not isGuiVisibleForInput(gui) then
				return false
			end
			if not gui.Active then
				return false
			end
			return gui:IsA("TextButton") or gui:IsA("ImageButton") or gui:IsA("TextBox")
		end

		local function hasBlockingInteractiveControlAt(x: number, y: number): boolean
			for _, gui in playerGui:GetGuiObjectsAtPosition(x, y) do
				if isUnderBlacklistedUi(gui) then
					continue
				end
				if isBlockingInteractiveControl(gui) then
					return true
				end
			end
			return false
		end

		local function isTapOnlyOverBlacklistedUi(x: number, y: number): boolean
			local objects = playerGui:GetGuiObjectsAtPosition(x, y)
			if #objects == 0 then
				return false
			end

			for _, gui in objects do
				if not isUnderBlacklistedUi(gui) then
					return false
				end
			end
			return true
		end

		local pointer = getPointerPosition(input)
		local inset = GuiService:GetGuiInset()
		local guiPointer = Vector2.new(pointer.X - inset.X, pointer.Y - inset.Y)

		if isTapOnlyOverBlacklistedUi(pointer.X, pointer.Y) then
			return false
		end
		if isTapOnlyOverBlacklistedUi(guiPointer.X, guiPointer.Y) then
			return false
		end

		if hasBlockingInteractiveControlAt(pointer.X, pointer.Y) then
			return true
		end

		if hasBlockingInteractiveControlAt(guiPointer.X, guiPointer.Y) then
			return true
		end

		return false
	end

	local function tryOpenEquippedLuckyBlock(input: InputObject, _gameProcessed: boolean)
		local inputType = input.UserInputType
		if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
			return
		end

		if tick() < luckyBlockOpenCooldownUntil then
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

		-- Mobile: tap anywhere opens the lucky block. CashAdding and other HUD overlays
		-- must never block touch input for this flow.
		if inputType ~= Enum.UserInputType.Touch and isClickOverAnyUi(input) then
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
