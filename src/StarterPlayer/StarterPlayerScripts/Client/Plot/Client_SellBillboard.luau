local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ClientLoader = require(script.Parent.Parent.Loader)

local Shared_Abbreviation = SharedModules.require("Shared_Abbreviation")
local Shared_Brainrots = SharedModules.require("Shared_Brainrots")
local Shared_Sounds = SharedModules.require("Shared_Sounds")
local Client_Data = ClientLoader.require("Client_Data")
local Client_Equip = ClientLoader.require("Client_Equip")
local Client_Messaging = ClientLoader.require("Client_Messaging")
local Client_SoundPreload = ClientLoader.require("Client_SoundPreload")

local Client_SellBillboard = {}

local ACTIVATE_DISTANCE = 20
local CHECK_INTERVAL = 0.1
local BUTTON_SLIDE_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BUTTON_STAGGER = 0.05
local BUTTON_SFX_STAGGER = BUTTON_STAGGER * 2
local SELL_ONE_HOLD_DURATION = 1.0
local SELL_ALL_HOLD_DURATION = 1.5
local SELL_ALL_PROGRESS_HEIGHT_SCALE = 1.05

local localPlayer = Players.LocalPlayer

local activeAttachment: Attachment? = nil
local activeBillboard: BillboardGui? = nil
local updateConnection: RBXScriptConnection? = nil
local activePriceButtonConnection: RBXScriptConnection? = nil
local activeSellBeginConnection: RBXScriptConnection? = nil
local activeSellEndConnection: RBXScriptConnection? = nil
local sellHoldUpdateConnection: RBXScriptConnection? = nil
local activeSellAllBeginConnection: RBXScriptConnection? = nil
local activeSellAllEndConnection: RBXScriptConnection? = nil
local sellAllHoldUpdateConnection: RBXScriptConnection? = nil
local sellResponseConnection: RBXScriptConnection? = nil
local isAnimatingOut = false
local isSellPending = false
local isSellHolding = false
local isSellAllHolding = false
local sellHoldStart = 0
local sellAllHoldStart = 0
local sellProgressFrame: Frame? = nil
local sellAllProgressFrame: Frame? = nil

local function playUiPopSfx()
	local soundId = Shared_Sounds.SFX and Shared_Sounds.SFX.UiPop or ""
	if type(soundId) ~= "string" or soundId == "" then
		return
	end
	Client_SoundPreload.PlayUi(soundId, 1, 1)
end

local function getAnimatedFrames(billboard: BillboardGui): { GuiObject }
	local rootFrame = billboard:FindFirstChild("Frame")
	if not rootFrame or not rootFrame:IsA("Frame") then
		return {}
	end

	local containers: { GuiObject } = {}
	for _, container in rootFrame:GetChildren() do
		if container:IsA("GuiObject") then
			table.insert(containers, container)
		end
	end

	table.sort(containers, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)

	local animatedFrames: { GuiObject } = {}
	for _, container in containers do
		local animatedFrame = container:FindFirstChild("Frame")
		if not animatedFrame or not animatedFrame:IsA("GuiObject") then
			for _, child in container:GetChildren() do
				if child:IsA("GuiObject") and child:FindFirstChildWhichIsA("ImageButton") then
					animatedFrame = child
					break
				end
			end
		end

		if animatedFrame and animatedFrame:IsA("GuiObject") then
			table.insert(animatedFrames, animatedFrame)
		end
	end

	return animatedFrames
end

local function animateBillboardButtonsIn(billboard: BillboardGui)
	local animatedFrames = getAnimatedFrames(billboard)
	for index, frameToTween in animatedFrames do
		frameToTween.Position = UDim2.new(-1, frameToTween.Position.X.Offset, 0.5, frameToTween.Position.Y.Offset)
		task.delay((index - 1) * BUTTON_SFX_STAGGER, function()
			if frameToTween.Parent then
				playUiPopSfx()
			end
		end)
		task.delay((index - 1) * BUTTON_STAGGER, function()
			if not frameToTween.Parent then
				return
			end
			TweenService:Create(frameToTween, BUTTON_SLIDE_TWEEN, {
				Position = UDim2.new(0, frameToTween.Position.X.Offset, 0.5, frameToTween.Position.Y.Offset),
			}):Play()
		end)
	end
end

