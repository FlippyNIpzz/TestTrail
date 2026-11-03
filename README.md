# Tycoon Foundation — Reusable Game Specification

## Documentation guide

All project documentation is maintained in this README. Historical audit and verification records retain their original scope and dates; later implementation records may supersede them.

- [Studio model organization](#studio-model-organization)
- [Delivery checklist](#delivery-checklist)
- [Source and API guide](#source-api-guide)
- [Player-data verification](#player-data-verification)
- [Economy verification](#economy-verification)
- [Base upgrades verification](#base-upgrades-verification)
- [Resource generation verification](#resources-verification)
- [Admin controls](#admin-controls)
- [Historical script and GUI audit](#script-gui-audit)
- [Third-party code and attribution](#third-party-code)
- [Archived source](#archived-source)

## Studio model organization

Reviewed in connected Studio CHAT on 2026-10-27. This is the project owner's preferred organization for future model work and supersedes earlier Workspace organization examples in historical records below. Inspect the current hierarchy before editing; preserve existing names, casing, underscores, slot IDs, and model boundaries.

```text
Workspace/
  Default/                       # Default scene objects: baseplate, camera, spawn
  World/                         # Static world scenery
    Arena/BasicArena
    Environment/GrassOutsidePerimeter
    Paths/                       # Arena walkways and BaseArenaPath
    Perimeter/                   # Colosseum additions, fences, stairs, PetraEntrance
  Game/                          # Feature-specific gameplay models and galleries
    Arena/
      Resource_Models/           # OreCluster, OreClusterJagged, OreClusterWide
    Base/
      Base_Models/
        Base_Levels/             # Base_Level_0 through Base_Level_4
        Base_Slots/              # Existing BaseSlot models
      Forge_Models/              # StoneForge, IronForge, SteelForge
    Companions/
      CompanionModelGallery
  Development/
    Test_/
      Assets/
      Cobble/
  Terrain
```

For new content, use the existing feature folder under Game, then a descriptive purpose group such as Resource_Models or Forge_Models. Put each complete object and its component parts inside a Model; use Folders to group related models. Keep static architecture in the appropriate World category, experiments in Development, and default scene objects in Default. Do not create a competing top-level Bases or generic Assets hierarchy when an established category already fits. Preserve the author's current placement of galleries and level models; moving templates into storage is a separate implementation decision, not part of routine organization.

ServerStorage currently holds runtime templates in CompanionModels, FacilityModels, ResourceModels, and PlotLevelModels, alongside historical backups. Workspace galleries and stored templates have different roles; inspect their consumers before deciding which copy to edit. ReplicatedStorage contains Shared.Features and a separate Gui tree. Studio models are separate from the filesystem src tree and are not mapped by the current Rojo project file.

**Path compatibility found during review:** BaseConfig still references Workspace.Bases.NoGemBases and Workspace.Bases.PlacedBases, whereas authored models now live under Workspace.Game.Base.Base_Models. The existing slot names also mix padding (BaseSlot_1 versus BaseSlot_06), so migration must inspect names and ArenaSlotIndex attributes rather than assume a rename or sequential index. tools/RigCompanions.luau still looks for Workspace.Development.CompanionModelGallery; the observed gallery is now Workspace.Game.Companions.CompanionModelGallery. These consumers need reconciliation before relying on them. This review recorded the convention only; it did not move objects or update runtime paths.

## Purpose

**Foundation** is reusable Roblox tycoon scaffolding, currently developed in TestTrail. Future games start in separate repositories copied from Foundation, then develop independently. The name does not refer to a game's main Git branch.

This document guides the project owner and AI coding agents. Its architectural and gameplay rules are defaults that may be adapted using judgment. It describes the intended foundation; existing Luau files have not yet been migrated or verified against every rule.

## How to Use This Specification

The core loop is **collect → deposit → process → collect outputs → spend → expand**. Each game supplies its theme, content, assets, and balance around that loop. The foundation must remain usable without companions, combat, arenas, or rebirth.

Rules in this document define the target behavior. “Must” identifies an implementation requirement; defaults are the starting choices for a copied game. A game may deliberately override a default, documenting the replacement and its effects on saved data, dependencies, and verification. Names, artwork, example prices, and sample content do not define a required theme.

Use this document as the design authority, [Delivery checklist](#delivery-checklist) to track delivery, and [Source and API guide](#source-api-guide) for the current source/API map. Verification records live in [Player-data verification](#player-data-verification) and [Economy verification](#economy-verification). Archived code is historical reference outside the active Rojo tree.

**Current status:** infrastructure, initial player-data handling, currency, inventory, and a sell menu exist. Arena resource generation exists (see [Resource generation verification](#resources-verification)); base ownership and structure upgrades exist (see [Base upgrades verification](#base-upgrades-verification)); arena carry-based movement exists (see [Carry Presentation and Movement](#carry-presentation-and-movement)); building placement/restoration, resource collection/carry visuals/deposits, facilities, generic upgrades, and the complete reference loop still need implementation. Mocked tests and packaging checks do not establish Studio readiness. This specification includes behavior beyond the current source.

### Scope and Delivery Boundaries

The reusable core includes the systems listed below and one minimal playable example. Trading, gifting, player-to-player theft, conveyors, freeform building, quests, monetization, and global leaderboards are outside the baseline. A game may add them with explicit ownership, persistence, and transaction contracts.

No core action requires a paid purchase. Roblox purchase fulfillment, if added by a specific game, needs a separate receipt and durable grant design; session request deduplication alone is insufficient.

## Architecture

Organize code by feature across separate `server`, `client`, and `shared` roots. Keep all modules for a feature directly in its feature folder within the appropriate root. The four layers define responsibilities, not additional subfolders:

| Layer | Responsibility | Primary module name |
| --- | --- | --- |
| **1. Config** | Static settings, content definitions, constants, types, and default templates. | `<Feature>Config.luau` |
| **2. Helpers** | Calculations and Roblox helpers such as raycasts, tweens, and model positioning; no ownership of authoritative state. | `<Feature>Helpers.luau` |
| **3. Services** | Runtime state, validation, and system rules. | `<Feature>Service.luau` |
| **4. Execution** | Startup and event wiring; delegates rules to services. | `<Feature>Server.luau` / `<Feature>Client.luau` |

Use specific supporting names such as `InventoryTypes.luau` and `InventoryTemplate.luau` where appropriate.

The four layers apply to infrastructure features too, including networking and player data. Keep their modules directly under their owning feature folder; central startup scripts coordinate them rather than becoming containers for system logic.

```text
src/
  server/Main.server.luau
  client/Main.client.luau
  shared/Features/Inventory/
    InventoryConfig.luau
    InventoryHelpers.luau
  server/Features/Inventory/
    InventoryService.luau
    InventoryServer.luau
  client/Features/Inventory/
    InventoryClient.luau
```

### Boundaries and Dependencies

- **Server:** Authoritative state, ownership, rewards, progression, and persistence.
- **Client:** Input, UI, camera, local presentation, and initial request validation.
- **Shared:** Definitions and helpers needed by both sides. Replicated content is readable by clients and contains no secrets. Shared modules do not share memory between server and client.
- Use explicit module calls between systems; avoid circular dependencies. Keep gameplay rules out of presentation and execution code.
- Execution normally owns event wiring. Services may own connections when appropriate to the system's lifecycle; document the choice and avoid duplicate wiring.

### Central Startup

Only `Main.server.luau` and `Main.client.luau` run automatically. Feature execution files are modules; requiring them must not start tasks or connect gameplay events.

Central startup selects enabled features and prepares them in dependency order through `Initialize`, then calls `Start` to connect events and begin work. Guard against duplicate initialization. Provide `Destroy` where connections, tasks, or temporary instances need cleanup.

Skip disabled optional features. Stop affected startup on dependency failure; a core failure keeps gameplay unavailable. Clients wait for required remotes and initial state before enabling interactions.

### Networking and Validation

One shared central registry declares feature-qualified remote names, types, and owning features, for example `Upgrades.BuyUpgrade`. Server startup creates enabled features' remotes through this registry; clients retrieve them through the same networking API. Features do not create their own remotes.

Feature execution modules handle requests and delegate operations to services. The registry owns channels, not gameplay rules or feature state.

Clients validate first for responsiveness. The server independently validates sensitive actions: currency, inventory, rewards, purchases, placement, ownership, progression, persistence, and private-state access. Relevant checks include types, finite numbers, quantities, IDs, prerequisites, distance, and request frequency. Derive prices and rewards from server-controlled definitions. Purely local presentation can rely on client validation.

Validate inputs before applying transactions; failures and repeated requests must not duplicate grants, deductions, pickups, or outputs. Return useful failure reasons and document validation responsibilities in each feature API.

## System Scope

| Required core | Responsibility |
| --- | --- |
| Player data | Versioned profiles, sessions, migrations, loading, and saving. |
| Networking and lifecycle | Communication, startup, join/leave, respawn, and cleanup. |
| Currency and inventory | Balances, item ownership, quantities, and transactions. |
| Bases and placement | Assignment, ownership, restoration, slots, and layout progression. |
| Resources and processing | Spawning, collection, carrying, deposit, processing, and output collection. |
| Purchases and upgrades | Costs, requirements, unlocks, and progression. |
| UI and synchronization | Reusable interface and client-visible state updates. |

Companions, combat, arenas, rebirth, and other specialized systems are optional. Each must be independently disableable without breaking core systems or requiring its assets and running tasks.

Before implementing a system, define its configuration, state ownership, public operations, dependencies, validation, initialization, and cleanup. Mark placeholders explicitly; default return values alone do not constitute working behavior.

## Game Configuration

- Use typed Luau modules returning data tables. Each feature owns its configuration modules directly in its feature folder; a small central `GameConfig` holds game identity and enabled features.
- Individual games customize content, prices, rewards, recipes, balance, assets, presentation, feature switches, and supported gameplay modes. Unsupported behavior may require game-specific code changes.
- Keep one authoritative definition per setting. Put client-readable configuration in shared feature folders and private definitions in server feature folders.
- Load and validate configuration once at startup; keep it immutable for that server session. Published changes apply to new servers. Runtime changes such as upgrades belong in state.
- Invalid required configuration stops the feature and its dependents with clear field/content-ID diagnostics. Do not silently substitute defaults or skip required entries.
- Configuration modules do not start tasks, connect events, or perform persistence operations.

### IDs and Assets

Use stable, unique namespaced content IDs with lowercase snake_case components: `resource.iron_ore`, `facility.basic_processor`, `currency.cash`. Keep them separate from display names, asset references, and unique item instance IDs. Validate cross-references; changing a saved ID requires migration.

Support both project asset paths and Roblox asset IDs. References explicitly identify their kind and expected asset type. Validate paths and instance classes before dependent startup; validate external ID formats and handle loading/permission failures explicitly. Resolve private assets on the server and replicate only what clients need.

## Currency and Inventory

**Currency:** Support multiple configured currencies, including games using only one. Define starting balances and allowed precision per currency. Save balances by currency ID; server services read, grant, and spend them. Require finite amounts, reject insufficient funds and negative balances, and validate all costs before any multi-currency deduction.

**Inventory:** Support both models:

| Item model | Identity and saved state |
| --- | --- |
| Stackable | Item definition ID and whole-number quantity of interchangeable units. |
| Unique | Server-generated instance ID, definition ID, and configured individual properties. Never merged into quantity stacks. |

Configure properties and inventory limits per game. Server operations validate ownership, definitions, quantities, properties, and capacity; reject duplicate instance IDs. Stack changes use positive finite whole numbers. Validate all inputs before consumption and keep consumption/output grants consistent on failure.

## Bases and Buildings

### Assignment and Layout

- Use **Base** consistently for a player's building and progression space.
- Generate evenly spaced bases around a circle, facing its center. Configure count, radius, center, and angular offset. Allow space for every layout stage without overlapping neighbors; an arena is not required.
- Server player cap equals base slot count. Match the Roblox experience's player-limit setting when publishing; local configuration does not change that setting.
- After a successful profile load, automatically assign one unoccupied base. Spawn the player at its layout-defined safe spawn point on join and every respawn.
- Physical base assignment is session state; saved progression belongs to the player. Restore progress on assignment, then release ownership and clean up world objects on departure.
- Unexpected base exhaustion is an assignment error: report it and never assign another player's base. Waiting areas and automatic extra bases are outside normal flow.

### Progression and Placement

Players purchase base levels; XP does not raise them. Configure starting/max levels, costs, prerequisites, and unlocks for slots, facilities, and upgrades. Unlocking does not automatically purchase a building.

Physical layouts expand or change at configured levels. Preserve slot IDs, buildings, facility progress, and stored resources across changes. Resolve slot positions from the current layout and restore the correct stage on rejoin. Every stage must accommodate permanent buildings within the assigned base space.

Buildings occupy predefined slots, with configured stable IDs, local transforms, allowed buildings, and unlock requirements. Server placement validates ownership, compatibility, availability, requirements, and costs; clients request IDs rather than authoritative transforms.

Current model assignment: **Zone 1 is reserved for Forge models**. Its Studio marker uses `AllowedModelCategory = "Forge"`; compatible models should use `ModelCategory = "Forge"`. This records the intended asset category; server placement enforcement is still pending.

**Zone 2 is reserved for Refinery models**. Its Studio marker uses `AllowedModelCategory = "Refinery"`; compatible models should use `ModelCategory = "Refinery"`. Server placement enforcement is still pending.

Placement is free or currency-paid per building. Buildings cannot be removed, sold, or relocated through normal interactions. Save buildings and progression by slot ID; session cleanup does not delete placements.

Games may define starter buildings in compatible, initially unlocked slots. Grant them free when creating a new profile; restore existing placements without granting starters again.

### Purchases and Upgrades

Support world buttons/prompts and UI menus through the same server operations. Validate costs, ownership, unlocks, target state, and proximity where required. Return success or useful failure feedback.

Base and facility upgrades cost currency only, with configured currency IDs and amounts. Non-consumable prerequisites may apply; inventory items are not upgrade costs.

### Implemented Base Structure Upgrade Scripts

| Script | Responsibility |
| --- | --- |
| [BaseConfig.luau](src/shared/Features/Base/BaseConfig.luau) | Defines the thirteen authored base locations, level-to-model mappings, upgrade prices, spawn offsets, and interaction limits. |
| [BaseService.luau](src/server/Features/Base/BaseService.luau) | Owns player base assignments, restores the saved level, validates upgrades, and updates currency and level in one profile transaction. Replaces only the structure while retaining the plot transform and runtime Buildings container. |
| [BaseModels.luau](src/server/Features/Base/BaseModels.luau) | Loads and validates model templates, then clones and aligns each structure to the base's ground position and orientation. |
| [BaseServer.luau](src/server/Features/Base/BaseServer.luau) | Connects player readiness, respawns, departure cleanup, owner-only upgrade prompts, and rate-limited upgrade/state requests. |

`Main.server.luau` initializes these modules through the Base feature lifecycle. Saved `Base.Level` selects `Base_Level_1` through `Base_Level_4` using `BaseConfig.Layouts`. Example cash costs to reach levels 2, 3, and 4 are **100, 250, and 500**, respectively; edit `BaseConfig.LevelCosts` to change them.

The server API is `BaseService.PurchaseLevel(player, expectedCurrentLevel)`. The central networking registry declares `Base.GetState` and `Base.PurchaseLevel`; clients cannot choose another player's base, the replacement model, or the price. Building placement and reconstruction from saved data remain pending. See [Base upgrades verification](#base-upgrades-verification) for API details, test results, and pending Studio play tests.

## Resources

### World Spawning

| Setting | Rule |
| --- | --- |
| Placement | Random valid positions inside configured zones; bounded attempts skip invalid placement. |
| Initial state | Zones start empty; first attempt waits for the normal random delay. |
| Timing | Each zone samples a new delay between configured positive minimum/maximum values after every attempt. |
| Selection | Per-zone weighted resource selection; finite non-negative weights, at least one positive. Zero excludes a resource. |
| Quantity | Exactly one unit per normally spawned pickup. |
| Capacity | One shared active-pickup cap per zone; no per-resource caps. At capacity, skip and wait for the next delay. |
| Lifetime | Required positive lifetime per resource; expired pickups cannot be collected and free spawn capacity. |

The server owns spawning and pickup lifetime. Defeat/departure drops are separate from generated pickups, do not consume zone capacity, and use their own expiration rules.

### Collection and Deposit

Collect automatically on character contact, with server validation of availability, eligibility, proximity, and applicable limits. Each pickup can be awarded once. Each resource defines its destination:

- **Direct inventory:** Immediately enters persistent inventory.
- **Carried until deposit:** Enters temporary carried state, then transfers to inventory or a configured processing input.

Carrying is unlimited, independently of persistent inventory limits. Entering the player's own base deposit zone automatically transfers accepted quantities; excess stays carried. Validate ownership and prevent duplicate contact deposits. Refresh visuals and movement after changes.

### Carry Presentation and Movement

Show carried resources in a stack above the character's head. Cap visible units through configuration without changing actual quantity, weight, deposits, or drops. Update/remove visuals with carried state; a UI counter is not required.

Player movement is enforced by the server's [ResourcesMovement.luau](src/server/Features/Resources/ResourcesMovement.luau), driven by the existing Resources lifecycle. This game uses total carried **units**, independently of unit weight, persistent inventory, visible model count, or the carry visual cap. The current server-only carry API is `ResourcesService.SetCarried(player, quantitiesByResourceId)`; missing state means zero. There is no client setter remote. `GetCarried(player)` returns an independent copy. Collection/deposit mechanics must call this API when transferring carried units; automatic collection, deposit and defeat drops remain pending.

Configure the four balance values in `ResourcesConfig.Movement`:

| Setting | Default | Meaning |
| --- | --- | --- |
| `OutsideArenaSpeed` | 16 | Always used outside the arena, regardless of load. |
| `ArenaBaseSpeed` | 16 | Arena speed with no carried resources. |
| `MinimumArenaSpeed` | 4 | Arena speed once the threshold is reached or exceeded. |
| `ResourceThreshold` | 30 | Total carried units at which slowdown reaches its minimum. This does not cap carrying. |

The project already defined proportional slowdown, so this implementation preserves it and derives its factor from the threshold:

```text
outside arena: speed = OutsideArenaSpeed
inside arena:
    count = clamp(carriedUnits or 0, 0, ResourceThreshold)
    factor = (ArenaBaseSpeed / MinimumArenaSpeed - 1) / ResourceThreshold
    speed = clamp(ArenaBaseSpeed / (1 + count * factor), MinimumArenaSpeed, ArenaBaseSpeed)
```

At or above the threshold the service uses `MinimumArenaSpeed` exactly. Defaults give 16 at zero units, 6.4 at 15 units, and 4 at 30 or more. Negative/invalid helper inputs count as zero; server carry mutations reject invalid/non-finite/fractional quantities and unknown resource IDs without changing state. Settings must be finite, speeds/threshold positive, and minimum arena speed no greater than the empty arena speed. Equal arena speeds are supported.

No existing arena-membership detector or player WalkSpeed writer was found in the active source or connected place. Detection reuses `ResourcesConfig.Zones[Movement.ArenaZoneId].SurfacePath`, currently the circular `Workspace.World.Arena.BasicArena.Floor`, and the same floor-geometry helper as spawning. Cylindrical floors use an elliptical footprint rather than their enclosing square. The root must lie from `BelowSurfaceTolerance` (default 6) studs below the floor top to `ArenaHeight` (default 64) studs above it. Arena geometry can move/rotate; its current transform is read during each check. A removed surface fails to outside speed. The optional combat Arena feature need not be enabled.

Carry changes refresh speed synchronously. Character/root/component changes trigger refreshes, and the existing server Heartbeat checks every frame to catch physics, teleports, boundary crossings and replacement Humanoids without a long polling delay. `CarriedResourceCount` and `InArena` player attributes are server-authored presentation/debug projections, never inputs to authority. New characters calculate from current server carry state; the pending defeat/drop system must explicitly clear or transfer that state on defeat. Leave and feature destruction clear session carry state and disconnect listeners. Carry quantities are not saved.

This is the sole player WalkSpeed owner. Companion animation only reads its own `CompanionWalkSpeed` presentation attribute. Future movement systems must integrate with this calculation rather than write competing player speeds. The current project has no active player movement modifiers. This game's outside-arena preset takes precedence over carry slowdown.

### Arena movement verification

- 18 isolated server tests passed against actual ResourcesService, ResourcesMovement and ResourcesHelpers source with real unparented Roblox Humanoids/parts and fake Player lifecycle signals. Required cases passed: entering empty; gaining/losing resources immediately inside; at/above threshold; leaving while loaded; reentering; and respawning both inside and outside.
- Additional checks cover distinct custom speeds, clamped/missing/invalid counts, copied carry reads, invalid writes, late root creation, rotated circular bounds, vertical bounds, removed geometry, ignoring forged presentation attributes, correcting a competing server property write, duplicate tracking and cleanup/reinitialization.
- 13 resource-spawner regressions passed after sharing the floor geometry helper. Rojo packaging passed: `/tmp/Tycoon-Arena-Movement.rbxlx`.
- The connected Play server exposed `InArena=false`, `CarriedResourceCount=0` and `WalkSpeed=16` for its admitted player outside the circular floor. Tests did not teleport, reset, or change carry quantities for the user's active character. Real multiplayer contact/collection acceptance remains pending with those mechanics.

To reproduce, run `python3 tests/run_movement.py` and execute the emitted Luau bundle through Studio's server command tool (or an Edit-mode loadstring context). Its world/character fixtures are unparented and cleaned up after successful tests.

### Defeat and Departure Drops

- Defeat drops all carried resources; persistent inventory is unaffected.
- Departure also drops all carried resources, using the last valid position if the character is unavailable. Clear carried state once; defeat and departure cannot drop the same resources twice.
- Other players can collect immediately. The original owner waits **3 seconds** by default, configurable per game and enforced by server-owned identity/timing. Respawn does not bypass it.
- Configure drop lifetime per resource, including no expiration. Reject expired pickups. Collection follows the resource's normal destination rule.
- Carried resources are neither saved nor automatically deposited on departure. World drops last only within their server's lifetime.

## Facilities and Processing

### Processing and Storage

Facilities automatically process deposited inputs over time, **one job at a time**. Recipes define inputs, outputs, and positive finite durations. Consume/reserve inputs once and complete each output once.

Input and output storage have per-facility capacities that increase through upgrades. Definitions specify how quantities count toward capacity. Excess deposit quantities remain carried.

Do not start a job unless storage can accept its complete output. Reserve that output capacity for the active job until completion. Pause new work when full, without consuming further inputs or discarding outputs; resume automatically when collection or upgrades free space.

Completed outputs wait at the facility. Owner contact with its collection zone transfers accepted items to inventory and currencies to balances. Remove only successfully transferred outputs; repeated contacts cannot duplicate collection.

### Recipes and Upgrades

Configure recipe selection per facility:

- **Fixed:** Repeat one assigned recipe.
- **Player-selected:** Repeat the saved active selection.
- **Automatic priority:** Choose the highest-priority eligible recipe, using configured order for ties.

Validate selections against allowed recipes and unlocks. Changes affect the next job; active jobs keep their recipe.

Upgrades can improve input capacity, output capacity, processing speed, and recipe unlocks. Support a combined level or separate tracks per facility. Configure stable track IDs, costs, prerequisites, max levels, effects, and explicit combination rules where effects overlap. Save levels and derive capabilities from definitions; upgrades never add concurrent jobs.

Unlocks do not replace a player's recipe selection. Speed upgrades affect active jobs: preserve work already completed at the old speed and recalculate remaining time at the new speed. Never restart or reconsume inputs, or apply the new speed retroactively.

### Offline Progress

Save queued inputs, active work/timing, recipe selection, and uncollected outputs in the profile. On load, reconcile elapsed server time using saved inputs and capacity rules, without duplicate completion.

Reconcile from the timing state of the last successfully saved snapshot. Do not assume departure saved successfully or count an already-processed interval twice. Previously unsaved inputs and progress cannot be recovered from that snapshot.

There is **no offline time limit**. Processing stops when inputs run out or storage prevents work. Outputs wait for contact collection. Time blocked by full storage does not become processing credit after space is freed.

## Player Data

### Profile Ownership and Loading

Use one versioned profile per player for all persistent progress. The player-data service owns loading, saving, migration, and session lifecycle. Feature services manage their sections through its API, without separate saves. Store serializable values with independent defaults; runtime instances and connections stay outside the profile. Preserve disabled features' sections unless explicitly migrated away. Replicate only needed client state, never the complete private profile.

| Situation | Policy |
| --- | --- |
| No existing save | Create a new profile from defaults. |
| Load failure | Default: **3 total attempts**, waiting **1 then 2 seconds**. Configurable per game. If exhausted, disconnect with a clear retry message; never activate or save fallback defaults. |
| Another active session | Retry acquisition for up to **10 seconds** by default, configurable. If still locked, disconnect clearly; never force ownership from a live session. |
| Abandoned lock | Renewable ownership lease with safe crash recovery. A server losing ownership stops profile writes. |

Do not enable persistent gameplay until the profile is loaded, migrated, and validated. Coordinate overlapping saves and session ownership to prevent stale writes.

### Migrations and Invalid Data

Migrate a working copy through explicit, ordered schema versions, preserving progress. Missing defaults may be added, but do not replace migrations for changed structures or meanings.

Failed migrations and unsupported newer versions are not activated or overwritten; disconnect with a compatibility message and record diagnostics. Schema changes do not imply full resets.

After migration, reset invalid sections to independent configured defaults while preserving valid sections. Schemas define reset boundaries. Record what reset and why, then validate dependent references. Do not activate a profile with unresolved invalid references. This policy applies only to successfully loaded data, never failed loads or migrations.

### Saving

- Routine writes occur only on **2-minute autosave** by default (configurable), departure, and shutdown. Stagger player saves and coordinate pending writes with cleanup.
- These triggers govern gameplay-data saves. Session-lock acquisition, renewal, and release may require separate storage operations; they must preserve saved gameplay data and verify session ownership.
- Purchases, upgrades, milestones, and other changes update session state without immediate writes.
- Repeated save failures allow continued gameplay. Notify the player that recent progress may not be preserved; retain unsaved changes and retry with increasing delays and bounded frequency.
- Do not mark failed writes saved or overwrite newer state with stale retry snapshots. Avoid repeated notifications; notify on recovery. Departure/shutdown retries remain bounded by available server lifetime.

### Studio Storage

Support in-memory and separate persistent development storage, defaulting to **in-memory**. Clearly report the active mode; in-memory progress resets with the test session and is not durable. Development persistence uses a separate namespace from live saves. Persistent-mode failure follows normal failure policies without silent in-memory fallback.

## Reference Example and Readiness

Include a small playable example: a currency, resource, recipe, starter facility, and purchasable progression. Use normal configuration and replaceable assets; core code must not depend on example IDs. Optional features are unnecessary for this loop:

**Join → receive a base → collect → deposit/process → collect outputs → purchase an upgrade → save → rejoin with progress restored.**

Foundation is ready for future games after Roblox Studio verification of this loop, multiplayer isolation, lifecycle cleanup, safe load/save failures, session protection, invalid/repeated request handling, independently disabled optional features, and configuration-only example content changes. Record results and limitations; existing files are not assumed compliant until checked.

## Transactions and Economy Rules

An operation that changes multiple persistent sections must commit all changes in one non-yielding profile transaction. Examples include buying a building, selling items, upgrading a facility, and collecting mixed item/currency outputs. Independent successful service calls do not provide rollback for a combined operation. No deduction or reward occurs on a rejected transaction.

World interactions also need a server-side claim or equivalent serialization around pickups, deposits, and collection. Coordinate temporary carried/world state with profile commits so failure leaves quantities available exactly once. Do not yield between validating ownership and committing the state transition. Publish visuals and client updates after the authoritative result is known.

Use configured numeric limits for balances, quantities, costs, and derived arithmetic. Reject overflow, non-finite results, and precision violations before committing. Currency precision specifies valid increments; it is not permission to silently round a purchase. Capacity acceptance is deterministic: configured resource/item order, then stable instance ID for unique items. Zero accepted units causes no state change.

### Selling Inventory

Games may configure stackable inventory items with currency sale rewards. Selling is owner-initiated through UI, uses positive whole quantities, and atomically removes owned items and grants configured rewards. Unsellable items remain visible with clear feedback. Currency rewards come from server definitions; clients never provide prices.

Unique-item sales are outside the default sale contract. A game enabling them must specify instance selection, property-based valuation, and ownership validation. Selling never removes carried resources or facility storage implicitly.

## UI and Client State

### Reusable Interface

| Surface | Required information and actions |
| --- | --- |
| Loading and availability | Profile loading, startup failure, save warning/recovery, and clear interaction gating. |
| HUD | Configured currency balances, base level, and access to inventory and progression. |
| Inventory | Owned stack quantities and unique instances, capacity, empty state, and configured sale actions. |
| Base purchases | Slot/building identity, cost, requirements, current state, and purchase result. |
| Facility | Input/output storage, active recipe, progress, blocked reason, recipe selection, and available upgrades. |
| Progression | Current levels, next effects, costs, unmet requirements, and max-level state. |
| Feedback | Useful pending, success, failure, unavailable, and full-storage messages. |

Use display metadata from definitions and reusable components. A game's theme supplies labels, icons, colors, models, and sounds. World prompts and menus invoke the same server operations. Full inventory must explain why collection stopped; a locked purchase must explain its unmet requirements.

Support mouse/keyboard, touch, and gamepad with readable scaling, safe screen insets, reachable controls, visible focus, and scrolling for long catalogs. Do not communicate ownership, affordability, or errors through color alone. Preserve selections, focused text entry, and scroll position during updates. Respawn must not duplicate screens or connections.

### Readiness and State Projection

Client states are loading, ready, and unavailable. Enable gameplay controls only after the server admits the profile, restores the base, and sends the required initial projection. World actions must enforce the same readiness on the server. Save warnings do not revoke an otherwise valid session; ownership loss does.

Replicate an allowlisted projection containing only the player's needed balances, inventory display data, progression, owned facility state, and action availability. Other players receive only public presentation such as base appearance. Do not expose session locks, storage keys, internal diagnostics, hidden unique-item properties, or another player's private economy.

The target synchronization contract is an initial snapshot followed by server updates with a per-session monotonically increasing revision. Each delta identifies its base and resulting revision. Ignore older updates; request a fresh snapshot on a revision gap. A snapshot replaces the projected state. Bound resynchronization requests and payload size. A new session has a new revision scope, so reconnecting cannot apply stale updates from the old session.

The existing economy UI polls a filtered snapshot; revisioned updates are future implementation work. A polling implementation may remain a documented game choice if it preserves correctness, input stability, and bounded request load.

Animate progress locally from server-provided work and speed, then correct against authoritative updates. Display estimates never complete jobs, grant outputs, or confirm purchases. Refresh action availability after each committed change.

### Requests and Results

Each mutating request uses a feature-qualified operation, validated IDs/quantities, and a session-scoped request sequence. Return a stable result code and safe display information; map codes to game-specific text. Baseline codes include `NotReady`, `InvalidRequest`, `NotOwner`, `TooFar`, `Locked`, `InsufficientFunds`, `CapacityFull`, `AlreadyOwned`, `MaxLevel`, `RateLimited`, and `Unavailable`.

For retryable mutations, remember the latest sequence, payload, and result per operation stream. A matching replay returns its previous result; reusing an ID for another payload or submitting an older sequence cannot mutate state. Serialize requests within each stream and bound retained state. Rate limiting must not turn a completed retry into a second operation. Remove request state at session cleanup. This protection lasts for the session; durable external grants require a separate persistent identity.

Clients show pending feedback and retry an uncertain request with the same payload and identity. They must not assume a timeout means failure or optimistically subtract authoritative balances. Configure per-operation limits; enforce type/size bounds before expensive work and validate all gameplay conditions independently of the UI.

## Resource Presentation Defaults

Each resource definition provides a display name, pickup model, carried model or reusable fallback, scale, and optional icon/sound. Primitive example assets must communicate resource identity without external asset permissions. Visual size does not change reward quantity, weight, or collection reach.

The default visible carry cap is **20 units total per character**. Display mixed resources in stable resource-ID order, oldest layer nearest the head; only the visual subset is capped. Derive visual units from aggregate carried quantities, without creating one object per actual unit. Update incrementally where practical. Carry models are non-colliding, cannot trigger pickups, and cannot block movement or camera interaction. Clear them on defeat, deposit, departure, and character replacement; recreate them from current carried state when needed.

Default movement settings are outside speed 16, empty arena speed 16, minimum arena speed 4, and a threshold of 30 carried units. Slowdown applies inside the configured arena only; outside speed always uses its independent preset. See [Carry Presentation and Movement](#carry-presentation-and-movement) for the formula and server API.

ResourcesMovement is the current single owner of player movement speed. It enforces the arena calculation or the outside preset. General movement modifiers and locks are not implemented; adding them requires an explicit precedence policy and integration into this owner. Other systems must not add competing WalkSpeed writers.

## Optional Feature Contracts

All optional features default off. Enabling one requires its validated catalogs, dependencies, profile section where needed, request validation, UI, and acceptance checks. A disabled feature starts no tasks, creates no feature remotes or world assets, and leaves its saved section intact. Core catalogs cannot require disabled content. Invalid dependency combinations fail startup clearly.

| Feature | Contract when enabled |
| --- | --- |
| Companions | Owned, equippable game-specific assets with configured behaviors. Follow, Base, and Fight use the contract below. Fight requires Combat; Follow and Base do not. |
| Combat | Configure targets, teams, damage, range, cooldowns, and defeat rules. Server validates hits, eligibility, range, and timing. Default player damage is off outside explicitly configured combat areas. Defeat invokes the carried-resource drop operation once; persistent inventory, currency, and buildings remain intact. Temporary combat state clears on respawn/leave. |
| Arena | Requires Combat. Configure bounds, entry/exit, participant limits, scheduling, and rewards. Server owns membership and event results; each event/reward has a deduplication identity. Leaving, defeat, and shutdown release participation. Base assignment and core resource zones work without an arena. |
| Rebirth | Configure eligibility, confirmation summary, reward, reset boundaries, and retained sections. Default retained state is rebirth count, permanent rebirth rewards, and unrelated optional ownership; the game must explicitly declare every reset section before enabling. Atomically validate and apply the reset/reward, then rebuild the world from committed state. Serialize against purchases/processing and clear affected carried state. No rebirth runs with an unresolved active operation. |

Optional rewards enter the normal currency/inventory APIs and respect their limits. Optional modifiers use explicit stacking rules; they cannot silently replace core prices, capacity, or movement behavior. In-progress jobs keep the completion semantics established by Facilities. If a game changes those semantics, document and verify the override.

## Companion

A **Companion** is an owned, equippable, game-specific asset with a defined behavior. It may be a creature, worker, robot, vehicle, floating object, or another themed asset. The foundation does not assume a pet, a humanoid rig, rarity, leveling, or combat stats.

### Scaffolding Tycoon Companion Cards

This game's companion cards extend the generic Companion contract with four types: **Electric, Water, Gravity, and Magneto**. Each type has **Common, Rare, Epic, and Legendary** variants, for **16 cards total**.

Every card displays separate stat bars for **Damage, Stamina, and Health**. Rarity determines the maximum level of each individual stat:

| Rarity | Damage maximum | Stamina maximum | Health maximum |
| --- | ---: | ---: | ---: |
| Common | 20 | 20 | 20 |
| Rare | 25 | 25 | 25 |
| Epic | 30 | 30 | 30 |
| Legendary | 36 | 36 | 36 |

These are per-stat level caps, not starting values, a shared stat-point budget, or defined combat units. Starting values, progression rules, and conversion from stat levels to gameplay effects remain unspecified.

Use the images in [Reference_Image](Reference_Image/) as visual references. All 16 cards must share consistent texturing, pixel size/density, and an overall art style so they visibly belong to the same game. Keep the pixel grid, shading treatment, border treatment, typography, and layout consistent across types and rarities; type and rarity variations must preserve that shared visual language. Exact pixel dimensions and rarity colors remain to be selected.

### Companion Rigs, IK, and Animation

Implemented and playtested in Studio for all **16 companion templates** in `ServerStorage.CompanionModels` and their copies in `Workspace.Development.CompanionModelGallery`. Each model has 14 `Motor6D` joints, welded decorative parts, an `AnimationController`/`Animator`, and two foot `IKControl` chains with knee poles. Original templates are backed up in `ServerStorage.CompanionModels_BeforeIK`.

[CompanionAnimation.luau](src/client/Features/Companion/CompanionAnimation.luau), started by `Main.client.luau`, provides procedural idle, walking, and cosmetic attack poses without uploaded animation IDs. It adjusts foot targets to nearby ground heights and handles streamed models. This presentation currently also runs for authored gallery models while the optional Companion gameplay feature is disabled; ownership, equipping, following, and combat timing remain pending.

To preview, select a gallery companion, set its `CompanionAnimationState` attribute to `Walk`, and press **Play**. Supported states are `Auto` (idle while stationary, walk when the root moves), `Idle`, `Walk`, and `Attack`. Set `CompanionAnimationEnabled` to `false` to reset poses and disable IK. `CompanionStride`, `CompanionStepHeight`, and `CompanionWalkSpeed` tune movement presentation. Foot IK supports small height changes; feet remain level rather than matching slope normals.

See [Companion Animation Verification](COMPANION_ANIMATION_VERIFICATION.md) for Play-mode results, limitations, attributes, and source locations. [RigCompanions.luau](tools/RigCompanions.luau) reproduces the rig setup in Studio Edit mode. These changes have not been published to the experience.

### Companion Concepts

Keep three concepts separate:

- **Definition:** Shared content such as appearance, supported behaviors, default behavior, and optional capabilities. Example ID: `companion.helper_bot`.
- **Owned instance:** One player's unique copy, identified by a server-generated instance ID. Copies of the same definition can have different configured properties.
- **Equipped deployment:** The runtime representation of that owned instance and its currently selected behavior. Unequipping removes the deployment, not ownership.

### Ownership and Equipping

Represent owned companions as unique inventory items with companion definition references. Inventory owns instance identity and properties; Companion owns equipped selections and behavior rules. Do not maintain a second competing ownership catalog in the profile.

Persist equipped instance IDs and selected behavior by instance ID in the Companion profile section. Models, positions, paths, targets, connections, and combat timers are temporary. Restore valid equipped selections after profile admission and base readiness, then create runtime deployments. Invalid saved references follow the profile validation/reset policy; never silently create replacement ownership.

The default equip limit is **one companion per player**, configurable per game. The limit counts all equipped companions, including those in Base behavior. An owned instance can have only one deployment and one selected behavior at a time. Inventory ownership alone grants no active effects.

The server validates ownership, readiness, supported behavior, equip capacity, and required dependencies for every equip or behavior request. Equipping another companion at capacity returns `CapacityFull`; replacement requires an explicit swap operation that validates the complete change before committing. Unequipping is allowed while a behavior is active and cancels its runtime work safely.

No default mechanic destroys, trades, sells, or consumes companions. A game adding one must atomically clear affected equipped selections alongside the ownership change and remove its runtime effects. Fusion, acquisition recipes, rarity, and individual progression are extensions rather than requirements of Companion.

### Behaviors

A behavior describes what an equipped companion does, rather than a separate companion type. A definition may support one or several behaviors. Its configured default must belong to its supported set. Players may select among supported behaviors through UI; a single-behavior companion needs no behavior selector.

| Behavior | Baseline operation | Boundary |
| --- | --- | --- |
| **Follow** | Accompany the owner using a configured offset or formation position. Stop or idle when within the follow distance; recover when stuck or beyond the configured leash. | Following alone grants no collection, production, or combat effects. |
| **Base** | Remain within the owner's base at a configured anchor or bounded roaming area. Stay there while the owner moves elsewhere. | Default is presence/idle only. A worker task or production modifier must be explicitly configured. |
| **Fight** | Accompany the owner, acquire an eligible target within the configured detection range, and attack through Combat. Return to following when no eligible target exists. | Requires Combat. Obey damage permissions, attack range/cooldown, target validity, and an owner leash; never pursue indefinitely. |

Base behavior does not place a permanent building or consume a building slot. A game may define stable companion anchors separately from building slots. Resolve those anchors against the current layout so expansion preserves assignments. Base companions cannot visit or operate another player's base by default.

Fight is a general behavior, not an alias for Arena. A game may permit it in an arena, a PvE region, or another configured combat area. Arena membership is an additional eligibility rule only when that game uses Arena. A target outside the permitted area or owner leash is released immediately. Default automatic targeting uses the nearest eligible hostile, breaking distance ties with a stable server-owned target ID. Revalidate before every attack; clients never supply authoritative hits or damage.

Switching behavior cancels the old behavior's paths, targets, tasks, and modifiers before the new one starts. It does not create a second deployment, reset attack cooldowns, heal the companion, or grant a reward. Preserve relevant transient combat state across switching and re-equipping so those actions cannot bypass combat rules.

### Configuration and Game-Specific Behavior

Each definition declares:

| Field group | Required decision |
| --- | --- |
| Identity and presentation | Stable definition ID, display name, model reference, movement style, and optional behavior animation references. |
| Behaviors | Supported behavior IDs, default behavior, and behavior-specific parameters. |
| Follow | Offset/formation spacing, follow distance, movement speed, leash distance, and stuck/recovery policy. |
| Base | Anchor or roaming policy, allowed bounds, and any explicit task/effect. |
| Fight, when supported | Combat definition reference, detection/attack ranges, cooldown, leash, target eligibility, and defeat/recovery policy. |
| Optional properties | Validated instance properties and any progression, effects, or acquisition rules the game enables. |

Use finite, bounded numeric parameters and validate cross-references during startup. Ground followers may use pathfinding; flying or floating companions may use another movement implementation. Do not require humanoids or ground navigation for every definition.

Game-specific behavior handlers implement enter, update, and exit/cleanup through Companion's service lifecycle. Configuration selects registered handlers and their parameters; it does not execute arbitrary scripts or load client-selected modules. Adding a new behavior can require game-specific code without changing ownership/equip semantics.

Additional capabilities are explicit. For example, resource collection assistance must use normal server pickup claims and configured owner/destination rules; it cannot grant resources merely because a visual touched them. A Base production bonus must declare its facility scope, magnitude, stacking rule, and removal conditions. Do not assume Follow collects, Base produces, or Fight awards loot.

### Authority, Lifecycle, and Presentation

The server owns equip state, selected behavior, targets, effects, and all gameplay outcomes. Clients can interpolate movement and play animations from public deployment state. Client-controlled physics or animation cannot establish attack hits, collection eligibility, or production work. Default companion models do not collide with players, obstruct travel, or trigger player-only contact interactions.

On owner defeat, suspend Follow and Fight deployments until respawn, then resume their selected behaviors at the new character. Base deployments remain at the base. Temporary suspension does not erase the equipped selection. A game enabling companion health must define recovery timing and preserve that state across equip changes; instant healing by toggling is disallowed.

On base rebuild, rebind Base deployments to valid current-layout anchors. On departure, session ownership loss, feature destruction, or startup rollback, stop all owned behavior work and remove deployments/effects. Companion ownership and equipped selections remain subject to normal saving. No companion work or rewards accrue offline by default; any offline production extension must integrate with Facilities reconciliation rather than run a second elapsed-time calculation.

UI shows owned companions, equipped state, supported/selected behavior, and useful unavailable reasons. Public replication includes only the deployment identity, owner, appearance, and presentation state needed by other clients; private instance properties remain filtered.

### Companion Acceptance Checks

- Equip an owned instance, reject an unowned one, enforce the configured limit, and restore selections on rejoin without duplicate models.
- Switch Follow → Base → Fight where supported; verify only the selected behavior runs and unsupported behaviors fail without state changes.
- Move, teleport, respawn, and expand the base; verify follow recovery, base bounds, anchor restoration, and cleanup.
- Reject Fight configuration when Combat is disabled while allowing Follow/Base-only definitions without Combat or Arena.
- Test invalid targets, restricted areas, leash limits, and repeated switching/equipping; no extra attacks, cooldown bypass, or unintended healing occurs.
- Unequip, leave, lose session ownership, and disable the feature; no tasks, targets, modifiers, or deployments remain active.

## Game Adaptation Contract

Before building a specific game, record the following in its repository:

| Decision | Required definition |
| --- | --- |
| Identity and persistence | Game ID, title, storage namespaces, schema version, development/live separation. |
| Core loop | What players collect, process, earn, and spend; the next visible progression goal. |
| Content | Stable currency/item/resource/recipe/building/slot IDs, cross-references, display metadata, and assets. |
| Economy | Starting balances, precision/limits, costs, sale rewards, processing yields/durations, and capacity accounting. |
| World | Base count/spacing/layouts, safe spawns, zones, contact volumes, and interaction distances. |
| Progression | Base levels, permanent placements, upgrade tracks, unlock prerequisites, and terminal levels. |
| Presentation | UI theme, supported inputs, carry visuals, feedback, and movement settings. |
| Optional behavior | Enabled features, dependencies, persistence/reset rules, and any deliberate core overrides. |

An upgrade definition must show a measurable next benefit and a finite non-negative cost; free levels are explicit. Reject prerequisite cycles, unreachable required content, invalid level ranges, and capacity reductions that invalidate existing state. At max progression, hide or disable further purchases with a clear max-level state. Reaching the end does not reset progress automatically.

Balance is game-specific. Use a small progression sheet/table to record expected collection throughput, processing throughput, capacity, and time to each purchase. Check the bottleneck across the entire loop; faster processing has no benefit if input collection cannot feed it. Record assumptions without treating a chosen pace as an engine rule.

## Verification and Completion Criteria

The following are target acceptance checks, not claims that the scaffold passes. Record date, configuration, storage mode, player count, actual result, and unresolved limitations. Use isolated development saves for destructive/failure tests.

| Area | Required check and passing result |
| --- | --- |
| New player | Fresh profile grants starters once, assigns one base, and makes the first collection/deposit/purchase goal understandable. |
| Reference loop | Complete the documented loop in Studio, save, join a new server in persistent development mode, and restore exact progression. |
| Multiplayer | At least two clients cannot buy, deposit, collect outputs, or request private state from each other's bases. |
| Contention | Simultaneous pickup contacts and repeated purchase/deposit/collection requests produce one valid transfer with no loss or duplication. |
| Inventory and money | Test invalid/non-finite values, precision, caps, insufficient funds, unique ownership, and failed mixed rewards; no partial commit occurs. |
| Layouts | Every layout stage fits all permanent slots and neighbors; progression/rejoin preserves placements, storage, and safe spawns. |
| Resource lifecycle | Spawn delays/caps/lifetimes behave as configured; expiration and collection free capacity once; owner cooldown survives respawn. |
| Carrying and movement | Mixed carries exceed the visual cap without losing quantity; slowdown, zone changes, modifiers, defeat, and departure remain consistent. |
| Facilities | Test each recipe mode, full output storage, partial collection, speed upgrades mid-job, and repeated completion callbacks. Inputs/outputs remain conserved. |
| Offline work | Compare known snapshots for short/long absence, exhausted inputs, blocked outputs, and repeated loads; elapsed intervals count once and blocked time gives no later credit. |
| Persistence failures | Failed loads/migrations never admit defaults; competing sessions cannot both write; save failure/recovery preserves dirty session state and reports status. |
| UI and network | Test touch/gamepad/desktop, focused entry during refresh, delayed/lost responses, retries, resync gaps, respawn, and private projection filtering. |
| Cleanup | Repeated joins, leaves, respawns, and startup failures leave no stale bases, tasks, connections, request state, or world instances. |
| Optional features | Run the core loop with all optional features off, then test each supported enabled combination and its declared dependencies. |
| Copy and retheme | Copy to a separate repository, replace example IDs/assets/configuration, build, and run the loop without editing core services. |

Use pure/helper and mocked service tests for calculations, validation, migrations, transaction rollback, and replay handling. Use Roblox Studio for actual contacts, replication, GUI, physics, lifecycle, and storage integration. A successful build is a packaging check. A release requires both the relevant automated checks and recorded Studio acceptance results.

The README is the reusable design baseline. Implementation is complete only when the configured example is playable, the acceptance evidence is recorded, and outstanding limitations are explicit in the delivery checklist.

## File and Script Reference

This inventory describes every existing project file, including generated/hidden project files, as of 2026-10-27. Git internal files under `.git/` are excluded. Update this section when adding, renaming, removing, or changing a file’s responsibility. Descriptions distinguish current implementation from planned behavior; a lifecycle scaffold is not a completed feature.

Only `src/server/Main.server.luau` and `src/client/Main.client.luau` execute automatically. Other active Luau files are required modules. Archived scripts are outside the Rojo tree and must not run alongside active startup. Studio-authored models and attributes are separate from these filesystem files.

### Project files and documentation

| File | Feature / current use |
| --- | --- |
| [.gitignore](.gitignore) | Excludes macOS metadata, generated sourcemaps, logs, and local editor settings from Git. |
| [README.md](README.md) | Project design authority: reusable gameplay contracts, architecture, zone assignments, acceptance criteria, and this complete file reference. |
| [default.project.json](default.project.json) | Rojo project mapping for active shared, server, and client source; archive is excluded. |
| [licenses/ProfileStore-LICENSE.txt](licenses/ProfileStore-LICENSE.txt) | License terms for the vendored ProfileStore dependency. |
| [selene.toml](selene.toml) | Selects Roblox standard-library definitions for Selene linting. |
| [sourcemap.json](sourcemap.json) | Generated Rojo mapping between source files and Roblox instances; regenerate rather than edit manually. |

### Active entry points and GUI directory

| File | Feature / current use |
| --- | --- |
| [src/client/Main.client.luau](src/client/Main.client.luau) | Automatic client entry point; selects enabled client features and runs ordered lifecycle startup. |
| [src/gui/.gitkeep](src/gui/.gitkeep) | Keeps the otherwise empty GUI directory in Git; active interfaces are created by client modules. |
| [src/server/Main.server.luau](src/server/Main.server.luau) | Automatic server entry point; selects enabled features and runs ordered lifecycle startup. |

### Shared definitions and helpers

| File | Feature / current use |
| --- | --- |
| [src/shared/Features/Arena/ArenaConfig.luau](src/shared/Features/Arena/ArenaConfig.luau) | Disabled optional Arena configuration scaffold; no complete content catalog yet. |
| [src/shared/Features/Base/BaseConfig.luau](src/shared/Features/Base/BaseConfig.luau) | Defines 13 authored plot paths, four level models, spawn offsets, level costs, and upgrade limits; building-slot and starter catalogs remain empty. |
| [src/shared/Features/Combat/CombatConfig.luau](src/shared/Features/Combat/CombatConfig.luau) | Disabled optional Combat configuration scaffold; no complete content catalog yet. |
| [src/shared/Features/Companion/CompanionConfig.luau](src/shared/Features/Companion/CompanionConfig.luau) | Disabled optional Companion configuration scaffold; no complete content catalog yet. |
| [src/shared/Features/Currency/CurrencyConfig.luau](src/shared/Features/Currency/CurrencyConfig.luau) | Defines currency IDs, display names, starting balances, precision, and numeric limits. |
| [src/shared/Features/Currency/CurrencyHelpers.luau](src/shared/Features/Currency/CurrencyHelpers.luau) | Validates currency configuration and amounts; applies grants and multi-currency deductions to transaction drafts. |
| [src/shared/Features/Facilities/FacilitiesConfig.luau](src/shared/Features/Facilities/FacilitiesConfig.luau) | Placeholder facility/recipe catalogs and processing settings; playable facility content is pending. |
| [src/shared/Features/Game/GameConfig.luau](src/shared/Features/Game/GameConfig.luau) | Defines game identity and central enabled-feature switches. |
| [src/shared/Features/Inventory/InventoryConfig.luau](src/shared/Features/Inventory/InventoryConfig.luau) | Defines item catalogs, stack/unique capacity limits, properties, and sale rewards. |
| [src/shared/Features/Inventory/InventoryHelpers.luau](src/shared/Features/Inventory/InventoryHelpers.luau) | Validates quantities, properties, catalogs, and inventory state; counts capacity and applies draft grants/removals. |
| [src/shared/Features/Lifecycle/LifecycleHelpers.luau](src/shared/Features/Lifecycle/LifecycleHelpers.luau) | Runs Initialize then Start in order and performs reverse cleanup after failure or shutdown. |
| [src/shared/Features/Networking/NetworkingConfig.luau](src/shared/Features/Networking/NetworkingConfig.luau) | Central registry of feature-owned remote names/types and lookup settings. |
| [src/shared/Features/Networking/NetworkingHelpers.luau](src/shared/Features/Networking/NetworkingHelpers.luau) | Resolves registered remotes through the shared networking lookup API. |
| [src/shared/Features/PlayerData/PlayerDataConfig.luau](src/shared/Features/PlayerData/PlayerDataConfig.luau) | Defines schema/storage namespaces, Studio storage mode, retry/session timing, autosave, and serialization limits. |
| [src/shared/Features/PlayerData/PlayerDataHelpers.luau](src/shared/Features/PlayerData/PlayerDataHelpers.luau) | Provides recursive table copy, freeze, and missing-default reconciliation helpers. |
| [src/shared/Features/PlayerData/PlayerDataTemplate.luau](src/shared/Features/PlayerData/PlayerDataTemplate.luau) | Defines the generic saved-profile type and initial section defaults. |
| [src/shared/Features/Rebirth/RebirthConfig.luau](src/shared/Features/Rebirth/RebirthConfig.luau) | Disabled optional Rebirth configuration scaffold; no complete content catalog yet. |
| [src/shared/Features/Resources/ResourcesConfig.luau](src/shared/Features/Resources/ResourcesConfig.luau) | Defines ore pickup assets, arena spawning zone, weights/timing/caps, carrying presentation, slowdown, and owner cooldown defaults. |
| [src/shared/Features/Resources/ResourcesHelpers.luau](src/shared/Features/Resources/ResourcesHelpers.luau) | Validates movement settings, calculates capped arena slowdown, and shares horizontal floor geometry and membership checks. |
| [src/shared/Features/UI/UIConfig.luau](src/shared/Features/UI/UIConfig.luau) | Configures UI refresh/request limits, row bounds, and presentation-only shop offers. |
| [src/shared/Features/Upgrades/UpgradesConfig.luau](src/shared/Features/Upgrades/UpgradesConfig.luau) | Empty upgrade catalog with currency-only cost policy. |

### Server features

| File | Feature / current use |
| --- | --- |
| [src/server/Features/Arena/ArenaServer.luau](src/server/Features/Arena/ArenaServer.luau) | Initializes/destroys the Arena service and guards lifecycle calls; feature event wiring remains a placeholder. |
| [src/server/Features/Arena/ArenaService.luau](src/server/Features/Arena/ArenaService.luau) | Arena service lifecycle scaffold; gameplay rules are not implemented. |
| [src/server/Features/Base/BaseModels.luau](src/server/Features/Base/BaseModels.luau) | Resolves/loads model assets, validates floors, derives plot origins, and creates positioned level structures. |
| [src/server/Features/Base/BaseServer.luau](src/server/Features/Base/BaseServer.luau) | Wires player readiness, character spawning, upgrade prompts, and base lifecycle cleanup. |
| [src/server/Features/Base/BaseService.luau](src/server/Features/Base/BaseService.luau) | Owns plot assignment, saved-level restoration, spawn positioning, release, and atomic base-level purchases; building placement remains unimplemented. |
| [src/server/Features/Combat/CombatServer.luau](src/server/Features/Combat/CombatServer.luau) | Initializes/destroys the Combat service and guards lifecycle calls; feature event wiring remains a placeholder. |
| [src/server/Features/Combat/CombatService.luau](src/server/Features/Combat/CombatService.luau) | Combat service lifecycle scaffold; gameplay rules are not implemented. |
| [src/server/Features/Companion/CompanionServer.luau](src/server/Features/Companion/CompanionServer.luau) | Initializes/destroys the Companion service and guards lifecycle calls; feature event wiring remains a placeholder. |
| [src/server/Features/Companion/CompanionService.luau](src/server/Features/Companion/CompanionService.luau) | Companion service lifecycle scaffold; gameplay rules are not implemented. |
| [src/server/Features/Currency/CurrencyServer.luau](src/server/Features/Currency/CurrencyServer.luau) | Initializes/destroys the Currency service and guards lifecycle calls; feature event wiring remains a placeholder. |
| [src/server/Features/Currency/CurrencyService.luau](src/server/Features/Currency/CurrencyService.luau) | Reads balances and performs validated currency grants/spends through profile transactions. |
| [src/server/Features/Facilities/FacilitiesServer.luau](src/server/Features/Facilities/FacilitiesServer.luau) | Initializes/destroys the Facilities service and guards lifecycle calls; feature event wiring remains a placeholder. |
| [src/server/Features/Facilities/FacilitiesService.luau](src/server/Features/Facilities/FacilitiesService.luau) | Facility lifecycle scaffold; deposit, output collection, recipe selection, offline reconciliation, and upgrades explicitly return NotImplemented. |
| [src/server/Features/Inventory/InventoryServer.luau](src/server/Features/Inventory/InventoryServer.luau) | Handles inventory sale requests, applies request limits, and clears departing-player request state. |
| [src/server/Features/Inventory/InventoryService.luau](src/server/Features/Inventory/InventoryService.luau) | Reads, grants, removes, and checks inventory; performs atomic item sales with session request replay protection. |
| [src/server/Features/Networking/NetworkingServer.luau](src/server/Features/Networking/NetworkingServer.luau) | Creates enabled features’ registered remotes and removes owned networking instances during cleanup. |
| [src/server/Features/PlayerData/PlayerDataSchema.luau](src/server/Features/PlayerData/PlayerDataSchema.luau) | Creates independent defaults and validates serializability, schema versions, migration hooks, and section reset boundaries. |
| [src/server/Features/PlayerData/PlayerDataServer.luau](src/server/Features/PlayerData/PlayerDataServer.luau) | Connects player join/leave and server shutdown to profile loading and release. |
| [src/server/Features/PlayerData/PlayerDataService.luau](src/server/Features/PlayerData/PlayerDataService.luau) | Owns profile admission, memory/persistent sessions, validated transactions, saving, retries, status, and session release. |
| [src/server/Features/PlayerData/Vendor/ProfileStore.luau](src/server/Features/PlayerData/Vendor/ProfileStore.luau) | Vendored persistence library providing session locks, DataStore operations, autosaves, and final saves; see [Third-party code and attribution](#third-party-code). |
| [src/server/Features/Rebirth/RebirthServer.luau](src/server/Features/Rebirth/RebirthServer.luau) | Initializes/destroys the Rebirth service and guards lifecycle calls; feature event wiring remains a placeholder. |
| [src/server/Features/Rebirth/RebirthService.luau](src/server/Features/Rebirth/RebirthService.luau) | Rebirth service lifecycle scaffold; gameplay rules are not implemented. |
| [src/server/Features/Resources/ResourcesServer.luau](src/server/Features/Resources/ResourcesServer.luau) | Wires player movement tracking and cleanup, starts spawn schedules, and drives movement/spawning through one Heartbeat. |
| [src/server/Features/Resources/ResourcesService.luau](src/server/Features/Resources/ResourcesService.luau) | Owns session carried-resource quantities through SetCarried/GetCarried and exposes movement/spawner lifecycle APIs; collection, carry visuals, deposit, and drops remain pending. |
| [src/server/Features/Resources/ResourcesMovement.luau](src/server/Features/Resources/ResourcesMovement.luau) | Enforces server-authoritative player speed from arena membership and carried units; owns character/root listeners and cleanup. |
| [src/server/Features/Resources/ResourcesSpawner.luau](src/server/Features/Resources/ResourcesSpawner.luau) | Validates resource zones/assets and manages delayed weighted spawning, placement attempts, caps, expiration, and cleanup. |
| [src/server/Features/UI/UIServer.luau](src/server/Features/UI/UIServer.luau) | Serves bounded UI state requests and cleans up request handling. |
| [src/server/Features/UI/UIService.luau](src/server/Features/UI/UIService.luau) | Builds an allowlisted owner-visible economy snapshot without exposing the complete private profile. |
| [src/server/Features/Upgrades/UpgradesServer.luau](src/server/Features/Upgrades/UpgradesServer.luau) | Initializes/destroys the Upgrades service and guards lifecycle calls; feature event wiring remains a placeholder. |
| [src/server/Features/Upgrades/UpgradesService.luau](src/server/Features/Upgrades/UpgradesService.luau) | Generic upgrade lifecycle scaffold; Purchase explicitly returns NotImplemented (base-level purchases use BaseService). |

### Client features

| File | Feature / current use |
| --- | --- |
| [src/client/Features/Arena/ArenaClient.luau](src/client/Features/Arena/ArenaClient.luau) | Arena client lifecycle scaffold; feature-specific input/presentation wiring remains pending (current economy UI lives in UIClient). |
| [src/client/Features/Base/BaseClient.luau](src/client/Features/Base/BaseClient.luau) | Base client lifecycle scaffold; feature-specific input/presentation wiring remains pending (current economy UI lives in UIClient). |
| [src/client/Features/Combat/CombatClient.luau](src/client/Features/Combat/CombatClient.luau) | Combat client lifecycle scaffold; feature-specific input/presentation wiring remains pending (current economy UI lives in UIClient). |
| [src/client/Features/Companion/CompanionClient.luau](src/client/Features/Companion/CompanionClient.luau) | Companion client lifecycle scaffold; feature-specific input/presentation wiring remains pending (current economy UI lives in UIClient). |
| [src/client/Features/Currency/CurrencyClient.luau](src/client/Features/Currency/CurrencyClient.luau) | Currency client lifecycle scaffold; feature-specific input/presentation wiring remains pending (current economy UI lives in UIClient). |
| [src/client/Features/Facilities/FacilitiesClient.luau](src/client/Features/Facilities/FacilitiesClient.luau) | Facilities client lifecycle scaffold; feature-specific input/presentation wiring remains pending (current economy UI lives in UIClient). |
| [src/client/Features/Inventory/InventoryClient.luau](src/client/Features/Inventory/InventoryClient.luau) | Inventory client lifecycle scaffold; feature-specific input/presentation wiring remains pending (current economy UI lives in UIClient). |
| [src/client/Features/Networking/NetworkingClient.luau](src/client/Features/Networking/NetworkingClient.luau) | Waits for required registered remotes during client startup. |
| [src/client/Features/PlayerData/PlayerDataClient.luau](src/client/Features/PlayerData/PlayerDataClient.luau) | Creates and updates loading, unavailable, save-warning, and recovery status presentation. |
| [src/client/Features/Rebirth/RebirthClient.luau](src/client/Features/Rebirth/RebirthClient.luau) | Rebirth client lifecycle scaffold; feature-specific input/presentation wiring remains pending (current economy UI lives in UIClient). |
| [src/client/Features/Resources/ResourcesClient.luau](src/client/Features/Resources/ResourcesClient.luau) | Resources client lifecycle scaffold; feature-specific input/presentation wiring remains pending (current economy UI lives in UIClient). |
| [src/client/Features/UI/UIClient.luau](src/client/Features/UI/UIClient.luau) | Creates General sidebar tabs for Inventory, Stats, and read-only Shop Offers; polls state and handles selling/pending feedback and cleanup. |
| [src/client/Features/Upgrades/UpgradesClient.luau](src/client/Features/Upgrades/UpgradesClient.luau) | Upgrades client lifecycle scaffold; feature-specific input/presentation wiring remains pending (current economy UI lives in UIClient). |

### Tests and runners

| File | Feature / current use |
| --- | --- |
| [tests/bases.spec.luau](tests/bases.spec.luau) | Mocked regression cases for plot assignment, restoration, upgrades, spawning, and rollback; does not establish real Studio integration readiness. |
| [tests/economy.spec.luau](tests/economy.spec.luau) | Mocked regression cases for currency/inventory validation, transactions, sales, replay handling, and filtered state; does not establish real Studio integration readiness. |
| [tests/player_data.spec.luau](tests/player_data.spec.luau) | Mocked regression cases for schema, memory/persistent adapter, session, and failure handling; does not establish real Studio integration readiness. |
| [tests/resources.spec.luau](tests/resources.spec.luau) | Mocked regression cases for spawn configuration, weighted selection, timing/caps, placement, lifetime, and cleanup; does not establish real Studio integration readiness. |
| [tests/run_bases.py](tests/run_bases.py) | Builds an isolated Studio loadstring bundle from actual source and the bases regression fixtures. |
| [tests/run_economy.py](tests/run_economy.py) | Bundles actual source with mocked Roblox services and runs the economy suite using a Luau CLI. |
| [tests/run_player_data.py](tests/run_player_data.py) | Bundles actual source with mocked Roblox services and runs the player_data suite using a Luau CLI. |
| [tests/run_resources.py](tests/run_resources.py) | Builds an isolated Studio loadstring bundle from actual source and the resources regression fixtures. |

### Archived source and documentation

| File | Feature / current use |
| --- | --- |
| [archive/pre-foundation-src/client/Controllers/ArenaController.luau](archive/pre-foundation-src/client/Controllers/ArenaController.luau) | Arena entry/exit, status, and event-timer client API stubs. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/client/Controllers/BaseController.luau](archive/pre-foundation-src/client/Controllers/BaseController.luau) | Facility placement, base upgrade, and base GUI request stubs. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/client/Controllers/CompanionController.luau](archive/pre-foundation-src/client/Controllers/CompanionController.luau) | Companion activation, behavior, upgrade, fusion, and GUI request stubs. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/client/Controllers/InventoryController.luau](archive/pre-foundation-src/client/Controllers/InventoryController.luau) | Inventory open/close, state request, and GUI refresh stubs. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/client/Main.client.luau](archive/pre-foundation-src/client/Main.client.luau) | Previous automatic client bootstrap requiring and initializing legacy controllers. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/gui/Base/Base.luau](archive/pre-foundation-src/gui/Base/Base.luau) | Empty Base GUI placeholder; contains no interface implementation. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/gui/Companion/Companion.luau](archive/pre-foundation-src/gui/Companion/Companion.luau) | Empty Companion GUI placeholder; contains no interface implementation. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/gui/Forge/Forge.luau](archive/pre-foundation-src/gui/Forge/Forge.luau) | Empty Forge GUI placeholder; contains no interface implementation. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/gui/HUD/HUD.luau](archive/pre-foundation-src/gui/HUD/HUD.luau) | Empty HUD GUI placeholder; contains no interface implementation. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/gui/Inventory/Inventory.luau](archive/pre-foundation-src/gui/Inventory/Inventory.luau) | Empty Inventory GUI placeholder; contains no interface implementation. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/gui/Printer/Printer.luau](archive/pre-foundation-src/gui/Printer/Printer.luau) | Empty Printer GUI placeholder; contains no interface implementation. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/gui/RepairStation/RepairStation.luau](archive/pre-foundation-src/gui/RepairStation/RepairStation.luau) | Empty RepairStation GUI placeholder; contains no interface implementation. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/gui/Smithy/Smithy.luau](archive/pre-foundation-src/gui/Smithy/Smithy.luau) | Empty Smithy GUI placeholder; contains no interface implementation. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Main.server.luau](archive/pre-foundation-src/server/Main.server.luau) | Previous server bootstrap wiring world services, player loading/spawning, departure, and shutdown. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Services/Arena/ArenaEventService.luau](archive/pre-foundation-src/server/Services/Arena/ArenaEventService.luau) | Legacy arena construction and participant/defeat handling; despite its filename, returns ArenaService. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Services/Arena/ArenaService.luau](archive/pre-foundation-src/server/Services/Arena/ArenaService.luau) | Arena membership and defeat/drop API scaffold. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Services/Base/BaseService.luau](archive/pre-foundation-src/server/Services/Base/BaseService.luau) | Legacy circular base construction, assignment, spawn, rebuild, and release. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Services/Base/PlacementService.luau](archive/pre-foundation-src/server/Services/Base/PlacementService.luau) | Facility placement, zone unlocking, and restoration API stubs. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Services/Companion/CarrierService.luau](archive/pre-foundation-src/server/Services/Companion/CarrierService.luau) | Carrier crafting/opening and odds/recipe API stubs. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Services/Companion/CompanionBehavior.luau](archive/pre-foundation-src/server/Services/Companion/CompanionBehavior.luau) | Base/Follow/Arena behavior and movement API stubs. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Services/Companion/CompanionCombat.luau](archive/pre-foundation-src/server/Services/Companion/CompanionCombat.luau) | Companion targeting, attacks, damage, and status API stubs. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Services/Companion/CompanionService.luau](archive/pre-foundation-src/server/Services/Companion/CompanionService.luau) | Companion ownership, activation, spawning, and stats API stubs. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Services/Companion/FusionService.luau](archive/pre-foundation-src/server/Services/Companion/FusionService.luau) | Companion fusion validation/calculation/preview API stubs. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Services/Facilities/ForgeService.luau](archive/pre-foundation-src/server/Services/Facilities/ForgeService.luau) | Timed resource refining and output collection API stubs. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Services/Facilities/PrinterService.luau](archive/pre-foundation-src/server/Services/Facilities/PrinterService.luau) | Companion upgrade/healing API stubs. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Services/Facilities/RepairStationService.luau](archive/pre-foundation-src/server/Services/Facilities/RepairStationService.luau) | Item repair and repair-cost/status API stubs. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Services/Facilities/SmithyService.luau](archive/pre-foundation-src/server/Services/Facilities/SmithyService.luau) | Item crafting, recipe, and output collection API stubs. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Services/Inventory/InventoryService.luau](archive/pre-foundation-src/server/Services/Inventory/InventoryService.luau) | Legacy categorized inventory add/remove/query API stubs. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Services/Player/PlayerDataService.luau](archive/pre-foundation-src/server/Services/Player/PlayerDataService.luau) | Previous game-specific profile loading, update, autosave, and saving implementation. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Services/Player/ProgressionService.luau](archive/pre-foundation-src/server/Services/Player/ProgressionService.luau) | Previous cash and rebirth progression operations. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Services/Resources/ResourceDropService.luau](archive/pre-foundation-src/server/Services/Resources/ResourceDropService.luau) | Carried-resource drop, pickup eligibility, and expiration API stubs. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Services/Resources/ResourceService.luau](archive/pre-foundation-src/server/Services/Resources/ResourceService.luau) | Collection, carrying, deposit, and processing API stubs. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/server/Services/Resources/ResourceSpawner.luau](archive/pre-foundation-src/server/Services/Resources/ResourceSpawner.luau) | Legacy spawn initialization, timed loop, and spawn/removal API. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/shared/Configs/ArenaConfig.luau](archive/pre-foundation-src/shared/Configs/ArenaConfig.luau) | Previous Arena settings/content definitions. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/shared/Configs/BaseConfig.luau](archive/pre-foundation-src/shared/Configs/BaseConfig.luau) | Previous Base settings/content definitions. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/shared/Configs/CompanionConfig.luau](archive/pre-foundation-src/shared/Configs/CompanionConfig.luau) | Previous Companion settings/content definitions. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/shared/Configs/FacilityConfig.luau](archive/pre-foundation-src/shared/Configs/FacilityConfig.luau) | Previous Facility settings/content definitions. Historical zone assignments include Smithy in Zone 2; superseded by the current Refinery assignment above. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/shared/Configs/GameConfig.luau](archive/pre-foundation-src/shared/Configs/GameConfig.luau) | Previous Game settings/content definitions. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/shared/Configs/ProgressionConfig.luau](archive/pre-foundation-src/shared/Configs/ProgressionConfig.luau) | Previous Progression settings/content definitions. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/shared/Configs/ResourceConfig.luau](archive/pre-foundation-src/shared/Configs/ResourceConfig.luau) | Previous Resource settings/content definitions. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/shared/Data/PlayerDataTemplate.luau](archive/pre-foundation-src/shared/Data/PlayerDataTemplate.luau) | Previous game-specific save defaults. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/shared/Network/NetworkManager.luau](archive/pre-foundation-src/shared/Network/NetworkManager.luau) | Legacy remote creation and event/function lookup. Archived reference only; excluded from active startup. |
| [archive/pre-foundation-src/shared/Utility/TableUtil.luau](archive/pre-foundation-src/shared/Utility/TableUtil.luau) | Legacy recursive table copying and default reconciliation. Archived reference only; excluded from active startup. |

