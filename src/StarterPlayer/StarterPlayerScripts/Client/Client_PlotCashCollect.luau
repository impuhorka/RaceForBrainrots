local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared_Abbreviation = require(ReplicatedStorage.Modules.Utilities.Shared_Abbreviation)

local Client_CashAddingPopups = require(script.Parent.Client_CashAddingPopups)
local Client_PlotBrainrotJump = require(script.Parent.Client_PlotBrainrotJump)

local localPlayer = Players.LocalPlayer

local Client_PlotCashCollect = {}

local COLLECT_COOLDOWN = 1
local ANIM_DURATION = 0.275
local HALF_ANIM_DURATION = ANIM_DURATION * 0.5
local COLLECT_EMIT_COUNT = 5
local COLLECT_EMIT_INTERVAL = 0.02
local COLLECT_VFX_LINGER_BUFFER = 0.25

local hookedSlots: { [Model]: boolean } = {}
local hookedPlots: { [Model]: boolean } = {}
local hookedSlotsFolders: { [Folder]: boolean } = {}
local collectCooldowns: { [Model]: boolean } = {}
local animatingButtons: { [BasePart]: boolean } = {}
local cashCollectEffectCounter = 0
local previousCashToCollect: { [Model]: number } = {}

local plotHandler: RemoteEvent

local function getOwnerUserId(plotModel: Model): number
	return tonumber(plotModel:GetAttribute("OwnerUserId")) or 0
end

local function getSlotId(slotModel: Model): number
	return tonumber(string.match(slotModel.Name, "%d+")) or 0
end

local function getInteractPart(slotModel: Model): BasePart?
	local buttonModel = slotModel:FindFirstChild("Button")
	if not buttonModel then
		return nil
	end

	local interactPart = buttonModel:FindFirstChild("InteractButton")
	if interactPart and interactPart:IsA("BasePart") then
		return interactPart
	end

	return buttonModel:FindFirstChild("InteractButton", true) :: BasePart?
end

local function getCashLabel(interactPart: BasePart): TextLabel?
	local surfaceGui = interactPart:FindFirstChildWhichIsA("SurfaceGui")
	if not surfaceGui then
		return nil
	end

	local textLabel = surfaceGui:FindFirstChild("TextLabel")
	if textLabel and textLabel:IsA("TextLabel") then
		return textLabel
	end

	return surfaceGui:FindFirstChildWhichIsA("TextLabel")
end

local function updateCashLabel(slotModel: Model)
	local interactPart = getInteractPart(slotModel)
	if not interactPart then
		return
	end

	local cashLabel = getCashLabel(interactPart)
	if not cashLabel then
		return
	end

	local cashToCollect = slotModel:GetAttribute("CashToCollect") or 0
	cashLabel.Text = ("$%s"):format(Shared_Abbreviation:Number(cashToCollect))
end

local function getCashCollectEffectTemplate(): Attachment?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local vfxFolder = assets and assets:FindFirstChild("VFX")
	if not vfxFolder then
		return nil
	end

	local cashCollectEffect = vfxFolder:FindFirstChild("CashCollectEffect")
		or vfxFolder:FindFirstChild("CashCollect")
	if cashCollectEffect and cashCollectEffect:IsA("Attachment") then
		return cashCollectEffect
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

local function playCollectVfx(interactPart: BasePart)
	local template = getCashCollectEffectTemplate()
	if not template then
		return
	end

	cashCollectEffectCounter += 1

	local attachment = template:Clone()
	attachment.Name = "CashCollectEffect_" .. cashCollectEffectCounter
	attachment.Parent = interactPart

	local emitters = collectParticleEmitters(attachment)
	local maxLifetime = 0
	for _, emitter in emitters do
		maxLifetime = math.max(maxLifetime, emitter.Lifetime.Max)
	end

	local emitDuration = (COLLECT_EMIT_COUNT - 1) * COLLECT_EMIT_INTERVAL

	task.spawn(function()
		for emitIndex = 1, COLLECT_EMIT_COUNT do
			if not attachment.Parent then
				return
			end

			for _, emitter in emitters do
				emitter:Emit(1)
			end

			if emitIndex < COLLECT_EMIT_COUNT then
				task.wait(COLLECT_EMIT_INTERVAL)
			end
		end
	end)

	task.delay(emitDuration + maxLifetime + COLLECT_VFX_LINGER_BUFFER, function()
		if attachment.Parent then
			attachment:Destroy()
		end
	end)
end

local function playCollectAnimation(interactPart: BasePart)
	if animatingButtons[interactPart] then
		return
	end

	animatingButtons[interactPart] = true

	local originCFrame = interactPart.CFrame
	local downCFrame = originCFrame * CFrame.new(0, -interactPart.Size.Y * 0.5, 0)

	local downTween = TweenService:Create(
		interactPart,
		TweenInfo.new(HALF_ANIM_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = downCFrame }
	)
	local upTween = TweenService:Create(
		interactPart,
		TweenInfo.new(HALF_ANIM_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = originCFrame }
	)

	downTween.Completed:Connect(function()
		upTween:Play()
	end)

	upTween.Completed:Connect(function()
		animatingButtons[interactPart] = nil
	end)

	downTween:Play()
