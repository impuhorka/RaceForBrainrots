local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared_LuckyBlocks = require(script.Parent.Shared_LuckyBlocks)
local Shared_Rarities = require(script.Parent.Shared_Rarities)
local Shared_Weight = require(script.Parent.Shared_Weight)

local Shared_LuckyBlockBillboard = {}

local DESPAWN_TIME_FORMAT = "%d seconds"

local function getBaseBillboardAttachmentYOffset(primaryPart: BasePart): number
	return primaryPart.Size.Y * 0.5 + 0.5
end

local function getBillboardAttachmentYOffset(primaryPart: BasePart, configName: string): number
	return getBaseBillboardAttachmentYOffset(primaryPart) + Shared_LuckyBlocks.GetBillboardYOffsetAdd(configName)
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

	return frame:FindFirstChildWhichIsA("TextLabel", true)
end

local function setFrameVisible(billboard: Instance, frameName: string, visible: boolean)
	local frame = billboard:FindFirstChild(frameName, true)
	if frame and frame:IsA("GuiObject") then
		frame.Visible = visible
	end
end

local function getBillboardFromModel(luckyBlockModel: Model): BillboardGui?
	local primaryPart = luckyBlockModel.PrimaryPart
	if not primaryPart then
		return nil
	end

	local attachment = primaryPart:FindFirstChild("BillboardAttachment")
	if not attachment then
		return nil
	end

	return attachment:FindFirstChildWhichIsA("BillboardGui")
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

local function scaleBillboardTextLabelsY(billboard: Instance, scale: number)
	for _, descendant in billboard:GetDescendants() do
		if not descendant:IsA("TextLabel") then
			continue
		end

		local size = descendant.Size
		descendant.Size = UDim2.new(
			size.X.Scale,
			size.X.Offset,
			size.Y.Scale * scale,
			math.floor(size.Y.Offset * scale + 0.5)
		)
	end
end

function Shared_LuckyBlockBillboard.Setup(
	luckyBlockModel: Model,
	configName: string,
	baseWeight: number?,
	weight: number?
)
	local config = Shared_LuckyBlocks.Data[configName]
	if not config or not luckyBlockModel.PrimaryPart then
		return
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local billboards = assets and assets:FindFirstChild("Billboards")
	local billboardTemplate = billboards and billboards:FindFirstChild("LuckyBlockBillboard")
	if not billboardTemplate then
		warn("Missing ReplicatedStorage.Assets.Billboards.LuckyBlockBillboard")
		return
	end

	local primaryPart = luckyBlockModel.PrimaryPart
	local existingAttachment = primaryPart:FindFirstChild("BillboardAttachment")
	if existingAttachment then
		existingAttachment:Destroy()
	end

	local billboardAttachment = Instance.new("Attachment")
	billboardAttachment.Name = "BillboardAttachment"
	billboardAttachment.Position = Vector3.new(0, getBillboardAttachmentYOffset(primaryPart, configName), 0)
	billboardAttachment.Parent = primaryPart

	local billboard = billboardTemplate:Clone()
	billboard.Parent = billboardAttachment

	local defaultBase = Shared_LuckyBlocks.GetBaseWeight(configName)
	local _, resolvedWeight = Shared_Weight.ResolveLuckyBlockWeights(
		{ BaseWeight = baseWeight, Weight = weight },
		defaultBase
	)
	setFrameTextLabel(billboard, "Weight", Shared_Weight.FormatKg(resolvedWeight))

	local displayStyle = config.DisplayStyle
	if type(displayStyle) == "table" then
		setFrameVisible(billboard, "Rarity", true)

		local rarityLabel = getFrameTextLabel(billboard, "Rarity")
		if rarityLabel then
			rarityLabel.Text = displayStyle.Label or config.DisplayName or configName
			if displayStyle.Color then
				rarityLabel.TextColor3 = displayStyle.Color
			end
			if displayStyle.ColorGradient then
				applyTextLabelGradient(
					rarityLabel,
					displayStyle.ColorGradient,
					displayStyle.GradientRotation or 90
				)
			end
		end
	elseif type(config.Rarity) == "string" then
		local rarityConfig = Shared_Rarities.Data[config.Rarity]
		if rarityConfig then
			setFrameVisible(billboard, "Rarity", true)

			local rarityLabel = getFrameTextLabel(billboard, "Rarity")
			if rarityLabel then
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

	local textScale = Shared_LuckyBlocks.GetBillboardTextScale(configName)
	if textScale then
		scaleBillboardTextLabelsY(billboard, textScale)
	end

	setFrameVisible(billboard, "DespawnTime", false)
end

function Shared_LuckyBlockBillboard.UpdateDespawnCountdown(luckyBlockModel: Model, seconds: number?)
	local billboard = getBillboardFromModel(luckyBlockModel)
	if not billboard then
		return
	end

	if type(seconds) == "number" and seconds > 0 then
		billboard.Enabled = true
		setFrameVisible(billboard, "DespawnTime", true)
		setFrameTextLabel(billboard, "DespawnTime", string.format(DESPAWN_TIME_FORMAT, seconds))
	else
		setFrameVisible(billboard, "DespawnTime", false)
	end
end

return Shared_LuckyBlockBillboard
