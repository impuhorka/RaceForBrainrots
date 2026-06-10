local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local ServerScriptService = game:GetService("ServerScriptService")

local Server_Data = require(ServerScriptService.Core.Server_Data)
local Shared_ProximityPrompt = SharedModules.require("Shared_ProximityPrompt")

local GameProcessService = {}

local collecting: { [Model]: boolean } = {}

function GameProcessService.CollectWorldLuckyBlock(player: Player, luckyBlock: Model)
	if collecting[luckyBlock] or not luckyBlock.Parent then
		return
	end

	collecting[luckyBlock] = true

	local configName = luckyBlock:GetAttribute("ConfigName")
	if type(configName) ~= "string" or configName == "" then
		collecting[luckyBlock] = nil
		return
	end

	local baseWeight = luckyBlock:GetAttribute("BaseWeight")
	local weight = luckyBlock:GetAttribute("Weight")
	local itemData: { [string]: number } = {}

	if type(baseWeight) == "number" then
		itemData.BaseWeight = baseWeight
	end
	if type(weight) == "number" then
		itemData.Weight = weight
	end

	local newIndex = Server_Data:AddInventoryItem(player, {
		ItemType = "LuckyBlock",
		ConfigName = configName,
		Data = itemData,
	})

	if newIndex then
		luckyBlock:Destroy()
	end

	collecting[luckyBlock] = nil
end

function GameProcessService.SetupWorldLuckyBlock(luckyBlock: Model)
	luckyBlock:SetAttribute("IsWorldLuckyBlock", true)

	local primaryPart = luckyBlock.PrimaryPart
	if not primaryPart then
		return
	end

	for _, descendant in luckyBlock:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
		end
	end

	local bboxCF, _ = luckyBlock:GetBoundingBox()
	local attachment = primaryPart:FindFirstChild("CollectAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		attachment = Instance.new("Attachment")
		attachment.Name = "CollectAttachment"
		attachment.Parent = primaryPart
	end
	attachment.Position = primaryPart.CFrame:PointToObjectSpace(bboxCF.Position)

	local pickUpPreset = Shared_ProximityPrompt.GetPreset("PickUpWorld")
	local pickupDistance = (pickUpPreset.MaxActivationDistance or 6) * 2

	local prompt = Shared_ProximityPrompt.Create(attachment, {
		Preset = "PickUpWorld",
		ActionText = "Pick Up",
		ObjectText = "",
		MaxActivationDistance = pickupDistance,
	})

	prompt.Triggered:Connect(function(player)
		GameProcessService.CollectWorldLuckyBlock(player, luckyBlock)
	end)
end

return GameProcessService