--!strict
-- Runtime ownership and authored placement. Base upgrades migrate facilities to matching new zones.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage.Shared.BaseConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Data = require(script.Parent.Parent.PlayerData.PlayerDataModule)
local BaseData = require(script.Parent.BaseData)
local BaseUtils = require(script.Parent.BaseUtils)
local ZoneCatalog = require(script.Parent.BaseZoneCatalog)
local BaseManager = {}
export type BaseAssignment = {
    Player: Player?, Index: number, Position: Vector3, CFrame: CFrame, IsPathway: boolean,
    Model: Model?, LayoutTemplate: Model?, Level: number, PurchasedZones: { [string]: boolean },
}
export type Result = { Success: boolean, Message: string }
local bases: { [number]: BaseAssignment } = {}
local playerToBase: { [Player]: number } = {}
local assetCreatedCallback: ((Player, string, Instance) -> ())? = nil
local initialized = false
local busy: { [Player]: boolean } = {}
local worldFolder = Workspace:FindFirstChild("World") or Instance.new("Folder", Workspace)
worldFolder.Name = "World"
local basesFolder = worldFolder:FindFirstChild("Bases") or Instance.new("Folder", worldFolder)
basesFolder.Name = "Bases"
-- Resolve on demand so assets added after module loading are available immediately.
local function assetRoots(): { Instance }
    local roots: { Instance } = {}
    local scene = Workspace:FindFirstChild("Game")
    local base = scene and scene:FindFirstChild("Base")
    if base then table.insert(roots, base) end
    for _, service in { Workspace, ServerStorage, ReplicatedStorage } do
        local assets = service:FindFirstChild("Assets")
        if assets then table.insert(roots, assets) end
    end
    return roots
end
local function assetFolder(name: string): Instance?
    for _, root in assetRoots() do
        local folder = root:FindFirstChild(name)
        if folder then return folder end
        if name == "Base_Models" and root:FindFirstChild("Base_Level_1") then return root end
    end
    return nil
end
local function baseTemplate(name: string): Instance?
    for _, root in assetRoots() do
        local folder = root:FindFirstChild("Base_Models") or root
        local template = folder:FindFirstChild(name)
        if template then return template end
    end
    return nil
end

function BaseManager.Feedback(player: Player, success: boolean, message: string): Result
    if player.Parent == Players then Remotes.BaseFeedback:FireClient(player, success, message) end
    return { Success = success, Message = message }
end
function BaseManager.GetBaseForPlayer(player: Player): BaseAssignment?
    local index = playerToBase[player]
    return if index then bases[index] else nil
end
function BaseManager.GetAllBases(): { [number]: BaseAssignment } return bases end
function BaseManager.IsInitialized(): boolean return initialized end
function BaseManager.IsOwner(player: Player, index: number): boolean
    local base = bases[index]
    return base ~= nil and base.Player == player
end
function BaseManager.SetAssetCreatedCallback(callback: ((Player, string, Instance) -> ())?) assetCreatedCallback = callback end
function BaseManager.GetAssetFolder(name: string): Instance? return assetFolder(name) end
function BaseManager.GetZoneCatalog(): { ZoneCatalog.LevelInfo }
    return ZoneCatalog.Levels(assetFolder("Base_Models"))
end
function BaseManager.GetPlayerZones(player: Player): ({ ZoneCatalog.ZoneInfo }, string?)
    local base = BaseManager.GetBaseForPlayer(player)
    return ZoneCatalog.Read(if base then base.Model else nil, if base then base.Level else 1)
end
function BaseManager.Near(player: Player, position: Vector3): boolean
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
    return player.Parent == Players and player:GetAttribute("DataReady") == true
        and root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.Health > 0
        and (root.Position - position).Magnitude <= Config.InteractionRange
