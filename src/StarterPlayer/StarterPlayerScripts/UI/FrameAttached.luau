local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared_Sounds = require(ReplicatedStorage.Modules.Shared_Sounds)
local Client_Data = require(script.Parent.Parent.Client.Client_Data)
local Client_SoundPreload = require(script.Parent.Parent.Client.Client_SoundPreload)
local FrameController = require(script.Parent.FrameController)
local FrameRegistry = require(script.Parent.FrameRegistry)

local TAG = "FrameAttached"
local INVENTORY_NAME = "Inventory"

local FrameAttached = {}

local active: { [Instance]: RBXScriptConnection } = {}
local inventoryButtons: { [ImageButton]: boolean } = {}
local keyboardToggleConnection: RBXScriptConnection? = nil

local function playHotkeyToggleSfx()
	local soundId = Shared_Sounds.SFX and Shared_Sounds.SFX.ImageButtonClick or ""
	if type(soundId) ~= "string" or soundId == "" then
		return
	end

	local sfxEnabled = Client_Data:GetValue("SFX")
	if sfxEnabled == false then
		return
	end

	Client_SoundPreload.PlayUi(soundId, 1, 0)
end

local function setInventoryStatus(button: ImageButton, isOpen: boolean)
	local status = button:FindFirstChild("Status")
	if not status or not status:IsA("TextLabel") then
		return
	end

	status.Text = if isOpen then "CLOSE" else "OPEN"

	local gradient = status:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Enabled = isOpen
	end
end

local function bindInventoryButton(button: ImageButton)
	if inventoryButtons[button] then
		return
	end
	inventoryButtons[button] = true
	setInventoryStatus(button, FrameController.isInventoryOpen())
end

local function toggle(button: ImageButton)
	local frameName = button:GetAttribute("AttachedFrame")
	if type(frameName) ~= "string" or frameName == "" then
		return
	end

	FrameRegistry.toggle(frameName)
end

local function setup(instance: Instance)
	if not instance:IsA("ImageButton") then
		return
	end
	if active[instance] then
		return
	end

	local frameName = instance:GetAttribute("AttachedFrame")
	if frameName == INVENTORY_NAME then
		bindInventoryButton(instance)
	end

	active[instance] = instance.MouseButton1Click:Connect(function()
		toggle(instance)
	end)

	instance.Destroying:Connect(function()
		local connection = active[instance]
		if connection then
			connection:Disconnect()
			active[instance] = nil
		end
		inventoryButtons[instance] = nil
	end)
end

local function teardown(instance: Instance)
	local connection = active[instance]
	if not connection then
		return
	end
	connection:Disconnect()
	active[instance] = nil
	inventoryButtons[instance] = nil
end

function FrameAttached.init()
	FrameController.onInventoryChanged(function(isOpen)
		for button in inventoryButtons do
			setInventoryStatus(button, isOpen)
		end
	end)

	CollectionService:GetInstanceAddedSignal(TAG):Connect(setup)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(teardown)

	for _, instance in CollectionService:GetTagged(TAG) do
		setup(instance)
	end

	if keyboardToggleConnection then
		keyboardToggleConnection:Disconnect()
		keyboardToggleConnection = nil
	end

	keyboardToggleConnection = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or UserInputService:GetFocusedTextBox() then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		if input.KeyCode == Enum.KeyCode.B then
			playHotkeyToggleSfx()
			FrameRegistry.toggle(INVENTORY_NAME)
		end
	end)
end

return FrameAttached
