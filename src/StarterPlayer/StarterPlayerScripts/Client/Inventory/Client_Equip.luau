local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local GuiService = game:GetService("GuiService")
local ClientLoader = require(script.Parent.Parent.Loader)

local UserInputService = game:GetService("UserInputService")

local Shared_Sounds = SharedModules.require("Shared_Sounds")
local Client_Data = ClientLoader.require("Client_Data")
local Client_Hotbar = ClientLoader.require("Client_Hotbar")
local Client_LuckyBlockOpening = ClientLoader.require("Client_LuckyBlockOpening")
local Client_LuckyBlockRevealState = ClientLoader.require("Client_LuckyBlockRevealState")
local Client_Messaging = ClientLoader.require("Client_Messaging")
local Client_SoundPreload = ClientLoader.require("Client_SoundPreload")

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

-- Full-screen or toast UI that should not block lucky-block taps.
local LUCKY_BLOCK_INPUT_IGNORE = {
	CashAdding = true,
	Messaging = true,
}

local TOUCH_TAP_MAX_MOVEMENT = 22
local TOUCH_TAP_MAX_DURATION = 0.45

local Client_Equip = {}
local luckyBlockOpenCooldownUntil = 0
local LUCKYBLOCK_OPEN_COOLDOWN = 0.35

local function isCarryingLuckyBlock(): boolean
	return Players.LocalPlayer:GetAttribute("CarryingLuckyBlock") == true
end

local equippedInventoryIndex: number? = nil
local strokeTemplate: UIStroke?
local slotStrokes: { [ImageButton]: UIStroke } = {}
local equipListeners: { () -> () } = {}
local refreshAll: (() -> ())?
local cashAddingFrame: GuiObject? = nil
local pendingTouchTaps: { [InputObject]: { startPos: Vector2, startTime: number, cancelled: boolean } } = {}

local function playUiPopSfx()
	local soundId = Shared_Sounds.SFX and Shared_Sounds.SFX.UiPop or ""
	if type(soundId) ~= "string" or soundId == "" then
		return
	end
	Client_SoundPreload.PlayUi(soundId, 1, 1)
end

local function syncEquippedToServer()
	local events = ReplicatedStorage:FindFirstChild("Events")
	local plotHandler = events and events:FindFirstChild("PlotHandler")
	if plotHandler and plotHandler:IsA("RemoteEvent") then
		plotHandler:FireServer("SetEquipped", equippedInventoryIndex)
	end
end

local function notifyEquipChanged()
	syncEquippedToServer()
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
	if isCarryingLuckyBlock() then
		return
	end

	if slotIndex < 1 or slotIndex > Client_Hotbar.GetSize() then
		return
	end

	local inventoryIndex = Client_Hotbar.GetSlotInventoryIndex(slotIndex)
	if not inventoryIndex then
		if equippedInventoryIndex then
			Client_Equip.Unequip()
			if refreshAll then
				refreshAll()
			end
		end
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

function Client_Equip.Equip(inventoryIndex: number?, playSfx: boolean?)
	if not inventoryIndex then
		return
	end

	if Client_LuckyBlockRevealState.IsMaskedIndex(inventoryIndex) then
		return
	end

	local inventory = Client_Data:GetValue("Inventory") or {}
	if not inventory[inventoryIndex] then
		return
	end

	equippedInventoryIndex = inventoryIndex
	if playSfx ~= false then
		playUiPopSfx()
	end
	notifyEquipChanged()
end

function Client_Equip.Toggle(inventoryIndex: number?)
	if not inventoryIndex then
		return
	end

	if isCarryingLuckyBlock() then
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

function Client_Equip.Unequip(playSfx: boolean?)
	if not equippedInventoryIndex then
		return
	end
	equippedInventoryIndex = nil
	if playSfx ~= false then
		playUiPopSfx()
	end
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

local function isIgnoredUi(gui: Instance?): boolean
	local current = gui
	while current do
		if LUCKY_BLOCK_INPUT_IGNORE[current.Name] then
			return true
		end
		if current:GetAttribute("LuckyBlockInputIgnore") == true then
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

	local function isPointerOverBlockingUi(x: number, y: number): boolean
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

		local function shouldIgnoreUi(gui: GuiObject): boolean
			if isIgnoredUi(gui) then
				return true
			end
			if gui.Name == "TrackHit" then
				return true
			end
			return false
		end

		local function isBlockingInteractiveControl(gui: GuiObject): boolean
			if shouldIgnoreUi(gui) then
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

		local function hasBlockingUiAt(screenX: number, screenY: number): boolean
			for _, gui in playerGui:GetGuiObjectsAtPosition(screenX, screenY) do
				if isBlockingInteractiveControl(gui) then
					return true
				end
			end
			return false
		end

		local inset = GuiService:GetGuiInset()
		local guiX = x - inset.X
		local guiY = y - inset.Y

		if hasBlockingUiAt(x, y) then
			return true
		end
		if hasBlockingUiAt(guiX, guiY) then
			return true
		end

		return false
	end

	local function isClickOverAnyUi(input: InputObject): boolean
		local pointer = getPointerPosition(input)
		return isPointerOverBlockingUi(pointer.X, pointer.Y)
	end

	local function tryOpenEquippedLuckyBlock(input: InputObject, gameProcessed: boolean)
		local inputType = input.UserInputType
		if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
			return
		end

		if gameProcessed then
			return
		end

		if tick() < luckyBlockOpenCooldownUntil then
			return
		end

		if isCarryingLuckyBlock() then
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

		if isClickOverAnyUi(input) then
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
		Client_Equip.Unequip(false)

		luckyBlockOpenCooldownUntil = tick() + LUCKYBLOCK_OPEN_COOLDOWN
		plotHandler:FireServer("OpenLuckyBlock", equippedIndex)
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch then
			if gameProcessed then
				return
			end

			local startPos = Vector2.new(input.Position.X, input.Position.Y)
			pendingTouchTaps[input] = {
				startPos = startPos,
				startTime = tick(),
				cancelled = isPointerOverBlockingUi(startPos.X, startPos.Y),
			}
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			tryOpenEquippedLuckyBlock(input, gameProcessed)
			return
		end

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

	UserInputService.InputChanged:Connect(function(input, _gameProcessed)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local pending = pendingTouchTaps[input]
		if not pending or pending.cancelled then
			return
		end

		local currentPos = Vector2.new(input.Position.X, input.Position.Y)
		if (currentPos - pending.startPos).Magnitude > TOUCH_TAP_MAX_MOVEMENT then
			pending.cancelled = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local pending = pendingTouchTaps[input]
		pendingTouchTaps[input] = nil
		if not pending or pending.cancelled or gameProcessed then
			return
		end

		local endPos = Vector2.new(input.Position.X, input.Position.Y)
		if (endPos - pending.startPos).Magnitude > TOUCH_TAP_MAX_MOVEMENT then
			return
		end
		if tick() - pending.startTime > TOUCH_TAP_MAX_DURATION then
			return
		end

		tryOpenEquippedLuckyBlock(input, false)
	end)
end

return Client_Equip