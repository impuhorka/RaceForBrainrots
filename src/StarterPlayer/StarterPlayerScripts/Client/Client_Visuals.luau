local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client_Data = require(script.Parent.Client_Data)
local Shared_Abbreviation = require(ReplicatedStorage.Modules.Utilities.Shared_Abbreviation)

local Client_Visuals = {}

local STAT_NAMES = { "Cash", "Strength", "Speed" }

local labels: { [string]: TextLabel } = {}

local function formatCash(value: number): string
	return ("$%s"):format(Shared_Abbreviation:Number(value or 0))
end

local function formatStrength(value: number): string
	return ("%s Strength"):format(Shared_Abbreviation:Number(value or 0))
end

local function formatSpeed(value: number): string
	return ("%s Speed"):format(Shared_Abbreviation:Number(value or 0))
end

local FORMATTERS = {
	Cash = formatCash,
	Strength = formatStrength,
	Speed = formatSpeed,
}

local function updateStat(statName: string)
	local label = labels[statName]
	local formatter = FORMATTERS[statName]
	if not label or not formatter then
		return
	end

	label.Text = formatter(Client_Data:GetValue(statName) or 0)
end

local function refreshAll()
	for _, statName in STAT_NAMES do
		updateStat(statName)
	end
end

function Client_Visuals.Init()
	Client_Data.WaitUntilReady()

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local visualsFrame = playerGui:WaitForChild("Main"):WaitForChild("Visuals")

	for _, statName in STAT_NAMES do
		local frame = visualsFrame:FindFirstChild(statName)
		if frame then
			local textLabel = frame:FindFirstChild("TextLabel")
			if textLabel and textLabel:IsA("TextLabel") then
				labels[statName] = textLabel
			else
				warn(("Client_Visuals: missing TextLabel in Visuals.%s"):format(statName))
			end
		else
			warn(("Client_Visuals: missing frame Visuals.%s"):format(statName))
		end
	end

	refreshAll()

	for _, statName in STAT_NAMES do
		Client_Data:ListenToChange(statName, function()
			updateStat(statName)
		end)
	end
end

return Client_Visuals
