local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared_Abbreviation = require(script.Parent.Utilities.Shared_Abbreviation)
local Shared_Brainrots = require(script.Parent.Shared_Brainrots)
local Shared_Modifiers = require(script.Parent.Utilities.Shared_Modifiers)
local Shared_Rarities = require(script.Parent.Utilities.Shared_Rarities)
local Shared_Weight = require(script.Parent.Shared_Weight)

local Shared_BrainrotBillboard = {}

local function getBillboardAttachmentYOffset(primaryPart: BasePart): number
	return primaryPart.Size.Y * 0.5 + 0.5
end

local function setFrameTextLabel(billboard: Instance, frameName: string, text: string)
	local frame = billboard:FindFirstChild(frameName, true)
	if not frame then
		return
	end

	if frame:IsA("TextLabel") then
		frame.Text = text
		return
	end

	local textLabel = frame:FindFirstChild("TextLabel")
	if textLabel and textLabel:IsA("TextLabel") then
		textLabel.Text = text
	end
end

local function getFrameTextLabel(billboard: Instance, frameName: string): TextLabel?
	local frame = billboard:FindFirstChild(frameName, true)
	if not frame then
		return nil
	end

	if frame:IsA("TextLabel") then
		return frame
	end

	local direct = frame:FindFirstChild("TextLabel")
	if direct and direct:IsA("TextLabel") then
		return direct
	end

	local nested = frame:FindFirstChildWhichIsA("TextLabel", true)
	if nested and nested:IsA("TextLabel") then
		return nested
	end

	return nil
end

local function setFrameVisible(billboard: Instance, frameName: string, visible: boolean)
	local frame = billboard:FindFirstChild(frameName, true)
	if frame and frame:IsA("GuiObject") then
		frame.Visible = visible
	end
end

local function applyTextLabelGradient(textLabel: TextLabel, colorGradient: ColorSequence, rotation: number)
	local gradient = textLabel:FindFirstChildOfClass("UIGradient")
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Parent = textLabel
	end

	gradient.Color = colorGradient
	gradient.Rotation = rotation
	gradient.Enabled = true
end

function Shared_BrainrotBillboard.Setup(
	brainrotModel: Model,
	configName: string,
	modifier: string?,
	level: number?,
	baseWeight: number?,
	rolledWeight: number?
)
	local config = Shared_Brainrots.Data[configName]
	if not config or not brainrotModel.PrimaryPart then
		return
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local billboards = assets and assets:FindFirstChild("Billboards")
	local billboardTemplate = billboards and billboards:FindFirstChild("BrainrotBillboard")
	if not billboardTemplate then
		warn("Missing ReplicatedStorage.Assets.Billboards.BrainrotBillboard")
		return
	end

	local primaryPart = brainrotModel.PrimaryPart

	local existingAttachment = primaryPart:FindFirstChild("BillboardAttachment")
	if existingAttachment then
		existingAttachment:Destroy()
	end

	local billboardAttachment = Instance.new("Attachment")
	billboardAttachment.Name = "BillboardAttachment"
	billboardAttachment.Position = Vector3.new(0, getBillboardAttachmentYOffset(primaryPart), 0)
	billboardAttachment.Parent = primaryPart

	local billboard = billboardTemplate:Clone()
	billboard.Parent = billboardAttachment

	setFrameTextLabel(billboard, "DisplayName", Shared_Brainrots.GetDisplayName(configName))

	local resolvedModifier = modifier or "Normal"
	local resolvedLevel = math.max(1, level or 1)
	local resolvedBaseWeight, resolvedRolledWeight =
		Shared_Weight.ResolveBrainrotWeights({ BaseWeight = baseWeight, Weight = rolledWeight }, configName)
	local income = Shared_Brainrots.GetCashPerSecond(
		configName,
		resolvedLevel,
		resolvedModifier,
		resolvedBaseWeight,
		resolvedRolledWeight
	)
	setFrameTextLabel(billboard, "Income", ("$%s/s"):format(Shared_Abbreviation:Number(income)))
	setFrameTextLabel(billboard, "Weight", Shared_Weight.FormatKg(resolvedRolledWeight))
	setFrameVisible(billboard, "Weight", true)

	local modifierFrame = billboard:FindFirstChild("Modifier", true)
	if modifierFrame then
		local hasModifier = resolvedModifier ~= "" and resolvedModifier ~= "Normal"
		setFrameVisible(billboard, "Modifier", hasModifier)

		if hasModifier then
			local modifierConfig = Shared_Modifiers.Data[resolvedModifier]
			local modifierLabel = getFrameTextLabel(billboard, "Modifier")
			if modifierLabel and modifierConfig then
				modifierLabel.Text = modifierConfig.DisplayName or resolvedModifier
				if modifierConfig.ColorGradient then
					applyTextLabelGradient(
						modifierLabel,
						modifierConfig.ColorGradient,
						modifierConfig.GradientRotation or 90
					)
				end
			end
		end
	end

	local rarityConfig = Shared_Rarities.Data[config.Rarity]
	local rarityFrame = billboard:FindFirstChild("Rarity", true)
	if rarityFrame then
		setFrameVisible(billboard, "Rarity", true)

		local rarityLabel = getFrameTextLabel(billboard, "Rarity")
		if rarityLabel and rarityConfig then
			rarityLabel.Text = rarityConfig.DisplayName or config.Rarity
			if rarityConfig.ColorGradient then
				applyTextLabelGradient(
					rarityLabel,
					rarityConfig.ColorGradient,
					rarityConfig.GradientRotation or 90
				)
			end
		end
	end
end

function Shared_BrainrotBillboard.UpdateIncome(
	brainrotModel: Model,
	configName: string,
	modifier: string?,
	level: number?,
	baseWeight: number?,
	rolledWeight: number?
)
	if not brainrotModel.PrimaryPart then
		return
	end

	local attachment = brainrotModel.PrimaryPart:FindFirstChild("BillboardAttachment")
	if not attachment then
		return
	end

	local billboard = attachment:FindFirstChildWhichIsA("BillboardGui")
	if not billboard then
		return
	end

	local resolvedModifier = modifier or "Normal"
	local resolvedLevel = math.max(1, level or 1)
	local resolvedBaseWeight, resolvedRolledWeight =
		Shared_Weight.ResolveBrainrotWeights({ BaseWeight = baseWeight, Weight = rolledWeight }, configName)
	local income = Shared_Brainrots.GetCashPerSecond(
		configName,
		resolvedLevel,
		resolvedModifier,
		resolvedBaseWeight,
		resolvedRolledWeight
	)
	setFrameTextLabel(billboard, "Income", ("$%s/s"):format(Shared_Abbreviation:Number(income)))
	setFrameTextLabel(billboard, "Weight", Shared_Weight.FormatKg(resolvedRolledWeight))
end

return Shared_BrainrotBillboard
