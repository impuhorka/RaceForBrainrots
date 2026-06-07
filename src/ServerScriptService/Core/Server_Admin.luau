local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Server_Data = require(script.Parent.Server_Data)
local Shared_Brainrots = require(ReplicatedStorage.Modules.Shared_Brainrots)
local Shared_LuckyBlocks = require(ReplicatedStorage.Modules.Shared_LuckyBlocks)

local Server_Admin = {}
local plotServiceRef = nil

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

local function normalizeLookupName(name: string): string
	return string.lower(string.gsub(name, "[^%w]", ""))
end

local function resolveBrainrotName(name: string): string?
	local normalizedInput = normalizeLookupName(name)
	for configName in Shared_Brainrots.Data do
		if normalizeLookupName(configName) == normalizedInput then
			return configName
		end
	end
	return nil
end

local function resolveLuckyBlockName(name: string): string?
	local normalizedInput = normalizeLookupName(name)
	for configName in Shared_LuckyBlocks.Data do
		if normalizeLookupName(configName) == normalizedInput then
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
		return targetError or "Usage: /addbrainrot [me|player] [ConfigName|all] [Modifier=Normal] [Level=1] [Amount=1]"
	end

	local rawConfigName = args[2]
	if not rawConfigName then
		return "Usage: /addbrainrot [me|player] [ConfigName|all] [Modifier=Normal] [Level=1] [Amount=1]"
	end

	local modifier = "Normal"
	local level = 1
	local amount = 1

	local trailing = {}
	for i = 3, #args do
		table.insert(trailing, args[i])
	end

	-- One trailing number defaults to amount, two trailing numbers are level then amount.
	local maybeAmount = tonumber(trailing[#trailing])
	if maybeAmount then
		amount = math.max(1, math.floor(maybeAmount))
		table.remove(trailing, #trailing)
	end

	local maybeLevel = tonumber(trailing[#trailing])
	if maybeLevel then
		level = math.max(1, math.floor(maybeLevel))
		table.remove(trailing, #trailing)
	end

	if trailing[1] then
		modifier = trailing[1]
	end

	local function addOne(configName: string): number
		local addedCount = 0
		for _ = 1, amount do
			local newIndex = Server_Data:AddInventoryItem(target, {
				ItemType = "Brainrot",
				ConfigName = configName,
				Data = {
					Level = level,
					Modifier = modifier,
				},
			})

			if not newIndex then
				break
			end
			addedCount += 1
		end
		return addedCount
	end

	if string.lower(rawConfigName) == "all" then
		local configNames = {}
		for configName in Shared_Brainrots.Data do
			table.insert(configNames, configName)
		end
		table.sort(configNames)

		local totalAdded = 0
		for _, configName in configNames do
			totalAdded += addOne(configName)
		end

		return ("Added %d brainrots to %s (%s L%d, amount %d each)"):format(
			totalAdded,
			target.Name,
			modifier,
			level,
			amount
		)
	end

	local configName = resolveBrainrotName(rawConfigName)
	if not configName then
		return ("Unknown brainrot: %s"):format(rawConfigName)
	end

	local addedCount = addOne(configName)
	if addedCount <= 0 then
		return "Failed to add brainrot"
	end

	return ("Added %d x %s (%s L%d) to %s"):format(addedCount, configName, modifier, level, target.Name)
end

local function executeAddLuckyBlock(actor: Player, args: { string }): string
	local target, targetError = resolveTargetPlayer(actor, args[1])
	if not target then
		return targetError or "Usage: /addluckyblock [me|player] [ConfigName|all] [Amount=1]"
	end

	local rawConfigName = args[2]
	if not rawConfigName then
		return "Usage: /addluckyblock [me|player] [ConfigName|all] [Amount=1]"
	end

	local amount = math.max(1, math.floor(tonumber(args[3]) or 1))

	local function addOne(configName: string): number
		local addedCount = 0
		for _ = 1, amount do
			local newIndex = Server_Data:AddInventoryItem(target, {
				ItemType = "LuckyBlock",
				ConfigName = configName,
				Data = {},
			})
			if not newIndex then
				break
			end
			addedCount += 1
		end
		return addedCount
	end

	if string.lower(rawConfigName) == "all" then
		local configNames = {}
		for configName in Shared_LuckyBlocks.Data do
			table.insert(configNames, configName)
		end
		table.sort(configNames)

		local totalAdded = 0
		for _, configName in configNames do
			totalAdded += addOne(configName)
		end

		return ("Added %d lucky blocks to %s (amount %d each)"):format(totalAdded, target.Name, amount)
	end

	local configName = resolveLuckyBlockName(rawConfigName)
	if not configName then
		return ("Unknown lucky block: %s"):format(rawConfigName)
	end

	local addedCount = addOne(configName)
	if addedCount <= 0 then
		return "Failed to add lucky block"
	end

	return ("Added %d x %s to %s"):format(addedCount, configName, target.Name)
end

local function executeHelp(): string
	return "Commands: /addcash [me|player] [amount], /addbrainrot [me|player] [ConfigName|all] [Modifier=Normal] [Level=1] [Amount=1], /addluckyblock [me|player] [ConfigName|all] [Amount=1], /wipe-data [me|player]"
end

local function executeWipeData(actor: Player, args: { string }): string
	local target = actor
	if args[1] then
		local resolvedTarget, targetError = resolveTargetPlayer(actor, args[1])
		if not resolvedTarget then
			return targetError or "Usage: /wipe-data [me|player]"
		end
		target = resolvedTarget
	end

	local success = Server_Data:ResetPlayerData(target)
	if not success then
		return ("Failed to wipe data for %s"):format(target.Name)
	end

	local teleported = false
	if plotServiceRef and plotServiceRef.ResetPlayerPlotFromData then
		teleported = plotServiceRef:ResetPlayerPlotFromData(target)
	end

	if teleported then
		return ("Wiped %s data and teleported to plot"):format(target.Name)
	end

	return ("Wiped %s data (plot teleport unavailable)"):format(target.Name)
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
	elseif command == "addluckyblock" then
		result = executeAddLuckyBlock(player, parts)
	elseif command == "wipe-data" or command == "wipedata" then
		result = executeWipeData(player, parts)
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
		{ Name = "addluckyblock", Alias = "/addluckyblock" },
		{ Name = "wipe_data", Alias = "/wipe-data" },
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

function Server_Admin:Init(plotService)
	plotServiceRef = plotService
	initTextChatCommands()
end

return Server_Admin
