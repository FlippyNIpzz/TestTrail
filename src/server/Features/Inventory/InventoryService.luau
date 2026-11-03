--!strict
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Features.Inventory.InventoryConfig)
local Rules = require(Shared.Features.Inventory.InventoryHelpers)
local CurrencyRules = require(Shared.Features.Currency.CurrencyHelpers)
local PlayerData = require(script.Parent.Parent.PlayerData.PlayerDataService)
local Service = {}
local initialized = false
local salesEnabled = true
local requests: { [Player]: any } = {}
function Service.Initialize(_context: any) Rules.ValidateConfig(); initialized = true end
function Service.Forget(player: Player) requests[player] = nil end
function Service.Destroy() table.clear(requests); salesEnabled = true; initialized = false end
function Service.GetSalesEnabled(): boolean return salesEnabled end
function Service.SetSalesEnabled(enabled: boolean): (boolean, string?)
    if not initialized then return false, "Unavailable" end
    if type(enabled) ~= "boolean" then return false, "InvalidRequest" end
    salesEnabled = enabled
    return true
end
function Service.GetInventory(player: Player): (boolean, any)
    if not initialized then return false, "Unavailable" end
    local ok, data = PlayerData.Get(player)
    if not ok then return false, data end
    return true, data.Inventory
end
function Service.Grant(player: Player, id: string, quantity: number, properties: any): (boolean, string?)
    if not initialized then return false, "Unavailable" end
    local definition = if type(id) == "string" then Config.Definitions[id] else nil
    if not definition then return false, "UnknownItem" end
    local instanceId = if definition.Kind == "Unique" then HttpService:GenerateGUID(false) else nil
    local ok, reason = PlayerData.Update(player, function(data)
        return Rules.ApplyGrant(data.Inventory, id, quantity, instanceId, properties)
    end)
    return ok, if ok then instanceId else reason
end
function Service.Remove(player: Player, id: string, quantity: number): (boolean, string?)
    if not initialized then return false, "Unavailable" end
    return PlayerData.Update(player, function(data) return Rules.ApplyRemove(data.Inventory, id, quantity) end)
end
function Service.Has(player: Player, id: string, quantity: number): (boolean, any)
    if type(id) ~= "string" or not Rules.IsQuantity(quantity) then return false, "InvalidQuantity" end
    local ok, inventory = Service.GetInventory(player)
    if not ok then return false, inventory end
    if inventory.Unique[id] then return true, quantity == 1 end
    local definition = Config.Definitions[id]
    if not definition or definition.Kind ~= "Stackable" then return false, "UnknownItem" end
    return true, (inventory.Stacks[id] or 0) >= quantity
end
function Service.GetNextSellRequestId(player: Player): number
    local previous = requests[player]
    return if previous then previous.id + 1 else 1
end
-- Sequential request IDs prevent replay even after old result details are discarded.
-- Only the last response is cached; older IDs are permanently stale for this session.
function Service.Sell(player: Player, id: any, quantity: any, requestId: any): (boolean, string?)
    if not initialized then return false, "Unavailable" end
    if not Rules.IsQuantity(requestId) or not Rules.IsQuantity(quantity) or quantity > Config.MaxRequestQuantity
        or type(id) ~= "string" or #id > 128 then return false, "InvalidRequest" end
    local previous = requests[player]
    if previous and requestId == previous.id then
        if id ~= previous.item or quantity ~= previous.quantity then return false, "RequestIdConflict" end
        return previous.ok, previous.reason
    end
    if not salesEnabled then return false, "SellingDisabled" end
    if requestId ~= Service.GetNextSellRequestId(player) then return false, "StaleRequest" end
    local definition = Config.Definitions[id]
    local ok, reason = false, "NotSellable"
    if definition and definition.Sell and definition.Kind == "Stackable" then
        local sale = definition.Sell
        local reward = sale.UnitPrice * quantity
        if CurrencyRules.IsAmount(sale.CurrencyId, reward) then
            ok, reason = PlayerData.Update(player, function(data)
                local removed, failure = Rules.ApplyRemove(data.Inventory, id, quantity)
                if not removed then return false, failure end
                return CurrencyRules.ApplyGrant(data.Currencies, sale.CurrencyId, reward)
            end)
        else reason = "InvalidSaleValue" end
    end
    requests[player] = { id = requestId, item = id, quantity = quantity, ok = ok, reason = reason }
    return ok, reason
end
return Service