local function destroyActiveBillboardNow()
	if activePriceButtonConnection then
		activePriceButtonConnection:Disconnect()
		activePriceButtonConnection = nil
	end
	if activeSellBeginConnection then
		activeSellBeginConnection:Disconnect()
		activeSellBeginConnection = nil
	end
	if activeSellEndConnection then
		activeSellEndConnection:Disconnect()
		activeSellEndConnection = nil
	end
	if sellHoldUpdateConnection then
		sellHoldUpdateConnection:Disconnect()
		sellHoldUpdateConnection = nil
	end
	if activeSellAllBeginConnection then
		activeSellAllBeginConnection:Disconnect()
		activeSellAllBeginConnection = nil
	end
	if activeSellAllEndConnection then
		activeSellAllEndConnection:Disconnect()
		activeSellAllEndConnection = nil
	end
	if sellAllHoldUpdateConnection then
		sellAllHoldUpdateConnection:Disconnect()
		sellAllHoldUpdateConnection = nil
	end
	isSellHolding = false
	isSellAllHolding = false
	sellProgressFrame = nil
	sellAllProgressFrame = nil

	if activeBillboard then
		activeBillboard:Destroy()
		activeBillboard = nil
	end
	if activeAttachment then
		activeAttachment:Destroy()
		activeAttachment = nil
	end
	isAnimatingOut = false
end

local function getPriceButton(billboard: BillboardGui): ImageButton?
	local root = billboard:FindFirstChild("PriceOfThisBrainrot", true)
	if not root then
		return nil
	end

	local inner = root:FindFirstChild("Frame")
	if inner and inner:IsA("GuiObject") then
		local direct = inner:FindFirstChild("ImageButton")
		if direct and direct:IsA("ImageButton") then
			return direct
		end
	end

	local fallback = root:FindFirstChild("ImageButton", true)
	if fallback and fallback:IsA("ImageButton") then
		return fallback
	end

	return nil
end

local function getSellButton(billboard: BillboardGui): ImageButton?
	local root = billboard:FindFirstChild("SellThisBrainrot", true)
	if not root then
		return nil
	end

	local inner = root:FindFirstChild("Frame")
	if inner and inner:IsA("GuiObject") then
		local direct = inner:FindFirstChild("ImageButton")
		if direct and direct:IsA("ImageButton") then
			return direct
		end
	end

	local fallback = root:FindFirstChild("ImageButton", true)
	if fallback and fallback:IsA("ImageButton") then
		return fallback
	end

	return nil
end

local function getSellProgressFrame(billboard: BillboardGui): Frame?
	local root = billboard:FindFirstChild("SellThisBrainrot", true)
	if not root then
		return nil
	end

	local outer = root:FindFirstChild("Frame")
	if not outer or not outer:IsA("GuiObject") then
		return nil
	end

	local progress = outer:FindFirstChild("Frame")
	if progress and progress:IsA("Frame") then
		return progress
	end

	return nil
end

local function getSellAllButton(billboard: BillboardGui): ImageButton?
	local root = billboard:FindFirstChild("SellAllBrainrots", true)
	if not root then
		return nil
	end

	local inner = root:FindFirstChild("Frame")
	if inner and inner:IsA("GuiObject") then
		local direct = inner:FindFirstChild("ImageButton")
		if direct and direct:IsA("ImageButton") then
			return direct
		end
	end

	local fallback = root:FindFirstChild("ImageButton", true)
	if fallback and fallback:IsA("ImageButton") then
		return fallback
	end

	return nil
end

local function getSellAllProgressFrame(billboard: BillboardGui): Frame?
	local root = billboard:FindFirstChild("SellAllBrainrots", true)
	if not root then
		return nil
	end

	local outer = root:FindFirstChild("Frame")
	if not outer or not outer:IsA("GuiObject") then
		return nil
	end

	local progress = outer:FindFirstChild("Frame")
	if progress and progress:IsA("Frame") then
		return progress
	end

	return nil
end

local function getEquippedBrainrotSellCost(): number?
	local equippedIndex = Client_Equip.GetEquippedIndex()
	if not equippedIndex then
		return nil
	end

	local inventory = Client_Data:GetValue("Inventory") or {}
	local item = inventory[equippedIndex]
	if not item or item.ItemType ~= "Brainrot" or type(item.ConfigName) ~= "string" then
		return nil
	end

	local level = math.max(1, item.Data and item.Data.Level or 1)
	local modifier = item.Data and item.Data.Modifier or "Normal"
	return Shared_Brainrots.GetSellWorth(item.ConfigName, level, modifier)
