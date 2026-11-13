--!strict
local Players = game:GetService("Players")
local Geometry = require(script.Parent.Parent.Arena.ArenaGeometry)
local World = {}
function World.Position(instance: Instance?): Vector3?
	if instance and instance:IsA("Model") then return instance:GetPivot().Position end
	if instance and instance:IsA("BasePart") then return instance.Position end
	return nil
end
World.Arena = Geometry.Floor
World.InArena = Geometry.Contains
World.ArenaSurface = Geometry.Surface
World.RandomArenaSurface = Geometry.RandomSurface

function World.Parameters(model: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local excluded: {Instance} = {model}
	local runtime = workspace:FindFirstChild("RuntimeCompanions")
	if runtime then table.insert(excluded, runtime) end
	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(excluded, player.Character) end
	end
	params.FilterDescendantsInstances = excluded
	return params
end

function World.Dimensions(model: Model): (number, number, number)
	local box, size = model:GetBoundingBox()
	local bottom = box.Position.Y - size.Y / 2
	local sole: number? = nil
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and (item.Name == "Foot" or item.Name == "LeftFoot" or item.Name == "RightFoot") then
			local cf, dimensions = item.CFrame, item.Size
			local halfHeight = (math.abs(cf.RightVector.Y) * dimensions.X + math.abs(cf.UpVector.Y) * dimensions.Y
				+ math.abs(cf.LookVector.Y) * dimensions.Z) / 2
			local y = item.Position.Y - halfHeight
			sole = if sole then math.min(sole, y) else y
		end
	end
	local offset = model:GetPivot().Position.Y - (sole or bottom)
	return offset, math.max(1, box.Position.Y + size.Y / 2 - (sole or bottom)), math.max(0.4, math.max(size.X, size.Z) / 2)
end

-- Probe relative to the feet, never from far above an unrelated roof/platform.
function World.Support(point: Vector3, offset: number, up: number, down: number, params: RaycastParams): RaycastResult?
	return workspace:Raycast(point + Vector3.new(0, up - offset, 0), Vector3.new(0, -(up + down), 0), params)
end

function World.Ground(model: Model, point: Vector3): Vector3
	local cached = model:GetAttribute("CompanionGroundOffset")
	local offset = if type(cached) == "number" then cached else World.Dimensions(model)
	local hit = World.Support(point, offset, 6, 100, World.Parameters(model))
	if hit then return Vector3.new(point.X, hit.Position.Y + offset, point.Z) end
	return point
end
return World
