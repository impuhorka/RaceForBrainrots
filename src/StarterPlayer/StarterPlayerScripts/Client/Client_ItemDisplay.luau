local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared_BrainrotAnimations = require(ReplicatedStorage.Modules.Shared_BrainrotAnimations)
local Shared_Brainrots = require(ReplicatedStorage.Modules.Shared_Brainrots)
local Shared_LuckyBlocks = require(ReplicatedStorage.Modules.Shared_LuckyBlocks)
local Shared_Rarities = require(ReplicatedStorage.Modules.Utilities.Shared_Rarities)

local Client_ItemDisplay = {}

local VIEWPORT_MODEL_Y_ROTATION = math.rad(-15)
local VIEWPORT_MODEL_SIZE = 0.7225
local VIEWPORT_MODEL_RETRY_COUNT = 8
local VIEWPORT_MODEL_RETRY_DELAY = 0.1

function Client_ItemDisplay.preloadBrainrotAnimations(inventory: { any })
	Shared_BrainrotAnimations.PreloadInventoryBrainrots(inventory)
end

function Client_ItemDisplay.getDisplayName(configName: string, itemType: string?): string
	if itemType == "LuckyBlock" then
		local cfg = Shared_LuckyBlocks.Data[configName]
		if cfg and type(cfg.DisplayName) == "string" and cfg.DisplayName ~= "" then
			return cfg.DisplayName
		end
		return configName
	end

	return Shared_Brainrots.GetDisplayName(configName)
end

local function getBrainrotModel(configName: string, modifier: string?): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets") or ReplicatedStorage:WaitForChild("Assets", 2)
	local brainrots = assets and (assets:FindFirstChild("Brainrots") or assets:WaitForChild("Brainrots", 2))
	local brainrotFolder = brainrots and (brainrots:FindFirstChild(configName) or brainrots:WaitForChild(configName, 1))
	if not brainrotFolder then
		return nil
	end

	local template: Instance? = nil
	if modifier and modifier ~= "" then
		template = brainrotFolder:FindFirstChild(modifier)
	end

	if not template then
		template = brainrotFolder:FindFirstChild("Normal")
	end

	if not template then
		template = brainrotFolder:FindFirstChildWhichIsA("Model")
	end

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

function Client_ItemDisplay.getSlotImageLabel(root: Instance): ImageLabel?
	local named = root:FindFirstChild("ItemImage", true)
	if named and named:IsA("ImageLabel") then
		return named
	end

	local namedIcon = root:FindFirstChild("Image", true)
	if namedIcon and namedIcon:IsA("ImageLabel") then
		return namedIcon
	end

	for _, descendant in root:GetDescendants() do
		if descendant:IsA("ImageLabel") then
			local current: Instance? = descendant.Parent
			local insideViewport = false
			while current do
				if current:IsA("ViewportFrame") then
					insideViewport = true
					break
				end
				current = current.Parent
			end

			if not insideViewport then
				return descendant
			end
		end
	end

	return nil
end

local function setItemNameRarityGradient(itemName: TextLabel?, rarity: string?)
	if not itemName then
		return
	end

	local existing = itemName:FindFirstChild("RarityGradient")
	if existing and not existing:IsA("UIGradient") then
		existing:Destroy()
		existing = nil
	end

	if not rarity then
		itemName.TextColor3 = Color3.fromRGB(255, 255, 255)
		if existing and existing:IsA("UIGradient") then
			existing.Enabled = false
		end
		return
	end

	local rarityData = Shared_Rarities.Data[rarity]
	if not rarityData then
		itemName.TextColor3 = Color3.fromRGB(255, 255, 255)
		if existing and existing:IsA("UIGradient") then
			existing.Enabled = false
		end
		return
	end

	local gradient = existing
	if not gradient or not gradient:IsA("UIGradient") then
		gradient = Instance.new("UIGradient")
		gradient.Name = "RarityGradient"
		gradient.Parent = itemName
	end

	gradient.Enabled = true
	gradient.Color = rarityData.ColorGradient
	gradient.Rotation = rarityData.GradientRotation or 0
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

	local itemImage = Client_ItemDisplay.getSlotImageLabel(slotButton)
	if itemImage then
		itemImage.Image = ""
		itemImage.Visible = false
	end

	local itemName = slotButton:FindFirstChild("ItemName")
	if itemName and itemName:IsA("TextLabel") then
		itemName.Text = ""
	end

	setItemNameRarityGradient(itemName :: TextLabel?, nil)
end

function Client_ItemDisplay.renderSlotButton(slotButton: ImageButton, item: any, playAnimation: boolean?)
	if not item then
		Client_ItemDisplay.clearSlotButton(slotButton)
		return
	end

	local itemName = slotButton:FindFirstChild("ItemName")
	if itemName and itemName:IsA("TextLabel") then
		itemName.Visible = true
	end

	local viewportFrame = Client_ItemDisplay.getViewportFrame(slotButton)
	local itemImage = Client_ItemDisplay.getSlotImageLabel(slotButton)

	if item.ItemType == "LuckyBlock" then
		local cfg = Shared_LuckyBlocks.Data[item.ConfigName]
		local rarity = cfg and cfg.Rarity

		if viewportFrame then
			viewportFrame:ClearAllChildren()
			viewportFrame.Visible = false
		end

		if itemImage then
			itemImage.Image = if cfg and type(cfg.Image) == "string" then cfg.Image else ""
			itemImage.Visible = true
		end

		if itemName and itemName:IsA("TextLabel") then
			itemName.Text = if type(rarity) == "string" and rarity ~= "" then rarity else "Lucky"
			setItemNameRarityGradient(itemName, rarity)
		end
		return
	end

	if itemName and itemName:IsA("TextLabel") then
		itemName.Text = Client_ItemDisplay.getDisplayName(item.ConfigName, item.ItemType)
	end
	setItemNameRarityGradient(itemName :: TextLabel?, nil)

	if itemImage then
		itemImage.Image = ""
		itemImage.Visible = false
	end

	if viewportFrame then
		local modifier = item.Data and item.Data.Modifier or "Normal"
		local renderToken = ((slotButton:GetAttribute("_ViewportRenderToken") :: number?) or 0) + 1
		slotButton:SetAttribute("_ViewportRenderToken", renderToken)
		Client_ItemDisplay.setupViewport(viewportFrame, item.ConfigName, modifier, playAnimation)

		if not viewportFrame.Visible then
			task.spawn(function()
				for _ = 1, VIEWPORT_MODEL_RETRY_COUNT do
					if slotButton:GetAttribute("_ViewportRenderToken") ~= renderToken then
						return
					end
					if not slotButton.Parent or not viewportFrame.Parent then
						return
					end

					task.wait(VIEWPORT_MODEL_RETRY_DELAY)
					Client_ItemDisplay.setupViewport(viewportFrame, item.ConfigName, modifier, playAnimation)
					if viewportFrame.Visible then
						return
					end
				end
			end)
		end
	end
end

return Client_ItemDisplay
