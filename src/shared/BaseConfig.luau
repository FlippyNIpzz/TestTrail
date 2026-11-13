--!strict
-- Authored Zones determine placement. Costs remain free for current testing.
local Config = {}
Config.InteractionRange = 12
Config.StatusRange = 20
Config.HoldDuration = 0.5
Config.ForgeInterval = 2
export type Zone = { Name: string, AssetType: string, Folder: string, Available: boolean, Cost: number, RequiredBaseLevel: number }
Config.Zones = {
    Zone1 = { Name = "Forge", AssetType = "Forge", Folder = "Forge_Models", Available = true, Cost = 0, RequiredBaseLevel = 1 },
    Zone2 = { Name = "Charge Station 1", AssetType = "ChargeStation", Folder = "ChargeStation_Models", Available = true, Cost = 0, RequiredBaseLevel = 1 },
    Zone3 = { Name = "Charge Station 2", AssetType = "ChargeStation", Folder = "ChargeStation_Models", Available = true, Cost = 0, RequiredBaseLevel = 2 },
    Zone4 = { Name = "AI Bot", AssetType = "AIBot", Folder = "", Available = false, Cost = 0, RequiredBaseLevel = 3 },
    Zone5 = { Name = "Charge Station 3", AssetType = "ChargeStation", Folder = "ChargeStation_Models", Available = true, Cost = 0, RequiredBaseLevel = 4 },
} :: { [string]: Zone }
Config.ForgeTiers = {
    { ModelName = "StoneForge", ProcessPerTick = 1, Name = "Stone Forge", Cost = 0, RequiredBaseLevel = 1 },
    { ModelName = "IronForge", ProcessPerTick = 2, Name = "Iron Forge", Cost = 0, RequiredBaseLevel = 1 },
    { ModelName = "SteelForge", ProcessPerTick = 4, Name = "Steel Forge", Cost = 0, RequiredBaseLevel = 1 },
}
Config.ChargeTiers = {
    { ModelName = "ChargeStation", MaxPower = 100, Rate = 5, Name = "Charge Station", Cost = 0, RequiredBaseLevel = 1 },
    { ModelName = "ChargeStation_Level_2", MaxPower = 200, Rate = 10, Name = "Charge Station Level 2", Cost = 0, RequiredBaseLevel = 1 },
    { ModelName = "ChargeStation_Level_3", MaxPower = 350, Rate = 20, Name = "Charge Station Level 3", Cost = 0, RequiredBaseLevel = 1 },
}
export type BaseLevel = { Name: string, Description: string, Cost: number, RequiredTier: number, Slots: { string } }
-- Each level uses Base_Level_<level>; each upgrade adds exactly one predefined slot.
Config.BaseLevels = {
    { Name = "Starter", Description = "Forge and charging station available", Cost = 0, RequiredTier = 0, Slots = { "Zone1", "Zone2" } },
    { Name = "Established", Description = "Requires the original forge and station purchased", Cost = 0, RequiredTier = 1, Slots = { "Zone1", "Zone2", "Zone3" } },
    { Name = "Developed", Description = "Requires the original forge and station at tier 2", Cost = 0, RequiredTier = 2, Slots = { "Zone1", "Zone2", "Zone3", "Zone4" } },
    { Name = "Expanded", Description = "Requires both original facilities at tier 2", Cost = 0, RequiredTier = 2, Slots = { "Zone1", "Zone2", "Zone3", "Zone4", "Zone5" } },
} :: { BaseLevel }
function Config.HasSlot(level: number, zone: string): boolean
    local layout = Config.BaseLevels[level]
    return layout ~= nil and table.find(layout.Slots, zone) ~= nil
end
function Config.CostText(cost: number): string
    return if cost == 0 then "Free" else ("$%d"):format(cost)
end
return Config
