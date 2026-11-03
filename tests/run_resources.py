"""Emit an isolated Luau resource test bundle for Studio loadstring.
No DataModel modifications: instances and workspace queries are mocked.
python3 tests/run_resources.py > /tmp/tycoon-resources-test.luau
"""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
print('''
local realEnum = Enum
local Enum = { RaycastFilterType = realEnum.RaycastFilterType }
local OverlapParams = { new = function() return {} end }
local RaycastParams = { new = function() return {} end }
local workspace = { Pickups = {}, Blocked = false, Queries = 0, Rays = 0 }
function workspace:GetPartBoundsInBox() self.Queries += 1; return if self.Blocked then { true } else {} end
function workspace:GetServerTimeNow() return 100 end
function workspace:Raycast(origin)
    self.Rays += 1
    if origin.X * origin.X + origin.Z * origin.Z <= 50 * 50 then return { Instance = true } end
    return nil
end
local function signal()
    local handlers = {}
    return { Connect = function(_, callback)
        table.insert(handlers, callback)
        return { Disconnect = function() local i = table.find(handlers, callback); if i then table.remove(handlers, i) end end }
    end, Fire = function() for _, callback in table.clone(handlers) do callback() end end }
end
local newInstance
newInstance = function(class)
    local obj = { ClassName = class, CFrame = CFrame.new(), Size = Vector3.one, Destroying = signal(), Attributes = {}, Children = {}, BoxOffset = CFrame.new() }
    function obj:IsA(name) return name == self.ClassName or (name == "BasePart" and self.ClassName == "Part") end
    function obj:GetDescendants() return table.clone(self.Children) end
    function obj:GetBoundingBox() return self.CFrame * self.BoxOffset, self.Size end
    function obj:GetPivot() return self.CFrame end
    function obj:PivotTo(cf) self.CFrame = cf end
    function obj:SetAttribute(k, v) self.Attributes[k] = v end
    function obj:Clone()
        local copy = newInstance(self.ClassName)
        for _, k in { "Name", "Size", "CFrame", "Color", "Anchored", "CanCollide", "CanTouch", "CanQuery", "BoxOffset" } do copy[k] = self[k] end
        copy.Attributes = table.clone(self.Attributes)
        for _, child in self.Children do table.insert(copy.Children, child:Clone()) end
        return copy
    end
    function obj:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true; self.Destroying.Fire()
        local index = table.find(workspace.Pickups, self)
        if index then table.remove(workspace.Pickups, index) end
        self.Parent = nil
    end
    return setmetatable(obj, { __newindex = function(self, key, value)
        rawset(self, key, value)
        if key == "Parent" and value and (self:IsA("BasePart") or self:IsA("Model")) then table.insert(workspace.Pickups, self) end
    end })
end
local Instance = { new = newInstance }
local floor = newInstance("Part")
floor.Size = Vector3.new(0.5, 100, 100)
floor.CFrame = CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
function floor:IsDescendantOf() return true end
local function node(children) return { FindFirstChild = function(_, name) return children[name] end } end
local oreModels = {}
for index, name in { "OreCluster", "OreClusterWide", "OreClusterJagged" } do
    local model = newInstance("Model"); model.Name = name
    model.Size = Vector3.new(2 + index / 5, 1.5 + index / 5, 2.5)
    model.CFrame = CFrame.new(10 * index, 8, 0)
    model.BoxOffset = CFrame.new(0.1, 0.2, -0.1)
    model.Attributes.PreviewOnly = true
    table.insert(model.Children, newInstance("Part"))
    oreModels[name] = model
end
local fakeTree = node({
    Workspace = node({ World = node({ Arena = node({ BasicArena = node({ Floor = floor }) }) }) }),
    ServerStorage = node({ ResourceModels = node(oreModels) }),
})
local game = { GetService = function() return { Shared = {} } end, FindFirstChild = fakeTree.FindFirstChild }
''')
config = (ROOT / 'src/shared/Features/Resources/ResourcesConfig.luau').read_text()
print('local Config = (function()\n' + config + '\nend)()')
helpers = (ROOT / 'src/shared/Features/Resources/ResourcesHelpers.luau').read_text()
print('local ResourceHelpers = (function()\n' + helpers + '\nend)()')
source = (ROOT / 'src/server/Features/Resources/ResourcesSpawner.luau').read_text()
source = source.replace('require(Shared.Features.Resources.ResourcesHelpers)', 'ResourceHelpers')
source = source.replace('require(Shared.Features.Resources.ResourcesConfig)', 'Config')
source = source.replace('require(Shared.Features.PlayerData.PlayerDataHelpers)', '{ DeepFreeze = function() end }')
print('local Spawner = (function()\n' + source + '\nend)()')
print((ROOT / 'tests/resources.spec.luau').read_text())
