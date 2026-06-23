local LuckyBlocks = {}

LuckyBlocks.DefaultBillboardYOffsetAdd = 0.35

LuckyBlocks.DefaultModifierChances = {
	Normal = 70,
	Golden = 18,
	Diamond = 7,
	Galaxy = 3,
	Lava = 1.5,
	Rainbow = 0.5,
}

LuckyBlocks.ModifierChancesByRarity = {
	Common = {
		Normal = 82,
		Golden = 14,
		Diamond = 3,
		Galaxy = 1,
	},
	Rare = {
		Normal = 72,
		Golden = 18,
		Diamond = 7,
		Galaxy = 2.5,
		Lava = 0.5,
	},
	Epic = {
		Normal = 60,
		Golden = 23,
		Diamond = 10,
		Galaxy = 5,
		Lava = 1.6,
		Rainbow = 0.4,
	},
	Legendary = {
		Normal = 48,
		Golden = 27,
		Diamond = 13,
		Galaxy = 7,
		Lava = 4,
		Rainbow = 1,
	},
	Mythical = {
		Normal = 38,
		Golden = 27,
		Diamond = 16,
		Galaxy = 10,
		Lava = 7,
		Rainbow = 2,
	},
	Secret = {
		Normal = 28,
		Golden = 26,
		Diamond = 18,
		Galaxy = 13,
		Lava = 11,
		Rainbow = 4,
	},
	Divine = {
		Normal = 20,
		Golden = 24,
		Diamond = 19,
		Galaxy = 16,
		Lava = 15,
		Rainbow = 6,
	},
	Superior = {
		Normal = 10,
		Golden = 20,
		Diamond = 22,
		Galaxy = 20,
		Lava = 18,
		Rainbow = 10,
	},
}

LuckyBlocks.Data = {
	CommonLuckyBlock = {
		DisplayName = "Lucky Block",
		Rarity = "Common",
		Image = "rbxassetid://78477350472889",
		BaseWeight = 10,
		MinLevel = 1,
		MaxLevel = 4,
		Blacklist = {},
	},
	RareLuckyBlock = {
		DisplayName = "Lucky Block",
		Rarity = "Rare",
		Image = "rbxassetid://89361878329509",
		BaseWeight = 25,
		MinLevel = 1,
		MaxLevel = 6,
		Blacklist = {},
	},
	EpicLuckyBlock = {
		DisplayName = "Lucky Block",
		Rarity = "Epic",
		Image = "rbxassetid://97509263941551",
		BaseWeight = 50,
		MinLevel = 2,
		MaxLevel = 8,
		Blacklist = {},
	},
	LegendaryLuckyBlock = {
		DisplayName = "Lucky Block",
		Rarity = "Legendary",
		Image = "rbxassetid://75895971800979",
		BaseWeight = 100,
		MinLevel = 3,
		MaxLevel = 10,
	},
	MythicalLuckyBlock = {
		DisplayName = "Lucky Block",
		Rarity = "Mythical",
		Image = "rbxassetid://121875813364809",
		BaseWeight = 200,
		MinLevel = 4,
		MaxLevel = 12,
	},
	SecretLuckyBlock = {
		DisplayName = "Lucky Block",
		Rarity = "Secret",
		Image = "rbxassetid://114710058131467",
		BaseWeight = 400,
		MinLevel = 5,
		MaxLevel = 14,
	},
	DivineLuckyBlock = {
		DisplayName = "Lucky Block",
		Rarity = "Divine",
		Image = "rbxassetid://90001956185589",
		BaseWeight = 650,
		MinLevel = 6,
		MaxLevel = 16,
	},
	SuperiorLuckyBlock = {
		DisplayName = "Lucky Block",
		Rarity = "Superior",
		Image = "rbxassetid://102574841893672",
		BaseWeight = 1000,
		MinLevel = 8,
		MaxLevel = 18,
	},
	VIPLuckyBlock = {
		DisplayName = "VIP Lucky Block",
		Image = "rbxassetid://79236053187843",
		BaseWeight = 500,
		BillboardYOffsetAdd = 2,
		BillboardTextScale = 1.45,
		IsDonate = true,
		DisplayStyle = {
			Label = "VIP",
			Color = Color3.fromRGB(255, 220, 120),
			ColorGradient = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 0)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 60, 255)),
			}),
			GradientRotation = 90,
		},
		ModifierChances = {
			Normal = 12,
			Golden = 24,
			Diamond = 24,
			Galaxy = 20,
			Lava = 12,
			Rainbow = 8,
		},
		RewardBrainrots = {
			{ ConfigName = "PepeFrogy", Weight = 4000 },
			{ ConfigName = "BurbalolliLulilolli", Weight = 3000 },
			{ ConfigName = "Ben", Weight = 2000 },
			{ ConfigName = "NyanCat", Weight = 800 },
			{ ConfigName = "GirafaCelestre", Weight = 175 },
			{ ConfigName = "LaVaccaSaturnoSaturnita", Weight = 25 },
		},
		Blacklist = {},
	},
	SixSevenLuckyBlock = {
		DisplayName = "67 Lucky Block",
		Image = "rbxassetid://127431029768961",
		Rarity = "Epic",
		BaseWeight = 67,
		BillboardYOffsetAdd = 2,
		BillboardTextScale = 1.45,
		IsDonate = true,
		DisplayStyle = {
			Label = "67",
			Color = Color3.fromRGB(255, 90, 90),
			ColorGradient = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 50, 50)),
			}),
			GradientRotation = 90,
		},
		RewardBrainrots = {
			{ ConfigName = "SixSeven", Weight = 1 },
		},
		Blacklist = {},
	},
}

