
local CompanionService = {}

local PlayerDataService = require(
    script.Parent.Parent.Player.PlayerDataService
)

-- GET COMPANIONS
function CompanionService.GetCompanions(player)
    local data = PlayerDataService.Get(player)
    return data and data.Companions.Owned or {}
end

-- GET COMPANION
function CompanionService.GetCompanion(player, companionId)
    -- Retrieve specified companion
    return nil
end

-- ADD COMPANION
function CompanionService.AddCompanion(player, companionData)
    -- Register newly acquired companion
    return false
end

-- ACTIVATE COMPANION
function CompanionService.Activate(player, companionId)
    -- Validate ownership
    -- Set one active companion
    return false
end

-- SPAWN COMPANION
function CompanionService.Spawn(player)
    -- Spawn active companion model
    return nil
end

-- DESPAWN COMPANION
function CompanionService.Despawn(player)
    -- Remove companion model
    return false
end

-- UPDATE STATS
function CompanionService.UpdateStats(player, companionId)
    -- Recalculate companion statistics
    return false
end

return CompanionService
