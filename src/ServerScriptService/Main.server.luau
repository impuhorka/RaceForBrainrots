local Server_Data = require(script.Parent.Core.Server_Data)
local Server_Admin = require(script.Parent.Core.Server_Admin)
local PlotService = require(script.Parent.Plot.PlotService)

Server_Data:Init()
Server_Admin:Init()

local plotService = PlotService.new()
plotService:Init()
