local Players = game:GetService("Players")
local ClientLoader = require(script.Parent.Parent.Loader)

local Client_Data = ClientLoader.require("Client_Data")
local Client_ItemDisplay = ClientLoader.require("Client_ItemDisplay")
local Client_LuckyBlockRevealState = ClientLoader.require("Client_LuckyBlockRevealState")

local HOTBAR_MAX = 9

local Client_Hotbar = {}

local hotbarSize = 0
local lastInventoryCount = 0
local previousInventory: { any } = {}

local hotbarFrame: Frame?
local slotButtons: { ImageButton } = {}
local hotbarSlots: { number? } = {}
local changedListeners: { () -> () } = {}

local function notifyChanged()
	for _, listener in changedListeners do
		listener()
	end
end

local function renderSlot(slotIndex: number)
	local slotButton = slotButtons[slotIndex]
	if not slotButton then
		return
	end

	local inventoryIndex = hotbarSlots[slotIndex]
	local inventory = Client_Data:GetValue("Inventory") or {}
	local item = inventoryIndex and inventory[inventoryIndex]
	local playAnimation = false
	if inventoryIndex then
		playAnimation = ClientLoader.require("Client_Equip").IsEquipped(inventoryIndex)
	end

	Client_ItemDisplay.renderSlotButton(slotButton, item, playAnimation, inventoryIndex)
end

local function preloadInventoryAnimations()
	local inventory = Client_Data:GetValue("Inventory") or {}
	Client_ItemDisplay.preloadBrainrotAnimations(inventory)
end

local function renderHotbar()
	for slotIndex = 1, hotbarSize do
		renderSlot(slotIndex)
	end
end

local function findFirstEmptyHotbarSlot(): number?
	for slotIndex = 1, hotbarSize do
		if not hotbarSlots[slotIndex] then
			return slotIndex
		end
	end
	return nil
end

local function snapshotInventory(inventory: { any }): { any }
	local copy = {}
	for index, item in inventory do
		copy[index] = item
	end
	return copy
end

local function itemsMatch(a: any, b: any): boolean
	if not a or not b then
		return false
	end
	if a.ItemType ~= b.ItemType or a.ConfigName ~= b.ConfigName then
		return false
	end

	local aData = a.Data or {}
	local bData = b.Data or {}
	return (aData.Level or 1) == (bData.Level or 1)
		and (aData.Modifier or "Normal") == (bData.Modifier or "Normal")
		and (aData.BaseWeight or 0) == (bData.BaseWeight or 0)
		and (aData.Weight or 0) == (bData.Weight or 0)
end

local function findItemIndex(inventory: { any }, item: any): number?
	for index, candidate in inventory do
		if itemsMatch(candidate, item) then
			return index
		end
	end
	return nil
end

function Client_Hotbar.IsInHotbar(inventoryIndex: number): boolean
	for slotIndex = 1, hotbarSize do
		if hotbarSlots[slotIndex] == inventoryIndex then
			return true
		end
	end
	return false
end

local function remapHotbarSlots(inventory: { any })
	for slotIndex = 1, hotbarSize do
		local inventoryIndex = hotbarSlots[slotIndex]
		if not inventoryIndex then
			continue
		end

		local currentItem = inventory[inventoryIndex]
		local previousItem = previousInventory[inventoryIndex]
		if currentItem and previousItem and itemsMatch(currentItem, previousItem) then
			continue
		end

		if not previousItem then
			hotbarSlots[slotIndex] = nil
			continue
		end

		local newIndex = findItemIndex(inventory, previousItem)
		hotbarSlots[slotIndex] = newIndex
	end
end

local function assignNewItemsToHotbar(inventory: { any })
	if #inventory <= lastInventoryCount then
		return
	end

	for inventoryIndex = lastInventoryCount + 1, #inventory do
		if Client_Hotbar.IsInHotbar(inventoryIndex) then
			continue
		end

		local emptySlot = findFirstEmptyHotbarSlot()
		if not emptySlot then
			break
		end

		hotbarSlots[emptySlot] = inventoryIndex
	end
