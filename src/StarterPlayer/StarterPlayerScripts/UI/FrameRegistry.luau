local Players = game:GetService("Players")

local BlurController = require(script.Parent.BlurController)
local FrameController = require(script.Parent.FrameController)
local ClientLoader = require(script.Parent.Parent.Client.Loader)
local Client_FOV = ClientLoader.require("Client_FOV")

local FrameRegistry = {}

local player = Players.LocalPlayer
local hooked: { [GuiObject]: boolean } = {}

local function isAnyOpen(frames: Folder): boolean
	for _, child in frames:GetChildren() do
		if child:IsA("GuiObject") and FrameController.isOpenForBlur(child) then
			return true
		end
	end
	return false
end

local function update(frames: Folder)
	local anyOpen = isAnyOpen(frames)
	BlurController.setOpen(anyOpen)
	Client_FOV.setFrameZoomActive(anyOpen)
end

local function hookFrame(frame: GuiObject, frames: Folder)
	if hooked[frame] then
		return
	end
	hooked[frame] = true

	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		update(frames)
	end)
end

local function setup(frames: Folder)
	FrameController.init(frames)

	FrameController.onBlurChanged(function()
		update(frames)
	end)

	local function refresh()
		update(frames)
	end

	for _, child in frames:GetChildren() do
		if child:IsA("GuiObject") then
			hookFrame(child, frames)
		end
	end

	frames.ChildAdded:Connect(function(child)
		if child:IsA("GuiObject") then
			hookFrame(child, frames)
		end
		refresh()
	end)

	frames.ChildRemoved:Connect(refresh)
	refresh()
end

function FrameRegistry.init()
	local playerGui = player:WaitForChild("PlayerGui")
	local main = playerGui:WaitForChild("Main")
	local frames = main:WaitForChild("Frames")
	setup(frames)
end

function FrameRegistry.getFrame(name: string): GuiObject?
	return FrameController.getFrame(name)
end

function FrameRegistry.toggle(name: string)
	FrameController.toggle(name)
end

return FrameRegistry
