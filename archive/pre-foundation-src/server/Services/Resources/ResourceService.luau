
local ResourceService = {}

local InventoryService = require(
    script.Parent.Parent.Inventory.InventoryService
)

-- COLLECT RESOURCE
function ResourceService.Collect(player, resourceId, amount)
    -- Validate resource collection
    -- Add resource to player's carried resources
    return false
end

-- GET CARRIED RESOURCES
function ResourceService.GetCarried(player)
    -- Return resources currently carried
    return {}
end

-- DEPOSIT RESOURCES
function ResourceService.Deposit(player, resourceId, amount)
    -- Transfer carried resources to processing facility
    return false
end

-- PROCESS RESOURCES
function ResourceService.Process(player, resourceId, amount)
    -- Convert raw resources into materials or Cash
    -- Processing rules and recipes TBD
    return false
end

-- CLEAR CARRIED RESOURCES
function ResourceService.ClearCarried(player)
    -- Clear carried resources after defeat
    -- Actual drops handled by ResourceDropService
    return false
end

return ResourceService
