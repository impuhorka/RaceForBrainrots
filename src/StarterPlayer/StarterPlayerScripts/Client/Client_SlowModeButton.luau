local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client_Data = require(script.Parent.Client_Data)

local TAG = "SlowModeButton"

local Client_SlowModeButton = {}

local plotHandler: RemoteEvent?
local activeConnections: { [ImageButton]: RBXScriptConnection } = {}

local function setGradientEnabled(button: ImageButton, gradientName: string, enabled: boolean)
	local gradient = button:FindFirstChild(gradientName, true)
	if gradient and gradient:IsA("UIGradient") then
		gradient.Enabled = enabled
	end
end

local function setStatusText(button: ImageButton, enabled: boolean)
	local status = button:FindFirstChild("Status", true)
	if status and status:IsA("TextLabel") then
		status.Text = if enabled then "ON" else "OFF"
	end
end

local function applyButtonState(button: ImageButton, enabled: boolean)
	setGradientEnabled(button, "GreenGradient", enabled)
	setGradientEnabled(button, "RedGradient", not enabled)
	setStatusText(button, enabled)
end

local function applyAllButtons()
	local slowModeEnabled = Client_Data:GetValue("SlowMode") == true
	for button in activeConnections do
		applyButtonState(button, slowModeEnabled)
	end
end

local function getTaggedButton(instance: Instance): ImageButton?
	if instance:IsA("ImageButton") then
		return instance
	end

	local nested = instance:FindFirstChildWhichIsA("ImageButton", true)
	if nested then
		return nested
	end

	return nil
end

local function setupButton(instance: Instance)
	local button = getTaggedButton(instance)
	if not button or activeConnections[button] then
		return
	end

	activeConnections[button] = button.MouseButton1Click:Connect(function()
		if not plotHandler then
			return
		end
		local currentEnabled = Client_Data:GetValue("SlowMode") == true
		plotHandler:FireServer("SetSlowMode", not currentEnabled)
	end)

	applyButtonState(button, Client_Data:GetValue("SlowMode") == true)

	button.Destroying:Connect(function()
		local connection = activeConnections[button]
		if connection then
			connection:Disconnect()
			activeConnections[button] = nil
		end
	end)
end

local function teardownButton(instance: Instance)
	local button = getTaggedButton(instance)
	if not button then
		return
	end

	local connection = activeConnections[button]
	if connection then
		connection:Disconnect()
		activeConnections[button] = nil
	end
end

function Client_SlowModeButton.Init()
	Client_Data.WaitUntilReady()
	local events = ReplicatedStorage:WaitForChild("Events")
	plotHandler = events:WaitForChild("PlotHandler") :: RemoteEvent

	for _, instance in CollectionService:GetTagged(TAG) do
		setupButton(instance)
	end

	CollectionService:GetInstanceAddedSignal(TAG):Connect(setupButton)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(teardownButton)

	Client_Data:ListenToChange("SlowMode", function()
		applyAllButtons()
	end)
end

return Client_SlowModeButton
