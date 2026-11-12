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
with tempfile.TemporaryDirectory(prefix='arena-tests-') as directory:
    path = Path(directory) / 'arena.luau'
    path.write_text(source)
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else 'luau', str(path)], check=True)
