local Shared_GameProcess = {}

Shared_GameProcess.WallFrontOpening = 125
Shared_GameProcess.HoleFloorSize = 80

Shared_GameProcess.FloorSizeByRarity = {
	Common = 300,
	Rare = 350,
	Epic = 500,
	Legendary = 600,
	Mythical = 700,
	Secret = 800,
	Divine = 900,
	Superior = 1000,
}

function Shared_GameProcess.GetFloorSize(rarity: string): number?
	local size = Shared_GameProcess.FloorSizeByRarity[rarity]
	if type(size) == "number" and size > 0 then
		return size
	end
	return nil
end

return Shared_GameProcess
