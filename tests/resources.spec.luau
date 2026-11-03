-- Run with tests/run_resources.py through Studio's loadstring compiler.
-- Instances and world queries are mocked; CFrame and Vector3 use Roblox types.
local passed = 0
local function test(name, callback)
    callback()
    passed += 1
    print("PASS " .. name)
end
local function count() return #workspace.Pickups end
local config = Config.Zones["zone.arena"]
test("invalid delays fail startup and leave no pickups", function()
    local zone = Config.Zones["zone.arena"]
    local saved = zone.MinDelaySeconds
    zone.MinDelaySeconds = 0
    assert(not pcall(Spawner.Initialize) and count() == 0)
    zone.MinDelaySeconds = saved
end)
test("all-zero weights fail startup", function()
    config.Weights["resource.ore"] = 0
    assert(not pcall(Spawner.Initialize) and count() == 0)
    config.Weights["resource.ore"] = 1
end)
test("unknown resource references fail startup", function()
    config.Weights["resource.missing"] = 1
    assert(not pcall(Spawner.Initialize) and count() == 0)
    config.Weights["resource.missing"] = nil
end)
test("disabled zones require no world assets", function()
    config.Enabled = false
    local path = config.SurfacePath
    config.SurfacePath = { "Missing" }
    Spawner.Initialize(); Spawner.Schedule(100); Spawner.Step(106)
    assert(count() == 0)
    Spawner.Destroy()
    config.SurfacePath = path; config.Enabled = true
end)
Spawner.Initialize()
Spawner.Schedule(100)
test("zones start empty and wait for their first delay", function()
    assert(count() == 0)
    Spawner.Step(100)
    assert(count() == 0)
    Spawner.Step(106)
    assert(count() == 1)
end)
test("one server-owned resource unit with expiration metadata", function()
    local pickup = workspace.Pickups[1]
    assert(pickup.Attributes.Quantity == 1 and pickup.Attributes.ResourceId == "resource.ore")
    assert(pickup:IsA("Model") and pickup.Attributes.ExpiresAt > 0)
    assert(pickup.Attributes.PreviewOnly == nil)
    for _, part in pickup:GetDescendants() do
        assert(part.Anchored and not part.CanCollide and not part.CanTouch and part.CanQuery)
    end
    -- The inspected floor is rotated 90 degrees, with local X as thickness.
    local box, size = pickup:GetBoundingBox()
    assert(math.abs(box.Position.Y - size.Y / 2 - 2.3) < 0.001)
    assert(math.abs(pickup.CFrame.Position.X) <= 46 and math.abs(pickup.CFrame.Position.Z) <= 46)
    for _, part in workspace.Pickups do
        for _, x in { -1, 1 } do for _, z in { -1, 1 } do
            local corner = part.CFrame:PointToWorldSpace(Vector3.new(x, 0, z))
            assert(corner.X * corner.X + corner.Z * corner.Z <= 2500)
        end end
    end
end)
test("shared zone capacity rejects additional generation", function()
    for _ = 2, config.MaxActive do assert(Spawner.Spawn("zone.arena")) end
    local ok, reason = Spawner.Spawn("zone.arena")
    assert(not ok and reason == "AtCapacity" and count() == config.MaxActive)
end)
test("external destruction releases capacity exactly once", function()
    workspace.Pickups[1]:Destroy()
    assert(Spawner.Spawn("zone.arena"))
    assert(not Spawner.Spawn("zone.arena"))
end)
test("expiration releases all capacity before another attempt", function()
    Spawner.Step(os.clock() + 1000)
    assert(count() == 1)
end)
test("blocked positions exhaust bounded attempts without spawning", function()
    workspace.Blocked = true
    workspace.Queries = 0
    workspace.Rays = 0
    local before = count()
    local ok, reason = Spawner.Spawn("zone.arena")
    assert(not ok and reason == "NoValidPlacement")
    assert(count() == before and workspace.Queries <= config.PlacementAttempts and workspace.Rays == 4 * config.PlacementAttempts)
    workspace.Blocked = false
end)
test("unknown zones and destroyed state reject spawning", function()
    assert(not Spawner.Spawn("zone.missing"))
    Spawner.Destroy(); Spawner.Destroy()
    assert(count() == 0 and not Spawner.Spawn("zone.arena"))
end)
test("reinitialization starts empty and does not duplicate state", function()
    Spawner.Initialize(); Spawner.Initialize(); Spawner.Schedule(100)
    assert(count() == 0)
    Spawner.Step(106)
    assert(count() == 1)
    Spawner.Destroy()
end)
test("all ore appearance variants spawn without changing resource identity", function()
    Spawner.Initialize()
    local seen = {}
    for _ = 1, 120 do
        local ok, pickup = Spawner.Spawn("zone.arena")
        assert(ok and pickup:IsA("Model"))
        assert(pickup.Attributes.ResourceId == "resource.ore" and pickup.Attributes.Quantity == 1)
        seen[pickup.Attributes.ModelVariant] = true
        pickup:Destroy()
    end
    assert(seen.OreCluster and seen.OreClusterWide and seen.OreClusterJagged)
    for _, source in oreModels do
        assert(source.Attributes.PreviewOnly == true and source.Children[1].Anchored == nil)
    end
    Spawner.Destroy()
end)
test("admin pause prevents spawns but continues expiry and resumes safely", function()
    Spawner.Initialize(); Spawner.Schedule(os.clock()); assert(Spawner.Spawn("zone.arena"))
    assert(Spawner.SetGenerationEnabled(false) and not Spawner.GetGenerationEnabled())
    assert(count() == 1)
    local ok, why = Spawner.Spawn("zone.arena"); assert(not ok and why == "GenerationDisabled")
    Spawner.Step(os.clock() + 1000); assert(count() == 0)
    assert(not Spawner.SetGenerationEnabled("yes"))
    assert(Spawner.SetGenerationEnabled(true)); assert(Spawner.Spawn("zone.arena"))
    Spawner.Destroy(); assert(Spawner.GetGenerationEnabled())
end)
return tostring(passed) .. " resource tests passed"
