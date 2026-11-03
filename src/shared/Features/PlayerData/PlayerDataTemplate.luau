--!strict

-- Generic profile contract. The server schema owns validation and migrations.
export type Profile = {
    SchemaVersion: number,
    Currencies: { [string]: number },
    Inventory: { Stacks: { [string]: number }, Unique: { [string]: any } },
    Base: { Level: number, Buildings: { [string]: any } },
    Features: { [string]: any },
}
return { SchemaVersion = 1, Currencies = {}, Inventory = { Stacks = {}, Unique = {} },
    Base = { Level = 1, Buildings = {} }, Features = {} }