<a id="delivery-checklist"></a>

## Delivery checklist

### Objective and current status

Deliver a self-contained Roblox project that can be copied into a separate game repository, customized through configuration and assets, and played without implementing its core systems again. The README contains the proposed design; this checklist records implementation and acceptance work, not additional user instructions.

The current project has module scaffolding and an initial player-data implementation. Currency, inventory, and the sell-menu operations are implemented; arena resource generation is implemented, base ownership and structure upgrades are implemented (see [Base upgrades verification](#base-upgrades-verification)), while building placement, resource collection/deposit, facility, and generic upgrade operations still return explicit `NotImplemented` failures. See [Resource generation verification](#resources-verification) for generation scope and test evidence. The central GameConfig is present, core features participate in lifecycle startup, and specialized features default off. Player-data and economy tests pass with mocked services; real persistence and the playable loop still require Studio verification. Archived source is reference material outside the Rojo tree. See [Player-data verification](#player-data-verification) for results and outstanding checks.

### Implementation sequence

Complete each stage with its verification before depending on it in later stages.

1. **Configuration and startup:** Define typed feature contracts, dependency checks, immutable validated content catalogs, asset resolution, and actionable startup errors. Keep game-specific content out of core services. Verify invalid references fail clearly and disabling each optional feature requires no assets or tasks.
2. **Player sessions:** Implement isolated defaults, schema migrations, section validation, memory storage, development/live namespaces, ownership leases, bounded loading retries, coordinated saving, and cleanup. Verify failed loads never activate defaults or overwrite saves; test competing sessions, ownership loss, save failures, and recovery.
3. **Economy:** Implement multiple currencies, stackable and unique inventory, capacity checks, and validated transactions. Verify invalid numbers, insufficient funds, repeated requests, and failed output grants cannot corrupt balances or consume items partially.
4. **Bases and purchases:** Generate circular base slots, assign after profile readiness, restore purchased progression and permanent slot placements, and handle safe respawns and release. Verify two players cannot access each other's base or purchases and layouts retain stable slot IDs.
5. **Resources:** Implement zone spawning, contact collection, carried state, weight and visuals, owned deposits, expiration, and defeat/departure drops. Verify each pickup awards once, excess stays carried, and death plus departure cannot duplicate drops.
6. **Facilities:** Implement one-job processing, input/output capacities, reserved output space, recipe selection, upgrades, and snapshot-based offline reconciliation. Verify storage blocking, partial collection, active speed changes, and rejoining cannot duplicate or discard work.
7. **Client and UI:** Define filtered state snapshots and updates, readiness gating, request payloads, server rate limits, reusable HUD and purchase interactions, and useful failure feedback. Verify late joins, respawns, repeated interactions, and private-state isolation.
8. **Example and release:** Supply replaceable primitive assets and configuration for one resource, currency, recipe, starter processor, and purchasable upgrade. Complete the verification matrix below and package a clean copy for a second game.

### Acceptance matrix

All items are pending Roblox Studio verification unless a dated result is recorded.

| Scenario | Passing result |
| --- | --- |
| Reference loop | Join, receive base, collect, deposit, process, collect outputs, purchase upgrade, save, rejoin, restore progress. |
| Multiplayer | Bases, balances, inventory, processing, and private state remain isolated. |
| Lifecycle | Repeated join/leave and respawn leave no stale ownership, connections, tasks, or world objects. |
| Persistence | Memory mode reports non-durability; development persistence restores progress in its separate namespace. |
| Failure handling | Load/migration failures and live locks block admission; save failures retain dirty state and notify appropriately. |
| Request validation | Invalid types, non-finite numbers, unauthorized IDs, distant actions, and repeated requests cause no duplicated rewards or deductions. |
| Offline processing | Last saved snapshots reconcile once, stop at input/storage limits, and do not accrue blocked-time credit. |
| Optional features | Companion, Combat, Arena, and Rebirth can each remain disabled without breaking the reference loop. |
| Retheming | Replace example content IDs, balance, and assets through configuration; run the same loop without core edits. |
| Copy independence | Fresh project builds without archive, original Git history, generated sourcemaps, or machine-local paths. |

### Copying a completed release

Copy `src/`, `default.project.json`, relevant tooling configuration, and project documentation into a new directory. Initialize a separate repository. Change game identity, Rojo project name, content/assets, and all persistent storage namespaces before enabling development persistence or publishing. Match the published player limit to configured base count. Build a fresh place and run the acceptance matrix for that game's configuration.

Do not call the current scaffold a completed release. A Rojo build verifies packaging only; it does not execute Luau or establish Studio, multiplayer, or DataStore correctness.

<a id="source-api-guide"></a>

## Source and API guide

The project README defines the intended design. This source implements infrastructure and an initial player-data system; the complete playable template remains under construction.

### Infrastructure

- `server/Main.server.luau` and `client/Main.client.luau`: explicit feature order.
- `shared/Features/Lifecycle/LifecycleHelpers.luau`: initialize/start lifecycle and reverse cleanup on failure.
- `Networking`: central remote registry, server creation, bounded client lookup.
- `shared/Features/Game/GameConfig.luau`: immutable identity and feature switches.
- `Resources/ResourcesHelpers.luau`: proportional movement calculation.

### Player data

`PlayerDataService` owns profile admission and transactions. `PlayerDataServer` wires player entry, departure, and shutdown. `PlayerDataSchema` owns serializable copies, version checks, ordered migration hooks, and independent reset boundaries. There are no historical migrations yet: version 1 is the initial generic schema. Older game-specific saves require an explicit migration before they can be admitted.

Default Studio mode is Memory: profiles survive rejoining the same running server, but reset when that server stops. This mode never requires ProfileStore and never probes DataStores. Setting `StudioStorageMode = "Persistent"` uses the separate development namespace. Published servers use the live namespace. Missing persistent API access fails startup; it does not fall back to memory.

Persistent storage uses pinned ProfileStore source; see [Third-party code and attribution](#third-party-code) for license, version, and local patches. The library owns staggered autosaves, session renewal, final saves, and storage operation serialization. The adapter gates admission, limits loading retries, prohibits timed forced takeover, and handles player status and retry scheduling. `OnAfterSave` confirms a successful storage response; requesting Save alone does not confirm durability.

Public server API:

- `Load(player)` returns success or a reason; player readiness is set only after validation.
- `Get(player)` returns success and an independent profile copy, or a failure reason.
- `Update(player, mutator)` validates and commits a working copy. The callback must not yield. Returning false cancels. This never writes immediately to storage.
- `Save(player)` returns whether a save was queued (or stored in server memory). Gameplay purchases should use Update, not Save.
- `Release(player)` removes access and requests the final save and session release.
- `Destroy()` stops admission, releases sessions, and disconnects owned listeners.

Only `DataReady` and `DataStatus` attributes are exposed for startup and status presentation; no profile is replicated. PlayerDataClient displays loading, save failure, recovery, and unavailable messages. Subsequent features must check admission before gameplay. Feature-specific building, facility, and optional-feature reference validation will be added with those catalogs; their full contracts are not implemented yet.

### Remaining gameplay

Currency and Inventory now implement validated server operations and atomic sales. The General sidebar provides Inventory (including selling), Stats (balances and inventory capacity), and read-only Shop Offers tabs, and polls filtered state updates. UIConfig.ShopOffers is currently empty because shop catalogs are not implemented. The offers view cannot buy items. See [Historical script and GUI audit](#script-gui-audit) for the architecture comparison and pending GUI verification. Sales use server-defined prices and sequential request IDs. Currency and item catalogs are validated and frozen during initialization.

Arena resource generation now has a server-owned spawner; see [Resource generation verification](#resources-verification) for configuration, API, results and pending Studio checks. Server-carried quantity state and arena movement are implemented; contact collection, carry visuals and deposit remain placeholders. Base now implements authored plot ownership, saved-level structure restoration, respawn placement, and transactional structure upgrades; see [Base upgrades verification](#base-upgrades-verification). Building placement/restoration, Facilities, generic Upgrades, and the remaining game UI are placeholders. Companion, Combat, Arena, and Rebirth are disabled. There is no playable example or general gameplay state synchronization yet. Enabling a feature switch includes it in startup; it is not a declaration of completeness.

`archive/pre-foundation-src` preserves previous source outside the Rojo tree. Port deliberately instead of running its bootstrap alongside this one.

### Validation

Run `python3 tests/run_player_data.py /path/to/luau` from the project root for profile-schema and adapter tests. They execute the actual source with mocked Roblox services and a fake persistent backend. They do not test ProfileStore's real DataStore operations, rendering, or cross-server races.

Use `rojo build -o /tmp/Tycoon-Foundation.rbxlx` for packaging. See [Player-data verification](#player-data-verification) and [Economy verification](#economy-verification) for outstanding Studio checks.

Run `python3 tests/run_economy.py /path/to/luau` for economy, transaction, replay-protection, and projection tests. See [Economy verification](#economy-verification) for API contracts and the sale interaction.

<a id="player-data-verification"></a>

## Player-data verification

### Automated results — October 24, 2026

- 19 Luau tests pass against actual schema/service source with mocked Roblox services and a fake persistent backend.
- Cases cover independent defaults, newer/missing versions, reset boundaries, unknown inventory references, serialization, copied reads, player isolation, commit/rollback, yielding/error/reentrant mutators, release/rejoin, cleanup, persistent-access refusal, conflict refusal, save notification/recovery, and session loss.
- All 61 active Luau modules compile with the Luau 0.744 CLI. This checks syntax and bytecode compilation, not Roblox type correctness.
- Rojo builds `/tmp/Tycoon-Foundation.rbxlx` successfully.

### Required Studio checks — not run

1. Start a two-player local server in default Memory mode. Confirm the non-durability log, independent profiles, and loading banner removal after admission. Change a balance through the server service, leave/rejoin the same server, and confirm restoration. Restart the server and confirm reset.
2. Set StudioStorageMode to Persistent in a separately published development experience. Confirm the development namespace is logged. Verify rejoining a new server restores progress and published configuration uses a different live namespace.
3. Disable Studio API access while in Persistent mode. Confirm startup stops and no default-memory session is admitted. Return the shipped template to Memory mode afterward.
4. Create an active development profile and attempt concurrent acquisition from another server. Confirm safe release/ownership handoff or bounded refusal without forced takeover; verify the original session stops access on ownership loss. Test abandoned ownership recovery after the library's stale-session threshold.
5. Seed development profiles with a newer schema, missing version, and corrupt envelope. Confirm admission fails and saved gameplay data is not overwritten. Seed an invalid inventory with a valid balance and confirm only its reset boundary changes.
6. Inject storage errors through a controlled test backend or Studio network fault setup. Confirm three loading failures use the configured delays and never admit fallback data. During saving failures, confirm the warning appears, live progress remains available, retries back off, and success displays recovery.
7. Change progress immediately before departure and shutdown. Confirm final saves complete, rejoin restores the final snapshot, and no stale session can overwrite the new owner's data. Repeat with overlapping autosave/final-save operations and storage failures.
8. Respawn and repeat lifecycle tests. Confirm the persistence banner survives respawns without duplicate listeners or GUI instances.

The complete reference gameplay loop, offline facilities, feature catalog reference validation, and game UI are pending their own implementation stages. No production-readiness claim is made from the mocked tests or Rojo build alone.

<a id="economy-verification"></a>

## Economy verification

### Implemented behavior

The example uses cash, ore, and ingots. Ingots sell for 10 cash each. Ore has no sale definition. These IDs and prices are content configuration; core services do not hardcode them. There is no resource-producing world yet, so the menu remains empty until a server operation grants items.

Players open Inventory / Sell, select an item row, enter a positive whole-number quantity, and sell it. The server checks profile admission, item definition, ownership, quantity, request sequence, and currency precision/limits. Removing items and granting the reward happen in one PlayerData.Update transaction; either both commit or neither does. Failed and repeated requests cannot duplicate rewards or consumption.

Only stackable items are sold by this example. Unique items are displayed individually but cannot be sold until a future game's configuration and rules specify how their individual properties affect value. Inventory itself supports both models.

The UI requests a filtered economy projection every two seconds. It preserves text input when the inventory is unchanged and during focused editing. It never receives the private profile or unique-item properties. After a transport failure it preserves the pending sale's payload and request ID for retry. The server remembers the latest response and rejects all older IDs, avoiding a replay window from cache eviction.

### Server API

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

### Networking

- UI.GetState is a RemoteFunction with no required arguments; returns success and filtered state or a failure reason. Per-player minimum interval: 0.5 seconds.
- Inventory.Sell is a RemoteFunction taking item ID, quantity, and sequential request ID; returns success and optional failure reason. Per-player minimum interval: 0.25 seconds.
- Clients never send prices, rewards, target players, balances, or authoritative item properties through these remotes.
- Request-frequency state and cached sale responses are removed on departure; remote handlers and owned connections are removed on destruction.

### Automated checks — October 24, 2026

18 economy tests pass against the actual service and helper source, plus the existing 19 player-data tests. Cases include multiple currencies and precision, startup validation and frozen configuration, full inventories, unique properties/IDs, ownership isolation, complete rollback on failed rewards, invalid numbers, repeated and stale sales, and private-state filtering. Roblox services are mocked; the real GUI and networking are not executed by these tests.

### Studio checks — pending

1. In a two-player Memory-mode local server, confirm cash balances and empty-state feedback appear independently. Respawn and confirm only one economy interface remains.
2. From the server command bar, require ServerScriptService.Server.Features.Inventory.InventoryService and grant ingots to one admitted player. Confirm only that player's inventory updates. No client grant remote exists.
3. Enter different quantities and verify the sold quantity and server balance. Confirm zero, negative, fractional, excessive, and nonnumeric entries provide feedback without state changes.
4. Fill inventory to its configured cap. Confirm extra grants fail. Grant test unique definitions in configuration and verify IDs, limits, defaults, and hidden properties.
5. Retry identical sale IDs, resend older IDs, and spam the remote with invalid requests. Confirm replay protection, rate limits, and ownership isolation.
6. Interrupt the network during a sale. Retry its same item and quantity after recovery; confirm one sale, even if the first request succeeded but its response was lost.
7. Verify quantity inputs remain usable across periodic refreshes, scrolling and buttons fit desktop/mobile screens, and opening/closing during requests causes no stale callbacks or duplicate controls.
8. Test storage-backed restoration of balances and inventory using the development namespace. This depends on the outstanding player-data Studio checks.

Bases, collection, processing, upgrades, and the full reference loop remain pending the next implementation stages.

<a id="base-upgrades-verification"></a>

## Base upgrades verification

### Implemented behavior

BaseService owns session plot assignments and structure changes. BaseServer assigns after DataReady, handles respawn placement, owner-only upgrade prompts and remote requests, and releases plots on departure or loss of readiness. BaseModels loads, validates, clones and positions structure templates. Requiring any module does not start gameplay.

Saved Base.Level selects the structure through BaseConfig.Layouts. The initial profile remains level 1; no saved schema or ID migration was introduced. Current mappings:

| Saved level | Model type | Project model | Cash cost to enter level |
| --- | --- | --- | --- |
| 1 | base.level_1 | Workspace.Bases.NoGemBases.Base_Level_1 | Initial level |
| 2 | base.level_2 | Workspace.Bases.NoGemBases.Base_Level_2 | 100 |
| 3 | base.level_3 | Workspace.Bases.NoGemBases.Base_Level_3 | 250 |
| 4 | base.level_4 | Workspace.Bases.NoGemBases.Base_Level_4 | 500 |

Prices are editable example balance in BaseConfig.LevelCosts, indexed by the destination level. The art model Base_Level_0 is an unclaimed preview, not a saved progression level. Levels outside the configured range fail assignment without modifying the profile.

This game deliberately uses thirteen existing authored plot locations rather than regenerating the README's default circle. BaseConfig.Plots lists five models in NoGemBases and eight in PlacedBases. These locations were inspected in Studio; ArenaSlotIndex has a reserved gap, so ownership uses stable configured plot IDs instead of those art attributes. The place's published player limit must match the thirteen configured plots; this code does not change Roblox's publishing setting.

Initialization caches independent templates before any source plot is occupied. On assignment the authored plot model is temporarily unparented and a PlayerBases wrapper is created at its floor's bottom-center transform. Release restores the original authored model. Destroy restores originals and removes only owned runtime wrappers/templates. The authored originals are previews; their visual BaseLevel is not player progress.

Each wrapper has Structure, Buildings and an UpgradeAnchor with a ProximityPrompt. Upgrades replace Structure only. Floor-bottom alignment retains plot position, yaw, and ground height across different model dimensions/pivots. Existing runtime children under Buildings survive structure swaps; saved Base.Buildings, inventory, facility state and other profile sections remain untouched. New structures expose OwnerUserId, BaseLevel, PlotLevel and ModelType attributes, and clear Unclaimed.

PurchaseLevel derives ownership from the requesting player's server assignment. It validates admission, expected current level, maximum level, alive character, distance (35 studs), available world objects and currency. The next level is always current + 1. There is no client-selected owner, model, transform or cost. The same expected level cannot purchase twice. Example levels have no additional prerequisites beyond sequential progression and their currency costs.

The next model is prepared before payment. Currency deduction and saved level update occur in one PlayerData.Update transaction. During its non-yielding callback the new structure is staged into the wrapper and the old one detached; if the transaction rejects, staging is removed and the old model restored. Only a successful transaction destroys the old structure. Existing PlayerData saving/session rules apply; Update is not a synchronous durable save.

### API and interaction

Server ModuleScript: ServerScriptService.Server.Features.Base.BaseService.

- Assign(player) / Restore(player): restore saved-level model into an available plot; repeated assignment returns the same plot ID.
- PurchaseLevel(player, expectedCurrentLevel): buy exactly one level. Returns true, or false with a reason such as NotReady, NoOwnedBase, InvalidLevel, StaleLevel, MaxLevel, TooFarOrDead, InsufficientFunds, BaseUnavailable or ModelPreparationFailed.
- GetState(player): returns true and PlotId, Level, MaxLevel, ModelType and independent NextCosts; otherwise false and a reason.
- SpawnCharacter(player): move the current character to the owned layout's SpawnOffset.
- Release(player): free its runtime assignment and restore the authored preview. Saved progress remains.
- Destroy(): clean up all runtime ownership, wrappers and templates.

BaseServer wires each owned prompt; other visitors cannot upgrade it. The prompt disables at max level. The triggering owner's BaseUpgradeResult attribute records Upgraded or the failure reason for a future UI.

The central registry owns Base.GetState and Base.PurchaseLevel RemoteFunctions. GetState accepts no payload; PurchaseLevel accepts the expected current level. Both are limited independently to one request per player per 0.5 seconds. Prompt purchases share the purchase limiter. A future UI should retrieve state, show NextCosts and send the displayed Level; after stale/transport failures, refresh before requesting another upgrade. No new client GUI is part of this change.

Assets can use ProjectPath with path segments, or AssetId with a positive integer ID; both must declare ExpectedClass="Model". External asset loading uses InsertService and requires appropriate experience permissions. FloorName must resolve to a BasePart with local Y vertical. Templates cannot contain scripts and all structure parts are anchored. Asset loading and catalog validation happen before admission-dependent assignment; failures roll back startup assets.

### Verification

- 13 base upgrade tests passed against actual BaseService/BaseModels/Currency rules with isolated, unparented Roblox model fixtures and a mocked profile transaction API. Cases cover isolated ownership, one assignment per player, pricing/model mapping, ground/yaw preservation, retained building state, stale/invalid requests, proximity/death, insufficient cash, model preparation failure, rejected-commit rollback, max level, saved-level restoration, invalid saves, base exhaustion and cleanup/reinitialization.
- All five changed/added base/config/networking modules compiled through Studio loadstring. This is not full static type checking.
- All four real authored level models validated and positioned as unparented clones. Ground alignment error was zero at the tested origin for each model. No live place instances were changed by these tests.
- Rojo packaging passed: /tmp/Tycoon-Base-Upgrades.rbxlx.

Reproduce isolated tests by emitting `python3 tests/run_bases.py` and executing that bundle with Studio loadstring in a development context. Fixtures remain outside the live DataModel and are destroyed after successful tests.

### Remaining acceptance and scope

Source files were not installed into the connected place. After syncing into the intended development place, run two players and confirm unique ownership, safe spawn/respawn, prompt interaction, current prices, currency changes, max level, departure release and same-server Memory-mode restoration. Use development persistent storage to verify restoration in a new server. Test delayed/lost requests, session loss, repeated starts/stops, failed assets, and every full-size layout against neighboring bases and world geometry.

Building purchasing, saved building reconstruction, facility reflow to level-specific slots, base deposit zones, and a purchase GUI remain unimplemented. Keeping Buildings intact during an upgrade does not implement those systems. Generic UpgradesService remains a placeholder for separate upgrade tracks; base structure progression lives in BaseService to keep assignment, model state and saved level under one owner.

<a id="resources-verification"></a>

## Resource generation verification

### Implemented scope

ResourcesSpawner owns generated pickup instances, per-zone counts, placement and expiration. ResourcesService delegates Spawn(zoneId). ResourcesServer owns one Heartbeat connection and schedules the first attempt during Start. Requiring modules does not begin generation. Destroy disconnects the heartbeat and removes only this service's instances and templates. No spawn remote exists. The same Resources lifecycle now also owns server carry state and arena movement; see [Carry Presentation and Movement](#carry-presentation-and-movement).

The current example selects resource.ore with weight 1 and a random OreCluster appearance, waits 2–5 seconds after each attempt, shares a 30-pickup zone cap, and expires each single-unit pickup after 60 seconds. These are configurable example values. Server carried quantities and arena movement are implemented; contact collection, carry visuals, deposits and defeat/departure drops remain pending. Pickups cannot currently be collected automatically.

ResourcesConfig.Zones["zone.arena"].SurfacePath points to Workspace.World.Arena.BasicArena.Floor, inspected in connected Studio CHAT. The floor is 0.5 × 100 × 100 with local X vertical; placement handles floors whose thinnest local axis is vertical. Zones support horizontal floor BaseParts, including yaw rotation. Four downward raycasts filtered to the configured surface require support beneath the entire rectangular pickup footprint; this handles the inspected circular Cylinder floor. Placement uses the complete pickup bounding box, a three-stud edge margin, and at most 12 attempts; unsupported positions and overlapping queryable geometry are rejected. Non-queryable geometry is not detected by this check. Mesh bounding boxes can conservatively reject otherwise open positions.

The ore pickup uses the three authored models in `ServerStorage.ResourceModels`: `OreCluster`, `OreClusterWide`, and `OreClusterJagged`. They match the gallery copies in `Workspace.Development.ResourceModelPreviews`; spawning clones the server templates and leaves the gallery untouched. `ResourcesConfig.Definitions["resource.ore"].PickupAssets` lists these project-model references. Each spawn chooses one visual variant uniformly, while the zone's resource weights still select the resource ID. All variants remain one unit of `resource.ore`, with the same lifetime, spawn delay and shared cap.

Use either a single `PickupAsset` reference or a nonempty dense `PickupAssets` array per resource. The spawner validates every configured variant, positions its complete bounding box above the floor, and applies the normal anchored/non-colliding part settings to every descendant. Spawned roots expose `ModelVariant` and clear `PreviewOnly`. Supported references:

- Primitive: Kind, ExpectedClass="BasePart", Size (Vector3), Color (Color3).
- ProjectPath: Kind, ExpectedClass="Model" or "BasePart", Path (segments beginning with service name).
- AssetId: Kind, ExpectedClass="Model", Id (positive integer); InsertService.LoadAsset returns a Model container and permission failures stop initialization.

Templates must contain parts and no scripts. Parts are anchored, non-colliding, queryable, and have contact generation disabled pending collection implementation. Do not use these generated pickups as carry models. External assets must be loadable by the experience. Configuration freezes after successful initialization; invalid enabled zones stop startup with an error and roll back owned assets. The spawner does not require assets for disabled zones. Arena movement still requires the surface selected by Movement.ArenaZoneId, even when generation is disabled. Disable all zones to run without generation, or disable Resources in GameConfig to omit resource movement and spawning entirely.

Server API: Spawn(zoneId) returns true and the generated instance, or false and Unavailable, UnknownZone, AtCapacity, WorldUnavailable or NoValidPlacement. It selects the resource and position itself. Manual calls respect the cap but intentionally bypass the automatic delay. Quantity, ResourceId, ZoneId and ExpiresAt attributes describe generated pickups; a future collection service must consult authoritative state and expiration before awarding anything.

### Verification

- Rojo packaging passed: /tmp/Tycoon-Arena-Resources.rbxlx.
- All four changed/added resource modules compiled using Studio loadstring.
- 12 resource tests passed using the actual spawner source, mocked Instances/world queries, and Roblox CFrame/Vector3 types. Tests cover initial delay, unit/expiry metadata, rotated circular-floor placement, cap, external destruction, expiration, bounded blocked attempts, invalid delays/weights/references, disabled zones and restart cleanup.
- Existing 18 economy and 19 player-data tests passed via isolated Studio loadstring bundles using their existing mocks. No DataStore calls or live world modifications were made by these test bundles.
- No scripts installed into the connected place; no live play or multiplayer acceptance performed.

To reproduce resource tests, run `python3 tests/run_resources.py` and execute its emitted bundle with Studio loadstring in an isolated development context. This bundle mocks workspace and Instance; it does not install gameplay scripts.

### OreCluster appearance update

- Replaced the gray primitive configuration with the three server-side OreCluster templates and added optional visual variants to ResourcesSpawner.
- 13 isolated resource regression tests pass, including multi-part cloning, variant selection, one-unit identity, preview-marker removal, placement, capacity, expiration and source-template preservation.
- 90 placements using actual authored models and the current arena floor passed in an unparented sandbox. All three variants appeared, remained anchored/non-colliding, and aligned above the floor. Temporary clones were removed after the check.
- Updated the two resource ModuleScript sources in the connected Studio's Edit DataModel. Start a new Play session to load the changed frozen configuration; preview/gallery models were not edited.
- Rojo packaging passed after moving the misplaced `explorer.compactFolders` preference from the project JSON into `.vscode/settings.json`.
- The model assets live in the place's ServerStorage and must be retained when syncing or copying it; the Rojo source tree does not export these authored assets into a fresh place.

### Remaining Studio acceptance

Sync the source into the intended place with its arena hierarchy present. Start a server and confirm the zone starts empty, first generation waits 2–5 seconds, positions avoid walls/characters/pickups, the cap stays at 30, and expired pickups disappear and release capacity. Destroy/restart the feature and confirm no duplicate heartbeat or owned instances remain. Check project-model and external asset loading separately, including errors and permissions. Test more than one zone and mixed/zero weights. Collection/deposit and the complete gameplay loop require subsequent implementation.

<a id="admin-controls"></a>

## Admin controls

The `Admin` feature adds a private, session-only control panel using the existing pixel GUI theme. Central server/client startup loads Admin after the gameplay features, and the central networking registry owns `Admin.GetState`, `Admin.Prepare`, and `Admin.Commit`. Only the two existing Main scripts run automatically. Admin can be omitted through `GameConfig.Features.Admin`.

### Configuration and permissions

Edit [AdminConfig.luau](src/server/Features/Admin/AdminConfig.luau). `AdminUserIds` accepts numeric Roblox user IDs. `AllowExperienceOwner = true` additionally authorizes the owner of a **user-owned** experience; group-owned experiences require explicit IDs. There is no Studio-wide bypass, username matching, client-provided authorization, or inferred group-role access. This configuration stays in ServerScriptService. The client receives only authorized display state, stable action/option IDs, revision, and request sequence; it never receives admin IDs or asset paths.

`Toggles` configures displayed controls through supported server adapters. Current adapters are `ResourceGeneration` (new pickups only; normal expiry continues), `InventorySelling` (new sales), and `BasePurchases` (both remote and world-prompt purchases). Enabling/disabling these gates does not destroy services, profiles, inventory, or base ownership. Completed sale replays retain their original result when selling is paused. Do not expose the frozen startup feature switches as hot-unload controls: networking, player data, and unfinished gameplay systems cannot safely be restarted through this panel.

`ModelTargets` is seeded from `BaseConfig.Plots`; each occupied plot supports the approved base styles built from `BaseConfig.Layouts`. Edit/filter these entries and their `Options` to narrow the catalog. Each option maps a public ID/name to a private validated style level. New controls/targets using an existing adapter need only configuration entries. A new kind of system or model requires a lifecycle-aware server adapter before its configuration can be exposed. Clients cannot supply arbitrary models, asset IDs, instance paths, owners, transforms, or module names.

### Changes and safety

Every state request and action rechecks server authorization and is rate limited. Prepare validates the action against the configured allowlist and returns a short-lived, player-bound confirmation token with a readable warning. Commit validates permission, readiness, token, expiry, current revision, and sequential request ID. The most recent commit result is retained for safe transport retries. Changing the payload under the same request ID or using an older ID is rejected. Request state is removed on leave and feature teardown.

All changes require an explicit confirmation. Base swapping may disrupt players standing on the structure; no action resets saved progress. The server prepares and validates a replacement using the existing BaseModels helpers before detaching the current Structure. It preserves the original floor-bottom position/orientation, owner, saved level, base wrapper, Buildings folder, UpgradeAnchor and ProximityPrompt instance/connections. Occupied Buildings folders are blocked because the future placement system has no compatibility validation yet. Failed preparation leaves the existing model in place. Ordinary base upgrades restore the progression-selected appearance, and rejoining restores saved progression. Replacements do not grant levels or change purchase prices.

The panel polls authoritative state every two seconds. A revision includes actual toggle values and each target's availability, appearance, owner and saved level, including ordinary join/release/upgrade changes. Another admin's change is reflected on the next poll; an outstanding confirmation becomes stale and cannot overwrite it. The client preserves a pending commit identity after an uncertain response and retries that same request. No DataStore, MessagingService, cross-server setting, or permanent configuration write is added.

### Implementation and verification (2026-10-27)

- [AdminService.luau](src/server/Features/Admin/AdminService.luau) owns policy, adapters, projection, confirmations and commit replay. [AdminServer.luau](src/server/Features/Admin/AdminServer.luau) owns remote wiring and leave cleanup. [AdminClient.luau](src/client/Features/Admin/AdminClient.luau) owns the authorized launcher, scrolling controls, confirmation UI and polling. It reuses `UITheme`.
- Rojo build passed (`/tmp/Tycoon-Admin.rbxlx`); all 11 added/changed runtime sources compiled in Studio.
- 68 isolated checks passed: 19 admin policy, 16 base, 14 resource and 19 economy tests. They cover two simulated admins, unauthorized requests, malformed requests, allowlists, expiry, revision/ownership conflicts, replay, rate limits, failed replacement rollback, placement, preserved prompt connections, paused spawning/expiry, purchase gating and sale replay while paused. `python3 tests/run_admin.py`, `run_bases.py` and `run_resources.py` emit isolated Studio loadstring bundles; `run_economy.py` runs against a Luau executable (its emitted bundle was evaluated through Studio for this run).
- In CHAT Play mode, the owner launcher opened; a confirmed resource toggle changed state, the other configured gates changed through real remotes, and an approved base swap preserved ground placement, saved level, Buildings and the exact upgrade-prompt instance. A live unapproved model request left the current structure intact. Temporarily revoking owner access in the test session caused all three real remotes to return Forbidden and hid the launcher. Permission was restored afterward; no test bypass was shipped.
- Desktop and iPhone 17 Pro portrait/landscape layouts were inspected with the device simulator. Portrait text-bound checks found no horizontal overflow; short screens use a compact header and scrolling confirmation text. Live multiplayer, physical touch and full gamepad navigation still need acceptance testing. The existing asset `203785492` continues to log an unrelated asset-type mismatch.
- Studio was returned to Edit and its default viewport. Temporary verification scripts, test access changes, model swaps and toggles were confined to Play and discarded when stopped.

<a id="script-gui-audit"></a>

## Historical script and GUI audit

Compared README.md, [Source and API guide](#source-api-guide), [Delivery checklist](#delivery-checklist), the active source, and default.project.json.

### Structure

All 13 startup features have matching server/client execution modules. The built place contains exactly two automatic scripts: server Main (Script) and client Main (LocalScript). Feature execution files and supporting files are ModuleScripts. Shared, server, and client roots map to ReplicatedStorage.Shared, ServerScriptService.Server, and StarterPlayer.StarterPlayerScripts.Client respectively. Archived controllers and GUI modules are excluded from the active Rojo tree. No missing startup module was found.

The README defines responsibility layers, not a requirement to create empty Config/Helpers/Service files for every feature. Networking and lifecycle already provide their applicable infrastructure modules. Avoid duplicate bootstraps or restoring archived GUI modules alongside the current UI.

### Implementation versus specification

| Area | Current source |
| --- | --- |
| Lifecycle/networking | Explicit ordered initialization/start and cleanup; central remote registry. |
| Player data | Schema, admission, session adapter, memory/persistent modes, status GUI; real persistence acceptance remains pending. |
| Currency/inventory | Validated server services, filtered UI projection, atomic sales and replay handling. |
| Base | Assignment, restoration, spawning, placement and level purchase operations return NotImplemented. Layout/slot catalogs are empty. |
| Resources | Collection, deposit, drop and spawn operations return NotImplemented. |
| Facilities/upgrades | Operations return NotImplemented; content catalogs are empty. |
| Companion/combat/arena/rebirth | Disabled scaffold features; not complete gameplay. |
| Full synchronization | Existing bounded snapshot polling; revisioned updates remain unimplemented. |

The general module structure matches the design; the full gameplay requirements do not yet pass. A complete playable foundation requires the missing systems and Studio acceptance evidence.

### Pixel GUI refresh (2026-10-27)

The active GUI now follows `Assets/Reference_Image/UI_Reference`: peach panels, navy title plates, gold rivets, hard two-pixel borders, inset bevels, and Arcade pixel lettering. `UITheme.luau` owns reusable colors, frames, and buttons using native Roblox UI geometry with no uploaded image dependencies. UIClient retains Inventory selling, live Stats, and read-only Offers. PlayerDataClient shares the theme for loading/save warnings. The wallet and General launcher stay compact; the menu has a dimmed backdrop and a taller compact layout for short viewports. Touch movement controls are restored on close, readiness loss, and teardown.

Verification in the connected CHAT place: all three UI modules compiled; Rojo build passed (`/tmp/Tycoon-Pixel-UI.rbxlx`); desktop, iPhone 17 Pro landscape, and portrait inspected. In a temporary memory-storage Play session, populated rows, empty inventory, Stats, Offers, close, save-warning visibility, readiness loss, touch-control restoration, and focused entry during polling were checked. Zero quantity was rejected; selling two ingots removed two units and granted 20 Cash. Portrait text-bound checks found no horizontal overflow. A transient refresh failure now clears after a successful refresh without replacing focused entry. Studio returned to Edit and the default viewport; temporary test grants/scripts were discarded. Existing asset `203785492` still logs an asset-type mismatch unrelated to this UI change. Physical touch/gamepad navigation, transport-failure replay, and multiplayer remain unverified.

### GUI review and change

Active GUI was FoundationEconomy (balances and inventory/sell) plus FoundationDataStatus (loading/save status). Historical HUD, shop/facility and inventory modules exist only in archive and do not run.

UIClient now provides a left-side General button opening Inventory, Stats, and Shop Offers tabs. Inventory retains the existing validated selling interaction. Stats shows live currency balances and stack/unique inventory capacities from UI.GetState; it does not invent unsupported progression statistics. Shop Offers displays presentation-only UIConfig.ShopOffers entries with shop name, offer name, description and price label. It has no purchase buttons, handlers, or purchase remote calls. The catalog starts empty because no current shop definitions exist; the GUI says so explicitly. Future shop implementation should supply this catalog from its authoritative definitions rather than maintain competing prices.

The panel uses relative dimensions, a maximum size, scrolling content and Activated navigation; input focus protection, respawn persistence and cleanup remain in place. These properties still require real touch/gamepad/desktop visual and navigation checks.

### Verification

- Rojo build passed: /tmp/Tycoon-General-Sidebar.rbxlx.
- All 13 server/client execution pairs exist; packaged automatic-script class/count audit passed.
- No Luau CLI was found, so automated Luau regression suites were not rerun.
- No Studio visual/play test performed. Connected Studio is named CHAT; project identity has not been established, so no live place was modified.
- Pending: open General, switch all tabs, close/reopen, scroll, change balances/inventory, sell/retry, respawn, lose/recover data readiness, and inspect small screens/gamepad focus in the intended place.

<a id="third-party-code"></a>

## Third-party code and attribution

### ProfileStore by MAD STUDIO / loleris

- Repository: https://github.com/MadStudioRoblox/ProfileStore
- Pinned upstream commit: `45c9847cbcf1fc260369c50eb335aba7c35aecdd` (2025-07-31).
- License: Apache 2.0, retained in `licenses/ProfileStore-LICENSE.txt`.
- Source: `src/server/Features/PlayerData/Vendor/ProfileStore.luau`.
- Documentation: https://madstudioroblox.github.io/ProfileStore/api/

ProfileService is no longer supported and directs users to ProfileStore. ProfileStore is its supported successor; its latest upstream commit at integration was dated above. No claim is made about a guaranteed future maintenance schedule.

Foundation changes to vendored source:

1. Reject corrupt storage envelopes inside the UpdateAsync transform instead of silently replacing them with a new profile.
2. Accept an internal `ValidateData` callback before session acquisition so unsupported schema versions and failed migrations cannot be written back.
3. Accept internal `ErrorRetryDelays` for the configured loading backoff instead of hardcoding its initial delays.

The adapter gates persistent access on DataStoreState == Access, configures 120-second staggered library autosaves, cancels acquisition after ten seconds or three storage errors, and prevents the timed forced-takeover path. Crash recovery uses ProfileStore's stale-session detection. Memory mode does not require the library and does not issue DataStore probes.

The Vendor subdirectory is isolated third-party code, an exception to the flat feature-module convention. Preserve license and attribution when copying the template. Audit these local patches whenever updating the dependency.

<a id="archived-source"></a>

## Archived source

`archive/pre-foundation-src` preserves every original Luau file, including uncommitted player-data work, before the architecture migration. These files are outside the Rojo source tree and do not execute. They are reference material, not the active implementation.
