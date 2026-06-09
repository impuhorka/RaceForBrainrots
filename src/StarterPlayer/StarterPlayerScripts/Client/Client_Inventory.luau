local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client_Data = require(script.Parent.Client_Data)
local Client_Equip = require(script.Parent.Client_Equip)
local Client_Hotbar = require(script.Parent.Client_Hotbar)
local Client_ItemDisplay = require(script.Parent.Client_ItemDisplay)
local Client_LuckyBlockRevealState = require(script.Parent.Client_LuckyBlockRevealState)
local FrameController = require(script.Parent.Parent.UI.FrameController)
local Shared_Brainrots = require(ReplicatedStorage.Modules.Shared_Brainrots)
local Shared_LuckyBlocks = require(ReplicatedStorage.Modules.Shared_LuckyBlocks)
local Shared_Sounds = require(ReplicatedStorage.Modules.Shared_Sounds)
local Client_SoundPreload = require(script.Parent.Client_SoundPreload)

local HOLD_DRAG_TIME = 0.75
local DRAG_FAILSAFE_TIMEOUT = 6
local INVENTORY_MAX_SLOTS = 60

local Client_Inventory = {}

local inventoryFrame: GuiObject?
local scrollingFrame: ScrollingFrame?
local itemTemplate: GuiObject?
local dragLayer: GuiObject?
local searchTextBox: TextBox?
local slotsCountLabel: TextLabel?

local function playUiPopSfx()
	local soundId = Shared_Sounds.SFX and Shared_Sounds.SFX.UiPop or ""
	if type(soundId) ~= "string" or soundId == "" then
		return
	end
	Client_SoundPreload.PlayUi(soundId, 1, 1)
end

local function toGuiPos(position: Vector2): Vector2
	local inset = GuiService:GetGuiInset()
	return Vector2.new(position.X - inset.X, position.Y - inset.Y)
end

local function toVector2(position: Vector2 | Vector3): Vector2
	if typeof(position) == "Vector3" then
		return Vector2.new(position.X, position.Y)
	end
	return position
end

local function isPointInGui(gui: GuiObject, position: Vector2): boolean
	local absPos = gui.AbsolutePosition
	local absSize = gui.AbsoluteSize
	return position.X >= absPos.X
		and position.X <= absPos.X + absSize.X
		and position.Y >= absPos.Y
		and position.Y <= absPos.Y + absSize.Y
end

local function isPointInGuiAt(gui: GuiObject, guiPos: Vector2, rawPos: Vector2): boolean
	return isPointInGui(gui, guiPos) or isPointInGui(gui, rawPos)
end

local function getHotbarSlotAtPoint(guiPos: Vector2, rawPos: Vector2): number?
	for slotIndex = 1, Client_Hotbar.GetSize() do
		local slotButton = Client_Hotbar.GetSlotButton(slotIndex)
		if slotButton and isPointInGuiAt(slotButton, guiPos, rawPos) then
			return slotIndex
		end
	end

	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end

	for _, pos in { guiPos, rawPos } do
		for _, gui in playerGui:GetGuiObjectsAtPosition(pos.X, pos.Y) do
			for slotIndex = 1, Client_Hotbar.GetSize() do
				local slotButton = Client_Hotbar.GetSlotButton(slotIndex)
				if slotButton and (gui == slotButton or gui:IsDescendantOf(slotButton)) then
					return slotIndex
				end
			end
		end
	end

	return nil
end

local function getDropPositions(endInput: InputObject): (Vector2, Vector2)
	local rawPos = toVector2(endInput.Position)
	return toGuiPos(rawPos), rawPos
end

local function getSlotButton(root: Instance): ImageButton?
	if root:IsA("ImageButton") then
		return root
	end
	return root:FindFirstChildWhichIsA("ImageButton", true)
end

local function clearInventorySlots()
	if not scrollingFrame then
		return
	end

	for _, child in scrollingFrame:GetChildren() do
		if child ~= itemTemplate and child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function setSlotIdVisible(button: ImageButton, visible: boolean)
	local idLabel = button:FindFirstChild("ID")
	if idLabel and idLabel:IsA("TextLabel") then
		idLabel.Visible = visible
	end
end

