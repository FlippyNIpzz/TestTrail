-- Run in Studio Edit mode after loading this file as a function body.
-- Only authored companion templates and gallery copies are changed.
local storage = game:GetService("ServerStorage")
local templates = storage:WaitForChild("CompanionModels")
if not storage:FindFirstChild("CompanionModels_BeforeIK") then
    local backup = templates:Clone()
    backup.Name = "CompanionModels_BeforeIK"
    backup.Parent = storage
end
local function rig(model)
    if model:GetAttribute("CompanionRigVersion") == 1 then return end
    local torso = assert(model:FindFirstChild("Torso"))
    local frame = torso.CFrame
    local original = {}
    for _,p in model:GetDescendants() do
        if p:IsA("BasePart") then table.insert(original, p) end
    end
    local function sidePart(name, sign)
        for _,p in original do
            if p.Name == name and frame:PointToObjectSpace(p.Position).X * sign > 0 then return p end
        end
        error(model.Name .. " missing " .. name)
    end
    local root = Instance.new("Part")
    root.Name = "CompanionRoot"
    root.Size = Vector3.new(0.5, 0.5, 0.5)
    root.CFrame = frame
    root.Transparency = 1
    root.Anchored = true
    root.CanCollide = false
    root.CanTouch = false
    root.CanQuery = false
    root.Parent = model
    model.PrimaryPart = root
    local function motor(name, a, b, world)
        local j = Instance.new("Motor6D")
        j.Name = name
        j.Part0 = a
        j.Part1 = b
        j.C0 = a.CFrame:ToObjectSpace(world)
        j.C1 = b.CFrame:ToObjectSpace(world)
        j.Parent = a
        return j
    end
    motor("Body", root, torso, frame)
    local head = assert(model:FindFirstChild("Head"))
    motor("HeadTurn", torso, head, frame * CFrame.new(0, 1, 0))
    local cores = {[torso]=true, [head]=true}
    local sides = {}
    for _,spec in {{"Left",-1},{"Right",1}} do
        local label,sign = spec[1],spec[2]
        local upper,lower,hand = sidePart("Shoulder",sign),sidePart("Forearm",sign),sidePart("Fist",sign)
        local thigh,shin,foot = sidePart("Thigh",sign),sidePart("Ankle",sign),sidePart("Foot",sign)
        for _,p in {upper,lower,hand,thigh,shin,foot} do cores[p]=true end
        upper.Name=label.."UpperArm" lower.Name=label.."LowerArm" hand.Name=label.."Hand"
        thigh.Name=label.."UpperLeg" shin.Name=label.."LowerLeg" foot.Name=label.."Foot"
        motor(label.."Shoulder",torso,upper,frame*CFrame.new(sign*0.88,0.85,0))
        motor(label.."Elbow",upper,lower,frame*CFrame.new(sign*1.62,-0.2,0))
        motor(label.."Wrist",lower,hand,frame*CFrame.new(sign*1.8,-0.96,-0.05))
        motor(label.."Hip",torso,thigh,frame*CFrame.new(sign*0.52,-1.15,0.05))
        motor(label.."Knee",thigh,shin,frame*CFrame.new(sign*0.55,-1.82,0))
        motor(label.."Ankle",shin,foot,frame*CFrame.new(sign*0.6,-2.22,-0.1))
        table.insert(sides,{sign=sign,upper=upper,lower=lower,hand=hand,thigh=thigh,shin=shin,foot=foot,label=label})
    end
    local headNames = {Neck=true,FaceRecess=true,HelmetFrame=true,HelmetTopPlate=true,Eye=true,EyeHighlight=true,EarPlate=true,HelmetCheekGuard=true,GoldRoyalHelmetWing=true,CrownPoint=true,CrownCenter=true,Crest=true,CrestGem=true,RoyalGem=true}
    local upperNames = {ShoulderCap=true,ReinforcedPauldron=true,EnhancedShoulderGuard=true,EpicShoulderFin=true,ElementalShoulderCrest=true,ShoulderLightning=true,WaterShoulderCrystal=true}
    for _,p in original do
        if not cores[p] then
            local localPos=frame:PointToObjectSpace(p.Position)
            local s=sides[if localPos.X<0 then 1 else 2]
            local owner=torso
            if headNames[p.Name] then owner=head
            elseif upperNames[p.Name] then owner=s.upper
            elseif p.Name=="ElbowJoint" or p.Name=="WristBand" or p.Name=="ForearmEnergy" then owner=s.lower
            elseif p.Name=="KnucklePlate" then owner=s.hand
            elseif p.Name=="KneeGuard" then owner=s.thigh
            elseif p.Name=="GreavePlate" then owner=s.shin
            elseif p.Name=="BootTrim" then owner=s.foot end
            local weld=Instance.new("WeldConstraint")
            weld.Name="CompanionDetailWeld" weld.Part0=owner weld.Part1=p weld.Parent=p
        end
        p.Anchored=false p.Massless=true p.CanCollide=false p.CanTouch=false p.CanQuery=false
    end
    local controller=Instance.new("AnimationController") controller.Name="CompanionAnimator" controller.Parent=model
    Instance.new("Animator",controller)
    local targets=Instance.new("Folder") targets.Name="IKTargets" targets.Parent=model
    for _,s in sides do
        local target=Instance.new("Attachment") target.Name=s.label.."FootTarget"
        target.CFrame=root.CFrame:ToObjectSpace(s.foot.CFrame) target.Parent=root
        local pole=Instance.new("Attachment") pole.Name=s.label.."KneePole"
        pole.Position=Vector3.new(s.sign*0.6,-1.5,-3) pole.Parent=root
        local ik=Instance.new("IKControl") ik.Name=s.label.."FootIK" ik.Type=Enum.IKControlType.Transform
        ik.ChainRoot=s.thigh ik.EndEffector=s.foot ik.Target=target ik.Pole=pole
        ik.SmoothTime=0.06 ik.Weight=1 ik.Parent=controller
    end
    model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
    model:SetAttribute("CompanionRigVersion",1)
    model:SetAttribute("CompanionAnimationEnabled",true)
    model:SetAttribute("CompanionAnimationState","Auto")
    model:SetAttribute("CompanionStride",0.5)
    model:SetAttribute("CompanionStepHeight",0.3)
    model:SetAttribute("CompanionWalkSpeed",6)
end
local count=0
for _,m in templates:GetChildren() do if m:IsA("Model") then rig(m) count+=1 task.wait() end end
local gallery=workspace:FindFirstChild("Development") and workspace.Development:FindFirstChild("CompanionModelGallery")
if gallery then
    for _,m in gallery:GetChildren() do
        if m:IsA("Model") and templates:FindFirstChild(m.Name) then rig(m) count+=1 task.wait() end
    end
end
return "Rigged "..count.." companion templates/gallery models"
