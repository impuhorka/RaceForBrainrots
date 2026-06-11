local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModules = require(ReplicatedStorage.Modules.Loader)

local Shared_GameProcess = SharedModules.require("Shared_GameProcess")

local MapProcessBuildTiming = {}

local function getGameFolder(): Instance?
	return Workspace:FindFirstChild("Game")
end

function MapProcessBuildTiming.extendPhaseEndTime(buildEndTime: number)
	local gameFolder = getGameFolder()
	if not gameFolder then
		return
	end

	local phaseEndTime = gameFolder:GetAttribute("ProcessPhaseEndTime")
	if type(phaseEndTime) ~= "number" or buildEndTime > phaseEndTime then
		gameFolder:SetAttribute("ProcessPhaseEndTime", buildEndTime)
	end
end

function MapProcessBuildTiming.beginBuildWindow(duration: number): (number, number)
	local buildStartTime = Workspace:GetServerTimeNow()
	local buildEndTime = buildStartTime + duration
	MapProcessBuildTiming.extendPhaseEndTime(buildEndTime)
	return buildStartTime, buildEndTime
end

function MapProcessBuildTiming.setMapBuildAttributes(
	buildId: number,
	buildStartTime: number,
	buildEndTime: number,
	totalItems: number
)
	local gameFolder = getGameFolder()
	if not gameFolder then
		return
	end

	local buildDuration = buildEndTime - buildStartTime
	gameFolder:SetAttribute("DecorationBuildId", buildId)
	gameFolder:SetAttribute("MapBuildStartTime", buildStartTime)
	gameFolder:SetAttribute("MapBuildEndTime", buildEndTime)
	gameFolder:SetAttribute("MapBuildTotalItems", totalItems)
	gameFolder:SetAttribute(
		"MapBuildItemsPerSecond",
		Shared_GameProcess.GetMapRevealItemsPerSecond(totalItems, buildDuration)
	)
end

export type PacedStepper = {
	pace: () -> boolean,
	getSlotIndex: () -> number,
}

function MapProcessBuildTiming.makePacedStepper(
	buildStartTime: number,
	buildEndTime: number,
	totalSlots: number
): PacedStepper
	local slotIndex = 0
	local lastRevealAt: number? = nil
	local buildDuration = math.max(buildEndTime - buildStartTime, 0.01)

	local function isBuildTimeRemaining(): boolean
		return Workspace:GetServerTimeNow() < buildEndTime
	end

	local function pace(): boolean
		if not isBuildTimeRemaining() then
			return false
		end
		slotIndex += 1
		lastRevealAt = Shared_GameProcess.WaitForPacedReveal(
			buildStartTime,
			slotIndex,
			totalSlots,
			buildDuration,
			lastRevealAt
		)
		return isBuildTimeRemaining()
	end

	return {
		pace = pace,
		getSlotIndex = function()
			return slotIndex
		end,
	}
end

return MapProcessBuildTiming
