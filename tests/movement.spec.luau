local passed = 0
local function test(name, callback)
    local ok, reason = pcall(callback)
    assert(ok, name .. ": " .. tostring(reason))
    passed += 1
end
local function close(a, b) assert(math.abs(a-b) < 0.0001, tostring(a) .. " ~= " .. tostring(b)) end
local settings = Config.Movement
local function character(position, withRoot)
    local c = Instance.new("Model")
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = c
    if withRoot ~= false then
        local root = Instance.new("Part"); root.Name = "HumanoidRootPart"
        root.Anchored = true; root.Position = position; root.Parent = c
    end
    c.Parent = workspace
    return c
end
local alice = { Attributes = { DataReady = true }, Parent = Players,
    CharacterAdded = signal(), CharacterRemoving = signal(), UserId = 1 }
function alice:GetAttribute(key) return self.Attributes[key] end
function alice:SetAttribute(key, value) self.Attributes[key] = value end
table.insert(players, alice)
alice.Character = character(Vector3.new(100, 8, 0))
local function speed() return alice.Character.Humanoid.WalkSpeed end
local function move(position) alice.Character.HumanoidRootPart.Position = position; Movement.Step() end
local function carry(quantity) assert(Service.SetCarried(alice, { ["resource.ore"] = quantity })) end
local inside = Vector3.new(1, 8, 1)
local outside = Vector3.new(100, 8, 1)
Service.Initialize({}); Service.Track(alice)
test("outside starts at preset with missing carry treated as zero", function()
    close(speed(), settings.OutsideArenaSpeed)
    local ok, counts = Service.GetCarried(alice); assert(ok and next(counts) == nil)
end)
test("entering empty arena uses configured base speed", function()
    move(inside); close(speed(), settings.ArenaBaseSpeed); assert(alice:GetAttribute("InArena") == true)
end)
test("gaining resources updates immediately with existing proportional formula", function()
    carry(15)
    close(speed(), 6.4)
    assert(alice:GetAttribute("CarriedResourceCount") == 15)
end)
test("losing resources restores speed immediately", function()
    carry(5); close(speed(), 16/1.5)
    carry(0); close(speed(), settings.ArenaBaseSpeed)
end)
test("at and beyond threshold speed stays at minimum without capping carry", function()
    carry(30); close(speed(), settings.MinimumArenaSpeed)
    carry(300); close(speed(), settings.MinimumArenaSpeed)
    local ok, counts = Service.GetCarried(alice); assert(ok and counts["resource.ore"] == 300)
end)
test("leaving while heavily loaded always returns to outside preset", function()
    move(outside); close(speed(), settings.OutsideArenaSpeed)
    carry(1); close(speed(), settings.OutsideArenaSpeed)
    carry(300); close(speed(), settings.OutsideArenaSpeed)
end)
test("reentering with threshold load reapplies the minimum", function()
    move(inside); close(speed(), settings.MinimumArenaSpeed)
end)
test("forged carry and location attributes never control authoritative speed", function()
    alice:SetAttribute("CarriedResourceCount", 0); alice:SetAttribute("InArena", false)
    Movement.Step(); close(speed(), settings.MinimumArenaSpeed)
    assert(alice:GetAttribute("InArena") == true)
end)
test("respawn outside resets the new humanoid despite retained carry", function()
    local old = alice.Character
    alice.CharacterRemoving:Fire(old)
    alice.Character = character(outside)
    alice.CharacterAdded:Fire(alice.Character)
    close(speed(), settings.OutsideArenaSpeed)
    old:Destroy()
end)
test("respawn inside calculates from server carry state", function()
    local old = alice.Character
    alice.CharacterRemoving:Fire(old)
    alice.Character = character(inside)
    alice.CharacterAdded:Fire(alice.Character)
    close(speed(), settings.MinimumArenaSpeed)
    carry(0); close(speed(), settings.ArenaBaseSpeed)
    old:Destroy()
end)
test("late root on respawn is handled on the next server frame", function()
    local old = alice.Character
    alice.CharacterRemoving:Fire(old)
    alice.Character = character(inside, false)
    alice.CharacterAdded:Fire(alice.Character)
    close(speed(), settings.OutsideArenaSpeed)
    local root = Instance.new("Part"); root.Name = "HumanoidRootPart"; root.Position = inside; root.Parent = alice.Character
    Movement.Step(); close(speed(), settings.ArenaBaseSpeed)
    old:Destroy()
end)
test("circular arena excludes its bounding-square corners and honors height", function()
    assert(Helpers.IsInsideArena(floor, inside, settings))
    assert(not Helpers.IsInsideArena(floor, Vector3.new(45, 8, 45), settings))
    assert(not Helpers.IsInsideArena(floor, Vector3.new(1, 1000, 1), settings))
    assert(not Helpers.IsInsideArena(floor, Vector3.new(1, -1000, 1), settings))
    floor.CFrame = CFrame.new(31, 4, 21) * CFrame.Angles(0, 0.7, math.pi/2)
    assert(Helpers.IsInsideArena(floor, Vector3.new(31,8,21), settings))
    floor.CFrame = CFrame.new(1,4,1) * CFrame.Angles(0,0,math.pi/2)
end)
test("helper clamps missing invalid negative and excessive carry values", function()
    for _, v in { false, "10", 0/0, -10 } do close(Helpers.CalculateMovementSpeed(settings, true, v), settings.ArenaBaseSpeed) end
    close(Helpers.CalculateMovementSpeed(settings, true, nil), settings.ArenaBaseSpeed)
    close(Helpers.CalculateMovementSpeed(settings, true, math.huge), settings.MinimumArenaSpeed)
    close(Helpers.CalculateMovementSpeed(settings, false, math.huge), settings.OutsideArenaSpeed)
end)
test("invalid carry writes reject without changing prior state", function()
    carry(4)
    for _, n in { -1, 0/0, math.huge, 0.5 } do assert(not Service.SetCarried(alice, { ["resource.ore"] = n })) end
    assert(not Service.SetCarried(alice, { ["resource.missing"] = 1 }))
    local ok, counts = Service.GetCarried(alice); assert(ok and counts["resource.ore"] == 4)
    counts["resource.ore"] = 1000
    Movement.Step(); close(speed(), 16/1.4)
end)
test("server enforcement corrects another WalkSpeed write next frame", function()
    alice.Character.Humanoid.WalkSpeed = 99
    Movement.Step(); close(speed(), 16/1.4)
end)
test("missing arena fails safely to outside speed", function()
    floor.Parent = nil
    Movement.Step(); close(speed(), settings.OutsideArenaSpeed)
    floor.Parent = arena
end)
test("custom speeds are independent outside and configuration validates", function()
    local custom = table.clone(settings)
    custom.OutsideArenaSpeed = 24; custom.ArenaBaseSpeed = 20; custom.MinimumArenaSpeed = 5; custom.ResourceThreshold = 10
    Helpers.ValidateMovement(custom)
    close(Helpers.CalculateMovementSpeed(custom,false,100),24)
    close(Helpers.CalculateMovementSpeed(custom,true,0),20)
    close(Helpers.CalculateMovementSpeed(custom,true,10),5)
    custom.ResourceThreshold=0; assert(not pcall(Helpers.ValidateMovement,custom))
end)
test("tracking and cleanup do not leave duplicate listeners or carried state", function()
    Service.Track(alice); Service.Track(alice)
    assert(alice.CharacterAdded.Count() == 1 and alice.CharacterRemoving.Count() == 1)
    assert(alice:GetAttribute("CarriedResourceCount") == 4)
    Service.Destroy(); Service.Destroy()
    assert(alice.CharacterAdded.Count() == 0 and alice.CharacterRemoving.Count() == 0)
    assert(alice:GetAttribute("CarriedResourceCount") == nil and alice:GetAttribute("InArena") == nil)
    close(speed(), settings.OutsideArenaSpeed)
    Service.Initialize({}); Service.Track(alice)
    local ok, counts = Service.GetCarried(alice); assert(ok and next(counts) == nil)
    Movement.Step(); close(speed(), settings.ArenaBaseSpeed)
    Service.Destroy()
end)
workspace:Destroy()
return tostring(passed) .. " arena movement tests passed"
