local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Client_Data = require(script.Parent.Client_Data)
local Client_Equip = require(script.Parent.Client_Equip)
local Client_Hotbar = require(script.Parent.Client_Hotbar)
local Client_ItemDisplay = require(script.Parent.Client_ItemDisplay)
local FrameController = require(script.Parent.Parent.UI.FrameController)

local HOLD_DRAG_TIME = 0.75

local Client_Inventory = {}

local inventoryFrame: GuiObject?
local scrollingFrame: ScrollingFrame?
local itemTemplate: GuiObject?
local dragLayer: GuiObject?

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
		local viewportFrame = Client_ItemDisplay.getViewportFrame(clone)
		if viewportFrame then
			local modifier = item.Data and item.Data.Modifier or "Normal"
			local playIdle = playAnimation == true
			Client_ItemDisplay.setupViewport(viewportFrame, item.ConfigName, modifier, playIdle)

			if playIdle then
				task.defer(function()
					if clone.Parent then
						Client_ItemDisplay.setViewportIdlePlaying(viewportFrame, item.ConfigName, true)
					end
				end)
			end
		end

		local itemName = clone:FindFirstChild("ItemName")
		if itemName and itemName:IsA("TextLabel") then
			itemName.Visible = true
			itemName.Text = Client_ItemDisplay.getDisplayName(item.ConfigName, item.ItemType)
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

		local pollConn = RunService.Heartbeat:Connect(function()
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

		local moveConn = UserInputService.InputChanged:Connect(function(moveInput)
			if not dragging or not canCheckDrag then
				return
			end
			if moveInput.UserInputType == Enum.UserInputType.MouseMovement then
				updateDrag(UserInputService:GetMouseLocation())
			elseif moveInput.UserInputType == Enum.UserInputType.Touch and moveInput == input then
				updateDrag(toVector2(moveInput.Position))
			end
		end)

		local endConn
		endConn = UserInputService.InputEnded:Connect(function(endInput)
			if endInput.UserInputType ~= input.UserInputType then
				return
			end

			dragging = false
			pollConn:Disconnect()
			moveConn:Disconnect()
			endConn:Disconnect()

			if dragClone then
				dragClone:Destroy()
			end

			if didDrag then
				local guiPos, rawPos = getDropPositions(endInput)
				local restoreSource = onDrop(guiPos, rawPos, true)

				if restoreSource then
					if fromInventory then
						Client_Inventory.Render()
					elseif item then
						Client_ItemDisplay.renderSlotButton(
							sourceButton,
							item,
							Client_Equip.IsEquipped(inventoryIndex)
						)
					end
				end

				Client_Equip.Refresh(scrollingFrame, itemTemplate)
				return
			end

			Client_Equip.Toggle(inventoryIndex)
			Client_Equip.Refresh(scrollingFrame, itemTemplate)
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
	if not scrollingFrame or not itemTemplate then
		return
	end

	clearInventorySlots()

	local inventory = Client_Data:GetValue("Inventory") or {}

	for inventoryIndex = 1, #inventory do
		if Client_Hotbar.IsInHotbar(inventoryIndex) then
			continue
		end

		local item = inventory[inventoryIndex]
		local slot = itemTemplate:Clone()
		slot.Name = "Item_" .. inventoryIndex
		slot.Visible = true

		local slotButton = getSlotButton(slot)
		if slotButton then
			Client_ItemDisplay.renderSlotButton(
				slotButton,
				item,
				Client_Equip.IsEquipped(inventoryIndex)
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

	Client_Equip.SetRefreshAll(function()
		Client_Equip.Refresh(scrollingFrame, itemTemplate)
		refreshViewportAnimations()
	end)

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

	Client_Data:ListenToChange("Inventory", function()
		Client_Equip.ValidateEquipped()
		Client_Inventory.Render()
	end)

	FrameController.onInventoryChanged(function()
		Client_Inventory.Render()
	end)
end

return Client_Inventory
