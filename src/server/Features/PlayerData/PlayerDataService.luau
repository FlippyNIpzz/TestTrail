--!strict
-- Layer 3: owns profile admission and transactions. Never replicate these profiles.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Features.PlayerData.PlayerDataConfig)
local Helpers = require(Shared.Features.PlayerData.PlayerDataHelpers)
local Schema = require(script.Parent.PlayerDataSchema)
local Service = {}
local sessions: { [Player]: any } = {}
local loading: { [Player]: boolean } = {}
local failures: { [string]: number } = {}
local connections: { any } = {}
local memory: { [string]: any } = {}
local store: any = nil
local library: any = nil
local initialized, closing, persistent = false, false, false
local generation = 0

local function status(player: Player, value: string)
    player:SetAttribute("DataStatus", value)
end

function Service.Initialize(_context: any)
    if initialized then return end
    assert(Config.StudioStorageMode == "Memory" or Config.StudioStorageMode == "Persistent", "Invalid StudioStorageMode")
    assert(Config.AutoSaveSeconds > 0 and Config.SessionWaitSeconds > 0 and Config.SessionWaitSeconds < 40, "Invalid persistence timing")
    persistent = not RunService:IsStudio() or Config.StudioStorageMode == "Persistent"
    closing = false
    generation += 1
    if persistent then
        library = require(script.Parent.Vendor.ProfileStore)
        library.SetConstant("AUTO_SAVE_PERIOD", Config.AutoSaveSeconds)
        -- Bound acquisition before ProfileStore's forced takeover interval.
        library.SetConstant("SESSION_STEAL", 1000000000)
        local deadline = os.clock() + Config.StorageReadySeconds
        while library.DataStoreState == "NotReady" and os.clock() < deadline do task.wait(0.1) end
        assert(library.DataStoreState == "Access", "Persistent storage unavailable; refusing memory fallback")
        local name = if RunService:IsStudio() then Config.DevelopmentStore else Config.LiveStore
        assert(Config.DevelopmentStore ~= Config.LiveStore, "Development and live namespaces must differ")
        store = library.New(name, Schema.New())
        table.insert(connections, library.OnError:Connect(function(message: string, storeName: string, key: string)
            if storeName ~= name then return end
            failures[key] = (failures[key] or 0) + 1
            warn("[PlayerData] Storage error: " .. message)
            for player, session in sessions do
                if session.key == key then
                    status(player, "SaveFailed")
                    -- Retain live data; retry with bounded exponential backoff.
                    if not session.retrying and not session.releasing then
                        session.retrying = true
                        task.spawn(function()
                            local delaySeconds = Config.SaveRetryInitialSeconds
                            while sessions[player] == session and not closing and not session.releasing do
                                task.wait(delaySeconds)
                                if sessions[player] ~= session or session.releasing or closing then break end
                                if player:GetAttribute("DataStatus") ~= "SaveFailed" then break end
                                Service.Save(player)
                                delaySeconds = math.min(delaySeconds * 2, Config.SaveRetryMaxSeconds)
                            end
                            session.retrying = false
                        end)
                    end
                end
            end
        end))
        print("[PlayerData] Persistent storage: " .. name)
    else
        print("[PlayerData] MEMORY storage: progress is not durable and resets when this server stops.")
    end
    initialized = true
end

