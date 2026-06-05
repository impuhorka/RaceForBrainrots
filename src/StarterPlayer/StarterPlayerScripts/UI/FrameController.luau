local TweenService = game:GetService("TweenService")

local INVENTORY_NAME = "Inventory"

local SLIDE_Y = 0.1
local BASE_TIME = 0.35
local OPEN_TIME = BASE_TIME * 0.7
local CLOSE_TIME = OPEN_TIME * 0.5
local OPEN_TWEEN_INFO = TweenInfo.new(OPEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CLOSE_TWEEN_INFO = TweenInfo.new(CLOSE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local FrameController = {}

local origins: { [GuiObject]: UDim2 } = {}
local tweens: { [GuiObject]: Tween } = {}
local tweenGeneration: { [GuiObject]: number } = {}
local currentOpen: GuiObject? = nil
local inventoryOpen = false
local framesFolder: Folder? = nil
local inventoryListeners: { (boolean) -> () } = {}
local blurListeners: { () -> () } = {}
local closingBlurFrames: { [GuiObject]: boolean } = {}
local closeConnections: { [ImageButton]: RBXScriptConnection } = {}

local notifyInventoryChanged: (boolean) -> ()
local notifyBlurChanged: () -> ()

local function getClosedPosition(origin: UDim2): UDim2
	return UDim2.new(origin.X.Scale, origin.X.Offset, origin.Y.Scale - SLIDE_Y, origin.Y.Offset)
end

local function isInventory(frame: GuiObject): boolean
	return frame.Name == INVENTORY_NAME
end

local function countsForBlur(frame: GuiObject): boolean
	return not isInventory(frame)
end

notifyInventoryChanged = function(isOpen: boolean)
	for _, listener in inventoryListeners do
		listener(isOpen)
	end
end

notifyBlurChanged = function()
	for _, listener in blurListeners do
		listener()
	end
end

local function bumpGeneration(frame: GuiObject): number
	local generation = (tweenGeneration[frame] or 0) + 1
	tweenGeneration[frame] = generation
	return generation
end

local function isCurrentGeneration(frame: GuiObject, generation: number): boolean
	return tweenGeneration[frame] == generation
end

local function setClosingForBlur(frame: GuiObject, isClosing: boolean)
	if not countsForBlur(frame) then
		return
	end

	if isClosing then
		if not closingBlurFrames[frame] then
			closingBlurFrames[frame] = true
			notifyBlurChanged()
		end
		return
	end

	if closingBlurFrames[frame] then
		closingBlurFrames[frame] = nil
		notifyBlurChanged()
	end
end

local function cancelTween(frame: GuiObject)
	bumpGeneration(frame)

	local tween = tweens[frame]
	if tween then
		tween:Cancel()
		tweens[frame] = nil
	end

	setClosingForBlur(frame, false)
end

local function getFrame(name: string): GuiObject?
	if not framesFolder then
		return nil
	end
	return framesFolder:FindFirstChild(name) :: GuiObject?
end

local function playOpenTween(frame: GuiObject, origin: UDim2)
	cancelTween(frame)

	local generation = tweenGeneration[frame]

	frame.Position = getClosedPosition(origin)
	frame.Visible = true

	local tween = TweenService:Create(frame, OPEN_TWEEN_INFO, { Position = origin })
	tweens[frame] = tween
	tween:Play()
	tween.Completed:Once(function(state)
		if not isCurrentGeneration(frame, generation) then
			return
		end

		tweens[frame] = nil
		if state == Enum.PlaybackState.Completed then
			frame.Position = origin
		end
	end)
end

local function playCloseTween(frame: GuiObject, origin: UDim2, onFinished: (() -> ())?)
	cancelTween(frame)

	local generation = tweenGeneration[frame]

	setClosingForBlur(frame, true)

	frame.Position = origin
	frame.Visible = true

	local closedPosition = getClosedPosition(origin)
	local tween = TweenService:Create(frame, CLOSE_TWEEN_INFO, { Position = closedPosition })
	tweens[frame] = tween
	tween:Play()
	tween.Completed:Once(function(state)
		if not isCurrentGeneration(frame, generation) then
			return
		end

		tweens[frame] = nil
		setClosingForBlur(frame, false)
		frame.Visible = false
		frame.Position = origin

		if onFinished then
			onFinished()
		end
	end)
end

function FrameController.register(frame: GuiObject)
	if not frame:IsA("GuiObject") then
		return
	end
	origins[frame] = frame.Position
	FrameController.hookCloseButton(frame)
end

function FrameController.hookCloseButton(frame: GuiObject)
	local banner = frame:FindFirstChild("Banner")
	if not banner then
		return
	end

	local closeButton = banner:FindFirstChild("Close")
	if not closeButton or not closeButton:IsA("ImageButton") then
		return
	end

	if closeConnections[closeButton] then
		return
	end

	closeConnections[closeButton] = closeButton.MouseButton1Click:Connect(function()
		FrameController.close(frame)
	end)

	closeButton.Destroying:Connect(function()
		local connection = closeConnections[closeButton]
		if connection then
			connection:Disconnect()
			closeConnections[closeButton] = nil
		end
	end)
end

function FrameController.instantClose(frame: GuiObject, keepCurrent: boolean?)
	cancelTween(frame)

	local origin = origins[frame]
	if origin then
		frame.Position = origin
	end

	frame.Visible = false

	if isInventory(frame) then
		if inventoryOpen then
			inventoryOpen = false
			notifyInventoryChanged(false)
		end
		return
	end

	if not keepCurrent and currentOpen == frame then
		currentOpen = nil
	end
end

function FrameController.openInventory(frame: GuiObject)
	local origin = origins[frame]
	if not origin then
		return
	end

	if inventoryOpen then
		FrameController.closeInventory(frame)
		return
	end

	inventoryOpen = true
	notifyInventoryChanged(true)
	playOpenTween(frame, origin)
end

function FrameController.closeInventory(frame: GuiObject)
	if not inventoryOpen then
		return
	end

	local origin = origins[frame]
	if not origin then
		return
	end

	inventoryOpen = false
	notifyInventoryChanged(false)
	playCloseTween(frame, origin)
end

function FrameController.open(frame: GuiObject)
	if isInventory(frame) then
		FrameController.openInventory(frame)
		return
	end

	local origin = origins[frame]
	if not origin then
		return
	end

	if currentOpen == frame then
		FrameController.close(frame)
		return
	end

	local previous = currentOpen

	if not previous and inventoryOpen then
		local inventoryFrame = getFrame(INVENTORY_NAME)
		if inventoryFrame then
			FrameController.instantClose(inventoryFrame)
		end
	end

	currentOpen = frame
	notifyBlurChanged()

	cancelTween(frame)

	frame.Position = getClosedPosition(origin)
	frame.Visible = true

	if previous then
		FrameController.instantClose(previous, true)
	end

	local generation = tweenGeneration[frame]
	local tween = TweenService:Create(frame, OPEN_TWEEN_INFO, { Position = origin })
	tweens[frame] = tween
	tween:Play()
	tween.Completed:Once(function(state)
		if not isCurrentGeneration(frame, generation) then
			return
		end

		tweens[frame] = nil
		if state == Enum.PlaybackState.Completed and currentOpen == frame then
			frame.Position = origin
		end
	end)
end

function FrameController.close(frame: GuiObject)
	if isInventory(frame) then
		FrameController.closeInventory(frame)
		return
	end

	if currentOpen ~= frame then
		return
	end

	local origin = origins[frame]
	if not origin then
		return
	end

	currentOpen = nil
	playCloseTween(frame, origin)
end

function FrameController.toggle(name: string)
	local frame = getFrame(name)
	if not frame then
		return
	end

	if isInventory(frame) then
		if inventoryOpen then
			FrameController.closeInventory(frame)
		else
			FrameController.openInventory(frame)
		end
		return
	end

	if currentOpen == frame then
		FrameController.close(frame)
	else
		FrameController.open(frame)
	end
end

function FrameController.isInventoryOpen(): boolean
	return inventoryOpen
end

function FrameController.onInventoryChanged(listener: (boolean) -> ())
	table.insert(inventoryListeners, listener)
	listener(inventoryOpen)
end

function FrameController.onBlurChanged(listener: () -> ())
	table.insert(blurListeners, listener)
end

function FrameController.isOpenForBlur(frame: GuiObject): boolean
	if not countsForBlur(frame) then
		return false
	end
	if closingBlurFrames[frame] then
		return false
	end
	if currentOpen == frame then
		return true
	end
	return frame.Visible
end

function FrameController.closeAllInstant()
	if not framesFolder then
		return
	end

	for _, child in framesFolder:GetChildren() do
		if not child:IsA("GuiObject") then
			continue
		end

		cancelTween(child)

		local origin = origins[child]
		if origin then
			child.Position = origin
		end

		child.Visible = false
	end

	table.clear(closingBlurFrames)
	currentOpen = nil

	if inventoryOpen then
		inventoryOpen = false
		notifyInventoryChanged(false)
	end

	notifyBlurChanged()
end

function FrameController.init(frames: Folder)
	framesFolder = frames

	for _, child in frames:GetChildren() do
		FrameController.register(child :: GuiObject)
	end

	FrameController.closeAllInstant()

	frames.ChildAdded:Connect(function(child)
		FrameController.register(child :: GuiObject)
		if child:IsA("GuiObject") and child.Visible then
			FrameController.closeAllInstant()
		end
	end)
end

function FrameController.getFrame(name: string): GuiObject?
	return getFrame(name)
end

function FrameController.countsForBlur(frame: GuiObject): boolean
	return countsForBlur(frame)
end

return FrameController
