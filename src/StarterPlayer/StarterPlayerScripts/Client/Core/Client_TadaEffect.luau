local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ClientLoader = require(script.Parent.Parent.Loader)

local Client_TadaEffect = {}

local TADA_PIECE_COUNT = 50
local TADA_STAGGER_MAX = 0.35

function Client_TadaEffect.Play()
	if not ClientLoader.require("Client_VisualSettings").AreEffectsEnabled() then
		return
	end

	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "TadaEffect"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 500
	gui.Parent = playerGui

	local rainbow = {
		Color3.fromRGB(255, 0, 0),
		Color3.fromRGB(255, 140, 0),
		Color3.fromRGB(255, 255, 0),
		Color3.fromRGB(0, 255, 0),
		Color3.fromRGB(0, 220, 255),
		Color3.fromRGB(0, 80, 255),
		Color3.fromRGB(200, 0, 255),
		Color3.fromRGB(255, 0, 180),
	}

	local activePieces = 0
	local function pieceFinished()
		activePieces -= 1
		if activePieces <= 0 and gui.Parent then
			gui:Destroy()
		end
	end

	for i = 1, TADA_PIECE_COUNT do
		local w = 0.006 + math.random() * 0.008
		local h = w * (1.8 + math.random() * 2.2)

		local fromLeft = (i % 2) == 1

		local startX = if fromLeft then (math.random() * 0.18) else (0.82 + math.random() * 0.18)
		local startY = 0.75 + math.random() * 0.3

		local vy = 1.4 + math.random() * 0.8
		local vx = (if fromLeft then 1 else -1) * (0.3 + math.random() * 0.35)
		local gravity = 2.0 + math.random() * 1.2

		local peakTime = vy / gravity
		local totalTime = math.min(2 * peakTime + 0.3, 2.2)

		local startRot = math.random(-45, 45)
		local spinDir = if fromLeft then 1 else -1
		local spinDeg = spinDir * (120 + math.random() * 180)

		local piece = Instance.new("Frame")
		piece.Name = "TadaPiece_" .. tostring(i)
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = rainbow[math.random(1, #rainbow)]
		piece.BackgroundTransparency = 0
		piece.Size = UDim2.fromScale(w, h)
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromScale(startX, startY)
		piece.Rotation = startRot
		piece.Parent = gui

		activePieces += 1
		local stagger = math.random() * TADA_STAGGER_MAX
		task.delay(stagger, function()
			if not piece.Parent then
				pieceFinished()
				return
			end

			local startTime = os.clock()
			local conn
			conn = RunService.Heartbeat:Connect(function()
				if not piece.Parent then
					conn:Disconnect()
					pieceFinished()
					return
				end

				local elapsed = os.clock() - startTime

				local curX = startX + vx * elapsed
				local curY = startY - vy * elapsed + 0.5 * gravity * elapsed * elapsed

				local t = elapsed / totalTime
				local curRot = startRot + spinDeg * t

				local afterPeak = math.max(0, elapsed - peakTime)
				local fallFraction = math.min(afterPeak / (totalTime - peakTime + 0.001), 1)
				local sizeT = 1 - fallFraction

				piece.Position = UDim2.fromScale(curX, curY)
				piece.Rotation = curRot
				piece.Size = UDim2.fromScale(math.max(w * sizeT, 0.001), math.max(h * sizeT, 0.001))
				piece.BackgroundTransparency = math.min(fallFraction, 1)

				if elapsed >= totalTime or curY > 1.2 then
					conn:Disconnect()
					if piece.Parent then
						piece:Destroy()
					end
					pieceFinished()
				end
			end)
		end)
	end
end

return Client_TadaEffect
