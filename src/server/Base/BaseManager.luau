--!strict
-- Runtime plot ownership and placement. Never reposition Zones or replace a base for progression.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage.Shared.BaseConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Data = require(script.Parent.Parent.PlayerData.PlayerDataModule)
local BaseData = require(script.Parent.BaseData)
local BaseUtils = require(script.Parent.BaseUtils)
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
local assetsFolder = ServerStorage:WaitForChild("Assets", 5) or ReplicatedStorage:WaitForChild("Assets")
local baseModelsFolder = assetsFolder:WaitForChild("Base_Models")

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
function BaseManager.GetAssetFolder(name: string): Instance? return assetsFolder:FindFirstChild(name) end
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
    if zone == "Zone1" then return Config.ForgeTiers[if state then state.Forge.Tier else 1].ModelName end
    return Config.ChargeTiers[if state then state.ChargeStation.Tier else 1].ModelName
end
local function place(player: Player, zonePart: BasePart, placed: Instance): boolean
    local config = Config.Zones[zonePart.Name]
    if not config or not config.Available then return false end
    local existing = placed:FindFirstChild(zonePart.Name)
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
local function setupZonePrompts(base: BaseAssignment)
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
                if base.Player ~= player or not BaseManager.Near(player, part.Position) then
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
local function updateBaseModel(base: BaseAssignment, layout: number): boolean
    if base.Model and base.Model:GetAttribute("PreserveAuthoredBase") == true and not base.LayoutTemplate then
        warn("[BaseManager] Authored base is not archivable; cannot safely assign or reset it.")
        return false
    end
    local template = base.LayoutTemplate or baseModelsFolder:FindFirstChild("Base_Level_" .. layout)
        or baseModelsFolder:FindFirstChild("Base_Level_1") or baseModelsFolder:FindFirstChild("Base_Level_0")
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
            if not updateBaseModel(base, 1) then continue end
            base.Player = player; base.Level = saved.Level; base.PurchasedZones = saved.PurchasedZones
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
        BaseManager.Spend(player, nextLevel.Cost)
        state.Level += 1; base.Level = state.Level
        player:SetAttribute("BaseLevel", state.Level)
        return { Success = true, Message = ("Base upgraded to level %d. Facility access is unchanged."):format(state.Level) }
    end)
end
return BaseManager
