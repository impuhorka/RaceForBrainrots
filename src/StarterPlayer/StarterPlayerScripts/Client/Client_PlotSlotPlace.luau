local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared_ProximityPrompt = require(ReplicatedStorage.Modules.Shared_ProximityPrompt)

local Client_Data = require(script.Parent.Client_Data)
local Client_Equip = require(script.Parent.Client_Equip)
local Client_Hotbar = require(script.Parent.Client_Hotbar)
local Client_Inventory = require(script.Parent.Client_Inventory)
local Client_CashAddingPopups = require(script.Parent.Client_CashAddingPopups)
local Client_PlotBrainrotJump = require(script.Parent.Client_PlotBrainrotJump)

local localPlayer = Players.LocalPlayer

local Client_PlotSlotPlace = {}

local placePrompts: { [Model]: ProximityPrompt } = {}
local watchingSlots: { [Model]: boolean } = {}
local hookedPlots: { [Model]: boolean } = {}
local hookedSlotsFolders: { [Folder]: boolean } = {}

local function getOwnerUserId(plotModel: Model): number
	return tonumber(plotModel:GetAttribute("OwnerUserId")) or 0
end

local function getSlotId(slotModel: Model): number
	return tonumber(string.match(slotModel.Name, "%d+")) or 0
end

local function slotIsEmpty(slotModel: Model): boolean
	local configName = slotModel:GetAttribute("ConfigName")
	return type(configName) ~= "string" or configName == ""
end

local function hasEquippedBrainrot(): boolean
	local inventoryIndex = Client_Equip.GetEquippedIndex()
	if not inventoryIndex then
		return false
	end

	local inventory = Client_Data:GetValue("Inventory") or {}
	local item = inventory[inventoryIndex]
	return item ~= nil and item.ItemType == "Brainrot"
end

local function getStandingPart(slotModel: Model): BasePart?
	local standingPart = slotModel:FindFirstChild("StandingPart", true)
	if standingPart and standingPart:IsA("BasePart") then
		return standingPart
	end
	return nil
end

local function findOwnSlotModel(slotId: number): Model?
	local gameFolder = Workspace:FindFirstChild("Game")
	local plotsFolder = gameFolder and gameFolder:FindFirstChild("Plots")
	if not plotsFolder then
		return nil
	end

	for _, plotModel in plotsFolder:GetChildren() do
		if plotModel:IsA("Model") and getOwnerUserId(plotModel) == localPlayer.UserId then
			local slotsFolder = plotModel:FindFirstChild("Slots")
			if slotsFolder then
				local slotModel = slotsFolder:FindFirstChild("Slot" .. slotId)
				if slotModel and slotModel:IsA("Model") then
					return slotModel
				end
			end
		end
	end

	return nil
end

local function refreshAllPrompts()
	local equipped = hasEquippedBrainrot()
	for slotModel, prompt in placePrompts do
		if prompt.Parent then
			prompt.Enabled = equipped and slotIsEmpty(slotModel)
		else
			placePrompts[slotModel] = nil
		end
	end
end

local function setupPlacePrompt(slotModel: Model)
	if placePrompts[slotModel] then
		return
	end

	local standingPart = getStandingPart(slotModel)
	if not standingPart then
		if not watchingSlots[slotModel] then
			watchingSlots[slotModel] = true
			slotModel.DescendantAdded:Connect(function()
				if getStandingPart(slotModel) then
					setupPlacePrompt(slotModel)
				end
			end)
			slotModel.Destroying:Connect(function()
				watchingSlots[slotModel] = nil
			end)
		end
		return
	end

	local attachment = standingPart:FindFirstChild("Attachment")
	if not attachment or not attachment:IsA("Attachment") then
		attachment = Instance.new("Attachment")
		attachment.Parent = standingPart
	end

	local prompt = Shared_ProximityPrompt.Create(attachment, {
		Preset = "Place",
		Enabled = false,
	})

	placePrompts[slotModel] = prompt

	slotModel:GetAttributeChangedSignal("ConfigName"):Connect(refreshAllPrompts)
	slotModel.Destroying:Connect(function()
		placePrompts[slotModel] = nil
	end)

	prompt.Triggered:Connect(function()
		local inventoryIndex = Client_Equip.GetEquippedIndex()
		if not inventoryIndex or not slotIsEmpty(slotModel) then
			return
		end

		local inventory = Client_Data:GetValue("Inventory") or {}
		local item = inventory[inventoryIndex]
		if not item or item.ItemType ~= "Brainrot" then
			return
		end

		local slotId = getSlotId(slotModel)
		if slotId <= 0 then
			return
		end

		local events = ReplicatedStorage:WaitForChild("Events")
		local plotHandler = events:WaitForChild("PlotHandler") :: RemoteEvent
		plotHandler:FireServer("Place", slotId, inventoryIndex)
	end)

	refreshAllPrompts()
