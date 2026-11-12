--!strict
-- Cosmetic copies interpolate server movement and provide rich procedural human-like animations.
-- Drives walking arm/shoulder swing, jumping, idle breathing, and organic head glancing.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

type JointData = {
	Motor: Motor6D,
	BaseC0: CFrame,
	BaseC1: CFrame,
}

type FootData = {
	Target: Attachment,
	BaseTargetCF: CFrame,
	IK: IKControl,
	SoleOffset: number,
}

type Motion = {
	Source: Model,
	Visual: Model,
	Hidden: { [BasePart]: number },
	Frame: CFrame,
	LastTarget: Vector3,
	Speed: number,
	Phase: number,
	Weight: number,
	PreviousY: number,
	VerticalSpeed: number,
	IsAirborne: boolean,
	AirWeight: number,
	LandingSquash: number,
	LastYaw: number,
	TurnYawRate: number,
	HeadYaw: number,
	HeadPitch: number,
	TargetHeadYaw: number,
	TargetHeadPitch: number,
	NextGlanceTime: number,
	Joints: { [string]: JointData },
	Feet: { FootData },
	RayParams: RaycastParams,
	OwnerUserId: number?,
}

local motions: { [Model]: Motion } = {}
local visuals = Instance.new("Folder")
visuals.Name = "CompanionVisuals"
visuals.Parent = workspace

local function getJoint(joints: { [string]: JointData }, ...: string): JointData?
	for i = 1, select("#", ...) do
		local name = select(i, ...)
		local found = joints[name]
		if found then return found end
	end
	return nil
end

local function poseJoint(joint: JointData?, offset: CFrame)
	if joint then
		joint.Motor.C0 = joint.BaseC0 * offset
	end
end

local function makeMotor(name: string, p0: BasePart, p1: BasePart, world: CFrame): Motor6D
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = p0
	motor.Part1 = p1
	motor.C0 = p0.CFrame:ToObjectSpace(world)
	motor.C1 = p1.CFrame:ToObjectSpace(world)
	motor.Parent = p0
	return motor
end

