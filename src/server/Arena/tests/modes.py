"""Unit tests for Arena Modes: MoltenSurge, MeteorShower, and TitanAwakening."""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]

source = r'''
local clock = 100
local workspace = {
    GetServerTimeNow = function() return clock end,
    FindFirstChild = function(_, name) return nil end,
}
local game = {
    GetService = function(_, name)
        if name == "Players" then
            return Players
        end
        return {}
    end
}

local Vector3 = {}
local vectorMeta = {}
function Vector3.new(x, y, z) return setmetatable({X=x or 0, Y=y or 0, Z=z or 0}, vectorMeta) end
function vectorMeta.__index(v, key)
    local length = math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z)
    if key == "Magnitude" then return length end
    if key == "Unit" then return (if length > 0 then Vector3.new(v.X/length, v.Y/length, v.Z/length) else Vector3.new(0,0,0)) end
    if key == "Lerp" then
        return function(self, target, alpha)
            return self + (target - self) * alpha
        end
    end
    error("Unsupported vector key: " .. tostring(key))
end
function vectorMeta.__add(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
function vectorMeta.__sub(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
function vectorMeta.__mul(a, b)
    if type(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
    return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
function vectorMeta:Lerp(target, alpha)
    return self + (target - self) * alpha
end

local CFrame = {}
local cframeMeta = {}
function CFrame.new(pos, lookAt)
    local posVec = if type(pos) == "table" and pos.X then pos else Vector3.new(pos or 0, 0, 0)
    return setmetatable({Position = posVec}, cframeMeta)
end
function CFrame.Angles(...) return CFrame.new(Vector3.new(0, 0, 0)) end
function CFrame.lookAt(pos, target) return CFrame.new(pos) end
function cframeMeta.__mul(a, b) return CFrame.new(a.Position + (b.Position or Vector3.new(0,0,0))) end

local Random = {
    new = function()
        return {
            NextInteger = function(_, low, high) return low or 1 end,
            NextNumber = function(_, low, high) return low or 0 end,
        }
    end
}
local Color3 = {
    fromRGB = function(r, g, b) return {R=r, G=g, B=b} end,
}
local Enum = {
    PartType = { Ball = "Ball", Cylinder = "Cylinder", Block = "Block" },
    Material = { Slate = "Slate", Neon = "Neon", Basalt = "Basalt" },
}

local Instance = {}
function Instance.new(kind)
    local props = {
        ClassName = kind,
        Name = kind,
        Position = Vector3.new(0, 0, 0),
        CFrame = CFrame.new(Vector3.new(0,0,0)),
        Size = Vector3.new(1, 1, 1),
        Children = {},
        Attributes = {},
        Parent = nil,
    }
    local obj = {}
    local meta = {}
    function meta.__index(t, k)
        return props[k]
    end
    function meta.__newindex(t, k, v)
        if k == "Parent" then
            local old = props.Parent
            if old and old.Children then
                for idx, c in ipairs(old.Children) do
                    if c == t then table.remove(old.Children, idx); break end
                end
            end
            props.Parent = v
            if v and v.Children then
                table.insert(v.Children, t)
            end
            return
        end
        props[k] = v
    end
    setmetatable(obj, meta)

    function props:IsA(name) return name == kind or (kind == "Part" and name == "BasePart") end
    function props:IsDescendantOf(root) return props.Parent ~= nil end
    function props:FindFirstChild(name)
        for _, c in ipairs(self.Children) do
            if c.Name == name then return c end
        end
        return nil
    end
    function props:FindFirstChildWhichIsA(name)
        for _, c in ipairs(self.Children) do
            if c:IsA(name) then return c end
        end
        return nil
    end
    function props:GetChildren()
        local list = {}
        for _, c in ipairs(self.Children) do table.insert(list, c) end
        return list
    end
    function props:SetAttribute(k, v) self.Attributes[k] = v end
    function props:GetAttribute(k) return self.Attributes[k] end
    function props:Destroy()
        obj.Parent = nil
        for _, c in ipairs(self.Children) do c:Destroy() end
        self.Children = {}
    end
    function props:TakeDamage(amount)
        if self.Health then
            self.Health = math.max(0, self.Health - amount)
        end
    end
    function props:PivotTo(cf) self.CFrame = cf end
    return obj
end

local task = {
    delay = function(sec, fn) end
}

local damageTaken = 0
local humanoid = Instance.new("Humanoid")
humanoid.Health = 100
humanoid.MaxHealth = 100
function humanoid:TakeDamage(amount)
    damageTaken += amount
    self.Health = math.max(0, self.Health - amount)
end

local rootPart = Instance.new("Part")
rootPart.Name = "HumanoidRootPart"
rootPart.Position = Vector3.new(5, 1, 5)

local character = Instance.new("Model")
character.Name = "TestPlayer"
rootPart.Parent = character
humanoid.Parent = character

local player = { Character = character }
Players = {
    GetPlayers = function() return { player } end,
}

local floorPart = Instance.new("Part")
floorPart.Position = Vector3.new(0, 0, 0)
local Geometry = {
    Contains = function(_, pt) return true end,
    RandomSurface = function(_, rnd, inset, height) return Vector3.new(5, height, 5) end,
    Surface = function(_, pt, inset, height) return Vector3.new(pt.X, height, pt.Z) end,
}

local spawnedOres = {}
local context = {
    Bounds = floorPart,
    RuntimeFolder = Instance.new("Folder"),
    HazardsFolder = Instance.new("Folder"),
    OresFolder = Instance.new("Folder"),
    DropsFolder = Instance.new("Folder"),
    BossesFolder = Instance.new("Folder"),
    RegisterOre = function(ore, id) end,
    SpawnOreAt = function(bounds, id, pos)
        table.insert(spawnedOres, {id = id, pos = pos})
        return Instance.new("Part")
    end,
}
'''

