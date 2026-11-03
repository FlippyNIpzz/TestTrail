local passed = 0
local function test(name, callback)
    local ok, reason = pcall(callback)
    assert(ok, name .. ": " .. tostring(reason))
    passed += 1
    print("PASS " .. name)
end
local function player(id)
    return { UserId = id, Parent = Players, Attributes = {}, SetAttribute = function(self, key, value) self.Attributes[key] = value end,
        GetAttribute = function(self, key) return self.Attributes[key] end }
end

test("independent configured defaults", function()
    local a, b = Schema.New(), Schema.New()
    a.Currencies["currency.cash"] = 100
    assert(b.Currencies["currency.cash"] == 0)
    a.Inventory.Stacks["resource.ore"] = 2
    assert(b.Inventory.Stacks["resource.ore"] == nil)
end)
test("reject newer schema without mutating input", function()
    local data = Schema.New()
    data.SchemaVersion = Config.SchemaVersion + 1
    local ok, reason = Schema.Prepare(data)
    assert(not ok and reason == "NewerSchemaVersion" and data.SchemaVersion == 2)
end)
test("missing version requires migration policy", function()
    assert(not Schema.Prepare({ Currencies = {} }))
end)
test("section reset preserves valid progress and disabled feature data", function()
    local data = Schema.New()
    data.Currencies["currency.cash"] = 30
    data.Inventory = "broken"
    data.Features.Companion = { Owned = { "saved" } }
    local ok, result, resets = Schema.Prepare(data)
    assert(ok and #resets == 1 and resets[1] == "Inventory")
    assert(result.Currencies["currency.cash"] == 30 and result.Features.Companion.Owned[1] == "saved")
    assert(data.Inventory == "broken")
end)
test("unknown inventory references reset the inventory boundary", function()
    local data = Schema.New()
    data.Inventory.Stacks["resource.missing"] = 5
    local ok, result, resets = Schema.Prepare(data)
    assert(ok and #resets == 1 and next(result.Inventory.Stacks) == nil)
end)
test("reject cycles nonfinite and mixed tables", function()
    local cyclic = {}; cyclic.self = cyclic
    assert(not Schema.CheckSerializable(cyclic))
    assert(not Schema.CheckSerializable({ n = 0/0 }))
    assert(not Schema.CheckSerializable({ n = math.huge }))
    assert(not Schema.CheckSerializable({ [1] = "a", label = "b" }))
    assert(not Schema.CheckSerializable({ [2] = "hole" }))
    assert(Schema.CheckSerializable({ list = { 1, 2 }, dictionary = { a = true } }))
end)
Service.Initialize({})
local alice, bob = player(1), player(2)
assert(Service.Load(alice)); assert(Service.Load(bob))
test("memory admission and copy isolation", function()
    assert(alice.Attributes.DataReady and alice.Attributes.DataStatus == "Ready")
    local ok, data = Service.Get(alice); assert(ok)
    data.Currencies["currency.cash"] = 999
    local _, original = Service.Get(alice)
    assert(original.Currencies["currency.cash"] == 0)
end)
test("commit does not leak between players", function()
    assert(Service.Update(alice, function(data) data.Currencies["currency.cash"] = 25 end))
    local _, data = Service.Get(bob)
    assert(data.Currencies["currency.cash"] == 0)
end)
test("rejected and invalid transactions roll back", function()
    assert(not Service.Update(alice, function(data) data.Currencies["currency.cash"] = 8; return false, "No" end))
    assert(not Service.Update(alice, function(data) data.Currencies["currency.cash"] = -1 end))
    assert(not Service.Update(alice, function(data) data.Currencies["currency.cash"] = 0/0 end))
    local _, data = Service.Get(alice)
    assert(data.Currencies["currency.cash"] == 25)
end)
test("yielding and throwing transactions roll back", function()
    assert(not Service.Update(alice, function(data) data.Currencies["currency.cash"] = 0; coroutine.yield() end))
    assert(not Service.Update(alice, function() error("failure") end))
    local _, data = Service.Get(alice)
    assert(data.Currencies["currency.cash"] == 25)
end)
test("reentrant transactions cannot commit", function()
    assert(Service.Update(alice, function()
        local ok, reason = Service.Update(alice, function() end)
        assert(not ok and reason == "TransactionBusy")
    end))
end)
test("release is idempotent and rejoin restores server memory", function()
    assert(Service.Release(alice)); assert(not Service.Release(alice))
    assert(not Service.Get(alice)); assert(not alice.Attributes.DataReady)
    assert(Service.Load(alice))
    local _, data = Service.Get(alice)
    assert(data.Currencies["currency.cash"] == 25)
end)
test("destroy rejects access and resets memory", function()
    Service.Destroy()
    assert(not Service.Load(alice)); assert(not Service.Get(alice))
    Service.Initialize({}); assert(Service.Load(alice))
    local _, data = Service.Get(alice)
    assert(data.Currencies["currency.cash"] == 0)
    Service.Destroy()
end)
print(tostring(passed) .. " player-data tests passed")

-- Persistent adapter tests use a fake ProfileStore; no network or DataStore writes.
local function signal()
    local handlers = {}
    return {
        Connect = function(_, callback)
            table.insert(handlers, callback)
            return { Disconnect = function() table.remove(handlers, table.find(handlers, callback)) end }
        end,
        Fire = function(_, ...) for _, callback in table.clone(handlers) do callback(...) end end,
    }
end
local fake = { DataStoreState = "Access", OnError = signal(), SetConstant = function() end }
local activeProfile, nextData, didAcquire, conflict = nil, nil, false, false
fake.New = function(name, template)
    assert(name == Config.DevelopmentStore)
    return { StartSessionAsync = function(_, key, params)
        didAcquire = false
        if conflict then return nil end
        local data = nextData or Helpers.DeepCopy(template)
        if nextData then params.ValidateData(data) end
        if params.Cancel() then return nil end
        didAcquire = true
        local profile = { Data = data, active = true, OnSessionEnd = signal(), OnAfterSave = signal() }
        profile.AddUserId = function() end
        profile.IsActive = function(self) return self.active end
        profile.EndSession = function(self) self.active = false; self.OnSessionEnd:Fire() end
        profile.Save = function(self) self.OnAfterSave:Fire(self.Data) end
        activeProfile = profile
        return profile
    end }
end
-- The runner substitutes this explicitly marked vendor require for this fake.
VendorForTests = fake
Config.StudioStorageMode = "Persistent"
test("persistent unavailable never falls back to memory", function()
    fake.DataStoreState = "NoAccess"
    assert(not pcall(Service.Initialize, {}))
    assert(not Service.Load(alice))
    Service.Destroy()
    fake.DataStoreState = "Access"
end)
Service.Initialize({})
test("persistent newer schema rejected before acquisition", function()
    nextData = Schema.New(); nextData.SchemaVersion = Config.SchemaVersion + 1
    local ok = Service.Load(alice)
    assert(not ok and not didAcquire and not Service.Get(alice))
    nextData = nil
end)
test("session conflict never activates fallback defaults", function()
    conflict = true
    assert(not Service.Load(alice)); assert(not Service.Get(alice))
    conflict = false
end)
test("persistent data assigned and save queued", function()
    assert(Service.Load(alice))
    assert(Service.Update(alice, function(data) data.Currencies["currency.cash"] = 42 end))
    assert(activeProfile.Data.Currencies["currency.cash"] == 42)
    local ok, state = Service.Save(alice)
    assert(ok and state == "Queued" and alice.Attributes.DataStatus == "Ready")
end)
test("save failures notify and recovery clears status", function()
    -- Suppress retry scheduling in this synchronous fake; test notification callbacks.
    task.spawn = function() end
    fake.OnError:Fire("test write failure", Config.DevelopmentStore, "Player_1")
    assert(alice.Attributes.DataStatus == "SaveFailed")
    activeProfile.OnAfterSave:Fire(activeProfile.Data)
    assert(alice.Attributes.DataStatus == "Ready")
end)
test("session loss blocks all access and disconnects player", function()
    alice.Kick = function(self) self.kicked = true end
    activeProfile.active = false
    activeProfile.OnSessionEnd:Fire()
    assert(alice.kicked and not alice.Attributes.DataReady)
    assert(not Service.Get(alice)); assert(not Service.Update(alice, function() end))
end)
Service.Destroy()
print(tostring(passed) .. " total player-data tests passed")
