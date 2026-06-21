local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_DataConfig = SharedModules.require("Shared_DataConfig")

local Shared_Leaderboards = {}

Shared_Leaderboards.EntryCount = 50
Shared_Leaderboards.UpdateIntervalSeconds = 60

Shared_Leaderboards.BoardIds = {
	MaxSpeed = "MaxSpeed",
	TotalCash = "TotalCash",
}

Shared_Leaderboards.BoardConfig = {
	MaxSpeed = {
		modelName = "MaxSpeed",
		orderedStoreName = Shared_DataConfig.LeaderboardStores.MaxSpeed,
	},
	TotalCash = {
		modelName = "TotalCash",
		orderedStoreName = Shared_DataConfig.LeaderboardStores.TotalCash,
	},
}

return Shared_Leaderboards
