local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server_Data = require(script.Parent.Server_Data)

local Server_Settings = {}

local VOLUME_KEYS = {
	Music = true,
	SFX = true,
}

local BOOLEAN_KEYS = {
	Animations = true,
	PopUps = true,
}

function Server_Settings.Init()
	local settingsHandler = ReplicatedStorage:WaitForChild("Events"):WaitForChild("SettingsHandler") :: RemoteEvent

	settingsHandler.OnServerEvent:Connect(function(player: Player, action: string, key: any, value: any)
		if action ~= "Set" then
			return
		end
		if type(key) ~= "string" then
			return
		end

		if VOLUME_KEYS[key] then
			if type(value) ~= "number" then
				return
			end
			value = math.clamp(value, 0, 1)
		elseif BOOLEAN_KEYS[key] then
			if type(value) ~= "boolean" then
				return
			end
		else
			return
		end

		Server_Data:SetValue(player, key, value)
	end)
end

return Server_Settings
