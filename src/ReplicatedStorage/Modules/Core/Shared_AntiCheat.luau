local Shared_AntiCheat = {}

Shared_AntiCheat.CheckInterval = 0.2
Shared_AntiCheat.ViolationWindow = 45
Shared_AntiCheat.KickThreshold = 6

Shared_AntiCheat.TeleportGraceDuration = 1.75
Shared_AntiCheat.SpawnGraceDuration = 2.5

Shared_AntiCheat.WalkSpeedTolerance = 3
Shared_AntiCheat.HorizontalSpeedMultiplier = 1.45
Shared_AntiCheat.HorizontalSpeedBuffer = 8

Shared_AntiCheat.TeleportDistanceBuffer = 14
Shared_AntiCheat.TeleportSpeedMultiplier = 2.75

Shared_AntiCheat.MaxAirTimeWithoutGround = 4.5
Shared_AntiCheat.MaxVerticalSpeed = 110
Shared_AntiCheat.InsideSolidStrikeDelay = 0.35

Shared_AntiCheat.KickMessage = "Exploit detected. Fair play only."

return Shared_AntiCheat
