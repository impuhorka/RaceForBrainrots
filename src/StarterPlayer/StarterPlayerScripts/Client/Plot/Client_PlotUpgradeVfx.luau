local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ClientLoader = require(script.Parent.Parent.Loader)

local Client_PlotBrainrotJump = ClientLoader.require("Client_PlotBrainrotJump")

local Client_PlotUpgradeVfx = {}

local EMIT_COUNT = 1
local LINGER_BUFFER = 0.25

local hookedSlots: { [Model]: boolean } = {}
local hookedPlots: { [Model]: boolean } = {}
local hookedSlotsFolders: { [Folder]: boolean } = {}
local previousLevels: { [Model]: number } = {}
local upgradeEffectCounter = 0

local function getUpgradeEffectTemplate(): Attachment?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local vfxFolder = assets and assets:FindFirstChild("VFX")
	local upgradeEffect = vfxFolder and vfxFolder:FindFirstChild("UpgradeEffect")
	if upgradeEffect and upgradeEffect:IsA("Attachment") then
		return upgradeEffect
	end
	return nil
end

local function collectParticleEmitters(root: Instance): { ParticleEmitter }
	local emitters: { ParticleEmitter } = {}

	for _, descendant in root:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			table.insert(emitters, descendant)
		end
	end

	if root:IsA("ParticleEmitter") then
		table.insert(emitters, root)
	end

	return emitters
end

local function playUpgradeVfx(brainrotModel: Model)
	local primaryPart = brainrotModel.PrimaryPart
	local template = getUpgradeEffectTemplate()
	if not primaryPart or not template then
		return
	end

	upgradeEffectCounter += 1

	local attachment = template:Clone()
	attachment.Name = "UpgradeEffect_" .. upgradeEffectCounter
	attachment.Parent = primaryPart

	local maxLifetime = 0
	for _, emitter in collectParticleEmitters(attachment) do
		for _ = 1, EMIT_COUNT do
			emitter:Emit(1)
		end
		maxLifetime = math.max(maxLifetime, emitter.Lifetime.Max)
	end

	task.delay(maxLifetime + LINGER_BUFFER, function()
		if attachment.Parent then
			attachment:Destroy()
		end
	end)
end

local function onSlotLevelChanged(slotModel: Model)
	local newLevel = slotModel:GetAttribute("Level")
	if type(newLevel) ~= "number" then
		return
	end

	local oldLevel = previousLevels[slotModel]
	previousLevels[slotModel] = newLevel

	if not oldLevel or newLevel <= oldLevel then
		return
	end

	local brainrotModel = slotModel:FindFirstChild("PlacedBrainrot")
	if brainrotModel and brainrotModel:IsA("Model") then
		playUpgradeVfx(brainrotModel)
		task.defer(function()
			RunService.Heartbeat:Wait()
			if brainrotModel.Parent and slotModel.Parent then
				Client_PlotBrainrotJump.PlayUpgrade(brainrotModel, slotModel)
			end
		end)
	end
end

local function hookSlot(slotModel: Model)
	if hookedSlots[slotModel] then
		return
	end
	hookedSlots[slotModel] = true

	previousLevels[slotModel] = slotModel:GetAttribute("Level") or 1

	slotModel:GetAttributeChangedSignal("Level"):Connect(function()
		onSlotLevelChanged(slotModel)
	end)

	slotModel.Destroying:Connect(function()
		hookedSlots[slotModel] = nil
		previousLevels[slotModel] = nil
	end)
end

local function hookSlotsFolder(slotsFolder: Folder)
	if hookedSlotsFolders[slotsFolder] then
		return
	end
	hookedSlotsFolders[slotsFolder] = true

	for _, slotModel in slotsFolder:GetChildren() do
		if slotModel:IsA("Model") then
			hookSlot(slotModel)
		end
	end

	slotsFolder.ChildAdded:Connect(function(slotModel)
		if slotModel:IsA("Model") then
			hookSlot(slotModel)
		end
	end)

	slotsFolder.Destroying:Connect(function()
		hookedSlotsFolders[slotsFolder] = nil
	end)
end

local function hookPlot(plotModel: Model)
	if not hookedPlots[plotModel] then
		hookedPlots[plotModel] = true

		plotModel.ChildAdded:Connect(function(child)
			if child.Name == "Slots" and child:IsA("Folder") then
				hookSlotsFolder(child)
			end
		end)

		plotModel.Destroying:Connect(function()
			hookedPlots[plotModel] = nil
		end)
	end

	local slotsFolder = plotModel:FindFirstChild("Slots")
	if slotsFolder and slotsFolder:IsA("Folder") then
		hookSlotsFolder(slotsFolder)
	end
end

function Client_PlotUpgradeVfx.Init()
	local gameFolder = Workspace:WaitForChild("Game")
	local plotsFolder = gameFolder:WaitForChild("Plots")

	for _, plotModel in plotsFolder:GetChildren() do
		if plotModel:IsA("Model") then
			hookPlot(plotModel)
		end
	end

	plotsFolder.ChildAdded:Connect(function(plotModel)
		if plotModel:IsA("Model") then
			hookPlot(plotModel)
		end
	end)
end

return Client_PlotUpgradeVfx