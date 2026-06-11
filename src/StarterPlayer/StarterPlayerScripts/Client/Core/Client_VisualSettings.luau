local ClientLoader = require(script.Parent.Parent.Loader)

local Client_VisualSettings = {}

local function getClientData()
	return ClientLoader.require("Client_Data")
end

function Client_VisualSettings.AreEffectsEnabled(): boolean
	return getClientData():GetValue("VisualEffects") ~= false
end

function Client_VisualSettings.Listen(listener: (enabled: boolean) -> ())
	return getClientData():ListenToChange("VisualEffects", function(value)
		listener(value ~= false)
	end)
end

return Client_VisualSettings