end

local function hookPriceButton(billboard: BillboardGui)
	if activePriceButtonConnection then
		activePriceButtonConnection:Disconnect()
		activePriceButtonConnection = nil
	end

	local priceButton = getPriceButton(billboard)
	if not priceButton then
		return
	end

	activePriceButtonConnection = priceButton.MouseButton1Click:Connect(function()
		local sellCost = getEquippedBrainrotSellCost()
		if not sellCost then
			Client_Messaging.Show("Equip a brainrot to check his price!", "red")
			return
		end

		Client_Messaging.Show(("I can give you $%s for this brainrot."):format(Shared_Abbreviation:Number(sellCost)), "green")
	end)
end

local function hookSellButton(billboard: BillboardGui)
	if activeSellBeginConnection then
		activeSellBeginConnection:Disconnect()
		activeSellBeginConnection = nil
	end
	if activeSellEndConnection then
		activeSellEndConnection:Disconnect()
		activeSellEndConnection = nil
	end
	if sellHoldUpdateConnection then
		sellHoldUpdateConnection:Disconnect()
		sellHoldUpdateConnection = nil
	end

	local sellButton = getSellButton(billboard)
	if not sellButton then
		return
	end

	sellProgressFrame = getSellProgressFrame(billboard)
	if sellProgressFrame then
		sellProgressFrame.Size = UDim2.new(0, 0, SELL_ALL_PROGRESS_HEIGHT_SCALE, 0)
	end

	local function setProgress(progress: number)
		if sellProgressFrame then
			sellProgressFrame.Size = UDim2.new(math.clamp(progress, 0, 1), 0, SELL_ALL_PROGRESS_HEIGHT_SCALE, 0)
		end
	end

	local function stopHold(resetProgress: boolean)
		isSellHolding = false
		if sellHoldUpdateConnection then
			sellHoldUpdateConnection:Disconnect()
			sellHoldUpdateConnection = nil
		end
		if resetProgress then
			setProgress(0)
		end
	end

	local function trySellOne()
		local equippedIndex = Client_Equip.GetEquippedIndex()
		if not equippedIndex then
			Client_Messaging.Show("Equip a brainrot that you would like to sell!", "red")
			stopHold(true)
			return
		end

		local inventory = Client_Data:GetValue("Inventory") or {}
		local item = inventory[equippedIndex]
		if not item or item.ItemType ~= "Brainrot" then
			Client_Messaging.Show("Equip a brainrot that you would like to sell!", "red")
			stopHold(true)
			return
		end

		local events = ReplicatedStorage:FindFirstChild("Events")
		local plotHandler = events and events:FindFirstChild("PlotHandler")
		if not plotHandler or not plotHandler:IsA("RemoteEvent") then
			Client_Messaging.Show("Sell service unavailable.", "red")
			stopHold(true)
			return
		end

		isSellPending = true
		stopHold(false)
		setProgress(1)
		plotHandler:FireServer("SellEquipped", equippedIndex)
	end

	activeSellBeginConnection = sellButton.InputBegan:Connect(function(input: InputObject)
		if isSellPending or isSellHolding then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		isSellHolding = true
		sellHoldStart = tick()
		setProgress(0)

		if sellHoldUpdateConnection then
			sellHoldUpdateConnection:Disconnect()
		end
		sellHoldUpdateConnection = RunService.RenderStepped:Connect(function()
			if not isSellHolding then
				return
			end

			local heldFor = tick() - sellHoldStart
			local progress = heldFor / SELL_ONE_HOLD_DURATION
			setProgress(progress)
			if progress >= 1 then
				trySellOne()
			end
		end)
	end)

	activeSellEndConnection = sellButton.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if isSellHolding and not isSellPending then
			stopHold(true)
		end
	end)
end

