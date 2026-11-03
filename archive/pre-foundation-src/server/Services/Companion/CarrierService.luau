
local CarrierService = {}

local InventoryService = require(
    script.Parent.Parent.Inventory.InventoryService
)

local CompanionService = require(
    script.Parent.CompanionService
)

-- VALIDATE CRAFTING
function CarrierService.CanCraft(player, carrierId)
    -- Verify required refined materials
    -- Check Carrier recipe
    return false
end

-- CRAFT CARRIER
function CarrierService.Craft(player, carrierId)
    -- Validate crafting requirements
    -- Consume refined materials
    -- Add Carrier to player inventory
    return false
end

-- OPEN CARRIER
function CarrierService.Open(player, carrierId)
    -- Verify Carrier ownership
    -- Determine companion reward
    -- Consume Carrier
    -- Add companion to collection
    return nil
end

-- GET RARITY ODDS
function CarrierService.GetOdds(carrierId)
    -- Return companion rarity probabilities
    -- Common, Rare, Epic, Legendary
    return {}
end

-- GET CARRIER RECIPES
function CarrierService.GetRecipes(player)
    -- Return available Carrier recipes
    return {}
end

return CarrierService
