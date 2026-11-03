--!strict

-- Layer 3: owns Resources rules and runtime state.
local Spawner = require(script.Parent.ResourcesSpawner)
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Features.Resources.ResourcesConfig)
local Tables = require(game:GetService("ReplicatedStorage").Shared.Features.PlayerData.PlayerDataHelpers)
local Movement = require(script.Parent.ResourcesMovement)
local Service = {}
local carried: { [Player]: { [string]: number } } = {}
local initialized = false
local context: any = nil
function Service.Initialize(dependencies: any)
    if initialized then return end
    Movement.Initialize(function(player)
        local total = 0
        for _, quantity in carried[player] or {} do total += quantity end
        return total
    end)
    Spawner.Initialize()
    initialized = true
    context = dependencies
end
function Service.Destroy()
    for _, player in Players:GetPlayers() do Service.Forget(player) end
    Movement.Destroy()
    Spawner.Destroy()
    table.clear(carried)
    initialized = false
    context = nil
end
-- TODO: Define typed inputs and implement Collect; never report placeholder success.
function Service.Collect(...: any): (boolean, string)
    return false, "NotImplemented: Resources.Collect"
end

-- TODO: Define typed inputs and implement Deposit; never report placeholder success.
function Service.Deposit(...: any): (boolean, string)
    return false, "NotImplemented: Resources.Deposit"
end

-- TODO: Define typed inputs and implement DropCarried; never report placeholder success.
function Service.DropCarried(...: any): (boolean, string)
    return false, "NotImplemented: Resources.DropCarried"
end

-- Session-only carried units. Attributes are projections, never authority.
function Service.GetCarried(player: Player): (boolean, any)
    if not initialized or player.Parent ~= Players then return false, "Unavailable" end
    return true, Tables.DeepCopy(carried[player] or {})
end
function Service.SetCarried(player: Player, quantities: any): (boolean, string?)
    if not initialized or player.Parent ~= Players or player:GetAttribute("DataReady") ~= true then return false, "NotReady" end
    if type(quantities) ~= "table" then return false, "InvalidCarriedResources" end
    local copy, total = {}, 0
    for id, quantity in quantities do
        local definition = Config.Definitions[id]
        if not definition or definition.CollectionMode ~= "Carried" then return false, "UnknownCarriedResource" end
        if type(quantity) ~= "number" or quantity ~= quantity or quantity < 0
            or quantity >= 9007199254740992 or quantity % 1 ~= 0 then return false, "InvalidCarriedQuantity" end
        if quantity > 0 then copy[id] = quantity end
        total += quantity
        if total >= 9007199254740992 then return false, "CarriedQuantityLimit" end
    end
    carried[player] = copy
    player:SetAttribute("CarriedResourceCount", total)
    Movement.Refresh(player)
    return true
end
function Service.Track(player: Player)
    local total = 0; for _, quantity in carried[player] or {} do total += quantity end
    player:SetAttribute("CarriedResourceCount", total)
    Movement.Track(player)
end
function Service.Forget(player: Player)
    Movement.Untrack(player)
    carried[player] = nil
    player:SetAttribute("CarriedResourceCount", nil)
end
-- Server-only operation: resource type and position are selected by the spawner.
function Service.Spawn(zoneId: string): (boolean, any)
    return Spawner.Spawn(zoneId)
end
function Service.Schedule(now: number) Spawner.Schedule(now) end
function Service.Step(now: number) Movement.Step(); Spawner.Step(now) end
return Service
