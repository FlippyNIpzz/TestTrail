--!strict
-- Scene adapters: no world creation or Studio edits required.
local Geometry = require(script.Parent.Parent.Arena.ArenaGeometry)
local World = {}
function World.Position(instance: Instance?): Vector3?
	if instance and instance:IsA("Model") then return instance:GetPivot().Position end
	if instance and instance:IsA("BasePart") then return instance.Position end
	return nil
end
-- Keep one geometry contract for combat, carrying, collection, and spawning.
World.Arena = Geometry.Floor
World.InArena = Geometry.Contains
World.ArenaSurface = Geometry.Surface
World.RandomArenaSurface = Geometry.RandomSurface
function World.Ground(model: Model, point: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded: {Instance} = {model}
	local runtime = workspace:FindFirstChild("RuntimeCompanions")
	if runtime then table.insert(excluded, runtime) end
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then table.insert(excluded, player.Character) end
	end
	params.FilterDescendantsInstances = excluded
	local hit = workspace:Raycast(point + Vector3.new(0, 30, 0), Vector3.new(0, -100, 0), params)
	if hit then
		local box, size = model:GetBoundingBox()
		local bottomOffset = model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
		return Vector3.new(point.X, hit.Position.Y + bottomOffset, point.Z)
	end
	return point
end
return World
