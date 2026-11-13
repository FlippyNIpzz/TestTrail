"""Test actual visual rig construction with minimal hierarchy/translation mocks."""
from pathlib import Path
import re
import subprocess
import sys
import tempfile
root = Path(__file__).resolve().parents[1]
src = root.parents[1]
rig = src / 'client/Companion/CompanionRig.luau'
math = src / 'shared/CompanionMotionMath.luau'
if not rig.exists():
    rig = root.parent / 'client/CompanionRig.luau'
    math = root.parent / 'shared/CompanionMotionMath.luau'
source = 'local MotionMath = (function()\n' + math.read_text() + '\nend)()\n'
source += r'''
local Vector3={}
local vm={}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vm) end
Vector3.zero=Vector3.new(0,0,0)
function vm.__index(v,k)
    if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
    error(k)
end
function vm.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function vm.__sub(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function vm.__mul(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
function vm.__div(a,b) return Vector3.new(a.X/b,a.Y/b,a.Z/b) end
local CFrame={}
local cm={}
function CFrame.new(v) return setmetatable({Position=v or Vector3.zero},cm) end
CFrame.identity=CFrame.new()
function cm.__index(cf,k)
    if k=="Rotation" then return CFrame.identity end
    if k=="UpVector" then return Vector3.new(0,1,0) end
    if k=="ToObjectSpace" then return function(a,b) return CFrame.new(b.Position-a.Position) end end
    if k=="PointToObjectSpace" then return function(a,b) return b-a.Position end end
    if k=="Inverse" then return function(a) return CFrame.new(Vector3.zero-a.Position) end end
    if k=="Lerp" then return function(a,b,t) return CFrame.new(a.Position+(b.Position-a.Position)*t) end end
    error(k)
end
function cm.__mul(a,b) return CFrame.new(a.Position+b.Position) end
local methods={}
local im={}
local warnings={}
local warn=function(message) table.insert(warnings,message) end
function im.__index(item,k)
    if k=="Position" then return item.CFrame.Position end
    return methods[k]
end
function im.__newindex(item,k,v)
    rawset(item,k,v)
    if k=="Parent" and v then table.insert(v.Children,item) end
end
local Instance={}
function Instance.new(class)
    return setmetatable({ClassName=class,Name=class,Children={},CFrame=CFrame.new(),
        C0=CFrame.new(),C1=CFrame.new(),Size=Vector3.new(1,1,1)},im)
end
function methods:IsA(class)
    if class=="BasePart" then return self.ClassName=="Part" end
    if class=="JointInstance" then return self.ClassName=="Motor6D" or self.ClassName=="Weld" end
    return self.ClassName==class
end
function methods:GetDescendants()
    local result={}
    local function add(item) for _,child in item.Children do table.insert(result,child); add(child) end end
    add(self); return result
end
function methods:FindFirstChild(name,recursive)
    for _,child in (if recursive then self:GetDescendants() else self.Children) do
        if child.Name==name then return child end
    end
    return nil
end
function methods:GetPivot() return CFrame.new() end
local function node(class,name,parent,position)
    local n=Instance.new(class); n.Name=name; n.CFrame=CFrame.new(position); n.Parent=parent; return n
end
local model=node("Model","TestRig",nil)
local root=node("Part","CompanionRoot",model)
local torso=node("Part","Torso",model)
local upper=node("Part","LeftUpperArm",model,Vector3.new(-1,0,0))
local lower=node("Part","LeftLowerArm",model,Vector3.new(-1,-1,0))
local hand=node("Part","LeftHand",model,Vector3.new(-1,-2,0))
local body=node("Motor6D","RootJoint",root); body.Part0=root; body.Part1=torso
local shoulder=node("Motor6D","Left Shoulder",torso); shoulder.Part0=torso; shoulder.Part1=upper
shoulder.C0=CFrame.new(Vector3.new(-0.5,0.2,0))
local elbow=node("Motor6D","CustomElbow",upper); elbow.Part0=upper; elbow.Part1=lower
local wrist=node("WeldConstraint","ExistingWrist",lower); wrist.Part0=lower; wrist.Part1=hand
local decoration=node("Part","HandGem",model,Vector3.new(-1,-2.1,0))
local right=node("Part","RightUpperArm",model,Vector3.new(1,0,0))
local attachment=node("Attachment","RightShoulderRigAttachment",right)
attachment.WorldCFrame=CFrame.new(Vector3.new(0.7,0.3,0))
'''
code=rig.read_text()
code=re.sub(r'local MotionMath = require\([^\n]+\)', 'local MotionMath = MotionMath', code)
code=re.sub(r'export type Joint = [^\n]+\n', '', code)
code=re.sub(r'export type Foot = \{.*?\n\}', '', code, flags=re.S)
source+='local Rig = (function()\n'+code+'\nend)()\n'
source+=r'''
local joints=Rig.Setup(model)
assert(joints.body.Motor==body and joints.leftshoulder.Motor==shoulder)
assert(joints.leftelbow.Motor==elbow, "Connectivity beats an arbitrary motor name")
assert(joints.leftwrist==nil, "Preserve existing rigid joint; do not add competing motor")
assert(#warnings>0)
assert(joints.rightshoulder.Motor.C0.Position.X==0.7, "Use authored attachment pivot")
local leftMotors=0
for _,item in model:GetDescendants() do
    if item:IsA("Motor6D") and item.Part1==upper then leftMotors+=1 end
end
assert(leftMotors==1, "Alias cannot duplicate an existing shoulder")
assert(joints.leftshoulder.BaseC0==shoulder.C0, "Authored rest frame retained")
assert(root.Anchored and not hand.Anchored and not hand.CanCollide)
local gemWeld=decoration:FindFirstChild("WeldConstraint")
assert(gemWeld and gemWeld.Part0==hand, "Decoration follows nearest connected limb")
local count=#model:GetDescendants()
Rig.Setup(model)
assert(#model:GetDescendants()==count, "Rig setup must be idempotent")
local conflict=node("WeldConstraint","ConflictingElbowWeld",lower)
conflict.Part0=upper; conflict.Part1=lower
local conflicted=Rig.Setup(model)
assert(conflicted.leftelbow==nil and conflicted.customelbow==nil, "Do not drive a motor locked by a rigid weld")
print("PASS: authored rest transforms, joint aliases/connectivity, no duplicate motors, rigid-weld preservation, attachment pivots, decoration ownership and idempotent rig setup")
'''
with tempfile.TemporaryDirectory(prefix='companion-rig-') as directory:
    path=Path(directory)/'rig.luau'; path.write_text(source)
    subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'luau',str(path)],check=True)
