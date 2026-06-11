local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_MapDecorationBlueprint = SharedModules.require("Shared_MapDecorationBlueprint")

local MapProcessDecorationQuery = {}

export type ZoneDecorationIndex = {
	byZoneKey: { [string]: { Model } },
}

local function zoneKey(rarityName: string, holeSide: string): string
	return `{rarityName}|{holeSide}`
end

function MapProcessDecorationQuery.isMapDecoration(instance: Instance): boolean
	return instance:IsA("Model") and instance:GetAttribute("IsClientMapDecoration") == true
end

function MapProcessDecorationQuery.collectMapDecorationModels(root: Instance): { Model }
	local models: { Model } = {}
	for _, child in root:GetChildren() do
		if MapProcessDecorationQuery.isMapDecoration(child) then
			table.insert(models, child)
		end
	end
	return models
end

function MapProcessDecorationQuery.buildZoneDecorationIndex(models: { Model }): ZoneDecorationIndex
	local byZoneKey: { [string]: { Model } } = {}
	for _, model in models do
		local rarity = model:GetAttribute("Rarity")
		local holeSide = model:GetAttribute("HoleSide")
		if type(rarity) ~= "string" or type(holeSide) ~= "string" then
			continue
		end

		local key = zoneKey(rarity, holeSide)
		local bucket = byZoneKey[key]
		if not bucket then
			bucket = {}
			byZoneKey[key] = bucket
		end
		table.insert(bucket, model)
	end

	return {
		byZoneKey = byZoneKey,
	}
end

function MapProcessDecorationQuery.getZoneModels(
	index: ZoneDecorationIndex,
	rarityName: string,
	holeSide: string
): { Model }
	return index.byZoneKey[zoneKey(rarityName, holeSide)] or {}
end

function MapProcessDecorationQuery.countNonTreeDecorationSteps(models: { Model }): number
	local steps = 0
	for _, model in models do
		local folder = model:GetAttribute("MapDecorationFolder")
		local template = model:GetAttribute("MapDecorationTemplate")
		if folder == "Decorations"
			and Shared_MapDecorationBlueprint.TemplateInList(template, Shared_MapDecorationBlueprint.TreeTemplateNames)
		then
			continue
		end
		steps += 1
	end
	return steps
end

function MapProcessDecorationQuery.modelOverlapsHoleFloor(model: Model, holeFloor: BasePart): boolean
	local bboxCF, bboxSize = model:GetBoundingBox()
	local halfX = bboxSize.X / 2
	local halfZ = bboxSize.Z / 2
	local distX = math.abs(bboxCF.Position.X - holeFloor.Position.X)
	local distZ = math.abs(bboxCF.Position.Z - holeFloor.Position.Z)
	return distX <= holeFloor.Size.X / 2 + halfX and distZ <= holeFloor.Size.Z / 2 + halfZ
end

return MapProcessDecorationQuery
