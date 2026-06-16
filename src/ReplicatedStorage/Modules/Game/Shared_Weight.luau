local Shared_Carry = require(script.Parent.Parent.Economy.Shared_Carry)
local Shared_Rarities = require(script.Parent.Shared_Rarities)

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
	MaxSizeMultiplier = 2.1,
	-- Lucky block kg (10-1000) is for economy/carry; visual size uses this spread instead.
	LuckyBlockMinKg = 10,
	LuckyBlockMaxKg = 1000,
	LuckyBlockMinVisualScale = 1,
	LuckyBlockMaxVisualScale = 2.1,
	-- Brainrots only scale from the weight roll, not lucky-block base tier.
	BrainrotSizeRatioSlope = 0.25,
	BrainrotMaxSizeMultiplier = 1.35,
	IncomeRatioSlope = 0.55,
	MaxIncomeMultiplier = 5.5,
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

function Shared_Weight.GetLuckyBlockMaxRollWeight(baseWeight: number, rarityName: string): number
	local maxRequiredStrength = Shared_Rarities.GetMaxRequiredStrength(rarityName)
	if maxRequiredStrength then
		return Shared_Carry.GetMaxCarryWeight(maxRequiredStrength)
	end

	local safeBase = math.max(0.01, tonumber(baseWeight) or 1)
	return roundWeight(safeBase * 9)
end

function Shared_Weight.RollLuckyBlockWeight(baseWeight: number, rarityName: string): number
	local rolled = Shared_Weight.RollWeight(baseWeight)
	local maxWeight = Shared_Weight.GetLuckyBlockMaxRollWeight(baseWeight, rarityName)
	return roundWeight(math.min(rolled, maxWeight))
end

local function getSublinearScale(ratio: number, slope: number): number
	if ratio <= 1 then
		return ratio
	end
	return 1 + (ratio - 1) * slope
end

local function getLuckyBlockTierVisualScale(baseWeight: number): number
	local balance = Shared_Weight.Balance
	local minKg = balance.LuckyBlockMinKg or 10
	local maxKg = balance.LuckyBlockMaxKg or 1000
	local minScale = balance.LuckyBlockMinVisualScale or 1
	local maxScale = balance.LuckyBlockMaxVisualScale or 2.5
	local span = math.max(maxKg - minKg, 0.01)

	local safeBase = math.clamp(tonumber(baseWeight) or minKg, minKg, maxKg)
	local alpha = (safeBase - minKg) / span
	return minScale + alpha * (maxScale - minScale)
end

local function getWeightedSizeMultiplier(baseWeight: number, rolledWeight: number): number
	local balance = Shared_Weight.Balance
	local slope = balance.SizeRatioSlope or 0.425
	local maxScale = balance.MaxSizeMultiplier or 2.5

	local safeBase = math.max(0.01, tonumber(baseWeight) or balance.LuckyBlockMinKg or 10)
	local safeWeight = math.max(safeBase, tonumber(rolledWeight) or safeBase)

	local tierScale = getLuckyBlockTierVisualScale(safeBase)
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

local LUCKY_BLOCK_PRIMARY_NAMES = {
	"PrimaryPart",
	"Primary",
	"Hitbox",
	"Root",
	"Main",
}

function Shared_Weight.EnsureLuckyBlockPrimaryPart(model: Model): BasePart?
	if model.PrimaryPart and model.PrimaryPart:IsDescendantOf(model) then
		return model.PrimaryPart
	end

	for _, name in LUCKY_BLOCK_PRIMARY_NAMES do
		local direct = model:FindFirstChild(name)
		if direct and direct:IsA("BasePart") then
			model.PrimaryPart = direct
			return direct
		end
	end

	local largestDirect: BasePart? = nil
	local largestVolume = 0
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			local volume = child.Size.X * child.Size.Y * child.Size.Z
			if volume > largestVolume then
				largestVolume = volume
				largestDirect = child
			end
		end
	end
	if largestDirect then
		model.PrimaryPart = largestDirect
		return largestDirect
	end

	model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
	return model.PrimaryPart
end

function Shared_Weight.CountLuckyBlockParts(model: Model): number
	local count = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

function Shared_Weight.WeldLuckyBlockAssembly(model: Model): BasePart?
	local primaryPart = Shared_Weight.EnsureLuckyBlockPrimaryPart(model)
	if not primaryPart then
		return nil
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		end
	end

	primaryPart.Anchored = true
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Massless = true
			if part ~= primaryPart then
				part.Anchored = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primaryPart
				weld.Part1 = part
				weld.Parent = primaryPart
			end
		end
	end

	return primaryPart
end

function Shared_Weight.PrepareLuckyBlockForWorld(model: Model): BasePart?
	Shared_Weight.SyncLuckyBlockPivot(model)
	local primaryPart = Shared_Weight.WeldLuckyBlockAssembly(model)
	if primaryPart then
		model:SetAttribute("LuckyBlockPartCount", Shared_Weight.CountLuckyBlockParts(model))
	end
	return primaryPart
end

local function resetPivotToPrimaryPart(model: Model, primaryPart: BasePart)
	local savedWorldCFrames: { [BasePart]: CFrame } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			savedWorldCFrames[descendant] = descendant.CFrame
		end
	end

	model:PivotTo(primaryPart.CFrame)

	for part, worldCFrame in savedWorldCFrames do
		if part.Parent then
			part.CFrame = worldCFrame
		end
	end
end

function Shared_Weight.SyncLuckyBlockPivot(model: Model): BasePart?
	local primaryPart = Shared_Weight.EnsureLuckyBlockPrimaryPart(model)
	if not primaryPart then
		return nil
	end

	resetPivotToPrimaryPart(model, primaryPart)
	return primaryPart
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
