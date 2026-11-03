--!strict

local Helpers = {}
function Helpers.CalculateSpeed(baseSpeed: number, minimumSpeed: number, weight: number, factor: number): number
    for _, value in { baseSpeed, minimumSpeed, weight, factor } do
        assert(value == value and math.abs(value) < math.huge, "Expected finite movement values")
    end
    assert(baseSpeed > 0 and minimumSpeed > 0 and minimumSpeed <= baseSpeed, "Invalid speed range")
    assert(weight >= 0 and factor >= 0, "Weight and factor must be non-negative")
    return math.max(minimumSpeed, baseSpeed / (1 + weight * factor))
end
function Helpers.ValidateMovement(config: any)
    for _, key in { "OutsideArenaSpeed", "ArenaBaseSpeed", "MinimumArenaSpeed", "ResourceThreshold", "ArenaHeight" } do
        local value = config[key]
        assert(type(value) == "number" and value == value and value > 0 and value < math.huge, "Invalid Movement." .. key)
    end
    assert(config.MinimumArenaSpeed <= config.ArenaBaseSpeed, "MinimumArenaSpeed exceeds ArenaBaseSpeed")
    local factor = (config.ArenaBaseSpeed / config.MinimumArenaSpeed - 1) / config.ResourceThreshold
    assert(factor == factor and factor < math.huge, "Movement speed ratio/threshold overflows")
    assert(type(config.BelowSurfaceTolerance) == "number" and config.BelowSurfaceTolerance >= 0
        and config.BelowSurfaceTolerance < math.huge, "Invalid Movement.BelowSurfaceTolerance")
    assert(type(config.ArenaZoneId) == "string", "Invalid Movement.ArenaZoneId")
end
function Helpers.CalculateMovementSpeed(config: any, insideArena: boolean, carriedCount: any): number
    -- The outside preset bypasses carry calculations unconditionally.
    if not insideArena then return config.OutsideArenaSpeed end
    local count = if type(carriedCount) == "number" and carriedCount == carriedCount then carriedCount else 0
    count = math.clamp(count, 0, config.ResourceThreshold)
    if count >= config.ResourceThreshold then return config.MinimumArenaSpeed end
    -- Preserve the project's proportional formula; derive its factor so the
    -- minimum is reached at the configured threshold, rather than asymptotically.
    local factor = (config.ArenaBaseSpeed / config.MinimumArenaSpeed - 1) / config.ResourceThreshold
    return math.clamp(Helpers.CalculateSpeed(config.ArenaBaseSpeed, config.MinimumArenaSpeed, count, factor),
        config.MinimumArenaSpeed, config.ArenaBaseSpeed)
end
-- Imported floors may use local X or Z as their vertical thickness.
function Helpers.SurfaceGeometry(surface: BasePart): (CFrame, Vector3)
    local cf, size = surface.CFrame, surface.Size
    local normal, right, width, height, depth
    if size.X <= size.Y and size.X <= size.Z then
        normal, right, width, height, depth = cf.RightVector, cf.UpVector, size.Y, size.X, size.Z
    elseif size.Y <= size.Z then
        normal, right, width, height, depth = cf.UpVector, cf.RightVector, size.X, size.Y, size.Z
    else
        normal, right, width, height, depth = -cf.LookVector, cf.RightVector, size.X, size.Z, size.Y
    end
    assert(math.abs(normal:Dot(Vector3.yAxis)) > 0.999, "Arena surface must be horizontal")
    if normal.Y < 0 then normal = -normal end
    return CFrame.fromMatrix(cf.Position, right, normal, right:Cross(normal)), Vector3.new(width, height, depth)
end
function Helpers.IsInsideArena(surface: BasePart, position: Vector3, config: any): boolean
    if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z then return false end
    local frame, size = Helpers.SurfaceGeometry(surface)
    local point = frame:PointToObjectSpace(position)
    local aboveFloor = point.Y - size.Y / 2
    if aboveFloor < -config.BelowSurfaceTolerance or aboveFloor > config.ArenaHeight then return false end
    -- Roblox cylinders extend along local X; its Y/Z axes form the footprint.
    if surface:IsA("Part") and surface.Shape == Enum.PartType.Cylinder then
        return (point.X / (size.X / 2)) ^ 2 + (point.Z / (size.Z / 2)) ^ 2 <= 1
    end
    return math.abs(point.X) <= size.X / 2 and math.abs(point.Z) <= size.Z / 2
end
return Helpers
