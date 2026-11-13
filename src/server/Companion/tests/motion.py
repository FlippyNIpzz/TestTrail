"""Exercise production motion rules and server traversal with deterministic scene adapters."""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
shared = root.parents[1] / 'shared' / 'CompanionMotionMath.luau'
# Also supports the isolated review staging directory.
if not shared.exists():
    shared = root.parent / 'shared' / 'CompanionMotionMath.luau'

def module(path):
    code = path.read_text()
    code = re.sub(r'export type State = \{.*?\n\}', '', code, flags=re.S)
    code = re.sub(r'local (\w+) = require\([^\n]+\)', lambda m: f'local {m[1]} = {m[1]}', code)
    return '(function()\n' + code + '\nend)()\n'

source = 'local Motion = ' + module(shared)
source += r'''
assert(Motion.Grounded(0, false, 0), "Measured foot clearance, not torso height")
assert(Motion.Grounded(0.2, true, 0) and not Motion.Grounded(0.2, false, 0), "Ground hysteresis")
assert(not Motion.Grounded(nil, true, 0), "Ray misses cannot be grounded")
assert(not Motion.Grounded(0, true, 8), "Upward launch is airborne")
for _, case in {{0,"Walk"},{0.4,"StepUp"},{-0.4,"StepDown"},{2,"Jump"},{4,"Blocked"},{-7,"Blocked"}} do
    assert(Motion.Terrain(case[1],1,0.65,3.5,6,0.7)==case[2])
end
assert(Motion.Terrain(nil,1,0.65,3.5,6,0.7)=="Blocked")
assert(Motion.Terrain(0,0.4,0.65,3.5,6,0.7)=="Blocked")
local previous = nil
for i=0,1000 do
    local x,y,stance=Motion.Gait(i/1000*math.pi*2)
    assert(x>=-1 and x<=1 and y>=0 and y<=1)
    if stance then assert(y==0, "Stance feet stay down") end
    if previous then assert(math.abs(x-previous)<0.02, "Continuous foot cycle") end
    previous=x
end
local w = Motion.Attack(-1); assert(w==0)
w=Motion.Attack(100); assert(w==0)
w=Motion.Attack(0); assert(w==0)
w=Motion.Attack(0.15); assert(w==1)
assert(Motion.JointName("Left Shoulder")==Motion.JointName("LeftShoulder"))
assert(Motion.JointName("RootJoint")==Motion.JointName("Body"))
assert(Motion.JointName("RightUpperArm")==Motion.JointName("RightShoulder"))

local Vector3 = {}
local vm = {}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vm) end
Vector3.zero=Vector3.new(0,0,0)
function vm.__index(v,k)
    if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
    if k=="Unit" then return v/v.Magnitude end
    error(k)
end
function vm.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function vm.__sub(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function vm.__mul(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
function vm.__div(a,b) return Vector3.new(a.X/b,a.Y/b,a.Z/b) end
local CFrame={}
local cm={}
function CFrame.new(v) return setmetatable({Position=v},cm) end
function CFrame.lookAt(p,_) return CFrame.new(p) end
function cm.__index(_,k) if k=="Rotation" then return CFrame.new(Vector3.zero) end; error(k) end
function cm.__mul(a,b) return CFrame.new(a.Position+b.Position) end
local now=0
local os={clock=function() return now end}
local floorHeight=function(_) return 0 end
local block=nil -- solid body volume: {MinX, MaxX, Top}
local function overlapsBlock(cf,size)
    if not block then return false end
    local bottom=cf.Position.Y-size.Y*0.5
    local top=cf.Position.Y+size.Y*0.5
    local minX=cf.Position.X-size.X*0.5
    local maxX=cf.Position.X+size.X*0.5
    if maxX<=block.MinX or minX>=block.MaxX then return false end
    return top>0 and bottom<block.Top
end
local pathCount=0
local queued={}
local Enum={PathStatus={Success="Success"},PathWaypointAction={Jump="Jump"}}
local PathfindingService={CreatePath=function()
    pathCount+=1
    return {ComputeAsync=function() end,Status="Success",Destroy=function() end,
        GetWaypoints=function() return {{Position=Vector3.zero},{Position=Vector3.new(0,0,4)}} end}
end}
local task={spawn=function(fn) table.insert(queued,fn) end}
local ReplicatedStorage={}
local game={GetService=function(_,name)
    if name=="PathfindingService" then return PathfindingService end
    return ReplicatedStorage
end}
local workspace={FallenPartsDestroyHeight=-100, Blockcast=function(_,cf,size,_,_)
    return if overlapsBlock(cf,size) then {} else nil
end}
local Config={StepHeight=0.65,JumpHeight=3.5,JumpLookAhead=0.3,PathJumpRequestLifetime=0.75,
    MaxDrop=6,Gravity=60,MaxSlopeDegrees=42,
    PathRetryInterval=1.5,PathTargetTolerance=5,MaxTravelPerSubstep=0.5}
local World={Dimensions=function() return 2,4,0.5 end,Parameters=function() return {} end}
function World.Support(point,offset,up,down,_)
    local y=floorHeight(point.X)
    if y and y<=point.Y-offset+up and y>=point.Y-offset-down then
        return {Position=Vector3.new(point.X,y,point.Z),Normal=Vector3.new(0,1,0)}
    end
    return nil
end
function World.Ground(_,point) return Vector3.new(point.X,(floorHeight(point.X) or point.Y-2)+2,point.Z) end
local function model()
    local m={frame=CFrame.new(Vector3.new(0,2,0)),attrs={},Parent=true}
    function m:GetPivot() return self.frame end
    function m:PivotTo(cf) self.frame=cf end
    function m:SetAttribute(k,v) self.attrs[k]=v end
    return m
end
'''
source += 'local Locomotion = ' + module(root / 'CompanionLocomotion.luau')
source += r'''
local m=model()
local s=Locomotion.New(m)
local function tick(target,speed,mode,alive)
    now+=0.1
    Locomotion.Step(s,target,speed or 8,0.1,alive~=false,mode or "Follow")
end
tick(Vector3.new(8,2,0))
assert(m:GetPivot().Position.X>0.7 and math.abs(m:GetPivot().Position.Y-2)<1e-6)
assert(m.attrs.CompanionGrounded and m.attrs.CompanionLocomotionState=="Walk")
-- Home/Fight don't depend on an owner's humanoid or jump state.
tick(m:GetPivot().Position,8,"Home")
assert(m.attrs.CompanionLocomotionState=="Idle")
tick(m:GetPivot().Position,8,"Fight")
assert(m.attrs.CompanionGrounded)
-- Ascending/descending a small step tracks local support.
m:PivotTo(CFrame.new(Vector3.new(0,2,0))); Locomotion.Reset(s)
floorHeight=function(x) return if x>=0.3 then 0.4 else 0 end
tick(Vector3.new(3,2.4,0))
assert(math.abs(m:GetPivot().Position.Y-2.4)<1e-6)
assert(m.attrs.CompanionLocomotionState=="StepUp")
floorHeight=function(x) return if x>=1 then 0 else 0.4 end
tick(Vector3.new(3,2,0))
assert(math.abs(m:GetPivot().Position.Y-2)<1e-6)
assert(m.attrs.CompanionLocomotionState=="StepDown")
-- A high ledge creates a trajectory, followed by landing.
m:PivotTo(CFrame.new(Vector3.new(0,2,0))); Locomotion.Reset(s)
floorHeight=function(x) return if x>=0.3 then 2 else 0 end
tick(Vector3.new(4,4,0))
assert(not s.Grounded and s.VerticalSpeed>0 and m.attrs.CompanionLocomotionState=="Jump")
local fell=false
for _=1,20 do tick(Vector3.new(4,4,0),3); if s.VerticalSpeed<0 then fell=true end end
assert(fell and s.Grounded and s.LandingSpeed>0)
-- No support at an edge means stop rather than walking into a void.
floorHeight=function(x) return if x<0.3 then 0 else nil end
m:PivotTo(CFrame.new(Vector3.new(0,2,0))); Locomotion.Reset(s)
tick(Vector3.new(4,2,0))
assert(m:GetPivot().Position.X<0.3 and s.Grounded)
-- Body blockage queues bounded routing, and stale results cannot replace a reset route.
floorHeight=function(_) return 0 end
m:PivotTo(CFrame.new(Vector3.new(0,2,0))); Locomotion.Reset(s)
m:PivotTo(CFrame.new(Vector3.new(0,2,0))); Locomotion.Reset(s)
block={MinX=-1e9,MaxX=1e9,Top=10}
tick(Vector3.new(4,2,0))
assert(m:GetPivot().Position.X==0 and s.Pending)
local generation=s.Generation
Locomotion.Reset(s)
for _,fn in queued do fn() end
queued={}
assert(#s.Waypoints==0 and s.Generation>generation)
block=nil
-- A solid low obstacle is jumped over instead of stopping the route.
floorHeight=function(x) return if x>=1.2 and x<2.6 then 1.5 else 0 end
m:PivotTo(CFrame.new(Vector3.new(0,2,0))); Locomotion.Reset(s)
block={MinX=1.2,MaxX=2.6,Top=1.5}
local launched=false
for _=1,30 do
    tick(Vector3.new(4,2,0))
    launched = launched or not s.Grounded
    if launched and s.Grounded and m:GetPivot().Position.X>2.6 then break end
end
assert(launched, "Low obstacle must trigger a jump")
assert(s.Grounded and m:GetPivot().Position.X>2.6, "Jump must carry the body past the obstacle")
block=nil
-- A path jump waypoint still launches when the support probe reports Blocked.
floorHeight=function(x) return if x>=0.5 then nil else 0 end
m:PivotTo(CFrame.new(Vector3.new(0,2,0))); Locomotion.Reset(s)
s.Waypoints={{Position=Vector3.new(0,0,0),Action="Jump"},{Position=Vector3.new(4,0,0)}}
s.Index=1
block={MinX=0.5,MaxX=1e9,Top=10}
tick(Vector3.new(4,2,0))
assert(not s.Grounded and s.VerticalSpeed>0, "Requested jump overrides blocked terrain")
block=nil
floorHeight=function(_) return 0 end
m:PivotTo(CFrame.new(Vector3.new(0,2,0))); Locomotion.Reset(s)
s.VerticalSpeed=-20; s.AirTime=1; s.Grounded=false
Locomotion.Reset(s)
assert(s.VerticalSpeed==0 and s.AirTime==0 and s.Grounded and m.attrs.CompanionTeleportId>0)
-- A jump waypoint at the route origin must not be skipped.
s.Mode="Follow"
s.Waypoints={{Position=Vector3.new(0,0,0),Action="Jump"},{Position=Vector3.new(4,0,0)}}
s.Index=1
tick(Vector3.new(4,2,0))
assert(not s.Grounded and s.VerticalSpeed>0, "Origin jump waypoint launches")
m:PivotTo(CFrame.new(Vector3.new(0,2,0))); Locomotion.Reset(s)
-- Removing support makes the companion fall even while idle.
floorHeight=function(_) return nil end
tick(nil)
assert(not s.Grounded and s.VerticalSpeed<0 and m.attrs.CompanionLocomotionState=="Fall")
floorHeight=function(_) return 0 end
m:PivotTo(CFrame.new(Vector3.new(0,2,0))); Locomotion.Reset(s)
-- Defeat stops walking while still allowing gravity to settle the model.
tick(Vector3.new(20,2,0),8,"Home",false)
assert(m:GetPivot().Position.X==0 and m.attrs.CompanionLocomotionState=="Defeated")
print("PASS: ground hysteresis, missing support, gait continuity, attack envelopes, joint aliases, flat/step/jump/land/edge traversal, solid obstacle jumps, blocked routing, stale path reset, teleports, modes and defeat")
'''
with tempfile.TemporaryDirectory(prefix='companion-motion-') as directory:
    bundle = Path(directory) / 'motion.luau'
    bundle.write_text(source)
    subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau', str(bundle)], check=True)