end
function BaseManager.CanSpend(player: Player, cost: number, requiredLevel: number): (boolean, string)
    local profile = Data.GetProfile(player)
    if not profile or not profile.Base or not BaseManager.GetBaseForPlayer(player) then return false, "Base is not ready." end
    if profile.Base.Level < requiredLevel then return false, ("Requires Base level %d."):format(requiredLevel) end
    if cost < 0 or cost ~= cost or cost == math.huge then return false, "Invalid upgrade cost." end
    if profile.Cash < cost then return false, ("Requires %s."):format(Config.CostText(cost)) end
    return true, ""
end
function BaseManager.Spend(player: Player, cost: number)
    local profile = Data.GetProfile(player)
    if profile then
        profile.Cash -= cost
        player:SetAttribute("Cash", profile.Cash)
    end
end
-- All transaction callbacks below must be synchronous; no DataStore/network waits.
function BaseManager.Transaction(player: Player, action: () -> Result): Result
    if busy[player] then return BaseManager.Feedback(player, false, "Please wait for the current action.") end
    busy[player] = true
    local ok, result = pcall(action)
    busy[player] = nil
    if not ok then
        warn("[BaseManager] Action failed: " .. tostring(result))
        return BaseManager.Feedback(player, false, "Unable to complete the action. Please retry.")
    end
    return BaseManager.Feedback(player, result.Success, result.Message)
end
local function primary(asset: Instance): BasePart?
    if asset:IsA("BasePart") then return asset end
    if asset:IsA("Model") then return asset.PrimaryPart or asset:FindFirstChildWhichIsA("BasePart", true) end
    return nil
end
local function prepare(folder: Instance?, name: string, pivot: CFrame): Instance?
    local template = folder and folder:FindFirstChild(name)
    if not template or not template.Archivable or not primary(template) then return nil end
    local clone: Instance? = nil
    local ok = pcall(function()
        local copy = template:Clone()
        clone = copy
        if not primary(copy) then error("Cloned facility has no usable part") end
        if copy:IsA("Model") then copy:PivotTo(pivot)
        elseif copy:IsA("BasePart") then copy.CFrame = pivot
        else error("Facility must be a Model or BasePart") end
    end)
    if not ok then if clone then clone:Destroy() end; return nil end
    return clone
end
local function install(player: Player, zone: string, copy: Instance, placed: Instance, old: Instance?): boolean
    copy.Name = zone
    copy:SetAttribute("BaseOwnerUserId", player.UserId)
    copy:SetAttribute("RuntimeBaseAsset", true)
    copy:SetAttribute("BaseFacilityReady", true)
    -- Setup before removing the old asset. Failed setup leaves it usable.
    local ok, reason = pcall(function()
        copy.Parent = placed
        if assetCreatedCallback then assetCreatedCallback(player, zone, copy) end
    end)
    if not ok then
        copy:Destroy()
        warn("[BaseManager] Asset setup failed: " .. tostring(reason))
        return false
    end
    if old then old:Destroy() end
    return true
end
function BaseManager.UpgradeZoneAsset(player: Player, zone: string, folder: Instance?, name: string): Instance?
    local base = BaseManager.GetBaseForPlayer(player)
    local placed = base and base.Model and base.Model:FindFirstChild("PlacedAssets")
    local old = placed and placed:FindFirstChild(zone)
    if not old or not placed or not (old:IsA("Model") or old:IsA("BasePart")) then return nil end
    local copy = prepare(folder, name, (old :: PVInstance):GetPivot())
    if not copy then return nil end
    return if install(player, zone, copy, placed, old) then copy else nil
end
local function savedTemplate(player: Player, zone: string): string
    local profile = Data.GetProfile(player)
    local state = profile and profile.Base
    if Config.Zones[zone].AssetType == "Forge" then return Config.ForgeTiers[if state then state.Forge.Tier else 1].ModelName end
    return Config.ChargeTiers[if state then state.ChargeStations[zone].Tier else 1].ModelName
