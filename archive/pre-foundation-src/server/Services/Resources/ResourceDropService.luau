
local ResourceDropService = {}

local ResourceService = require(
    script.Parent.ResourceService
)

local OWNER_LOCKOUT = 3

-- DROP RESOURCES
function ResourceDropService.Drop(player)
    -- Get all carried resources
    -- Spawn drops at player's position
    -- Record owner and drop timestamp
    -- Clear carried resources
    return false
end

-- VALIDATE PICKUP
function ResourceDropService.CanPickup(player, drop)
    -- Other players can collect immediately
    -- Original owner waits OWNER_LOCKOUT seconds
    return false
end

-- PICK UP DROP
function ResourceDropService.Pickup(player, drop)
    -- Validate pickup eligibility
    -- Transfer resources
    -- Remove collected drop
    return false
end

-- REMOVE DROP
function ResourceDropService.Remove(drop)
    -- Remove dropped resource from Arena
    return false
end

-- CLEANUP
function ResourceDropService.Cleanup()
    -- Remove expired drops
    -- Expiration duration TBD
    return false
end

return ResourceDropService
