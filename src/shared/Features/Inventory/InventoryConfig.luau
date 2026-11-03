--!strict
-- Inventory counts all stacked units toward MaxStackUnits; unique items have a separate cap.
return {
    MaxStackUnits = 1000,
    MaxUniqueItems = 100,
    MaxRequestQuantity = 1000,
    Definitions = {
        ["resource.ore"] = { DisplayName = "Ore", Kind = "Stackable" },
        ["product.ingot"] = {
            DisplayName = "Ingot", Kind = "Stackable",
            Sell = { CurrencyId = "currency.cash", UnitPrice = 10 },
        },
    },
}
