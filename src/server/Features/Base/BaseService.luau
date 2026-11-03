--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Features.Base.BaseConfig)
local Currency = require(Shared.Features.Currency.CurrencyHelpers)
local Tables = require(Shared.Features.PlayerData.PlayerDataHelpers)
local PlayerData = require(script.Parent.Parent.PlayerData.PlayerDataService)
local Models = require(script.Parent.BaseModels)
local Service = {}
local initialized = false
local purchasesEnabled = true
local plots: { any } = {}
local templates: { [number]: Model } = {}
local owned: { [Player]: any } = {}
local root: Folder? = nil
local function isLevel(level: any): boolean
    return type(level) == "number" and level % 1 == 0 and level >= Config.StartingLevel and level <= Config.MaxLevel
end
local function eligible(player: Player): (boolean, any)
    if not initialized or player.Parent ~= Players or player:GetAttribute("DataReady") ~= true then return false, "NotReady" end
    return PlayerData.Get(player)
end
function Service.Initialize(_context: any)
    if initialized then return end
    local ok, failure = pcall(function()
        assert(Config.StartingLevel == 1 and isLevel(Config.MaxLevel), "Invalid base level range")
        assert(Config.Count == #Config.Plots and Config.Count > 0, "Base count must equal authored plot count")
        assert(Config.UpgradeDistance > 0 and Config.UpgradeDistance < math.huge, "Invalid upgrade distance")
        assert(Config.RequestIntervalSeconds > 0 and Config.RequestIntervalSeconds < math.huge, "Invalid base request interval")
        for level = Config.StartingLevel, Config.MaxLevel do
            local layout = Config.Layouts[level]
            assert(layout and type(layout.ModelType) == "string" and typeof(layout.SpawnOffset) == "CFrame", "Missing base layout " .. level)
            local template = Models.Load(layout.Asset)
            templates[level] = template
            Models.Validate(template, layout.FloorName)
            if level > Config.StartingLevel then
                local costs = Config.LevelCosts[level]
                assert(type(costs) == "table", "Missing base costs for level " .. level)
                for id, amount in costs do assert(Currency.IsAmount(id, amount, true), "Invalid base cost for level " .. level .. ": " .. tostring(id)) end
            end
        end
        local seen, ids = {}, {}
        for _, definition in Config.Plots do
            assert(type(definition.Id) == "string" and not ids[definition.Id], "Duplicate/invalid base plot ID")
            ids[definition.Id] = true
            local original = Models.Resolve(definition.Path)
            assert(original:IsA("Model") and not seen[original], "Duplicate/invalid authored base plot")
            seen[original] = true
            local floor = original:FindFirstChild("Floor", true)
            assert(floor and floor:IsA("BasePart"), "Authored base plot missing Floor")
            table.insert(plots, { Id = definition.Id, Original = original, Parent = original.Parent, Origin = Models.Origin(floor), Owner = nil })
        end
        Tables.DeepFreeze(Config)
        initialized = true
    end)
    if not ok then Service.Destroy(); error("[Base] " .. tostring(failure), 0) end
end
function Service.Assign(player: Player): (boolean, any)
    local ready, data = eligible(player)
    if not ready then return false, data end
    if owned[player] then return true, owned[player].Id end
    if not isLevel(data.Base.Level) then return false, "UnsupportedSavedBaseLevel" end
    local plot
    for _, candidate in plots do if not candidate.Owner then plot = candidate; break end end
    if not plot then return false, "NoBaseAvailable" end
    local wrapper, structure
    local ok, failure = pcall(function()
        structure = Models.Create(templates[data.Base.Level], Config.Layouts[data.Base.Level], plot.Origin, player, data.Base.Level)
        wrapper = Instance.new("Model")
        wrapper.Name = plot.Id
        wrapper:SetAttribute("OwnerUserId", player.UserId)
        wrapper:SetAttribute("BaseLevel", data.Base.Level)
        structure.Parent = wrapper
        local buildings = Instance.new("Folder"); buildings.Name = "Buildings"; buildings.Parent = wrapper
        local anchor = Instance.new("Part")
        anchor.Name = "UpgradeAnchor"; anchor.Size = Vector3.one; anchor.Transparency = 1
        anchor.Anchored = true; anchor.CanCollide = false; anchor.CanTouch = false; anchor.CanQuery = false
        anchor.CFrame = plot.Origin * CFrame.new(0, 3, 0); anchor.Parent = wrapper
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = "UpgradeBase"; prompt.ActionText = "Upgrade Base"; prompt.ObjectText = "Your Base"
        prompt.MaxActivationDistance = Config.UpgradeDistance; prompt.RequiresLineOfSight = false
        prompt.Enabled = purchasesEnabled and data.Base.Level < Config.MaxLevel; prompt.Parent = anchor
        if not root then root = Instance.new("Folder"); root.Name = "PlayerBases"; root.Parent = workspace end
        wrapper.Parent = root
        plot.Original.Parent = nil
        plot.Owner = player; plot.Wrapper = wrapper; plot.Structure = structure; plot.Prompt = prompt
        plot.Level = data.Base.Level; owned[player] = plot
    end)
    if not ok then
        if wrapper then wrapper:Destroy() elseif structure then structure:Destroy() end
        plot.Original.Parent = plot.Parent
        return false, "BaseAssignmentFailed:" .. tostring(failure)
    end
    return true, plot.Id
end
function Service.GetState(player: Player): (boolean, any)
    local ready, data = eligible(player)
    if not ready then return false, data end
    local plot = owned[player]
    if not plot then return false, "NoOwnedBase" end
    local level = data.Base.Level
    if not isLevel(level) then return false, "UnsupportedSavedBaseLevel" end
    return true, { PlotId = plot.Id, Level = level, MaxLevel = Config.MaxLevel,
        ModelType = plot.Structure:GetAttribute("ModelType"),
        NextCosts = if level < Config.MaxLevel then Tables.DeepCopy(Config.LevelCosts[level + 1]) else nil }
end
function Service.GetUpgradePrompt(player: Player): ProximityPrompt?
    local plot = owned[player]
    return if plot then plot.Prompt else nil
end
function Service.GetPurchasesEnabled(): boolean return purchasesEnabled end
function Service.SetPurchasesEnabled(enabled: boolean): (boolean, string?)
    if not initialized then return false, "Unavailable" end
    if type(enabled) ~= "boolean" then return false, "InvalidRequest" end
    purchasesEnabled = enabled
    for _, plot in plots do
        if plot.Prompt then plot.Prompt.Enabled = enabled and plot.Level < Config.MaxLevel end
    end
    return true
end
-- Admin adapters retain the wrapper, Buildings, prompt instance and saved level.
function Service.GetAdminModelState(plotId: string): any
    for _, plot in plots do
        if plot.Id == plotId then
            local available = plot.Owner ~= nil and plot.Wrapper ~= nil and plot.Wrapper.Parent ~= nil and plot.Structure ~= nil and plot.Structure.Parent == plot.Wrapper
            return { Available = available, Current = if available then plot.Structure:GetAttribute("ModelType") else "Unoccupied", OwnerUserId = if plot.Owner then plot.Owner.UserId else 0, Level = plot.Level or 0 }
        end
    end
    return { Available = false, Current = "Unavailable", OwnerUserId = 0, Level = 0 }
end
function Service.ReplaceAppearance(plotId: string, styleLevel: number): (boolean, string?)
    if not initialized or not isLevel(styleLevel) then return false, "InvalidModel" end
    local plot
    for _, candidate in plots do if candidate.Id == plotId then plot = candidate; break end end
    if not plot or not plot.Owner or not plot.Wrapper or not plot.Wrapper.Parent or not plot.Structure or plot.Structure.Parent ~= plot.Wrapper then return false, "TargetUnavailable" end
    if plot.Busy then return false, "UpgradeBusy" end
    local buildings = plot.Wrapper:FindFirstChild("Buildings")
    if not buildings or #buildings:GetChildren() > 0 then return false, "OccupiedBuildings" end
    plot.Busy = true
    local staged: Model? = nil
    local old = plot.Structure
    local ok, reason = pcall(function()
        staged = Models.Create(templates[styleLevel], Config.Layouts[styleLevel], plot.Origin, plot.Owner, plot.Level)
        -- Complete validation/placement before touching the current model.
        assert(old.Parent == plot.Wrapper and plot.Owner.Parent == Players, "Target changed")
        staged.Parent = plot.Wrapper
        old.Parent = nil
    end)
    if not ok then
        if staged then staged:Destroy() end
        if old.Parent ~= plot.Wrapper then old.Parent = plot.Wrapper end
        plot.Busy = false
        warn("[Admin] Base replacement rejected: " .. tostring(reason))
        return false, "ModelPreparationFailed"
    end
    plot.Structure = staged
    old:Destroy()
    plot.Busy = false
    return true
end
function Service.PurchaseLevel(player: Player, expectedLevel: any): (boolean, string?)
    if not purchasesEnabled then return false, "PurchasesDisabled" end
    local ready, data = eligible(player)
    if not ready then return false, data end
    local plot = owned[player]
    if not plot or plot.Owner ~= player then return false, "NoOwnedBase" end
    if plot.Busy then return false, "UpgradeBusy" end
    if not isLevel(expectedLevel) then return false, "InvalidLevel" end
    if expectedLevel ~= data.Base.Level or expectedLevel ~= plot.Level then return false, "StaleLevel" end
    if expectedLevel >= Config.MaxLevel then return false, "MaxLevel" end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local part = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not part or not part:IsA("BasePart")
        or (part.Position - plot.Origin.Position).Magnitude > Config.UpgradeDistance then return false, "TooFarOrDead" end
    if not plot.Wrapper.Parent or plot.Structure.Parent ~= plot.Wrapper then return false, "BaseUnavailable" end
    local target = expectedLevel + 1
    local affordable, why = Currency.ApplySpend(Tables.DeepCopy(data.Currencies), Config.LevelCosts[target])
    if not affordable then return false, why end
    plot.Busy = true
    local staged: Model? = nil
    local old = plot.Structure
    -- All fallible rendering is staged before committing the profile transaction.
    local prepared, failure = pcall(function()
        staged = Models.Create(templates[target], Config.Layouts[target], plot.Origin, player, target)
    end)
    if not prepared then plot.Busy = false; return false, "ModelPreparationFailed:" .. tostring(failure) end
    local ok, reason = PlayerData.Update(player, function(draft)
        if draft.Base.Level ~= expectedLevel then return false, "StaleLevel" end
        local spent, why = Currency.ApplySpend(draft.Currencies, Config.LevelCosts[target])
        if not spent then return false, why end
        -- No yielding: a failed transaction restores the old structure below.
        staged.Parent = plot.Wrapper
        old.Parent = nil
        draft.Base.Level = target
        -- Buildings and all other saved sections are deliberately left intact.
        return true
    end)
    if not ok then
        staged:Destroy()
        old.Parent = plot.Wrapper
        plot.Busy = false
        return false, reason
    end
    plot.Structure = staged; plot.Level = target
    plot.Wrapper:SetAttribute("BaseLevel", target)
    plot.Prompt.Enabled = purchasesEnabled and target < Config.MaxLevel
    old:Destroy()
    plot.Busy = false
    return true
end
function Service.SpawnCharacter(player: Player): (boolean, string?)
    local ready = eligible(player)
    local plot = owned[player]
    if not ready or not plot then return false, "NoOwnedBase" end
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return false, "CharacterUnavailable" end
    character:PivotTo(plot.Origin * Config.Layouts[plot.Level].SpawnOffset)
    return true
end
function Service.Restore(player: Player): (boolean, any)
    -- Assignment restores the saved level. Runtime upgrades go through PurchaseLevel.
    return Service.Assign(player)
end
function Service.Release(player: Player): boolean
    local plot = owned[player]
    if not plot then return false end
    owned[player] = nil
    if plot.Wrapper then plot.Wrapper:Destroy() end
    plot.Original.Parent = plot.Parent
    plot.Owner = nil; plot.Wrapper = nil; plot.Structure = nil; plot.Prompt = nil; plot.Busy = false
    return true
end
function Service.Destroy()
    local players = {}
    for player in owned do table.insert(players, player) end
    for _, player in players do Service.Release(player) end
    for _, template in templates do template:Destroy() end
    table.clear(templates); table.clear(plots)
    if root then root:Destroy(); root = nil end
    initialized = false
    purchasesEnabled = true
end
function Service.PlaceBuilding(...: any): (boolean, string)
    return false, "NotImplemented: Base.PlaceBuilding"
end
return Service