end
local function place(player: Player, zonePart: BasePart, placed: Instance): boolean
    local config = Config.Zones[zonePart.Name]
    if not config or not config.Available then return false end
    local existing = placed:FindFirstChild(zonePart.Name)
    if existing and existing:GetAttribute("BaseOwnerUserId") == player.UserId
        and existing:GetAttribute("BaseFacilityReady") == true then return true end
    local pivot = zonePart.CFrame
    if existing then
        if not (existing:IsA("Model") or existing:IsA("BasePart")) then return false end
        -- Authored facilities keep their placement even when restoring a different saved tier.
        pivot = (existing :: PVInstance):GetPivot()
    end
    local copy = prepare(BaseManager.GetAssetFolder(config.Folder), savedTemplate(player, zonePart.Name), pivot)
    return copy ~= nil and install(player, zonePart.Name, copy, placed, existing)
end
local function hideZone(zone: BasePart)
    zone.Transparency = 1
    zone.CanCollide = false
    local prompt = zone:FindFirstChild("ZonePrompt")
    if prompt then prompt:Destroy() end
end
local function setupZonePrompts(base: BaseAssignment, layoutLevel: number?)
    local model = base.Model
    if not model then return end
    local zones = model:FindFirstChild("Zones")
    if not zones then return end
    local placed: Instance = model:FindFirstChild("PlacedAssets") or Instance.new("Folder", model)
    placed.Name = "PlacedAssets"
    for _, part in ipairs(zones:GetChildren()) do
        if not part:IsA("BasePart") then continue end
        local zone = part.Name
        local config = Config.Zones[zone]
        local oldPrompt = part:FindFirstChild("ZonePrompt")
        if oldPrompt then oldPrompt:Destroy() end
        local owner = base.Player
        local unlocked = Config.HasSlot(layoutLevel or base.Level, zone)
        if not unlocked then continue end
        if owner and base.PurchasedZones[zone] and place(owner, part, placed) then hideZone(part); continue end
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = "ZonePrompt"
        prompt.ObjectText = if config then config.Name else zone
        prompt.ActionText = if not config or not config.Available then "Coming soon"
            elseif base.PurchasedZones[zone] then "Retry restoring facility"
            else ("Purchase | %s | Base %d"):format(Config.CostText(config.Cost), config.RequiredBaseLevel)
        prompt.HoldDuration = Config.HoldDuration
        prompt.MaxActivationDistance = Config.InteractionRange
        prompt.RequiresLineOfSight = false
        prompt.ClickablePrompt = true
        prompt.Enabled = owner ~= nil and config ~= nil and config.Available
        prompt:SetAttribute("BaseOwnerUserId", if owner then owner.UserId else 0)
        prompt.Parent = part
        if config and not config.Available then
            local old = part:FindFirstChild("UnavailableStatus")
            if old then old:Destroy() end
            local gui = Instance.new("BillboardGui")
            gui.Name = "UnavailableStatus"; gui.Size = UDim2.fromOffset(180, 40)
            gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0); gui.MaxDistance = 40
            local label = Instance.new("TextLabel")
            label.Size = UDim2.fromScale(1, 1); label.BackgroundTransparency = 1
            label.TextColor3 = Color3.fromRGB(255, 237, 192); label.TextStrokeTransparency = 0
            label.Text = config.Name .. " — Coming soon"; label.TextWrapped = true
            label.Parent = gui; gui.Parent = part
        end
        prompt.Triggered:Connect(function(player: Player)
            BaseManager.Transaction(player, function()
                if base.Player ~= player or base.Model ~= model or not Config.HasSlot(base.Level, zone)
                    or not BaseManager.Near(player, part.Position) then
                    return { Success = false, Message = "Stand near a zone in your own base." }
                end
                if not config or not config.Available then return { Success = false, Message = "Coming soon." } end
                local restoring = base.PurchasedZones[zone] == true
                local installed = placed:FindFirstChild(zone)
                if restoring and installed and installed:GetAttribute("BaseOwnerUserId") == player.UserId
                    and installed:GetAttribute("BaseFacilityReady") == true then
                    return { Success = false, Message = "Already purchased." }
                end
                local cost = if restoring then 0 else config.Cost
                local allowed, reason = BaseManager.CanSpend(player, cost, if restoring then 1 else config.RequiredBaseLevel)
                if not allowed then return { Success = false, Message = reason } end
                if not place(player, part, placed) then return { Success = false, Message = "Facility template unavailable. Nothing was charged." } end
                BaseManager.Spend(player, cost)
                base.PurchasedZones[zone] = true
                hideZone(part)
                return { Success = true, Message = config.Name .. (if restoring then " restored." else " purchased.") }
            end)
        end)
    end
