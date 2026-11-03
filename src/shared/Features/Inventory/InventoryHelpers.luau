--!strict
-- Pure inventory operations on transaction drafts. Server creates unique instance IDs.
local Config = require(script.Parent.InventoryConfig)
local CurrencyHelpers = require(script.Parent.Parent.Currency.CurrencyHelpers)
local TableHelpers = require(script.Parent.Parent.PlayerData.PlayerDataHelpers)
local Helpers = {}
function Helpers.IsQuantity(value: any, allowZero: boolean?): boolean
    return type(value) == "number" and value == value and value < 9007199254740992
        and value % 1 == 0 and (value > 0 or (allowZero == true and value == 0))
end
function Helpers.ValidateProperties(definition: any, properties: any): (boolean, any)
    if type(properties) ~= "table" then return false, "InvalidProperties" end
    local result = {}
    local rules = definition.Properties or {}
    for key in properties do if rules[key] == nil then return false, "UnknownProperty" end end
    for key, rule in rules do
        local value = properties[key]
        if value == nil then value = rule.Default end
        if type(value) ~= rule.Type then return false, "InvalidProperty:" .. key end
        if rule.Type == "number" and (value ~= value or math.abs(value) == math.huge or value < rule.Min or value > rule.Max) then return false, "InvalidProperty:" .. key end
        if rule.Type == "string" and #value > rule.MaxLength then return false, "InvalidProperty:" .. key end
        result[key] = value
    end
    return true, result
end
function Helpers.ValidateConfig()
    assert(Helpers.IsQuantity(Config.MaxStackUnits, true), "Invalid MaxStackUnits")
    assert(Helpers.IsQuantity(Config.MaxUniqueItems, true), "Invalid MaxUniqueItems")
    assert(Helpers.IsQuantity(Config.MaxRequestQuantity), "Invalid MaxRequestQuantity")
    for id, definition in Config.Definitions do
        assert(type(id) == "string" and id:match("^[a-z][a-z0-9_]*%.[a-z][a-z0-9_]*$"), "Invalid inventory ID: " .. tostring(id))
        assert(type(definition.DisplayName) == "string", "Missing item name: " .. id)
        assert(definition.Kind == "Stackable" or definition.Kind == "Unique", "Invalid item kind: " .. id)
        for name, rule in definition.Properties or {} do
            assert(definition.Kind == "Unique" and type(name) == "string", "Properties require unique items: " .. id)
            assert(rule.Type == "number" or rule.Type == "string" or rule.Type == "boolean", "Invalid property type: " .. id .. "." .. name)
            if rule.Type == "number" then
                assert(type(rule.Min) == "number" and type(rule.Max) == "number" and rule.Min == rule.Min and rule.Max == rule.Max and math.abs(rule.Min) < math.huge and math.abs(rule.Max) < math.huge and rule.Min <= rule.Max, "Invalid property range: " .. id)
            elseif rule.Type == "string" then assert(Helpers.IsQuantity(rule.MaxLength, true), "Invalid property length: " .. id) end
        end
        assert(Helpers.ValidateProperties(definition, {}), "Invalid property defaults: " .. id)
        if definition.Sell then
            assert(definition.Kind == "Stackable", "Unique sales require a game-specific policy: " .. id)
            assert(CurrencyHelpers.IsAmount(definition.Sell.CurrencyId, definition.Sell.UnitPrice), "Invalid sale price: " .. id)
        end
    end
    TableHelpers.DeepFreeze(Config)
end
function Helpers.Count(inventory: any): (number, number)
    local units, unique = 0, 0
    for _, quantity in inventory.Stacks do units += quantity end
    for _ in inventory.Unique do unique += 1 end
    return units, unique
end
function Helpers.Validate(inventory: any): boolean
    if type(inventory) ~= "table" or type(inventory.Stacks) ~= "table" or type(inventory.Unique) ~= "table" then return false end
    for id, amount in inventory.Stacks do
        local definition = Config.Definitions[id]
        if not definition or definition.Kind ~= "Stackable" or not Helpers.IsQuantity(amount, true) then return false end
    end
    for id, item in inventory.Unique do
        if type(id) ~= "string" or #id == 0 or type(item) ~= "table" then return false end
        local definition = Config.Definitions[item.DefinitionId]
        if not definition or definition.Kind ~= "Unique" or not Helpers.ValidateProperties(definition, item.Properties) then return false end
    end
    local units, unique = Helpers.Count(inventory)
    return units <= Config.MaxStackUnits and unique <= Config.MaxUniqueItems
end
function Helpers.ApplyGrant(inventory: any, id: any, quantity: any, instanceId: string?, properties: any): (boolean, string?)
    local definition = if type(id) == "string" then Config.Definitions[id] else nil
    if not definition then return false, "UnknownItem" end
    if not Helpers.IsQuantity(quantity) then return false, "InvalidQuantity" end
    local units, unique = Helpers.Count(inventory)
    if definition.Kind == "Stackable" then
        if properties ~= nil or instanceId ~= nil then return false, "StackPropertiesNotSupported" end
        if quantity > Config.MaxStackUnits - units then return false, "InventoryFull" end
        inventory.Stacks[id] = (inventory.Stacks[id] or 0) + quantity
    else
        if quantity ~= 1 or type(instanceId) ~= "string" or #instanceId == 0 then return false, "InvalidUniqueGrant" end
        if inventory.Unique[instanceId] then return false, "DuplicateInstanceId" end
        if unique >= Config.MaxUniqueItems then return false, "InventoryFull" end
        local valid, normalized = Helpers.ValidateProperties(definition, properties or {})
        if not valid then return false, normalized end
        inventory.Unique[instanceId] = { DefinitionId = id, Properties = normalized }
    end
    return true
end
-- Stack IDs remove quantities; unique instance IDs remove exactly one item.
function Helpers.ApplyRemove(inventory: any, id: any, quantity: any): (boolean, string?)
    if type(id) ~= "string" or not Helpers.IsQuantity(quantity) then return false, "InvalidQuantity" end
    local instance = inventory.Unique[id]
    if instance then
        if quantity ~= 1 then return false, "InvalidUniqueQuantity" end
        inventory.Unique[id] = nil
        return true
    end
    local definition = Config.Definitions[id]
    if not definition or definition.Kind ~= "Stackable" then return false, "UnknownItem" end
    local owned = inventory.Stacks[id] or 0
    if owned < quantity then return false, "InsufficientItems" end
    inventory.Stacks[id] = if owned == quantity then nil else owned - quantity
    return true
end
return Helpers