function LuckyBlocks.GetBillboardTextScale(configName: string): number?
	local config = LuckyBlocks.Data[configName]
	if config and type(config.BillboardTextScale) == "number" and config.BillboardTextScale > 0 then
		return config.BillboardTextScale
	end
	return nil
end

function LuckyBlocks.GetBillboardYOffsetAdd(configName: string): number
	local config = LuckyBlocks.Data[configName]
	if config and type(config.BillboardYOffsetAdd) == "number" then
		return config.BillboardYOffsetAdd
	end
	return LuckyBlocks.DefaultBillboardYOffsetAdd or 0.35
end

function LuckyBlocks.IsDonateBlock(configName: string): boolean
	local config = LuckyBlocks.Data[configName]
	return config ~= nil and config.IsDonate == true
end

function LuckyBlocks.IsMapSpawnable(configName: string): boolean
	return LuckyBlocks.Data[configName] ~= nil and not LuckyBlocks.IsDonateBlock(configName)
end

function LuckyBlocks.GetDisplayStyle(configName: string): { [string]: any }?
	local config = LuckyBlocks.Data[configName]
	if not config or type(config.DisplayStyle) ~= "table" then
		return nil
	end
	return config.DisplayStyle
end

function LuckyBlocks.GetRewardBrainrots(configName: string): { string }?
	local config = LuckyBlocks.Data[configName]
	if not config then
		return nil
	end

	local rewardBrainrots = config.RewardBrainrots
	if type(rewardBrainrots) ~= "table" or #rewardBrainrots == 0 then
		return nil
	end

	local resolved: { string } = {}
	for _, entry in rewardBrainrots do
		if type(entry) == "string" and entry ~= "" then
			table.insert(resolved, entry)
		elseif type(entry) == "table" and type(entry.ConfigName) == "string" and entry.ConfigName ~= "" then
			table.insert(resolved, entry.ConfigName)
		end
	end

	if #resolved == 0 then
		return nil
	end

	return resolved
end

function LuckyBlocks.RollRewardBrainrot(luckyBlockConfigName: string): string?
	local config = LuckyBlocks.Data[luckyBlockConfigName]
	if not config or type(config.RewardBrainrots) ~= "table" or #config.RewardBrainrots == 0 then
		return nil
	end

	local Shared_Brainrots = require(script.Parent.Shared_Brainrots)
	local totalWeight = 0
	local entries: { { ConfigName: string, Weight: number } } = {}

	for _, entry in config.RewardBrainrots do
		local configName: string? = nil
		local weight = 0

		if type(entry) == "string" and entry ~= "" then
			configName = entry
			weight = 1
		elseif type(entry) == "table" and type(entry.ConfigName) == "string" and entry.ConfigName ~= "" then
			configName = entry.ConfigName
			weight = math.max(0, tonumber(entry.Weight) or tonumber(entry.Chance) or 0)
		end

		if configName and weight > 0 and Shared_Brainrots.Data[configName] then
			totalWeight += weight
			table.insert(entries, { ConfigName = configName, Weight = weight })
		end
	end

	if totalWeight <= 0 or #entries == 0 then
		return nil
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, entry in entries do
		cumulative += entry.Weight
		if roll <= cumulative then
			return entry.ConfigName
		end
	end

	return entries[#entries].ConfigName
end

function LuckyBlocks.GetRewardBrainrotChances(luckyBlockConfigName: string): { { ConfigName: string, ChancePercent: number } }?
	local config = LuckyBlocks.Data[luckyBlockConfigName]
	if not config or type(config.RewardBrainrots) ~= "table" or #config.RewardBrainrots == 0 then
		return nil
	end

	local Shared_Brainrots = require(script.Parent.Shared_Brainrots)
	local totalWeight = 0
	local entries: { { ConfigName: string, Weight: number } } = {}

	for _, entry in config.RewardBrainrots do
		local configName: string? = nil
		local weight = 0

		if type(entry) == "string" and entry ~= "" then
			configName = entry
			weight = 1
		elseif type(entry) == "table" and type(entry.ConfigName) == "string" and entry.ConfigName ~= "" then
			configName = entry.ConfigName
			weight = math.max(0, tonumber(entry.Weight) or tonumber(entry.Chance) or 0)
		end

		if configName and weight > 0 and Shared_Brainrots.Data[configName] then
			totalWeight += weight
			table.insert(entries, { ConfigName = configName, Weight = weight })
		end
	end

	if totalWeight <= 0 then
		return nil
	end

	local resolved = {}
	for _, entry in entries do
		table.insert(resolved, {
			ConfigName = entry.ConfigName,
			ChancePercent = (entry.Weight / totalWeight) * 100,
		})
	end

	return resolved
end

function LuckyBlocks.GetRewardRarities(configName: string): { string }?
	local config = LuckyBlocks.Data[configName]
	if not config then
		return nil
	end

	local rewardRarities = config.RewardRarities
	if type(rewardRarities) ~= "table" or #rewardRarities == 0 then
		return nil
	end

	local resolved: { string } = {}
	for _, rarity in rewardRarities do
		if type(rarity) == "string" and rarity ~= "" then
			table.insert(resolved, rarity)
		end
	end

	if #resolved == 0 then
		return nil
	end

	return resolved
end

function LuckyBlocks.GetConfigNameForRarity(rarity: string): string?
	for configName, config in LuckyBlocks.Data do
		if not config.IsDonate and config.Rarity == rarity then
			return configName
		end
	end
	return nil
end

function LuckyBlocks.RollRewardLevel(_configName: string): number
	return 1
end

function LuckyBlocks.GetBaseWeight(configName: string): number
	local config = LuckyBlocks.Data[configName]
	local baseWeight = config and config.BaseWeight
	if type(baseWeight) == "number" and baseWeight > 0 then
		return baseWeight
	end
	return 10
end

return LuckyBlocks