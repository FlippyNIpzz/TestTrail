
local BaseConfig = {}

-- BASE LAYOUT
BaseConfig.MaxBases = 13
BaseConfig.CircleRadius = 100
BaseConfig.Shape = "Rectangular"
BaseConfig.FaceCenter = true
BaseConfig.AutoAssign = true

-- TEMPORARY TEST DIMENSIONS
BaseConfig.Width = 24
BaseConfig.Length = 24
BaseConfig.FloorThickness = 1

-- BASE PROGRESSION
BaseConfig.StartingLevel = 1
BaseConfig.MaxLevel = nil -- TBD

-- FACILITY ZONES
BaseConfig.Zones = {
    [1] = {
        Name = "Forge",
        Facility = "Forge",
        UnlockLevel = 1,
    },

    [2] = {
        Name = "Smithy",
        Facility = "Smithy",
        UnlockLevel = nil, -- TBD
    },

    [3] = {
        Name = "Printer",
        Facility = "Printer",
        UnlockLevel = nil, -- TBD
    },

    [4] = {
        Name = "RepairStation",
        Facility = "RepairStation",
        UnlockLevel = nil, -- TBD
    },
}

-- BASE UPGRADES
BaseConfig.UpgradeCosts = {}

return BaseConfig
