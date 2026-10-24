
local ProgressionConfig = {}

-- PLAYER PROGRESSION
ProgressionConfig.Player = {
    StartingLevel = 1,
    StartingXP = 0,

    IncreasingXP = true,
    XPFormula = nil, -- TBD
    MaxLevel = nil, -- TBD
}

-- BASE PROGRESSION
ProgressionConfig.Base = {
    StartingLevel = 1,
    IndependentFromPlayerLevel = true,

    UpgradeRequiresCash = true,
    UpgradeRequiresMaterials = true,

    MaxLevel = nil, -- TBD
    UpgradeCosts = {}, -- TBD
}

-- REBIRTH SYSTEM
ProgressionConfig.Rebirth = {
    Enabled = true,

    -- REQUIREMENTS
    RequiredLevel = nil, -- TBD
    Requirements = {}, -- TBD

    -- RESET RULES
    ResetPlayerLevel = true,
    ResetBaseLevel = true,

    PlayerResetLevel = 1,
    BaseResetLevel = 1,

    ResetInventory = nil, -- TBD
    ResetCompanions = nil, -- TBD
    ResetCash = nil, -- TBD

    -- PERMANENT PROGRESSION
    PermanentBonuses = {}, -- TBD
    BonusFormula = nil, -- TBD

    RebirthLevelFormula = nil, -- TBD
}

return ProgressionConfig
