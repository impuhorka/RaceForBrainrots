--[[
	Shared module resolver for ReplicatedStorage.Modules.
	Use Loader.require("Shared_Brainrots") instead of deep folder paths.
]]

local Loader = {}

local root = script.Parent
local cache: { [string]: any } = {}

local PATHS: { [string]: ModuleScript } = {
	-- Game
	Shared_BrainrotAnimations = root.Game.Shared_BrainrotAnimations,
	Shared_BrainrotBillboard = root.Game.Shared_BrainrotBillboard,
	Shared_Brainrots = root.Game.Shared_Brainrots,
	Shared_LuckyBlockBillboard = root.Game.Shared_LuckyBlockBillboard,
	Shared_LuckyBlocks = root.Game.Shared_LuckyBlocks,
	Shared_Modifiers = root.Game.Shared_Modifiers,
	Shared_Rarities = root.Game.Shared_Rarities,
	Shared_Weight = root.Game.Shared_Weight,

	-- Plot
	Shared_PlotConfig = root.Plot.Shared_PlotConfig,
	Shared_ProximityPrompt = root.Plot.Shared_ProximityPrompt,
	Shared_Rebirth = root.Plot.Shared_Rebirth,

	-- GameProcess
	Shared_GameProcess = root.GameProcess.Shared_GameProcess,
	Shared_RoadGradient = root.GameProcess.Shared_RoadGradient,

	-- Economy
	Shared_SpeedStore = root.Economy.Shared_SpeedStore,
	Shared_StatStore = root.Economy.Shared_StatStore,
	Shared_StrengthStore = root.Economy.Shared_StrengthStore,

	-- Core
	Shared_Abbreviation = root.Core.Shared_Abbreviation,
	Shared_BigNum = root.Core.Shared_BigNum,
	Shared_Sounds = root.Core.Shared_Sounds,
	Shared_TableUtil = root.Core.Shared_TableUtil,

	-- Vendor
	ReplicaController = root.Vendor.ReplicaController,
	MadworkMaid = root.Vendor.MadworkMaid,
	MadworkScriptSignal = root.Vendor.MadworkScriptSignal,
	RateLimiter = root.Vendor.RateLimiter,
}

function Loader.require(moduleName: string): any
	local cached = cache[moduleName]
	if cached ~= nil then
		return cached
	end

	local moduleScript = PATHS[moduleName]
	if not moduleScript then
		error(`[Modules.Loader] Unknown module: {moduleName}`, 2)
	end

	local module = require(moduleScript)
	cache[moduleName] = module
	return module
end

function Loader.clearCache()
	table.clear(cache)
end

return Loader
