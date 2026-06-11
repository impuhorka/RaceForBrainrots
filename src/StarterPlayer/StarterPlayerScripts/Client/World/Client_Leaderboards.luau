local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_Leaderboards = SharedModules.require("Shared_Leaderboards")

local Client_Leaderboards = {}

type BoardUi = {
	model: Model,
	scrollingFrame: ScrollingFrame,
	templates: { [number]: GuiObject },
	rows: { GuiObject },
}

local boards: { [string]: BoardUi } = {}
local lastSnapshot: { [string]: { any } }? = nil
local rowAttributeName = "LeaderboardRow"

local function findTextLabel(root: Instance, name: string): TextLabel?
	local direct = root:FindFirstChild(name)
	if direct and direct:IsA("TextLabel") then
		return direct
	end
	local nested = root:FindFirstChild(name, true)
	if nested and nested:IsA("TextLabel") then
		return nested
	end
	return nil
end

local function scrollingFrameHasRowTemplates(scrollingFrame: ScrollingFrame): boolean
	if findTextLabel(scrollingFrame, "NickName") and findTextLabel(scrollingFrame, "Data") then
		return true
	end

	for _, child in scrollingFrame:GetChildren() do
		if child:IsA("GuiObject") and findTextLabel(child, "NickName") and findTextLabel(child, "Data") then
			return true
		end
	end

	return false
end

local function getScrollingFrame(model: Model): ScrollingFrame?
	local surfaceGui = model:FindFirstChildWhichIsA("SurfaceGui", true)
	if surfaceGui then
		local frame = surfaceGui:FindFirstChild("Frame", true)
		if frame then
			local scrolling = frame:FindFirstChild("ScrollingFrame", true)
			if scrolling and scrolling:IsA("ScrollingFrame") then
				return scrolling
			end
		end

		for _, descendant in surfaceGui:GetDescendants() do
			if descendant:IsA("ScrollingFrame") then
				return descendant
			end
		end
	end

	local bestMatch: ScrollingFrame? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ScrollingFrame") and scrollingFrameHasRowTemplates(descendant) then
			return descendant
		end
		if descendant:IsA("ScrollingFrame") and not bestMatch then
			bestMatch = descendant
		end
	end

	return bestMatch
end

local function hideTemplate(template: GuiObject)
	template.Visible = false
end

local function findNamedTemplate(scrollingFrame: ScrollingFrame, place: number): GuiObject?
	local name = tostring(place)
	local direct = scrollingFrame:FindFirstChild(name)
	if direct and direct:IsA("GuiObject") then
		return direct
	end

	local nested = scrollingFrame:FindFirstChild(name, true)
	if nested and nested:IsA("GuiObject") and nested:GetAttribute(rowAttributeName) ~= true then
		return nested
	end

	return nil
end

local function collectTemplates(scrollingFrame: ScrollingFrame): { [number]: GuiObject }
	local templates: { [number]: GuiObject } = {}
	for place = 1, 4 do
		local template = findNamedTemplate(scrollingFrame, place)
		if template then
			templates[place] = template
			hideTemplate(template)
		end
	end

	if next(templates) then
		for _, template in templates do
			hideTemplate(template)
		end
		return templates
	end

	local fallback: { GuiObject } = {}
	for _, child in scrollingFrame:GetChildren() do
		if
			child:IsA("GuiObject")
			and child:GetAttribute(rowAttributeName) ~= true
			and findTextLabel(child, "NickName")
			and findTextLabel(child, "Data")
		then
			table.insert(fallback, child)
		end
	end

	table.sort(fallback, function(a, b)
		return (a.LayoutOrder or 0) < (b.LayoutOrder or 0)
	end)

	for index, template in fallback do
		if index <= 4 then
			templates[index] = template
			hideTemplate(template)
		end
	end

	return templates
end

local function clearRows(boardUi: BoardUi)
	for _, row in boardUi.rows do
		if row and row.Parent then
			row:Destroy()
		end
	end
	table.clear(boardUi.rows)
end

