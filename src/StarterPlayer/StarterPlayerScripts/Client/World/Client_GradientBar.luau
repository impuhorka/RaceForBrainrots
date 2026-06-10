local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_RoadGradient = SharedModules.require("Shared_RoadGradient")

local Client_GradientBar = {}

local localPlayer = Players.LocalPlayer
local GENERATED_FOLDER_NAME = "GeneratedSegments"
local PLAYER_ICONS_FOLDER_NAME = "PlayerIcons"
local LEGACY_PLAYER_ICON_NAME = "PlayerIcon"
local END_CORNER_SCALE = 0.5
local DIVIDER_COLOR = Color3.fromRGB(0, 0, 0)
local PLAYER_ICON_HEIGHT_SCALE = 1.35
local LOCAL_PLAYER_ICON_ZINDEX = 50
local OTHER_PLAYER_ICON_ZINDEX = 40

local roadFrameRef: GuiObject?
local playerIconsFolder: Folder?
local playerIcons: { [Player]: ImageLabel } = {}
local roadNearZ = 0
local roadFarZ = 0
local roadBoundsReady = false
local updateConnection: RBXScriptConnection?

local function clearGenerated(roadFrame: GuiObject)
	local existing = roadFrame:FindFirstChild(GENERATED_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
end

local function setClipsDescendants(gui: GuiObject, enabled: boolean)
	if gui:IsA("Frame") or gui:IsA("ScrollingFrame") or gui:IsA("CanvasGroup") then
		gui.ClipsDescendants = enabled
		return
	end

	pcall(function()
		(gui :: any).ClipsDescendants = enabled
	end)
end

local function applyUICorner(gui: GuiObject)
	local corner = gui:FindFirstChildOfClass("UICorner")
	if not corner then
		corner = Instance.new("UICorner")
		corner.Parent = gui
	end
	corner.CornerRadius = UDim.new(END_CORNER_SCALE, 0)
end

local function applyPillMask(gui: GuiObject)
	applyUICorner(gui)
	setClipsDescendants(gui, true)
end

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function tryInitRoadBounds(): boolean
	local zones = Workspace:FindFirstChild("Zones")
	local enterPart = zones and zones:FindFirstChild("EnterPart")
	if not enterPart or not enterPart:IsA("BasePart") then
		return false
	end

	local totalLength = Shared_RoadGradient.GetRoadTotalLength()
	if totalLength <= 0 then
		return false
	end

	roadNearZ, roadFarZ = Shared_RoadGradient.GetRoadBounds(enterPart)
	roadBoundsReady = true
	return true
end

local function getPlayerIconZIndex(player: Player): number
	if player == localPlayer then
		return LOCAL_PLAYER_ICON_ZINDEX
	end
	return OTHER_PLAYER_ICON_ZINDEX
end

local function updatePlayerIconsSize()
	if not playerIconsFolder or not roadFrameRef then
		return
	end

	local roadHeight = roadFrameRef.AbsoluteSize.Y
	if roadHeight <= 0 then
		return
	end

	local iconSize = math.max(12, math.floor(roadHeight * PLAYER_ICON_HEIGHT_SCALE))
	for _, icon in playerIcons do
		icon.Size = UDim2.fromOffset(iconSize, iconSize)
	end
end

local function updatePlayerIconPosition(player: Player, icon: ImageLabel)
	if not roadBoundsReady then
		icon.Visible = false
		return
	end

	local root = getCharacterRoot(player)
	if not root then
		icon.Visible = false
		return
	end

	local playerZ = root.Position.Z
	if not Shared_RoadGradient.IsOnRoad(playerZ, roadNearZ, roadFarZ) then
		icon.Visible = false
		return
	end

	local roadAlpha = Shared_RoadGradient.GetRoadAlphaFromWorldZ(playerZ, roadNearZ, roadFarZ)
	local barScale = Shared_RoadGradient.GetBarScaleFromRoadAlpha(roadAlpha)

	icon.Visible = true
	icon.Position = UDim2.fromScale(barScale, 0.5)
	icon.ZIndex = getPlayerIconZIndex(player)
end

local function updateAllPlayerIcons()
	for player, icon in playerIcons do
		updatePlayerIconPosition(player, icon)
	end
end

local function loadPlayerThumbnail(player: Player, icon: ImageLabel)
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size48x48
			)
		end)
		if ok and icon.Parent then
			icon.Image = image
		end
	end)
end

