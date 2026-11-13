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

Movement uses server-driven model pivots with terrain checks and obstacle pathfinding. Arena damage targets the nearest eligible opposing companion or player inside the boundary and excludes the owner and ForceField-protected players. External player weapons must call the server-only Damage API to damage companions.

Run `python3 server/Companion/tests/run.py /path/to/luau` for pure rule tests. Real DataStore persistence, model placement, combat and responsive UI need Studio playtesting after sync. The existing profile store still uses GetAsync/SetAsync without cross-server session locking.

## Locomotion and visual rig contract

`CompanionLocomotion` owns local terrain probes, swept body clearance, bounded
steps/drops, ballistic jumps/falls, rate-limited asynchronous path requests, and
safe recovery. Mode changes and teleports invalidate pending route results.
Pathfinding suggests routes; every next movement still passes traversal checks.
Raises between StepHeight and JumpHeight are probed ahead of the body and jumped;
path jump waypoints launch even when the next surface reads as blocked. Jump
headroom and ascent checks use a thin column so an obstacle beside the body does
not cancel the launch.
A blocked/unreachable target leaves the companion stopped while routing retries.
Follow retains its existing long-distance catch-up teleport. Defeated companions
stop walking and recover at Home. Traversal limits live in `CompanionData`.

The server publishes `CompanionGrounded`, `CompanionLocomotionState`,
`CompanionVerticalSpeed`, `CompanionLandingSpeed`, `CompanionGroundOffset`,
`CompanionRigHeight`, `CompanionStrideLength`, and `CompanionTeleportId`.
`LastAttackTime` uses `Workspace:GetServerTimeNow()` on both server and client.
Damage remains immediate at the existing server attack interval; the cosmetic
strike has a short windup/strike/recovery envelope and does not authorize damage.

`CompanionRig` preserves existing rest transforms and connected joint chains.
Disconnected recognized limbs get motors using authored `<Joint>RigAttachment`
positions where available, otherwise dimension-based fallback pivots. Existing
rigid/indirect connections are preserved and warned about rather than replaced.
This avoids damaging authored rigs but cannot animate a limb welded rigidly to
its torso. Resolve those warnings with the Studio AI Assistant prompt below.

Optional `LeftFootIK` / `RightFootIK` controls must have valid ChainRoot and
EndEffector properties and `LeftFootTarget` / `RightFootTarget` attachments under
CompanionRoot (or HumanoidRootPart). Targets must encode the foot's neutral
orientation. Foot planting, surface alignment, moving-support tracking, bounded
reach, and pelvis lowering run when these exist. Without them, hips/knees/ankles
use a procedural gait with a stance/swing cycle. Exact foot contact without IK is
not guaranteed. Preserve a single Motor6D chain per limb and avoid duplicate
names. Every model needs a torso/primary part and a consistent upright pivot.

### User-run visual acceptance checks

- Flat ground: idle breathing without root drift; slow/fast walking, low charge,
  starts/stops and sharp turns. Check opposing arms, feet and torso clearance.
- Walk up/down steps under StepHeight; test slopes near MaxSlopeDegrees. Check
  knee clearance, sole placement, foot sliding and pelvis height on each template.
- Traverse a ledge above StepHeight but below JumpHeight; verify real ascent,
  falling pose, grounded landing and impact-scaled recovery. Check low ceilings.
- Approach walls, narrow passages, excessive drops and unreachable destinations:
  route or stop, never move through walls. Test moving/removing obstacles.
- Jump the owner while the companion is idle at Home or in Fight: no false jump.
- Change modes mid-route/midair; teleport, respawn, unequip/re-equip, and stream
  models in/out. No stale foot lock, yaw burst, route result or landing squash.
- Combat with two clients: one animation per attack with a shared timeline;
  wrists return to their rest poses after attacks and defeat.
- Home charging continues to drain the current station and cycle at depletion.

### Studio AI Assistant prompt for authored rigs

Inspect each companion template's torso, shoulders, elbows, wrists, hips, knees,
and ankles. Preserve appearance, scale, template names and unrelated assets.
Ensure one correctly directed Motor6D chain per limb; identify rigid welds or
alternate connections that prevent articulation and replace only the conflicting
limb connections. Preserve decorative welds to their intended limb. Put named
Left/Right ShoulderRigAttachment, ElbowRigAttachment, WristRigAttachment,
HipRigAttachment, KneeRigAttachment and AnkleRigAttachment attachments at the
actual anatomical pivots (e.g. LeftShoulderRigAttachment). Check mirrored axes
and neutral arm clearance. Configure optional LeftFootIK/RightFootIK with valid
leg chains, foot end effectors, knee poles, and neutral-oriented foot target
attachments under CompanionRoot. Do not run or debug game code. Report changes
and anything requiring my visual playtest.