-- Rigs or validates joints on the visual clone so Motor6D procedural poses animate limbs cleanly.
local function setupVisualRig(visual: Model): ({ [string]: JointData }, { FootData })
	local root = visual:FindFirstChild("CompanionRoot") :: BasePart?
	local torso = visual:FindFirstChild("Torso") :: BasePart?
	if not torso and visual.PrimaryPart and visual.PrimaryPart.Name ~= "CompanionRoot" then
		torso = visual.PrimaryPart
	end
	if not torso then
		for _, item in visual:GetChildren() do
			if item:IsA("BasePart") and item.Name ~= "CompanionRoot" then
				torso = item
				break
			end
		end
	end

	local torsoPart = torso
	if torsoPart then
		local frame = torsoPart.CFrame
		if not root then
			local newRoot = Instance.new("Part")
			newRoot.Name = "CompanionRoot"
			newRoot.Size = Vector3.new(0.5, 0.5, 0.5)
			newRoot.CFrame = frame
			newRoot.Transparency = 1
			newRoot.CanCollide = false
			newRoot.CanTouch = false
			newRoot.CanQuery = false
			newRoot.Massless = true
			newRoot.Parent = visual
			root = newRoot
		end
		visual.PrimaryPart = root

		-- Check if joints already exist
		local existingJoints: { [string]: Motor6D } = {}
		for _, item in visual:GetDescendants() do
			if item:IsA("Motor6D") then
				existingJoints[item.Name] = item
			end
		end

		if not existingJoints["Body"] and root then
			makeMotor("Body", root, torsoPart, frame)
		end

		local head = visual:FindFirstChild("Head") :: BasePart?
		if head and not existingJoints["HeadTurn"] and not existingJoints["Neck"] then
			makeMotor("HeadTurn", torsoPart, head, frame * CFrame.new(0, 1, 0))
		end

		-- Auto-identify side limbs if not already motored
		local originalParts: { BasePart } = {}
		for _, item in visual:GetDescendants() do
			if item:IsA("BasePart") and item ~= root then
				table.insert(originalParts, item)
			end
		end

		local function findSidePart(names: { string }, sign: number): BasePart?
			for _, p in originalParts do
				for _, name in names do
					if p.Name == name and frame:PointToObjectSpace(p.Position).X * sign > 0 then
						return p
					end
				end
			end
			return nil
		end

		local sides = {
			{ Label = "Left", Sign = -1 },
			{ Label = "Right", Sign = 1 },
		}

		for _, side in sides do
			local label, sign = side.Label, side.Sign
			local upper = findSidePart({ label .. "UpperArm", label .. "Shoulder", "Shoulder" }, sign)
			local lower = findSidePart({ label .. "LowerArm", label .. "Forearm", "Forearm" }, sign)
			local hand = findSidePart({ label .. "Hand", label .. "Fist", "Fist" }, sign)
			local thigh = findSidePart({ label .. "UpperLeg", label .. "Thigh", "Thigh" }, sign)
			local shin = findSidePart({ label .. "LowerLeg", label .. "Ankle", "Ankle" }, sign)
			local foot = findSidePart({ label .. "Foot", "Foot" }, sign)

			if upper and not existingJoints[label .. "Shoulder"] then
				makeMotor(label .. "Shoulder", torsoPart, upper, frame * CFrame.new(sign * 0.88, 0.85, 0))
			end
			if upper and lower and not existingJoints[label .. "Elbow"] then
				makeMotor(label .. "Elbow", upper, lower, frame * CFrame.new(sign * 1.62, -0.2, 0))
			end
			if lower and hand and not existingJoints[label .. "Wrist"] then
				makeMotor(label .. "Wrist", lower, hand, frame * CFrame.new(sign * 1.8, -0.96, -0.05))
			end
			if thigh and not existingJoints[label .. "Hip"] then
				makeMotor(label .. "Hip", torsoPart, thigh, frame * CFrame.new(sign * 0.52, -1.15, 0.05))
			end
			if thigh and shin and not existingJoints[label .. "Knee"] then
				makeMotor(label .. "Knee", thigh, shin, frame * CFrame.new(sign * 0.55, -1.82, 0))
			end
			if shin and foot and not existingJoints[label .. "Ankle"] then
				makeMotor(label .. "Ankle", shin, foot, frame * CFrame.new(sign * 0.6, -2.22, -0.1))
			end
		end

		-- Weld accessory/decorative parts to torso if unattached
		for _, p in originalParts do
			if p ~= torsoPart and not p:FindFirstChildOfClass("Motor6D") and not p:FindFirstChildOfClass("WeldConstraint") then
				local isPart1OfMotor = false
				for _, m in visual:GetDescendants() do
					if m:IsA("Motor6D") and m.Part1 == p then
						isPart1OfMotor = true
						break
					end
				end
				if not isPart1OfMotor then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = torsoPart
					weld.Part1 = p
					weld.Parent = p
				end
			end
		end
	end

	-- Configure physics state: Root anchored, limbs unanchored
	for _, item in visual:GetDescendants() do
		if item:IsA("BasePart") then
			if root and item == root then
				item.Anchored = true
			else
				item.Anchored = false
			end
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
			item.Massless = true
		end
	end

	-- Collect all active joints
	local joints: { [string]: JointData } = {}
	for _, item in visual:GetDescendants() do
		if item:IsA("Motor6D") then
			joints[item.Name] = {
				Motor = item,
				BaseC0 = item.C0,
				BaseC1 = item.C1,
			}
		end
	end

	-- Collect foot IK controls if configured
	local feet: { FootData } = {}
	local controller = visual:FindFirstChildOfClass("AnimationController")
	if controller and root then
		for _, side in { "Left", "Right" } do
			local target = root:FindFirstChild(side .. "FootTarget")
			local ik = controller:FindFirstChild(side .. "FootIK")
			local footPart = visual:FindFirstChild(side .. "Foot")
			if target and target:IsA("Attachment") and ik and ik:IsA("IKControl") and footPart and footPart:IsA("BasePart") then
				table.insert(feet, {
					Target = target,
					BaseTargetCF = target.CFrame,
					IK = ik,
					SoleOffset = footPart.Size.Y / 2,
				})
			end
		end
	end

	return joints, feet
end

local function remove(source: Model)
	local motion = motions[source]
	if not motion then return end
	for part, transparency in motion.Hidden do
		if part and part.Parent then
			part.LocalTransparencyModifier = transparency
		end
	end
	motion.Visual:Destroy()
	motions[source] = nil
