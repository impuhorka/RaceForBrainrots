local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local ClientLoader = require(script.Parent.Parent.Loader)

local Shared_Brainrots = SharedModules.require("Shared_Brainrots")
local Shared_Modifiers = SharedModules.require("Shared_Modifiers")
local Shared_Rarities = SharedModules.require("Shared_Rarities")
local Client_Data = ClientLoader.require("Client_Data")
local Client_ItemDisplay = ClientLoader.require("Client_ItemDisplay")

local Client_Index = {}

local currentModifier = "Normal"
local cardsByConfig: { [string]: GuiObject } = {}
local modifierButtons: { [string]: ImageButton } = {}
local entriesCache = {}
local indexFrameRef: GuiObject? = nil

local function getBrainrotEntries()
	local entries = {}
	for configName, brainrotData in Shared_Brainrots.Data do
		local rarityName = brainrotData.Rarity
		local rarityData = Shared_Rarities.Data[rarityName]
		table.insert(entries, {
			ConfigName = configName,
			DisplayName = Shared_Brainrots.GetDisplayName(configName),
			RarityName = rarityName,
			RarityData = rarityData,
		})
	end

	table.sort(entries, function(a, b)
		local aOrder = (a.RarityData and a.RarityData.LayoutOrder) or math.huge
		local bOrder = (b.RarityData and b.RarityData.LayoutOrder) or math.huge
		if aOrder == bOrder then
			return a.DisplayName < b.DisplayName
		end
		return aOrder < bOrder
	end)

	return entries
end

local function sortedModifierEntries()
	local entries = {}
	for modifierName, modifierData in Shared_Modifiers.Data do
		table.insert(entries, {
			Name = modifierName,
			Data = modifierData,
		})
	end

	table.sort(entries, function(a, b)
		local aOrder = a.Data.LayoutOrder or math.huge
		local bOrder = b.Data.LayoutOrder or math.huge
		if aOrder == bOrder then
			return a.Name < b.Name
		end
		return aOrder < bOrder
	end)

	return entries
end

local function getIndexScrollingFrame(indexFrame: GuiObject): ScrollingFrame?
	local direct = indexFrame:FindFirstChild("ScrollingFrame")
	if direct and direct:IsA("ScrollingFrame") then
		return direct
	end

	for _, child in indexFrame:GetChildren() do
		if child:IsA("ScrollingFrame") then
			return child
		end
	end

	return nil
end

local function getModifiersScrollingFrame(indexFrame: GuiObject): ScrollingFrame?
	local modifiersRoot = indexFrame:FindFirstChild("Modifiers")
	if not modifiersRoot then
		return nil
	end

	if modifiersRoot:IsA("ScrollingFrame") then
		return modifiersRoot
	end

	local nested = modifiersRoot:FindFirstChild("ScrollingFrame")
	if nested and nested:IsA("ScrollingFrame") then
		return nested
	end

	return nil
end

local function applyGradient(target: Instance?, colorGradient: ColorSequence?, rotation: number?)
	if not target or not colorGradient then
		return
	end

	local gradient = target:FindFirstChildOfClass("UIGradient")
	if not gradient then
		return
	end

	gradient.Color = colorGradient
	gradient.Rotation = rotation or 0
	gradient.Enabled = true
end

local function setGradientEnabled(target: Instance?, enabled: boolean)
	if not target then
		return
	end
	local gradient = target:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Enabled = enabled
	end
end

local function blackOutViewportModel(viewportFrame: ViewportFrame)
	local worldModel = viewportFrame:FindFirstChildOfClass("WorldModel")
	if not worldModel then
		return
	end

	for _, descendant in worldModel:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Color = Color3.new(0, 0, 0)
			descendant.Material = Enum.Material.SmoothPlastic
			descendant.Reflectance = 0
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = 1
		end
	end
end

local function setMysteryViewport(viewportFrame: ViewportFrame, configName: string)
	Client_ItemDisplay.setupViewport(viewportFrame, configName, "Normal", false)
	viewportFrame.Ambient = Color3.new(0, 0, 0)
	viewportFrame.LightColor = Color3.new(0, 0, 0)
	blackOutViewportModel(viewportFrame)
end

local function isIndexed(indexData: any, modifier: string, configName: string): boolean
	if type(indexData) ~= "table" then
		return false
	end

	local modifierEntries = indexData[modifier]
	if type(modifierEntries) ~= "table" then
		return false
	end

	for _, indexedConfig in modifierEntries do
		if indexedConfig == configName then
			return true
		end
	end

	return false
end

local function setModifierButtonSelected(button: ImageButton, selected: boolean)
	local stroke = button:FindFirstChild("WhiteStroke")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Transparency = if selected then 0 else 1
	end
end

local function refreshModifierSelection()
	for modifierName, button in modifierButtons do
		setModifierButtonSelected(button, modifierName == currentModifier)
	end
end

