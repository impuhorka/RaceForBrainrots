local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server_Data = require(script.Parent.Server_Data)

local Server_FavoritePrompt = {}

function Server_FavoritePrompt.Init()
	local favoritePromptHandler = ReplicatedStorage:WaitForChild("Events"):WaitForChild("FavoritePromptHandler") :: RemoteEvent

	favoritePromptHandler.OnServerEvent:Connect(function(player: Player, action: string)
		if action ~= "MarkShown" then
			return
		end

		if Server_Data:GetValue(player, "FavoritePromptShown") == true then
			return
		end

		Server_Data:SetValue(player, "FavoritePromptShown", true)
	end)
end

return Server_FavoritePrompt
