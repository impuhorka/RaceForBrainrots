local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_Abbreviation = SharedModules.require("Shared_Abbreviation")
local Shared_StrengthStore = SharedModules.require("Shared_StrengthStore")
local Client_StatStoreUi = require(script.Parent.Client_StatStoreUi)

local Client_StrengthStore = Client_StatStoreUi.create({
	statName = "Strength",
	frameName = "StrengthStore",
	sharedStore = Shared_StrengthStore,
	buyRemoteAction = "BuyStrength",
	successRemoteAction = "StrengthPurchaseSuccess",
	failedRemoteAction = "StrengthPurchaseFailed",
	successMessage = function(addedAmount, paidCost)
		return ("Bought +%d strength for $%s."):format(addedAmount, Shared_Abbreviation:Number(paidCost))
	end,
})

return Client_StrengthStore