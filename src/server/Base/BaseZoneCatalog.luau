--!strict
-- Definitions own slot identity; authored parts supply only placement transforms.
local Config = require(game:GetService("ReplicatedStorage").Shared.BaseConfig)
local Catalog = {}
export type ZoneInfo = { Id: string, AssetType: string, Available: boolean, Issue: string? }
export type LevelInfo = { Level: number, Zones: { ZoneInfo }, Added: { string }, Removed: { string }, Issue: string? }
function Catalog.Read(model: Model?, level: number): ({ ZoneInfo }, string?)
    local layout = Config.BaseLevels[level]
    if not layout then return {}, "Unknown base level" end
    local folder = model and model:FindFirstChild("Zones")
    local problem = if not model then "Model unavailable" elseif not folder then "Zones folder missing" else nil
    local counts: { [string]: number } = {}
    if folder then
        for _, child in ipairs(folder:GetChildren()) do counts[child.Name] = (counts[child.Name] or 0) + 1 end
    end
    local zones: { ZoneInfo } = {}
    for _, id in ipairs(layout.Slots) do
        local definition = Config.Zones[id]
        local part = folder and folder:FindFirstChild(id)
        local issue: string? = nil
        if not part then issue = "Placement part missing"
        elseif counts[id] > 1 then issue = "Duplicate zone name"
        elseif not part:IsA("BasePart") then issue = "Zone must be a part"
        elseif not definition.Available then issue = "Not implemented" end
        table.insert(zones, { Id = id, AssetType = definition.Name, Available = issue == nil, Issue = issue })
    end
    if folder then
        for _, part in ipairs(folder:GetChildren()) do
            if not Config.HasSlot(level, part.Name) then
                problem = "Unexpected zone " .. part.Name .. " in this level's model"
            end
        end
    end
    return zones, problem
end
function Catalog.Levels(folder: Instance?): { LevelInfo }
    local levels: { LevelInfo } = {}
    local previous: { [string]: boolean } = {}
    for level = 1, #Config.BaseLevels do
        local item = folder and folder:FindFirstChild("Base_Level_" .. level)
        local model = if item and item:IsA("Model") then item else nil
        local zones, issue = Catalog.Read(model, level)
        local added: { string } = {}
        for _, zone in ipairs(zones) do
            if level > 1 and not previous[zone.Id] then table.insert(added, zone.Id) end
            previous[zone.Id] = true
        end
        table.insert(levels, { Level = level, Zones = zones, Added = added, Removed = {}, Issue = issue })
    end
    return levels
end
return Catalog
