local Shared_Weight = {}

Shared_Weight.RollTiers = {
	{ chance = 70, minMult = 1, maxMult = 1.75 },
	{ chance = 18.5, minMult = 1.75, maxMult = 2.5 },
	{ chance = 8, minMult = 2.5, maxMult = 3.5 },
	{ chance = 3, minMult = 3.5, maxMult = 4.5 },
	{ chance = 0.45, minMult = 4.5, maxMult = 5.5 },
	{ chance = 0.04, minMult = 5.5, maxMult = 6.5 },
	{ chance = 0.009, minMult = 6.5, maxMult = 7.5 },
	{ chance = 0.001, minMult = 7.5, maxMult = 9 },
}

Shared_Weight.Balance = {
	SizeReferenceBase = 15,
	SizeRatioSlope = 0.425,
	MaxSizeMultiplier = 2.5,
	-- Brainrots only scale from the weight roll, not lucky-block base tier.
	BrainrotSizeRatioSlope = 0.25,
	BrainrotMaxSizeMultiplier = 1.5,
	IncomeRatioSlope = 0.375,
	MaxIncomeMultiplier = 3,
}

local function roundWeight(value: number): number
	return math.floor(value * 100 + 0.5) / 100
end

function Shared_Weight.GetRatio(baseWeight: number, rolledWeight: number): number
	local base = math.max(0.01, tonumber(baseWeight) or 1)
	local rolled = math.max(base, tonumber(rolledWeight) or base)
	return rolled / base
end

function Shared_Weight.RollWeightMultiplier(): number
	local roll = math.random() * 100
	local cumulative = 0

	for _, tier in Shared_Weight.RollTiers do
		cumulative += tier.chance
		if roll <= cumulative then
			return tier.minMult + math.random() * (tier.maxMult - tier.minMult)
		end
	end

	return 1
end

function Shared_Weight.RollWeight(baseWeight: number): number
	local safeBase = math.max(0.01, tonumber(baseWeight) or 1)
	return roundWeight(safeBase * Shared_Weight.RollWeightMultiplier())
end

local function getSublinearScale(ratio: number, slope: number): number
	if ratio <= 1 then
		return ratio
	end
	return 1 + (ratio - 1) * slope
end

local function getWeightedSizeMultiplier(baseWeight: number, rolledWeight: number): number
	local balance = Shared_Weight.Balance
	local referenceBase = balance.SizeReferenceBase or 15
	local slope = balance.SizeRatioSlope or 0.425
	local maxScale = balance.MaxSizeMultiplier or 2.5

	local safeBase = math.max(0.01, tonumber(baseWeight) or referenceBase)
	local safeWeight = math.max(safeBase, tonumber(rolledWeight) or safeBase)

	local tierScale = getSublinearScale(safeBase / referenceBase, slope)
	local rollScale = getSublinearScale(safeWeight / safeBase, slope)

	return math.min(maxScale, tierScale * rollScale)
end

local function getBrainrotWeightedSizeMultiplier(baseWeight: number, rolledWeight: number): number
	local balance = Shared_Weight.Balance
	local slope = balance.BrainrotSizeRatioSlope or 0.25
	local maxScale = balance.BrainrotMaxSizeMultiplier or 1.5
	local referenceBase = balance.SizeReferenceBase or 15

	local safeBase = math.max(0.01, tonumber(baseWeight) or referenceBase)
	local safeWeight = math.max(safeBase, tonumber(rolledWeight) or safeBase)

	local rollScale = getSublinearScale(safeWeight / safeBase, slope)
	return math.min(maxScale, rollScale)
end

function Shared_Weight.GetBrainrotScaleMultiplier(baseWeight: number, rolledWeight: number): number
	return getBrainrotWeightedSizeMultiplier(baseWeight, rolledWeight)
end

function Shared_Weight.GetLuckyBlockScaleMultiplier(baseWeight: number, rolledWeight: number): number
	return getWeightedSizeMultiplier(baseWeight, rolledWeight)
end

function Shared_Weight.GetModelOriginScale(model: Model): number
	local stored = model:GetAttribute("OriginScale")
	if type(stored) == "number" and stored > 0 then
		return stored
	end

	local originScale = 1
	local ok, currentScale = pcall(function()
		return model:GetScale()
	end)
	if ok and type(currentScale) == "number" and currentScale > 0 then
		originScale = currentScale
	end

	model:SetAttribute("OriginScale", originScale)
	return originScale
end

function Shared_Weight.GetLuckyBlockModelOriginScale(model: Model): number
	return Shared_Weight.GetModelOriginScale(model)