local function renderCards()
	local indexData = Client_Data:GetValue("Index") or {}
	local indexVisible = indexFrameRef ~= nil and indexFrameRef.Visible

	for _, entry in entriesCache do
		local clone = cardsByConfig[entry.ConfigName]
		if not clone then
			continue
		end

		local frame = clone:FindFirstChild("Frame")
		if not frame or not frame:IsA("GuiObject") then
			continue
		end

		local discovered = isIndexed(indexData, currentModifier, entry.ConfigName)
		local wasDiscovered = clone:GetAttribute("_WasDiscovered") == true
		clone:SetAttribute("_WasDiscovered", discovered)

		local viewportFrame = frame:FindFirstChild("ViewportFrame")
		if viewportFrame and viewportFrame:IsA("ViewportFrame") then
			if discovered then
				Client_ItemDisplay.setupViewport(viewportFrame, entry.ConfigName, currentModifier, false)
				viewportFrame.Ambient = Color3.fromRGB(200, 200, 200)
				viewportFrame.LightColor = Color3.fromRGB(255, 255, 255)
				Client_ItemDisplay.setViewportIdlePlaying(viewportFrame, entry.ConfigName, indexVisible)
			else
				Client_ItemDisplay.setViewportIdlePlaying(viewportFrame, entry.ConfigName, false)
				setMysteryViewport(viewportFrame, entry.ConfigName)
			end
		end

		local displayNameLabel = frame:FindFirstChild("DisplayName")
		if displayNameLabel and displayNameLabel:IsA("TextLabel") then
			displayNameLabel.Text = if discovered then entry.DisplayName else "???"
		end

		local rarityLabel = frame:FindFirstChild("Rarity")
		if rarityLabel and rarityLabel:IsA("TextLabel") then
			rarityLabel.Text = if discovered then ((entry.RarityData and entry.RarityData.DisplayName) or entry.RarityName or "Unknown") else "???"
			if discovered then
				applyGradient(
					rarityLabel,
					entry.RarityData and entry.RarityData.ColorGradient,
					entry.RarityData and entry.RarityData.GradientRotation
				)
			else
				setGradientEnabled(rarityLabel, false)
			end
		end
	end
end

function Client_Index.Init()
	Client_Data.WaitUntilReady()

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local main = playerGui:WaitForChild("Main")
	local frames = main:WaitForChild("Frames")
	local indexFrame = frames:FindFirstChild("Index")
	if not indexFrame or not indexFrame:IsA("GuiObject") then
		warn("Client_Index: missing Frames.Index")
		return
	end
	indexFrameRef = indexFrame

	local scrollingFrame = getIndexScrollingFrame(indexFrame)
	if not scrollingFrame then
		warn("Client_Index: missing Index.ScrollingFrame")
		return
	end

	local template = scrollingFrame:FindFirstChild("Template")
	if not template or not template:IsA("GuiObject") then
		warn("Client_Index: missing index template")
		return
	end
	template.Visible = false

	for _, child in scrollingFrame:GetChildren() do
		if child ~= template and child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	entriesCache = getBrainrotEntries()
	table.clear(cardsByConfig)
	for index, entry in entriesCache do
		local clone = template:Clone()
		clone.Name = entry.ConfigName
		clone.LayoutOrder = index
		clone.Visible = true
		clone:SetAttribute("_WasDiscovered", false)

		local frame = clone:FindFirstChild("Frame")
		if frame and frame:IsA("GuiObject") then
			local imageLabel = frame:FindFirstChild("ImageLabel")
			applyGradient(
				imageLabel,
				entry.RarityData and entry.RarityData.ColorGradient,
				entry.RarityData and entry.RarityData.GradientRotation
			)
		end

		clone.Parent = scrollingFrame
		cardsByConfig[entry.ConfigName] = clone
	end

	local modifiersScrollingFrame = getModifiersScrollingFrame(indexFrame)
	if modifiersScrollingFrame then
		local modifiersTemplate = modifiersScrollingFrame:FindFirstChild("Template")
		if modifiersTemplate and modifiersTemplate:IsA("GuiObject") then
			for _, child in modifiersScrollingFrame:GetChildren() do
				if child ~= modifiersTemplate and child:IsA("GuiObject") then
					child:Destroy()
				end
			end
			modifiersTemplate.Visible = false
			table.clear(modifierButtons)

			for _, modifierEntry in sortedModifierEntries() do
				local clone = modifiersTemplate:Clone()
				clone.Name = modifierEntry.Name
				clone.LayoutOrder = modifierEntry.Data.LayoutOrder or 0
				clone.Visible = true

				local button = clone:FindFirstChild("ImageButton")
				if button and button:IsA("ImageButton") then
					local modifierText = button:FindFirstChild("Modifier")
					if modifierText and modifierText:IsA("TextLabel") then
						modifierText.Text = modifierEntry.Data.DisplayName or modifierEntry.Name
					end
					applyGradient(button, modifierEntry.Data.ColorGradient, modifierEntry.Data.GradientRotation)
					setModifierButtonSelected(button, modifierEntry.Name == currentModifier)
					modifierButtons[modifierEntry.Name] = button

					button.MouseButton1Click:Connect(function()
						if currentModifier == modifierEntry.Name then
							return
						end
						currentModifier = modifierEntry.Name
						refreshModifierSelection()
						renderCards()
					end)
				end

				clone.Parent = modifiersScrollingFrame
			end
		end
	end

	refreshModifierSelection()
	renderCards()
	Client_Data:ListenToChange("Index", renderCards)
	indexFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		renderCards()
	end)
end

return Client_Index