--!strict
-- BaseAssetManager (Layer 3: Manager Layer)
-- Forge processing, station power, and asset upgrades.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataManager = require(ServerScriptService:WaitForChild("Server"):WaitForChild("PlayerData"):WaitForChild("PlayerDataModule"))
local Inventory = require(ServerScriptService:WaitForChild("Server"):WaitForChild("PlayerData"):WaitForChild("Inventory"))

local Config = require(game:GetService("ReplicatedStorage").Shared.BaseConfig)
local BaseManager = require(script.Parent.BaseManager)
local BaseAssetManager = {}
local lastConsumption: { [number]: number } = {}
local lastOre: { [number]: string } = {}

export type ForgeInventory = {
    Tier: number,
    Intake: { [string]: number },
    Output: { [string]: number },
}

export type ChargeStationState = {
    Tier: number,
    PowerStored: number,
    MaxPower: number,
    GenerationRate: number,
}

export type PlayerAssetData = {
    Forge: ForgeInventory,
    ChargeStation: ChargeStationState,
}

local initialized = false
local stationModels: { [number]: Instance } = {}

local assetStates: { [number]: PlayerAssetData } = {}
local statusGuis: { [number]: { [string]: BillboardGui } } = {}

local CHARGE_STATION_TIERS = Config.ChargeTiers
local FORGE_TIERS = Config.ForgeTiers

local function getPrimaryPart(assetInstance: Instance): BasePart?
    if assetInstance:IsA("Model") then
        return assetInstance.PrimaryPart or assetInstance:FindFirstChildWhichIsA("BasePart", true)
    elseif assetInstance:IsA("BasePart") then
        return assetInstance
    end
    return nil
end

local function getItemTotal(items: { [string]: number }): number
    local total = 0
    for _, amount in pairs(items) do
        total += amount
    end
    return total
end

local function makeStatusLabel(parent: BillboardGui, name: string, position: UDim2, size: UDim2, textSize: number): TextLabel
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Position = position
    label.Size = size
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Arcade
    label.TextColor3 = Color3.fromRGB(255, 237, 192)
    label.TextStrokeColor3 = Color3.fromRGB(54, 42, 57)
    label.TextStrokeTransparency = 0
    label.TextSize = textSize
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.Parent = parent
    return label
end

local function createStatusGui(player: Player, assetInstance: Instance, assetType: string)
    local primaryPart = getPrimaryPart(assetInstance)
    if not primaryPart then return end

    local existing = assetInstance:FindFirstChild("StatusBillboard")
    if existing then existing:Destroy() end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "StatusBillboard"
    billboard.Adornee = primaryPart
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 100
    billboard.Size = UDim2.fromOffset(280, 170)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
    billboard.Parent = assetInstance

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.fromScale(1, 1)
    panel.BackgroundColor3 = Color3.fromRGB(65, 76, 108)
    panel.BackgroundTransparency = 0.1
    panel.BorderSizePixel = 0
    panel.Parent = billboard

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(54, 42, 57)
    stroke.Thickness = 2
    stroke.Parent = panel

    makeStatusLabel(billboard, "Title", UDim2.fromOffset(8, 5), UDim2.new(1, -16, 0, 22), 16)
    makeStatusLabel(billboard, "Status", UDim2.fromOffset(8, 29), UDim2.new(1, -16, 1, -34), 13)

    local playerGuis = statusGuis[player.UserId] or {}
    playerGuis[assetType] = billboard
    statusGuis[player.UserId] = playerGuis
end

