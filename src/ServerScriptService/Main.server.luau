local Server_Data = require(script.Parent.Core.Server_Data)
local Server_Settings = require(script.Parent.Core.Server_Settings)
local Server_Admin = require(script.Parent.Core.Server_Admin)
local PlotService = require(script.Parent.Plot.PlotService)
local GameProcessFloors = require(script.Parent.GameProcess.GameProcessFloors)

Server_Data:Init()
Server_Settings.Init()
GameProcessFloors.Setup()

local plotService = PlotService.new()
plotService:Init()
Server_Admin:Init(plotService)
