local Shared_DataConfig = {}

Shared_DataConfig.Version = 3

Shared_DataConfig.PlayerStoreName = `RunForBrainrots_v{Shared_DataConfig.Version}`

Shared_DataConfig.LeaderboardStores = {
	MaxSpeed = `RFB_MaxSpeed_v{Shared_DataConfig.Version}`,
	TotalCash = `RFB_TotalCash_v{Shared_DataConfig.Version}`,
}

return Shared_DataConfig