function Service.Load(player: Player): (boolean, string?)
    if not initialized or closing then return false, "Unavailable" end
    if sessions[player] then return true end
    if loading[player] then return false, "AlreadyLoading" end
    loading[player] = true
    local current = generation
    status(player, "Loading")
    local key = "Player_" .. tostring(player.UserId)
    local profile: any = nil
    local rejection: string? = nil
    if persistent then
        failures[key] = 0
        local deadline = os.clock() + Config.SessionWaitSeconds
        local ok, result = pcall(function()
            return store:StartSessionAsync(key, {
                ErrorRetryDelays = Config.LoadRetryDelays,
                Cancel = function()
                    return closing or current ~= generation or player.Parent ~= Players or os.clock() >= deadline
                        or (failures[key] or 0) >= Config.LoadAttempts or rejection ~= nil
                end,
                ValidateData = function(raw: any)
                    local valid, reason = Schema.Prepare(raw)
                    if not valid then rejection = tostring(reason); error(rejection) end
                end,
            })
        end)
        if ok then profile = result else rejection = tostring(result) end
    end
    if closing or current ~= generation or player.Parent ~= Players then
        if profile then profile:EndSession() end
        loading[player] = nil
        return false, "Cancelled"
    end
    if persistent and not profile then
        loading[player] = nil
        failures[key] = nil
        status(player, "Unavailable")
        return false, rejection or "StorageUnavailableOrSessionLocked"
    end
    local raw = if profile then profile.Data else memory[key] or Schema.New()
    local valid, data, resets = Schema.Prepare(raw)
    if not valid then
        if profile then profile:EndSession() end
        loading[player] = nil
        status(player, "Unavailable")
        return false, tostring(data)
    end
    if profile then profile.Data = data; profile:AddUserId(player.UserId) end
    local session = { key = key, data = data, profile = profile, releasing = false, updating = false, retrying = false, savePending = false, connections = {} }
    sessions[player] = session
    if profile then
        table.insert(session.connections, profile.OnSessionEnd:Connect(function()
            if sessions[player] ~= session or session.releasing then return end
            sessions[player] = nil
            player:SetAttribute("DataReady", false)
            status(player, "Unavailable")
            for _, connection in session.connections do connection:Disconnect() end
            if player.Parent == Players then player:Kick("Your data session ended. Please rejoin to keep your progress safe.") end
        end))
        table.insert(session.connections, profile.OnAfterSave:Connect(function()
            session.savePending = false
            if sessions[player] == session and not session.releasing and profile:IsActive() then status(player, "Ready") end
        end))
    end
    if resets and #resets > 0 then warn("[PlayerData] Reset invalid sections for " .. key .. ": " .. table.concat(resets, ", ")) end
    loading[player] = nil
    player:SetAttribute("DataReady", true)
    status(player, "Ready")
    return true
end

-- Returns a copy: callers cannot mutate authoritative state through a retained reference.
function Service.Get(player: Player): (boolean, any)
    local session = sessions[player]
    if not session or session.releasing then return false, "NotReady" end
    return true, Helpers.DeepCopy(session.data)
end

-- Mutator runs without yielding on a working copy; false cancels. No storage writes.
function Service.Update(player: Player, mutator: (any) -> (boolean?, string?)): (boolean, string?)
    local session = sessions[player]
    if not session or session.releasing then return false, "NotReady" end
    if session.updating then return false, "TransactionBusy" end
    if session.profile and not session.profile:IsActive() then return false, "SessionLost" end
    session.updating = true
    local candidate = Helpers.DeepCopy(session.data)
    local thread = coroutine.create(mutator)
    local ok, accepted, reason = coroutine.resume(thread, candidate)
    local yielded = coroutine.status(thread) ~= "dead"
    if yielded then coroutine.close(thread) end
    session.updating = false
    if not ok then warn(accepted); return false, "TransactionFailed" end
    if yielded then return false, "TransactionMustNotYield" end
    if accepted == false then return false, reason or "TransactionRejected" end
    if sessions[player] ~= session or session.releasing then return false, "SessionLost" end
    if session.profile and not session.profile:IsActive() then return false, "SessionLost" end
    local valid, normalized, resets = Schema.Prepare(candidate)
    if not valid or (resets and #resets > 0) then return false, "InvalidTransaction" end
    session.data = normalized
    if session.profile then session.profile.Data = normalized end
    return true
end

-- Success means queued, not confirmed durable. OnAfterSave confirms completion.
function Service.Save(player: Player): (boolean, string?)
    local session = sessions[player]
    if not session or session.releasing then return false, "NotReady" end
    if not persistent then memory[session.key] = Helpers.DeepCopy(session.data); return true, "MemoryOnly" end
    if not session.profile:IsActive() then return false, "SessionLost" end
    if session.savePending then return true, "AlreadyQueued" end
    session.savePending = true
    session.profile:Save()
    -- ProfileStore saves asynchronously; allow retry if it fails without OnAfterSave.
    task.delay(Config.SaveRetryInitialSeconds, function() session.savePending = false end)
    return true, "Queued"
end

function Service.Release(player: Player): (boolean, string?)
    local session = sessions[player]
    if not session or session.releasing then return false, "NotReady" end
    session.releasing = true
    player:SetAttribute("DataReady", false)
    for _, connection in session.connections do connection:Disconnect() end
    sessions[player] = nil
    failures[session.key] = nil
    if session.profile then session.profile:EndSession()
    else memory[session.key] = Helpers.DeepCopy(session.data) end
    return true
end

function Service.Destroy()
    closing = true
    generation += 1
    for player in sessions do Service.Release(player) end
    for _, connection in connections do connection:Disconnect() end
    table.clear(connections)
    table.clear(memory)
    initialized = false
end
return Service
