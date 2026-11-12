# Basic arena

`Arena.Init()` is called by Main after base initialization. `Arena.Stop()` disconnects the loop and removes its runtime objects. Source is managed through Rojo.

Edit `ArenaData.luau` for temporary mode durations, ore pools (duplicate IDs increase probability), spawn intervals, ore caps, rewards, and boss template names. Modes rotate Normal (180s), Rich (120s), Boss (90s). Every transition removes remaining ore and bosses. Ores are simple anchored placeholder rocks with automatic proximity collection; spawning starts with one rock and fills gradually to the cap.

`ArenaGeometry` is the shared source of geometry for all Arena systems. It resolves only `Workspace.Game.World.Arena.BasicArena.ArenaFloor`; legacy tags, `ArenaBounds`, and other `Floor` parts cannot override it. ArenaFloor is a horizontal disk with its smallest local dimension as thickness (including the authored local-X thickness). The smaller remaining dimension defines the circular diameter. Presence is inside the world-XZ circle and at or above the top surface, with no upper ceiling. A missing or tilted floor disables Arena activity. Dimensions are read each call, so floor moves/resizes update subsequent checks and spawns.

Ore and bosses spawn on the top surface using uniformly sampled circular positions, inset from the edge. Drops clamp radially onto that same surface. Existing spawned objects are not moved when the floor is edited during play; restart play after scene edits to regenerate them. `CompanionWorld` delegates its Arena APIs to this helper, keeping collection, carrying penalties, damage drops, Fight targeting and attack eligibility consistent.

Create Model templates named `StoneGolem` and `IronGolem` under `ServerStorage.ArenaBosses` (or edit the configuration). Rich spawns StoneGolem; Boss spawns IronGolem; Normal has no boss. Each template must contain a BasePart. Templates are cloned once per mode and can carry their own server AI. Missing templates warn and are skipped. This module does not implement boss combat, rewards, or AI.

`workspace.RuntimeArena` exposes `Mode`, `ModeEndsAt` (server timestamp), and `TimeRemaining` attributes for a future HUD. Runtime children are `Ores`, `Drops`, and `Bosses`.

`TryCollectOre(player, ore)` validates registration, profile readiness, actual forge placement in the player's current assigned base (`PlacedAssets.Zone1`), living character, arena bounds, distance, and cooldown. It claims the ore before awarding inventory, so two players cannot collect the same rock. A default forge state or purchased-zone flag alone does not unlock collection. Removing the forge immediately blocks further interactions. Ore and dropped bundles have no prompts and cannot collide with any player. The server scans every 0.1 seconds and attempts to collect the nearest eligible ore within 12 studs, at most once per player per 0.3-second cooldown. A forge-less player can walk through ore but cannot collect it. Future weapon/mining handlers must call `CanInteractWithOre` before damage and `TryCollectOre` to award collection; no client reward remote exists.

Verification: `python3 server/Arena/tests/run.py /path/to/luau`. Tests mock Roblox services and exercise collection denial, successful collection, duplicate claims, cooldown, ownership, and forge removal. Studio playtesting is still needed for placement, automatic pickup timing, and boss models.


## Carrying and damage drops

`ArenaCarryManager` starts from Main. All raw ores (including Scrap, matching Inventory.GetOres) contribute to a replicated, non-colliding stack above the character. The stack shows up to eight placeholder rocks and a total quantity label, and remains visible outside the arena until deposited or dropped. Refined items do not count.

Inside the arena, speed is `max(MinimumCarrySpeed, DefaultWalkSpeed - oreCount * SpeedPenaltyPerOre)`, capped at the default. Defaults are 16 speed, 0.35 penalty per raw ore, and a minimum of 8. Outside the arena (or when the boundary is unavailable), speed is always reset to DefaultWalkSpeed on the next Heartbeat. Other WalkSpeed assignments do not redefine the default. Configure these values in ArenaData; this manager owns player walking speed.

Humanoid health decreases inside the arena (including lethal damage) drop all carried raw ore; healing and damage outside do not. This covers boss and companion damage applied through Humanoid health. Each ore type becomes one quantity-preserving bundle near the player, clamped inside the arena. The owner must wait four seconds before reclaiming that bundle; other players may immediately collect it, subject to the usual forge, distance, alive, and profile checks. Bundles survive mode transitions and expire after 60 seconds. Disabling the arena boundary clears drops. Configuration lives in ArenaData.

Additional checks: `python3 server/Arena/tests/carry.py /path/to/luau`. Mock tests verify speed caps/restoration, default speed enforcement, damage/healing behavior, owner lockouts, theft, and bundle quantities. Visual placement, multiplayer timing, and actual boss attacks still require Studio playtesting.

Local geometry checks: `python3 server/Arena/tests/geometry.py luau` executes ArenaGeometry with vector/scene mocks, including circular bounds, height, 1,000 spawn samples, drop clamping, floor movement/resizing, and missing-floor behavior. `tests/geometry.spec.luau` is the separate Roblox-datatype version; local verification does not run it in Studio.

Run all local checks from src with `python3 tools/verify.py`; see `tools/README.md`. No Studio connection is used.
