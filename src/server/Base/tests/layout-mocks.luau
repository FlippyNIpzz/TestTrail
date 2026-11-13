function methods:GetDescendants()
    local result = {}
    for _, child in ipairs(self:GetChildren()) do
        table.insert(result, child)
        for _, nested in ipairs(child:GetDescendants()) do table.insert(result, nested) end
    end
    return result
end
function methods:GetPivot() return self.Pivot or self.CFrame end
function methods:PivotTo(pivot) self.Pivot = pivot end
function methods:Clone()
    local copy = Instance.new(self.ClassName)
    for key, value in pairs(self) do
        if key ~= "Parent" and key ~= "PrimaryPart" and key ~= "Triggered" then copy[key] = value end
    end
    copy.Attributes = table.clone(self.Attributes)
    for _, child in ipairs(self:GetChildren()) do
        local cloned = child:Clone(); cloned.Parent = copy
        if child == self.PrimaryPart then copy.PrimaryPart = cloned end
    end
    return copy
end
local newInstance = Instance.new
function Instance.new(class, parent)
    local item = newInstance(class, parent)
    item.Archivable = true
    item.Position = {Tag = "position"}
    item.CFrame = {Tag = "transform"}
    return item
end
local assetsFolder = Instance.new("Folder")
local baseModels = Instance.new("Folder", assetsFolder); baseModels.Name = "Base_Models"
function methods:WaitForChild(name) return assert(self:FindFirstChild(name), name) end
local storage = {FindFirstChild = function(_, name) return if name == "Assets" then assetsFolder else nil end}
game.GetService = function(_, name)
    if name == "Workspace" then return workspace end
    if name == "Players" then return Players end
    return storage
end
local Remotes = {BaseFeedback = {FireClient = function() end}}
local Data = PlayerDataManager
local BaseData = {TOTAL_SPOTS = 1, BASE_COUNT = 1, PATHWAY_INDEX = 14}
local BaseUtils = {CalculateSpotTransform = function() return {}, {Position = {Tag = "plot"}} end}
local ZoneCatalog = Catalog
local function layout(level)
    local model = Instance.new("Model", baseModels); model.Name = "Base_Level_" .. level
    model.PrimaryPart = Instance.new("Part", model)
    local zones = Instance.new("Folder", model); zones.Name = "Zones"
    for _, id in ipairs(Config.BaseLevels[math.max(1, level)].Slots) do
        local part = Instance.new("Part", zones); part.Name = id
    end
    return model
end
for level = 0, 4 do layout(level) end
for _, name in {"Forge_Models", "ChargeStation_Models"} do
    local folder = Instance.new("Folder", assetsFolder); folder.Name = name
    for _, tier in ipairs(if name == "Forge_Models" then Config.ForgeTiers else Config.ChargeTiers) do
        local model = Instance.new("Model", folder); model.Name = tier.ModelName
        model.PrimaryPart = Instance.new("Part", model)
    end
end
