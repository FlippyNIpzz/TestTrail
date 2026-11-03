--!strict
return {
    EconomyRefreshSeconds = 2,
    StateRequestInterval = 0.5,
    SellRequestInterval = 0.25,
    MaxRows = 200,
    -- Presentation-only catalog; never grants items or invokes a purchase remote.
    -- Populate from the game's actual shop definitions when shops are implemented.
    -- Entries: { ShopName: string, Name: string, Description: string, PriceLabel: string }
    ShopOffers = {},
}
