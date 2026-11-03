--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Networking = require(Shared.Features.Networking.NetworkingHelpers)
local UIConfig = require(Shared.Features.UI.UIConfig)
local Service = require(script.Parent.InventoryService)
local Feature = {}
local initialized, started = false, false
local remote: RemoteFunction? = nil
local removing: RBXScriptConnection? = nil
local last: { [Player]: number } = {}
function Feature.Initialize(context: any)
    if initialized then return end
    assert(context.GameConfig.Features.Networking and context.GameConfig.Features.PlayerData and context.GameConfig.Features.Currency, "Inventory requires Networking, PlayerData, Currency")
    assert(UIConfig.SellRequestInterval > 0, "Invalid sell request timing")
    Service.Initialize(context); initialized = true
end
function Feature.Start()
    assert(initialized, "Inventory not initialized")
    if started then return end
    remote = Networking.Get("Inventory.Sell") :: RemoteFunction
    remote.OnServerInvoke = function(player: Player, itemId: any, quantity: any, requestId: any)
        local now = os.clock()
        if last[player] and now - last[player] < UIConfig.SellRequestInterval then return false, "TooManyRequests" end
        last[player] = now
        return Service.Sell(player, itemId, quantity, requestId)
    end
    removing = Players.PlayerRemoving:Connect(function(player) last[player] = nil; Service.Forget(player) end)
    started = true
end
function Feature.Destroy()
    if remote then remote.OnServerInvoke = nil; remote = nil end
    if removing then removing:Disconnect(); removing = nil end
    table.clear(last); Service.Destroy(); initialized = false; started = false
end
return Feature
