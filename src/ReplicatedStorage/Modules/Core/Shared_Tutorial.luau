local SharedModules = require(script.Parent.Parent.Loader)
local Shared_SpeedStore = SharedModules.require("Shared_SpeedStore")
local Shared_StrengthStore = SharedModules.require("Shared_StrengthStore")

local Shared_Tutorial = {}

Shared_Tutorial.Steps = {
	{
		Id = 1,
		Message = "Go to the Strength Store and buy 3 strength!",
		MessageColor = "yellow",
		Target = "StrengthStore",
		RequiredStrength = Shared_StrengthStore.DefaultValue + Shared_StrengthStore.FreeStrengthPoints,
	},
	{
		Id = 2,
		Message = "Go to the entrance wall!",
		WaitForRaceMessage = "Wait until the race starts!",
		RaceActiveMessage = "Pick up a Common Lucky Block!",
		CarryingMessage = "Bring it back to the entrance!",
		FailedRaceMessage = "Unlucky! Wait for the next race and try again!",
		MessageColor = "yellow",
		Target = "EntranceWall",
		PickupRarity = "Common",
	},
	{
		Id = 3,
		Message = "Click on the screen to open your Lucky Block!",
		MessageColor = "yellow",
		Target = "OpenLuckyBlock",
	},
	{
		Id = 4,
		Message = "Equip and Place brainrot on your plot!",
		MessageColor = "yellow",
		Target = "PlotSlot",
	},
	{
		Id = 5,
		ReadyMessage = "Purchase +1 Speed!",
		CompletedMessage = "Tutorial is completed!",
		MessageColor = "yellow",
		Target = "SpeedStore",
		PurchaseAmount = 1,
		RequiredSpeed = Shared_SpeedStore.DefaultSpeed + 1,
	},
}

function Shared_Tutorial.GetStep(stepIndex: number)
	return Shared_Tutorial.Steps[stepIndex]
end

function Shared_Tutorial.GetStepCount(): number
	return #Shared_Tutorial.Steps
end

return Shared_Tutorial
