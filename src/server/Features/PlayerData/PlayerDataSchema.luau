--!strict
-- Layer 2: serialization checks, ordered migrations, and independent reset boundaries.
local Shared = game:GetService("ReplicatedStorage").Shared
local Helpers = require(Shared.Features.PlayerData.PlayerDataHelpers)
local Config = require(Shared.Features.PlayerData.PlayerDataConfig)
local Template = require(Shared.Features.PlayerData.PlayerDataTemplate)
local Currency = require(Shared.Features.Currency.CurrencyConfig)
local CurrencyRules = require(Shared.Features.Currency.CurrencyHelpers)
local InventoryRules = require(Shared.Features.Inventory.InventoryHelpers)
local Schema = {}
local migrations: { [number]: (any) -> any } = {}

function Schema.CheckSerializable(value: any): (boolean, string?)
    local seen = {}
    local function check(v: any, depth: number): boolean
        local kind = type(v)
        if kind == "number" then return v == v and math.abs(v) < math.huge end
        if kind == "boolean" or kind == "string" then return true end
        if kind ~= "table" or depth > 32 or seen[v] then return false end
        seen[v] = true
        local strings, numbers, count, maximum = false, false, 0, 0
        for key, child in v do
            if type(key) == "string" then strings = true
            elseif type(key) == "number" and key >= 1 and key % 1 == 0 then
                numbers = true
                maximum = math.max(maximum, key)
            else return false end
            count += 1
            if not check(child, depth + 1) then return false end
        end
        seen[v] = nil
        return not (strings and numbers) and (not numbers or maximum == count)
    end
    if check(value, 0) then return true end
    return false, "NonSerializableProfile"
end

function Schema.New(): any
    local data = Helpers.DeepCopy(Template)
    for id, definition in Currency.Definitions do data.Currencies[id] = definition.StartingBalance end
    return data
end

local function quantity(value: any): boolean
    return type(value) == "number" and value == value and value >= 0 and value < math.huge and value % 1 == 0
end

function Schema.Prepare(raw: any): (boolean, any, { string }?)
    if type(raw) ~= "table" then return false, "InvalidProfileRoot" end
    local version = raw.SchemaVersion
    if not quantity(version) or version < 1 then return false, "MissingOrInvalidSchemaVersion" end
    if version > Config.SchemaVersion then return false, "NewerSchemaVersion" end
    if not Schema.CheckSerializable(raw) then return false, "NonSerializableProfile" end
    local data = Helpers.DeepCopy(raw)
    while version < Config.SchemaVersion do
        local migrate = migrations[version]
        if not migrate then return false, "MissingMigrationFromVersion:" .. tostring(version) end
        local ok, result = pcall(migrate, data)
        if not ok or type(result) ~= "table" or result.SchemaVersion ~= version + 1 then
            return false, "MigrationFailedFromVersion:" .. tostring(version)
        end
        data = result
        version += 1
    end
    local defaults, resets = Schema.New(), {}
    local function reset(section: string, valid: boolean)
        if not valid then
            data[section] = Helpers.DeepCopy(defaults[section])
            table.insert(resets, section)
        end
    end
    local balancesValid = type(data.Currencies) == "table"
    if balancesValid then
        for id, amount in data.Currencies do
            local definition = Currency.Definitions[id]
            if not definition or not CurrencyRules.IsAmount(id, amount, true) then
                balancesValid = false
                break
            end
        end
    end
    reset("Currencies", balancesValid)
    for id, amount in defaults.Currencies do
        if data.Currencies[id] == nil then data.Currencies[id] = amount end
    end
    local inventoryValid = InventoryRules.Validate(data.Inventory)
    reset("Inventory", inventoryValid)
    reset("Base", type(data.Base) == "table" and quantity(data.Base.Level) and data.Base.Level >= 1 and type(data.Base.Buildings) == "table")
    reset("Features", type(data.Features) == "table")
    if not Schema.CheckSerializable(data) then return false, "InvalidMigratedProfile" end
    return true, data, resets
end
return Schema
