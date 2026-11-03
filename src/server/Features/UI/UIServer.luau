--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Networking = require(Shared.Features.Networking.NetworkingHelpers)
local Config = require(Shared.Features.UI.UIConfig)
local Service = require(script.Parent.UIService)
local Feature = {}
local initialized, started = false, false
local remote: RemoteFunction? = nil
local removing: RBXScriptConnection? = nil
local last: { [Player]: number } = {}
function Feature.Initialize(context: any)
    if initialized then return end
    assert(context.GameConfig.Features.Networking and context.GameConfig.Features.PlayerData and context.GameConfig.Features.Currency and context.GameConfig.Features.Inventory, "UI requires Networking, PlayerData, Currency, Inventory")
    assert(Config.StateRequestInterval > 0 and Config.EconomyRefreshSeconds >= Config.StateRequestInterval, "Invalid UI request timing")
    Service.Initialize(context); initialized = true
end
function Feature.Start()
    assert(initialized, "UI not initialized")
    if started then return end
    remote = Networking.Get("UI.GetState") :: RemoteFunction
    remote.OnServerInvoke = function(player: Player)
        local now = os.clock()
        if last[player] and now - last[player] < Config.StateRequestInterval then return false, "TooManyRequests" end
        last[player] = now
        return Service.GetVisibleState(player)
    end
    removing = Players.PlayerRemoving:Connect(function(player) last[player] = nil end)
    started = true
end
function Feature.Destroy()
    if remote then remote.OnServerInvoke = nil; remote = nil end
    if removing then removing:Disconnect(); removing = nil end
    table.clear(last); Service.Destroy(); initialized = false; started = false
end
return Feature
