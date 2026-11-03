--!strict
-- Private session authority. No persistence, client paths, or arbitrary module calls.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Config = require(script.Parent.AdminConfig)
local Service = {}
local initialized = false
local revision = 0
local signature = ""
local adapters: { [string]: any } = {}
local toggles: { [string]: any } = {}
local targets: { [string]: any } = {}
local confirmations: { [Player]: any } = {}
local results: { [Player]: any } = {}
local lastPrepare: { [Player]: number } = {}
local lastCommit: { [Player]: number } = {}
local lastState: { [Player]: number } = {}
function Service.IsAdmin(player: Player): boolean
    if player.Parent ~= Players then return false end
    if Config.AllowExperienceOwner and game.CreatorType == Enum.CreatorType.User and game.CreatorId > 0 and player.UserId == game.CreatorId then return true end
    return table.find(Config.AdminUserIds, player.UserId) ~= nil
end
local function limited(map: any, player: Player, interval: number): boolean
    local now = os.clock()
    if map[player] and now - map[player] < interval then return true end
    map[player] = now
    return false
end
local function nextId(player: Player): number return if results[player] then results[player].Id + 1 else 1 end
local function snapshot(player: Player): any
    local state: any = { Features = {}, Models = {} }
    local keys = {}
    for _, entry in Config.Toggles do
        local adapter = adapters[entry.Adapter]
        local enabled = if adapter then adapter.Get() else false
        table.insert(state.Features, { Id = entry.Id, Name = entry.Name, Warning = entry.Warning, Supported = adapter ~= nil, Enabled = enabled })
        table.insert(keys, entry.Id .. ":" .. tostring(adapter ~= nil) .. ":" .. tostring(enabled))
    end
    for _, entry in Config.ModelTargets do
        local adapter = adapters[entry.Adapter]
        local current = if adapter then adapter.Get(entry) else { Available = false, Current = "Unavailable", OwnerUserId = 0, Level = 0 }
        local options = {}
        for _, option in entry.Options do table.insert(options, { Id = option.Id, Name = option.Name }) end
        table.insert(state.Models, { Id = entry.Id, Name = entry.Name, Available = current.Available, Current = current.Current, OwnerUserId = current.OwnerUserId, Level = current.Level, Options = options })
        table.insert(keys, entry.Id .. ":" .. tostring(current.Available) .. ":" .. tostring(current.Current) .. ":" .. current.OwnerUserId .. ":" .. current.Level)
    end
    local newSignature = table.concat(keys, "|")
    if newSignature ~= signature then signature = newSignature; revision += 1 end
    state.Revision = revision
    state.NextRequestId = nextId(player)
    return state
