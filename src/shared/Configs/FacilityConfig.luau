
local FacilityConfig = {}

-- FORGE
FacilityConfig.Forge = {
    Name = "Forge",
    Zone = 1,

    ProcessingMode = "Timed",
    ProcessingDuration = nil, -- TBD
    Capacity = nil, -- TBD

    Recipes = {}, -- TBD
    Costs = {}, -- TBD
}

-- SMITHY
FacilityConfig.Smithy = {
    Name = "Smithy",
    Zone = 2,

    ProcessingMode = "Instant",
    ProcessingDuration = 0,
    Capacity = nil, -- TBD

    Recipes = {}, -- TBD
    Costs = {}, -- TBD
}

-- PRINTER
FacilityConfig.Printer = {
    Name = "Printer",
    Zone = 3,

    ProcessingMode = "Timed",
    ProcessingDuration = nil, -- TBD
    Capacity = nil, -- TBD

    UpgradeCosts = {}, -- TBD
    HealingCosts = {}, -- TBD
}

-- REPAIR STATION
FacilityConfig.RepairStation = {
    Name = "RepairStation",
    Zone = 4,

    ProcessingMode = "Instant",
    ProcessingDuration = 0,
    Capacity = nil, -- TBD

    RepairCosts = {}, -- TBD
}

return FacilityConfig
