# Base system

## Level and slot definitions

`src/shared/BaseConfig.luau` defines the complete slot list for every level. A zone ID identifies a persistent slot; `AssetType` identifies its predefined facility. Players cannot choose a different facility type for a slot.

| Base level | Zone1 | Zone2 | Zone3 | Zone4 | Zone5 |
| --- | --- | --- | --- | --- | --- |
| 1 — Starter | Forge | Charge Station 1 | — | — | — |
| 2 — Established | Forge | Charge Station 1 | Charge Station 2 | — | — |
| 3 — Developed | Forge | Charge Station 1 | Charge Station 2 | AI Bot | — |
| 4 — Expanded | Forge | Charge Station 1 | Charge Station 2 | AI Bot | Charge Station 3 |

Every base upgrade adds exactly one slot. Newly unlocked forge/station slots use the existing owner proximity-prompt purchase flow. Unlocking a slot does not automatically purchase its facility. AI Bot is reserved and visibly unavailable; its system and asset templates are deferred. The former Command Terminal and Inspector definitions are removed.

Cash costs remain zero for testing. Existing tier requirements remain: level 2 requires the original forge and station purchased; levels 3 and 4 require those original facilities at tier 2. AI Bot is never an upgrade prerequisite. Every purchased forge/station can independently reach tier 3.

## Placement contract

- Numbered plots live at `Workspace/World/Bases/Base_<index>`. Authored plot pivots and level-1 layouts are preserved. Missing numbered plots use the existing 13-base, radius-125 ring; position 14 remains reserved for the pathway.
- Each model has a `Zones` folder containing uniquely named BaseParts matching the table above. A part's CFrame is the placement transform. The matching placed facility is named with that zone ID under `PlacedAssets`.
- Initial placement uses the zone CFrame without guessed offsets. Existing authored facilities retain their pivot on saved-tier restoration. Facility tier upgrades retain their current pivot.
- Base upgrades use the exact `Assets/Base_Models/Base_Level_<level>` template at the existing plot pivot. Existing facility instances move to matching zone CFrames, preserving their individual tier, charge, contents, prompts, and station registration.
- Higher-level templates must contain exactly their configured zones, including the reserved AI Bot part. Missing, duplicate, non-part, or unexpected zones reject upgrades/restoration. Missing templates or unmappable placed assets also reject the swap without charging or changing saved progression. Setup failures roll moved assets back.
- Extra zones in legacy authored level-1 plots are reported but receive no purchase prompts and cannot unlock higher-level facilities. Code never guesses new transforms or rewrites authored zone geometry.
- Returning players with saved levels above 1 require the corresponding exact template. Plot indices and world coordinates are not saved.
- Assets are resolved from `ServerStorage/Assets`, with the existing `ReplicatedStorage/Assets` fallback. Forge templates remain in `Forge_Models`; all station slots share the tier templates in `ChargeStation_Models`.

## Saved state and facilities

`BaseProfile.Load` produces version 2. Existing `Forge` state is retained. `ChargeStations` holds independent station state keyed by `Zone2`, `Zone3`, and `Zone5`; each record stores tier, power, capacity, and generation rate. The original `ChargeStation` field remains an alias of `ChargeStations.Zone2` for compatibility. Legacy saves migrate their original station without copying its power to new stations. Purchase flags are restricted to implemented slots unlocked by the saved base level.

Runtime facility state directly references the saved profile. Leaving clears runtime references without clearing facilities. Existing autosave/leave-save behavior remains; there is no new offline processing or session locking.

- Forge: deposits carried ore/Scrap and collects output through owner proximity; processes 1/2/4 items every two seconds at tiers 1/2/3, with round-robin material selection.
- Charge Station: each purchased, live station independently stores 100/200/350 power and generates 5/10/20 per second at tiers 1/2/3. Upgrades preserve stored power.
- Home companions: select stations in slot order, keep the current station until it reaches zero, then advance to the next charged station and wrap around. Empty, unpurchased, missing, and locked stations are skipped. If all are empty, charging resumes when power becomes available. Mode changes and companion replacement reset the selected station. Existing transfer rate, range, health/stamina priority, and surplus XP behavior remain.

Purchases and upgrades validate ownership, proximity, readiness, and costs. Transaction and setup callbacks must remain synchronous. Base upgrades preserve the previous layout/state on failure. Facility APIs accept an optional station slot; omitting it preserves original-station behavior.

## UI

The Base panel lists each unlocked facility separately, its tier or purchase status, and every level's configured slots even if its model is missing. Template problems are reported; unavailable next layouts disable base upgrades. Each station has its own prompt and status billboard; the billboard appears within `StatusRange` (20 studs) and both anchor at the model's base. AI Bot displays Coming soon.

## Local verification

From `src`, run `python3 tools/verify.py`. This compiles Luau, runs the existing suites and `server/Base/tests/run.py`, builds Rojo, and performs Roblox-aware analysis. The base tests execute actual source with mocked Roblox dependencies and cover:

- Four level definitions, legacy migration, independent saved station data, locked-slot filtering, and malformed values.
- Slot catalog diagnostics, missing/duplicate placement parts, and deferred AI Bot status.
- Per-station charge generation, consumption, upgrades, failure rollback, station selection/cycling, and empty/missing/unpurchased stations.
- Purchases, exact layout validation, unlocks, migration of facility instances/pivots, failed base-swap rollback, and level-4 restoration.

Mocks do not establish live physics, movement, replication, DataStore durability, or multiplayer behavior. User-run Studio checks remain necessary for facility alignment, companion travel between stations, save/rejoin behavior, owner/visitor prompts, and upgrades on real templates. Agents must not start Studio tests.

## Authored model follow-up

No Studio models are created or edited by the source changes. The real templates must match the table above, particularly the new `Base_Level_4`. Existing pivots and unrelated authored content must be preserved.

Copy-ready Studio AI Assistant prompt for Workspace model preparation:

> Prepare Workspace staging copies of the base layouts named Base_Level_1 through Base_Level_4, preserving the existing design, plot pivots, and unrelated content. In each copy, use a Zones folder of uniquely named placement parts. Level 1 has Zone1 for the forge and Zone2 for charge station 1. Level 2 adds Zone3 for charge station 2. Level 3 adds Zone4 reserved for a future AI Bot. Level 4 adds Zone5 for charge station 3. Each level carries forward all earlier slots. Position and orient each zone to fit its predefined facility using the authored facility pivots. Do not add scripts, implement AI Bot behavior, run tests, or alter active player bases. Keep all this work in Workspace staging copies for review.

After reviewing the staging models, the user can put the corresponding templates in `Assets/Base_Models`. This source implementation does not automate that scene operation.
