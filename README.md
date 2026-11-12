# Scaffolding Tycoon

A Roblox game built around arena ore collection, base facilities, and companions. This reference describes the current local source; balance values are development settings.

## Gameplay loop

1. Claim an assigned base and place a forge in Zone1.
2. Enter the arena and walk near ore to collect it.
3. Return within 12 studs of your forge to deposit raw ore.
4. Collect refined output by approaching the forge while carrying no raw ore.
5. Place a charge station in Zone2 to restore and level your Home-mode companion.
6. Manage companions through the Bag: equip, store, fuse, or choose a mode.

## Bases and facilities

Thirteen base spots surround a reserved pathway spot at a radius of 125 studs. Joining assigns the first available base using its level-1 template. Characters spawn and respawn three studs above the assigned base transform. Leaving releases the base and restores its level-0 template.

Owners activate zone prompts to place facilities. Placement and facility upgrades currently have no currency cost. Purchased zones, facility tiers, forge contents, and station power last for the current session.

| Facility | Placement | Function |
| --- | --- | --- |
| Forge | Zone1; starts as StoneForge | Converts raw ore into refined inventory items. |
| Charge station | Zone2; starts as ChargeStation | Generates power for the owner's Home-mode companion. |

### Forge

Every 0.25 seconds, the server checks whether a living owner is within 12 studs of their forge. Carried raw ore transfers into its intake. When the owner carries no raw ore, available output transfers into their inventory.

Every two seconds, the forge processes one available ore type. Each processed unit becomes one item named `Refined` plus the original item ID, such as `IronOre` → `RefinedIronOre`.

| Tier | Model | Units per processing tick |
| --- | --- | --- |
| 1 | StoneForge | 1 |
| 2 | IronForge | 2 |
| 3 | SteelForge | 4 |

The owner uses the forge's upgrade prompt to advance one tier. A failed model replacement restores the previous tier.

### Charge station

Stations generate power once per second using elapsed time, up to their capacity. The upgrade prompt advances one tier and replaces the model.

| Tier | Model | Capacity | Power per second |
| --- | --- | --- | --- |
| 1 | ChargeStation | 100 | 5 |
| 2 | ChargeStation_Level_2 | 200 | 10 |
| 3 | ChargeStation_Level_3 | 350 | 20 |

## Arena and carrying

The arena uses the horizontal circular `Workspace.Game.World.Arena.BasicArena.ArenaFloor`. Its current position and size determine collection bounds and spawn positions.

A living player with a loaded profile and a placed forge automatically collects nearby ore within six studs. Both player and ore must be inside the arena. Collection scans run every 0.1 seconds, with a 0.3-second cooldown per player. Each regular pickup grants one unit.

Modes repeat in this order. Switching modes clears regular ore and replaces mode-specific boss models when their templates exist.

| Mode | Duration | Spawn interval | Ore limit | Ore pool |
| --- | --- | --- | --- | --- |
| Normal | 180 seconds | 3 seconds | 20 | Iron, copper; iron has double weight |
| Rich | 120 seconds | 2 seconds | 30 | Iron, copper, gold |
| Boss | 90 seconds | 4 seconds | 15 | Copper, gold |

Raw ore appears as an overhead stack of up to eight pieces with a quantity label. Inside the arena, walking speed is `max(8, 16 - 0.35 × ore count)`. Outside it, speed is 16.

Taking damage inside the arena drops all carried raw ore into one bundle per item type. Other eligible players can collect the bundles immediately; the original owner waits four seconds. Unclaimed bundles expire after 60 seconds.

## Inventory and controls

The Bag shows resource quantities and companion controls. Press **B** or **I** to toggle it, or use its launcher. **Escape**, the close button, and the backdrop close it.

The HUD displays cash, scrap, player level, and carried ore. Inventory changes are sent from the server to the owning client. Joining grants five IronOre when the inventory contains none; this is the current starter-item behavior.

## Companions

A new collection equips one Common companion selected from the available templates. Older profiles with a companion ID migrate that companion into the collection. Each companion has a unique ID, template, element, rarity, four stat values, level, XP, health, charge, and mode.

### Modes

| Mode | Behavior |
| --- | --- |
| Home | Wanders near the owner's station or base. Within 14 studs of the station, draws up to 13 power per second. |
| Follow | Follows at a four-stud sideways/backward offset. Teleports to the follow target when more than 80 studs away. |
| Fight | Enters the arena and pursues the nearest eligible rival player or living companion inside it. |

