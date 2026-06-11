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
		orderedStoreName = "RFB_MaxSpeed_v1",
	},
	TotalCash = {
		modelName = "TotalCash",
		orderedStoreName = "RFB_TotalCash_v1",
	},
}

return Shared_Leaderboards