end
-- Validate the exact next-level template before touching the live base.
local function requiredZones(level: number, purchased: { [string]: boolean }, placed: Instance?): { [string]: boolean }
    local required: { [string]: boolean } = {}
    for _, name in ipairs(Config.BaseLevels[level].Slots) do required[name] = true end
    for name, owned in pairs(purchased) do if owned then required[name] = true end end
    if placed then
        for _, asset in ipairs(placed:GetChildren()) do required[asset.Name] = true end
    end
    return required
end
local function validateLayout(level: number, required: { [string]: boolean }): (Model?, string)
    local name = "Base_Level_" .. level
    local template = baseTemplate(name)
    if not template or not template:IsA("Model") or not template.Archivable or not primary(template) then
        return nil, name .. " is unavailable or invalid."
    end
    for _, item in ipairs(template:GetDescendants()) do
        if not item.Archivable then return nil, name .. " contains non-archivable content." end
    end
    local zones = template:FindFirstChild("Zones")
    if not zones then return nil, name .. " is missing Zones." end
    local found: { [string]: boolean } = {}
    local seen: { [string]: boolean } = {}
    for _, zone in ipairs(zones:GetChildren()) do
        if seen[zone.Name] then return nil, name .. " has duplicate zone " .. zone.Name .. "." end
        seen[zone.Name] = true
        if not Config.HasSlot(level, zone.Name) then return nil, name .. " has unexpected zone " .. zone.Name .. "." end
        if zone:IsA("BasePart") then found[zone.Name] = true end
    end
    for zone in pairs(required) do
        if not found[zone] then return nil, name .. " is missing zone " .. zone .. "." end
    end
    local placed = template:FindFirstChild("PlacedAssets")
    if placed and not placed:IsA("Folder") then return nil, name .. " has an invalid PlacedAssets folder." end
    return template, ""
end
function BaseManager.GetLayoutAvailability(player: Player, level: number): (boolean, string)
    local base = BaseManager.GetBaseForPlayer(player)
    if not base then return false, "Base is not ready." end
    local placed = base.Model and base.Model:FindFirstChild("PlacedAssets")
    local template, reason = validateLayout(level, requiredZones(level, base.PurchasedZones, placed))
    return template ~= nil, reason