end

local function setupAllSlots(slotsFolder: Folder)
	for _, slotModel in slotsFolder:GetChildren() do
		if slotModel:IsA("Model") then
			setupPlacePrompt(slotModel)
		end
	end
end

local function hookSlotsFolder(slotsFolder: Folder)
	if not hookedSlotsFolders[slotsFolder] then
		hookedSlotsFolders[slotsFolder] = true

		slotsFolder.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				setupPlacePrompt(child)
			end
		end)
	end

	setupAllSlots(slotsFolder)
end

local function refreshPlot(plotModel: Model)
	if getOwnerUserId(plotModel) ~= localPlayer.UserId then
		return
	end

	local slotsFolder = plotModel:FindFirstChild("Slots")
	if slotsFolder and slotsFolder:IsA("Folder") then
		hookSlotsFolder(slotsFolder)
	end

	refreshAllPrompts()
end

local function hookPlot(plotModel: Model)
	if not hookedPlots[plotModel] then
		hookedPlots[plotModel] = true

		plotModel:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			refreshPlot(plotModel)
		end)

		plotModel.ChildAdded:Connect(function(child)
			if child.Name == "Slots" and child:IsA("Folder") then
				refreshPlot(plotModel)
			end
		end)
	end

	refreshPlot(plotModel)
end

local function refreshOwnPlot()
	local gameFolder = Workspace:FindFirstChild("Game")
	local plotsFolder = gameFolder and gameFolder:FindFirstChild("Plots")
	if not plotsFolder then
		return
	end

	for _, plotModel in plotsFolder:GetChildren() do
		if plotModel:IsA("Model") then
			hookPlot(plotModel)
		end
	end

	refreshAllPrompts()
end

function Client_PlotSlotPlace.Init()
	Client_Data.WaitUntilReady()

	Client_Equip.OnChanged(refreshAllPrompts)
	Client_Data:ListenToChange("Inventory", refreshAllPrompts)

	local events = ReplicatedStorage:WaitForChild("Events")
	local plotHandler = events:WaitForChild("PlotHandler") :: RemoteEvent

	plotHandler.OnClientEvent:Connect(function(action: string, payload: any, payload2: any)
		if action == "PlaceSuccess" then
			if type(payload) == "number" then
				task.defer(function()
					local slotModel = findOwnSlotModel(payload)
					if not slotModel then
						return
					end

					local brainrotModel = slotModel:WaitForChild("PlacedBrainrot", 2)
					if not brainrotModel or not brainrotModel:IsA("Model") then
						return
					end

					RunService.Heartbeat:Wait()
					if brainrotModel.Parent and slotModel.Parent then
						Client_PlotBrainrotJump.PlayPlace(brainrotModel, slotModel)
					end
				end)
			end
			Client_Equip.Unequip()
			Client_Hotbar.Refresh()
			Client_Inventory.Render()
		elseif action == "PickupSuccess" then
			Client_Hotbar.Refresh()
			Client_Inventory.Render()
			local collectedCash = tonumber(payload2) or 0
			if collectedCash > 0 then
				Client_CashAddingPopups.Show(collectedCash)
			end
		end
	end)

	local gameFolder = Workspace:WaitForChild("Game")
	local plotsFolder = gameFolder:WaitForChild("Plots")

	for _, plotModel in plotsFolder:GetChildren() do
		if plotModel:IsA("Model") then
			hookPlot(plotModel)
		end
	end

	plotsFolder.ChildAdded:Connect(function(plotModel)
		if plotModel:IsA("Model") then
			hookPlot(plotModel)
		end
	end)

	task.defer(refreshOwnPlot)
	task.delay(1, refreshOwnPlot)
end

return Client_PlotSlotPlace
