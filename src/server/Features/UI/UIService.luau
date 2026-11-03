--!strict
-- Explicit economy projection: never send the profile or hidden unique properties.
local Shared = game:GetService("ReplicatedStorage").Shared
local CurrencyConfig = require(Shared.Features.Currency.CurrencyConfig)
local InventoryConfig = require(Shared.Features.Inventory.InventoryConfig)
local Rules = require(Shared.Features.Inventory.InventoryHelpers)
local Inventory = require(script.Parent.Parent.Inventory.InventoryService)
local PlayerData = require(script.Parent.Parent.PlayerData.PlayerDataService)
local Service = {}
local initialized = false
function Service.Initialize(_context: any) initialized = true end
function Service.Destroy() initialized = false end
function Service.GetVisibleState(player: Player): (boolean, any)
    if not initialized then return false, "Unavailable" end
    local ok, data = PlayerData.Get(player)
    if not ok then return false, data end
    local balances, stacks, unique = {}, {}, {}
    for id, definition in CurrencyConfig.Definitions do
        table.insert(balances, { Id = id, Name = definition.DisplayName, Amount = data.Currencies[id] or 0 })
    end
    for id, amount in data.Inventory.Stacks do
        local definition = InventoryConfig.Definitions[id]
        if definition and amount > 0 then
            local sale = definition.Sell
            table.insert(stacks, { Id = id, Name = definition.DisplayName, Quantity = amount,
                UnitPrice = if sale then sale.UnitPrice else nil,
                CurrencyId = if sale then sale.CurrencyId else nil,
                CurrencyName = if sale then CurrencyConfig.Definitions[sale.CurrencyId].DisplayName else nil })
        end
    end
    for instanceId, item in data.Inventory.Unique do
        local definition = InventoryConfig.Definitions[item.DefinitionId]
        if definition then table.insert(unique, { InstanceId = instanceId, Id = item.DefinitionId, Name = definition.DisplayName }) end
    end
    local function byId(a, b) return a.Id < b.Id end
    table.sort(balances, byId); table.sort(stacks, byId)
    table.sort(unique, function(a, b) return a.InstanceId < b.InstanceId end)
    local units, uniqueCount = Rules.Count(data.Inventory)
    return true, { Balances = balances, Stacks = stacks, Unique = unique,
        StackUnits = units, MaxStackUnits = InventoryConfig.MaxStackUnits,
        UniqueCount = uniqueCount, MaxUniqueItems = InventoryConfig.MaxUniqueItems,
        NextSellRequestId = Inventory.GetNextSellRequestId(player), MaxSellQuantity = InventoryConfig.MaxRequestQuantity }
end
return Service
