--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Features.Base.BaseConfig)
local Networking = require(Shared.Features.Networking.NetworkingHelpers)
local Service = require(script.Parent.BaseService)
local Feature = {}
local initialized, started = false, false
local generation = 0
local connections: { RBXScriptConnection } = {}
local listeners: { [Player]: { RBXScriptConnection } } = {}
local last: { [Player]: number } = {}
local lastState: { [Player]: number } = {}
local purchase: RemoteFunction? = nil
local state: RemoteFunction? = nil
local function upgrade(player: Player, expected: any)
    local now = os.clock()
    if last[player] and now - last[player] < Config.RequestIntervalSeconds then return false, "TooManyRequests" end
    last[player] = now
    return Service.PurchaseLevel(player, expected)
end
local function forget(player: Player)
    for _, connection in listeners[player] or {} do connection:Disconnect() end
    listeners[player] = nil; last[player] = nil; lastState[player] = nil
    Service.Release(player)
end
function Feature.Initialize(context: any)
    if initialized then return end
    assert(context.GameConfig.Features.PlayerData and context.GameConfig.Features.Currency and context.GameConfig.Features.Networking, "Base requires PlayerData, Currency and Networking")
    Service.Initialize(context); initialized = true
end
function Feature.Start()
    assert(initialized, "Base not initialized")
    if started then return end
    started = true; generation += 1
    local current = generation
    purchase = Networking.Get("Base.PurchaseLevel") :: RemoteFunction
    state = Networking.Get("Base.GetState") :: RemoteFunction
    purchase.OnServerInvoke = upgrade
    state.OnServerInvoke = function(player)
        local now = os.clock()
        if lastState[player] and now - lastState[player] < Config.RequestIntervalSeconds then return false, "TooManyRequests" end
        lastState[player] = now
        return Service.GetState(player)
    end
    local function joined(player: Player)
        if listeners[player] then return end
        local ownedConnections: { RBXScriptConnection } = {}
        listeners[player] = ownedConnections
        local promptConnection: RBXScriptConnection? = nil
        local function spawnCharacter(character: Model)
            task.spawn(function()
                local part = character:WaitForChild("HumanoidRootPart", 10)
                if part and started and current == generation and listeners[player] == ownedConnections and player.Character == character then
                    Service.SpawnCharacter(player)
                end
            end)
        end
        local function readyChanged()
            if player:GetAttribute("DataReady") ~= true then
                if promptConnection then promptConnection:Disconnect(); promptConnection = nil end
                Service.Release(player)
                return
            end
            local ok, reason = Service.Assign(player)
            if not ok then
                warn("[Base] Assignment failed for " .. player.UserId .. ": " .. tostring(reason))
                player:Kick("Your base could not be assigned safely. Please rejoin.")
                return
            end
            if not promptConnection then
                local prompt = Service.GetUpgradePrompt(player)
                if prompt then
                    promptConnection = prompt.Triggered:Connect(function(visitor)
                        if visitor ~= player then return end
                        local available, data = Service.GetState(player)
                        if available then
                            local accepted, why = upgrade(player, data.Level)
                            player:SetAttribute("BaseUpgradeResult", if accepted then "Upgraded" else tostring(why))
                        end
                    end)
                    table.insert(ownedConnections, promptConnection)
                end
            end
            if player.Character then spawnCharacter(player.Character) end
        end
        table.insert(ownedConnections, player:GetAttributeChangedSignal("DataReady"):Connect(readyChanged))
        table.insert(ownedConnections, player.CharacterAdded:Connect(spawnCharacter))
        readyChanged()
    end
    table.insert(connections, Players.PlayerAdded:Connect(joined))
    table.insert(connections, Players.PlayerRemoving:Connect(forget))
    for _, player in Players:GetPlayers() do joined(player) end
end
function Feature.Destroy()
    started = false; generation += 1
    if purchase then purchase.OnServerInvoke = nil; purchase = nil end
    if state then state.OnServerInvoke = nil; state = nil end
    for _, connection in connections do connection:Disconnect() end
    table.clear(connections)
    local players = {}; for player in listeners do table.insert(players, player) end
    for _, player in players do forget(player) end
    Service.Destroy(); initialized = false
end
return Feature