local function ensurePlayerIconsFolder(roadFrame: GuiObject): Folder
	local existing = roadFrame:FindFirstChild(PLAYER_ICONS_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local legacyIcon = roadFrame:FindFirstChild(LEGACY_PLAYER_ICON_NAME)
	if legacyIcon then
		legacyIcon:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = PLAYER_ICONS_FOLDER_NAME
	folder.Parent = roadFrame
	return folder
end

local function ensurePlayerIcon(player: Player): ImageLabel
	local folder = playerIconsFolder
	if not folder then
		return nil :: any
	end

	local iconName = tostring(player.UserId)
	local existing = folder:FindFirstChild(iconName)
	if existing and existing:IsA("ImageLabel") then
		local stroke = existing:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke:Destroy()
		end
		existing.ZIndex = getPlayerIconZIndex(player)
		playerIcons[player] = existing
		return existing
	end

	local icon = Instance.new("ImageLabel")
	icon.Name = iconName
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0, 0.5)
	icon.Visible = false
	icon.ZIndex = getPlayerIconZIndex(player)
	icon.Parent = folder

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = icon

	playerIcons[player] = icon
	loadPlayerThumbnail(player, icon)
	return icon
end

local function removePlayerIcon(player: Player)
	local icon = playerIcons[player]
	if icon then
		icon:Destroy()
	end
	playerIcons[player] = nil
end

local function ensureAllPlayerIcons()
	if not playerIconsFolder then
		return
	end

	for _, player in Players:GetPlayers() do
		ensurePlayerIcon(player)
	end
end

local function startPlayerIconTracking(roadFrame: GuiObject)
	roadFrameRef = roadFrame
	playerIconsFolder = ensurePlayerIconsFolder(roadFrame)
	ensureAllPlayerIcons()

	if not tryInitRoadBounds() then
		task.spawn(function()
			local zones = Workspace:WaitForChild("Zones", 30)
			if not zones then
				return
			end
			zones:WaitForChild("EnterPart", 30)
			tryInitRoadBounds()
		end)
	end

	if updateConnection then
		updateConnection:Disconnect()
	end

	updateConnection = RunService.Heartbeat:Connect(function()
		if not roadBoundsReady then
			tryInitRoadBounds()
		end
		updatePlayerIconsSize()
		updateAllPlayerIcons()
	end)

	if not roadFrame:GetAttribute("_GradientBarSizeHook") then
		roadFrame:SetAttribute("_GradientBarSizeHook", true)
		roadFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updatePlayerIconsSize)
	end

	updatePlayerIconsSize()
	updateAllPlayerIcons()
end

local function applyRoadGradient(roadFrame: GuiObject)
	setClipsDescendants(roadFrame, false)
	applyUICorner(roadFrame)

	local segments = Shared_RoadGradient.GetSegments()
	if #segments == 0 then
		return
	end

	local templateGradient = roadFrame:FindFirstChildWhichIsA("UIGradient")
	if templateGradient then
		templateGradient.Enabled = false
	end

	clearGenerated(roadFrame)

	local container = Instance.new("Frame")
	container.Name = GENERATED_FOLDER_NAME
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Size = UDim2.fromScale(1, 1)
	container.Position = UDim2.fromScale(0, 0)
	container.ZIndex = roadFrame.ZIndex
	container.Parent = roadFrame
	applyPillMask(container)

	local dividerWidth = Shared_RoadGradient.GetHoleWidthScale()
	local dividerCount = math.max(0, #segments - 1)
	local reservedScale = dividerCount * dividerWidth
	local colorScale = math.max(0, 1 - reservedScale)

	local cursor = 0
	for index, segment in segments do
		local segmentWidth = segment.WidthScale * colorScale
		local segmentFrame = Instance.new("Frame")
		segmentFrame.Name = segment.Rarity
		segmentFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		segmentFrame.BorderSizePixel = 0
		segmentFrame.Size = UDim2.fromScale(segmentWidth, 1)
		segmentFrame.Position = UDim2.fromScale(cursor, 0)
		segmentFrame.ZIndex = container.ZIndex
		segmentFrame.Parent = container

		local uiGradient = Instance.new("UIGradient")
		uiGradient.Color = segment.ColorGradient
		uiGradient.Parent = segmentFrame

		cursor += segmentWidth

		if index < #segments then
			local divider = Instance.new("Frame")
			divider.Name = "Hole"
			divider.BackgroundColor3 = DIVIDER_COLOR
			divider.BorderSizePixel = 0
			divider.Size = UDim2.fromScale(dividerWidth, 1)
			divider.Position = UDim2.fromScale(cursor, 0)
			divider.ZIndex = container.ZIndex + 1
			divider.Parent = container

			cursor += dividerWidth
		end
	end

	startPlayerIconTracking(roadFrame)
end

function Client_GradientBar.Init()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local main = playerGui:WaitForChild("Main")
	local gradientBar = main:WaitForChild("GradientBar")
	local road = gradientBar:WaitForChild("Road")

	Players.PlayerAdded:Connect(function(player)
		ensurePlayerIcon(player)
	end)

	Players.PlayerRemoving:Connect(removePlayerIcon)

	if gradientBar:IsA("GuiObject") then
		applyUICorner(gradientBar)
	end

	if road:IsA("GuiObject") then
		applyRoadGradient(road)
	end
end

return Client_GradientBar
