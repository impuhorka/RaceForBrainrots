--[[
	Central client module resolver.
	Use Loader.require("Client_Data") instead of deep script.Parent chains.
]]

local Loader = {}

local root = script.Parent
local cache: { [string]: any } = {}

local PATHS: { [string]: ModuleScript } = {
	Client_AntiFling = root.Core.Client_AntiFling,
	Client_AudioSettings = root.Core.Client_AudioSettings,
	Client_BackgroundMusic = root.Settings.Client_BackgroundMusic,
	Client_CashAddingPopups = root.Plot.Client_CashAddingPopups,
	Client_Data = root.Core.Client_Data,
	Client_Equip = root.Inventory.Client_Equip,
	Client_EquipHold = root.Inventory.Client_EquipHold,
	Client_FOV = root.Core.Client_FOV,
	Client_GradientBar = root.World.Client_GradientBar,
	Client_Leaderboards = root.World.Client_Leaderboards,
	Client_GameProcess = root.World.Client_GameProcess,
	Client_VIPWalls = root.World.Client_VIPWalls,
	Client_GameProcessBrainrots = root.LuckyBlocks.Client_GameProcessBrainrots,
	Client_GameProcessLuckyBlocks = root.LuckyBlocks.Client_GameProcessLuckyBlocks,
	Client_BrainrotDrop = root.Inventory.Client_BrainrotDrop,
	Client_LuckyBlockCarry = root.LuckyBlocks.Client_LuckyBlockCarry,
	Client_Hotbar = root.Inventory.Client_Hotbar,
	Client_Index = root.World.Client_Index,
	Client_InteractStorePrompts = root.Stores.Client_InteractStorePrompts,
	Client_Inventory = root.Inventory.Client_Inventory,
	Client_ItemDisplay = root.Inventory.Client_ItemDisplay,
	Client_LuckyBlockOpening = root.LuckyBlocks.Client_LuckyBlockOpening,
	Client_WorldDropAnimation = root.LuckyBlocks.Client_WorldDropAnimation,
	Client_LuckyBlockRevealState = root.Inventory.Client_LuckyBlockRevealState,
	Client_Messaging = root.Core.Client_Messaging,
	Client_ModelVfx = root.Core.Client_ModelVfx,
	Client_OfflineCash = root.Plot.Client_OfflineCash,
	Client_PlotBillboards = root.Plot.Client_PlotBillboards,
	Client_PlotBrainrotAnimations = root.Plot.Client_PlotBrainrotAnimations,
	Client_PlotBrainrotVfx = root.Plot.Client_PlotBrainrotVfx,
	Client_PlotBrainrotJump = root.Plot.Client_PlotBrainrotJump,
	Client_PlotCashCollect = root.Plot.Client_PlotCashCollect,
	Client_PlotSlotPlace = root.Plot.Client_PlotSlotPlace,
	Client_PlotSlotSurfaces = root.Plot.Client_PlotSlotSurfaces,
	Client_PlotSpawnAnimation = root.Plot.Client_PlotSpawnAnimation,
	Client_PlotUpgradeSign = root.Plot.Client_PlotUpgradeSign,
	Client_PlotUpgradeVfx = root.Plot.Client_PlotUpgradeVfx,
	Client_ProximityPrompts = root.World.Client_ProximityPrompts,
	Client_RainbowBrainrots = root.World.Client_RainbowBrainrots,
	Client_Marketplace = root.Stores.Client_Marketplace,
	Client_Rebirth = root.Stores.Client_Rebirth,
	Client_RobuxStore = root.Stores.Client_RobuxStore,
	Client_SellBillboard = root.Plot.Client_SellBillboard,
	Client_Settings = root.Settings.Client_Settings,
	Client_SlowModeButton = root.Settings.Client_SlowModeButton,
	Client_SoundPreload = root.Core.Client_SoundPreload,
	Client_SpiralSway = root.Core.Client_SpiralSway,
	Client_StreakSfx = root.Core.Client_StreakSfx,
	Client_SpeedStore = root.Stores.Client_SpeedStore,
	Client_StrengthStore = root.Stores.Client_StrengthStore,
	Client_TadaEffect = root.Core.Client_TadaEffect,
	Client_Tutorial = root.Core.Client_Tutorial,
	Client_UiPulse = root.Core.Client_UiPulse,
	Client_UiWiggle = root.Core.Client_UiWiggle,
	Client_Visuals = root.Core.Client_Visuals,
	Client_VisualSettings = root.Core.Client_VisualSettings,
}

function Loader.require(moduleName: string): any
	local cached = cache[moduleName]
	if cached ~= nil then
		return cached
	end

	local moduleScript = PATHS[moduleName]
	if not moduleScript then
		error(`[Client.Loader] Unknown module: {moduleName}`, 2)
	end

	local module = require(moduleScript)
	cache[moduleName] = module
	return module
end

function Loader.clearCache()
	table.clear(cache)
end

return Loader
