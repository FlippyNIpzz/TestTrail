local expected = { {"Zone1", "Zone2"}, {"Zone1", "Zone2", "Zone3"},
    {"Zone1", "Zone2", "Zone3", "Zone4"}, {"Zone1", "Zone2", "Zone3", "Zone4", "Zone5"} }
for level, slots in ipairs(expected) do
    assert(#Config.BaseLevels[level].Slots == #slots)
    for index, id in ipairs(slots) do assert(Config.BaseLevels[level].Slots[index] == id) end
end
assert(Config.Zones.Zone3.AssetType == "ChargeStation")
assert(Config.Zones.Zone4.AssetType == "AIBot" and not Config.Zones.Zone4.Available)
assert(Config.Zones.Zone5.AssetType == "ChargeStation")
local state = Profile.Load({Level = 4, PurchasedZones = {Zone1 = true, Zone2 = true, Zone3 = true, Zone5 = true},
    Forge = {Tier = 2, Intake = {Iron = 8}, Output = {RefinedIron = 3}},
    ChargeStation = {Tier = 2, PowerStored = 123}})
assert(state.Version == 2 and state.Level == 4)
assert(state.Forge.Intake.Iron == 8 and state.Forge.Output.RefinedIron == 3)
assert(state.ChargeStations.Zone2.Tier == 2 and state.ChargeStations.Zone2.PowerStored == 123)
assert(state.ChargeStations.Zone2 == state.ChargeStation)
assert(state.ChargeStations.Zone3 ~= state.ChargeStations.Zone5)
assert(state.ChargeStations.Zone3.PowerStored == 0 and state.ChargeStations.Zone5.Tier == 1)
state.ChargeStations.Zone3.PowerStored = 44
state.ChargeStations.Zone5.PowerStored = 77
local saved = Profile.Load(state)
assert(saved.ChargeStations.Zone3.PowerStored == 44 and saved.ChargeStations.Zone5.PowerStored == 77)
local locked = Profile.Load({Level = 1, PurchasedZones = {Zone2 = true, Zone3 = true, Zone4 = true, Zone5 = true}})
assert(locked.PurchasedZones.Zone2 and not locked.PurchasedZones.Zone3 and not locked.PurchasedZones.Zone5)
local bad = Profile.Load({Level = 4, ChargeStations = {Zone3 = {Tier = 99, PowerStored = math.huge}, Zone5 = {Tier = 2, PowerStored = 999}}})
assert(bad.ChargeStations.Zone3.Tier == 3 and bad.ChargeStations.Zone3.PowerStored == 0)
assert(bad.ChargeStations.Zone5.PowerStored == 200)
local templates = Instance.new("Folder")
for level, slots in ipairs(expected) do
    local model = Instance.new("Model", templates); model.Name = "Base_Level_" .. level
    local zones = Instance.new("Folder", model); zones.Name = "Zones"
    for _, id in ipairs(slots) do local part = Instance.new("Part", zones); part.Name = id end
end
local catalog = Catalog.Levels(templates)
assert(#catalog[4].Zones == 5 and catalog[4].Added[1] == "Zone5")
assert(catalog[3].Added[1] == "Zone4" and catalog[3].Zones[4].Issue == "Not implemented")
local missing = Catalog.Read(nil, 4)
assert(#missing == 5 and missing[1].Issue == "Placement part missing")
local zoneFolder = templates:FindFirstChild("Base_Level_2"):FindFirstChild("Zones")
local duplicate = Instance.new("Part", zoneFolder); duplicate.Name = "Zone3"
assert(Catalog.Read(templates:FindFirstChild("Base_Level_2"), 2)[3].Issue == "Duplicate zone name")
local player = {UserId = 1}; players[1] = player; profiles[player] = {Base = state}
local model = Instance.new("Model", workspace)
local placed = Instance.new("Folder", model); placed.Name = "PlacedAssets"
bases[player] = {Model = model, Level = 4, PurchasedZones = state.PurchasedZones}
Assets.LoadPlayerAssets(player)
local models = {}
for _, slot in {"Zone2", "Zone3", "Zone5"} do
    local station = Instance.new("Model", placed); station.Name = slot
    station:SetAttribute("BaseOwnerUserId", player.UserId)
    station.PrimaryPart = Instance.new("Part", station)
    models[slot] = station
    Assets.SetupAssetPrompts(player, station, slot)
    local status = station:FindFirstChild("StatusBillboard")
    assert(status and status.MaxDistance == Config.StatusRange and status.StudsOffsetWorldSpace.Y == -0.5)
    local anchor = station.PrimaryPart:FindFirstChild("UpgradePromptAttachment")
    assert(anchor and anchor:FindFirstChild("UpgradePrompt") and anchor.WorldPosition.Y == -0.5)
end
assert(Assets.SelectChargeStation(player, nil) == "Zone2")
assert(Assets.SelectChargeStation(player, "Zone3") == "Zone3") -- keep current, not first
assert(Assets.SelectChargeStation(player, "Zone2", true) == "Zone3")
assert(Assets.SelectChargeStation(player, "Zone3", true) == "Zone5")
assert(Assets.SelectChargeStation(player, "Zone5", true) == "Zone2")
assert(Assets.TryConsumeCharge(player, 123, "Zone2"))
assert(state.ChargeStations.Zone2.PowerStored == 0 and state.ChargeStations.Zone3.PowerStored == 44)
assert(Assets.SelectChargeStation(player, "Zone2") == "Zone3")
assert(not Assets.TryConsumeCharge(player, 45, "Zone3"))
assert(not Assets.TryConsumeCharge(player, 0/0, "Zone3"))
local copy = Assets.GetChargeStationData(player, "Zone3"); copy.PowerStored = 0
assert(state.ChargeStations.Zone3.PowerStored == 44)
assert(Assets.UpgradeChargeStation(player, "Zone3"))
assert(state.ChargeStations.Zone3.Tier == 2 and state.ChargeStations.Zone3.PowerStored == 44)
assert(state.ChargeStations.Zone5.Tier == 1 and state.ChargeStations.Zone2.Tier == 2)
failUpgrade = true
assert(not Assets.UpgradeChargeStation(player, "Zone3"))
assert(state.ChargeStations.Zone3.Tier == 2 and state.ChargeStations.Zone3.MaxPower == 200)
assert(not Assets.UpgradeChargeStation(player, "Zone4"))
Assets.StepChargeStations(1)
assert(state.ChargeStations.Zone2.PowerStored == 10 and state.ChargeStations.Zone3.PowerStored == 54 and state.ChargeStations.Zone5.PowerStored == 82)
bases[player].Level = 2
Assets.StepChargeStations(1)
assert(state.ChargeStations.Zone5.PowerStored == 82) -- authored extra cannot generate early
assert(Assets.SelectChargeStation(player, "Zone3", true) == "Zone2")
bases[player].Level = 4
state.PurchasedZones.Zone3 = nil
assert(Assets.SelectChargeStation(player, "Zone2", true) == "Zone5")
assert(not Assets.TryConsumeCharge(player, 1, "Zone3"))
state.PurchasedZones.Zone3 = true
models.Zone5:Destroy()
assert(Assets.SelectChargeStation(player, "Zone3", true) == "Zone2")
state.ChargeStations.Zone2.PowerStored = 0; state.ChargeStations.Zone3.PowerStored = 0
assert(Assets.SelectChargeStation(player, nil) == nil)
Assets.StepChargeStations(1)
assert(Assets.SelectChargeStation(player, nil) == "Zone2")
print("PASS: four layouts, legacy/per-slot save migration, locked slots, catalog diagnostics, station cycle, empty/missing stations, isolated consumption/upgrades, rollback and generation")