local function normalizeSearchText(text: string): string
	return string.lower(string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

local function getItemRarity(item: any): string
	if not item or type(item.ConfigName) ~= "string" then
		return ""
	end

	if item.ItemType == "Brainrot" then
		local config = Shared_Brainrots.Data[item.ConfigName]
		return config and (config.Rarity or "") or ""
	end

	if item.ItemType == "LuckyBlock" then
		local config = Shared_LuckyBlocks.Data[item.ConfigName]
		return config and (config.Rarity or "") or ""
	end

	return ""
end

local function itemMatchesSearch(item: any, query: string): boolean
	if query == "" then
		return true
	end

	if not item then
		return false
	end

	local modifier = if type(item.Data) == "table" and type(item.Data.Modifier) == "string" and item.Data.Modifier ~= ""
		then item.Data.Modifier
		else "Normal"
	local itemType = if type(item.ItemType) == "string" then item.ItemType else ""
	local configName = if type(item.ConfigName) == "string" then item.ConfigName else ""
	local displayName = Client_ItemDisplay.getDisplayName(configName, itemType)
	local rarity = getItemRarity(item)

	local searchBlob = string.lower(table.concat({
		displayName,
		configName,
		modifier,
		rarity,
		itemType,
	}, " "))

	return string.find(searchBlob, query, 1, true) ~= nil
end

local function updateSlotsCounter(inventory: { any })
	if not slotsCountLabel then
		return
	end
	slotsCountLabel.Text = ("%s/%s"):format(#inventory, INVENTORY_MAX_SLOTS)
end

local function createDragClone(original: ImageButton, item: any, playAnimation: boolean?)
	local absSize = original.AbsoluteSize

	local clone = original:Clone()
	clone.Parent = dragLayer
	clone.AnchorPoint = Vector2.new(0, 0)
	clone.AutomaticSize = Enum.AutomaticSize.None
	clone.Size = UDim2.fromOffset(absSize.X, absSize.Y)
	clone.Visible = true
	clone.ZIndex = 50

	for _, child in clone:GetDescendants() do
		if child:IsA("UIScale") then
			child:Destroy()
		elseif child:IsA("GuiObject") then
			child.ZIndex = math.max(child.ZIndex, 50)
		end
	end

	setSlotIdVisible(clone, false)

	if item then
		local itemName = clone:FindFirstChild("ItemName")
		if item.ItemType == "Brainrot" then
			local viewportFrame = Client_ItemDisplay.getViewportFrame(clone)
			if viewportFrame then
				local modifier = item.Data and item.Data.Modifier or "Normal"
				local playIdle = playAnimation == true
				Client_ItemDisplay.setupViewport(viewportFrame, item.ConfigName, modifier, playIdle)
				Client_ItemDisplay.setModifierStroke(clone, modifier)

				if playIdle then
					task.defer(function()
						if clone.Parent then
							Client_ItemDisplay.setViewportIdlePlaying(viewportFrame, item.ConfigName, true)
						end
					end)
				end
			end

			if itemName and itemName:IsA("TextLabel") then
				itemName.Visible = true
				itemName.Text = Client_ItemDisplay.getDisplayName(item.ConfigName, item.ItemType)
			end
		elseif item.ItemType == "LuckyBlock" then
			local viewportFrame = Client_ItemDisplay.getViewportFrame(clone)
			if viewportFrame then
				viewportFrame:ClearAllChildren()
				viewportFrame.Visible = false
			end
			if itemName and itemName:IsA("TextLabel") then
				itemName.Visible = true
				itemName.Text = ""
			end
			Client_ItemDisplay.setModifierStroke(clone, "Normal")
		end
	end

	return clone
end

local function positionDragClone(clone: GuiObject, position: Vector2, grabOffset: Vector2)
	if not dragLayer then
		return
	end

	local layerPos = dragLayer.AbsolutePosition
	clone.Position = UDim2.fromOffset(
		position.X - layerPos.X - grabOffset.X,
		position.Y - layerPos.Y - grabOffset.Y
	)
end

local function getInventorySlotRoot(button: ImageButton): GuiObject
	local parent = button.Parent
	if parent and parent:IsA("GuiObject") and parent ~= scrollingFrame then
		return parent :: GuiObject
	end
	return button
end

local function getPointerPosition(activeInput: InputObject, fallback: Vector2): Vector2
	if activeInput.UserInputType == Enum.UserInputType.Touch then
		return toVector2(activeInput.Position)
	end
	return UserInputService:GetMouseLocation()
end

local function isPointerInSlot(bounds: GuiObject, position: Vector2): boolean
	local rawPos = toVector2(position)
	return isPointInGuiAt(bounds, toGuiPos(rawPos), rawPos)
end

local function runSlotInteraction(
	sourceButton: ImageButton,
	getInventoryIndex: () -> number?,
	getItem: () -> any,
	onDrop: (Vector2, Vector2, boolean) -> boolean,
	inventorySlot: GuiObject?,
	requireInventoryOpen: boolean
)
	if not dragLayer then
		return
	end

	local function begin(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		if requireInventoryOpen and not FrameController.isInventoryOpen() then
			return
		end

		local inventoryIndex = getInventoryIndex()
		local item = getItem()
		if not inventoryIndex or not item then
			return
		end

		if Client_LuckyBlockRevealState.IsMaskedIndex(inventoryIndex) then
			return
		end

		local fromInventory = inventorySlot ~= nil
		local dragBounds: GuiObject = if fromInventory
			then (inventorySlot or getInventorySlotRoot(sourceButton))
			else sourceButton
		local startTime = tick()
		local startPos = toGuiPos(getPointerPosition(input, toVector2(input.Position)))
		local lastPos = getPointerPosition(input, toVector2(input.Position))
		local grabOffset = startPos - sourceButton.AbsolutePosition
		local dragging = true
		local didDrag = false
		local canCheckDrag = false
		local dragClone: ImageButton? = nil
		local pollConn: RBXScriptConnection?
		local moveConn: RBXScriptConnection?
		local endConn: RBXScriptConnection?
		local dragFailSafeConn: RBXScriptConnection?
		local finished = false

		task.defer(function()
			canCheckDrag = true
		end)

		local function hideOrigin()
			if fromInventory then
				local slot = inventorySlot or getInventorySlotRoot(sourceButton)
				if slot and slot.Parent then
					slot:Destroy()
				end
			else
				Client_ItemDisplay.clearSlotButton(sourceButton)
				Client_Equip.SetStrokeEnabled(sourceButton, false)
			end
		end

		local function startDrag(position: Vector2)
			if didDrag then
				return
			end

			if not FrameController.isInventoryOpen() then
				return
			end

			didDrag = true
			dragClone = createDragClone(sourceButton, item, Client_Equip.IsEquipped(inventoryIndex))
			if dragClone and Client_Equip.IsEquipped(inventoryIndex) then
				Client_Equip.SetStrokeEnabled(dragClone, true)
			end
			hideOrigin()
			positionDragClone(dragClone, toGuiPos(position), grabOffset)
		end

		local function updateDrag(position: Vector2)
			lastPos = position
			if not didDrag then
				if not isPointerInSlot(dragBounds, position) then
					startDrag(position)
				end
				return
			end

			if dragClone then
				positionDragClone(dragClone, toGuiPos(position), grabOffset)
			end
		end

		local function finishDrag(dropRawPos: Vector2?)
			if finished then
				return
			end
			finished = true
			dragging = false

			if pollConn then
				pollConn:Disconnect()
				pollConn = nil
			end
			if moveConn then
				moveConn:Disconnect()
				moveConn = nil
			end
			if endConn then
				endConn:Disconnect()
				endConn = nil
			end
			if dragFailSafeConn then
				dragFailSafeConn:Disconnect()
				dragFailSafeConn = nil
			end

			if dragClone then
				dragClone:Destroy()
				dragClone = nil
			end

			if didDrag then
				local rawPos = dropRawPos or lastPos
				local guiPos = toGuiPos(rawPos)
				local restoreSource = onDrop(guiPos, rawPos, true)
				if not restoreSource then
					playUiPopSfx()
				end

				if restoreSource then
					if fromInventory then
						Client_Inventory.Render()
					elseif item then
						Client_ItemDisplay.renderSlotButton(
							sourceButton,
							item,
							Client_Equip.IsEquipped(inventoryIndex),
							inventoryIndex
						)
					end
				end

				Client_Equip.Refresh(scrollingFrame, itemTemplate)
				return
			end

			Client_Equip.Toggle(inventoryIndex)
			Client_Equip.Refresh(scrollingFrame, itemTemplate)
		end

		pollConn = RunService.Heartbeat:Connect(function()
			if not dragging or didDrag or not canCheckDrag then
				return
			end

			lastPos = getPointerPosition(input, lastPos)

			if not isPointerInSlot(dragBounds, lastPos) then
				startDrag(lastPos)
				return
			end

			if tick() - startTime >= HOLD_DRAG_TIME then
				startDrag(lastPos)
			end
		end)

		-- Fail-safe timeout only: if drag somehow never receives InputEnded,
		-- force cleanup after a long timeout to avoid ghost clones.
		dragFailSafeConn = RunService.Heartbeat:Connect(function()
			if not dragging or not didDrag then
				return
			end

			if tick() - startTime < DRAG_FAILSAFE_TIMEOUT then
				return
			end

			local fallbackPos = lastPos
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				fallbackPos = UserInputService:GetMouseLocation()
			end
			finishDrag(toVector2(fallbackPos))
		end)

		moveConn = UserInputService.InputChanged:Connect(function(moveInput)
			if not dragging or not canCheckDrag then
				return
			end
			if moveInput.UserInputType == Enum.UserInputType.MouseMovement then
				updateDrag(UserInputService:GetMouseLocation())
			elseif moveInput.UserInputType == Enum.UserInputType.Touch and moveInput == input then
				updateDrag(toVector2(moveInput.Position))
			end
		end)

		endConn = UserInputService.InputEnded:Connect(function(endInput)
			if endInput.UserInputType ~= input.UserInputType then
				return
			end
			finishDrag(toVector2(endInput.Position))
		end)
	end

	return begin
end

local function moveHotbarItemToInventory(slotIndex: number)
	Client_Hotbar.SetHotbarSlot(slotIndex, nil)
	Client_Inventory.Render()
end

local function swapHotbarSlots(fromSlot: number, toSlot: number)
	if fromSlot == toSlot then
		return
	end

	local fromIndex = Client_Hotbar.GetSlotInventoryIndex(fromSlot)
	local toIndex = Client_Hotbar.GetSlotInventoryIndex(toSlot)
	Client_Hotbar.SetHotbarSlot(fromSlot, toIndex)
	Client_Hotbar.SetHotbarSlot(toSlot, fromIndex)
end

local function setupHotbarSlot(slotIndex: number, slotButton: ImageButton)
	Client_Equip.EnsureStroke(slotButton)

	local beginInteraction = runSlotInteraction(
		slotButton,
		function()
			return Client_Hotbar.GetSlotInventoryIndex(slotIndex)
		end,
		function()
			return Client_Hotbar.GetHotbarItem(slotIndex)
		end,
		function(dropPos, rawPos)
			local inventoryIndex = Client_Hotbar.GetSlotInventoryIndex(slotIndex)
			if not inventoryIndex then
				return true
			end

			if isPointInGuiAt(slotButton, dropPos, rawPos) then
				return true
			end

			local targetSlot = getHotbarSlotAtPoint(dropPos, rawPos)
			if targetSlot then
				if targetSlot == slotIndex then
					return true
				end

				local targetIndex = Client_Hotbar.GetSlotInventoryIndex(targetSlot)
				if targetIndex then
					swapHotbarSlots(slotIndex, targetSlot)
				else
					Client_Hotbar.SetHotbarSlot(targetSlot, inventoryIndex)
				end
				Client_Inventory.Render()
				return false
			end

			if not FrameController.isInventoryOpen() then
				return true
			end

			moveHotbarItemToInventory(slotIndex)
			return false
		end,
		nil,
		false
	)

	slotButton.InputBegan:Connect(beginInteraction)
end

local function setupInventorySlot(inventoryIndex: number, slotRoot: GuiObject, slotButton: ImageButton)
	Client_Equip.EnsureStroke(slotButton)

	local beginInteraction = runSlotInteraction(
		slotButton,
		function()
			return inventoryIndex
		end,
		function()
			local inventory = Client_Data:GetValue("Inventory") or {}
			return inventory[inventoryIndex]
		end,
		function(dropPos, rawPos)
			local targetSlot = getHotbarSlotAtPoint(dropPos, rawPos)
			if targetSlot then
				Client_Hotbar.SetHotbarSlot(targetSlot, inventoryIndex)
				Client_Inventory.Render()
				return false
			end

			return true
		end,
		slotRoot,
		true
	)

	slotButton.InputBegan:Connect(beginInteraction)
end

local function refreshViewportAnimations()
	local equippedIndex = Client_Equip.GetEquippedIndex()

	for slotIndex = 1, Client_Hotbar.GetSize() do
		local slotButton = Client_Hotbar.GetSlotButton(slotIndex)
		local inventoryIndex = Client_Hotbar.GetSlotInventoryIndex(slotIndex)
		local item = Client_Hotbar.GetHotbarItem(slotIndex)
		if slotButton and inventoryIndex and item then
			local viewportFrame = Client_ItemDisplay.getViewportFrame(slotButton)
			if viewportFrame then
				Client_ItemDisplay.setViewportIdlePlaying(
					viewportFrame,
					item.ConfigName,
					inventoryIndex == equippedIndex
				)
			end
		end
	end

	if not scrollingFrame or not itemTemplate then
		return
	end

	for _, child in scrollingFrame:GetChildren() do
		if child == itemTemplate or not child:IsA("GuiObject") then
			continue
		end

		local inventoryIndex = tonumber(string.match(child.Name, "%d+"))
		if not inventoryIndex then
			continue
		end

		local slotButton = getSlotButton(child)
		if not slotButton then
			continue
		end

		local inventory = Client_Data:GetValue("Inventory") or {}
		local item = inventory[inventoryIndex]
		if not item then
			continue
		end

		local viewportFrame = Client_ItemDisplay.getViewportFrame(slotButton)
		if viewportFrame then
			Client_ItemDisplay.setViewportIdlePlaying(
				viewportFrame,
				item.ConfigName,
				inventoryIndex == equippedIndex
			)
		end
	end
end

function Client_Inventory.Render()
	local inventory = Client_Data:GetValue("Inventory") or {}
	updateSlotsCounter(inventory)

	if not scrollingFrame or not itemTemplate then
		return
	end

	clearInventorySlots()
	local searchQuery = normalizeSearchText(if searchTextBox then searchTextBox.Text else "")

	for inventoryIndex = 1, #inventory do
		if Client_Hotbar.IsInHotbar(inventoryIndex) then
			continue
		end

		local item = inventory[inventoryIndex]
		if not itemMatchesSearch(item, searchQuery) then
			continue
		end

		local slot = itemTemplate:Clone()
		slot.Name = "Item_" .. inventoryIndex
		slot.Visible = true

		local slotButton = getSlotButton(slot)
		if slotButton then
			Client_ItemDisplay.renderSlotButton(
				slotButton,
				item,
				Client_Equip.IsEquipped(inventoryIndex),
				inventoryIndex
			)
			slot.Parent = scrollingFrame
			setupInventorySlot(inventoryIndex, slot, slotButton)
		end
	end

	Client_Equip.Refresh(scrollingFrame, itemTemplate)
end

function Client_Inventory.Init()
	Client_Data.WaitUntilReady()
	Client_Equip.Init()

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local main = playerGui:WaitForChild("Main")
	dragLayer = main

	inventoryFrame = main:WaitForChild("Frames"):WaitForChild("Inventory")
	scrollingFrame = inventoryFrame:WaitForChild("ScrollingFrame") :: ScrollingFrame
	itemTemplate = scrollingFrame:WaitForChild("Template")
	itemTemplate.Visible = false

	local searchRoot = inventoryFrame:FindFirstChild("Search", true)
	if searchRoot then
		if searchRoot:IsA("TextBox") then
			searchTextBox = searchRoot
		else
			local nestedSearch = searchRoot:FindFirstChildWhichIsA("TextBox", true)
			if nestedSearch then
				searchTextBox = nestedSearch
			end
		end
	end

	local slotsRoot = inventoryFrame:FindFirstChild("Slots", true)
	if slotsRoot then
		if slotsRoot:IsA("TextLabel") then
			slotsCountLabel = slotsRoot
		else
			local nestedLabel = slotsRoot:FindFirstChildWhichIsA("TextLabel", true)
			if nestedLabel then
				slotsCountLabel = nestedLabel
			end
		end
	end

	Client_Equip.SetRefreshAll(function()
		Client_Equip.Refresh(scrollingFrame, itemTemplate)
		refreshViewportAnimations()
	end)

	if searchTextBox then
		searchTextBox:GetPropertyChangedSignal("Text"):Connect(function()
			Client_Inventory.Render()
		end)
	end

	for slotIndex = 1, Client_Hotbar.GetSize() do
		local slotButton = Client_Hotbar.GetSlotButton(slotIndex)
		if slotButton then
			setupHotbarSlot(slotIndex, slotButton)
		end
	end

	Client_Inventory.Render()

	Client_Hotbar.OnChanged(function()
		Client_Equip.ValidateEquipped()
		Client_Inventory.Render()
	end)

	Client_Equip.OnChanged(function()
		refreshViewportAnimations()
	end)

	Client_Data:ListenToChange("Animations", refreshViewportAnimations)

	Client_Data:ListenToChange("Inventory", function()
		Client_Equip.ValidateEquipped()
		Client_Inventory.Render()
	end)

	FrameController.onInventoryChanged(function()
		Client_Inventory.Render()
	end)

	Client_LuckyBlockRevealState.OnChanged(function()
		Client_Inventory.Render()
	end)
end

return Client_Inventory