local function hookSellAllButton(billboard: BillboardGui)
	if activeSellAllBeginConnection then
		activeSellAllBeginConnection:Disconnect()
		activeSellAllBeginConnection = nil
	end
	if activeSellAllEndConnection then
		activeSellAllEndConnection:Disconnect()
		activeSellAllEndConnection = nil
	end
	if sellAllHoldUpdateConnection then
		sellAllHoldUpdateConnection:Disconnect()
		sellAllHoldUpdateConnection = nil
	end

	local sellAllButton = getSellAllButton(billboard)
	if not sellAllButton then
		return
	end
	sellAllProgressFrame = getSellAllProgressFrame(billboard)
	if sellAllProgressFrame then
		sellAllProgressFrame.Size = UDim2.new(0, 0, SELL_ALL_PROGRESS_HEIGHT_SCALE, 0)
	end

	local function setProgress(progress: number)
		if sellAllProgressFrame then
			sellAllProgressFrame.Size = UDim2.new(math.clamp(progress, 0, 1), 0, SELL_ALL_PROGRESS_HEIGHT_SCALE, 0)
		end
	end

	local function stopHold(resetProgress: boolean)
		isSellAllHolding = false
		if sellAllHoldUpdateConnection then
			sellAllHoldUpdateConnection:Disconnect()
			sellAllHoldUpdateConnection = nil
		end
		if resetProgress then
			setProgress(0)
		end
	end

	local function trySellAll()
		local inventory = Client_Data:GetValue("Inventory") or {}
		local hasBrainrot = false
		for _, item in inventory do
			if item and item.ItemType == "Brainrot" then
				hasBrainrot = true
				break
			end
		end
		if not hasBrainrot then
			Client_Messaging.Show("You don't have any brainrots to sell.", "red")
			stopHold(true)
			return
		end

		local events = ReplicatedStorage:FindFirstChild("Events")
		local plotHandler = events and events:FindFirstChild("PlotHandler")
		if not plotHandler or not plotHandler:IsA("RemoteEvent") then
			Client_Messaging.Show("Sell service unavailable.", "red")
			stopHold(true)
			return
		end

		isSellPending = true
		stopHold(false)
		setProgress(1)
		plotHandler:FireServer("SellAllBrainrots")
	end

	activeSellAllBeginConnection = sellAllButton.InputBegan:Connect(function(input: InputObject)
		if isSellPending or isSellAllHolding then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		isSellAllHolding = true
		sellAllHoldStart = tick()
		setProgress(0)

		if sellAllHoldUpdateConnection then
			sellAllHoldUpdateConnection:Disconnect()
		end
		sellAllHoldUpdateConnection = RunService.RenderStepped:Connect(function()
			if not isSellAllHolding then
				return
			end

			local heldFor = tick() - sellAllHoldStart
			local progress = heldFor / SELL_ALL_HOLD_DURATION
			setProgress(progress)
			if progress >= 1 then
				trySellAll()
			end
		end)
	end)

	activeSellAllEndConnection = sellAllButton.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if isSellAllHolding and not isSellPending then
			stopHold(true)
		end
	end)
end


local function getSellPrimaryPart(): BasePart?
	local gameFolder = Workspace:FindFirstChild("Game")
	local interact = gameFolder and gameFolder:FindFirstChild("Interact")
	local sell = interact and interact:FindFirstChild("Sell")
	local pipiPotato = sell and sell:FindFirstChild("PipiPotato")
	if pipiPotato and pipiPotato:IsA("Model") then
		if pipiPotato.PrimaryPart then
			return pipiPotato.PrimaryPart
		end
		local firstPart = pipiPotato:FindFirstChildWhichIsA("BasePart", true)
		if firstPart then
			return firstPart
		end
	end
	return nil
end

local function getCharacterTorso(character: Model?): BasePart?
	if not character then
		return nil
	end

	local customCharacter = character:FindFirstChild("CustomCharacter")
	if customCharacter then
		local main = customCharacter:FindFirstChild("Main")
		if main and main:IsA("BasePart") then
			return main
		end
	end

	return character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("HumanoidRootPart")
		or character.PrimaryPart
end

