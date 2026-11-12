# Base system

## Placement contract

- Initial facility placement uses the authored `Zones/Zone1` (forge) or `Zones/Zone2` (station) CFrame. No guessed offsets, footprint adjustments, or zone movement are applied.
- An already authored facility under `PlacedAssets/Zone1` or `Zone2` retains its pivot when its saved tier is restored. Facility upgrades retain the current world pivot.
- Existing `Workspace/World/Bases/Base_<index>` models supply their own plot pivots and layouts. Assignment/release clones that layout rather than relocating it onto the generated circle. Non-archivable authored layouts are skipped rather than replaced with a fallback that could lose content.
- Where no authored numbered plot exists, the existing 13-base/radius-125 layout and level-0/level-1 templates remain in use. Spot 14 remains reserved for the pathway.
- Base progression changes saved level only. It does not replace a physical base, shift zones, or move facilities. Model pivot inconsistencies must be corrected through Studio AI Assistant by the user; code does not guess corrections.
- Arbitrary models outside the established `World/Bases/Base_<index>/Zones` and `PlacedAssets` hierarchy are not discovered or moved.

## Configuration and compatibility

`src/shared/BaseConfig.luau` owns facility names, templates, costs, requirements, and rates. Cash costs remain zero for testing. Existing facility tiers remain available at Base level 1.

Base milestones are provisional: level 2 requires both facilities purchased; level 3 requires both at tier 2. These milestones do not yet unlock new facilities. Command Terminal and Inspector are visibly unavailable, not purchasable empty zones.

Existing public assignment, upgrade, inventory-transfer, charge-generation, charge-consumption, and asset-query functions remain. `UpgradeForge` and `UpgradeChargeStation` still return booleans. `PurchaseZone` remains declared for compatibility; server proximity prompts still perform purchases. `BaseAction` supports only `Get` and `Upgrade`, with a per-player request throttle.

## Saved state and lifecycle

`BaseProfile.Load` migrates old profiles into a version-1 `Base` record, validates numbers and item quantities, and derives station capacities/rates from configuration. It does not modify inventory or companion data. The existing DataStore name and save path remain unchanged.

The record contains Base level, purchased zones, facility tiers, forge intake/output, and stored station power. Runtime facility state refers directly to this profile record, so forge transfers stay within saved player data. Plot numbers and world coordinates are not saved: a returning player restores their facilities at the assigned plot's authored locations.

Assignment waits for `DataReady` and initialized managers, loads facility state, then restores models and interactions. Leaving detaches runtime references without clearing saved facilities. Respawn teleportation remains three studs above the assigned plot pivot. No offline processing was added. Durability still depends on the existing autosave/leave-save mechanism; this work does not add DataStore session locking or crash-proof saving.

## Purchases and upgrades

Server actions validate ownership, character proximity, profile readiness, requirements, and affordability. Templates are cloned and configured before old assets are removed or resources charged. Missing templates leave purchases available and upgrades unchanged; restoration exposes a retry prompt without charging again. Duplicate callbacks from destroyed upgrade prompts are ignored.

The per-player transaction guard is synchronous: transaction callbacks and facility-setup callbacks must not yield. Do not add DataStore calls or asynchronous work inside them. Profile currency and facility changes occur in the same synchronous action.

## Existing mechanics retained

- Forge checks owner proximity every 0.25 seconds, within 12 studs of its primary part. Carried ore/Scrap deposits automatically; output collects automatically when carrying no ore.
- Forge processes 1/2/4 items every two seconds according to tier. A sorted round-robin order processes one material type per tick without starving other types.
- Stations retain capacities 100/200/350 and generation 5/10/20 per second. Generation requires a registered live station. Charge survives upgrades.
- Companion Home-mode behavior, range, transfer rate, health/stamina priority, and surplus XP conversion remain in the Companion system.

## UI

The BASE launcher opens a responsive, scrollable panel using the existing theme. It shows Base level, milestones, facility purchases/tiers, next upgrades, requirements, and restoration failures. Base level is separate from the player level shown in the wallet HUD.

Purchase/upgrade proximity prompts remain the entry point for facilities. Only the owner sees actionable prompts; the server independently enforces ownership and distance. Billboards show permanent MAX status, forge contents/rate, and station generation versus active companion supply. Toasts report transfers, successes, and failures. Existing Bag shortcuts and companion controls remain unchanged.

## Implementation sequence completed

1. Existing behavior and placement contract documented.
2. Shared configuration introduced with unchanged facility rates and free testing costs.
3. Purchase/replacement validation and failure handling centralized.
4. Backward-compatible profile migration and profile-backed facility state added.
5. Explicit readiness and saved-tier restoration connected to assignment.
6. Existing forge/station mechanics retained with deterministic processing.
7. Logical Base milestones added without physical Base upgrades.
8. Base panel, owner prompt filtering, status improvements, and feedback added.
9. Cross-module calls and failure paths reviewed locally.
10. Compilation, Rojo build, and static-analysis results are reported in the implementation handoff. No test suites or Studio sessions are run under the user's no-tests instruction.

## User-run Studio checklist (not performed by the agent)

- On fresh join and respawn, verify assignment, landing position, and lack of duplicate numbered bases.
- Compare authored zone transforms and facility pivots before/after purchases, both facility upgrades, Base upgrades, and plot release/reassignment. Check model alignment visually at all tiers.
- Verify owner prompts, visitor rejection, 12-stud range, dead-character rejection, and repeated input behavior with multiple players.
- Temporarily unavailable templates should leave purchases retryable, upgrade state/resources unchanged, and saved restorations retryable without a second charge.
- Deposit mixed materials, observe round-robin processing, collect, and check Bag/HUD updates. Rejoin with both intake and output pending and verify restored quantities.
- Generate station power, consume it with a Home companion, upgrade, and rejoin. Verify capacity, generation, consumption, and saved power.
- Upgrade Base milestones with and without requirements; confirm player level and physical layout do not change.
- Verify old profiles retain inventory and companions while receiving default Base state. Verify leaving/rejoining another plot restores saved tiers at that plot's authored locations.
- Check desktop/mobile panel sizing, long prompt text, MAX labels, failure toasts, Bag controls, and companion UI.

## Local checks for this implementation

- Compilation of the ten changed/new Luau source files: passed.
- Rojo build: passed (`src/tools/.local/base-implementation.rbxlx`).
- Rojo sourcemap: passed.
- `python3 src/tools/verify.py --analyze-only`: failed project-wide with 28 unique diagnostics (44 occurrences), all outside the changed files. The remaining reports concern UITheme, InventoryUI, CompanionUI/Collection/Manager, Inventory, Arena, and Main.server. Full report: `src/tools/.local/analysis.log`.
- No test suites, Play/Run sessions, command-bar snippets, or Studio execution were performed.

Local compilation/static analysis cannot establish live physics, replication, DataStore durability, or multiplayer behavior.
