local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared_Brainrots = require(script.Parent.Shared_Brainrots)

local Shared_BrainrotAssets = {}

local VIP_ASSET_FOLDER = "VIP"

local function getAssetsFolder(): Instance?
	return ReplicatedStorage:FindFirstChild("Assets")
end

local function getBrainrotsRoot(): Instance?
	local assets = getAssetsFolder()
	return assets and assets:FindFirstChild("Brainrots")
end

function Shared_BrainrotAssets.GetAssetName(configName: string): string
	local config = Shared_Brainrots.Data[configName]
	if config and type(config.AssetName) == "string" and config.AssetName ~= "" then
		return config.AssetName
	end
	return configName
end

local function findNamedChild(parent: Instance?, name: string): Instance?
	if not parent then
		return nil
	end

	local direct = parent:FindFirstChild(name)
	if direct then
		return direct
	end

	local normalizedTarget = string.lower(name)
	for _, child in parent:GetChildren() do
		if string.lower(child.Name) == normalizedTarget then
			return child
		end
	end

	return nil
end

function Shared_BrainrotAssets.FindBrainrotContainer(configName: string): Instance?
	local brainrotsRoot = getBrainrotsRoot()
	if not brainrotsRoot then
		return nil
	end

	local assetName = Shared_BrainrotAssets.GetAssetName(configName)
	local candidates = { assetName, configName }

	for _, candidateName in candidates do
		local direct = findNamedChild(brainrotsRoot, candidateName)
		if direct then
			return direct
		end

		local vipFolder = brainrotsRoot:FindFirstChild(VIP_ASSET_FOLDER)
		local vipChild = findNamedChild(vipFolder, candidateName)
		if vipChild then
			return vipChild
		end
	end

	return nil
end

function Shared_BrainrotAssets.GetTemplate(configName: string, modifier: string?): Model?
	local container = Shared_BrainrotAssets.FindBrainrotContainer(configName)
	if not container then
		return nil
	end

	if container:IsA("Model") then
		return container
	end

	local resolvedModifier = if type(modifier) == "string" and modifier ~= "" then modifier else "Normal"
	local template = container:FindFirstChild(resolvedModifier) or container:FindFirstChild("Normal")
	if template and template:IsA("Model") then
		return template
	end

	template = container:FindFirstChildWhichIsA("Model")
	if template and template:IsA("Model") then
		return template
	end

	return nil
end

function Shared_BrainrotAssets.CloneModel(configName: string, modifier: string?): Model?
	local template = Shared_BrainrotAssets.GetTemplate(configName, modifier)
	if not template then
		return nil
	end

	local model = template:Clone()
	model.Name = configName
	return model
end

function Shared_BrainrotAssets.HasAssets(configName: string, modifier: string?): boolean
	return Shared_BrainrotAssets.GetTemplate(configName, modifier) ~= nil
end

function Shared_BrainrotAssets.GetVIPExclusiveConfigNames(): { string }
	local names: { string } = {}
	for configName, config in Shared_Brainrots.Data do
		if config.IsVIPExclusive == true then
			table.insert(names, configName)
		end
	end
	table.sort(names)
	return names
end

function Shared_BrainrotAssets.ValidateVIPAssets(): { string }
	local missing: { string } = {}
	for _, configName in Shared_BrainrotAssets.GetVIPExclusiveConfigNames() do
		if not Shared_BrainrotAssets.HasAssets(configName, "Normal") then
			table.insert(missing, configName)
		end
	end
	return missing
end

return Shared_BrainrotAssets
