
local ArenaService = {}

local ResourceDropService = require(
    script.Parent.Parent.Resources.ResourceDropService
)

-- INITIALIZE ARENA
function ArenaService.Initialize()
    -- Set up Arena boundaries
    -- Register Arena systems
end

-- PLAYER ENTERS ARENA
function ArenaService.Enter(player)
    -- Register player inside Arena
    return false
end

-- PLAYER EXITS ARENA
function ArenaService.Exit(player)
    -- Remove player from Arena tracking
    return false
end

-- CHECK ARENA STATUS
function ArenaService.IsInside(player)
    -- Return whether player is inside Arena
    return false
end

-- PLAYER DEFEATED
function ArenaService.OnPlayerDefeated(player)
    -- Trigger carried-resource drops
    return ResourceDropService.Drop(player)
end

-- GET ARENA PLAYERS
function ArenaService.GetPlayers()
    -- Return players currently inside Arena
    return {}
end

return ArenaService