end

local function tryCollect(slotModel: Model, plotModel: Model, interactPart: BasePart)
	if collectCooldowns[slotModel] then
		return
	end

	if getOwnerUserId(plotModel) ~= localPlayer.UserId then
		return
	end

	local cashToCollect = slotModel:GetAttribute("CashToCollect") or 0
	if cashToCollect <= 0 then
		return
	end

	collectCooldowns[slotModel] = true
	playCollectAnimation(interactPart)
	playCollectVfx(interactPart)
	Client_CashAddingPopups.Show(cashToCollect)

	local brainrotModel = slotModel:FindFirstChild("PlacedBrainrot")
	if brainrotModel and brainrotModel:IsA("Model") then
		Client_PlotBrainrotJump.PlayCollect(brainrotModel, slotModel)
	end
	previousCashToCollect[slotModel] = 0

	local slotId = getSlotId(slotModel)
	if slotId > 0 then
		plotHandler:FireServer("Collect", slotId)
	end

	task.delay(COLLECT_COOLDOWN, function()
		collectCooldowns[slotModel] = nil
	end)
end

local function hookSlot(slotModel: Model, plotModel: Model)
	if hookedSlots[slotModel] then
		updateCashLabel(slotModel)
		return
	end
	hookedSlots[slotModel] = true
	previousCashToCollect[slotModel] = slotModel:GetAttribute("CashToCollect") or 0

	local interactPart = getInteractPart(slotModel)
	if interactPart then
		updateCashLabel(slotModel)

		slotModel:GetAttributeChangedSignal("CashToCollect"):Connect(function()
			local newCash = slotModel:GetAttribute("CashToCollect") or 0
			local oldCash = previousCashToCollect[slotModel] or 0
			previousCashToCollect[slotModel] = newCash

			if oldCash > 0 and newCash <= 0 then
				local brainrotModel = slotModel:FindFirstChild("PlacedBrainrot")
				if brainrotModel and brainrotModel:IsA("Model") then
					Client_PlotBrainrotJump.PlayCollect(brainrotModel, slotModel)
				end
			end

			updateCashLabel(slotModel)
		end)

		slotModel:GetAttributeChangedSignal("ConfigName"):Connect(function()
			updateCashLabel(slotModel)
		end)

		interactPart.Touched:Connect(function(hit)
			local character = hit.Parent
			if not character then
				return
			end

			local player = Players:GetPlayerFromCharacter(character)
			if player ~= localPlayer then
				return
			end

			tryCollect(slotModel, plotModel, interactPart)
		end)
	else
		if not slotModel:GetAttribute("_PlotCashWatching") then
			slotModel:SetAttribute("_PlotCashWatching", true)
			slotModel.DescendantAdded:Connect(function()
				if getInteractPart(slotModel) then
					hookSlot(slotModel, plotModel)
				end
			end)
		end
	end

	slotModel.Destroying:Connect(function()
		hookedSlots[slotModel] = nil
		collectCooldowns[slotModel] = nil
		previousCashToCollect[slotModel] = nil
	end)
end

local function hookSlotsFolder(slotsFolder: Folder, plotModel: Model)
	if not hookedSlotsFolders[slotsFolder] then
		hookedSlotsFolders[slotsFolder] = true

		slotsFolder.ChildAdded:Connect(function(slotModel)
			if slotModel:IsA("Model") then
				hookSlot(slotModel, plotModel)
			end
		end)

		slotsFolder.Destroying:Connect(function()
			hookedSlotsFolders[slotsFolder] = nil
		end)
	end

	for _, slotModel in slotsFolder:GetChildren() do
		if slotModel:IsA("Model") then
			hookSlot(slotModel, plotModel)
		end
	end
end

local function hookPlot(plotModel: Model)
	if not hookedPlots[plotModel] then
		hookedPlots[plotModel] = true

		plotModel.ChildAdded:Connect(function(child)
			if child.Name == "Slots" and child:IsA("Folder") then
				hookSlotsFolder(child, plotModel)
			end
		end)

		plotModel.Destroying:Connect(function()
			hookedPlots[plotModel] = nil
		end)
	end

	local slotsFolder = plotModel:FindFirstChild("Slots")
	if slotsFolder and slotsFolder:IsA("Folder") then
		hookSlotsFolder(slotsFolder, plotModel)
	end
end

function Client_PlotCashCollect.Init()
	plotHandler = ReplicatedStorage:WaitForChild("Events"):WaitForChild("PlotHandler") :: RemoteEvent

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

return Client_PlotCashCollect
