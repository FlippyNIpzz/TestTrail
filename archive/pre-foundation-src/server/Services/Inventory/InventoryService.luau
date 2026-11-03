
local InventoryService = {}

local PlayerDataService = require(
    script.Parent.Parent.Player.PlayerDataService
)

-- ADD TO INVENTORY
function InventoryService.Add(player, category, itemId, amount)
    -- Add items to specified inventory category
    return false
end

-- REMOVE FROM INVENTORY
function InventoryService.Remove(player, category, itemId, amount)
    -- Check quantity and remove items
    return false
end

-- CHECK INVENTORY
function InventoryService.Has(player, category, itemId, amount)
    -- Check if player owns required quantity
    return false
end

-- GET INVENTORY
function InventoryService.GetInventory(player)
    local data = PlayerDataService.Get(player)
    return data and data.Inventory
end

-- GET ITEM QUANTITY
function InventoryService.GetQuantity(player, category, itemId)
    -- Return quantity of specified item
    return 0
end

return InventoryService
