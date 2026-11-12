"""Exercise actual carry manager speed and health callbacks with scene mocks."""
from pathlib import Path
import re, subprocess, sys, tempfile
code = (Path(__file__).resolve().parents[1] / 'ArenaCarryManager.luau').read_text()
code = re.sub(r'local (\w+) = require\([^\n]+\)', lambda m: f'local {m[1]} = {m[1]}', code)
# Visual construction requires Studio; isolate it from speed/health tests.
a = code.index('local function rebuildStack(')
b = code.index('\nfunction Carry.Step()', a)
code = code[:a] + 'local function rebuildStack(...) end\n' + code[b:]
source = r'''
local callback
local humanoid = {WalkSpeed=16, Health=100, HealthChanged={Connect=function(_, fn)
callback=fn; return {Disconnect=function() end} end}}
local root = {IsA=function() return true end, Position={}}
local character = {FindFirstChild=function() return root end, FindFirstChildWhichIsA=function() return humanoid end}
local player = {Character=character}
local Players = {GetPlayers=function() return {player} end}
local game = {GetService=function() return Players end}
local Config = {DefaultWalkSpeed=16, MinimumCarrySpeed=8, SpeedPenaltyPerOre=0.35}
local count, inside, dropped = 10, true, 0
local Inventory = {GetOres=function() return {IronOre=count} end}
local Data = {GetProfile=function() return {} end}
local World = {Arena=function() return {} end, InArena=function() return inside end}
local Arena = {DropCarriedOre=function() if inside then dropped+=1; count=0 end end}
'''
source += 'local Carry = (function()\n' + code + '\nend)()\n'
source += r'''
Carry.Step(); assert(humanoid.WalkSpeed == 12.5)
Carry.Step(); assert(humanoid.WalkSpeed == 12.5) -- no accumulating penalty
count=100; Carry.Step(); assert(humanoid.WalkSpeed == 8)
inside=false; Carry.Step(); assert(humanoid.WalkSpeed == 16)
inside=true; humanoid.WalkSpeed=24; count=10
Carry.Step(); assert(humanoid.WalkSpeed == 12.5)
inside=false; humanoid.WalkSpeed=40; Carry.Step(); assert(humanoid.WalkSpeed == 16)
callback(90); assert(dropped == 0)
inside=true; callback(80); assert(dropped == 1)
Carry.Step(); assert(humanoid.WalkSpeed == 16)
callback(95); assert(dropped == 1) -- healing does not drop
count=10; Carry.Step(); Carry.Stop(); assert(humanoid.WalkSpeed == 16)
print("Carry: speed cap, restoration, default speed enforcement, damage and healing checks passed")
'''
with tempfile.TemporaryDirectory() as directory:
    path=Path(directory)/'carry.luau'; path.write_text(source)
    subprocess.run([sys.argv[1], str(path)], check=True)