end

local function add(source: Model)
	if motions[source] or not source.Archivable then return end
	local visual = source:Clone()
	local hidden: { [BasePart]: number } = {}

	for _, item in visual:GetDescendants() do
		if item:IsA("BaseScript") or item:IsA("ModuleScript") then
			item:Destroy()
		end
	end

	for _, item in source:GetDescendants() do
		if item:IsA("BasePart") then
			hidden[item] = item.LocalTransparencyModifier
			item.LocalTransparencyModifier = 1
		end
	end

	local joints, feet = setupVisualRig(visual)
	visual.Parent = visuals
	local frame = source:GetPivot()

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { visual, source }
	rayParams.RespectCanCollide = true

	local ownerUserId = source:GetAttribute("OwnerUserId") :: number?
	local _, initYaw, _ = frame.Rotation:ToEulerAnglesYXZ()

	motions[source] = {
		Source = source,
		Visual = visual,
		Hidden = hidden,
		Frame = frame,
		LastTarget = frame.Position,
		Speed = 0,
		Phase = math.random() * math.pi * 2,
		Weight = 0,
		PreviousY = frame.Position.Y,
		VerticalSpeed = 0,
		IsAirborne = false,
		AirWeight = 0,
		LandingSquash = 0,
		LastYaw = initYaw,
		TurnYawRate = 0,
		HeadYaw = 0,
		HeadPitch = 0,
		TargetHeadYaw = 0,
		TargetHeadPitch = 0,
		NextGlanceTime = os.clock() + math.random(15, 30) / 10,
		Joints = joints,
		Feet = feet,
		RayParams = rayParams,
		OwnerUserId = ownerUserId,
	}
end

