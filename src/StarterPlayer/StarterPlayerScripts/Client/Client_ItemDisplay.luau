local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared_BrainrotAnimations = require(ReplicatedStorage.Modules.Shared_BrainrotAnimations)
local Shared_Brainrots = require(ReplicatedStorage.Modules.Shared_Brainrots)

local Client_ItemDisplay = {}

local VIEWPORT_MODEL_Y_ROTATION = math.rad(-15)
local VIEWPORT_MODEL_SIZE = 0.7225

function Client_ItemDisplay.preloadBrainrotAnimations(inventory: { any })
	Shared_BrainrotAnimations.PreloadInventoryBrainrots(inventory)
end

function Client_ItemDisplay.getDisplayName(configName: string): string
	return Shared_Brainrots.GetDisplayName(configName)
end

local function getBrainrotModel(configName: string, modifier: string?): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local brainrots = assets and assets:FindFirstChild("Brainrots")
	local brainrotFolder = brainrots and brainrots:FindFirstChild(configName)
	if not brainrotFolder then
		return nil
	end

	local template = brainrotFolder:FindFirstChild(modifier or "Normal")
	if not template or not template:IsA("Model") then
		return nil
	end

	local model = template:Clone()
	model.Name = configName
	return model
end

function Client_ItemDisplay.getViewportFrame(root: Instance): ViewportFrame?
	return root:FindFirstChildWhichIsA("ViewportFrame", true)
end

function Client_ItemDisplay.setupViewport(
	viewportFrame: ViewportFrame,
	configName: string,
	modifier: string?,
	playAnimation: boolean?
)
	viewportFrame:ClearAllChildren()

	local model = getBrainrotModel(configName, modifier)
	if not model then
		viewportFrame.Visible = false
		return
	end

	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewportFrame
	model.Parent = worldModel
	model:PivotTo(model:GetPivot() * CFrame.Angles(0, VIEWPORT_MODEL_Y_ROTATION, 0))

	local cf, size = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local center = cf.Position
	local halfHeight = size.Y * 0.5
	local halfWidth = math.max(size.X, size.Z) * 0.5

	local vFov = math.rad(camera.FieldOfView)
	local viewportSize = viewportFrame.AbsoluteSize
	local aspect = if viewportSize.Y > 0 then viewportSize.X / viewportSize.Y else 1
	local hFov = 2 * math.atan(math.tan(vFov * 0.5) * aspect)

	local distY = halfHeight / math.tan(vFov * 0.5)
	local distX = halfWidth / math.tan(hFov * 0.5)
	local distance = math.max(distY, distX) * 0.9 / VIEWPORT_MODEL_SIZE

	local lookVector = pivot.LookVector
	local upVector = pivot.UpVector

	camera.CFrame = CFrame.lookAt(
		center + lookVector * distance + upVector * (halfHeight * 0.05),
		center
	)

	if playAnimation then
		local animModel = model
		local animConfigName = configName
		task.defer(function()
			if animModel.Parent then
				Shared_BrainrotAnimations.PlayIdle(animModel, animConfigName)
			end
		end)
	end

	viewportFrame.Visible = true
end

function Client_ItemDisplay.setViewportIdlePlaying(viewportFrame: ViewportFrame, configName: string, playing: boolean)
	local worldModel = viewportFrame:FindFirstChildOfClass("WorldModel")
	if not worldModel then
		return
	end

	local model = worldModel:FindFirstChildWhichIsA("Model")
	if not model then
		return
	end

	if playing then
		Shared_BrainrotAnimations.PlayIdle(model, configName)
	else
		Shared_BrainrotAnimations.StopIdle(model)
	end
end

function Client_ItemDisplay.clearSlotButton(slotButton: ImageButton)
	local viewportFrame = Client_ItemDisplay.getViewportFrame(slotButton)
	if viewportFrame and viewportFrame:IsA("ViewportFrame") then
		viewportFrame:ClearAllChildren()
		viewportFrame.Visible = false
	end

	local itemName = slotButton:FindFirstChild("ItemName")
	if itemName and itemName:IsA("TextLabel") then
		itemName.Text = ""
	end
end

function Client_ItemDisplay.renderSlotButton(slotButton: ImageButton, item: any, playAnimation: boolean?)
	if not item then
		Client_ItemDisplay.clearSlotButton(slotButton)
		return
	end

	local itemName = slotButton:FindFirstChild("ItemName")
	if itemName and itemName:IsA("TextLabel") then
		itemName.Visible = true
		itemName.Text = Client_ItemDisplay.getDisplayName(item.ConfigName)
	end

	local viewportFrame = Client_ItemDisplay.getViewportFrame(slotButton)
	if viewportFrame then
		local modifier = item.Data and item.Data.Modifier or "Normal"
		Client_ItemDisplay.setupViewport(viewportFrame, item.ConfigName, modifier, playAnimation)
	end
end

return Client_ItemDisplay
