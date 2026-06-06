local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared_BrainrotBillboard = require(ReplicatedStorage.Modules.Shared_BrainrotBillboard)
local Shared_Brainrots = require(ReplicatedStorage.Modules.Shared_Brainrots)
local Shared_ProximityPrompt = require(ReplicatedStorage.Modules.Shared_ProximityPrompt)

local PlotBrainrotVisuals = {}

local function getBrainrotTemplate(configName: string, modifier: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local brainrots = assets and assets:FindFirstChild("Brainrots")
	local brainrotFolder = brainrots and brainrots:FindFirstChild(configName)
	if not brainrotFolder then
		return nil
	end

	local template = brainrotFolder:FindFirstChild(modifier) or brainrotFolder:FindFirstChild("Normal")
	if not template or not template:IsA("Model") then
		return nil
	end

	return template
end

local function getStandingPivot(slotModel: Model, brainrotModel: Model): CFrame?
	local standingPart = slotModel:FindFirstChild("StandingPart", true)
	local primaryPart = brainrotModel.PrimaryPart
	if not standingPart or not standingPart:IsA("BasePart") or not primaryPart then
		return nil
	end

	local yOffset = standingPart.Size.Y / 2 + primaryPart.Size.Y / 2
	return standingPart.CFrame * CFrame.new(0, yOffset, 0) * CFrame.Angles(0, math.rad(90), 0)
end

local function updateBillboardAttachment(brainrotModel: Model)
	local primaryPart = brainrotModel.PrimaryPart
	if not primaryPart then
		return
	end

	local attachment = primaryPart:FindFirstChild("BillboardAttachment")
	if attachment and attachment:IsA("Attachment") then
		attachment.Position = Vector3.new(0, primaryPart.Size.Y * 0.5 + 0.5, 0)
	end
end

function PlotBrainrotVisuals.ApplyScaleAndPosition(brainrotModel: Model, slotModel: Model, level: number)
	local scale = Shared_Brainrots.GetScaleForLevel(level)
	brainrotModel:ScaleTo(scale)

	local pivot = getStandingPivot(slotModel, brainrotModel)
	if pivot then
		brainrotModel:PivotTo(pivot)
	end

	updateBillboardAttachment(brainrotModel)
end

function PlotBrainrotVisuals.SetupBillboard(
	brainrotModel: Model,
	configName: string,
	modifier: string?,
	level: number?
)
	Shared_BrainrotBillboard.Setup(brainrotModel, configName, modifier, level)
end

function PlotBrainrotVisuals.UpdateBillboardIncome(
	brainrotModel: Model,
	configName: string,
	modifier: string?,
	level: number?
)
	Shared_BrainrotBillboard.UpdateIncome(brainrotModel, configName, modifier, level)
end

function PlotBrainrotVisuals.ClearSlot(slotModel: Model)
	local existing = slotModel:FindFirstChild("PlacedBrainrot")
	if existing and existing:IsA("Model") then
		existing:Destroy()
	end
end

function PlotBrainrotVisuals.SetupPickupPrompt(
	brainrotModel: Model,
	onPickup: (Player) -> ()
)
	local primary = brainrotModel.PrimaryPart
	if not primary then
		return
	end

	local attachment = primary:FindFirstChild("PickupAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		attachment = Instance.new("Attachment")
		attachment.Name = "PickupAttachment"
		attachment.Parent = primary
	end

	local prompt = Shared_ProximityPrompt.Create(attachment, {
		Preset = "PickUp",
	})

	prompt.Triggered:Connect(onPickup)
end

function PlotBrainrotVisuals.PlaceOnSlot(
	slotModel: Model,
	configName: string,
	modifier: string?,
	level: number?,
	onPickup: ((Player) -> ())?
)
	PlotBrainrotVisuals.ClearSlot(slotModel)

	local template = getBrainrotTemplate(configName, modifier or "Normal")
	if not template then
		warn(("Missing brainrot model %s/%s"):format(configName, modifier or "Normal"))
		return nil
	end

	local brainrotModel = template:Clone()
	brainrotModel.Name = "PlacedBrainrot"

	if not brainrotModel.PrimaryPart then
		brainrotModel.PrimaryPart = brainrotModel:FindFirstChildWhichIsA("BasePart", true)
	end

	for _, part in brainrotModel:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end

	brainrotModel:SetAttribute("ConfigName", configName)
	brainrotModel.Parent = slotModel

	PlotBrainrotVisuals.ApplyScaleAndPosition(brainrotModel, slotModel, level or 1)
	PlotBrainrotVisuals.SetupBillboard(brainrotModel, configName, modifier, level)

	if onPickup then
		PlotBrainrotVisuals.SetupPickupPrompt(brainrotModel, onPickup)
	end

	return brainrotModel
end

return PlotBrainrotVisuals
