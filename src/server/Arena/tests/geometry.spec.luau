-- Run with Roblox datatypes; no authored scene changes.
return function(Geometry, floor)
	assert(Geometry.Floor() == floor, "Must resolve the authored ArenaFloor")
	local radius, top = Geometry.Dimensions(floor)
	assert(radius > 0)
	local center = Vector3.new(floor.Position.X, top, floor.Position.Z)
	assert(Geometry.Contains(floor, center))
	assert(Geometry.Contains(floor, center + Vector3.new(0, 10000, 0)))
	assert(not Geometry.Contains(floor, center - Vector3.new(0, 0.1, 0)))
	assert(Geometry.Contains(floor, center + Vector3.new(radius, 0, 0)))
	assert(not Geometry.Contains(floor, center + Vector3.new(radius + 0.1, 10, 0)))
	assert(not Geometry.Contains(floor, center + Vector3.new(radius * 0.9, 10, radius * 0.9)))
	local random = Random.new(42)
	local meanSquaredRadius = 0
	for _ = 1, 1000 do
		local point = Geometry.RandomSurface(floor, random, 6, 1.5)
		assert(Geometry.Contains(floor, point))
		assert(math.abs(point.Y - top - 1.5) < 0.001)
		local offset = Vector3.new(point.X - center.X, 0, point.Z - center.Z)
		assert(offset.Magnitude <= radius - 6 + 0.001)
		meanSquaredRadius += offset.Magnitude ^ 2 / (radius - 6) ^ 2
	end
	assert(meanSquaredRadius / 1000 > 0.45 and meanSquaredRadius / 1000 < 0.55)
	local drop = Geometry.Surface(floor, center + Vector3.new(radius * 2, 50, radius * 2), math.sqrt(2), 1)
	assert(Geometry.Contains(floor, drop) and math.abs(drop.Y - top - 1) < 0.001)
	-- Exercise translated, resized, and differently oriented floors without editing the scene.
	local sample = Instance.new("Part")
	for _, setup in {
		{Vector3.new(0.5, 100, 100), CFrame.Angles(0, 0, math.pi / 2)},
		{Vector3.new(80, 2, 80), CFrame.Angles(0, 0.7, 0)},
		{Vector3.new(60, 60, 4), CFrame.Angles(math.pi / 2, 0, 0)},
	} do
		sample.Size = setup[1]
		sample.CFrame = CFrame.new(150, 30, -90) * setup[2]
		local r, y = Geometry.Dimensions(sample)
		assert(r > 0 and y > 30)
		assert(Geometry.Contains(sample, Vector3.new(150, y + 100, -90)))
		assert(not Geometry.Contains(sample, Vector3.new(150 + r + 1, y, -90)))
	end
	sample.CFrame = CFrame.Angles(0.5, 0.5, 0.5)
	assert(Geometry.Dimensions(sample) == 0)
	sample:Destroy()
	return "Geometry passed: circular edges, height, 1000 spawns, drop clamp, resize, translation, axis rotation"
end