local function clearActiveBillboard(instant: boolean?)
	if not activeBillboard and not activeAttachment then
		isAnimatingOut = false
		return
	end

	if instant then
		destroyActiveBillboardNow()
		return
	end

	if isAnimatingOut then
		return
	end
	isAnimatingOut = true

	local billboardRef = activeBillboard
	local attachmentRef = activeAttachment
	if not billboardRef or not attachmentRef then
		destroyActiveBillboardNow()
		return
	end

	local animatedFrames = getAnimatedFrames(billboardRef)
	if #animatedFrames == 0 then
		destroyActiveBillboardNow()
		return
	end

	for i = #animatedFrames, 1, -1 do
		local frameToTween = animatedFrames[i]
		local reverseIndex = (#animatedFrames - i)
		task.delay(reverseIndex * BUTTON_STAGGER, function()
			if not frameToTween.Parent then
				return
			end
			TweenService:Create(frameToTween, BUTTON_SLIDE_TWEEN, {
				Position = UDim2.new(-1.35, frameToTween.Position.X.Offset, 0.5, frameToTween.Position.Y.Offset),
			}):Play()
		end)
	end

	local totalDuration = (#animatedFrames - 1) * BUTTON_STAGGER + BUTTON_SLIDE_TWEEN.Time + 0.03
	task.delay(totalDuration, function()
		if activeBillboard == billboardRef and activeAttachment == attachmentRef then
			destroyActiveBillboardNow()
		end
	end)
end

local function ensureSellBillboardOnTorso(torso: BasePart)
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	if activeAttachment and activeAttachment.Parent == torso and activeBillboard and activeBillboard.Parent == playerGui then
		return
	end

	clearActiveBillboard(true)

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local billboards = assets and assets:FindFirstChild("Billboards")
	local template = billboards and billboards:FindFirstChild("SellBillboard")
	if not template or not template:IsA("BillboardGui") then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "SellBillboardAttachment"
	attachment.Parent = torso

	local billboard = template:Clone()
	billboard.Adornee = attachment
	billboard.Parent = playerGui
	animateBillboardButtonsIn(billboard)
	hookPriceButton(billboard)
	hookSellButton(billboard)
	hookSellAllButton(billboard)

	activeAttachment = attachment
	activeBillboard = billboard
end

local function update()
	local targetPart = getSellPrimaryPart()
	local torso = getCharacterTorso(localPlayer.Character)
	if not targetPart or not torso then
		clearActiveBillboard()
		return
	end

	local distance = (torso.Position - targetPart.Position).Magnitude
	if distance <= ACTIVATE_DISTANCE then
		ensureSellBillboardOnTorso(torso)
	else
		clearActiveBillboard()
	end
end

function Client_SellBillboard.Init()
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end

	if sellResponseConnection then
		sellResponseConnection:Disconnect()
		sellResponseConnection = nil
	end

	local events = ReplicatedStorage:WaitForChild("Events")
	local plotHandler = events:WaitForChild("PlotHandler") :: RemoteEvent
	sellResponseConnection = plotHandler.OnClientEvent:Connect(function(action: string, payload: any, payload2: any)
		if action == "SellEquippedSuccess" then
			isSellPending = false
			if sellProgressFrame then
				sellProgressFrame.Size = UDim2.new(0, 0, SELL_ALL_PROGRESS_HEIGHT_SCALE, 0)
			end
			Client_Equip.Unequip()
			Client_Messaging.Show(
				("Sold equipped brainrot for $%s!"):format(Shared_Abbreviation:Number(payload or 0)),
				"green"
			)
		elseif action == "SellEquippedFailed" then
			isSellPending = false
			if sellProgressFrame then
				sellProgressFrame.Size = UDim2.new(0, 0, SELL_ALL_PROGRESS_HEIGHT_SCALE, 0)
			end
			Client_Messaging.Show("Equip a brainrot that you would like to sell!", "red")
		elseif action == "SellAllBrainrotsSuccess" then
			isSellPending = false
			if sellAllProgressFrame then
				sellAllProgressFrame.Size = UDim2.new(0, 0, SELL_ALL_PROGRESS_HEIGHT_SCALE, 0)
			end
			Client_Equip.Unequip()
			Client_Messaging.Show(
				("Sold %s brainrots for $%s!"):format(tostring(payload or 0), Shared_Abbreviation:Number(payload2 or 0)),
				"green"
			)
		elseif action == "SellAllBrainrotsFailed" then
			isSellPending = false
			if sellAllProgressFrame then
				sellAllProgressFrame.Size = UDim2.new(0, 0, SELL_ALL_PROGRESS_HEIGHT_SCALE, 0)
			end
			Client_Messaging.Show("You don't have any brainrots to sell.", "red")
		end
	end)

	local elapsed = 0
	updateConnection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CHECK_INTERVAL then
			return
		end
		elapsed = 0
		update()
	end)

	localPlayer.CharacterRemoving:Connect(function()
		isSellPending = false
		isSellHolding = false
		clearActiveBillboard(true)
	end)
end

return Client_SellBillboard