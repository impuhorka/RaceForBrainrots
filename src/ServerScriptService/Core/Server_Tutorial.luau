local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_Tutorial = SharedModules.require("Shared_Tutorial")
local Server_Data = require(script.Parent.Server_Data)

local Server_Tutorial = {}

local tutorialHandler: RemoteEvent? = nil

function Server_Tutorial.Init()
	local events = ReplicatedStorage:WaitForChild("Events")
	tutorialHandler = events:WaitForChild("TutorialHandler") :: RemoteEvent

	tutorialHandler.OnServerEvent:Connect(function(player: Player, action: string, stepId: any)
		if action ~= "CompleteStep" or type(stepId) ~= "number" then
			return
		end

		local step = Shared_Tutorial.GetStep(stepId)
		if not step then
			return
		end

		if Server_Data:GetValue(player, "TutorialCompleted") == true then
			return
		end

		if stepId >= Shared_Tutorial.GetStepCount() then
			Server_Data:SetValue(player, "TutorialCompleted", true)
		end

		if tutorialHandler then
			tutorialHandler:FireClient(player, "StepCompleted", stepId)
		end
	end)
end

return Server_Tutorial
