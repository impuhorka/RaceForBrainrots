local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_Abbreviation = SharedModules.require("Shared_Abbreviation")
local Shared_StrengthStore = SharedModules.require("Shared_StrengthStore")
local Client_StatStoreUi = require(script.Parent.Client_StatStoreUi)
local ClientLoader = require(script.Parent.Parent.Loader)

local Client_Data = ClientLoader.require("Client_Data")

local function getFreeStrengthPointsUsed(): number
	return math.clamp(
		math.floor(Client_Data:GetValue("FreeStrengthPointsUsed") or 0),
		0,
		Shared_StrengthStore.FreeStrengthPoints
	)
end

local Client_StrengthStore = Client_StatStoreUi.create({
	statName = "Strength",
	frameName = "StrengthStore",
	sharedStore = Shared_StrengthStore,
	buyRemoteAction = "BuyStrength",
	successRemoteAction = "StrengthPurchaseSuccess",
	failedRemoteAction = "StrengthPurchaseFailed",
	purchaseCostContextKeys = { "FreeStrengthPointsUsed" },
	getPurchaseCostContext = getFreeStrengthPointsUsed,
	successMessage = function(addedAmount, paidCost)
		if paidCost <= 0 then
			return ("Bought +%d strength for free!"):format(addedAmount)
		end
		return ("Bought +%d strength for $%s."):format(addedAmount, Shared_Abbreviation:Number(paidCost))
	end,
})

return Client_StrengthStore