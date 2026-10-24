
local PlacementService = {}

local BaseService = require(
    script.Parent.BaseService
)

-- VALIDATE PLACEMENT
function PlacementService.CanPlace(player, facilityId, zoneId)
    -- Verify player owns the base
    -- Check if facility is allowed in zone
    -- Check facility unlock requirements
    -- Check whether placement is available
    return false
end

-- PLACE FACILITY
function PlacementService.Place(player, facilityId, zoneId, position)
    -- Validate placement
    -- Create facility model
    -- Record facility placement in player data
    return false
end

-- GET ZONES
function PlacementService.GetZones(player)
    -- Return available and locked base zones
    return {}
end

-- CHECK ZONE
function PlacementService.IsZoneUnlocked(player, zoneId)
    -- Verify zone is unlocked through Base Level
    return false
end

-- GET PLACED FACILITIES
function PlacementService.GetFacilities(player)
    -- Return player's placed facilities
    return {}
end

-- RESTORE PLACEMENTS
function PlacementService.Restore(player)
    -- Reconstruct saved facility placements
    return false
end

return PlacementService
