local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Server_Data = require(script.Parent.Server_Data)
local Shared_Brainrots = require(ReplicatedStorage.Modules.Shared_Brainrots)

local Server_Admin = {}

local COMMAND_PREFIX = "/"

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	return player.UserId == game.CreatorId
end

local function splitWords(text: string): { string }
	local words = {}
	for token in string.gmatch(text, "%S+") do
		table.insert(words, token)
	end
	return words
end

local function resolveBrainrotName(name: string): string?
	for configName in Shared_Brainrots.Data do
		if string.lower(configName) == string.lower(name) then
			return configName
		end
	end
	return nil
end

local function resolveTargetPlayer(actor: Player, rawTarget: string?): (Player?, string?)
	if not rawTarget then
		return nil, "Missing target player"
	end

	if string.lower(rawTarget) == "me" then
		return actor, nil
	end

	local exact = Players:FindFirstChild(rawTarget)
	if exact and exact:IsA("Player") then
		return exact, nil
	end

	local lowered = string.lower(rawTarget)
	for _, player in Players:GetPlayers() do
		if string.lower(player.Name) == lowered then
			return player, nil
		end
	end

	for _, player in Players:GetPlayers() do
		if string.find(string.lower(player.Name), lowered, 1, true) then
			return player, nil
		end
	end

	return nil, ("Player not found: %s"):format(rawTarget)
end

local function executeAddCash(actor: Player, args: { string }): string
	local target, targetError = resolveTargetPlayer(actor, args[1])
	if not target then
		return targetError or "Usage: /addcash [me|player] [amount]"
	end

	local amount = tonumber(args[2])
	if not amount then
		return "Usage: /addcash [me|player] [amount]"
	end

	local rounded = math.floor(amount)
	Server_Data:AddValue(target, "Cash", rounded)
	return ("Added $%d to %s"):format(rounded, target.Name)
end

local function executeAddBrainrot(actor: Player, args: { string }): string
	local target, targetError = resolveTargetPlayer(actor, args[1])
	if not target then
		return targetError or "Usage: /addbrainrot [me|player] [ConfigName] [Modifier=Normal] [Level=1]"
	end

	local rawConfigName = args[2]
	if not rawConfigName then
		return "Usage: /addbrainrot [me|player] [ConfigName] [Modifier=Normal] [Level=1]"
	end

	local configName = resolveBrainrotName(rawConfigName)
	if not configName then
		return ("Unknown brainrot: %s"):format(rawConfigName)
	end

	local modifier = args[3] or "Normal"
	local level = tonumber(args[4]) or 1
	level = math.max(1, math.floor(level))

	local newIndex = Server_Data:AddInventoryItem(target, {
		ItemType = "Brainrot",
		ConfigName = configName,
		Data = {
			Level = level,
			Modifier = modifier,
		},
	})

	if not newIndex then
		return "Failed to add brainrot"
	end

	return ("Added %s (%s L%d) to %s inventory slot %d"):format(configName, modifier, level, target.Name, newIndex)
end

local function executeHelp(): string
	return "Commands: /addcash [me|player] [amount], /addbrainrot [me|player] [ConfigName] [Modifier=Normal] [Level=1]"
end

local function handleCommand(player: Player, message: string)
	if not isAdmin(player) then
		return
	end

	if string.sub(message, 1, 1) ~= COMMAND_PREFIX then
		return
	end

	local parts = splitWords(message)
	if #parts == 0 then
		return
	end

	local command = string.lower(string.sub(parts[1], 2))
	table.remove(parts, 1)

	local result: string?
	if command == "addcash" then
		result = executeAddCash(player, parts)
	elseif command == "addbrainrot" then
		result = executeAddBrainrot(player, parts)
	elseif command == "adminhelp" then
		result = executeHelp()
	end

	if result then
		print(("[Admin][%s] %s"):format(player.Name, result))
	end
end

local function initTextChatCommands()
	local folder = TextChatService:FindFirstChild("TextChatCommands")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TextChatCommands"
		folder.Parent = TextChatService
	end

	local commands = {
		{ Name = "addcash", Alias = "/addcash" },
		{ Name = "addbrainrot", Alias = "/addbrainrot" },
		{ Name = "adminhelp", Alias = "/adminhelp" },
	}

	for _, info in commands do
		if folder:FindFirstChild(info.Name) then
			continue
		end

		local cmd = Instance.new("TextChatCommand")
		cmd.Name = info.Name
		cmd.PrimaryAlias = info.Alias
		cmd.Triggered:Connect(function(source, text)
			local player = Players:GetPlayerByUserId(source.UserId)
			if player then
				handleCommand(player, text)
			end
		end)
		cmd.Parent = folder
	end
end

function Server_Admin:Init()
	initTextChatCommands()
end

return Server_Admin
