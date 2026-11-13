--!strict
-- Server-only traversal. Cosmetic animation never determines gameplay position.
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Motion = require(ReplicatedStorage.Shared.CompanionMotionMath)
local Config = require(script.Parent.CompanionData)
local World = require(script.Parent.CompanionWorld)
local Locomotion = {}
export type State = {
	Model: Model, Offset: number, Height: number, Radius: number,
	VerticalSpeed: number, Grounded: boolean, LastSafe: Vector3,
	AirTime: number, LandingSpeed: number, LandUntil: number,
	Waypoints: {PathWaypoint}, Index: number, Goal: Vector3?, NextPath: number,
	Pending: boolean, Generation: number, Mode: string?, Teleports: number,
	JumpRequestUntil: number,
}

function Locomotion.New(model: Model): State
	local offset, height, radius = World.Dimensions(model)
	model:SetAttribute("CompanionGroundOffset", offset)
	model:SetAttribute("CompanionRigHeight", height)
	model:SetAttribute("CompanionStrideLength", math.max(0.6, height * 0.65))
	return {
		Model = model, Offset = offset, Height = height, Radius = radius,
		VerticalSpeed = 0, Grounded = true, LastSafe = model:GetPivot().Position,
		AirTime = 0, LandingSpeed = 0, LandUntil = 0,
		Waypoints = {}, Index = 1, Goal = nil, NextPath = 0, Pending = false,
		Generation = 0, Mode = nil, Teleports = 0, JumpRequestUntil = 0,
	}
end

function Locomotion.Reset(state: State)
	state.Generation += 1
	state.Waypoints = {}
	state.Goal = nil
	state.Pending = false
	state.NextPath = 0
	state.VerticalSpeed = 0
	state.AirTime = 0
	state.LandingSpeed = 0
	state.LandUntil = 0
	state.JumpRequestUntil = 0
	state.Grounded = true
	state.LastSafe = state.Model:GetPivot().Position
	state.Teleports += 1
	state.Model:SetAttribute("CompanionTeleportId", state.Teleports)
end

local function requestPath(state: State, goal: Vector3)
	if state.Pending or os.clock() < state.NextPath then return end
	state.Pending = true
	state.NextPath = os.clock() + Config.PathRetryInterval
	state.Goal = goal
	local generation = state.Generation
	local start = state.Model:GetPivot().Position - Vector3.new(0, state.Offset, 0)
	local destination = goal - Vector3.new(0, state.Offset, 0)
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = state.Radius + 0.15, AgentHeight = state.Height,
			AgentCanJump = true, AgentCanClimb = false, WaypointSpacing = 2,
		})
		local ok = pcall(function() path:ComputeAsync(start, destination) end)
		if state.Generation == generation and state.Model.Parent then
			state.Pending = false
			if ok and path.Status == Enum.PathStatus.Success then
				state.Waypoints = path:GetWaypoints()
				state.Index = 1 -- retain jump actions at the request origin
				state.JumpRequestUntil = 0
			end
		end
		path:Destroy()
	end)
end

-- Sweep an upright body volume; a small sole inset avoids resting-floor hits.
local function clear(state: State, from: Vector3, to: Vector3, params: RaycastParams, groundStep: boolean?): boolean
	local direction = to - from
	if direction.Magnitude < 0.001 then return true end
	local inset = if groundStep then math.min(Config.StepHeight + 0.1, state.Height * 0.3) else 0.1
	local height = math.max(0.5, state.Height - inset - 0.06)
	local center = from + Vector3.new(0, height / 2 + inset - state.Offset, 0)
	local size = Vector3.new(state.Radius * 2, height, state.Radius * 2)
	return workspace:Blockcast(CFrame.new(center), size, direction, params) == nil
end

-- Thin vertical column: ceilings only, so an obstacle beside the body cannot veto a jump.
local function column(from: Vector3, to: Vector3, params: RaycastParams): boolean
	local direction = to - from
	if direction.Magnitude < 0.001 then return true end
	local start = from + Vector3.new(0, 0.06, 0)
	return workspace:Blockcast(CFrame.new(start), Vector3.new(0.24, 0.12, 0.24), direction, params) == nil
