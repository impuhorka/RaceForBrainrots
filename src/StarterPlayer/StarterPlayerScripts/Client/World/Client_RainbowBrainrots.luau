local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ClientLoader = require(script.Parent.Parent.Loader)

local Client_RainbowBrainrots = {}

local RAINBOW_EFFECT_TAG = "RainbowEffect"
local RAINBOW_PERIOD = 6
local UPDATE_HZ = 12
local UPDATE_DT = 1 / UPDATE_HZ

local trackedSAs: { [SurfaceAppearance]: boolean } = {}
local saCleanupConns: { [SurfaceAppearance]: RBXScriptConnection } = {}
local heartbeatConnection: RBXScriptConnection? = nil
local initialized = false
local acc = 0
local t = 0
local localPlayer = Players.LocalPlayer

local function getFrameVisible(frameName: string): boolean
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return false
	end
	local main = playerGui:FindFirstChild("Main")
	local frames = main and main:FindFirstChild("Frames")
	local frame = frames and frames:FindFirstChild(frameName)
	return frame ~= nil and frame:IsA("GuiObject") and frame.Visible
end

local function shouldAnimateSurfaceAppearance(sa: SurfaceAppearance, indexVisible: boolean, inventoryVisible: boolean): boolean
	local inViewport = false
	local inIndex = false
	local inInventory = false

	local current: Instance? = sa
	while current do
		if current:IsA("ViewportFrame") then
			inViewport = true
		elseif current.Name == "Index" then
			inIndex = true
		elseif current.Name == "Inventory" then
			inInventory = true
		end
		current = current.Parent
	end

	if not inViewport then
		return true
	end
	if inIndex and not indexVisible then
		return false
	end
	if inInventory and not inventoryVisible then
		return false
	end
	return true
end

local function untrackSurfaceAppearance(sa: SurfaceAppearance)
	trackedSAs[sa] = nil
	local conn = saCleanupConns[sa]
	if conn then
		conn:Disconnect()
		saCleanupConns[sa] = nil
	end
end

local function trackSurfaceAppearance(sa: SurfaceAppearance)
	if trackedSAs[sa] then
		return
	end

	trackedSAs[sa] = true
	saCleanupConns[sa] = sa.AncestryChanged:Connect(function(_, parent)
		if not parent then
			untrackSurfaceAppearance(sa)
		end
	end)
end

local function handleTaggedInstanceAdded(inst: Instance)
	if not inst:IsA("SurfaceAppearance") then
		return
	end
	trackSurfaceAppearance(inst)
end

function Client_RainbowBrainrots.Init()
	if initialized then
		return
	end
	initialized = true

	for _, inst in CollectionService:GetTagged(RAINBOW_EFFECT_TAG) do
		handleTaggedInstanceAdded(inst)
	end

	CollectionService:GetInstanceAddedSignal(RAINBOW_EFFECT_TAG):Connect(handleTaggedInstanceAdded)
	CollectionService:GetInstanceRemovedSignal(RAINBOW_EFFECT_TAG):Connect(function(inst)
		if inst:IsA("SurfaceAppearance") then
			untrackSurfaceAppearance(inst)
		end
	end)

	heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		if not heartbeatConnection then
			return
		end

		acc += dt
		if acc < UPDATE_DT then
			return
		end

		t += acc
		acc = 0

		if not ClientLoader.require("Client_VisualSettings").AreEffectsEnabled() then
			return
		end

		local h = (t / RAINBOW_PERIOD) % 1
		local tint = Color3.fromHSV(h, 1, 1)
		local indexVisible = getFrameVisible("Index")
		local inventoryVisible = getFrameVisible("Inventory")

		for sa in trackedSAs do
			if sa.Parent then
				if shouldAnimateSurfaceAppearance(sa, indexVisible, inventoryVisible) then
					sa.Color = tint
				end
			else
				untrackSurfaceAppearance(sa)
			end
		end
	end)
end

return Client_RainbowBrainrots
