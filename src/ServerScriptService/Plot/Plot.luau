local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_PlotConfig = SharedModules.require("Shared_PlotConfig")
local Shared_Rebirth = SharedModules.require("Shared_Rebirth")

local Plot = {}
Plot.__index = Plot

local function getPlotIdFromName(name: string): number
	local numberText = string.match(name, "%d+")
	return tonumber(numberText) or 0
end

local function getBillboardLabels(billboard: BillboardGui): (ImageLabel?, TextLabel?)
	local root = billboard:FindFirstChild("Frame", true)
	if not root or not root:IsA("GuiObject") then
		root = billboard
	end

	return root:FindFirstChildWhichIsA("ImageLabel", true), root:FindFirstChildWhichIsA("TextLabel", true)
end

local function getPlotAssets()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local plotAssets = assets and assets:FindFirstChild("Plot")
	if not plotAssets then
		return nil, nil
	end

	return plotAssets:FindFirstChild("PlotSlot"), plotAssets:FindFirstChild("AdditionalFloor")
end

local function getMapFolder(plotModel: Model): Instance
	return plotModel:FindFirstChild("Map") or plotModel
end

local function getFloor0(plotModel: Model): Model?
	local map = getMapFolder(plotModel)
	local floor0 = map:FindFirstChild("Floor0")
	if floor0 and floor0:IsA("Model") then
		return floor0
	end
	return nil
end

local function slotHasBrainrot(slotModel: Model): boolean
	local configName = slotModel:GetAttribute("ConfigName")
	return type(configName) == "string" and configName ~= ""
end

local function storeButtonDefaults(buttonModel: Model)
	for _, part in buttonModel:GetDescendants() do
		if part:IsA("BasePart") then
			if part:GetAttribute("OriginalTransparency") == nil then
				part:SetAttribute("OriginalTransparency", part.Transparency)
			end
			if part:GetAttribute("OriginalCanCollide") == nil then
				part:SetAttribute("OriginalCanCollide", part.CanCollide)
			end
		end
	end
end

local function setButtonVisible(buttonModel: Model, visible: boolean)
	for _, part in buttonModel:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end

		if visible then
			local transparency = part:GetAttribute("OriginalTransparency")
			if transparency ~= nil then
				part.Transparency = transparency
			end
			local canCollide = part:GetAttribute("OriginalCanCollide")
			if canCollide ~= nil then
				part.CanCollide = canCollide
			end
		else
			part.Transparency = 1
			part.CanCollide = false
		end
	end
end

local function setInteractSurfaceEnabled(slotModel: Model, enabled: boolean)
	local interactPart = slotModel:FindFirstChild("InteractButton", true)
	if not interactPart or not interactPart:IsA("BasePart") then
		return
	end

	for _, child in interactPart:GetChildren() do
		if child:IsA("SurfaceGui") then
			child.Enabled = enabled
		end
	end
end

local function updateSlotOccupiedState(slotModel: Model)
	local occupied = slotHasBrainrot(slotModel)

	local buttonModel = slotModel:FindFirstChild("Button")
	if buttonModel and buttonModel:IsA("Model") then
		storeButtonDefaults(buttonModel)
		setButtonVisible(buttonModel, occupied)
	end

	setInteractSurfaceEnabled(slotModel, occupied)
end

local function hookSlotOccupiedState(slotModel: Model)
	updateSlotOccupiedState(slotModel)
	slotModel:GetAttributeChangedSignal("ConfigName"):Connect(function()
		updateSlotOccupiedState(slotModel)
	end)
end

local function getUpgradeSign(plotModel: Model): Instance?
	return plotModel:FindFirstChild("UpgradeSign", true)
end

local function getUpgradeSignMainPart(upgradeSign: Instance): BasePart?
	local main = upgradeSign:FindFirstChild("main", true)
	if main and main:IsA("BasePart") then
		return main
	end
	return nil
end

local function storeUpgradeSignDefaults(upgradeSign: Instance)
	for _, descendant in upgradeSign:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant:GetAttribute("OriginalTransparency") == nil then
				descendant:SetAttribute("OriginalTransparency", descendant.Transparency)
			end
			if descendant:GetAttribute("OriginalCanCollide") == nil then
				descendant:SetAttribute("OriginalCanCollide", descendant.CanCollide)
			end
		elseif descendant:IsA("SurfaceGui") then
			if descendant:GetAttribute("OriginalSurfaceGuiEnabled") == nil then
				descendant:SetAttribute("OriginalSurfaceGuiEnabled", descendant.Enabled)
			end
		end
	end
end

