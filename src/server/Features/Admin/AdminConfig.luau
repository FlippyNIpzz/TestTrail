--!strict
-- Private, server-session controls. IDs are Roblox user IDs, never display names.
local BaseConfig = require(game:GetService("ReplicatedStorage").Shared.Features.Base.BaseConfig)
local options = {}
for level = BaseConfig.StartingLevel, BaseConfig.MaxLevel do
    table.insert(options, { Id = BaseConfig.Layouts[level].ModelType, Name = "Base style " .. level, Level = level })
end
local targets = {}
for _, plot in BaseConfig.Plots do
    table.insert(targets, { Id = plot.Id, Name = plot.Id, Adapter = "BaseStructure", PlotId = plot.Id, Options = options })
end
return {
    AdminUserIds = {}, -- Example: { 123456789, 987654321 }
    AllowExperienceOwner = true, -- User-owned experiences only; groups need explicit IDs above.
    RequestIntervalSeconds = 0.35,
    StateIntervalSeconds = 0.5,
    ConfirmationLifetimeSeconds = 30,
    Toggles = {
        { Id = "resources.generation", Name = "Resource generation", Adapter = "ResourceGeneration", Feature = "Resources", Warning = "Pauses new pickups. Existing pickups keep their normal expiry." },
        { Id = "inventory.selling", Name = "Item selling", Adapter = "InventorySelling", Feature = "Inventory", Warning = "Changes whether all players can sell inventory items." },
        { Id = "base.purchases", Name = "Base purchases", Adapter = "BasePurchases", Feature = "Base", Warning = "Changes whether all players can purchase base levels." },
    },
    ModelTargets = targets,
}