end

function Shared_Weight.GetWeightedScaleFromOrigin(
	originScale: number,
	baseWeight: number,
	rolledWeight: number
): number
	local safeOrigin = math.max(0.01, tonumber(originScale) or 1)
	local weightMultiplier = getWeightedSizeMultiplier(baseWeight, rolledWeight)
	return safeOrigin * weightMultiplier
end

function Shared_Weight.GetBrainrotScaleFromOrigin(
	originScale: number,
	baseWeight: number,
	rolledWeight: number
): number
	local safeOrigin = math.max(0.01, tonumber(originScale) or 1)
	local weightMultiplier = Shared_Weight.GetBrainrotScaleMultiplier(baseWeight, rolledWeight)
	return safeOrigin * weightMultiplier
end

function Shared_Weight.GetLuckyBlockScaleFromOrigin(
	originScale: number,
	baseWeight: number,
	rolledWeight: number
): number
	return Shared_Weight.GetWeightedScaleFromOrigin(originScale, baseWeight, rolledWeight)
end

function Shared_Weight.ApplyWeightedScale(model: Model, baseWeight: number, rolledWeight: number): number
	local originScale = Shared_Weight.GetModelOriginScale(model)
	local targetScale = Shared_Weight.GetWeightedScaleFromOrigin(originScale, baseWeight, rolledWeight)
	model:ScaleTo(targetScale)
	return targetScale
end

function Shared_Weight.ApplyBrainrotScale(model: Model, baseWeight: number, rolledWeight: number): number
	local originScale = Shared_Weight.GetModelOriginScale(model)
	local targetScale = Shared_Weight.GetBrainrotScaleFromOrigin(originScale, baseWeight, rolledWeight)
	model:ScaleTo(targetScale)
	return targetScale
end

function Shared_Weight.ApplyLuckyBlockScale(model: Model, baseWeight: number, rolledWeight: number): number
	return Shared_Weight.ApplyWeightedScale(model, baseWeight, rolledWeight)
end

function Shared_Weight.GetScaleMultiplier(baseWeight: number, rolledWeight: number): number
	return Shared_Weight.GetBrainrotScaleMultiplier(baseWeight, rolledWeight)
end

function Shared_Weight.GetIncomeMultiplier(baseWeight: number, rolledWeight: number): number
	local ratio = Shared_Weight.GetRatio(baseWeight, rolledWeight)
	if ratio <= 1 then
		return 1
	end

	local balance = Shared_Weight.Balance
	local incomeMult = 1 + (ratio - 1) * (balance.IncomeRatioSlope or 0.375)
	return math.min(balance.MaxIncomeMultiplier or 3, incomeMult)
end

function Shared_Weight.FormatKg(weight: number): string
	local safeWeight = math.max(0, tonumber(weight) or 0)
	local rounded = roundWeight(safeWeight)
	local whole = math.floor(rounded + 0.0001)
	if math.abs(rounded - whole) < 0.001 then
		return ("%d kg"):format(whole)
	end

	local text = string.format("%.2f", rounded)
	text = text:gsub("(%..-)0+$", "%1")
	text = text:gsub("%.$", "")
	return text .. " kg"
end

function Shared_Weight.ResolveLuckyBlockWeights(itemData: any?, defaultBaseWeight: number): (number, number)
	local baseWeight = defaultBaseWeight
	local weight = defaultBaseWeight

	if type(itemData) == "table" then
		if type(itemData.BaseWeight) == "number" then
			baseWeight = itemData.BaseWeight
		end
		if type(itemData.Weight) == "number" then
			weight = itemData.Weight
		else
			weight = baseWeight
		end
	end

	baseWeight = roundWeight(math.max(0.01, baseWeight))
	weight = roundWeight(math.max(baseWeight, weight))
	return baseWeight, weight
end

function Shared_Weight.ResolveBrainrotWeights(itemData: any?, configName: string): (number, number)
	local defaultBase = 15
	local baseWeight = defaultBase
	local rolledWeight = defaultBase

	if type(itemData) == "table" then
		if type(itemData.BaseWeight) == "number" then
			baseWeight = itemData.BaseWeight
		end
		if type(itemData.Weight) == "number" then
			rolledWeight = itemData.Weight
		else
			rolledWeight = baseWeight
		end
	end

	baseWeight = roundWeight(math.max(0.01, baseWeight))
	rolledWeight = roundWeight(math.max(baseWeight, rolledWeight))
	return baseWeight, rolledWeight
end

return Shared_Weight
