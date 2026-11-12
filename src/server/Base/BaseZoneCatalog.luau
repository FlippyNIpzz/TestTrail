--!strict
-- Read-only discovery of authored zone parts. Never infer an unknown zone's asset type.
local Config = require(game:GetService("ReplicatedStorage").Shared.BaseConfig)
local Catalog = {}
export type ZoneInfo = { Id: string, AssetType: string, Available: boolean, Issue: string? }
export type LevelInfo = { Level: number, Zones: { ZoneInfo }, Added: { string }, Removed: { string }, Issue: string? }
function Catalog.Read(model: Model?): ({ ZoneInfo }, string?)
    if not model then return {}, "Model unavailable" end
    local folder = model:FindFirstChild("Zones")
    if not folder then return {}, "Zones folder missing" end
    local zones: { ZoneInfo } = {}
    local counts: { [string]: number } = {}
    for _, child in ipairs(folder:GetChildren()) do counts[child.Name] = (counts[child.Name] or 0) + 1 end
    for _, child in ipairs(folder:GetChildren()) do
        local definition = Config.Zones[child.Name]
        local issue: string? = nil
        if counts[child.Name] > 1 then issue = "Duplicate zone name"
        elseif not child:IsA("BasePart") then issue = "Zone must be a part"
        elseif not definition then issue = "Asset type not assigned"
        elseif not definition.Available then issue = "Not implemented" end
        table.insert(zones, {
            Id = child.Name, AssetType = if definition then definition.Name else "Unassigned",
            Available = issue == nil, Issue = issue,
        })
    end
    table.sort(zones, function(a, b)
        local left = tonumber(string.match(a.Id, "^Zone(%d+)$"))
        local right = tonumber(string.match(b.Id, "^Zone(%d+)$"))
        if left and right and left ~= right then return left < right end
        return a.Id < b.Id
    end)
    return zones, nil
end
function Catalog.Levels(folder: Instance): { LevelInfo }
    local levels: { LevelInfo } = {}
    local previous: { [string]: boolean }? = nil
    for level = 1, #Config.BaseLevels do
        local item = folder:FindFirstChild("Base_Level_" .. level)
        local model = if item and item:IsA("Model") then item else nil
        local zones, issue = Catalog.Read(model)
        local names: { [string]: boolean } = {}
        local added: { string } = {}
        local removed: { string } = {}
        for _, zone in ipairs(zones) do
            names[zone.Id] = true
            if previous and not previous[zone.Id] then table.insert(added, zone.Id) end
        end
        if previous and not issue then
            for id in pairs(previous) do if not names[id] then table.insert(removed, id) end end
            table.sort(removed)
        end
        table.insert(levels, { Level = level, Zones = zones, Added = added, Removed = removed,
            Issue = issue or (if level > 1 and not previous then "Previous level unavailable; new zones unknown" else nil) })
        previous = if issue then nil else names
    end
    return levels
end
return Catalog
