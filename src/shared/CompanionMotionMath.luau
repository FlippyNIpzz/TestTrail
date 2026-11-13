--!strict
-- Pure locomotion/pose rules, shared with local regression tests.
local Motion = {}

function Motion.Grounded(clearance: number?, wasGrounded: boolean, verticalSpeed: number): boolean
	if clearance == nil or verticalSpeed > 2 then return false end
	return clearance <= (if wasGrounded then 0.24 else 0.12)
end

function Motion.Terrain(rise: number?, normalY: number, stepHeight: number, jumpHeight: number, maxDrop: number, slopeCos: number): string
	if rise == nil or normalY < slopeCos then return "Blocked" end
	if rise > jumpHeight or rise < -maxDrop then return "Blocked" end
	if rise > stepHeight then return "Jump" end
	if rise > 0.08 then return "StepUp" end
	if rise < -0.08 then return "StepDown" end
	return "Walk"
end

function Motion.Gait(phase: number): (number, number, boolean)
	local cycle = (phase / (2 * math.pi)) % 1
	local stance = 0.6
	if cycle < stance then
		return 1 - 2 * cycle / stance, 0, true
	end
	local t = (cycle - stance) / (1 - stance)
	local smooth = t * t * (3 - 2 * t)
	return -1 + 2 * smooth, math.sin(t * math.pi), false
end

function Motion.Attack(age: number): (number, number)
	if age < 0 or age >= 0.55 then return 0, 0 end
	if age < 0.12 then
		local t = age / 0.12
		return t * t * (3 - 2 * t), -t * 0.25
	elseif age < 0.23 then
		return 1, -0.25 + 1.25 * (age - 0.12) / 0.11
	else
		local t = (age - 0.23) / 0.32
		local weight = 1 - t * t * (3 - 2 * t)
		return weight, weight
	end
end

function Motion.JointName(name: string): string
	local key = string.lower((string.gsub(name, "[%s_]", "")))
	local aliases = {
		root = "body", rootjoint = "body", neck = "headturn", head = "headturn",
		leftupperarm = "leftshoulder", rightupperarm = "rightshoulder",
		leftlowerarm = "leftelbow", rightlowerarm = "rightelbow",
		lefthand = "leftwrist", righthand = "rightwrist",
		leftupperleg = "lefthip", rightupperleg = "righthip",
		leftlowerleg = "leftknee", rightlowerleg = "rightknee",
		leftfoot = "leftankle", rightfoot = "rightankle",
	}
	return aliases[key] or key
end
return Motion
