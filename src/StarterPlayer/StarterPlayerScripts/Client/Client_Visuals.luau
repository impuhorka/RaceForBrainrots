local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Client_Data = require(script.Parent.Client_Data)
local Shared_Abbreviation = require(ReplicatedStorage.Modules.Utilities.Shared_Abbreviation)

local Client_Visuals = {}

local STAT_NAMES = { "Cash", "Strength", "Speed" }
local CASH_TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local labels: { [string]: TextLabel } = {}
local cashNormalGradient: UIGradient? = nil
local cashDecreaseGradient: UIGradient? = nil
local cashValueObject = Instance.new("NumberValue")
local cashTween: Tween? = nil
local cashDecreaseVisualToken = 0

local function formatCash(value: number): string
	return ("$%s"):format(Shared_Abbreviation:Number(value or 0))
end

local function formatStrength(value: number): string
	return ("%s Strength"):format(Shared_Abbreviation:Number(value or 0))
end

local function formatSpeed(value: number): string
	return ("%s Speed"):format(Shared_Abbreviation:Number(value or 0))
end

local FORMATTERS = {
	Cash = formatCash,
	Strength = formatStrength,
	Speed = formatSpeed,
}

local function findGradient(root: Instance, gradientName: string): UIGradient?
	local gradient = root:FindFirstChild(gradientName, true)
	if gradient and gradient:IsA("UIGradient") then
		return gradient
	end
	return nil
end

local function setCashDecreaseVisual(isDecreasing: boolean)
	if cashDecreaseGradient then
		cashDecreaseGradient.Enabled = isDecreasing
	end
	if cashNormalGradient then
		cashNormalGradient.Enabled = not isDecreasing
	end
end

local function setCashLabelText(value: number)
	local cashLabel = labels.Cash
	if not cashLabel then
		return
	end

	cashLabel.Text = formatCash(math.max(0, math.round(value)))
end

local function updateCashStat(animate: boolean)
	local cashLabel = labels.Cash
	if not cashLabel then
		return
	end

	local targetCash = Client_Data:GetValue("Cash") or 0
	if not animate then
		if cashTween then
			cashTween:Cancel()
			cashTween = nil
		end
		cashValueObject.Value = targetCash
		setCashLabelText(targetCash)
		setCashDecreaseVisual(false)
		return
	end

	local startCash = cashValueObject.Value
	if targetCash == startCash then
		setCashLabelText(targetCash)
		setCashDecreaseVisual(false)
		return
	end

	if targetCash < startCash then
		if cashTween then
			cashTween:Cancel()
			cashTween = nil
		end
		local oldDisplayed = formatCash(math.max(0, math.round(startCash)))
		local newDisplayed = formatCash(math.max(0, math.round(targetCash)))
		if oldDisplayed ~= newDisplayed then
			cashDecreaseVisualToken += 1
			local token = cashDecreaseVisualToken
			setCashDecreaseVisual(true)
			cashTween = TweenService:Create(cashValueObject, CASH_TWEEN_INFO, {
				Value = targetCash,
			})
			cashTween:Play()
			cashTween.Completed:Once(function(playbackState)
				if playbackState == Enum.PlaybackState.Completed and token == cashDecreaseVisualToken then
					setCashLabelText(targetCash)
					setCashDecreaseVisual(false)
				end
			end)
		else
			cashDecreaseVisualToken += 1
			cashValueObject.Value = targetCash
			setCashLabelText(targetCash)
			setCashDecreaseVisual(false)
		end
		return
	end

	if cashTween then
		cashTween:Cancel()
		cashTween = nil
	end

	setCashDecreaseVisual(false)
	cashTween = TweenService:Create(cashValueObject, CASH_TWEEN_INFO, {
		Value = targetCash,
	})

	cashTween:Play()
	cashTween.Completed:Once(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed then
			setCashLabelText(targetCash)
			setCashDecreaseVisual(false)
		end
	end)
end

local function updateStat(statName: string, animate: boolean?)
	local label = labels[statName]
	local formatter = FORMATTERS[statName]
	if not label or not formatter then
		return
	end

	if statName == "Cash" then
		updateCashStat(animate ~= false)
		return
	end

	label.Text = formatter(Client_Data:GetValue(statName) or 0)
end

local function refreshAll(animate: boolean?)
	for _, statName in STAT_NAMES do
		updateStat(statName, animate)
	end
end

function Client_Visuals.Init()
	Client_Data.WaitUntilReady()

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local visualsFrame = playerGui:WaitForChild("Main"):WaitForChild("Visuals")

	for _, statName in STAT_NAMES do
		local frame = visualsFrame:FindFirstChild(statName)
		if frame then
			local textLabel = frame:FindFirstChild("TextLabel")
			if textLabel and textLabel:IsA("TextLabel") then
				labels[statName] = textLabel
				if statName == "Cash" then
					cashNormalGradient = findGradient(frame, "NormalGradient")
					cashDecreaseGradient = findGradient(frame, "DecreaseGradient")
				end
			else
				warn(("Client_Visuals: missing TextLabel in Visuals.%s"):format(statName))
			end
		else
			warn(("Client_Visuals: missing frame Visuals.%s"):format(statName))
		end
	end

	cashValueObject.Value = Client_Data:GetValue("Cash") or 0
	cashValueObject:GetPropertyChangedSignal("Value"):Connect(function()
		setCashLabelText(cashValueObject.Value)
	end)
	refreshAll(false)
	setCashDecreaseVisual(false)

	for _, statName in STAT_NAMES do
		Client_Data:ListenToChange(statName, function()
			updateStat(statName, true)
		end)
	end
end

return Client_Visuals
