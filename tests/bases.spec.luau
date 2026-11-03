local passed = 0
local function test(name, callback)
    local ok, reason = pcall(callback)
    assert(ok, name .. ": " .. tostring(reason))
    passed += 1
end
local function folder(parent, name)
    local f = Instance.new("Folder"); f.Name = name; f.Parent = parent; return f
end
local bases = folder(workspace, "Bases")
local sources = folder(bases, "NoGemBases")
local placed = folder(bases, "PlacedBases")
local originals = {}
for index, definition in Config.Plots do
    local name = definition.Path[#definition.Path]
    local model = Instance.new("Model"); model.Name = name
    local floor = Instance.new("Part"); floor.Name = "Floor"
    floor.Size = Vector3.new(24 + index, 0.5 + index / 10, 28 + index)
    floor.CFrame = CFrame.new(index * 70, floor.Size.Y / 2, 0) * CFrame.Angles(0, index / 5, 0)
    floor.Anchored = true; floor.Parent = model; model.PrimaryPart = floor
    model.Parent = if index <= 5 then sources else placed
    originals[index] = { Model = model, Parent = model.Parent }
end
local function player(id, level, balance)
    local character = Instance.new("Model")
    local part = Instance.new("Part"); part.Name = "HumanoidRootPart"; part.Parent = character
    local humanoid = Instance.new("Humanoid"); humanoid.Parent = character
    local p = { UserId = id, Parent = Players, Character = character, GetAttribute = function() return true end }
    profiles[p] = { Base = { Level = level or 1, Buildings = { ["slot.forge"] = { Level = 2 } } },
        Currencies = { ["currency.cash"] = balance or 1000 }, Features = { Facility = { Stored = 12 } } }
    return p
end
local alice, bob = player(1), player(2)
local function state(p) local ok, result = Service.GetState(p); assert(ok); return result end
local function runtime(p)
    for _, wrapper in workspace.PlayerBases:GetChildren() do if wrapper:GetAttribute("OwnerUserId") == p.UserId then return wrapper end end
    error("No runtime base")
end
local function near(p) p.Character:PivotTo(runtime(p).Structure.Floor.CFrame * CFrame.new(0, 4, 0)) end
Currency.ValidateConfig()
Service.Initialize({})
test("one isolated base per admitted player", function()
    assert(Service.Assign(alice)); assert(Service.Assign(bob))
    local a, b = state(alice), state(bob)
    assert(a.PlotId ~= b.PlotId and a.Level == 1 and a.ModelType == "base.level_1")
    assert(Service.Assign(alice)); assert(#workspace.PlayerBases:GetChildren() == 2)
end)
test("upgrade changes own model and spends exactly configured cash", function()
    near(alice)
    local before = runtime(alice).Structure
    assert(Service.PurchaseLevel(alice, 1))
    assert(state(alice).Level == 2 and state(alice).ModelType == "base.level_2")
    assert(runtime(alice).Structure ~= before and before.Parent == nil)
    assert(profiles[alice].Currencies["currency.cash"] == 900)
    assert(state(bob).Level == 1 and profiles[bob].Currencies["currency.cash"] == 1000)
end)
test("model swap retains plot ground, orientation and building state", function()
    local wrapper = runtime(alice)
    local original = originals[1].Model.Floor
    local ground = Models.Origin(wrapper.Structure.Floor)
    assert((ground.Position - Models.Origin(original).Position).Magnitude < 0.001)
    assert(ground.LookVector:Dot(Models.Origin(original).LookVector) > 0.999)
    local marker = Instance.new("Part"); marker.Name = "ExistingBuilding"; marker.Parent = wrapper.Buildings
    assert(Service.PurchaseLevel(alice, 2))
    assert(marker.Parent == wrapper.Buildings and profiles[alice].Base.Buildings["slot.forge"].Level == 2)
    assert(profiles[alice].Features.Facility.Stored == 12)
end)
test("stale, fractional and non-finite levels cannot buy again", function()
    for _, level in { 1, 2, -1, 1.5, math.huge, 0/0 } do assert(not Service.PurchaseLevel(alice, level)) end
    assert(profiles[alice].Currencies["currency.cash"] == 650 and state(alice).Level == 3)
end)
test("remote players and dead characters cannot upgrade", function()
    local part = bob.Character.HumanoidRootPart
    part.CFrame = CFrame.new(0, 10000, 0)
    assert(not Service.PurchaseLevel(bob, 1))
    near(bob); bob.Character.Humanoid.Health = 0
    assert(not Service.PurchaseLevel(bob, 1))
    bob.Character.Humanoid.Health = 100
end)
test("insufficient cash leaves original model and state intact", function()
    near(bob); profiles[bob].Currencies["currency.cash"] = 99
    local original = runtime(bob).Structure
    local ok, reason = Service.PurchaseLevel(bob, 1)
    assert(not ok and reason == "InsufficientFunds")
    assert(runtime(bob).Structure == original and state(bob).Level == 1)
    profiles[bob].Currencies["currency.cash"] = 1000
end)
test("model preparation failure never charges", function()
    local create = Models.Create
    Models.Create = function() error("Injected asset failure") end
    assert(not Service.PurchaseLevel(bob, 1))
    Models.Create = create
    assert(state(bob).Level == 1 and profiles[bob].Currencies["currency.cash"] == 1000)
end)
test("rejected commit rolls back staged structure and cash", function()
    local original = runtime(bob).Structure
    rejected = true
    assert(not Service.PurchaseLevel(bob, 1))
    rejected = false
    assert(runtime(bob).Structure == original and original.Parent == runtime(bob))
    assert(state(bob).Level == 1 and profiles[bob].Currencies["currency.cash"] == 1000)
    assert(Service.PurchaseLevel(bob, 1))
end)
test("max level cannot charge or replace structure", function()
    near(alice); assert(Service.PurchaseLevel(alice, 3))
    local structure = runtime(alice).Structure
    assert(not Service.PurchaseLevel(alice, 4))
    assert(state(alice).Level == 4 and profiles[alice].Currencies["currency.cash"] == 150)
    assert(runtime(alice).Structure == structure and not Service.GetUpgradePrompt(alice).Enabled)
end)
test("release and reassign restore saved model without a second charge", function()
    assert(Service.Release(alice)); assert(not Service.Release(alice))
    assert(originals[1].Model.Parent == originals[1].Parent)
    assert(Service.Assign(alice)); assert(state(alice).Level == 4)
    assert(profiles[alice].Currencies["currency.cash"] == 150)
    assert(Service.SpawnCharacter(alice))
end)
test("unadmitted or unsupported saves receive no base", function()
    local visitor = player(3); profiles[visitor] = nil
    assert(not Service.Assign(visitor) and not Service.PurchaseLevel(visitor, 1))
    local invalid = player(4, 9)
    assert(not Service.Assign(invalid) and profiles[invalid].Base.Level == 9)
    visitor.Character:Destroy(); invalid.Character:Destroy()
end)
test("exhaustion never assigns another player's plot", function()
    local extras = {}
    for id = 5, 15 do local p = player(id); table.insert(extras, p); assert(Service.Assign(p)) end
    local overflow = player(16)
    local ok, reason = Service.Assign(overflow)
    assert(not ok and reason == "NoBaseAvailable")
    assert(state(alice).Level == 4 and state(bob).Level == 2)
    for _, p in extras do Service.Release(p); p.Character:Destroy() end
    overflow.Character:Destroy()
end)
test("admin purchase switch gates purchases and prompts", function()
    local cash = profiles[bob].Currencies["currency.cash"]
    assert(Service.SetPurchasesEnabled(false) and not Service.GetPurchasesEnabled())
    assert(not Service.GetUpgradePrompt(bob).Enabled)
    local ok, why = Service.PurchaseLevel(bob, 2)
    assert(not ok and why == "PurchasesDisabled" and profiles[bob].Currencies["currency.cash"] == cash)
    assert(not Service.SetPurchasesEnabled("yes"))
    assert(Service.SetPurchasesEnabled(true) and Service.GetUpgradePrompt(bob).Enabled)
end)
test("admin model swap preserves pivot, progress and prompt connection", function()
    local wrapper = runtime(bob)
    local prompt, buildings, old = Service.GetUpgradePrompt(bob), wrapper.Buildings, wrapper.Structure
    local ground = Models.Origin(old.Floor)
    local triggered = 0
    local connection = prompt:GetPropertyChangedSignal("Enabled"):Connect(function() triggered += 1 end)
    local cash, saved = profiles[bob].Currencies["currency.cash"], profiles[bob].Base.Level
    assert(Service.ReplaceAppearance(state(bob).PlotId, 4))
    assert(wrapper.Structure ~= old and old.Parent == nil and wrapper.Buildings == buildings and Service.GetUpgradePrompt(bob) == prompt)
    assert((Models.Origin(wrapper.Structure.Floor).Position - ground.Position).Magnitude < 0.001)
    assert(Models.Origin(wrapper.Structure.Floor).LookVector:Dot(ground.LookVector) > 0.999)
    assert(profiles[bob].Base.Level == saved and profiles[bob].Currencies["currency.cash"] == cash and state(bob).ModelType == "base.level_4")
    assert(Service.GetAdminModelState(state(bob).PlotId).Current == "base.level_4")
    prompt.Enabled = false; prompt.Enabled = true; task.wait(); assert(triggered == 2); connection:Disconnect()
end)
test("invalid and failed admin swaps keep current model", function()
    local original = runtime(bob).Structure
    assert(not Service.ReplaceAppearance(state(bob).PlotId, 99))
    local create = Models.Create; Models.Create = function() error("Injected admin failure") end
    assert(not Service.ReplaceAppearance(state(bob).PlotId, 1)); Models.Create = create
    assert(runtime(bob).Structure == original and original.Parent == runtime(bob))
    local building = Instance.new("Part"); building.Parent = runtime(bob).Buildings
    local ok, why = Service.ReplaceAppearance(state(bob).PlotId, 1)
    assert(not ok and why == "OccupiedBuildings" and runtime(bob).Structure == original)
    building:Destroy()
end)
test("destroy restores authored scene and permits clean reinitialization", function()
    Service.Destroy(); Service.Destroy()
    for _, item in originals do assert(item.Model.Parent == item.Parent) end
    assert(not workspace:FindFirstChild("PlayerBases"))
    Service.Initialize({}); assert(Service.Assign(alice)); assert(state(alice).Level == 4)
    Service.Destroy()
end)
alice.Character:Destroy(); bob.Character:Destroy(); workspace:Destroy()
return tostring(passed) .. " base upgrade tests passed"