RunService.RenderStepped:Connect(function(deltaTime: number)
	local runtime = workspace:FindFirstChild("RuntimeCompanions")
	if runtime then
		for _, source in runtime:GetChildren() do
			if source:IsA("Model") then add(source) end
		end
	end

	local dt = math.min(deltaTime, 0.1)
	local blend = 1 - math.exp(-14 * dt)

	for source, motion in motions do
		if source.Parent ~= runtime or runtime == nil then
			remove(source)
			continue
		end

		local target = source:GetPivot()
		local displacement = target.Position - motion.LastTarget
		motion.LastTarget = target.Position

		-- Teleports and respawns must never fly across the map
		if displacement.Magnitude > 25 then
			motion.Frame = target
			motion.Speed = 0
			motion.Weight = 0
			motion.AirWeight = 0
			motion.LandingSquash = 0
			motion.PreviousY = target.Position.Y
		end

		local previous = motion.Frame
		local position = previous.Position:Lerp(target.Position, blend)
		local rotation = previous.Rotation:Lerp(target.Rotation, 1 - math.exp(-9 * dt))
		motion.Frame = CFrame.new(position) * rotation

		local travel = position - previous.Position
		local horizSpeed = Vector3.new(travel.X, 0, travel.Z).Magnitude / math.max(dt, 0.001)
		motion.Speed += (horizSpeed - motion.Speed) * (1 - math.exp(-10 * dt))

		-- Track turning yaw velocity to enable anticipatory head lead and banking
		local _, currentYaw, _ = rotation:ToEulerAnglesYXZ()
		local yawDelta = (currentYaw - motion.LastYaw)
		yawDelta = (yawDelta + math.pi) % (2 * math.pi) - math.pi
		local turnRate = yawDelta / math.max(dt, 0.001)
		motion.TurnYawRate += (turnRate - motion.TurnYawRate) * (1 - math.exp(-8 * dt))
		motion.LastYaw = currentYaw

		local alive = (source:GetAttribute("Health") :: number? or 1) > 0
		local weight = if alive then math.clamp(motion.Speed / 6, 0, 1) else 0
		motion.Weight += (weight - motion.Weight) * blend

		-- Track vertical movement and detect jumping/falling
		local vy = (position.Y - motion.PreviousY) / math.max(dt, 0.001)
		motion.VerticalSpeed += (vy - motion.VerticalSpeed) * (1 - math.exp(-12 * dt))
		motion.PreviousY = position.Y

		local groundHit = workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -6, 0), motion.RayParams)
		local groundDist = if groundHit then math.max(0, position.Y - groundHit.Position.Y) else 0

		-- Detect jump via vertical speed or owner character jumping in follow mode
		local isAirborne = groundDist > 0.65 or math.abs(motion.VerticalSpeed) > 3
		local owner = if motion.OwnerUserId then Players:GetPlayerByUserId(motion.OwnerUserId) else nil
		local ownerChar = owner and owner.Character
		local ownerHumanoid = ownerChar and ownerChar:FindFirstChildOfClass("Humanoid")
		if ownerHumanoid then
			local state = ownerHumanoid:GetState()
			if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
				isAirborne = true
			end
		end

		if motion.IsAirborne and not isAirborne then
			motion.LandingSquash = 1.0
		end
		motion.IsAirborne = isAirborne
		motion.LandingSquash = math.max(0, motion.LandingSquash - dt * 4.5)

		local targetAirWeight = if isAirborne and alive then 1 else 0
		motion.AirWeight += (targetAirWeight - motion.AirWeight) * (1 - math.exp(-12 * dt))

		-- Walking gait phase advances with ground speed
		motion.Phase = (motion.Phase + motion.Speed * dt * 1.8) % (math.pi * 2)
		local gait = motion.Phase
		local swing = math.sin(gait) * motion.Weight * (1 - motion.AirWeight)

		-- Organic idle head glancing and looking around behavior
		local now = os.clock()
		if now >= motion.NextGlanceTime then
			local headPart = ownerChar and ownerChar:FindFirstChild("Head") :: BasePart?
			if headPart and (headPart.Position - position).Magnitude < 20 and math.random() < 0.35 then
				-- Look up at owner
				local localTarget = motion.Frame:PointToObjectSpace(headPart.Position)
				motion.TargetHeadYaw = math.clamp(-math.atan2(localTarget.X, -localTarget.Z), -math.rad(55), math.rad(55))
				motion.TargetHeadPitch = math.clamp(math.asin(math.clamp(localTarget.Unit.Y, -1, 1)), -math.rad(20), math.rad(25))
			else
				local roll = math.random()
				if roll < 0.4 then
					motion.TargetHeadYaw = 0
					motion.TargetHeadPitch = 0
				elseif roll < 0.7 then
					motion.TargetHeadYaw = -math.rad(math.random(22, 42))
					motion.TargetHeadPitch = math.rad(math.random(-6, 8))
				else
					motion.TargetHeadYaw = math.rad(math.random(22, 42))
					motion.TargetHeadPitch = math.rad(math.random(-6, 8))
				end
			end
			motion.NextGlanceTime = now + math.random(22, 45) / 10
		end

		local glanceBlend = 1 - math.exp(-6 * dt)
		motion.HeadYaw += (motion.TargetHeadYaw - motion.HeadYaw) * glanceBlend
		motion.HeadPitch += (motion.TargetHeadPitch - motion.HeadPitch) * glanceBlend

		-- Head leads turning direction
		local headLeadYaw = math.clamp(-motion.TurnYawRate * 0.22, -math.rad(28), math.rad(28))
		local walkNod = math.sin(gait * 2) * math.rad(1.5) * motion.Weight * (1 - motion.AirWeight)

		-- Joint references
		local j = motion.Joints
		local bodyJoint = getJoint(j, "Body", "Root", "RootJoint")
		local headJoint = getJoint(j, "HeadTurn", "Neck", "Head")
		local lShoulder = getJoint(j, "LeftShoulder", "Left Shoulder", "LeftUpperArm")
		local rShoulder = getJoint(j, "RightShoulder", "Right Shoulder", "RightUpperArm")
		local lElbow = getJoint(j, "LeftElbow", "Left Elbow", "LeftLowerArm")
		local rElbow = getJoint(j, "RightElbow", "Right Elbow", "RightLowerArm")
		local lWrist = getJoint(j, "LeftWrist", "LeftHand")
		local rWrist = getJoint(j, "RightWrist", "RightHand")
		local lHip = getJoint(j, "LeftHip", "Left Hip", "LeftUpperLeg")
		local rHip = getJoint(j, "RightHip", "Right Hip", "RightUpperLeg")
		local lKnee = getJoint(j, "LeftKnee", "Left Knee", "LeftLowerLeg")
		local rKnee = getJoint(j, "RightKnee", "Right Knee", "RightLowerLeg")
		local lAnkle = getJoint(j, "LeftAnkle", "LeftFoot")
		local rAnkle = getJoint(j, "RightAnkle", "RightFoot")

		-- Check combat attack state
		local animState = source:GetAttribute("CompanionAnimationState") :: string?
		local lastAttack = source:GetAttribute("LastAttackTime") :: number? or 0
		local isAttacking = animState == "Attack" or (now - lastAttack < 0.45)

		-- 1. Torso Motion (Bobbing, Breathing, Forward Lean, Bank, Squash)
		local groundPhaseWeight = (1 - motion.AirWeight)
		local bob = (1 - math.cos(gait * 2)) * 0.08 * motion.Weight * groundPhaseWeight
		local idleBreath = if alive then (1 + math.sin(now * 2.2)) * 0.018 * (1 - motion.Weight) * groundPhaseWeight else 0
		local squashY = -motion.LandingSquash * 0.22
		local leanPitch = math.rad(-4) * motion.Weight * groundPhaseWeight + (if motion.AirWeight > 0.05 then math.rad(-8) * motion.AirWeight else 0)
		local swayRoll = math.sin(gait) * math.rad(3.5) * motion.Weight * groundPhaseWeight
		local bankRoll = math.clamp(-motion.TurnYawRate * 0.12, -math.rad(7), math.rad(7))

		if alive then
			poseJoint(bodyJoint, CFrame.new(0, bob + idleBreath + squashY, 0) * CFrame.Angles(leanPitch, 0, swayRoll + bankRoll))
		else
			poseJoint(bodyJoint, CFrame.Angles(math.rad(18), 0, 0))
		end

		-- 2. Head Articulation
		if alive then
			local headAirPitch = if motion.AirWeight > 0.05 then math.rad(10) * motion.AirWeight else 0
			poseJoint(headJoint, CFrame.Angles(motion.HeadPitch + walkNod + headAirPitch, motion.HeadYaw + headLeadYaw, 0))
		else
			poseJoint(headJoint, CFrame.Angles(-math.rad(30), 0, 0))
		end

		-- 3. Arm and Shoulder Articulation
		if alive and isAttacking then
			local strike = (math.sin(now * 10) + 1) * 0.5
			poseJoint(rShoulder, CFrame.Angles(-math.rad(35) - strike * math.rad(55), 0, math.rad(8)))
			poseJoint(rElbow, CFrame.Angles(-math.rad(45) + strike * math.rad(35), 0, 0))
			poseJoint(lShoulder, CFrame.Angles(math.rad(22), math.rad(12), -math.rad(16)))
			poseJoint(lElbow, CFrame.Angles(-math.rad(65), 0, 0))
		elseif alive then
			local breathShoulder = math.sin(now * 2.2) * math.rad(1.5) * (1 - motion.Weight) * groundPhaseWeight
			local armPitchL = swing * math.rad(36)
			local armPitchR = -swing * math.rad(36)
			local shoulderYawL = swing * math.rad(6)
			local shoulderYawR = -swing * math.rad(6)
			local shoulderRollL = -math.rad(3) - swing * math.rad(2.5) + breathShoulder
			local shoulderRollR = math.rad(3) + swing * math.rad(2.5) - breathShoulder

			local elbowL = math.rad(-8) - math.max(0, swing) * math.rad(40) - math.max(0, -swing) * math.rad(8)
			local elbowR = math.rad(-8) - math.max(0, -swing) * math.rad(40) - math.max(0, swing) * math.rad(8)

			-- Jump blending for arms
			if motion.AirWeight > 0.01 then
				local aw = motion.AirWeight
				local jumpPitch = math.rad(26)
				local jumpRollL = -math.rad(20)
				local jumpRollR = math.rad(20)
				local jumpElbow = math.rad(-35)

				armPitchL = armPitchL * (1 - aw) + jumpPitch * aw
				armPitchR = armPitchR * (1 - aw) + jumpPitch * aw
				shoulderRollL = shoulderRollL * (1 - aw) + jumpRollL * aw
				shoulderRollR = shoulderRollR * (1 - aw) + jumpRollR * aw
				elbowL = elbowL * (1 - aw) + jumpElbow * aw
				elbowR = elbowR * (1 - aw) + jumpElbow * aw
			end

			poseJoint(lShoulder, CFrame.Angles(armPitchL, shoulderYawL, shoulderRollL))
			poseJoint(rShoulder, CFrame.Angles(armPitchR, shoulderYawR, shoulderRollR))
			poseJoint(lElbow, CFrame.Angles(elbowL, 0, 0))
			poseJoint(rElbow, CFrame.Angles(elbowR, 0, 0))
			poseJoint(lWrist, CFrame.Angles(0, math.rad(8), math.rad(-5)))
			poseJoint(rWrist, CFrame.Angles(0, -math.rad(8), math.rad(5)))
		else
			-- Defeated limp posture
			poseJoint(lShoulder, CFrame.Angles(math.rad(12), 0, -math.rad(4)))
			poseJoint(rShoulder, CFrame.Angles(math.rad(12), 0, math.rad(4)))
			poseJoint(lElbow, CFrame.Angles(-math.rad(5), 0, 0))
			poseJoint(rElbow, CFrame.Angles(-math.rad(5), 0, 0))
		end

		-- 4. Leg Articulation
		if alive then
			local hipPitchL = -swing * math.rad(28)
			local hipPitchR = swing * math.rad(28)
			local kneeL = math.rad(-4) - math.max(0, -swing) * math.rad(36)
			local kneeR = math.rad(-4) - math.max(0, swing) * math.rad(36)
			local ankleL = -hipPitchL - kneeL
			local ankleR = -hipPitchR - kneeR

			-- Jump blending for legs (tucking up in mid-air)
			if motion.AirWeight > 0.01 then
				local aw = motion.AirWeight
				local jumpHip = math.rad(24)
				local jumpKnee = math.rad(-42)
				hipPitchL = hipPitchL * (1 - aw) + jumpHip * aw
				hipPitchR = hipPitchR * (1 - aw) + jumpHip * aw
				kneeL = kneeL * (1 - aw) + jumpKnee * aw
				kneeR = kneeR * (1 - aw) + jumpKnee * aw
				ankleL = ankleL * (1 - aw)
				ankleR = ankleR * (1 - aw)
			end

			poseJoint(lHip, CFrame.Angles(hipPitchL, 0, -math.rad(2)))
			poseJoint(rHip, CFrame.Angles(hipPitchR, 0, math.rad(2)))
			poseJoint(lKnee, CFrame.Angles(kneeL, 0, 0))
			poseJoint(rKnee, CFrame.Angles(kneeR, 0, 0))
			poseJoint(lAnkle, CFrame.Angles(ankleL, 0, 0))
			poseJoint(rAnkle, CFrame.Angles(ankleR, 0, 0))

			-- Update foot IK targets if IK is available
			if #motion.Feet > 0 and motion.Visual.PrimaryPart then
				local stride = math.clamp(tonumber(source:GetAttribute("CompanionStride")) or 0.5, 0, 0.8)
				local height = math.clamp(tonumber(source:GetAttribute("CompanionStepHeight")) or 0.3, 0, 0.6)
				local primaryCF = motion.Visual.PrimaryPart.CFrame

				for index, foot in motion.Feet do
					local cycle = gait + (index - 1) * math.pi
					local lift = math.max(0, math.sin(cycle)) * height * motion.Weight * groundPhaseWeight
					local localCF = foot.BaseTargetCF * CFrame.new(0, 0, math.cos(cycle) * stride * motion.Weight)
					local desired = primaryCF * localCF
					local hit = workspace:Raycast(desired.Position + Vector3.new(0, 1.1, 0), Vector3.new(0, -2.6, 0), motion.RayParams)
					foot.IK.Enabled = hit ~= nil and motion.AirWeight < 0.5
					if hit then
						local correction = math.clamp(hit.Position.Y + foot.SoleOffset - desired.Position.Y, -0.5, 0.45)
						local world = desired + Vector3.new(0, correction + lift, 0)
						foot.Target.CFrame = primaryCF:ToObjectSpace(world)
					end
				end
			end
		end

		-- 5. Position Visual Root (if no Body joint exists, apply full sway directly to visual)
		if not bodyJoint then
			motion.Visual:PivotTo(motion.Frame * CFrame.new(0, bob + idleBreath + squashY, 0) * CFrame.Angles(leanPitch, 0, swayRoll + bankRoll))
		else
			motion.Visual:PivotTo(motion.Frame)
		end
	end
end)
