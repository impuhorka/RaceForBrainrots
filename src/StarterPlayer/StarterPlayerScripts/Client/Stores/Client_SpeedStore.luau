local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_Abbreviation = SharedModules.require("Shared_Abbreviation")
local Shared_SpeedStore = SharedModules.require("Shared_SpeedStore")
local Client_StatStoreUi = require(script.Parent.Client_StatStoreUi)

local Client_SpeedStore = Client_StatStoreUi.create({
	statName = "Speed",
	frameName = "SpeedStore",
	sharedStore = Shared_SpeedStore,
	buyRemoteAction = "BuySpeed",
	successRemoteAction = "SpeedPurchaseSuccess",
	failedRemoteAction = "SpeedPurchaseFailed",
	successMessage = function(addedAmount, paidCost)
		return ("Bought +%d speed for $%s."):format(addedAmount, Shared_Abbreviation:Number(paidCost))
	end,
})

return Client_SpeedStore