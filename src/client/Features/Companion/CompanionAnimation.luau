-- Cosmetic presentation for authored rigs, including development gallery previews.
-- Does not equip companions, move roots, or establish gameplay hits.
local RunService = game:GetService("RunService")
local Animation = {}
local records = {}
local connections = {}
local running = false
local function attach(model)
    if records[model] or not model:IsA("Model") or model:GetAttribute("CompanionRigVersion") ~= 1 then return end
    local root = model:FindFirstChild("CompanionRoot")
    local controller = model:FindFirstChild("CompanionAnimator")
    if not root or not controller then return end
    local joints = {}
    for _,joint in model:GetDescendants() do
        if joint:IsA("Motor6D") then joints[joint.Name] = {joint=joint, base=joint.C0} end
    end
    local count = 0
    for _ in joints do count += 1 end
    if count ~= 14 or not controller:FindFirstChildOfClass("Animator") then return end
    local feet = {}
    for _,side in {"Left","Right"} do
        local foot = model:FindFirstChild(side.."Foot")
        local target = root:FindFirstChild(side.."FootTarget")
        local ik = controller:FindFirstChild(side.."FootIK")
        if not foot or not target or not ik then return end
        table.insert(feet, {target=target, base=target.CFrame, ik=ik, sole=foot.Size.Y/2})
    end
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances = {model}
    ray.RespectCanCollide = true
    records[model] = {root=root,joints=joints,feet=feet,ray=ray,last=root.Position,phase=0,time=0,blend=0}
end
local function pose(record,name,cf)
    local joint = record.joints[name]
    if joint then joint.joint.C0 = joint.base * cf end
end
local function reset(record)
    for _,j in record.joints do j.joint.C0=j.base end
    for _,f in record.feet do f.ik.Enabled=false f.target.CFrame=f.base end
end
local function update(dt)
    for model,r in records do
        if not model:IsDescendantOf(workspace) then reset(r) records[model]=nil continue end
        local delta=r.root.Position-r.last r.last=r.root.Position
        if model:GetAttribute("CompanionAnimationEnabled")==false then reset(r) continue end
        local speed=Vector3.new(delta.X,0,delta.Z).Magnitude/math.max(dt,0.001)
        if delta.Magnitude>10 then speed=0 end
        local state=model:GetAttribute("CompanionAnimationState") or "Auto"
        local walking=state=="Walk" or (state=="Auto" and speed>0.15)
        local nominal=math.clamp(tonumber(model:GetAttribute("CompanionWalkSpeed")) or 6,0.1,30)
        local rate=if state=="Walk" then 1 else math.clamp(speed/nominal,0.25,2)
        r.blend += ((if walking then 1 else 0)-r.blend)*(1-math.exp(-dt*10))
        r.time+=dt r.phase+=dt*7*rate
        local swing=math.sin(r.phase)*r.blend
        pose(r,"Body",CFrame.new(0,math.sin(r.time*2)*0.035,0)*CFrame.Angles(0,0,-swing*0.025))
        pose(r,"HeadTurn",CFrame.Angles(0,math.sin(r.time*0.65)*0.08,0))
        pose(r,"LeftShoulder",CFrame.Angles(swing*0.4,0,-0.025))
        pose(r,"RightShoulder",CFrame.Angles(-swing*0.4,0,0.025))
        pose(r,"LeftElbow",CFrame.Angles(-0.06-math.max(0,-swing)*0.15,0,0))
        pose(r,"RightElbow",CFrame.Angles(-0.06-math.max(0,swing)*0.15,0,0))
        if state=="Attack" then
            local strike=(math.sin(r.time*9)+1)*0.5
            pose(r,"RightShoulder",CFrame.Angles(-0.6-strike*1.1,0,-0.12))
            pose(r,"RightElbow",CFrame.Angles(-0.3+strike*0.25,0,0))
        end
        local stride=math.clamp(tonumber(model:GetAttribute("CompanionStride")) or 0.5,0,0.8)
        local height=math.clamp(tonumber(model:GetAttribute("CompanionStepHeight")) or 0.3,0,0.6)
        for index,f in r.feet do
            local cycle=r.phase+(index-1)*math.pi
            local lift=math.max(0,math.sin(cycle))*height*r.blend
            local localCF=f.base*CFrame.new(0,0,math.cos(cycle)*stride*r.blend)
            local desired=r.root.CFrame*localCF
            local hit=workspace:Raycast(desired.Position+Vector3.new(0,1.1,0),Vector3.new(0,-2.6,0),r.ray)
            f.ik.Enabled=hit~=nil
            if hit then
                -- Limit correction to the short legs' reachable terrain range.
                local correction=math.clamp(hit.Position.Y+f.sole-desired.Position.Y,-0.5,0.45)
                local world=desired+Vector3.new(0,correction+lift,0)
                f.target.CFrame=r.root.CFrame:ToObjectSpace(world)
            end
        end
    end
end
function Animation.Start()
    if running then return end
    running=true
    for _,item in workspace:GetDescendants() do if item:IsA("Model") then attach(item) end end
    table.insert(connections,workspace.DescendantAdded:Connect(function(item)
        local model = if item:IsA("Model") then item else item:FindFirstAncestorOfClass("Model")
        if model then task.defer(function() if running and model:IsDescendantOf(workspace) then attach(model) end end) end
    end))
    table.insert(connections,RunService.PreAnimation:Connect(update))
end
function Animation.Destroy()
    running=false
    for _,connection in connections do connection:Disconnect() end
    table.clear(connections)
    for _,record in records do reset(record) end
    table.clear(records)
end
return Animation