end

local function headroom(state: State, position: Vector3, params: RaycastParams): boolean
	local top = position.Y - state.Offset + state.Height + 0.05
	local from = Vector3.new(position.X, top, position.Z)
	return column(from, from + Vector3.new(0, Config.JumpHeight + 0.1, 0), params)
end

function Locomotion.Step(state: State, target: Vector3?, speed: number, dt: number, alive: boolean, mode: string)
	local model = state.Model
	if state.Mode ~= mode then
		state.Mode = mode
		state.Generation += 1
		state.Waypoints = {}
		state.Goal = nil
		state.Pending = false
		state.NextPath = 0
		state.JumpRequestUntil = 0
	end
	local params = World.Parameters(model)
	local position = model:GetPivot().Position
	local frame = model:GetPivot()
	local goal = if target then World.Ground(model, target) else position
	if state.Goal and (goal - state.Goal).Magnitude > Config.PathTargetTolerance then
		state.Generation += 1
		state.Pending = false
		state.Waypoints = {}
		state.Goal = nil
		state.JumpRequestUntil = 0
	end
	local jumped = false
	local waypoint: PathWaypoint? = state.Waypoints[state.Index]
	while waypoint and (Vector3.new(waypoint.Position.X, position.Y, waypoint.Position.Z) - position).Magnitude < 0.6 do
		jumped = jumped or waypoint.Action == Enum.PathWaypointAction.Jump
		state.Index += 1
		waypoint = state.Waypoints[state.Index]
	end
	if jumped then state.JumpRequestUntil = os.clock() + Config.PathJumpRequestLifetime end
	local destination = if waypoint then waypoint.Position + Vector3.new(0, state.Offset, 0) else goal
	local jumpRequested = os.clock() < state.JumpRequestUntil
	local elapsed = math.clamp(dt, 0, 0.25)
	local stepSize = math.min(1 / 30, Config.MaxTravelPerSubstep / math.max(speed, 1))
	local steps = math.clamp(math.ceil(elapsed / stepSize), 1, 128)
	local h = math.min(stepSize, elapsed / steps)
	local label = "Idle"
	local blocked = false
	local moved = 0
	local slopeCos = math.cos(math.rad(Config.MaxSlopeDegrees))
	for _ = 1, steps do
		local currentHit = World.Support(position, state.Offset, 0.25, Config.MaxDrop + 1, params)
		local clearance = if currentHit then position.Y - state.Offset - currentHit.Position.Y else nil
		if state.Grounded and not Motion.Grounded(clearance, true, state.VerticalSpeed) then
			state.Grounded = false
			state.VerticalSpeed = 0
		end
		local delta = Vector3.new(destination.X - position.X, 0, destination.Z - position.Z)
		local travel = if alive and target and delta.Magnitude > 0.15 then delta.Unit * math.min(speed * h, delta.Magnitude) else Vector3.zero
		local candidate = position + travel
		-- Probe ahead by the body radius so a raise is seen before the body reaches it.
		local aheadJump = false
		local aheadBlocked = false
		if travel.Magnitude > 0 then
			local ahead = position + travel.Unit * (state.Radius + Config.JumpLookAhead)
			local aheadHit = World.Support(ahead, state.Offset, Config.JumpHeight + 0.2, Config.MaxDrop + 1, params)
			local aheadRise = if aheadHit then aheadHit.Position.Y + state.Offset - position.Y else nil
			local aheadTerrain = Motion.Terrain(aheadRise, if aheadHit then aheadHit.Normal.Y else 0, Config.StepHeight, Config.JumpHeight, Config.MaxDrop, slopeCos)
			-- Flat tops are obstacles; tilted hits are walkable slopes, not jump targets.
			aheadJump = aheadTerrain == "Jump" and aheadHit ~= nil and aheadHit.Normal.Y >= 0.9
			aheadBlocked = aheadTerrain == "Blocked"
		end
		local hit = World.Support(candidate, state.Offset, Config.JumpHeight + 0.2, Config.MaxDrop + 1, params)
		local rise = if hit then hit.Position.Y + state.Offset - position.Y else nil
		if state.Grounded then
			local terrain = Motion.Terrain(rise, if hit then hit.Normal.Y else 0, Config.StepHeight, Config.JumpHeight, Config.MaxDrop, slopeCos)
			if travel.Magnitude > 0 and (jumpRequested or aheadJump or terrain == "Jump") then
				if headroom(state, position, params) then
					state.VerticalSpeed = math.sqrt(2 * Config.Gravity * Config.JumpHeight)
					state.Grounded = false
					state.JumpRequestUntil = 0
					jumpRequested = false
				else blocked = true; travel = Vector3.zero end
			elseif travel.Magnitude > 0 and (aheadBlocked or terrain == "Blocked") then
				blocked = true
				travel = Vector3.zero
			elseif hit and rise and travel.Magnitude > 0 then
				if rise < -Config.StepHeight then
					state.Grounded = false
					state.VerticalSpeed = 0
				else
					local lifted = position + Vector3.new(0, math.max(0, rise), 0)
					local grounded = Vector3.new(candidate.X, hit.Position.Y + state.Offset, candidate.Z)
					if clear(state, position, lifted, params) and clear(state, lifted, grounded, params, true) then
						position = grounded
						moved += travel.Magnitude
						if terrain ~= "Walk" or label == "Idle" then label = terrain end
						state.LastSafe = position
					else blocked = true end
					travel = Vector3.zero
				end
			end
		end
		if not state.Grounded then
			state.AirTime += h
			local nextHorizontal = position + travel
			if clear(state, position, nextHorizontal, params) then
				position = nextHorizontal
				moved += travel.Magnitude
			else blocked = true end
			local oldY = position.Y
			local nextY = oldY + state.VerticalSpeed * h - 0.5 * Config.Gravity * h * h
			state.VerticalSpeed -= Config.Gravity * h
			local floor = World.Support(position, state.Offset, 0.1, math.max(Config.MaxDrop, oldY - nextY + 0.2), params)
			local floorY = if floor then floor.Position.Y + state.Offset else -math.huge
			if state.VerticalSpeed <= 0 and floor and floor.Normal.Y >= slopeCos and nextY <= floorY and oldY >= floorY - 0.12 then
				position = Vector3.new(position.X, floorY, position.Z)
				state.LandingSpeed = math.abs(state.VerticalSpeed)
				state.VerticalSpeed = 0
				state.Grounded = true
				state.AirTime = 0
				state.LastSafe = position
				state.LandUntil = os.clock() + 0.16
			elseif nextY > oldY and not column(position, Vector3.new(position.X, nextY, position.Z), params) then
				state.VerticalSpeed = 0
			else
				position = Vector3.new(position.X, nextY, position.Z)
			end
			if state.AirTime > 2.5 or position.Y < workspace.FallenPartsDestroyHeight + state.Height then
				model:PivotTo(CFrame.new(state.LastSafe) * frame.Rotation)
				Locomotion.Reset(state)
				position = model:GetPivot().Position
				break
			end
		end
	end
	if moved > 0.001 then
		local facing = Vector3.new(destination.X - position.X, 0, destination.Z - position.Z)
		if facing.Magnitude > 0.01 then frame = CFrame.lookAt(position, position + facing) end
	end
	model:PivotTo(CFrame.new(position) * frame.Rotation)
	if blocked and target and alive and state.Grounded then requestPath(state, goal) end
	if not alive then label = "Defeated"
	elseif not state.Grounded then label = if state.VerticalSpeed > 0 then "Jump" else "Fall"
	elseif os.clock() < state.LandUntil then label = "Land"
	elseif moved < 0.001 then label = "Idle" end
	model:SetAttribute("CompanionLocomotionState", label)
	model:SetAttribute("CompanionGrounded", state.Grounded)
	model:SetAttribute("CompanionVerticalSpeed", state.VerticalSpeed)
	model:SetAttribute("CompanionLandingSpeed", state.LandingSpeed)
end
return Locomotion
