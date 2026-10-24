
local Controllers = script.Parent:WaitForChild("Controllers")

-- CLIENT CONTROLLERS
local ArenaController = require(
    Controllers.ArenaController
)

local BaseController = require(
    Controllers.BaseController
)

local CompanionController = require(
    Controllers.CompanionController
)

local InventoryController = require(
    Controllers.InventoryController
)

-- INITIALIZE CLIENT
local function Initialize()
    ArenaController.Initialize()
    BaseController.Initialize()
    CompanionController.Initialize()
    InventoryController.Initialize()
end

Initialize()
