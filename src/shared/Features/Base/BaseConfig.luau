--!strict
-- Game adaptation: retain the 13 authored locations rather than regenerate a circle.
-- Level 0 is the artist's unclaimed preview; saved progression starts at level 1.
local layouts = {}
for level = 1, 4 do
    layouts[level] = {
        ModelType = "base.level_" .. level,
        Asset = { Kind = "ProjectPath", ExpectedClass = "Model",
            Path = { "Workspace", "Bases", "NoGemBases", "Base_Level_" .. level } },
        FloorName = "Floor", SpawnOffset = CFrame.new(0, 4, 0),
    }
end
local plots = {}
for level = 0, 4 do
    table.insert(plots, { Id = "base.plot_" .. (#plots + 1),
        Path = { "Workspace", "Bases", "NoGemBases", "Base_Level_" .. level } })
end
for index = 6, 13 do
    table.insert(plots, { Id = "base.plot_" .. (#plots + 1),
        Path = { "Workspace", "Bases", "PlacedBases", string.format("BaseSlot_%02d", index) } })
end
return {
    Count = 13, StartingLevel = 1, MaxLevel = 4,
    Plots = plots, Layouts = layouts,
    -- Example costs indexed by the level being purchased; tune game balance here.
    LevelCosts = {
        [2] = { ["currency.cash"] = 100 },
        [3] = { ["currency.cash"] = 250 },
        [4] = { ["currency.cash"] = 500 },
    },
    UpgradeDistance = 35, RequestIntervalSeconds = 0.5,
    Slots = {}, StarterBuildings = {},
}
