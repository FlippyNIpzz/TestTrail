"""Run actual ArenaGeometry with small vector/scene mocks in the official Luau CLI."""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
source = r'''
local Vector3 = {}
local vectorMeta = {}
function Vector3.new(x, y, z) return setmetatable({X=x, Y=y, Z=z}, vectorMeta) end
function vectorMeta.__index(v, key)
    local length = math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z)
    if key == "Magnitude" then return length end
    if key == "Unit" then return Vector3.new(v.X/length, v.Y/length, v.Z/length) end
    error("Unsupported test vector property: " .. key)
end
function vectorMeta.__mul(v, n) return Vector3.new(v.X*n, v.Y*n, v.Z*n) end
local function part(size, position, normalAxis)
    local frame = {RightVector=Vector3.new(1,0,0), UpVector=Vector3.new(0,0,1), LookVector=Vector3.new(1,0,0)}
    frame[normalAxis] = Vector3.new(0,1,0)
    return {Size=size, Position=position, CFrame=frame, IsA=function(_, kind) return kind=="BasePart" end}
end
local floor = part(Vector3.new(0.5,100,100), Vector3.new(1,4.36115074,1), "RightVector")
local function node(children)
    return {FindFirstChild=function(_, name) return children[name] end}
end
local arenaChildren = {ArenaFloor=floor, Floor={}}
local workspace = node({Game=node({World=node({Arena=node({BasicArena=node(arenaChildren)})})})})
'''
source += 'local Geometry = (function()\n' + (root / 'ArenaGeometry.luau').read_text() + '\nend)()\n'
source += r'''
assert(Geometry.Floor()==floor)
arenaChildren.ArenaFloor=nil
assert(Geometry.Floor()==nil, "Must not fall back to another Floor")
arenaChildren.ArenaFloor=floor
local radius, top = Geometry.Dimensions(floor)
assert(radius==50 and math.abs(top-4.61115074)<1e-8)
assert(Geometry.Contains(floor, Vector3.new(1,top,1)))
assert(Geometry.Contains(floor, Vector3.new(1,top+10000,1)))
assert(not Geometry.Contains(floor, Vector3.new(1,top-0.1,1)))
assert(Geometry.Contains(floor, Vector3.new(51,top,1)))
assert(not Geometry.Contains(floor, Vector3.new(51.1,top,1)))
assert(not Geometry.Contains(floor, Vector3.new(46,top,46)), "Rectangular corner must be outside")
math.randomseed(42)
local random = {NextNumber=function(_, low, high)
    return (low or 0) + math.random() * ((high or 1) - (low or 0))
end}
local mean = 0
for _=1,1000 do
    local p=Geometry.RandomSurface(floor, random, 6, 1.5)
    local r=math.sqrt((p.X-1)^2+(p.Z-1)^2)
    assert(r<=44 and Geometry.Contains(floor,p))
    assert(math.abs(p.Y-1.5-top)<1e-8, "Ore bottom must rest on floor top")
    mean += r*r/(44*44)
end
assert(mean/1000>0.45 and mean/1000<0.55, "Spawn distribution must cover disk area")
local p=Geometry.Surface(floor, Vector3.new(101,200,101), math.sqrt(2),1)
assert(Geometry.Contains(floor,p) and math.abs(p.Y-top-1)<1e-8)
local clamped=Geometry.Surface(floor, floor.Position,100,1)
assert(clamped.X==1 and clamped.Z==1)
for _, case in {
    {Vector3.new(80,2,80), "UpVector",40,31},
    {Vector3.new(60,60,4), "LookVector",30,32},
    {Vector3.new(0.5,120,120), "RightVector",60,30.25},
} do
    floor.Size=case[1]
    floor.Position=Vector3.new(150,30,-90)
    floor.CFrame=part(floor.Size,floor.Position,case[2]).CFrame
    local r,y=Geometry.Dimensions(floor)
    assert(r==case[3] and y==case[4])
    assert(Geometry.Contains(floor,Vector3.new(150,y+100,-90)))
    assert(not Geometry.Contains(floor,Vector3.new(150+r+1,y,-90)))
end
floor.CFrame.RightVector=Vector3.new(0.7,0.7,0)
assert(Geometry.Floor()==nil, "Tilted floor must disable arena")
print("Geometry: exact floor resolution, circular bounds, world Y, 1000 spawns, drops, resize/move and axis checks passed")
'''
with tempfile.TemporaryDirectory(prefix='arena-geometry-') as directory:
    bundle = Path(directory) / 'geometry.luau'
    bundle.write_text(source)
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else 'luau', str(bundle)], check=True)
