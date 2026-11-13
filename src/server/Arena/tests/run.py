"""Server collection security checks with mocked Roblox services; pass a Luau CLI path."""
from pathlib import Path
import re
import subprocess
import sys
import tempfile
root = Path(__file__).resolve().parents[1]
source = r'''
local Players = {}
local game = {GetService = function(_, name) return if name == "Players" then Players else {} end}
local Random = {new = function() return {} end}
local clock = 100
local os = {clock=function() return clock end}
local workspace = {GetServerTimeNow=function() return clock end}
local Config = {InteractionDistance=12, CollectionCooldown=0.3, Ores={IronOre={Amount=1}}}
local loaded, placed, inArena = true, true, true
local forge = {IsA=function(_, kind) return kind == "BasePart" end}
local assets = {FindFirstChild=function() return if placed then forge else nil end}
local model = {IsDescendantOf=function() return true end, FindFirstChild=function() return assets end}
local player = {Parent=Players, UserId=1}
Players.GetPlayers = function() return {player} end
local base = {Player=player, Model=model}
local BaseManager = {GetBaseForPlayer=function() return base end}
local Data = {GetProfile=function() return if loaded then {} else nil end}
local awarded = 0
local Inventory = {AddItem=function(_, id, amount) assert(id == "IronOre"); awarded += amount end}
local World = {Arena=function() return {} end, InArena=function() return inArena end}
local distance = 5
local position = setmetatable({}, {__sub=function() return {Magnitude=distance} end})
local rootPart = {Position=position, IsA=function() return true end}
local humanoid = {Health=100}
player.Character = {FindFirstChild=function() return rootPart end, FindFirstChildWhichIsA=function() return humanoid end}
'''
source += r'''
local vectorMeta = {}
local Vector3 = {new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z}, vectorMeta) end}
vectorMeta.__add = function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vectorMeta.__sub = function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
local CFrame = {new=function(p) return {Position=p} end}
local Enum = {PartType={Ball=1}, Material={Slate=1}}
local Instance = {new=function()
    local part = {Destroying={Connect=function() end}}
    part.SetAttribute=function(self,k,v) self[k]=v end
    part.Destroy=function(self) self.Parent=nil; self.Destroyed=true end
    return part
end}
local sceneChildren, storedChildren = {}, {}
local function node(children) return {FindFirstChild=function(_,name) return children[name] end} end
workspace.FindFirstChild = function(_,name) return sceneChildren[name] end
local oldService = game.GetService
game.GetService = function(self,name)
    if name == "ServerStorage" then return node(storedChildren) end
    return oldService(self,name)
end
World.ArenaSurface = function(_,p,_,height) return Vector3.new(p.X,height,p.Z) end
local cloned
local function template()
    return {Archivable=true, IsA=function(_,kind) return kind=="Model" end,
        FindFirstChildWhichIsA=function() return {} end,
        Clone=function()
            local part = {IsA=function(_,kind) return kind=="BasePart" end}
            cloned = {GetBoundingBox=function() return {Position=Vector3.new(0,2,0)},Vector3.new(4,4,4) end,
                GetPivot=function() return Vector3.new(0,2,0) end,
                PivotTo=function(self,p) self.Pivot=p end,
                GetDescendants=function() return {part} end, Part=part}
            return cloned
        end}
end
'''
code = (root / 'Arena.luau').read_text()
code = re.sub(r'local (\w+) = require\([^\n]+\)', lambda m: f'local {m[1]} = {m[1]}', code)
code = code.replace('return Arena\n', '''
function Arena.TestDrop(owner)
    local ore = Arena.TestOre()
    dropInfo[ore] = {Owner=owner, Amount=7, UnlockAt=104, ExpiresAt=160}
    lastCollection[player] = nil
    return ore
end
function Arena.TestOre()
    ores = {}
    local ore = {Parent=ores, Position=position, Destroy=function(self) self.Parent=nil end}
    registered[ore] = "IronOre"
    return ore
end
return Arena
''')
source += 'local Arena = (function()\n' + code + '\nend)()\n'
source += r'''
local ore = Arena.TestOre()
placed = false
assert(not Arena.TryCollectOre(player, ore)); assert(awarded == 0)
placed = true; loaded = false
assert(not Arena.TryCollectOre(player, ore))
loaded = true; distance = 50
assert(not Arena.TryCollectOre(player, ore))
distance = 5; inArena = false
assert(not Arena.TryCollectOre(player, ore))
inArena = true; humanoid.Health = 0
assert(not Arena.TryCollectOre(player, ore))
humanoid.Health = 100
base.Player = {}
assert(not Arena.TryCollectOre(player, ore))
base.Player = player
assert(Arena.TryCollectOre(player, ore)); assert(awarded == 1)
assert(not Arena.TryCollectOre(player, ore)); assert(awarded == 1)
ore = Arena.TestOre()
assert(not Arena.TryCollectOre(player, ore)); assert(awarded == 1)
placed = false
assert(not Arena.CanInteractWithOre(player, ore))
placed = true
ore = Arena.TestDrop(1)
assert(not Arena.TryCollectOre(player, ore)); assert(awarded == 1)
clock = 104
assert(Arena.TryCollectOre(player, ore)); assert(awarded == 8)
clock = 100
ore = Arena.TestDrop(2)
assert(Arena.TryCollectOre(player, ore)); assert(awarded == 15)
assert(not Arena.TryCollectOre(player, ore)); assert(awarded == 15)
-- Exercise automatic scanning, not just the direct collection API.
clock = 200
ore = Arena.TestOre()
placed = false; Arena.CollectNearbyOre(); assert(awarded == 15)
placed = true; loaded = false; Arena.CollectNearbyOre(); assert(awarded == 15)
loaded = true; distance = 13; Arena.CollectNearbyOre(); assert(awarded == 15)
distance = 12; inArena = false; Arena.CollectNearbyOre(); assert(awarded == 15)
inArena = true; humanoid.Health = 0; Arena.CollectNearbyOre(); assert(awarded == 15)
humanoid.Health = 100; Arena.CollectNearbyOre(); assert(awarded == 16)
Arena.CollectNearbyOre(); assert(awarded == 16) -- claimed once
ore = Arena.TestOre(); Arena.CollectNearbyOre(); assert(awarded == 16)
clock += 1; placed = false; Arena.CollectNearbyOre(); assert(awarded == 16)
placed = true; Arena.CollectNearbyOre(); assert(awarded == 17)
clock = 100; ore = Arena.TestDrop(1)
Arena.CollectNearbyOre(); assert(awarded == 17)
clock = 104; Arena.CollectNearbyOre(); assert(awarded == 24)
clock = 100; ore = Arena.TestDrop(2)
Arena.CollectNearbyOre(); assert(awarded == 31)
print("Arena: direct/automatic pickup, range, forge removal, cooldown, owner lock and theft checks passed")
'''
source += r'''
Arena.TestOre()
local location = Vector3.new(5,0,6)
local fallback = Arena.SpawnOreAt({},"IronOre",location)
assert(fallback and fallback.Transparency == nil and fallback.OreType == "IronOre")
assert(Arena.SpawnOreAt({},"Unknown",location) == nil)
local storageTemplate = template()
storedChildren.ResourceModels = node({IronOre=storageTemplate})
local storedOre = Arena.SpawnOreAt({},"IronOre",location)
assert(storedOre.Transparency == 1 and cloned.Parent == storedOre)
assert(cloned.Pivot.Y == 2 and cloned.Part.Anchored and not cloned.Part.CanCollide)
local authoredTemplate = template()
sceneChildren.Game = node({Arena=node({Resource_Models=node({IronOre=authoredTemplate})})})
storageTemplate.Clone = function() error("Workspace template must take precedence") end
local authoredOre = Arena.SpawnOreAt({},"IronOre",location)
assert(cloned.Parent == authoredOre and authoredOre.Transparency == 1)
local visual = cloned
clock += 1
assert(Arena.TryCollectOre(player,authoredOre))
assert(authoredOre.Destroyed and visual.Parent == authoredOre, "Visual must be owned by destroyed pickup root")
authoredTemplate.Archivable = false
storedChildren.ResourceModels = nil
assert(Arena.SpawnOreAt({},"IronOre",location).Transparency == nil)
print("PASS: authored/storage ore spawning, precedence, procedural fallback and pickup ownership")
'''
with tempfile.TemporaryDirectory(prefix='arena-tests-') as directory:
    path = Path(directory) / 'arena.luau'
    path.write_text(source)
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else 'luau', str(path)], check=True)
