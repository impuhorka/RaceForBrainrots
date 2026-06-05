local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer

local YOU_TEXT = "YOU"
local YOU_COLOR = Color3.fromRGB(255, 230, 0)
local OTHER_COLOR = Color3.fromRGB(255, 255, 255)

local YOU_SCALE_Y = 1.35

local Client_PlotBillboards = {}

local hookedPlots: { [Model]: boolean } = {}
local originalTextSizes: { [TextLabel]: UDim2 } = {}

local function getOwnerUserId(plotModel: Model): number
	local ownerUserId = plotModel:GetAttribute("OwnerUserId")
	return tonumber(ownerUserId) or 0
end

local function getBillboard(plotModel: Model): BillboardGui?
	local ownerPart = plotModel:FindFirstChild("OwnerPart", true)
	if not ownerPart or not ownerPart:IsA("BasePart") then
		return nil
	end

	local attachment = ownerPart:FindFirstChildOfClass("Attachment")
	if not attachment then
		return nil
	end

	local billboard = attachment:FindFirstChildOfClass("BillboardGui")
	if billboard then
		return billboard
	end

	return ownerPart:FindFirstChildWhichIsA("BillboardGui", true)
end

local function getBillboardLabels(billboard: BillboardGui): (ImageLabel?, TextLabel?)
	local root = billboard:FindFirstChild("Frame", true)
	if not root or not root:IsA("GuiObject") then
		root = billboard
	end

	local imageLabel = root:FindFirstChildWhichIsA("ImageLabel", true)
	local textLabel = root:FindFirstChildWhichIsA("TextLabel", true)

	return imageLabel, textLabel
end

local function getOriginalTextSize(textLabel: TextLabel): UDim2
	local original = originalTextSizes[textLabel]
	if original then
		return original
	end

	original = textLabel.Size
	originalTextSizes[textLabel] = original
	return original
end

local function applyTextSize(textLabel: TextLabel, isYou: boolean)
	local original = getOriginalTextSize(textLabel)

	if isYou then
		textLabel.Size = UDim2.new(
			original.X.Scale,
			original.X.Offset,
			original.Y.Scale * YOU_SCALE_Y,
			original.Y.Offset * YOU_SCALE_Y
		)
	else
		textLabel.Size = original
	end
end

local function applyAvatar(imageLabel: ImageLabel, userId: number)
	task.spawn(function()
		local ok, thumb = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		if ok and thumb and imageLabel.Parent then
			imageLabel.Image = thumb
		end
	end)
end

local function updatePlotBillboard(plotModel: Model)
	local billboard = getBillboard(plotModel)
	if not billboard or not billboard.Enabled then
		return
	end

	local imageLabel, textLabel = getBillboardLabels(billboard)
	if not textLabel then
		return
	end

	local ownerUserId = getOwnerUserId(plotModel)
	local ownerName = plotModel:GetAttribute("OwnerName")

	if ownerUserId <= 0 then
		textLabel.Text = ""
		textLabel.TextColor3 = OTHER_COLOR
		applyTextSize(textLabel, false)
		if imageLabel then
			imageLabel.Image = ""
		end
		return
	end

	local isYou = ownerUserId == localPlayer.UserId

	if isYou then
		textLabel.Text = YOU_TEXT
		textLabel.TextColor3 = YOU_COLOR
	else
		local displayName = if type(ownerName) == "string" and ownerName ~= "" then ownerName else ("Player" .. tostring(ownerUserId))
		textLabel.Text = displayName
		textLabel.TextColor3 = OTHER_COLOR
	end

	applyTextSize(textLabel, isYou)

	if imageLabel then
		applyAvatar(imageLabel, ownerUserId)
	end
end

local function refreshAll()
	local gameFolder = Workspace:FindFirstChild("Game")
	local plotsFolder = gameFolder and gameFolder:FindFirstChild("Plots")
	if not plotsFolder then
		return
	end

	for _, child in plotsFolder:GetChildren() do
		if child:IsA("Model") then
			updatePlotBillboard(child)
		end
	end
end

local function hookPlot(plotModel: Model)
	if hookedPlots[plotModel] then
		return
	end
	hookedPlots[plotModel] = true

	local function refresh()
		updatePlotBillboard(plotModel)
	end

	refresh()
	task.defer(refresh)

	plotModel:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
	plotModel:GetAttributeChangedSignal("OwnerName"):Connect(refresh)

	local billboard = getBillboard(plotModel)
	if billboard then
		billboard:GetPropertyChangedSignal("Enabled"):Connect(refresh)

		local _, textLabel = getBillboardLabels(billboard)
		if textLabel then
			textLabel:GetPropertyChangedSignal("Text"):Connect(function()
				updatePlotBillboard(plotModel)
			end)
		end
	end

	plotModel.DescendantAdded:Connect(refresh)
end

function Client_PlotBillboards:Init()
	local gameFolder = Workspace:WaitForChild("Game")
	local plotsFolder = gameFolder:WaitForChild("Plots")

	for _, child in plotsFolder:GetChildren() do
		if child:IsA("Model") then
			hookPlot(child)
		end
	end

	plotsFolder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			hookPlot(child)
		end
	end)

	task.spawn(function()
		for _ = 1, 30 do
			refreshAll()
			task.wait(0.25)
		end
	end)
end

return Client_PlotBillboards