end
function Service.Initialize(context: any)
    if initialized then return end
    assert(Config.RequestIntervalSeconds > 0 and Config.StateIntervalSeconds > 0 and Config.ConfirmationLifetimeSeconds > 0, "Invalid Admin timings")
    for _, id in Config.AdminUserIds do assert(type(id) == "number" and id > 0 and id < math.huge and id % 1 == 0, "Invalid admin user ID") end
    local features = context.GameConfig.Features
    if features.Resources then
        local spawner = require(script.Parent.Parent.Resources.ResourcesSpawner)
        adapters.ResourceGeneration = { Get = spawner.GetGenerationEnabled, Set = spawner.SetGenerationEnabled }
    end
    if features.Inventory then
        local inventory = require(script.Parent.Parent.Inventory.InventoryService)
        adapters.InventorySelling = { Get = inventory.GetSalesEnabled, Set = inventory.SetSalesEnabled }
    end
    if features.Base then
        local base = require(script.Parent.Parent.Base.BaseService)
        adapters.BasePurchases = { Get = base.GetPurchasesEnabled, Set = base.SetPurchasesEnabled }
        adapters.BaseStructure = { Get = function(entry) return base.GetAdminModelState(entry.PlotId) end, Set = function(entry, option) return base.ReplaceAppearance(entry.PlotId, option.Level) end }
    end
    local known = { ResourceGeneration = true, InventorySelling = true, BasePurchases = true, BaseStructure = true }
    for _, entry in Config.Toggles do
        assert(type(entry.Id) == "string" and not toggles[entry.Id] and known[entry.Adapter] and entry.Adapter ~= "BaseStructure", "Invalid admin toggle")
        toggles[entry.Id] = entry
    end
    for _, entry in Config.ModelTargets do
        assert(type(entry.Id) == "string" and not targets[entry.Id] and entry.Adapter == "BaseStructure" and type(entry.PlotId) == "string" and #entry.Options > 0, "Invalid admin target")
        local seen = {}
        for _, option in entry.Options do
            assert(type(option.Id) == "string" and not seen[option.Id] and type(option.Level) == "number" and option.Level % 1 == 0, "Invalid admin model option")
            seen[option.Id] = true
        end
        targets[entry.Id] = entry
    end
    initialized = true
end
function Service.GetState(player: Player): (boolean, any)
    if not Service.IsAdmin(player) then return false, "Forbidden" end
    if not initialized then return false, "Unavailable" end
    if limited(lastState, player, Config.StateIntervalSeconds) then return false, "RateLimited" end
    return true, snapshot(player)
end
local function validText(value: any): boolean return type(value) == "string" and #value > 0 and #value <= 100 end
function Service.Prepare(player: Player, kind: any, id: any, value: any, expectedRevision: any): (boolean, any)
    if not Service.IsAdmin(player) then return false, "Forbidden" end
    if not initialized or player:GetAttribute("DataReady") ~= true then return false, "NotReady" end
    if limited(lastPrepare, player, Config.RequestIntervalSeconds) then return false, "RateLimited" end
    if not validText(id) or (kind ~= "Toggle" and kind ~= "Model") or type(expectedRevision) ~= "number" then return false, "InvalidRequest" end
    local state = snapshot(player)
    if expectedRevision ~= state.Revision then return false, "StaleState" end
    local entry, option, description
    if kind == "Toggle" then
        entry = toggles[id]
        if not entry or type(value) ~= "boolean" then return false, "InvalidRequest" end
        if not adapters[entry.Adapter] then return false, "Unsupported" end
        if adapters[entry.Adapter].Get() == value then return false, "AlreadySet" end
        description = (if value then "Enable " else "Disable ") .. entry.Name .. "? " .. entry.Warning
    else
        entry = targets[id]
        if not entry or not validText(value) then return false, "InvalidRequest" end
        if not adapters[entry.Adapter] then return false, "Unsupported" end
        for _, candidate in entry.Options do if candidate.Id == value then option = candidate; break end end
        if not option then return false, "UnapprovedModel" end
        local current = adapters[entry.Adapter].Get(entry)
        if not current.Available then return false, "TargetUnavailable" end
        if current.Current == value then return false, "AlreadySet" end
        description = "Replace " .. entry.Name .. " with " .. option.Name .. "? Players standing on it may be disrupted. Saved level is unchanged; a normal upgrade or rejoin restores the progression style. Bases with buildings cannot be swapped."
    end
    local token = HttpService:GenerateGUID(false)
    confirmations[player] = { Token = token, Kind = kind, Entry = entry, Value = value, Option = option, Revision = revision, Expires = os.clock() + Config.ConfirmationLifetimeSeconds }
    return true, { Token = token, Description = description, RequestId = nextId(player) }
end
function Service.Commit(player: Player, token: any, requestId: any): (boolean, string)
    if not Service.IsAdmin(player) then return false, "Forbidden" end
    if not initialized or player:GetAttribute("DataReady") ~= true then return false, "NotReady" end
    if not validText(token) or type(requestId) ~= "number" or requestId < 1 or requestId >= 9007199254740992 or requestId % 1 ~= 0 then return false, "InvalidRequest" end
    local prior = results[player]
    if prior and prior.Id == requestId then
        if prior.Token ~= token then return false, "RequestIdConflict" end
        return prior.Ok, prior.Code
    end
    if requestId ~= nextId(player) then return false, "StaleRequest" end
    if limited(lastCommit, player, Config.RequestIntervalSeconds) then return false, "RateLimited" end
    local pending = confirmations[player]
    local function finish(ok: boolean, code: string): (boolean, string)
        results[player] = { Id = requestId, Token = token, Ok = ok, Code = code }
        confirmations[player] = nil
        return ok, code
    end
    if not pending or pending.Token ~= token then return finish(false, "InvalidConfirmation") end
    if os.clock() > pending.Expires then return finish(false, "ConfirmationExpired") end
    snapshot(player) -- Detect ordinary upgrades, joins/releases, or another admin's changes.
    if pending.Revision ~= revision then return finish(false, "StaleState") end
    local adapter = adapters[pending.Entry.Adapter]
    local transported, accepted, reason = pcall(function()
        if pending.Kind == "Toggle" then return adapter.Set(pending.Value) end
        return adapter.Set(pending.Entry, pending.Option)
    end)
    if not transported then warn("[Admin] Adapter failed: " .. tostring(accepted)); return finish(false, "ActionFailed") end
    if not accepted then return finish(false, tostring(reason)) end
    snapshot(player)
    return finish(true, "Applied")
end
function Service.Forget(player: Player)
    confirmations[player] = nil; results[player] = nil; lastPrepare[player] = nil; lastCommit[player] = nil; lastState[player] = nil
end
function Service.Destroy()
    table.clear(adapters); table.clear(toggles); table.clear(targets); table.clear(confirmations); table.clear(results)
    table.clear(lastPrepare); table.clear(lastCommit); table.clear(lastState)
    initialized = false; signature = ""; revision = 0
end
return Service
