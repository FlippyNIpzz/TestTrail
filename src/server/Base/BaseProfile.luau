--!strict
-- Pure migration: no services, profile sessions, or world dependencies.
local Config = require(game:GetService("ReplicatedStorage").Shared.BaseConfig)
local Profile = {}
export type Forge = { Tier: number, Intake: { [string]: number }, Output: { [string]: number } }
export type Charge = { Tier: number, PowerStored: number, MaxPower: number, GenerationRate: number }
export type State = {
    Version: number, Level: number, PurchasedZones: { [string]: boolean },
    Forge: Forge, ChargeStation: Charge,
}
local function numberIn(value: unknown, fallback: number, minimum: number, maximum: number): number
    if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
    return math.clamp(value, minimum, maximum)
end
local function record(raw: unknown): { [string]: unknown }
    return if type(raw) == "table" then raw :: { [string]: unknown } else {}
end
local function items(raw: unknown): { [string]: number }
    local result: { [string]: number } = {}
    if type(raw) == "table" then
        for key, value in pairs(record(raw)) do
            if type(key) == "string" and type(value) == "number" and value > 0
                and value < math.huge and value % 1 == 0 then result[key] = value end
        end
    end
    return result
end
function Profile.Load(raw: unknown): State
    local data = record(raw)
    local forge = record(data.Forge)
    local charge = record(data.ChargeStation)
    local tier = math.floor(numberIn(charge.Tier, 1, 1, #Config.ChargeTiers))
    local config = Config.ChargeTiers[tier]
    local purchased: { [string]: boolean } = {}
    if type(data.PurchasedZones) == "table" then
        for zone, enabled in pairs(record(data.PurchasedZones)) do
            if type(zone) == "string" and Config.Zones[zone] and Config.Zones[zone].Available and enabled == true then
                purchased[zone] = true
            end
        end
    end
    return {
        Version = 1, Level = math.floor(numberIn(data.Level, 1, 1, #Config.BaseLevels)), PurchasedZones = purchased,
        Forge = { Tier = math.floor(numberIn(forge.Tier, 1, 1, #Config.ForgeTiers)), Intake = items(forge.Intake), Output = items(forge.Output) },
        ChargeStation = { Tier = tier, PowerStored = numberIn(charge.PowerStored, 0, 0, config.MaxPower),
            MaxPower = config.MaxPower, GenerationRate = config.Rate },
    }
end
return Profile
