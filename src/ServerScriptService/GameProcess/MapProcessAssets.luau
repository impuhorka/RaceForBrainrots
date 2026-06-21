local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_GameProcess = SharedModules.require("Shared_GameProcess")
local Shared_Rarities = SharedModules.require("Shared_Rarities")
local Shared_Weight = SharedModules.require("Shared_Weight")
local Shared_MapDecorationBlueprint = SharedModules.require("Shared_MapDecorationBlueprint")

local MapProcessAssets = {}

function MapProcessAssets.getGameProcessAssets(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local gameProcessAssets = assets and assets:FindFirstChild("GameProcess")
	if gameProcessAssets and gameProcessAssets:IsA("Folder") then
		return gameProcessAssets
	end
	return nil
end

function MapProcessAssets.getFloorTemplate(): BasePart?
	local gameProcessAssets = MapProcessAssets.getGameProcessAssets()
	local floorPart = gameProcessAssets and gameProcessAssets:FindFirstChild("FloorPart")
	if floorPart and floorPart:IsA("BasePart") then
		return floorPart
	end
	return nil
end

function MapProcessAssets.getWallTemplate(): BasePart?
	local gameProcessAssets = MapProcessAssets.getGameProcessAssets()
	local wall = gameProcessAssets and gameProcessAssets:FindFirstChild("Wall")
	if wall and wall:IsA("BasePart") then
		return wall
	end
	return nil
end

function MapProcessAssets.getWallSurfaceGuiTemplate(): SurfaceGui?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local billboards = assets and assets:FindFirstChild("Billboards")
	local surfaceGui = billboards and billboards:FindFirstChild("WallSurfaceGui")
	if surfaceGui and surfaceGui:IsA("SurfaceGui") then
		return surfaceGui
	end
	return nil
end

function MapProcessAssets.getLianaTemplates(): { Model }
	local gameProcessAssets = MapProcessAssets.getGameProcessAssets()
	local lianasFolder = gameProcessAssets and gameProcessAssets:FindFirstChild("Lianas")
	if not lianasFolder then
		return {}
	end

	local templates: { Model } = {}
	for _, child in lianasFolder:GetChildren() do
		if child:IsA("Model") then
			table.insert(templates, child)
		end
	end
	return templates
end

function MapProcessAssets.getLilyTemplate(): Model?
	local gameProcessAssets = MapProcessAssets.getGameProcessAssets()
	local lily = gameProcessAssets and gameProcessAssets:FindFirstChild("Lily")
	if lily and lily:IsA("Model") then
		return lily
	end
	return nil
end

function MapProcessAssets.getDecorationTemplates(): { Model }
	local gameProcessAssets = MapProcessAssets.getGameProcessAssets()
	local decorationsFolder = gameProcessAssets and gameProcessAssets:FindFirstChild("Decorations")
	if not decorationsFolder then
		return {}
	end

	local templates: { Model } = {}
	for _, child in decorationsFolder:GetChildren() do
		if child:IsA("Model") then
			table.insert(templates, child)
		end
	end
	return templates
end

function MapProcessAssets.findDecorationTemplate(templates: { Model }, name: string): Model?
	for _, template in templates do
		if template.Name == name then
			return template
		end
	end
	return nil
end

function MapProcessAssets.getMinimapDecorationTemplates(decorationTemplates: { Model }, names: { string }): { Model }
	local templates: { Model } = {}
	for _, decorationName in names do
		local template = MapProcessAssets.findDecorationTemplate(decorationTemplates, decorationName)
		if template then
			table.insert(templates, template)
		end
	end
	return templates
end

function MapProcessAssets.getMinimapTreeTemplates(decorationTemplates: { Model }): { Model }
	return MapProcessAssets.getMinimapDecorationTemplates(decorationTemplates, Shared_MapDecorationBlueprint.TreeTemplateNames)
end

function MapProcessAssets.getMinimapRockTemplates(decorationTemplates: { Model }): { Model }
	return MapProcessAssets.getMinimapDecorationTemplates(decorationTemplates, Shared_MapDecorationBlueprint.RockTemplateNames)
end

function MapProcessAssets.getMinimapBushTemplates(decorationTemplates: { Model }): { Model }
	return MapProcessAssets.getMinimapDecorationTemplates(decorationTemplates, Shared_MapDecorationBlueprint.BushTemplateNames)
end

function MapProcessAssets.getFlowerTemplates(): { Model }
	local gameProcessAssets = MapProcessAssets.getGameProcessAssets()
	local flowersFolder = gameProcessAssets and gameProcessAssets:FindFirstChild("Flowers")
	if not flowersFolder then
		return {}
	end

	local templates: { Model } = {}
	for _, child in flowersFolder:GetChildren() do
		if child:IsA("Model") then
			table.insert(templates, child)
		end
	end
	return templates
end

function MapProcessAssets.getGrassTemplates(): { Model }
	local gameProcessAssets = MapProcessAssets.getGameProcessAssets()
	local grassFolder = gameProcessAssets and gameProcessAssets:FindFirstChild("Grass")
	if not grassFolder then
		return {}
	end

	local templates: { Model } = {}
	for _, child in grassFolder:GetChildren() do
		if child:IsA("Model") then
			table.insert(templates, child)
		end
	end
	return templates
end

function MapProcessAssets.getMushroomTemplates(): { Model }
	local gameProcessAssets = MapProcessAssets.getGameProcessAssets()
	local mushroomsFolder = gameProcessAssets and gameProcessAssets:FindFirstChild("Mushrooms")
	if not mushroomsFolder then
		return {}
	end

	local templates: { Model } = {}
	for _, child in mushroomsFolder:GetChildren() do
		if child:IsA("Model") then
			table.insert(templates, child)
		end
	end
	return templates
end

local FLOWER_TOP_COLORS = {
	Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(255, 130, 210),
	Color3.fromRGB(170, 90, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(90, 150, 255),
	Color3.fromRGB(255, 150, 40),
}

function MapProcessAssets.applyFlowerTopColor(flower: Model)
	local colorPart = flower:FindFirstChild("ColorPart")
	if colorPart and colorPart:IsA("BasePart") then
		colorPart.Color = FLOWER_TOP_COLORS[math.random(1, #FLOWER_TOP_COLORS)]
	end
end

function MapProcessAssets.applyLianaFlowerColors(liana: Model)
	local flowersContainer = liana:FindFirstChild("Flowers")
	if not flowersContainer then
		return
	end

	for _, flower in flowersContainer:GetChildren() do
		if flower:IsA("Model") then
			MapProcessAssets.applyFlowerTopColor(flower)
		end
	end
end

function MapProcessAssets.getDecorationExtents(decoration: Model): Vector3
	local extents = decoration:GetExtentsSize()
	if extents.Magnitude > 0 then
		return extents
	end

	local _, size = decoration:GetBoundingBox()
	return size
end

function MapProcessAssets.applyModelScaleRange(model: Model, minScale: number, maxScale: number)
	local originScale = Shared_Weight.GetModelOriginScale(model)
	local scaleMultiplier = minScale + math.random() * (maxScale - minScale)
	model:ScaleTo(originScale * scaleMultiplier)
end

function MapProcessAssets.applyDecorationScale(decoration: Model)
	MapProcessAssets.applyModelScaleRange(decoration, Shared_GameProcess.DecorationScaleMin, Shared_GameProcess.DecorationScaleMax)
end

function MapProcessAssets.applyDecorationScaleKind(decoration: Model, scaleKind: string?)
	if scaleKind == "rock" then
		MapProcessAssets.applyModelScaleRange(decoration, Shared_GameProcess.RockScaleMin, Shared_GameProcess.RockScaleMax)
	elseif scaleKind == "bush" then
		MapProcessAssets.applyModelScaleRange(decoration, Shared_GameProcess.BushScaleMin, Shared_GameProcess.BushScaleMax)
	elseif scaleKind == "tree" then
		MapProcessAssets.applyModelScaleRange(decoration, Shared_GameProcess.TreeScaleMin, Shared_GameProcess.TreeScaleMax)
	else
		MapProcessAssets.applyDecorationScale(decoration)
	end
end

function MapProcessAssets.applyLianaScale(liana: Model)
	local originScale = Shared_Weight.GetModelOriginScale(liana)
	local minScale = Shared_GameProcess.LianaScaleMin
	local maxScale = Shared_GameProcess.LianaScaleMax
	local scaleMultiplier = minScale + math.random() * (maxScale - minScale)
	liana:ScaleTo(originScale * scaleMultiplier)
end

function MapProcessAssets.applyLilyScale(lily: Model)
	MapProcessAssets.applyModelScaleRange(lily, Shared_GameProcess.LilyScaleMin, Shared_GameProcess.LilyScaleMax)
end

function MapProcessAssets.prepareAnchoredModel(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
end

function MapProcessAssets.getLuckyBlockTemplate(configName: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local luckyBlocks = assets and assets:FindFirstChild("LuckyBlocks")
	local template = luckyBlocks and luckyBlocks:FindFirstChild(configName)
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

function MapProcessAssets.prepareLuckyBlockModel(model: Model)
	return Shared_Weight.PrepareLuckyBlockForWorld(model)
end
function MapProcessAssets.getSortedRarities(): { string }
	local rarities: { { Name: string, LayoutOrder: number } } = {}
	for rarityName, rarityData in Shared_Rarities.Data do
		table.insert(rarities, {
			Name = rarityName,
			LayoutOrder = rarityData.LayoutOrder or 0,
		})
	end

	table.sort(rarities, function(a, b)
		if a.LayoutOrder == b.LayoutOrder then
			return a.Name < b.Name
		end
		return a.LayoutOrder < b.LayoutOrder
	end)

	local orderedNames: { string } = {}
	for _, rarity in rarities do
		table.insert(orderedNames, rarity.Name)
	end
	return orderedNames
end

local cachedBuildContext: any = nil

function MapProcessAssets.getBuildContext()
	if cachedBuildContext then
		return cachedBuildContext
	end
	local zones = Workspace:FindFirstChild("Zones")
	local enterPart = zones and zones:FindFirstChild("EnterPart")
	if not enterPart or not enterPart:IsA("BasePart") then
		warn("Missing workspace.Zones.EnterPart")
		return nil
	end

	local floorTemplate = MapProcessAssets.getFloorTemplate()
	if not floorTemplate then
		warn("Missing ReplicatedStorage.Assets.GameProcess.FloorPart")
		return nil
	end

	local wallTemplate = MapProcessAssets.getWallTemplate()
	if not wallTemplate then
		warn("Missing ReplicatedStorage.Assets.GameProcess.Wall")
		return nil
	end

	local decorationTemplates = MapProcessAssets.getDecorationTemplates()
	if #decorationTemplates == 0 then
		warn("Missing ReplicatedStorage.Assets.GameProcess.Decorations models")
	end

	local flowerTemplates = MapProcessAssets.getFlowerTemplates()
	if #flowerTemplates == 0 then
		warn("Missing ReplicatedStorage.Assets.GameProcess.Flowers models")
	end

	local grassTemplates = MapProcessAssets.getGrassTemplates()
	if #grassTemplates == 0 then
		warn("Missing ReplicatedStorage.Assets.GameProcess.Grass models")
	end

	local mushroomTemplates = MapProcessAssets.getMushroomTemplates()
	if #mushroomTemplates == 0 then
		warn("Missing ReplicatedStorage.Assets.GameProcess.Mushrooms models")
	end

	local lianaTemplates = MapProcessAssets.getLianaTemplates()
	if #lianaTemplates == 0 then
		warn("Missing ReplicatedStorage.Assets.GameProcess.Lianas models")
	end

	local lilyTemplate = MapProcessAssets.getLilyTemplate()
	if not lilyTemplate then
		warn("Missing ReplicatedStorage.Assets.GameProcess.Lily model")
	end

	cachedBuildContext = {
		enterPart = enterPart,
		floorTemplate = floorTemplate,
		wallTemplate = wallTemplate,
		decorationTemplates = decorationTemplates,
		flowerTemplates = flowerTemplates,
		grassTemplates = grassTemplates,
		mushroomTemplates = mushroomTemplates,
		lianaTemplates = lianaTemplates,
		lilyTemplate = lilyTemplate,
	}
	return cachedBuildContext
end

return MapProcessAssets
