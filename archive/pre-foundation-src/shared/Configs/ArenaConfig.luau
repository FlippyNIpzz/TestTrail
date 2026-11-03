
local ArenaConfig = {}

-- ARENA LAYOUT
ArenaConfig.Shape = "Circular"
ArenaConfig.Radius = 50
ArenaConfig.Center = Vector3.new(0, 0, 0)

-- COMBAT RULES
ArenaConfig.CombatEnabled = true
ArenaConfig.CombatType = "CompanionsOnly"
ArenaConfig.MaxActiveCompanions = 1

-- PLAYER DEFEAT
ArenaConfig.DropAllCarriedResources = true
ArenaConfig.OwnerPickupLockout = 3
ArenaConfig.OtherPlayersCanPickup = true

-- RESOURCE DROPS
ArenaConfig.DropExpiration = nil -- TBD

-- ARENA EVENTS
ArenaConfig.EventsEnabled = true
ArenaConfig.EventsScheduled = true

ArenaConfig.EventSettings = {
    Interval = nil, -- TBD
    Duration = nil, -- TBD
    MinimumPlayers = nil, -- TBD
}

-- EVENT TYPES
ArenaConfig.EventTypes = {
    -- Future Arena event definitions
}

-- REWARDS
ArenaConfig.EventRewards = {
    -- Future event rewards
}

return ArenaConfig
