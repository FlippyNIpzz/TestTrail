# Companions

Local implementation; scene assets are not created or modified by these scripts.

- `CompanionData.luau`: rarity budgets/min/max, level multiplier, XP, movement, combat, station rates. Common is 30 points with 5–10 per stat. Rare uses 10–23 per stat; its budget and Epic/Legendary settings are provisional balancing values.
- `CompanionRules.luau`: random fixed-budget stats, fusion, storage resets, recovery and validation.
- `CompanionCollection.luau`: unique owned copies, random Common starters and legacy `CompanionId` migration. Templates use `<Element><Rarity>` names under `ServerStorage.Assets.Companions` (or `Companion`). New starters are sampled from available Common models.
- `CompanionManager.luau`: server-authoritative equip/fusion/modes, runtime models, arena damage and recovery. Trusted reward scripts can call `Grant(player, templateId)`. Other server combat systems can call `Damage(player, amount)`.
- `CompanionWorld.luau`: ground positioning and shared ArenaGeometry adapters. The sole boundary is `Workspace.Game.World.Arena.BasicArena.ArenaFloor`: a horizontal circular footprint extending upward without a ceiling. Missing/tilted floors disable Fight requests and arena attacks.
- `CompanionServer.server.luau`: remote wiring. PlayerDataServer attaches/detaches sessions after profile loading.
- `client/Companion/CompanionUI.luau`: existing Bag's Companions tab, detail view, modes, equip/storage confirmation and destructive fusion preview.

Only one companion is equipped. Stored companions keep their individual stat points but have overall level and XP 0. Disconnecting does not unequip. Health, stamina and mode are saved; no offline XP is awarded. Fusion requires the equipped survivor and a distinct owned same-rarity donor, consumes the donor, keeps per-stat maxima and the highest overall level, and sets XP to 0. The starting budget is never reapplied after fusion.

Level multiplier is `1 + Level * LevelMultiplier`, so level 0 remains usable. Station power is divided proportionally between missing health and stamina, with only surplus converted to XP. Stations use the current BaseAssetManager station registration and power pool. At zero stamina companions still attack, but move slower. Defeat changes mode to Home and teleports to the assigned base; recovery does not restore Fight automatically.

Movement uses server-driven grounded model pivots, not obstacle pathfinding. Arena damage targets the nearest eligible opposing companion or player inside the boundary and excludes the owner and ForceField-protected players. External player weapons must call the server-only Damage API to damage companions.

Run `python3 server/Companion/tests/run.py /path/to/luau` for pure rule tests. Real DataStore persistence, model placement, combat and responsive UI need Studio playtesting after sync. The existing profile store still uses GetAsync/SetAsync without cross-server session locking.
