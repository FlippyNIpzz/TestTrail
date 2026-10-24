
local RepairStationService = {}

local InventoryService = require(
    script.Parent.Parent.Inventory.InventoryService
)

-- INITIALIZE
function RepairStationService.Initialize(player)
    -- Prepare player's RepairStation
end

-- VALIDATE REPAIR
function RepairStationService.CanRepair(player, itemId)
    -- Verify ownership, durability and repair costs
    return false
end

-- REPAIR EQUIPMENT
function RepairStationService.Repair(player, itemId)
    -- Consume materials
    -- Restore durability
    return false
end

-- GET REPAIR INFORMATION
function RepairStationService.GetRepairInfo(player, itemId)
    -- Return durability and repair requirements
    return nil
end

-- GET STATUS
function RepairStationService.GetStatus(player)
    -- Return RepairStation status
    return nil
end

return RepairStationService
