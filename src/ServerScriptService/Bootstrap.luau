local Server_Data = require(script.Parent.Core.Server_Data)
local Server_Leaderboards = require(script.Parent.Core.Server_Leaderboards)
local Server_Settings = require(script.Parent.Core.Server_Settings)
local Server_Admin = require(script.Parent.Core.Server_Admin)
local Server_Tutorial = require(script.Parent.Core.Server_Tutorial)
local PlotService = require(script.Parent.Plot.PlotService)
local GameProcessCycle = require(script.Parent.GameProcess.GameProcessCycle)
local GameProcessService = require(script.Parent.GameProcess.GameProcessService)

local Bootstrap = {}

function Bootstrap.start()
	Server_Data:Init()
	Server_Tutorial.Init()
	Server_Leaderboards.Init()
	Server_Settings.Init()
	GameProcessService.Init()
	GameProcessCycle.Init()

	local plotService = PlotService.new()
	plotService:Init()
	GameProcessCycle.SetPlotService(plotService)
	Server_Admin:Init(plotService)
end

return Bootstrap
