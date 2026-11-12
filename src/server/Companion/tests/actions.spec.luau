local migrated, err = Collection.Load(nil, "ElectricCommon")
assert(migrated and not err and #migrated.Owned == 1)
local saved = migrated.Owned[1]
saved.Level, saved.XP, saved.Mode, saved.Health = 4, 22, "Home", 15
local resumed = Collection.Load(migrated)
assert(resumed.Owned[1].Level == 4 and resumed.Owned[1].XP == 22 and resumed.Owned[1].Mode == "Home")
assert(resumed.Owned[1].Health == 15)
assert(not Collection.Load({Owned = {saved, saved}, EquippedId = saved.Id}))
local player = {Parent = Players, SetAttribute = function() end}
local other = {Parent = Players, SetAttribute = function() end}
local survivor = companion("keep", {Health=10, Charge=5, Damage=8, Speed=7}, 4, 20)
local donor = companion("consume", {Health=5, Charge=10, Damage=7, Speed=8}, 0, 0)
local wrong = companion("rare", {Health=10, Charge=10, Damage=10, Speed=10}, 0, 0)
wrong.Rarity = "Rare"
profiles[player] = {Companions = {Owned = {survivor, donor, wrong}, EquippedId = "keep"}}
profiles[other] = {Companions = {Owned = {companion("foreign", {Health=5,Charge=5,Damage=5,Speed=5},0,0)}}}
Manager.AttachPlayer(player)
local function action(kind, id, secondId)
    now += 1
    return Manager.Action(player, kind, id, secondId)
end
assert(not action("Fuse", "consume", "keep").Ok) -- survivor must be equipped
assert(not action("Fuse", "keep", "keep").Ok)
assert(not action("Fuse", "keep", "foreign").Ok)
assert(not action("Fuse", "keep", "rare").Ok)
assert(not action("Equip", "foreign").Ok)
assert(not action("Mode", "Fight").Ok) -- no arena means no PvP
assert(action("Fuse", "keep", "consume").Ok)
assert(#profiles[player].Companions.Owned == 2 and survivor.XP == 0 and survivor.Level == 4)
assert(survivor.Stats.Charge == 10 and survivor.Stats.Speed == 8)
assert(not action("Fuse", "keep", "consume").Ok) -- consumed IDs cannot be replayed
local snapshot = Manager.Snapshot(player)
snapshot.Owned[1].Stats.Health = 999
assert(survivor.Stats.Health == 10)
assert(action("Equip", "rare").Ok)
assert(survivor.Level == 0 and survivor.XP == 0 and survivor.Stats.Health == 10)
assert(action("Unequip", "rare").Ok and profiles[player].Companions.EquippedId == nil)
assert(action("Equip", "keep").Ok)
assert(Manager.Damage(player, 99999))
assert(survivor.Health == 0 and survivor.Mode == "Home")
assert(not action("Mode", "Follow").Ok)
assert(not Manager.Damage(player, 0/0))
Manager.DetachPlayer(player)
assert(profiles[player].Companions.EquippedId == "keep") -- leave != unequip
print("PASS: legacy migration, resume, ownership, equipped-only fusion, consumed-ID replay, equip resets, defeat, snapshot isolation")