local function setRowLabels(row: GuiObject, entry: any)
	local nickLabel = findTextLabel(row, "NickName")
	local dataLabel = findTextLabel(row, "Data")
	local placeLabel = findTextLabel(row, "Place")

	if nickLabel then
		nickLabel.Text = tostring(entry.name or "Unknown")
	end
	if dataLabel then
		dataLabel.Text = tostring(entry.displayValue or "")
	end
	if placeLabel and type(entry.place) == "number" and entry.place >= 4 then
		placeLabel.Text = tostring(entry.place)
	end
end

local function renderBoard(boardId: string, entries: { any })
	local boardUi = boards[boardId]
	if not boardUi then
		return
	end

	clearRows(boardUi)

	for index, entry in entries do
		if index > Shared_Leaderboards.EntryCount then
			break
		end

		local place = if type(entry.place) == "number" then entry.place else index
		local templateIndex = math.clamp(place, 1, 4)
		local template = boardUi.templates[templateIndex]
		if not template then
			continue
		end

		local row = template:Clone()
		row.Name = `Row_{place}`
		row.Visible = true
		row:SetAttribute(rowAttributeName, true)
		row.Parent = boardUi.scrollingFrame
		setRowLabels(row, entry)
		table.insert(boardUi.rows, row)
	end
end

local pendingBoardConnections: { [string]: RBXScriptConnection } = {}

local function bindBoardModel(boardId: string, model: Model): boolean
	if boards[boardId] then
		return true
	end

	local scrollingFrame = getScrollingFrame(model)
	if not scrollingFrame then
		return false
	end

	local templates = collectTemplates(scrollingFrame)
	for _, template in templates do
		hideTemplate(template)
	end

	boards[boardId] = {
		model = model,
		scrollingFrame = scrollingFrame,
		templates = templates,
		rows = {},
	}

	local pendingConnection = pendingBoardConnections[boardId]
	if pendingConnection then
		pendingConnection:Disconnect()
		pendingBoardConnections[boardId] = nil
	end

	if lastSnapshot and lastSnapshot[boardId] then
		renderBoard(boardId, lastSnapshot[boardId])
	end

	return true
end

local function watchBoardModel(boardId: string, model: Model)
	if bindBoardModel(boardId, model) then
		return
	end

	local existingConnection = pendingBoardConnections[boardId]
	if existingConnection then
		existingConnection:Disconnect()
	end

	pendingBoardConnections[boardId] = model.DescendantAdded:Connect(function()
		bindBoardModel(boardId, model)
	end)

	task.defer(function()
		bindBoardModel(boardId, model)
	end)
end

local function bindLeaderboardsFolder(folder: Instance)
	for boardId, config in Shared_Leaderboards.BoardConfig do
		local model = folder:FindFirstChild(config.modelName)
		if model and model:IsA("Model") then
			watchBoardModel(boardId, model)
		else
			task.spawn(function()
				local resolved = folder:WaitForChild(config.modelName, 30)
				if resolved and resolved:IsA("Model") then
					watchBoardModel(boardId, resolved)
				else
					warn(`[Client_Leaderboards] Missing leaderboard model {config.modelName}`)
				end
			end)
		end
	end

	if lastSnapshot then
		Client_Leaderboards.ApplySnapshot(lastSnapshot)
	end
end

function Client_Leaderboards.ApplySnapshot(snapshot: { [string]: { any } })
	if type(snapshot) ~= "table" then
		return
	end

	lastSnapshot = snapshot

	for boardId, entries in snapshot do
		if type(entries) == "table" then
			renderBoard(boardId, entries)
		end
	end
end

function Client_Leaderboards.Init()
	local events = ReplicatedStorage:WaitForChild("Events", 15)
	local leaderboardHandler = events and events:WaitForChild("LeaderboardHandler", 15)
	if leaderboardHandler and leaderboardHandler:IsA("RemoteEvent") then
		leaderboardHandler.OnClientEvent:Connect(function(action: string, snapshot: any)
			if action == "Update" then
				Client_Leaderboards.ApplySnapshot(snapshot)
			end
		end)
	end

	local gameFolder = Workspace:WaitForChild("Game", 30)
	if not gameFolder then
		return
	end

	local leaderboardsFolder = gameFolder:WaitForChild("Leaderboards", 30)
	if leaderboardsFolder then
		bindLeaderboardsFolder(leaderboardsFolder)
	end
end

return Client_Leaderboards
