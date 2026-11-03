--!strict
-- Game adaptation: retain the 13 authored locations rather than regenerate a circle.
-- Level 0 is the artist's unclaimed preview; saved progression starts at level 1.
local layouts = {}
for level = 1, 4 do
    layouts[level] = {
        ModelType = "base.level_" .. level,
        Asset = { Kind = "ProjectPath", ExpectedClass = "Model",
            Path = { "ServerStorage", "PlotLevelModels", "Base_Level_" .. level } },
        FloorName = "Floor", SpawnOffset = CFrame.new(0, 4, 0),
    }
end
local plots = {}
-- Explicit authored names preserve plot IDs despite mixed padding and legacy metadata.
local slotNames = { "BaseSlot_1", "BaseSlot_2", "BaseSlot_3", "BaseSlot_4", "BaseSlot_5",
    "BaseSlot_06", "BaseSlot_07", "BaseSlot_08", "BaseSlot_09", "BaseSlot_10",
    "BaseSlot_11", "BaseSlot_12", "BaseSlot_13" }
for index, name in slotNames do
    table.insert(plots, { Id = "base.plot_" .. index,
        Path = { "Workspace", "Game", "Base", "Base_Models", "Base_Slots", name } })
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
