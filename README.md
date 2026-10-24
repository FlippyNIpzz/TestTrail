# TestTrail: Game Context & Architectural Blueprint

## 1. High-Level Game Overview
* **Game Concept:** A circular multi-player plot survival and collection game where players gather cards and packs in the arena, deposit them into their base Inspector, grade and trade them at the shared Central Grader, summon Drones (pets), and prestige through Rebirth mechanics.
* **Ultimate Objective:** Rebirth multiple times to secure permanent bonuses (such as improved Pack Odds and stat multipliers), scale your power, upgrade your BaseAssets and Drones, and dominate the Central Arena.
* **Core Gameplay Loop:** 
  Collect Cards/Packs in Arena -> Deposit at Base Inspector -> Grade at Central Grader -> Sell / Upgrade / Fuse / Repack -> Equip Drone -> Arena PvP & Battle Mode -> Rebirth

---

## 2. Core Systems & Mechanics

### A. Base & Real Estate System
* **Layout:** $N$ plots arranged in a circle, facing inward toward the shared Central Arena.
* **Assignment:** Automatically assigned to a single player upon joining via `PlotManager`. Only the owner can interact with their BaseAssets.
* **BaseAssets & Zones:**
  1. **Inspector Zone:** A BaseAsset located on every player's plot. Players deposit what they collected in the arena; the Inspector opens packs, cleans/repairs card condition, and sells raw items. It cannot grade or sell upgraded items.
  2. **CardPacker Zone:** A placeable Asset used to repack Cards back into sealed CardPacks to be sold at the Central Grader.
  3. **DroidMinion Zone:** Houses the DroidMinion worker structure, which manages Droid repairs, maintenance, and level upgrades using its internal endurance/supply pool.
  4. **Smithy Zone:** Crafting/refining station for advanced gear and upgrades.

### B. Cards, Condition, Grading & Economy
* **Card & Pack Flow:** Items spawn in the arena as Raw Cards or CardPacks. Raw cards must be graded to maximize value.
* **Card Properties:**
  * **Rarity:** Tier (e.g., Common, Rare, Epic). Fixed and never changes.
  * **Stats:** Damage, Stamina, Health, and Special. They boost your Drone in PvP only and provide no direct sell value.
  * **Condition:** Wear and tear on the physical card that influences its likelihood of getting a high Grade. Cleaned and repaired at the Base Inspector.
  * **Grade:** Quality rating assigned at the Central Grader, setting the Card's ultimate value and power.
* **Upgrading, Fusing & Repacking:**
  * **Upgrade:** Spend cash to raise a Card's stats.
  * **Fuse:** Combine 3 Cards of the same Rarity into 1 for boosted stats (average Grade of the 3 components, Rarity remains unchanged).
  * **Repack:** Use a CardPacker to turn cards back into packs.
* **Economy & Graders:**
  * **Cash:** The primary currency earned by selling graded Cards or repacked CardPacks.
  * **Base Inspector:** One per Base; handles raw items, pack opening, and condition repairs.
  * **Central Grader:** A shared, public structure next to the Arena (PSA-style). Grades cards, buys graded cards/packs, and runs a rotating shop stock that replaces player-to-player trading.

### C. Drone (Pet) & DroidMinion Systems
* **Definition:** A Card that the player has equipped and summoned as an active companion (one active at a time).
* **DroneStats:** Identical to the source Card (Rarity, Grade, Stats). Upgrading the Drone requires upgrading its underlying Card.
* **Drone Modes:**
  * **Home Mode:** Stays within the owner's plot to be repaired, maintained, and leveled up by the DroidMinion.
  * **Follow Mode:** Trails behind the owner and defends them against hostile entities or players.
  * **Arena Mode:** Roams the Central Arena targeting non-owner players or pets that enter the zone.
  * **To Battle Mode:** A progressive stage/tower quick-combat system where the Droid fights other players' pets sequentially. Each cleared floor yields cash rewards.
  * **Movement Rule:** Droids physically navigate and move to targets rather than teleporting.
* **DroidMinion Structure:**
  * **Upgrades:** Upgradable via Cash to increase work speed and supply capacity (acting as an endurance/stamina pool).
  * **Function:** Automatically performs level upgrades for the Droid and restores Droid health after battles.

### D. Arena & Carry Rules
* **Combat Rules:** Players cannot damage each other directly; all combat is executed via Drones. Players take damage from both environmental hazards and enemy Drones.
* **Carrying Mechanics:**
  * Carried items stack visually on top of the player's head.
  * **Speed Penalty:** The more items a player carries, the slower their walking speed, calculated dynamically inside the arena (e.g., `WalkSpeed = math.max(4, 16 - (CarriedCount * 1.5))`). Outside speed defaults to normal.
  * **Damage Penalty:** Taking damage causes the player to drop everything they are carrying.
  * **Pickup Lock:** The damaged player cannot pick up their dropped items for 3 seconds, but other players can collect them immediately. Defeat only drops what is currently being carried.

### E. Progression & Rebirth
* **Rebirth Reset:** Resets all player cash, level, XP, plots, structures, and Grinders back to Level 1.
* **Persisted Data:** Keeps the Rebirth Count, owned Droids/Pets, and permanent stat multipliers (such as leveling speed, scrap processing speed, base movement speed, and Pack Odds).

---

## 3. Strict 4-Layer Modular Luau Architecture
All scripts created or modified must adhere to this folder structure and separation of responsibilities:

```text
ReplicatedStorage / ServerScriptService / StarterPlayer
  └── Features / [FeatureName]
       ├── Data/       --> [Feature]Data    (Static Configs, Constants, Types)
       ├── Utils/      --> [Feature]Utils   (Pure Math, Raycasts, Tweens, Helpers)
       ├── State/      --> [Feature]Manager (Runtime State, Game Rules, Validation)
       └── Execution/  --> [Feature]Server / [Feature]Client (Entry points, Events)