end
local function replaceOwnedBase(player: Player, base: BaseAssignment, level: number): (boolean, string)
    local old = base.Model
    if not old then return false, "Current base is unavailable." end
    local oldPlaced = old:FindFirstChild("PlacedAssets")
    local required = requiredZones(level, base.PurchasedZones, oldPlaced)
    local template, reason = validateLayout(level, required)
    if not template then return false, reason end
    -- Every current asset must be movable and uniquely mapped; never silently drop one.
    local names: { [string]: boolean } = {}
    local moves: { { Asset: PVInstance, Parent: Instance, Pivot: CFrame } } = {}
    if oldPlaced then
        for _, asset in ipairs(oldPlaced:GetChildren()) do
            if not (asset:IsA("Model") or asset:IsA("BasePart")) or names[asset.Name] then
                return false, "Cannot safely map placed asset " .. asset.Name .. "."
            end
            if base.PurchasedZones[asset.Name] and (asset:GetAttribute("BaseOwnerUserId") ~= player.UserId
                or asset:GetAttribute("BaseFacilityReady") ~= true) then
                return false, "Restore " .. asset.Name .. " before upgrading the base."
            end
            names[asset.Name] = true
            table.insert(moves, { Asset = asset :: PVInstance, Parent = oldPlaced, Pivot = (asset :: PVInstance):GetPivot() })
        end
    end
    local model = template:Clone()
    model.Name = old.Name
    model:PivotTo(base.CFrame)
    model:SetAttribute("BaseIndex", base.Index)
    model:SetAttribute("BaseOwnerUserId", player.UserId)
    model:SetAttribute("BaseLevel", level)
    local zones = model:FindFirstChild("Zones") :: Instance
    local placed: Instance = model:FindFirstChild("PlacedAssets") or Instance.new("Folder", model)
    placed.Name = "PlacedAssets"
    -- Template placeholders must not duplicate purchased/live facilities.
    for _, placeholder in ipairs(placed:GetChildren()) do
        if names[placeholder.Name] or base.PurchasedZones[placeholder.Name] then placeholder:Destroy() end
    end
    local restored: { Instance } = {}
    for zone, owned in pairs(base.PurchasedZones) do
        if not owned or names[zone] then continue end
        local config = Config.Zones[zone]
        if not config or not config.Available then model:Destroy(); return false, "Cannot restore owned facility " .. zone .. "." end
        local target = zones:FindFirstChild(zone) :: BasePart
        local asset = prepare(BaseManager.GetAssetFolder(config.Folder), savedTemplate(player, zone), target.CFrame)
        if not asset then model:Destroy(); return false, "Cannot restore " .. config.Name .. "; its saved-tier template is unavailable." end
        asset.Name = zone
        asset:SetAttribute("BaseOwnerUserId", player.UserId)
        asset:SetAttribute("BaseFacilityReady", true)
        asset:SetAttribute("RuntimeBaseAsset", true)
        asset.Parent = placed
        table.insert(restored, asset)
    end
    local ok, failure = pcall(function()
        -- No yields: migrate the actual instances, preserving prompts and station registration.
        for _, move in ipairs(moves) do
            local target = zones:FindFirstChild(move.Asset.Name) :: BasePart
            move.Asset.Parent = placed
            move.Asset:PivotTo(target.CFrame)
        end
        base.Model = model
        model.Parent = basesFolder
        for _, asset in ipairs(restored) do
            if assetCreatedCallback then assetCreatedCallback(player, asset.Name, asset) end
        end
        setupZonePrompts(base, level)
    end)
    if not ok then
        base.Model = old
        for _, move in ipairs(moves) do
            move.Asset.Parent = move.Parent
            move.Asset:PivotTo(move.Pivot)
        end
        model:Destroy()
        warn("[BaseManager] Base upgrade rolled back: " .. tostring(failure))
        return false, "Unable to prepare the next base. Your current base and facilities were preserved."
    end
    old:Destroy()
    return true, ""
end
local function updateBaseModel(base: BaseAssignment, layout: number): boolean
    if base.Model and base.Model:GetAttribute("PreserveAuthoredBase") == true and not base.LayoutTemplate then
        warn("[BaseManager] Authored base is not archivable; cannot safely assign or reset it.")
        return false
    end
    local template: Instance? = nil
    if layout > 1 then
        -- Saved progression must restore its actual layout, never silently fall back to level 1.
        local exact, reason = validateLayout(layout, requiredZones(layout, base.PurchasedZones, nil))
        if not exact then warn("[BaseManager] " .. reason); return false end
        template = exact
    else
        template = base.LayoutTemplate or baseTemplate("Base_Level_" .. layout)
            or baseTemplate("Base_Level_1") or baseTemplate("Base_Level_0")
    end
    if not template or not template:IsA("Model") or not template.Archivable then return false end
    if base.LayoutTemplate then
        for _, item in ipairs(template:GetDescendants()) do
            if not item.Archivable then return false end
        end
    end
    local model = template:Clone()
    model.Name = "Base_" .. base.Index
    model:PivotTo(base.CFrame)
    model:SetAttribute("BaseIndex", base.Index)
    model:SetAttribute("BaseLevel", layout)
    if layout > 1 then
        local placeholders = model:FindFirstChild("PlacedAssets")
        if placeholders then
            for _, asset in ipairs(placeholders:GetChildren()) do
                if base.PurchasedZones[asset.Name] then asset:Destroy() end
            end
        end
    end
    local old = base.Model
    base.Model = model
    model.Parent = basesFolder
    if old then old:Destroy() end
    return true
