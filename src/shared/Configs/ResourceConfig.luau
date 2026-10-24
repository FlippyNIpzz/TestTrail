
local ResourceConfig = {}

-- RESOURCE TYPES
ResourceConfig.Resources = {
    Scrap = {
        Name = "Scrap",
        Collectible = true,
        Refinable = true,
    },
}

-- RESOURCE SPAWNING
ResourceConfig.Spawning = {
    Enabled = true,
    Mode = "Continuous",

    InitialCount = 12,
    Interval = 3,
    MaxSpawned = 30,

    SpawnZone = "Arena",
    EdgeMargin = 5,
}

-- RESOURCE COLLECTION
ResourceConfig.Collection = {
    Enabled = true,
    AutoPickup = false, -- TBD
}

-- CARRYING SYSTEM
ResourceConfig.Carrying = {
    Unlimited = true,
    VisibleStack = true,
    ShowCounter = true,
    StackPosition = "AbovePlayer",
}

-- RESOURCE DROPS
ResourceConfig.Drops = {
    DropAllOnDefeat = true,
    OwnerPickupLockout = 3,
    OtherPlayersCanPickup = true,
    NeverExpire = true,
}

-- RESOURCE PROCESSING
ResourceConfig.Processing = {
    Enabled = true,
    Recipes = {}, -- TBD
}

return ResourceConfig
