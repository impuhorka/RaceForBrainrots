local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Server_Data = require(script.Parent.Server_Data)
local Shared_Brainrots = SharedModules.require("Shared_Brainrots")
local Shared_LuckyBlocks = SharedModules.require("Shared_LuckyBlocks")

local Server_Admin = {}
local plotServiceRef = nil
local adminFeedbackEvent: RemoteEvent? = nil

local COMMAND_PREFIX = "/"
local GROUP_ADMIN_MIN_RANK = 254

local function isAdmin(player: Player): boolean
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		if ok and type(rank) == "number" then
			return rank >= GROUP_ADMIN_MIN_RANK
		end
		return false
	end
	return player.UserId == game.CreatorId
end

local function sendAdminFeedback(player: Player, message: string, isError: boolean?)
	if adminFeedbackEvent then
		adminFeedbackEvent:FireClient(player, message, isError == true)
	end
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

	local normalizedTarget = normalizeLookupName(rawTarget)
	if normalizedTarget == "me" then
		return actor, nil
	end

	local exact = Players:FindFirstChild(rawTarget)
	if exact and exact:IsA("Player") then
		return exact, nil
	end

	for _, player in Players:GetPlayers() do
		if normalizeLookupName(player.Name) == normalizedTarget then
			return player, nil
		end
		if normalizeLookupName(player.DisplayName) == normalizedTarget then
			return player, nil
		end
	end

	for _, player in Players:GetPlayers() do
		local normalizedName = normalizeLookupName(player.Name)
		local normalizedDisplay = normalizeLookupName(player.DisplayName)
		if string.find(normalizedName, normalizedTarget, 1, true) then
			return player, nil
		end
		if string.find(normalizedDisplay, normalizedTarget, 1, true) then
			return player, nil
		end
	end

	return nil, ("Player not found: %s"):format(rawTarget)
end

local function executeSetStat(actor: Player, args: { string }, statName: string, usage: string, minValue: number): string
	local target, targetError = resolveTargetPlayer(actor, args[1])
	if not target then
		return targetError or usage
	end

	local amount = tonumber(args[2])
	if not amount then
		return usage
	end

	local rounded = math.max(minValue, math.floor(amount))
	Server_Data:SetValue(target, statName, rounded)
	return ("Set %s to %d for %s"):format(statName, rounded, target.Name)
end

local function executeAddStat(actor: Player, args: { string }, statName: string, usage: string, minValue: number): string
	local target, targetError = resolveTargetPlayer(actor, args[1])
	if not target then
		return targetError or usage
	end

	local amount = tonumber(args[2])
	if not amount then
		return usage
	end

	local rounded = math.floor(amount)
	local current = math.max(minValue, math.floor(Server_Data:GetValue(target, statName) or minValue))
	local nextValue = math.max(minValue, current + rounded)
	Server_Data:SetValue(target, statName, nextValue)
	return ("Added %d %s to %s (now %d)"):format(rounded, statName, target.Name, nextValue)
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

local function executeSetCash(actor: Player, args: { string }): string
	return executeSetStat(actor, args, "Cash", "Usage: /setcash [me|player] [amount]", 0)
end

local function executeSetSpeed(actor: Player, args: { string }): string
	return executeSetStat(actor, args, "Speed", "Usage: /setspeed [me|player] [amount]", 1)
end

local function executeSetStrength(actor: Player, args: { string }): string
	return executeSetStat(actor, args, "Strength", "Usage: /setstrength [me|player] [amount]", 1)
end

local function executeAddSpeed(actor: Player, args: { string }): string
	return executeAddStat(actor, args, "Speed", "Usage: /addspeed [me|player] [amount]", 1)
end

local function executeAddStrength(actor: Player, args: { string }): string
	return executeAddStat(actor, args, "Strength", "Usage: /addstrength [me|player] [amount]", 1)
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
	return "Commands: /addcash, /setcash, /addspeed, /setspeed, /addstrength, /setstrength [me|player] [amount], /addbrainrot [me|player] [ConfigName|all] [Modifier=Normal] [Level=1] [Amount=1], /addluckyblock [me|player] [ConfigName|all] [Amount=1], /wipe-data [me|player]"
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

	local GameProcessService = require(ServerScriptService.GameProcess.GameProcessService)
	GameProcessService.ForfeitCarriedLuckyBlock(target)

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
	elseif command == "setcash" then
		result = executeSetCash(player, parts)
	elseif command == "addspeed" then
		result = executeAddSpeed(player, parts)
	elseif command == "setspeed" then
		result = executeSetSpeed(player, parts)
	elseif command == "addstrength" then
		result = executeAddStrength(player, parts)
	elseif command == "setstrength" then
		result = executeSetStrength(player, parts)
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
		local lowered = string.lower(result)
		local isError = string.find(lowered, "usage:", 1, true)
			or string.find(lowered, "failed", 1, true)
			or string.find(lowered, "unknown", 1, true)
			or string.find(lowered, "not found", 1, true)
			or string.find(lowered, "missing", 1, true)
		sendAdminFeedback(player, result, isError ~= nil)
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
		{ Name = "setcash", Alias = "/setcash" },
		{ Name = "addspeed", Alias = "/addspeed" },
		{ Name = "setspeed", Alias = "/setspeed" },
		{ Name = "addstrength", Alias = "/addstrength" },
		{ Name = "setstrength", Alias = "/setstrength" },
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
	local eventsFolder = ReplicatedStorage:WaitForChild("Events")
	adminFeedbackEvent = eventsFolder:WaitForChild("AdminFeedback") :: RemoteEvent
	initTextChatCommands()
end

return Server_Admin