end
function BaseManager.InitializeBases()
    if initialized then return end
    for index = 1, BaseData.TOTAL_SPOTS do
        local position, pivot = BaseUtils.CalculateSpotTransform(index)
        local base: BaseAssignment = { Player = nil, Index = index, Position = position, CFrame = pivot,
            IsPathway = index == BaseData.PATHWAY_INDEX, Model = nil, LayoutTemplate = nil, Level = 0, PurchasedZones = {} }
        bases[index] = base
        if not base.IsPathway then
            local authored = basesFolder:FindFirstChild("Base_" .. index)
            if authored and authored:IsA("Model") then
                -- Retain the authored layout, including zone CFrames, on assignment/release.
                base.Model = authored
                authored:SetAttribute("PreserveAuthoredBase", true)
                base.CFrame = authored:GetPivot()
                base.Position = base.CFrame.Position
                local clonable = authored.Archivable
                for _, item in ipairs(authored:GetDescendants()) do
                    if not item.Archivable then clonable = false; break end
                end
                if clonable then base.LayoutTemplate = authored:Clone() end
            else updateBaseModel(base, 0) end
        end
    end
    initialized = true
end
function BaseManager.AssignBase(player: Player): number?
    if playerToBase[player] then return playerToBase[player] end
    local profile = Data.GetProfile(player)
    local saved = profile and profile.Base
    if not initialized or not saved or player:GetAttribute("DataReady") ~= true then return nil end
    for index = 1, BaseData.BASE_COUNT do
        local base = bases[index]
        if base and not base.Player then
            base.PurchasedZones = saved.PurchasedZones
            if not updateBaseModel(base, saved.Level) then base.PurchasedZones = {}; continue end
            base.Player = player; base.Level = saved.Level
            playerToBase[player] = index
            local model = base.Model
            if model then model:SetAttribute("BaseOwnerUserId", player.UserId) end
            player:SetAttribute("BaseLevel", saved.Level)
            setupZonePrompts(base)
            return index
        end
    end
    return nil
end
function BaseManager.ReleaseBase(player: Player)
    local base = BaseManager.GetBaseForPlayer(player)
    if base then
        base.Player = nil; base.PurchasedZones = {}; base.Level = 0
        updateBaseModel(base, 0)
    end
    playerToBase[player] = nil; busy[player] = nil
end
function BaseManager.UpgradeBase(player: Player): Result
    return BaseManager.Transaction(player, function()
        local base = BaseManager.GetBaseForPlayer(player)
        local profile = Data.GetProfile(player)
        local state = profile and profile.Base
        if not base or not state then return { Success = false, Message = "Base is not ready." } end
        if not BaseManager.Near(player, base.Position) then return { Success = false, Message = "Return to the center of your base to upgrade." } end
        local nextLevel = Config.BaseLevels[state.Level + 1]
        if not nextLevel then return { Success = false, Message = "Base is at maximum level." } end
        local allowed, reason = BaseManager.CanSpend(player, nextLevel.Cost, 1)
        if not allowed then return { Success = false, Message = reason } end
        if not state.PurchasedZones.Zone1 or not state.PurchasedZones.Zone2
            or state.Forge.Tier < nextLevel.RequiredTier or state.ChargeStation.Tier < nextLevel.RequiredTier then
            return { Success = false, Message = nextLevel.Description .. "." }
        end
        local replaced, failure = replaceOwnedBase(player, base, state.Level + 1)
        if not replaced then return { Success = false, Message = failure } end
        BaseManager.Spend(player, nextLevel.Cost)
        state.Level += 1; base.Level = state.Level
        player:SetAttribute("BaseLevel", state.Level)
        return { Success = true, Message = ("Base upgraded to level %d. Facilities moved to their new zones."):format(state.Level) }
    end)
end
return BaseManager
