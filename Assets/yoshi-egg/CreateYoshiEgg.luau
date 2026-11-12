-- Paste this entire command into Roblox Studio's Command Bar in Edit mode.
-- The model's pivot is at the bottom of the egg.
local BASE_POSITION = Vector3.new(0, 0, 0)
local SCALE = 1
local SHELL_COLOR = Color3.fromRGB(255, 251, 233)
local SPOT_COLOR = Color3.fromRGB(99, 196, 49)

local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- Overlapping ellipsoids give the shell a broad base and a tapered crown.
-- Each entry is { center height, horizontal radius, vertical radius }.
local profile = {
    { 1.825, 1.725, 1.825 },
    { 2.18, 1.60, 1.87 },
    { 2.70, 1.27, 1.825 },
}

-- Each entry is { angle around the egg, height, spot width, spot height }.
local spotLayout = {
    { -100, 1.78, 1.18, 1.20 },
    { -45, 2.78, 0.95, 1.03 },
    { -155, 2.87, 0.95, 1.08 },
    { -34, 0.91, 0.82, 0.90 },
    { 17, 2.03, 1.13, 1.17 },
    { 79, 2.84, 1.02, 1.02 },
    { 143, 1.92, 1.18, 1.17 },
    { 81, 0.90, 0.84, 0.93 },
    { -93, 3.83, 0.78, 0.76 },
}

local function radiusAtHeight(height)
    local radius = 0
    for _, ellipsoid in ipairs(profile) do
        local t = (height - ellipsoid[1]) / ellipsoid[3]
        if math.abs(t) < 1 then
            radius = math.max(radius, ellipsoid[2] * math.sqrt(1 - t * t))
        end
    end
    return radius
end

local function makePart(parent, shape, size, transform)
    local part = Instance.new("Part")
    part.Shape = shape
    part.Size = size
    part.CFrame = transform
    part.Anchored = true
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

local scratch = Instance.new("Folder")
scratch.Name = "_EggConstruction"
scratch.Parent = workspace

local egg = Instance.new("Model")
egg.Name = "YoshiEgg"
local success, failure = pcall(function()
    local lobes = {}
    for _, ellipsoid in ipairs(profile) do
        local y, horizontal, vertical = table.unpack(ellipsoid)
        table.insert(lobes, makePart(
            scratch,
            Enum.PartType.Ball,
            Vector3.new(horizontal * 2, vertical * 2, horizontal * 2),
            CFrame.new(0, y, 0)
        ))
    end

    local first = table.remove(lobes, 1)
    local shell = first:UnionAsync(lobes, Enum.CollisionFidelity.Hull, Enum.RenderFidelity.Precise)
    shell.Name = "Shell"
    shell.UsePartColor = true
    shell.Color = SHELL_COLOR
    shell.Material = Enum.Material.SmoothPlastic
    shell.Anchored = true
    shell.Parent = egg

    -- Clip each green patch to a slightly larger copy of the shell.
    -- The visible spot curves with the egg from every viewing angle.
    local spotSurface = shell:Clone()
    spotSurface.Size *= 1.012
    spotSurface.Parent = scratch
    for index, entry in ipairs(spotLayout) do
        local degrees, y, width, height = table.unpack(entry)
        local angle = math.rad(degrees)
        local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
        local slope = (radiusAtHeight(y + 0.01) - radiusAtHeight(y - 0.01)) / 0.02
        local normal = (radial - Vector3.yAxis * slope).Unit
        local across = Vector3.yAxis:Cross(normal).Unit
        local up = normal:Cross(across).Unit
        local surface = radial * radiusAtHeight(y) + Vector3.yAxis * y
        local cutter = makePart(
            scratch,
            Enum.PartType.Cylinder,
            Vector3.new(1.20, height, width),
            CFrame.fromMatrix(surface - normal * 0.27, normal, up)
        )
        local spot = spotSurface:IntersectAsync(
            { cutter },
            Enum.CollisionFidelity.Hull,
            Enum.RenderFidelity.Precise
        )
        spot.Name = string.format("GreenSpot_%02d", index)
        spot.UsePartColor = true
        spot.Color = SPOT_COLOR
        spot.Material = Enum.Material.SmoothPlastic
        spot.Anchored = true
        spot.CanCollide = false
        spot.CanTouch = false
        spot.CanQuery = false
        spot.CastShadow = false
        spot.Parent = egg
        cutter:Destroy()
    end

    local bounds, size = egg:GetBoundingBox()
    egg.WorldPivot = CFrame.new(0, bounds.Position.Y - size.Y / 2, 0)
    egg:ScaleTo(SCALE)
    egg:PivotTo(CFrame.new(BASE_POSITION))
end)

scratch:Destroy()
if not success then
    egg:Destroy()
    error("Could not create the egg: " .. tostring(failure), 0)
end

egg.Parent = workspace
Selection:Set({ egg })
ChangeHistoryService:SetWaypoint("Create Yoshi Egg")
print("Created " .. egg:GetFullName())
