--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Features.Currency.CurrencyConfig)
local Rules = require(Shared.Features.Currency.CurrencyHelpers)
local PlayerData = require(script.Parent.Parent.PlayerData.PlayerDataService)
local Service = {}
local initialized = false
function Service.Initialize(_context: any) Rules.ValidateConfig(); initialized = true end
function Service.Destroy() initialized = false end
function Service.GetBalance(player: Player, id: string): (boolean, any)
    if not initialized then return false, "Unavailable" end
    if type(id) ~= "string" or not Config.Definitions[id] then return false, "UnknownCurrency" end
    local ok, data = PlayerData.Get(player)
    if not ok then return false, data end
    return true, data.Currencies[id] or 0
end
function Service.Grant(player: Player, id: string, amount: number): (boolean, string?)
    if not initialized then return false, "Unavailable" end
    return PlayerData.Update(player, function(data) return Rules.ApplyGrant(data.Currencies, id, amount) end)
end
function Service.Spend(player: Player, costs: { [string]: number }): (boolean, string?)
    if not initialized then return false, "Unavailable" end
    return PlayerData.Update(player, function(data) return Rules.ApplySpend(data.Currencies, costs) end)
end
return Service
