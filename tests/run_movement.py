"""Emit movement tests for Studio loadstring; all character/floor fixtures are unparented.
Actual service/helpers/movement source, Roblox Humanoids/CFrames, fake Player signals.
python3 tests/run_movement.py > /tmp/tycoon-movement-tests.luau
"""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def module(name, path, substitutions=None):
    code = (ROOT / 'src' / path).read_text()
    for old, new in (substitutions or {}).items(): code = code.replace(old, new)
    print(f'local {name} = (function()\n{code}\nend)()')
print('''
local workspace = Instance.new("Folder")
workspace.Name = "Workspace"
local function folder(parent, name)
    local instance = Instance.new("Folder"); instance.Name = name; instance.Parent = parent; return instance
end
local arena = folder(folder(folder(workspace, "World"), "Arena"), "BasicArena")
local floor = Instance.new("Part")
floor.Name = "Floor"; floor.Anchored = true; floor.Shape = Enum.PartType.Cylinder
floor.Size = Vector3.new(0.5, 100, 100)
floor.CFrame = CFrame.new(1, 4, 1) * CFrame.Angles(0, 0, math.pi / 2)
floor.Parent = arena
local players = {}
local Players = { GetPlayers = function() return table.clone(players) end }
local game = { GetService = function(_, name)
    if name == "Players" then return Players end
    return { Shared = {} }
end, FindFirstChild = function(_, name) if name == "Workspace" then return workspace end end }
local Spawner = { Initialize = function() end, Destroy = function() end, Step = function() end, Schedule = function() end }
local function signal()
    local handlers = {}
    return { Connect = function(_, callback)
        table.insert(handlers, callback)
        return { Disconnect = function() local i=table.find(handlers, callback); if i then table.remove(handlers,i) end end }
    end, Fire = function(_, ...) for _, callback in table.clone(handlers) do callback(...) end end,
    Count = function() return #handlers end }
end
''')
module('Config', 'shared/Features/Resources/ResourcesConfig.luau')
module('Tables', 'shared/Features/PlayerData/PlayerDataHelpers.luau')
module('Helpers', 'shared/Features/Resources/ResourcesHelpers.luau')
module('Movement', 'server/Features/Resources/ResourcesMovement.luau', {
    'require(Shared.Features.Resources.ResourcesConfig)': 'Config',
    'require(Shared.Features.Resources.ResourcesHelpers)': 'Helpers',
})
module('Service', 'server/Features/Resources/ResourcesService.luau', {
    'require(script.Parent.ResourcesSpawner)': 'Spawner',
    'require(game:GetService("ReplicatedStorage").Shared.Features.Resources.ResourcesConfig)': 'Config',
    'require(game:GetService("ReplicatedStorage").Shared.Features.PlayerData.PlayerDataHelpers)': 'Tables',
    'require(script.Parent.ResourcesMovement)': 'Movement',
})
print((ROOT / 'tests/movement.spec.luau').read_text())
