--!strict

-- Shared identity and feature switches. Private storage settings belong to PlayerData.
-- Enabled means included in startup; it does not mean the feature is implemented.
local features: { [string]: boolean } = {
    Admin = true,
    Networking = true,
    PlayerData = true,
    Currency = true,
    Inventory = true,
    Base = true,
    Resources = true,
    Facilities = true,
    Upgrades = true,
    UI = true,
    Companion = false,
    Combat = false,
    Arena = false,
    Rebirth = false,
}

return table.freeze({
    Id = "foundation",
    DisplayName = "Tycoon Foundation",
    Features = table.freeze(features),
})