local function setUpgradeSignRegistered(upgradeSign: Instance, registered: boolean)
	storeUpgradeSignDefaults(upgradeSign)

	for _, descendant in upgradeSign:GetDescendants() do
		if descendant:IsA("BasePart") then
			if registered then
				local transparency = descendant:GetAttribute("OriginalTransparency")
				if transparency ~= nil then
					descendant.Transparency = transparency
				end
				local canCollide = descendant:GetAttribute("OriginalCanCollide")
				if canCollide ~= nil then
					descendant.CanCollide = canCollide
				end
			else
				descendant.Transparency = 1
				descendant.CanCollide = false
			end
		elseif descendant:IsA("SurfaceGui") then
			if registered then
				local enabled = descendant:GetAttribute("OriginalSurfaceGuiEnabled")
				if enabled ~= nil then
					descendant.Enabled = enabled
				end
			else
				descendant.Enabled = false
			end
		end
	end
end

local function disableUpgradeSignSurfaceTemplate(plotModel: Model)
	local upgradeSign = getUpgradeSign(plotModel)
	if not upgradeSign then
		return
	end

	local mainPart = getUpgradeSignMainPart(upgradeSign)
	if not mainPart then
		return
	end

	for _, child in mainPart:GetChildren() do
		if child:IsA("SurfaceGui") then
			child.Enabled = false
		end
	end
end

function Plot.new(model: Model)
	local teleportPart = model:FindFirstChild("TeleportPart", true)
	assert(teleportPart and teleportPart:IsA("BasePart"), ("Missing TeleportPart in %s"):format(model:GetFullName()))

	local ownerPart = model:FindFirstChild("OwnerPart", true)
	assert(ownerPart and ownerPart:IsA("BasePart"), ("Missing OwnerPart in %s"):format(model:GetFullName()))

	local ownerAttachment = ownerPart:FindFirstChildOfClass("Attachment")
	assert(ownerAttachment, ("Missing Owner attachment in %s"):format(model:GetFullName()))

	local billboard = ownerAttachment:FindFirstChildOfClass("BillboardGui")
	assert(billboard, ("Missing Owner billboard in %s"):format(model:GetFullName()))

	local self = setmetatable({}, Plot)
	self.Model = model
	self.Name = model.Name
	self.Id = getPlotIdFromName(model.Name)
	self.TeleportPart = teleportPart
	self.OwnerPart = ownerPart
	self.Billboard = billboard
	self.Owner = nil
	self.Slots = {}
	self.Floors = {}
	self.TotalSlots = 0
	self.Billboard.Enabled = false

	local upgradeSign = getUpgradeSign(model)
	if upgradeSign then
		setUpgradeSignRegistered(upgradeSign, false)
	end

	return self
end

function Plot:IsAvailable(): boolean
	return self.Owner == nil
end

function Plot:ClearBuild()
	for _, slot in self.Slots do
		if slot and slot.Parent then
			slot:Destroy()
		end
	end
	table.clear(self.Slots)
	self.TotalSlots = 0

	for floorIndex, floorModel in self.Floors do
		if floorIndex > 0 and floorModel and floorModel.Parent then
			floorModel:Destroy()
		end
	end
	table.clear(self.Floors)

	local slotsFolder = self.Model:FindFirstChild("Slots")
	if slotsFolder then
		slotsFolder:ClearAllChildren()
	end
end

function Plot:EnsureAdditionalFloor(floorIndex: number, additionalFloorTemplate: Model)
	if floorIndex <= 0 then
		return
	end

	if self.Floors[floorIndex] then
		return
	end

	local map = getMapFolder(self.Model)
	local existing = map:FindFirstChild("Floor" .. floorIndex)
	if existing and existing:IsA("Model") then
		self.Floors[floorIndex] = existing
		return
	end

	local floor0 = getFloor0(self.Model)
	if not floor0 then
		warn(("Missing Floor0 on %s"):format(self.Model.Name))
		return
	end

	local floorModel = additionalFloorTemplate:Clone()
	floorModel.Name = "Floor" .. floorIndex
	floorModel.Parent = map

	local yOffset = Shared_PlotConfig.getAdditionalFloorYOffset(floorIndex)
	local rotation = Shared_PlotConfig.getFloorRotation(floorIndex)
	floorModel:PivotTo(floor0:GetPivot() * CFrame.new(0, yOffset, 0) * rotation)

	self.Floors[floorIndex] = floorModel
end

function Plot:CleanupUnusedFloors()
	local usedFloors: { [number]: boolean } = { [0] = true }

	for slotId in self.Slots do
		local floorIndex = math.floor((slotId - 1) / Shared_PlotConfig.SlotsPerFloor)
		usedFloors[floorIndex] = true
	end

	for floorIndex, floorModel in self.Floors do
		if floorIndex > 0 and not usedFloors[floorIndex] then
			if floorModel and floorModel.Parent then
				floorModel:Destroy()
			end
			self.Floors[floorIndex] = nil
		end
	end
end

function Plot:GetSlotsFolder(): Folder
	local slotsFolder = self.Model:FindFirstChild("Slots")
	if not slotsFolder then
		slotsFolder = Instance.new("Folder")
		slotsFolder.Name = "Slots"
		slotsFolder.Parent = self.Model
	end
	return slotsFolder
end

