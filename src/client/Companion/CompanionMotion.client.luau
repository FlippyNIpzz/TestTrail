--!strict
-- Smoothed visual copies; authoritative traversal stays on the server.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Math = require(ReplicatedStorage.Shared.CompanionMotionMath)
local Rig = require(script.Parent.CompanionRig)

type Motion = {
	Visual: Model, Hidden: {[BasePart]: number}, Frame: CFrame, LastTarget: Vector3,
	Speed: number, Phase: number, Weight: number, AirWeight: number, Grounded: boolean,
	VerticalSpeed: number, Landing: number, Yaw: number, Turn: number,
	HeadYaw: number, HeadPitch: number, LookYaw: number, LookPitch: number, NextGlance: number,
	Joints: {[string]: Rig.Joint}, Feet: {Rig.Foot}, Params: RaycastParams,
	TeleportId: number, Pelvis: number, Dirty: boolean, Connections: {RBXScriptConnection},
}
local motions: {[Model]: Motion} = {}
local visuals = Instance.new("Folder")
visuals.Name = "CompanionVisuals"
visuals.Parent = workspace
local function number(model: Model, name: string, fallback: number): number
	local value = model:GetAttribute(name)
	return if type(value) == "number" then value else fallback
end
local function reset(motion: Motion, frame: CFrame)
	motion.Frame = frame; motion.LastTarget = frame.Position
	motion.Speed = 0; motion.Phase = 0; motion.Weight = 0; motion.AirWeight = 0
	motion.VerticalSpeed = 0; motion.Landing = 0; motion.Grounded = true
	local _, yaw = frame:ToEulerAnglesYXZ()
	motion.Yaw = yaw; motion.Turn = 0; motion.Pelvis = 0
	motion.HeadYaw = 0; motion.HeadPitch = 0; motion.LookYaw = 0; motion.LookPitch = 0
	motion.NextGlance = os.clock() + 1
	for _, joint in motion.Joints do joint.Motor.C0 = joint.BaseC0 end
	for _, foot in motion.Feet do
		foot.Plant = nil; foot.Support = nil; foot.SupportLocal = nil; foot.WasStance = false
		foot.Correction = 0; foot.IK.Weight = 0; foot.IK.Enabled = false
		foot.Target.CFrame = foot.BaseTargetCF
	end
end
local function remove(source: Model)
	local motion = motions[source]
	if not motion then return end
	for part, transparency in motion.Hidden do
		if part.Parent then part.LocalTransparencyModifier = transparency end
	end
	for _, connection in motion.Connections do connection:Disconnect() end
	motion.Visual:Destroy()
	motions[source] = nil
end
local function add(source: Model)
	if motions[source] or not source.Archivable then return end
	local visual = source:Clone()
	for _, item in visual:GetDescendants() do
		if item:IsA("BaseScript") or item:IsA("ModuleScript") then item:Destroy() end
	end
	local joints, feet = Rig.Setup(visual)
	visual.Parent = visuals
	local frame = source:GetPivot()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local motion: Motion = {
		Visual = visual, Hidden = {}, Frame = frame, LastTarget = frame.Position,
		Speed = 0, Phase = 0, Weight = 0, AirWeight = 0, Grounded = true,
		VerticalSpeed = 0, Landing = 0, Yaw = 0, Turn = 0,
		HeadYaw = 0, HeadPitch = 0, LookYaw = 0, LookPitch = 0, NextGlance = 0,
		Joints = joints, Feet = feet, Params = params,
		TeleportId = number(source, "CompanionTeleportId", 0), Pelvis = 0, Dirty = false, Connections = {},
	}
	reset(motion, frame)
	for _, item in source:GetDescendants() do
		if item:IsA("BasePart") then
			motion.Hidden[item] = item.LocalTransparencyModifier
			item.LocalTransparencyModifier = 1
		end
	end
	motion.Connections = {
		source.DescendantAdded:Connect(function() motion.Dirty = true end),
		source.DescendantRemoving:Connect(function() motion.Dirty = true end),
	}
	motions[source] = motion
end