Attacks occur within six studs, at most once per second, using the companion's calculated damage. Each attack reduces charge by two, down to zero. Zero charge halves movement speed; attacks remain enabled. Player targets with a ForceField are excluded.

Defeat sets health to zero, switches the companion to Home, and returns it home when a home position is available. Home-mode station power restores it. A defeated companion must recover health before switching to Follow or Fight.

### Stats and progression

The four stats are Health, Charge, Damage, and Speed. Initial rolls distribute the rarity budget within each stat's bounds.

| Rarity | Initial budget | Per-stat range |
| --- | --- | --- |
| Common | 30 | 5–10 |
| Rare | 64 | 10–23 |
| Epic | 110 | 20–40 |
| Legendary | 180 | 35–65 |

Effective values equal `stat × scale × (1 + level × 0.05)`. Scales are 10 for Health and Charge, 1 for Damage, and 1.5 for Speed.

Station power refills missing health and charge proportionally. Remaining power becomes XP; every 60 XP grants one level.

### Storage and fusion

Only one companion is equipped at a time. Unequipping or replacing it resets its level and XP to zero while preserving stat points. Health and charge are clamped to the resulting maximums.

Fusion requires two distinct owned companions of the same rarity. The equipped companion is kept; the other is consumed. Each resulting stat takes the higher parent value, level takes the higher parent level, and XP resets to zero. Fusion can exceed the initial total stat budget while retaining individual stat limits.

The Bag requests confirmation before storing an equipped companion or consuming a fusion partner. The server validates ownership, equipped status, rarity, and action cooldowns.

## Saved state

Profiles use DataStore `PlayerSaveData_v1` with keys `Player_<UserId>`. New profile defaults are 100 Cash, 0 Scrap, 0 Rebirths, and player Level 1.

Saved data includes profile values, inventory, companion collection, and equipped companion ID. Loads use `GetAsync`; saves use `SetAsync` every 300 seconds, on departure, and during shutdown. Failed loads reject admission. Shutdown waits up to 25 seconds for saves.

Base assignments and facility state are session-only. The current loader uses DataStores in Studio too; its behavior depends on Studio's API access settings.

## Source map

| Path | Responsibility |
| --- | --- |
| [src/server/Base](src/server/Base) | Base layout, assignment, placement, forge processing, and station power. |
| [src/server/Arena](src/server/Arena) | Circular bounds, mode rotation, ore collection, carrying, and drops. |
| [src/server/Companion](src/server/Companion) | Collection rules, stats, fusion, movement, charging, and combat. |
| [src/server/PlayerData](src/server/PlayerData) | Profile loading/saving, inventory, and player lifecycle. |
| [src/client](src/client) | HUD, Bag, companion controls, and cosmetic companion animation. |
| [src/shared/Remotes.luau](src/shared/Remotes.luau) | Inventory and companion network endpoints. |
| [default.project.json](default.project.json) | Rojo mappings for shared, server, client, and GUI files. |

Data modules define configuration and types; rule/helper modules provide reusable operations; managers own runtime behavior; entry scripts connect lifecycle events. Clients display state and request actions; servers apply gameplay changes.

## Required assets

- Base and facility templates: `ServerStorage.Assets.Base_Models`, `Forge_Models`, and `ChargeStation_Models`. Base/facility lookup also supports `ReplicatedStorage.Assets` as a fallback root.
- Base templates: `Base_Level_0` and `Base_Level_1`, with authored zone parts under `Zones`.
- Facility templates: the model names listed in the tier tables above.
- Companion models: `ServerStorage.Assets.Companions`, with `Companion` accepted as an alternate folder name. Template names end with a configured rarity, such as `ElectricCommon`.
- Arena floor: `Workspace.Game.World.Arena.BasicArena.ArenaFloor`.
- Mode-specific model spawning: Rich uses `ServerStorage.ArenaBosses.StoneGolem`; Boss uses `IronGolem`. This is a template-spawning definition, not a combat behavior specification.

## Local verification

Edit local source files; Rojo handles sync. Follow [AGENTS.md](AGENTS.md) and [src/AGENTS.md](src/AGENTS.md).

```sh
python3 src/tools/verify.py
```

The command compiles Luau, runs mock regression suites, builds the Rojo project, and runs Roblox-aware type/lint analysis. Tool setup and focused commands are documented in [src/tools/README.md](src/tools/README.md).

Local checks do not establish live physics, replication, DataStore persistence, or multiplayer behavior. Those require user-run Studio testing.
