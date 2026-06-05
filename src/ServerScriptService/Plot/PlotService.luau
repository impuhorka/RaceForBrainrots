local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Plot = require(script.Parent.Plot)
local PlotConfig = require(script.Parent.PlotConfig)
local PlotCash = require(script.Parent.PlotCash)
local PlotPlacement = require(script.Parent.PlotPlacement)
local Server_Data = require(ServerScriptService.Core.Server_Data)

local function getPlayerSlotCount(player: Player): number
	return Server_Data:GetValue(player, "TotalPlotSlots") or PlotConfig.DefaultPlotSlots
end

local PlotService = {}
PlotService.__index = PlotService

function PlotService.new()
	local self = setmetatable({}, PlotService)
	self.Plots = {}
	self.PlayerToPlot = {}
	return self
end

function PlotService:LoadPlots()
	local gameFolder = Workspace:WaitForChild("Game")
	local plotsFolder = gameFolder:WaitForChild("Plots")

	local plotModels = plotsFolder:GetChildren()
	table.sort(plotModels, function(a, b)
		return a.Name < b.Name
	end)

	for _, child in plotModels do
		if child:IsA("Model") then
			local plot = Plot.new(child)
			table.insert(self.Plots, plot)
		end
	end
end

function PlotService:GetPlotByPlayer(player: Player)
	return self.PlayerToPlot[player]
end

function PlotService:GetAvailablePlot()
	for _, plot in self.Plots do
		if plot:IsAvailable() then
			return plot
		end
	end
	return nil
end

function PlotService:TeleportPlayerToPlot(player: Player)
	local plot = self:GetPlotByPlayer(player)
	if not plot then
		return
	end
	plot:TeleportPlayer(player)
end

function PlotService:AttachPlayer(player: Player)
	if self.PlayerToPlot[player] then
		return
	end

	local plot = self:GetAvailablePlot()
	if not plot then
		warn(("No free plots for %s"):format(player.Name))
		return
	end

	plot:Assign(player, getPlayerSlotCount(player))
	self.PlayerToPlot[player] = plot

	task.spawn(function()
		while not Server_Data:GetProfile(player) do
			if player.Parent ~= Players then
				return
			end
			task.wait(0.1)
		end
		PlotPlacement.LoadPlotData(plot, Server_Data:GetValue(player, "Plot") or {})
	end)

	player.CharacterAdded:Connect(function(character)
		local currentPlot = self:GetPlotByPlayer(player)
		if not currentPlot then
			return
		end
		task.defer(function()
			currentPlot:TeleportCharacter(character)
		end)
	end)

	self:TeleportPlayerToPlot(player)
end

function PlotService:DetachPlayer(player: Player)
	local plot = self.PlayerToPlot[player]
	if not plot then
		return
	end

	PlotCash.SyncPlotCashToData(player, plot)
	plot:Release()
	self.PlayerToPlot[player] = nil
end

function PlotService:GetSlotCount(player: Player): number
	local plot = self:GetPlotByPlayer(player)
	if not plot then
		return 0
	end
	return plot:GetSlotCount()
end

function PlotService:AddSlot(player: Player): Model?
	local plot = self:GetPlotByPlayer(player)
	if not plot then
		return nil
	end
	return plot:AddSlot()
end

function PlotService:RemoveSlot(player: Player, slotId: number): boolean
	local plot = self:GetPlotByPlayer(player)
	if not plot then
		return false
	end
	return plot:RemoveSlot(slotId)
end

function PlotService:Init()
	self:LoadPlots()

	local plotHandler = ReplicatedStorage:WaitForChild("Events"):WaitForChild("PlotHandler") :: RemoteEvent
	plotHandler.OnServerEvent:Connect(function(player: Player, action: string, slotId: any, inventoryIndex: any)
		if action == "Place" then
			if type(slotId) ~= "number" or type(inventoryIndex) ~= "number" then
				return
			end

			local plot = self:GetPlotByPlayer(player)
			PlotPlacement.PlaceBrainrot(player, plot, slotId, inventoryIndex)
			return
		end

		if action == "Collect" then
			if type(slotId) ~= "number" then
				return
			end

			local plot = self:GetPlotByPlayer(player)
			PlotCash.Collect(player, plot, slotId)
			return
		end

		if action == "Upgrade" then
			if type(slotId) ~= "number" then
				return
			end

			local plot = self:GetPlotByPlayer(player)
			PlotPlacement.UpgradeBrainrot(player, plot, slotId)
		end
	end)

	PlotCash.StartGenerationLoop(function()
		return self.Plots
	end)

	for _, player in Players:GetPlayers() do
		self:AttachPlayer(player)
	end

	Players.PlayerAdded:Connect(function(player)
		self:AttachPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:DetachPlayer(player)
	end)
end

return PlotService