end

local function syncHotbarFromInventory()
	local inventory = Client_Data:GetValue("Inventory") or {}

	remapHotbarSlots(inventory)

	for slotIndex = 1, hotbarSize do
		local inventoryIndex = hotbarSlots[slotIndex]
		if inventoryIndex and not inventory[inventoryIndex] then
			hotbarSlots[slotIndex] = nil
		end
	end

	assignNewItemsToHotbar(inventory)

	previousInventory = snapshotInventory(inventory)
	lastInventoryCount = #inventory
end

function Client_Hotbar.GetSize(): number
	return hotbarSize
end

function Client_Hotbar.GetHotbarSlots(): { number? }
	return hotbarSlots
end

function Client_Hotbar.GetSlotButton(slotIndex: number): ImageButton?
	return slotButtons[slotIndex]
end

function Client_Hotbar.GetSlotInventoryIndex(slotIndex: number): number?
	return hotbarSlots[slotIndex]
end

function Client_Hotbar.GetHotbarItem(slotIndex: number): any?
	if slotIndex < 1 or slotIndex > hotbarSize then
		return nil
	end

	local inventoryIndex = hotbarSlots[slotIndex]
	if not inventoryIndex then
		return nil
	end

	local inventory = Client_Data:GetValue("Inventory") or {}
	return inventory[inventoryIndex]
end

function Client_Hotbar.SetHotbarSlot(slotIndex: number, inventoryIndex: number?)
	if slotIndex < 1 or slotIndex > hotbarSize then
		return
	end

	if inventoryIndex then
		for i = 1, hotbarSize do
			if hotbarSlots[i] == inventoryIndex then
				hotbarSlots[i] = nil
			end
		end
	end

	hotbarSlots[slotIndex] = inventoryIndex
	renderHotbar()
	notifyChanged()
end

function Client_Hotbar.RemoveFromHotbar(inventoryIndex: number)
	for slotIndex = 1, hotbarSize do
		if hotbarSlots[slotIndex] == inventoryIndex then
			hotbarSlots[slotIndex] = nil
		end
	end
	renderHotbar()
	notifyChanged()
end

function Client_Hotbar.OnChanged(listener: () -> ())
	table.insert(changedListeners, listener)
end

function Client_Hotbar.Refresh()
	syncHotbarFromInventory()
	renderHotbar()
	notifyChanged()
end

function Client_Hotbar.Init()
	Client_Data.WaitUntilReady()

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	hotbarFrame = playerGui:WaitForChild("Main"):WaitForChild("Hotbar")

	table.clear(slotButtons)
	hotbarSize = 0
	for slotIndex = 1, HOTBAR_MAX do
		local slotButton = hotbarFrame:FindFirstChild(tostring(slotIndex))
		if slotButton and slotButton:IsA("ImageButton") then
			slotButtons[slotIndex] = slotButton
			hotbarSize = slotIndex
		end
	end

	if hotbarSize == 0 then
		warn("No hotbar slots found")
	end

	table.clear(hotbarSlots)
	lastInventoryCount = 0
	previousInventory = {}

	local inventory = Client_Data:GetValue("Inventory") or {}
	previousInventory = snapshotInventory(inventory)
	assignNewItemsToHotbar(inventory)
	lastInventoryCount = #inventory
	previousInventory = snapshotInventory(inventory)
	renderHotbar()

	task.spawn(preloadInventoryAnimations)

	Client_Data:ListenToChange("Inventory", function()
		syncHotbarFromInventory()
		renderHotbar()
		notifyChanged()
		task.spawn(preloadInventoryAnimations)
	end)

	Client_LuckyBlockRevealState.OnChanged(function()
		renderHotbar()
		notifyChanged()
	end)
end

return Client_Hotbar