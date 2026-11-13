local player = {UserId = 9, Parent = Players, GetAttribute = function() return true end, SetAttribute = function() end}
profiles[player] = {Cash = 0, Base = Profile.Load(nil)}
BaseManager.Near = function() return true end
BaseManager.InitializeBases()
assert(BaseManager.AssignBase(player) == 1)
local base = BaseManager.GetBaseForPlayer(player)
local state = profiles[player].Base
local function buy(slot)
    local zone = base.Model:FindFirstChild("Zones"):FindFirstChild(slot)
    zone:FindFirstChild("ZonePrompt").Triggered.Callback(player)
    return base.Model:FindFirstChild("PlacedAssets"):FindFirstChild(slot)
end
assert(not BaseManager.UpgradeBase(player).Success)
local forge, first = buy("Zone1"), buy("Zone2")
assert(forge and first and state.PurchasedZones.Zone1 and state.PurchasedZones.Zone2)
local pivot = base.CFrame
local level2 = baseModels:FindFirstChild("Base_Level_2")
local third = level2:FindFirstChild("Zones"):FindFirstChild("Zone3")
third.Parent = nil
assert(not BaseManager.UpgradeBase(player).Success and state.Level == 1)
assert(forge.Parent == base.Model:FindFirstChild("PlacedAssets"))
third.Parent = level2:FindFirstChild("Zones")
local duplicate = Instance.new("Part", third.Parent); duplicate.Name = "Zone3"
assert(not BaseManager.UpgradeBase(player).Success)
duplicate:Destroy()
assert(BaseManager.UpgradeBase(player).Success and state.Level == 2)
assert(base.CFrame == pivot and base.Model:GetPivot() == pivot)
assert(forge.Parent == base.Model:FindFirstChild("PlacedAssets"))
assert(forge:GetPivot() == base.Model:FindFirstChild("Zones"):FindFirstChild("Zone1").CFrame)
assert(first.Parent == forge.Parent and not state.PurchasedZones.Zone3)
local second = buy("Zone3"); assert(second and second ~= first)
assert(not BaseManager.UpgradeBase(player).Success) -- existing tier milestone
state.Forge.Tier = 2; state.ChargeStations.Zone2.Tier = 2
local oldModel, oldParent, oldPivot = base.Model, first.Parent, first:GetPivot()
-- Force setup failure after existing facilities have moved; all must roll back.
local failGui = Instance.new
Instance.new = function(class, parent)
    if class == "BillboardGui" then error("simulated unavailable-slot setup failure") end
    return failGui(class, parent)
end
assert(not BaseManager.UpgradeBase(player).Success and state.Level == 2)
assert(base.Model == oldModel and first.Parent == oldParent and first:GetPivot() == oldPivot)
Instance.new = failGui
assert(BaseManager.UpgradeBase(player).Success and state.Level == 3)
local ai = base.Model:FindFirstChild("Zones"):FindFirstChild("Zone4")
assert(not ai:FindFirstChild("ZonePrompt").Enabled)
ai:FindFirstChild("ZonePrompt").Triggered.Callback(player)
assert(not state.PurchasedZones.Zone4)
assert(BaseManager.UpgradeBase(player).Success and state.Level == 4)
assert(buy("Zone5") and state.PurchasedZones.Zone5)
assert(not BaseManager.UpgradeBase(player).Success)
BaseManager.ReleaseBase(player)
assert(BaseManager.AssignBase(player) == 1 and BaseManager.GetBaseForPlayer(player).Level == 4)
base = BaseManager.GetBaseForPlayer(player)
for _, slot in {"Zone1", "Zone2", "Zone3", "Zone5"} do
    assert(base.Model:FindFirstChild("PlacedAssets"):FindFirstChild(slot))
end
print("PASS: purchases, exact layout validation, one-slot unlocks, facility identity/pivot preservation, failed-swap rollback, deferred AI slot, level-4 restore")
-- Resolution must be non-blocking, honor Workspace precedence, and refresh after loading.
local scene = Instance.new("Folder", workspace); scene.Name = "Game"
local authoredBase = Instance.new("Folder", scene); authoredBase.Name = "Base"
local authoredForge = Instance.new("Folder", authoredBase); authoredForge.Name = "Forge_Models"
assert(BaseManager.GetAssetFolder("Forge_Models") == authoredForge)
assert(BaseManager.GetAssetFolder("ChargeStation_Models") == assetsFolder:FindFirstChild("ChargeStation_Models"))
authoredForge:Destroy()
local workspaceAssets = Instance.new("Folder", workspace); workspaceAssets.Name = "Assets"
local workspaceForge = Instance.new("Folder", workspaceAssets); workspaceForge.Name = "Forge_Models"
assert(BaseManager.GetAssetFolder("Forge_Models") == workspaceForge)
workspaceAssets:Destroy()
assert(BaseManager.GetAssetFolder("Forge_Models") == assetsFolder:FindFirstChild("Forge_Models"))
assert(BaseManager.GetAssetFolder("Missing") == nil)
local storageLookup = storage.FindFirstChild
storage.FindFirstChild = function() return nil end
assert(BaseManager.GetAssetFolder("Base_Models") == nil)
assert(#BaseManager.GetZoneCatalog() == 4)
local direct = Instance.new("Model", authoredBase); direct.Name = "Base_Level_1"
assert(BaseManager.GetAssetFolder("Base_Models") == authoredBase)
storage.FindFirstChild = storageLookup
print("PASS: dynamic base asset precedence, sparse roots, missing assets and direct layouts")
