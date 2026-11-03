--!strict
-- Pure currency rules; operate on a transaction's draft balances, never storage.
local Config = require(script.Parent.CurrencyConfig)
local TableHelpers = require(script.Parent.Parent.PlayerData.PlayerDataHelpers)
local Helpers = {}
local MAX_SAFE = 9007199254740991
function Helpers.IsAmount(id: any, amount: any, allowZero: boolean?): boolean
    local definition = if type(id) == "string" then Config.Definitions[id] else nil
    if not definition or type(amount) ~= "number" or amount ~= amount or amount == math.huge
        or amount < 0 or (amount == 0 and not allowZero) then return false end
    local scaled = amount * 10 ^ definition.Precision
    return scaled <= MAX_SAFE and (scaled >= 1 or (allowZero == true and amount == 0)) and math.abs(scaled - math.round(scaled)) < 0.000001
end
function Helpers.ValidateConfig()
    for id, definition in Config.Definitions do
        assert(type(id) == "string" and id:match("^currency%.[a-z][a-z0-9_]*$"), "Invalid currency ID: " .. tostring(id))
        assert(type(definition.DisplayName) == "string", "Missing currency name: " .. id)
        assert(type(definition.Precision) == "number" and definition.Precision % 1 == 0 and definition.Precision >= 0 and definition.Precision <= 6, "Invalid currency precision: " .. id)
        assert(Helpers.IsAmount(id, definition.StartingBalance, true), "Invalid starting balance: " .. id)
    end
    TableHelpers.DeepFreeze(Config)
end
function Helpers.ApplyGrant(balances: any, id: any, amount: any): (boolean, string?)
    if not Helpers.IsAmount(id, amount) then return false, "InvalidAmount" end
    local old = balances[id] or 0
    local nextBalance = old + amount
    if not Helpers.IsAmount(id, nextBalance, true) then return false, "BalanceLimit" end
    balances[id] = math.round(nextBalance * 10 ^ Config.Definitions[id].Precision) / 10 ^ Config.Definitions[id].Precision
    return true
end
-- Validate every cost before any deduction. Empty costs support free purchases.
function Helpers.ApplySpend(balances: any, costs: any): (boolean, string?)
    if type(costs) ~= "table" then return false, "InvalidCosts" end
    for id, amount in costs do
        if not Helpers.IsAmount(id, amount, true) then return false, "InvalidCosts" end
        if (balances[id] or 0) < amount then return false, "InsufficientFunds" end
    end
    for id, amount in costs do
        local scale = 10 ^ Config.Definitions[id].Precision
        balances[id] = math.round(((balances[id] or 0) - amount) * scale) / scale
    end
    return true
end
return Helpers
