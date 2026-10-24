
local CompanionConfig = {}

-- GENERAL SETTINGS
CompanionConfig.MaxActive = 1

-- COMPANION TYPES
CompanionConfig.Types = {
    Flame = {
        BaseStats = {}, -- TBD
    },

    Beam = {
        BaseStats = {}, -- TBD
    },

    Gust = {
        BaseStats = {}, -- TBD
    },

    Orbiter = {
        BaseStats = {}, -- TBD
    },
}

-- COMPANION RARITIES
CompanionConfig.Rarities = {
    Common = {
        BaseStatMultiplier = nil, -- TBD
        GrowthMultiplier = nil, -- TBD
    },

    Rare = {
        BaseStatMultiplier = nil, -- TBD
        GrowthMultiplier = nil, -- TBD
    },

    Epic = {
        BaseStatMultiplier = nil, -- TBD
        GrowthMultiplier = nil, -- TBD
    },

    Legendary = {
        BaseStatMultiplier = nil, -- TBD
        GrowthMultiplier = nil, -- TBD
    },
}

-- COMPANION STATS
CompanionConfig.Stats = {
    "Health",
    "Damage",
    "Stamina",
    "Speed",
}

-- COMPANION MODES
CompanionConfig.Modes = {
    Base = "Base",
    Follow = "Follow",
    Arena = "Arena",
}

-- STAMINA SYSTEM
CompanionConfig.Stamina = {
    Enabled = true,
    DrainDuringMovement = true,
    RegenerateWhileStationary = true,

    DrainRate = nil, -- TBD
    RegenerationRate = nil, -- TBD
}

-- COMPANION LEVELING
CompanionConfig.Leveling = {
    StatGrowthEnabled = true,
    GrowthFormula = nil, -- TBD
    MaxLevel = nil, -- TBD
}

-- COMPANION ACQUISITION
CompanionConfig.Carriers = {
    Enabled = true,
    RarityOdds = {}, -- TBD
    Recipes = {}, -- TBD
}

-- COMPANION FUSION
CompanionConfig.Fusion = {
    Enabled = true,
    KeepHighestStats = true,
    ConsumeDonor = true,
    CombineLevels = true,

    LevelFormula = nil, -- TBD
}

-- COMBAT
CompanionConfig.Combat = {
    Enabled = true,
    AttackOwner = false,

    AttackRange = nil, -- TBD
    AttackCooldown = nil, -- TBD
    RespawnTime = nil, -- TBD
}

return CompanionConfig
