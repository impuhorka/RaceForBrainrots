local PlotConfig = {}

PlotConfig.SlotsPerFloor = 10
PlotConfig.DefaultPlotSlots = 10
PlotConfig.MaxPlotSlots = 35

local function roundToCoolThousands(value: number): number
	return math.max(1000, math.floor(value / 1000 + 0.5) * 1000)
end

function PlotConfig.getNextSlotCost(currentSlotCount: number): number
	local rawCost = 1000 * (currentSlotCount + 1) ^ 1.25
	return roundToCoolThousands(rawCost)
end

PlotConfig.SlotFirstFloorY = 18.27
PlotConfig.SlotNextFloorY = 17.25

PlotConfig.AdditionalFirstFloorY = 11.52
PlotConfig.AdditionalNextFloorY = 17.29

PlotConfig.SlotRelativeCFrames = {
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

function PlotConfig.getSlotFloorYOffset(floorIndex: number): number
	if floorIndex <= 0 then
		return 0
	end
	if floorIndex == 1 then
		return PlotConfig.SlotFirstFloorY
	end
	return PlotConfig.SlotFirstFloorY + (floorIndex - 1) * PlotConfig.SlotNextFloorY
end

function PlotConfig.getAdditionalFloorYOffset(floorIndex: number): number
	if floorIndex <= 0 then
		return 0
	end
	return PlotConfig.AdditionalFirstFloorY + (floorIndex - 1) * PlotConfig.AdditionalNextFloorY
end

function PlotConfig.getFloorRotation(floorIndex: number): CFrame
	if floorIndex <= 1 then
		return CFrame.new()
	end
	return CFrame.Angles(0, math.pi * (floorIndex - 1), 0)
end

return PlotConfig
