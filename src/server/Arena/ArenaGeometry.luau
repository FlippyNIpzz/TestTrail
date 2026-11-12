--!strict
-- ArenaFloor is a horizontal disk. Its thin local axis may be X, Y, or Z.
-- Geometry is read on every call so moving/resizing the floor updates all callers.
local Geometry = {}

function Geometry.Dimensions(floor: BasePart): (number, number)
	local size, frame = floor.Size, floor.CFrame
	local thickness, normal, diameter = size.X, frame.RightVector, math.min(size.Y, size.Z)
	if size.Y <= size.X and size.Y <= size.Z then
		thickness, normal, diameter = size.Y, frame.UpVector, math.min(size.X, size.Z)
	elseif size.Z <= size.X and size.Z <= size.Y then
		thickness, normal, diameter = size.Z, frame.LookVector, math.min(size.X, size.Y)
	end
	-- Tilted disks do not define the horizontal circle promised by this contract.
	if math.abs(normal.Y) < 0.999 then return 0, floor.Position.Y end
	return diameter / 2, floor.Position.Y + thickness / 2
end

function Geometry.Floor(): BasePart?
	local container: Instance? = workspace
	for _, name in { "Game", "World", "Arena", "BasicArena", "ArenaFloor" } do
		container = if container then container:FindFirstChild(name) else nil
	end
	if container and container:IsA("BasePart") then
		local radius = Geometry.Dimensions(container)
		if radius > 0 then return container end
	end
	return nil
end

function Geometry.Contains(floor: BasePart, point: Vector3): boolean
	local radius, top = Geometry.Dimensions(floor)
	local dx, dz = point.X - floor.Position.X, point.Z - floor.Position.Z
	return radius > 0 and point.Y >= top - 0.001 and dx * dx + dz * dz <= radius * radius
end

function Geometry.Surface(floor: BasePart, point: Vector3, inset: number, height: number): Vector3
	local radius, top = Geometry.Dimensions(floor)
	local limit = math.max(0, radius - math.max(0, inset))
	local delta = Vector3.new(point.X - floor.Position.X, 0, point.Z - floor.Position.Z)
	if delta.Magnitude > limit then delta = delta.Unit * limit end
	return Vector3.new(floor.Position.X + delta.X, top + height, floor.Position.Z + delta.Z)
end

function Geometry.RandomSurface(floor: BasePart, random: Random, inset: number, height: number): Vector3
	local radius, top = Geometry.Dimensions(floor)
	local distance = math.sqrt(random:NextNumber()) * math.max(0, radius - math.max(0, inset))
	local angle = random:NextNumber(0, 2 * math.pi)
	return Vector3.new(floor.Position.X + math.cos(angle) * distance, top + height,
		floor.Position.Z + math.sin(angle) * distance)
end

return Geometry