# Read and inline MoltenSurge, MeteorShower, TitanAwakening
def prepare_code(file_path):
    txt = file_path.read_text()
    import re
    txt = re.sub(r'local (\w+) = require\([^\n]+\)', lambda m: f'local {m[1]} = {m[1]}', txt)
    return txt

molten_code = prepare_code(root / 'Modes' / 'MoltenSurge.luau')
meteor_code = prepare_code(root / 'Modes' / 'MeteorShower.luau')
titan_code = prepare_code(root / 'Modes' / 'TitanAwakening.luau')

source += f'''
local MoltenSurge = (function()
{molten_code}
end)()

local MeteorShower = (function()
{meteor_code}
end)()

local TitanAwakening = (function()
{titan_code}
end)()

-- Test 1: MoltenSurge
MoltenSurge.Start(context)
clock = 102
MoltenSurge.Step(clock, 0.1)
assert(#context.HazardsFolder:GetChildren() >= 2, "MoltenSurge must spawn lava pools")
-- Transition warning to active
clock = 104
MoltenSurge.Step(clock, 0.1)
assert(damageTaken > 0, "MoltenSurge active pool must damage nearby character")
local preStopDamage = damageTaken
MoltenSurge.Stop()
assert(#context.HazardsFolder:GetChildren() == 0, "MoltenSurge stop must clear hazard parts")

-- Test 2: MeteorShower
damageTaken = 0
clock = 200
MeteorShower.Start(context)
clock = 202
MeteorShower.Step(clock, 0.1)
assert(#context.HazardsFolder:GetChildren() >= 2, "MeteorShower must spawn reticles & meteors")
-- Impact
clock = 205
MeteorShower.Step(clock, 0.1)
assert(#spawnedOres >= 2, "MeteorShower impact must spawn crater ores")
assert(damageTaken > 0, "MeteorShower impact must deal blast damage")
MeteorShower.Stop()

-- Test 3: TitanAwakening
damageTaken = 0
clock = 300
TitanAwakening.Start(context)
assert(#context.BossesFolder:GetChildren() >= 1, "TitanAwakening must have a boss model")
-- Roam
clock = 301
TitanAwakening.Step(clock, 0.1)
-- Advance to slam charge
clock = 305
TitanAwakening.Step(clock, 0.1)
-- Advance to slam execution
clock = 307
TitanAwakening.Step(clock, 0.1)
assert(damageTaken > 0, "Titan ground slam must deal AoE damage")
TitanAwakening.Stop()
assert(#context.BossesFolder:GetChildren() == 0, "TitanAwakening procedural boss must clean up on stop")

print("Modes: MoltenSurge, MeteorShower, and TitanAwakening unit tests passed successfully!")
'''

with tempfile.TemporaryDirectory(prefix='arena-modes-') as directory:
    path = Path(directory) / 'modes.luau'
    path.write_text(source)
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else 'luau', str(path)], check=True)
