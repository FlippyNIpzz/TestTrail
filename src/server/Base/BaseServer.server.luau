--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Remotes = require(Shared.Remotes)
local Config = require(Shared.BaseConfig)
local Data = require(script.Parent.Parent.PlayerData.PlayerDataModule)
local BaseManager = require(script.Parent.BaseManager)
local Assets = require(script.Parent.BaseAssetManager)
local joining: { [Player]: boolean } = {}
local requests: { [Player]: number } = {}
local function onPlayerAdded(player: Player)
    if joining[player] then return end
    joining[player] = true
    -- No guessed profile delay. Leave/failure exits without assigning an empty profile.
    while player.Parent == Players and (player:GetAttribute("DataReady") ~= true
        or not BaseManager.IsInitialized() or not Assets.IsInitialized()) do task.wait(0.1) end
    if player.Parent ~= Players or not Data.GetProfile(player) then return end
    Assets.LoadPlayerAssets(player)
    local index = BaseManager.AssignBase(player)
    if not index then BaseManager.Feedback(player, false, "No base is available. Please rejoin another server."); return end
    local function onCharacter(character: Model)
        local root = character:WaitForChild("HumanoidRootPart", 5)
        local base = BaseManager.GetBaseForPlayer(player)
        if base and root and player.Character == character then character:PivotTo(base.CFrame + Vector3.new(0, 3, 0)) end
    end
    player.CharacterAdded:Connect(onCharacter)
    if player.Character then task.spawn(onCharacter, player.Character) end
end
local function view(player: Player)
    local profile = Data.GetProfile(player)
    local state = profile and profile.Base
    local base = BaseManager.GetBaseForPlayer(player)
    if not state or not base then
        return { Ready = false, Level = 0, Details = "Waiting for your base…", UpgradeText = "Base not ready", CanUpgrade = false }
    end
    local lines = { Config.BaseLevels[state.Level].Name, "Forge and station access available from Base level 1.", "" }
    local placed = base.Model and base.Model:FindFirstChild("PlacedAssets")
    for _, zone in { "Zone1", "Zone2" } do
        local config = Config.Zones[zone]
        if state.PurchasedZones[zone] then
            local tier = if zone == "Zone1" then state.Forge.Tier else state.ChargeStation.Tier
            local tiers = if zone == "Zone1" then Config.ForgeTiers else Config.ChargeTiers
            table.insert(lines, ("%s: Tier %d%s"):format(config.Name, tier, if tier == #tiers then " (MAX)" else ""))
            local asset = placed and placed:FindFirstChild(zone)
            if not asset or asset:GetAttribute("BaseOwnerUserId") ~= player.UserId then
                table.insert(lines, "Not restored — use the zone's retry prompt.")
            end
            if tier < #tiers then
                table.insert(lines, ("Next: %s | %s | Base %d"):format(
                    tiers[tier + 1].Name, Config.CostText(tiers[tier + 1].Cost), tiers[tier + 1].RequiredBaseLevel))
            end
        else table.insert(lines, ("%s: Purchase at its zone | %s | Base %d"):format(config.Name, Config.CostText(config.Cost), config.RequiredBaseLevel)) end
    end
    table.insert(lines, "Command Terminal / Inspector: Coming soon")
    local nextLevel = Config.BaseLevels[state.Level + 1]
    local canUpgrade = false
    local upgradeText = "MAX BASE LEVEL"
    if nextLevel then
        local ready = state.PurchasedZones.Zone1 == true and state.PurchasedZones.Zone2 == true
            and state.Forge.Tier >= nextLevel.RequiredTier and state.ChargeStation.Tier >= nextLevel.RequiredTier
        canUpgrade = ready and profile ~= nil and profile.Cash >= nextLevel.Cost
        upgradeText = ("UPGRADE TO LEVEL %d | %s"):format(state.Level + 1, Config.CostText(nextLevel.Cost))
        table.insert(lines, "\nNext Base milestone: " .. nextLevel.Name)
        table.insert(lines, nextLevel.Description .. (if ready then " — Met" else " — Not met"))
        table.insert(lines, "Upgrade near the center of your base.")
    end
    return { Ready = true, Level = state.Level, Details = table.concat(lines, "\n"), UpgradeText = upgradeText, CanUpgrade = canUpgrade }
end
Remotes.BaseAction.OnServerInvoke = function(player: Player, action: unknown)
    if action ~= "Get" and action ~= "Upgrade" then return nil end
    local now = os.clock()
    if now - (requests[player] or -math.huge) < 0.25 then return nil end
    requests[player] = now
    if action == "Upgrade" then BaseManager.UpgradeBase(player) end
    return view(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player: Player)
    joining[player] = nil; requests[player] = nil
    BaseManager.ReleaseBase(player)
end)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, player) end
