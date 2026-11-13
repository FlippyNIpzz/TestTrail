local warn = print
local objects = {}
local Instance = {}
local methods = {}
function methods:IsA(class) return self.ClassName == class or (class == "BasePart" and self.ClassName == "Part") end
function methods:GetChildren()
    local result = {}
    for _, child in ipairs(objects) do if child.Parent == self then table.insert(result, child) end end
    return result
end
function methods:FindFirstChild(name)
    for _, child in ipairs(self:GetChildren()) do if child.Name == name then return child end end
    return nil
end
function methods:FindFirstChildWhichIsA(class, recursive)
    for _, child in ipairs(self:GetChildren()) do
        if child:IsA(class) then return child end
        if recursive then local found = child:FindFirstChildWhichIsA(class, true); if found then return found end end
    end
    return nil
end
function methods:IsDescendantOf(parent)
    local current = self.Parent
    while current do if current == parent then return true end; current = current.Parent end
    return false
end
function methods:SetAttribute(key, value) self.Attributes[key] = value end
function methods:GetAttribute(key) return self.Attributes[key] end
function methods:GetBoundingBox() return {Position = {X=0,Y=0,Z=0}}, {X=1,Y=1,Z=1} end
function methods:Destroy() self.Parent = nil end
function Instance.new(class, parent)
    local instance = setmetatable({ClassName = class, Name = class, Parent = parent, Attributes = {},
        Position = {X=0,Y=0,Z=0}, Size = {X=1,Y=1,Z=1},
        Triggered = {Connect = function(self, callback) self.Callback = callback end}}, {__index = methods})
    table.insert(objects, instance)
    return instance
end
local workspace = Instance.new("Folder")
local players = {}
local Players = {GetPlayerByUserId = function(_, id) return players[id] end}
local service = {WaitForChild = function(self) return self end}
local game = {GetService = function(_, name) return if name == "Players" then Players else service end}
local UDim2 = {fromOffset = function() return {} end, fromScale = function() return {} end, new = function() return {} end}
local Vector3 = {new = function(x, y, z) return {X = x or 0, Y = y or 0, Z = z or 0} end}
local Color3 = {fromRGB = function() return {} end}
local Enum = {Font = {Arcade = 1}, TextXAlignment = {Center = 1}}
local profiles, bases = {}, {}
local PlayerDataManager = {GetProfile = function(player) return profiles[player] end}
local Inventory = {}
local failUpgrade = false
local BaseManager = {
    GetBaseForPlayer = function(player) return bases[player] end,
    Transaction = function(_, callback) return callback() end,
    Near = function() return true end,
    CanSpend = function() return true, "" end,
    Spend = function() end,
    GetAssetFolder = function() return {} end,
    UpgradeZoneAsset = function(_, zone, _, template) return if failUpgrade then nil else {Name = zone, Template = template} end,
}
