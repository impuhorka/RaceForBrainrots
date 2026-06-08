local LuckyBlocks = {}

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
        
        Image = "rbxassetid://133495849637215",

        MinLevel = 1,
        MaxLevel = 10,

        Blacklist = {},
    },
    RareLuckyBlock = {
        DisplayName = "Lucky Block",
        Rarity = "Rare",
        
        Image = "rbxassetid://89530799088867",

        MinLevel = 10,
        MaxLevel = 20,

        Blacklist = {},
    },
    EpicLuckyBlock = {
        DisplayName = "Lucky Block",
        Rarity = "Epic",
        
        Image = "rbxassetid://89530799088867",

        MinLevel = 20,
        MaxLevel = 30,

        Blacklist = {},
    },
    LegendaryLuckyBlock = {
        DisplayName = "Lucky Block",
        Rarity = "Legendary",
        
        Image = "rbxassetid://89530799088867",

        MinLevel = 30,
        MaxLevel = 40,
    },
    MythicalLuckyBlock = {
        DisplayName = "Lucky Block",
        Rarity = "Mythical",
        
        Image = "rbxassetid://89530799088867",

        MinLevel = 40,
        MaxLevel = 50,
    },
    SecretLuckyBlock = {
        DisplayName = "Lucky Block",
        Rarity = "Secret",
        
        Image = "rbxassetid://89530799088867",

        MinLevel = 50,
        MaxLevel = 60,
    },
    DivineLuckyBlock = {
        DisplayName = "Lucky Block",
        Rarity = "Divine",
        
        Image = "rbxassetid://89530799088867",

        MinLevel = 60,
        MaxLevel = 70,
    },
    SuperiorLuckyBlock = {
        DisplayName = "Lucky Block",
        Rarity = "Superior",
        
        Image = "rbxassetid://89530799088867",

        MinLevel = 70,
        MaxLevel = 80,
    },
}

return LuckyBlocks