local function surfaceFrame(point: Vector3, normal: Vector3, facing: Vector3): CFrame
	local forward = facing - normal * facing:Dot(normal)
	if forward.Magnitude < 0.01 then forward = Vector3.new(0, 0, -1) end
	return CFrame.lookAt(point, point + forward.Unit, normal)
end

local function feetPose(motion: Motion, stride: number, height: number, dt: number, alive: boolean): number
	local root = motion.Visual.PrimaryPart
	if not root then return 0 end
	local pelvis = 0
	for _, foot in motion.Feet do
		local cycle = motion.Phase + (foot.Side - 1) * math.pi * 2 * 0.5
		local forward, lift, stance = Math.Gait(cycle)
		if motion.Weight < 0.05 then forward = 0; lift = 0; stance = true end
		local base = root.CFrame * foot.BaseTargetCF
		local desired = base.Position + motion.Frame.LookVector * (forward * stride * 0.5 * motion.Weight)
		local hit = workspace:Raycast(desired + Vector3.new(0, height * 0.4, 0), Vector3.new(0, -height * 0.8, 0), motion.Params)
		local usable = alive and motion.Grounded and hit ~= nil and motion.AirWeight < 0.5
		if usable and hit then
			local sole = hit.Position + hit.Normal * foot.SoleOffset
			local correction = sole.Y - base.Position.Y
			if math.abs(correction) > foot.Reach * 0.5 or hit.Normal.Y < 0.65 then usable = false
			else
				foot.Correction += (correction - foot.Correction) * (1 - math.exp(-18 * dt))
				pelvis = math.min(pelvis, math.clamp(foot.Correction, -height * 0.1, height * 0.06))
				local plant = foot.Plant
				if foot.Support and not foot.Support.Parent then plant = nil end
				if foot.Support and foot.Support.Parent and foot.SupportLocal then
					plant = foot.Support.CFrame * foot.SupportLocal
				end
				if not stance then plant = nil end
				if stance and (not foot.WasStance or not plant or (plant.Position - base.Position).Magnitude > foot.Reach * 0.65) then
					plant = surfaceFrame(sole, hit.Normal, motion.Frame.LookVector) * motion.Frame.Rotation:ToObjectSpace(base.Rotation)
					foot.Support = if hit.Instance:IsA("BasePart") then hit.Instance else nil
					foot.SupportLocal = if foot.Support then foot.Support.CFrame:ToObjectSpace(plant :: CFrame) else nil
				end
				foot.Plant = plant
				local target = plant or surfaceFrame(Vector3.new(sole.X, base.Position.Y + foot.Correction + lift * height * 0.12 * motion.Weight, sole.Z), hit.Normal, motion.Frame.LookVector) * motion.Frame.Rotation:ToObjectSpace(base.Rotation)
				foot.Target.WorldCFrame = target
			end
		end
		foot.WasStance = stance and usable
		if not usable then foot.Plant = nil; foot.Support = nil; foot.SupportLocal = nil end
		local weight = if usable then 1 - motion.AirWeight else 0
		foot.IK.Weight += (weight - foot.IK.Weight) * (1 - math.exp(-18 * dt))
		foot.IK.Enabled = foot.IK.Weight > 0.01
	end
	return pelvis
end

