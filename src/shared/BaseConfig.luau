--!strict
-- Authored Zones determine placement. Costs remain free for current testing.
local Config = {}
Config.InteractionRange = 12
Config.HoldDuration = 0.5
Config.ForgeInterval = 2
export type Zone = { Name: string, Folder: string, Available: boolean, Cost: number, RequiredBaseLevel: number }
Config.Zones = {
    Zone1 = { Name = "Forge", Folder = "Forge_Models", Available = true, Cost = 0, RequiredBaseLevel = 1 },
    Zone2 = { Name = "Charge Station", Folder = "ChargeStation_Models", Available = true, Cost = 0, RequiredBaseLevel = 1 },
    Zone3 = { Name = "Command Terminal", Folder = "", Available = false, Cost = 0, RequiredBaseLevel = 1 },
    Zone4 = { Name = "Inspector", Folder = "", Available = false, Cost = 0, RequiredBaseLevel = 1 },
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
export type BaseLevel = { Name: string, Description: string, Cost: number, RequiredTier: number }
-- Milestones only: existing facility access remains available at Base level 1.
Config.BaseLevels = {
    { Name = "Starter", Description = "Forge and charging station available", Cost = 0, RequiredTier = 0 },
    { Name = "Established", Description = "Requires both facilities purchased", Cost = 0, RequiredTier = 1 },
    { Name = "Developed", Description = "Requires both facilities at tier 2", Cost = 0, RequiredTier = 2 },
} :: { BaseLevel }
function Config.CostText(cost: number): string
    return if cost == 0 then "Free" else ("$%d"):format(cost)
end
return Config