function Plot:CreateSlot(slotId: number): Model?
	if self.Slots[slotId] then
		return self.Slots[slotId]
	end

	local slotTemplate, additionalFloorTemplate = getPlotAssets()
	if not slotTemplate then
		warn("Missing ReplicatedStorage.Assets.Plot.PlotSlot")
		return nil
	end

	local floorIndex = math.floor((slotId - 1) / Shared_PlotConfig.SlotsPerFloor)

	if floorIndex >= 1 and additionalFloorTemplate then
		self:EnsureAdditionalFloor(floorIndex, additionalFloorTemplate)
	end

	local slotCFrame = self:GetSlotCFrame(slotId)
	if not slotCFrame then
		return nil
	end

	local slotModel = slotTemplate:Clone()
	slotModel.Name = "Slot" .. slotId
	slotModel:PivotTo(slotCFrame)
	slotModel.Parent = self:GetSlotsFolder()

	local upgradePart = slotModel:FindFirstChild("UpgradePart", true)
	if upgradePart then
		for _, child in upgradePart:GetChildren() do
			if child:IsA("SurfaceGui") then
				child.Enabled = false
			end
		end
	end

	hookSlotOccupiedState(slotModel)

	self.Slots[slotId] = slotModel
	if slotId > self.TotalSlots then
		self.TotalSlots = slotId
	end

	return slotModel
end

function Plot:AddSlot(): Model?
	local slotId = self.TotalSlots + 1
	while self.Slots[slotId] do
		slotId += 1
	end
	return self:CreateSlot(slotId)
end

function Plot:GetSlotCFrame(slotId: number): CFrame?
	local slotRelativeId = ((slotId - 1) % Shared_PlotConfig.SlotsPerFloor) + 1
	local floorIndex = math.floor((slotId - 1) / Shared_PlotConfig.SlotsPerFloor)
	local relative = Shared_PlotConfig.SlotRelativeCFrames[slotRelativeId]

	if not relative then
		return nil
	end

	local yOffset = Shared_PlotConfig.getSlotFloorYOffset(floorIndex)
	local baseCFrame = self.TeleportPart.CFrame * relative

	if yOffset == 0 then
		return baseCFrame
	end

	return baseCFrame + self.TeleportPart.CFrame.UpVector * yOffset
end

function Plot:Build(totalSlots: number)
	self:ClearBuild()

	for slotId = 1, totalSlots do
		self:CreateSlot(slotId)
	end

	self.TotalSlots = totalSlots
end

function Plot:RefreshBillboard()
	local imageLabel, textLabel = getBillboardLabels(self.Billboard)
	if not self.Owner then
		if imageLabel then
			imageLabel.Image = ""
		end
		if textLabel then
			textLabel.Text = ""
		end
		return
	end

	if textLabel then
		textLabel.Text = self.Owner.DisplayName or self.Owner.Name
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

	if not imageLabel then
		return
	end

	local userId = self.Owner.UserId
	task.spawn(function()
		local ok, thumb = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		if ok and thumb and self.Owner and self.Owner.UserId == userId and imageLabel.Parent then
			imageLabel.Image = thumb
		end
	end)
end

function Plot:Assign(player: Player, totalSlots: number, rebirths: any?)
	self.Owner = player
	self.Model:SetAttribute("OwnerUserId", player.UserId)
	self.Model:SetAttribute("OwnerName", player.Name)
	self.Model:SetAttribute("OwnerRebirths", Shared_Rebirth.GetRebirthCount(rebirths))
	self.Billboard.Enabled = true

	local upgradeSign = getUpgradeSign(self.Model)
	if upgradeSign then
		setUpgradeSignRegistered(upgradeSign, true)
		disableUpgradeSignSurfaceTemplate(self.Model)
	end

	self:Build(totalSlots)
	self:RefreshBillboard()
end

function Plot:Release()
	self:ClearBuild()
	self.Owner = nil
	self.Model:SetAttribute("OwnerUserId", 0)
	self.Model:SetAttribute("OwnerName", "")
	self.Model:SetAttribute("OwnerRebirths", 0)

	local upgradeSign = getUpgradeSign(self.Model)
	if upgradeSign then
		setUpgradeSignRegistered(upgradeSign, false)
	end

	self.Billboard.Enabled = false
	self:RefreshBillboard()
end

function Plot:TeleportCharacter(character: Model)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		rootPart = character:WaitForChild("HumanoidRootPart", 5)
	end
	if not rootPart then
		return
	end

	character:PivotTo(self.TeleportPart.CFrame + Vector3.new(0, 4, 0))
end

function Plot:TeleportPlayer(player: Player)
	local character = player.Character
	if not character then
		return
	end
	self:TeleportCharacter(character)

	local Server_AntiCheat = require(script.Parent.Parent.Core.Server_AntiCheat)
	Server_AntiCheat.GrantTeleportGrace(player)
end

function Plot:GetSlot(slotId: number): Model?
	return self.Slots[slotId]
end

return Plot