RunService.RenderStepped:Connect(function(deltaTime: number)
	local runtime = workspace:FindFirstChild("RuntimeCompanions")
	if runtime then
		for _, source in runtime:GetChildren() do if source:IsA("Model") then add(source) end end
	end
	local dt = math.min(deltaTime, 0.1)
	local blend = 1 - math.exp(-14 * dt)
	local poseBlend = 1 - math.exp(-22 * dt)
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	local excluded: {Instance} = {visuals}
	if runtime then table.insert(excluded, runtime) end
	for _, player in Players:GetPlayers() do if player.Character then table.insert(excluded, player.Character) end end
	for source, motion in motions do
		if not runtime or source.Parent ~= runtime then remove(source); continue end
		-- Rebuild incomplete streamed clones only when their hierarchy changes.
		if motion.Dirty then remove(source); add(source); continue end
		motion.Params.FilterDescendantsInstances = excluded
		local target = source:GetPivot()
		local teleportId = number(source, "CompanionTeleportId", 0)
		if teleportId ~= motion.TeleportId or (target.Position - motion.LastTarget).Magnitude > 25 then
			reset(motion, target); motion.TeleportId = teleportId
		end
		motion.LastTarget = target.Position
		local previous = motion.Frame
		local position = previous.Position:Lerp(target.Position, blend)
		local rotation = previous.Rotation:Lerp(target.Rotation, 1 - math.exp(-10 * dt))
		motion.Frame = CFrame.new(position) * rotation
		motion.Visual:PivotTo(motion.Frame)
		local travel = position - previous.Position
		local distance = Vector3.new(travel.X, 0, travel.Z).Magnitude
		motion.Speed += (distance / math.max(deltaTime, 0.001) - motion.Speed) * (1 - math.exp(-12 * dt))
		local _, yaw = rotation:ToEulerAnglesYXZ()
		local yawDelta = (yaw - motion.Yaw + math.pi) % (2 * math.pi) - math.pi
		motion.Turn += (yawDelta / math.max(deltaTime, 0.001) - motion.Turn) * (1 - math.exp(-10 * dt))
		motion.Yaw = yaw
		local alive = number(source, "Health", 1) > 0
		local height = math.max(1, number(source, "CompanionRigHeight", 4))
		local stride = math.max(0.6, number(source, "CompanionStrideLength", height * 0.65))
		local label = source:GetAttribute("CompanionLocomotionState")
		local verticalSpeed = number(source, "CompanionVerticalSpeed", travel.Y / math.max(deltaTime, 0.001))
		motion.VerticalSpeed = verticalSpeed
		local groundedAttribute = source:GetAttribute("CompanionGrounded")
		local grounded: boolean
		if type(groundedAttribute) == "boolean" then grounded = groundedAttribute
		else
			local offset = number(source, "CompanionGroundOffset", height / 2)
			local hit = workspace:Raycast(position + Vector3.new(0, 0.3 - offset, 0), Vector3.new(0, -height, 0), motion.Params)
			local clearance = if hit then position.Y - offset - hit.Position.Y else nil
			grounded = Math.Grounded(clearance, motion.Grounded, verticalSpeed)
		end
		if grounded and not motion.Grounded then
			motion.Landing = math.clamp(number(source, "CompanionLandingSpeed", 8) / 25, 0.15, 1)
		end
		motion.Grounded = grounded
		motion.Landing = math.max(0, motion.Landing - dt * 3.5)
		motion.AirWeight += ((if alive and not grounded then 1 else 0) - motion.AirWeight) * blend
		local desiredWeight = if alive and grounded and motion.Speed > 0.15 then math.clamp(motion.Speed / (height * 0.8), 0, 1) else 0
		motion.Weight += (desiredWeight - motion.Weight) * blend
		if grounded and alive and distance > 0.001 then
			motion.Phase = (motion.Phase + distance / stride * math.pi * 2) % (math.pi * 2)
		end
		local gait = motion.Phase
		local groundWeight = 1 - motion.AirWeight
		local aw = motion.AirWeight
		local breath = if alive then math.sin(now * 2.2) * (1 - motion.Weight) * groundWeight else 0
		local owner = Players:GetPlayerByUserId(number(source, "OwnerUserId", 0))
		local character = owner and owner.Character
		if now >= motion.NextGlance then
			local head = character and character:FindFirstChild("Head")
			if head and head:IsA("BasePart") and (head.Position - position).Magnitude < 20 and math.random() < 0.35 then
				local localTarget = motion.Frame:PointToObjectSpace(head.Position)
				if localTarget.Magnitude > 0.01 then
					motion.LookYaw = math.clamp(-math.atan2(localTarget.X, -localTarget.Z), -0.8, 0.8)
					motion.LookPitch = math.clamp(math.asin(localTarget.Unit.Y), -0.3, 0.4)
				end
			else
				motion.LookYaw = math.rad(math.random(-35, 35)); motion.LookPitch = math.rad(math.random(-6, 8))
			end
			motion.NextGlance = now + math.random(22, 45) / 10
		end
		motion.HeadYaw += (motion.LookYaw - motion.HeadYaw) * (1 - math.exp(-6 * dt))
		motion.HeadPitch += (motion.LookPitch - motion.HeadPitch) * (1 - math.exp(-6 * dt))
		local pelvis = feetPose(motion, stride, height, dt, alive)
		motion.Pelvis += (pelvis - motion.Pelvis) * blend
		local bob = (1 - math.cos(gait * 2)) * height * 0.012 * motion.Weight
		local bodyY = bob + breath * height * 0.0045 - motion.Landing * height * 0.045 + motion.Pelvis
		local lean = -0.07 * motion.Weight - aw * (if verticalSpeed > 0 then 0.1 else -0.03)
		local bank = math.clamp(-motion.Turn * 0.08, -0.1, 0.1) * motion.Weight
		local function pose(name: string, offset: CFrame) Rig.Pose(motion.Joints, name, offset, poseBlend) end
		pose("Body", if alive then CFrame.new(0, bodyY, 0) * CFrame.Angles(lean, 0, bank + math.sin(gait) * 0.035 * motion.Weight) else CFrame.Angles(0.3, 0, 0))
		pose("HeadTurn", if alive then CFrame.Angles(motion.HeadPitch + math.sin(gait * 2) * 0.02 * motion.Weight, motion.HeadYaw + math.clamp(-motion.Turn * 0.2, -0.4, 0.4), 0) else CFrame.Angles(-0.5, 0, 0))
		local attackWeight, strike = Math.Attack(serverNow - number(source, "LastAttackTime", -math.huge))
		if not alive then attackWeight = 0 end
		for index, side in {"Left", "Right"} do
			local sign = if index == 1 then -1 else 1
			local phase = gait + (index - 1) * math.pi
			local forward, lift = Math.Gait(phase)
			local leg = forward * motion.Weight
			local arm = -leg
			local pitch = arm * math.rad(30) * groundWeight
			local roll = sign * math.rad(3) - sign * breath * math.rad(1)
			local elbow = -math.rad(10) - math.max(0, -arm) * math.rad(28)
			local wrist = CFrame.Angles(0, -sign * 0.1, sign * 0.05)
			pitch = pitch * (1 - aw) + (if verticalSpeed > 0 then 0.35 else -0.12) * aw
			roll = roll * (1 - aw) + sign * (if verticalSpeed > 0 then 0.3 else 0.45) * aw
			elbow = elbow * (1 - aw) - 0.6 * aw
			if attackWeight > 0 then
				local attackPitch = if index == 2 then -0.5 - strike * 1.05 else 0.2
				pitch += (attackPitch - pitch) * attackWeight
				roll += (sign * 0.2 - roll) * attackWeight
				elbow += ((if index == 2 then -0.8 + strike * 0.65 else -1.1) - elbow) * attackWeight
				wrist = wrist:Lerp(CFrame.identity, attackWeight)
			end
			if not alive then pitch = 0.2; roll = sign * 0.07; elbow = -0.08; wrist = CFrame.identity end
			pose(side .. "Shoulder", CFrame.Angles(pitch, arm * 0.05 * groundWeight, roll))
			pose(side .. "Elbow", CFrame.Angles(elbow, 0, 0))
			pose(side .. "Wrist", wrist)
			local stepLift = if label == "StepUp" then 1.3 else 1
			local hip = -leg * math.rad(27)
			local knee = -0.04 - lift * math.rad(48) * motion.Weight * stepLift
			hip = hip * (1 - aw) + (if verticalSpeed > 0 then 0.4 else 0.12) * aw
			knee = knee * (1 - aw) + (if verticalSpeed > 0 then -0.8 else -0.25) * aw - motion.Landing * 0.25
			local ankle = -(hip + knee) * groundWeight
			if not alive then hip = 0; knee = -0.1; ankle = 0 end
			pose(side .. "Hip", CFrame.Angles(hip, 0, sign * 0.025))
			pose(side .. "Knee", CFrame.Angles(knee, 0, 0))
			pose(side .. "Ankle", CFrame.Angles(ankle, 0, 0))
		end
	end
end)
