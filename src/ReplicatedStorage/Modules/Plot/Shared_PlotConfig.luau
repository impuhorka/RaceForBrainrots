local Shared_PlotConfig = {}

Shared_PlotConfig.SlotsPerFloor = 10
Shared_PlotConfig.DefaultPlotSlots = 10
Shared_PlotConfig.MaxPlotSlots = 50

local function roundToCoolThousands(value: number): number
	return math.max(1000, math.floor(value / 1000 + 0.5) * 1000)
end

function Shared_PlotConfig.getNextSlotCost(currentSlotCount: number): number
	if currentSlotCount < 10 then
		local rawCost = 1500 * (currentSlotCount + 1) ^ 1.32
		return roundToCoolThousands(rawCost)
	end

	local extraSlots = currentSlotCount - 9
	local rawCost = 90000 * extraSlots ^ 2.9
	return roundToCoolThousands(rawCost)
end

Shared_PlotConfig.SlotFirstFloorY = 18.27
Shared_PlotConfig.SlotNextFloorY = 17.25

Shared_PlotConfig.AdditionalFirstFloorY = 11.52
Shared_PlotConfig.AdditionalNextFloorY = 17.29

Shared_PlotConfig.SlotRelativeCFrames = {
	[1] = CFrame.new(10.8177662, -6.91995239, -38.6773224, -8.74227766e-08, 0, 0.999995708, 0, -1, 0, 1, 0, 8.74224e-08),
	[2] = CFrame.new(10.8177652, -6.91995239, -28.6773224, -8.74227766e-08, 0, 0.999995708, 0, -1, 0, 1, 0, 8.74224e-08),
	[3] = CFrame.new(10.8177652, -6.91995239, -18.6773224, -8.74227766e-08, 0, 0.999995708, 0, -1, 0, 1, 0, 8.74224e-08),
	[4] = CFrame.new(10.8177643, -6.91995239, -8.67732239, -8.74227766e-08, 0, 0.999995708, 0, -1, 0, 1, 0, 8.74224e-08),
	[5] = CFrame.new(10.8177633, -6.91995239, 1.32269287, -8.74227766e-08, 0, 0.999995708, 0, -1, 0, 1, 0, 8.74224e-08),
	[6] = CFrame.new(-10.7503815, -6.91995239, 1.40155029, 8.74227766e-08, 0, -0.999996424, 0, -1, 0, -1, 0, -8.74224639e-08),
	[7] = CFrame.new(-10.7503815, -6.91995239, -8.59844971, 8.74227766e-08, 0, -0.999996424, 0, -1, 0, -1, 0, -8.74224639e-08),
	[8] = CFrame.new(-10.7503815, -6.91995239, -18.5984497, 8.74227766e-08, 0, -0.999996424, 0, -1, 0, -1, 0, -8.74224639e-08),
	[9] = CFrame.new(-10.7503777, -6.91995239, -28.5984497, 8.74227766e-08, 0, -0.999996424, 0, -1, 0, -1, 0, -8.74224639e-08),
	[10] = CFrame.new(-10.7503777, -6.91995239, -38.5984497, 8.74227766e-08, 0, -0.999996424, 0, -1, 0, -1, 0, -8.74224639e-08),
}

function Shared_PlotConfig.getSlotFloorYOffset(floorIndex: number): number
	if floorIndex <= 0 then
		return 0
	end
	if floorIndex == 1 then
		return Shared_PlotConfig.SlotFirstFloorY
	end
	return Shared_PlotConfig.SlotFirstFloorY + (floorIndex - 1) * Shared_PlotConfig.SlotNextFloorY
end

function Shared_PlotConfig.getAdditionalFloorYOffset(floorIndex: number): number
	if floorIndex <= 0 then
		return 0
	end
	return Shared_PlotConfig.AdditionalFirstFloorY + (floorIndex - 1) * Shared_PlotConfig.AdditionalNextFloorY
end

function Shared_PlotConfig.getFloorRotation(floorIndex: number): CFrame
	if floorIndex <= 1 then
		return CFrame.new()
	end
	return CFrame.Angles(0, math.pi * (floorIndex - 1), 0)
end

return Shared_PlotConfig