local function updateStatusGui(player: Player, assetType: string)
    local playerGuis = statusGuis[player.UserId]
    local billboard = playerGuis and playerGuis[assetType]
    local state = assetStates[player.UserId]
    if not billboard or not billboard:IsDescendantOf(workspace) or not state then return end

    local title = billboard:FindFirstChild("Title") :: TextLabel?
    local status = billboard:FindFirstChild("Status") :: TextLabel?
    if not title or not status then return end

    if assetType == "Zone1" then
        local function describe(items: { [string]: number }): string
            local names = {}
            for name in pairs(items) do table.insert(names, name) end
            table.sort(names)
            local lines = {}
            for index, name in ipairs(names) do
                if index > 2 then table.insert(lines, "+ more"); break end
                table.insert(lines, ("%s: %d"):format(name, items[name]))
            end
            return if #lines > 0 then table.concat(lines, ", ") else "Empty"
        end
        local forge = state.Forge
        title.Text = ("FORGE | TIER %d%s"):format(forge.Tier, if forge.Tier == #FORGE_TIERS then " | MAX" else "")
        status.Text = ("INTAKE (%d): %s\n%s | %d / 2s\nOUTPUT (%d): %s\nWalk nearby to deposit / collect"):format(
            getItemTotal(forge.Intake), describe(forge.Intake), if next(forge.Intake) then "PROCESSING" else "IDLE",
            FORGE_TIERS[forge.Tier].ProcessPerTick, getItemTotal(forge.Output), describe(forge.Output))
    else
        local charge = state.ChargeStation
        local supplying = os.clock() - (lastConsumption[player.UserId] or -math.huge) < 1.5
        local stateText = if supplying then "SUPPLYING COMPANION" elseif charge.PowerStored >= charge.MaxPower then "FULL" else "FILLING"
        title.Text = ("STATION | TIER %d%s"):format(charge.Tier, if charge.Tier == #CHARGE_STATION_TIERS then " | MAX" else "")
        status.Text = ("POWER: %d / %d\nGENERATION: +%d/s\n%s\nCompanion Home mode to recharge"):format(
            math.floor(charge.PowerStored), charge.MaxPower, charge.GenerationRate, stateText)
    end
end

local function setupStatusGui(player: Player, assetInstance: Instance, assetType: string)
    createStatusGui(player, assetInstance, assetType)
    updateStatusGui(player, assetType)
end

--------------------------------------------------------------------------------
-- INITIALIZATION & DATA SYNC
--------------------------------------------------------------------------------

function BaseAssetManager.Init()
    if initialized then return end
    initialized = true
    print("[BaseAssetManager] Initializing base asset systems...")

    -- BaseServer loads assets after DataReady and before restoring placed facilities.

    Players.PlayerRemoving:Connect(function(player)
        assetStates[player.UserId] = nil
        stationModels[player.UserId] = nil
        statusGuis[player.UserId] = nil
        lastConsumption[player.UserId] = nil
        lastOre[player.UserId] = nil
    end)

    local BaseManager = require(script.Parent:WaitForChild("BaseManager"))
    BaseManager.SetAssetCreatedCallback(function(player, assetType, assetInstance)
        BaseAssetManager.SetupAssetPrompts(player, assetInstance, assetType)
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        BaseAssetManager.LoadPlayerAssets(player)
    end
    for _, base in pairs(BaseManager.GetAllBases()) do
        if base.Player and base.Model then
            local placedAssets = base.Model:FindFirstChild("PlacedAssets")
            if placedAssets then
                for _, asset in ipairs(placedAssets:GetChildren()) do
                    BaseAssetManager.SetupAssetPrompts(base.Player, asset, asset.Name)
                end
            end
        end
    end

    task.spawn(function()
        while true do
            task.wait(0.25)
            for _, player in ipairs(Players:GetPlayers()) do
                BaseAssetManager.HandleForgeProximity(player)
            end
        end
    end)

    -- Start background processing threads
    task.spawn(function()
        BaseAssetManager.RunForgeProcessor()
    end)

    task.spawn(function()
        BaseAssetManager.RunChargeStationGenerator()
    end)
end

function BaseAssetManager.IsInitialized(): boolean return initialized end

function BaseAssetManager.LoadPlayerAssets(player: Player)
    if assetStates[player.UserId] then return end
    local profile = PlayerDataManager.GetProfile(player)
    if not profile or not profile.Base then return end
    -- Direct profile reference: deposits, processing and consumption are saved together.
    assetStates[player.UserId] = profile.Base
end

function BaseAssetManager.GetPlayerAssetData(player: Player): PlayerAssetData?
    return assetStates[player.UserId]
end

--------------------------------------------------------------------------------
-- FORGE MECHANICS (Intake, Processing, Output, Upgrades, Proximity Walk-By)
--------------------------------------------------------------------------------

function BaseAssetManager.DepositOre(player: Player, oreType: string, amount: number): boolean
    local state = assetStates[player.UserId]
    if not state or amount <= 0 or amount >= math.huge or amount % 1 ~= 0 then return false end

    state.Forge.Intake[oreType] = (state.Forge.Intake[oreType] or 0) + amount
    updateStatusGui(player, "Zone1")
    print(("[BaseAssetManager] %s deposited %d %s into Forge intake. (Total Intake: %d)"):format(
        player.Name, amount, oreType, state.Forge.Intake[oreType]
    ))
    return true
end

function BaseAssetManager.CollectOutput(player: Player): { [string]: number }
    local state = assetStates[player.UserId]
    if not state then return {} end

    local collected = state.Forge.Output
    state.Forge.Output = {}
    updateStatusGui(player, "Zone1")
    return collected
end

-- Deposit carried ore nearby; collect output when carrying no ore.
function BaseAssetManager.HandleForgeProximity(player: Player)
    if not PlayerDataManager.GetProfile(player) then return end
    local BaseManager = require(script.Parent:WaitForChild("BaseManager"))
    local base = BaseManager.GetBaseForPlayer(player)
    local placedAssets = if base and base.Player == player and base.Model then base.Model:FindFirstChild("PlacedAssets") else nil
    local forge = placedAssets and placedAssets:FindFirstChild("Zone1")
    local primaryPart = forge and getPrimaryPart(forge)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
    if not forge or forge:GetAttribute("BaseOwnerUserId") ~= player.UserId
        or not primaryPart or not primaryPart:IsDescendantOf(workspace)
        or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0
        or (root.Position - primaryPart.Position).Magnitude > Config.InteractionRange then return end
    local state = assetStates[player.UserId]
    if not state then return end

    local ores = Inventory.GetOres(player)
    local hasOre = next(ores) ~= nil

    if hasOre then
        local summary = {}
        for oreType, count in pairs(ores) do
            if count > 0 and Inventory.RemoveItem(player, oreType, count) then
                BaseAssetManager.DepositOre(player, oreType, count)
                table.insert(summary, ("%d %s"):format(count, oreType))
            end
        end
        if #summary > 0 then BaseManager.Feedback(player, true, "Deposited " .. table.concat(summary, ", ")) end
        print(("[BaseAssetManager]: %s walked by Forge and deposited: %s"):format(
            player.Name, table.concat(summary, ", ")
        ))
    else
        local output = BaseAssetManager.CollectOutput(player)
        if next(output) then
            local summary = {}
            for refinedItem, count in pairs(output) do
                Inventory.AddItem(player, refinedItem, count)
                table.insert(summary, ("%d %s"):format(count, refinedItem))
            end
            BaseManager.Feedback(player, true, "Collected " .. table.concat(summary, ", "))
            print(("[BaseAssetManager]: %s walked by Forge and collected: %s"):format(
                player.Name, table.concat(summary, ", ")
            ))
        end
    end
end

-- Preserve the boolean upgrade API used by existing prompt callers.
local function upgrade(player: Player, zone: string): boolean
    local result = BaseManager.Transaction(player, function()
        local state = assetStates[player.UserId]
        local base = BaseManager.GetBaseForPlayer(player)
        local placed = base and base.Model and base.Model:FindFirstChild("PlacedAssets")
        local current = placed and placed:FindFirstChild(zone)
        local part = current and getPrimaryPart(current)
        if not state or not base or not base.PurchasedZones[zone] or not part or not BaseManager.Near(player, part.Position) then
            return { Success = false, Message = "Stand near your purchased facility to upgrade." }
        end
        local isForge = zone == "Zone1"
        local tier = if isForge then state.Forge.Tier else state.ChargeStation.Tier
        local tiers = if isForge then FORGE_TIERS else CHARGE_STATION_TIERS
        local nextTier = tiers[tier + 1]
        if not nextTier then return { Success = false, Message = "Facility is at maximum tier." } end
        local allowed, reason = BaseManager.CanSpend(player, nextTier.Cost, nextTier.RequiredBaseLevel)
        if not allowed then return { Success = false, Message = reason } end
        local oldCharge = table.clone(state.ChargeStation)
        if isForge then state.Forge.Tier = tier + 1
        else
            local config = CHARGE_STATION_TIERS[tier + 1]
            state.ChargeStation.Tier = tier + 1
            state.ChargeStation.MaxPower = config.MaxPower
            state.ChargeStation.GenerationRate = config.Rate
        end
        local folder = BaseManager.GetAssetFolder(Config.Zones[zone].Folder)
        local ok, model = pcall(BaseManager.UpgradeZoneAsset, player, zone, folder, nextTier.ModelName)
        if not ok or not model then
            state.Forge.Tier = if isForge then tier else state.Forge.Tier
            state.ChargeStation.Tier = oldCharge.Tier
            state.ChargeStation.MaxPower = oldCharge.MaxPower
            state.ChargeStation.GenerationRate = oldCharge.GenerationRate
            state.ChargeStation.PowerStored = oldCharge.PowerStored
            if current then BaseAssetManager.SetupAssetPrompts(player, current, zone) end
            return { Success = false, Message = "Upgrade template unavailable. Current facility and resources preserved." }
        end
        BaseManager.Spend(player, nextTier.Cost)
        return { Success = true, Message = "Upgraded to " .. nextTier.Name .. "." }
    end)
    return result.Success
end
function BaseAssetManager.UpgradeForge(player: Player): boolean return upgrade(player, "Zone1") end

function BaseAssetManager.RunForgeProcessor()
    while true do
        task.wait(Config.ForgeInterval) -- Processing interval

        for userId, state in pairs(assetStates) do
            local player = Players:GetPlayerByUserId(userId)
            local base = player and BaseManager.GetBaseForPlayer(player)
            local placed = base and base.Model and base.Model:FindFirstChild("PlacedAssets")
            local forge = placed and placed:FindFirstChild("Zone1")
            if player and forge and forge:GetAttribute("BaseOwnerUserId") == userId and PlayerDataManager.GetProfile(player) then
                local tierConfig = FORGE_TIERS[state.Forge.Tier] or FORGE_TIERS[1]
                -- Sorted round-robin prevents one ore type starving the rest.
                local names = {}
                for name in pairs(state.Forge.Intake) do table.insert(names, name) end
                table.sort(names)
                local start = 1
                local previous = lastOre[userId]
                if previous then
                    for index, name in ipairs(names) do
                        if name <= previous then start = index + 1 end
                    end
                end
                if start > #names then start = 1 end
                for offset = 0, #names - 1 do
                    local oreType = names[((start + offset - 1) % #names) + 1]
                    local count = state.Forge.Intake[oreType]
                    if count > 0 then
                        local processAmount = math.min(count, tierConfig.ProcessPerTick)
                        state.Forge.Intake[oreType] = count - processAmount
                        
                        local refinedName = "Refined" .. oreType
                        state.Forge.Output[refinedName] = (state.Forge.Output[refinedName] or 0) + processAmount
                        
                        if state.Forge.Intake[oreType] <= 0 then
                            state.Forge.Intake[oreType] = nil
                        end
                        lastOre[userId] = oreType
                        updateStatusGui(player, "Zone1")
                        break
                    end
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- CHARGE STATION MECHANICS (Power Generation, Storage, Upgrades)
--------------------------------------------------------------------------------

function BaseAssetManager.GetChargeStationModel(player: Player): Instance?
    local model = stationModels[player.UserId]
    return if model and model:IsDescendantOf(workspace) then model else nil
end

function BaseAssetManager.GetChargeStationData(player: Player): ChargeStationState?
    local state = assetStates[player.UserId]
    if not state then return nil end
    return table.clone(state.ChargeStation)
end

function BaseAssetManager.UpgradeChargeStation(player: Player): boolean return upgrade(player, "Zone2") end

local function publishCharge(userId: number, cs: ChargeStationState)
    local model = stationModels[userId]
    if model and model:IsDescendantOf(workspace) then
        model:SetAttribute("PowerStored", cs.PowerStored)
        model:SetAttribute("MaxPower", cs.MaxPower)
        model:SetAttribute("GenerationRate", cs.GenerationRate)
        local player = Players:GetPlayerByUserId(userId)
        if player then
            updateStatusGui(player, "Zone2")
        end
    end
end

-- Server-only consumption API; callers must validate the intended interaction.
function BaseAssetManager.TryConsumeCharge(player: Player, amount: number): boolean
    if amount ~= amount or amount <= 0 or amount == math.huge then return false end
    local state = assetStates[player.UserId]
    local model = stationModels[player.UserId]
    if not state or not model or not model:IsDescendantOf(workspace) then return false end
    if state.ChargeStation.PowerStored < amount then return false end
    state.ChargeStation.PowerStored -= amount
    lastConsumption[player.UserId] = os.clock()
    publishCharge(player.UserId, state.ChargeStation)
    return true
end

function BaseAssetManager.StepChargeStations(deltaTime: number)
    if deltaTime ~= deltaTime or deltaTime <= 0 or deltaTime == math.huge then return end
    for userId, state in pairs(assetStates) do
        local model = stationModels[userId]
        local player = Players:GetPlayerByUserId(userId)
        if model and model:IsDescendantOf(workspace) and player and PlayerDataManager.GetProfile(player) then
            local cs = state.ChargeStation
            cs.PowerStored = math.min(cs.MaxPower, cs.PowerStored + cs.GenerationRate * deltaTime)
            publishCharge(userId, cs)
        end
    end
end

function BaseAssetManager.RunChargeStationGenerator()
    while true do
        local elapsed = task.wait(1)
        BaseAssetManager.StepChargeStations(elapsed)
    end
end

--------------------------------------------------------------------------------
-- INTERACTION PROMPTS & PROXIMITY ZONES
--------------------------------------------------------------------------------

function BaseAssetManager.SetupAssetPrompts(player: Player, assetInstance: Instance, assetType: string)
    local primaryPart = getPrimaryPart(assetInstance)
    if not primaryPart then return end

    if assetType ~= "Zone1" and assetType ~= "Zone2" then return end
    setupStatusGui(player, assetInstance, assetType)
    local isForge = assetType == "Zone1"
    local state = assetStates[player.UserId]
    local tiers = if isForge then FORGE_TIERS else CHARGE_STATION_TIERS
    local tier = if state then (if isForge then state.Forge.Tier else state.ChargeStation.Tier) else 1
    local isMax = tier >= #tiers

    if not isForge then
        stationModels[player.UserId] = assetInstance
        if state then publishCharge(player.UserId, state.ChargeStation) end
    end

    local existing = primaryPart:FindFirstChild("UpgradePrompt") or primaryPart:FindFirstChild("AssetInteractionPrompt")
    if existing then existing:Destroy() end

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "UpgradePrompt"
    prompt.ObjectText = if isForge then ("Forge (%s - Tier %d)"):format(FORGE_TIERS[tier].Name, tier)
        else ("Charge Station (Tier %d)"):format(tier)
    local preview = "MAX"
    if not isMax then
        if isForge then preview = ("%d → %d items / 2s"):format(FORGE_TIERS[tier].ProcessPerTick, FORGE_TIERS[tier + 1].ProcessPerTick)
        else
            preview = ("%d → %d power; +%d → +%d/s"):format(
                CHARGE_STATION_TIERS[tier].MaxPower, CHARGE_STATION_TIERS[tier + 1].MaxPower,
                CHARGE_STATION_TIERS[tier].Rate, CHARGE_STATION_TIERS[tier + 1].Rate)
        end
    end
    prompt.ActionText = if isMax then "Max Tier Reached" else ("%s | %s | Base %d"):format(preview, Config.CostText(tiers[tier + 1].Cost), tiers[tier + 1].RequiredBaseLevel)
    prompt:SetAttribute("BaseOwnerUserId", player.UserId)
    prompt.HoldDuration = Config.HoldDuration
    prompt.MaxActivationDistance = Config.InteractionRange
    prompt.RequiresLineOfSight = false
    prompt.ClickablePrompt = true
    prompt.Enabled = not isMax
    prompt.Triggered:Connect(function(triggerPlayer: Player)
        if triggerPlayer ~= player or not primaryPart:IsDescendantOf(workspace) then return end
        if isForge then BaseAssetManager.UpgradeForge(player)
        else BaseAssetManager.UpgradeChargeStation(player) end
    end)
    prompt.Parent = primaryPart

    -- Proximity polling replaces the legacy forge touch zone.
    if isForge then
        local zone = assetInstance:FindFirstChild("ForgeProximityZone")
        if zone then zone:Destroy() end
    end
end

return BaseAssetManager
