--!strict
-- Rig only the local visual clone. Preserve authored rest frames and connections.
local MotionMath = require(game:GetService("ReplicatedStorage").Shared.CompanionMotionMath)
local Rig = {}
export type Joint = {Motor: Motor6D, BaseC0: CFrame, Axis: CFrame}
export type Foot = {
	Target: Attachment, BaseTargetCF: CFrame, IK: IKControl, SoleOffset: number,
	Side: number, Reach: number, Plant: CFrame?, Support: BasePart?, SupportLocal: CFrame?,
	WasStance: boolean, Correction: number,
}

local function part(model: Model, names: {string}): BasePart?
	for _, name in names do
		local found = model:FindFirstChild(name, true)
		if found and found:IsA("BasePart") then return found end
	end
	return nil
end

function Rig.Setup(visual: Model): ({[string]: Joint}, {Foot})
	local pivot = visual:GetPivot()
	local torso = part(visual, {"Torso", "UpperTorso", "Body"})
	if not torso then torso = visual.PrimaryPart end
	local joints: {[string]: Joint} = {}
	local feet: {Foot} = {}
	if not torso then return joints, feet end
	local root = part(visual, {"CompanionRoot", "HumanoidRootPart"})
	if root == torso then root = nil end
	if not root then
		local created = Instance.new("Part")
		created.Name = "CompanionRoot"
		created.Size = Vector3.new(0.2, 0.2, 0.2)
		created.CFrame = pivot
		created.Transparency = 1
		created.Parent = visual
		root = created
	end
	assert(root)
	local rigRoot: BasePart = root
	local torsoPart: BasePart = torso
	-- Keep model pivot coordinates unchanged when introducing a root.
	root.PivotOffset = root.CFrame:ToObjectSpace(pivot)
	visual.PrimaryPart = root
	local motors: {Motor6D} = {}
	local connections: {[BasePart]: {BasePart}} = {}
	local rigidConnections: {[BasePart]: {BasePart}} = {}
	local drivers: {[BasePart]: number} = {}
	local function connect(a: BasePart, b: BasePart)
		connections[a] = connections[a] or {}
		connections[b] = connections[b] or {}
		table.insert(connections[a], b)
		table.insert(connections[b], a)
	end
	for _, item in visual:GetDescendants() do
		if item:IsA("JointInstance") or item:IsA("WeldConstraint") then
			local a, b = item.Part0, item.Part1
			if a and b then connect(a, b) end
			if item:IsA("Motor6D") then
				table.insert(motors, item)
				if b then drivers[b] = (drivers[b] or 0) + 1 end
			elseif a and b then
				rigidConnections[a] = rigidConnections[a] or {}
				rigidConnections[b] = rigidConnections[b] or {}
				table.insert(rigidConnections[a], b); table.insert(rigidConnections[b], a)
			end
		end
	end
	local function connected(a: BasePart, b: BasePart, rigidOnly: boolean?): boolean
		local graph = if rigidOnly then rigidConnections else connections
		local seen: {[BasePart]: boolean} = {[a] = true}
		local queue = {a}
		local index = 1
		while index <= #queue do
			local node = queue[index]
			index += 1
			if node == b then return true end
			local neighbors: {BasePart} = graph[node] or {}
			for _, neighbor in neighbors do
				if not seen[neighbor] then seen[neighbor] = true; table.insert(queue, neighbor) end
			end
		end
		return false
	end
	local function register(name: string, motor: Motor6D)
		local a, b = motor.Part0, motor.Part1
		if not a or not b then return end
		if (drivers[b] or 0) > 1 or connected(a, b, true) then
			warn("[CompanionRig] Conflicting motor/weld drivers for " .. name .. " in " .. visual.Name)
			return
		end
		-- Procedural angles are in torso rest axes, conjugated into the authored joint axes.
		local world = (motor.Part0 :: BasePart).CFrame * motor.C0
		joints[MotionMath.JointName(name)] = {Motor = motor, BaseC0 = motor.C0,
			Axis = world.Rotation:ToObjectSpace((torso :: BasePart).CFrame.Rotation)}
	end
	local function joint(name: string, a: BasePart?, b: BasePart?, fallback: Vector3)
		if not a or not b or a == b then return end
		for _, motor in motors do
			if motor.Part0 == a and motor.Part1 == b then register(name, motor); return end
		end
		-- An indirect chain or existing rigid weld must not gain a competing motor.
		if connected(a, b) then
			warn("[CompanionRig] Preserve existing connection; author a Motor6D for " .. name .. " in " .. visual.Name)
			return
		end
		local attachment = b:FindFirstChild(name .. "RigAttachment") or a:FindFirstChild(name .. "RigAttachment")
		local world = CFrame.new(fallback) * (torso :: BasePart).CFrame.Rotation
		if attachment and attachment:IsA("Attachment") then world = attachment.WorldCFrame end
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0 = a
		motor.Part1 = b
		motor.C0 = a.CFrame:ToObjectSpace(world)
		motor.C1 = b.CFrame:ToObjectSpace(world)
		motor.Parent = a
		table.insert(motors, motor)
		connect(a, b)
		register(name, motor)
	end
	-- Register aliases once; actual connectivity below takes precedence over names.
	for _, motor in motors do
		if motor.Part0 and motor.Part1 then
			local name = MotionMath.JointName(motor.Name)
			if not joints[name] then register(name, motor) end
		end
	end
	joint("Body", root, torso, torso.Position)
	local head = part(visual, {"Head"})
	joint("HeadTurn", torso, head, if head then head.Position - torso.CFrame.UpVector * head.Size.Y / 2 else torso.Position)
	local function sidePart(label: string, aliases: {string}, sign: number): BasePart?
		local named = part(visual, {label .. aliases[1], label .. aliases[2]})
		if named then return named end
		for _, item in visual:GetDescendants() do
			if item:IsA("BasePart") and table.find(aliases, item.Name)
				and (torso :: BasePart).CFrame:PointToObjectSpace(item.Position).X * sign > 0 then return item end
		end
		return nil
	end
	for index, label in {"Left", "Right"} do
		local sign = if index == 1 then -1 else 1
		local upper = sidePart(label, {"UpperArm", "Shoulder", "Arm"}, sign)
		local lower = sidePart(label, {"LowerArm", "Forearm"}, sign)
		local hand = sidePart(label, {"Hand", "Fist"}, sign)
		local thigh = sidePart(label, {"UpperLeg", "Thigh", "Leg"}, sign)
		local shin = sidePart(label, {"LowerLeg", "Ankle"}, sign)
		local foot = sidePart(label, {"Foot", "Foot"}, sign)
		local function top(p: BasePart?): Vector3
			return if p then p.Position + torso.CFrame.UpVector * p.Size.Y * 0.45 else torso.Position
		end
		joint(label .. "Shoulder", torso, upper, top(upper))
		joint(label .. "Elbow", upper, lower, top(lower))
		joint(label .. "Wrist", lower, hand, top(hand))
		joint(label .. "Hip", torso, thigh, top(thigh))
		joint(label .. "Knee", thigh, shin, top(shin))
		joint(label .. "Ankle", shin, foot, top(foot))
		local target = rigRoot:FindFirstChild(label .. "FootTarget")
		local ik = visual:FindFirstChild(label .. "FootIK", true)
		if target and target:IsA("Attachment") and ik and ik:IsA("IKControl") and foot
			and ik.ChainRoot and ik.EndEffector then
			ik.Target = target
			ik.Weight = 0
			table.insert(feet, {Target = target, BaseTargetCF = target.CFrame, IK = ik,
				SoleOffset = foot.Size.Y / 2, Side = index, Reach = math.max(0.5, (torso.Position - foot.Position).Magnitude),
				Plant = nil, Support = nil, SupportLocal = nil, WasStance = false, Correction = 0})
		end
	end
	for _, item in visual:GetDescendants() do
		if item:IsA("BasePart") then
			if item ~= root and not connected(rigRoot, item) then
				-- Isolated decorations follow the nearest connected limb, not always the torso.
				local nearest: BasePart = torsoPart
				local distance = math.huge
				for candidate in connections do
					if candidate ~= root and connected(rigRoot, candidate) then
						local d = (candidate.Position - item.Position).Magnitude
						if d < distance then nearest = candidate; distance = d end
					end
				end
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = nearest; weld.Part1 = item; weld.Parent = item
				connect(nearest, item)
			end
			item.Anchored = item == root
			item.CanCollide = false; item.CanTouch = false; item.CanQuery = false; item.Massless = true
		end
	end
	return joints, feet
end

function Rig.Pose(joints: {[string]: Joint}, name: string, offset: CFrame, blend: number)
	local joint = joints[MotionMath.JointName(name)]
	if joint then
		local target = joint.BaseC0 * joint.Axis * offset * joint.Axis:Inverse()
		joint.Motor.C0 = joint.Motor.C0:Lerp(target, blend)
	end
end
return Rig
