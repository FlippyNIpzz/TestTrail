# Currency, inventory, and sell menu

## Implemented behavior

The example uses cash, ore, and ingots. Ingots sell for 10 cash each. Ore has no sale definition. These IDs and prices are content configuration; core services do not hardcode them. There is no resource-producing world yet, so the menu remains empty until a server operation grants items.

Players open Inventory / Sell, select an item row, enter a positive whole-number quantity, and sell it. The server checks profile admission, item definition, ownership, quantity, request sequence, and currency precision/limits. Removing items and granting the reward happen in one PlayerData.Update transaction; either both commit or neither does. Failed and repeated requests cannot duplicate rewards or consumption.

Only stackable items are sold by this example. Unique items are displayed individually but cannot be sold until a future game's configuration and rules specify how their individual properties affect value. Inventory itself supports both models.

The UI requests a filtered economy projection every two seconds. It preserves text input when the inventory is unchanged and during focused editing. It never receives the private profile or unique-item properties. After a transport failure it preserves the pending sale's payload and request ID for retry. The server remembers the latest response and rejects all older IDs, avoiding a replay window from cache eviction.

## Server API

- CurrencyService.GetBalance(player, currencyId): success and balance, or reason.
- CurrencyService.Grant(player, currencyId, amount): validated positive grant.
- CurrencyService.Spend(player, costs): validates all configured currency costs before any deduction; empty costs support free actions.
- InventoryService.GetInventory(player): independent inventory copy.
- InventoryService.Grant(player, definitionId, quantity, properties?): stack grant or one server-generated unique instance. Unique success returns the instance ID.
- InventoryService.Remove(player, stackDefinitionIdOrUniqueInstanceId, quantity): validates available ownership; unique quantity must equal one.
- InventoryService.Has(player, stackDefinitionIdOrUniqueInstanceId, quantity): success and boolean ownership result.
- InventoryService.Sell(player, definitionId, quantity, sequentialRequestId): atomic sale, with replay protection. Obtain the next ID from GetNextSellRequestId or the UI projection. Success returns true; failure returns false and a reason.
- InventoryService.Forget(player): remove request state on departure.

Shared CurrencyHelpers and InventoryHelpers operate on transaction draft tables. A multi-system operation can combine these helpers inside one PlayerData.Update; separate successful service calls are not automatically one combined transaction. Do not call Service.Save for purchases or sales.

Inventory capacity counts total stacked units and unique item count separately. Unique properties declare number ranges, string maximum lengths, or boolean values and independent defaults. Unknown properties and duplicate instance IDs are rejected. Saved inventory is revalidated using the same rules.

## Networking

- UI.GetState is a RemoteFunction with no required arguments; returns success and filtered state or a failure reason. Per-player minimum interval: 0.5 seconds.
- Inventory.Sell is a RemoteFunction taking item ID, quantity, and sequential request ID; returns success and optional failure reason. Per-player minimum interval: 0.25 seconds.
- Clients never send prices, rewards, target players, balances, or authoritative item properties through these remotes.
- Request-frequency state and cached sale responses are removed on departure; remote handlers and owned connections are removed on destruction.

## Automated checks — October 24, 2026

18 economy tests pass against the actual service and helper source, plus the existing 19 player-data tests. Cases include multiple currencies and precision, startup validation and frozen configuration, full inventories, unique properties/IDs, ownership isolation, complete rollback on failed rewards, invalid numbers, repeated and stale sales, and private-state filtering. Roblox services are mocked; the real GUI and networking are not executed by these tests.

## Studio checks — pending

1. In a two-player Memory-mode local server, confirm cash balances and empty-state feedback appear independently. Respawn and confirm only one economy interface remains.
2. From the server command bar, require ServerScriptService.Server.Features.Inventory.InventoryService and grant ingots to one admitted player. Confirm only that player's inventory updates. No client grant remote exists.
3. Enter different quantities and verify the sold quantity and server balance. Confirm zero, negative, fractional, excessive, and nonnumeric entries provide feedback without state changes.
4. Fill inventory to its configured cap. Confirm extra grants fail. Grant test unique definitions in configuration and verify IDs, limits, defaults, and hidden properties.
5. Retry identical sale IDs, resend older IDs, and spam the remote with invalid requests. Confirm replay protection, rate limits, and ownership isolation.
6. Interrupt the network during a sale. Retry its same item and quantity after recovery; confirm one sale, even if the first request succeeded but its response was lost.
7. Verify quantity inputs remain usable across periodic refreshes, scrolling and buttons fit desktop/mobile screens, and opening/closing during requests causes no stale callbacks or duplicate controls.
8. Test storage-backed restoration of balances and inventory using the development namespace. This depends on the outstanding player-data Studio checks.

Bases, collection, processing, upgrades, and the full reference loop remain pending the next implementation stages.
