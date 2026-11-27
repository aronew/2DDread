# DREAD — Implementation Plan (Vertical Slice)

Working title. Godot 4.7.x · GDScript · Forward+ 2D renderer with HDR-2D glow.

## 1. Audit of the existing project

The repository was empty: no scenes, scripts, or legacy mission/wave structure.
Nothing to preserve or refactor, so every system below is built for the target
design from day one.

## 2. Key technical decisions

| Decision | Why |
|---|---|
| **Pre-rendered 3D → 2D sprites (Blender/bpy, Cycles)** | Gives the dimensional, illustrated look of the references while running entirely on Godot's 2D renderer. |
| **Three passes per sprite: colour, normal, emission** | Normal maps let `PointLight2D` muzzle flashes/explosions relight characters and walls; the emission pass is drawn additively with HDR values so neon parts bloom. |
| **Normals encoded in a "top-down" frame** (R = screen right, G = screen up, B = world up) | Matches how Godot's `Light2D.height` model works, so floors light evenly and vertical wall faces only catch light from lights in front of them. |
| **Camera: ortho, 45° yaw, 30° pitch (ground diamond 256×128 = 2:1)** | Classic 2:1 isometric, matching the owner's mockup: walls show their faces and rooms read wide. (Was 48.6° / 4:3 for steeper twin-stick readability until Nov 2026.) |
| **Gameplay simulated in "ground space"** (`g = (screen.x, screen.y / K)`, K = 0.5) | Distances, AoE radii, speeds and knockback are true metric values; rendering is a cheap y-scale. |
| **Custom grid collision instead of physics bodies** | Walls are grid cells → circle-vs-square in tile space is exact, cheap, has no ghost-edge snagging, and scales to many enemies. DDA raycasts give exact projectile/wall hits and ricochet normals. |
| **Split player sprite: legs (move dir) + torso (aim dir, 32 dirs)** | True twin-stick: run one way, shoot another; legs backpedal instead of twisting 180°. |
| **Data-driven `Resource`s** (`WeaponData`, `EnemyData`) + perk scripts with hooks | New weapons/enemies/modifiers without touching the combat core. |
| **Signal bus (`Events`)** | HUD, audio, VFX, progression and encounters react to combat without hard references. |

## 3. Systems map

```
autoload/  InputSetup · Events · Game (hit-stop, refs, RNG) · Audio · VFX
core/      Iso math · SheetDB (sprite sheets → CanvasTextures) · IsoSprite · DamageInfo · Stats
player/    Player (movement, dash, aim, weapons, abilities) · PlayerVisual (legs/torso compositing)
combat/    WeaponData · Weapon · ProjectileSystem · CombatGrid (spatial hash) · Status effects · Perks
enemies/   EnemyData · Enemy (base FSM) · Mite · Spitter · Brute · Bloater · Elite affixes
abilities/ Shock Nova · Seeker Swarm · Hellfire Saber (RMB: combo / dash-slash / execute)
loot/      Item generation (6 rarities, affixes, legendary perks) · Pickups · Inventory
dungeon/   Layout (ASCII, hand-authored) · Dungeon builder · Rooms/encounters · Doors · Props/hazards
ui/        HUD · Minimap · Inventory screen · Damage numbers
tools/     Blender asset pipeline · audio synthesis
```

## 4. Phases (each produces something playable)

1. Movement + aim + camera in a lit test room.
2. Weapons + projectile system (rifle, scattergun, arc caster, rail lance, Havoc launcher).
3. Enemy base AI, damage, stagger, knockback, death.
4. Combat feel: VFX pools, hit-stop, trauma shake, lights, damage numbers, synthesized audio.
5. Dash (i-frames), Shock Nova, Seeker Swarm, Rend melee/execute.
6. Enemy roster (Mite, Spitter, Brute, Bloater) + elite affixes + encounter beats.
7. XP, levels, attributes, loot rarity, behaviour-changing modifiers, inventory.
8. Hand-crafted test dungeon: arenas, corridors, hazards, hidden treasure room, elite finale.
9. Automated playtests (scripted bot + screenshots), tuning, optimisation.

## 5. Design guardrails

* Movement is never locked by animations. Firing, dashing and abilities overlap freely.
* Every enemy attack is telegraphed (pose + ground marker + sound) and interruptible by stagger.
* Encounters mix roles: swarmers pressure, spitters zone, brutes anchor, bloaters punish clumping.
* Camera shake is trauma-based and budgeted; hit-stop only on heavy hits, crits and kills.
* Modifiers change *behaviour* (pierce, ricochet, split, chain, explode, sustain), not only numbers.

## 6. Status (end of first slice pass)

All nine phases have a playable first pass. The automated bot plays the full route,
including the elite finale and descending to depth 2, with no script errors.

**Playtest data** (bot, 120 s of game time):

| Bot profile | Damage taken | Deaths |
|---|---|---|
| Perfect aim + dodging | ~45–100 | 0 |
| Human-like aim, no dodging | ~240–270 | 0 |

An unleveled bot entering the Reactor directly with starter gear can die there.

**Tuning levers:** everything lives in `data/weapons/*.tres`, `data/enemies/*.tres`,
and the beat lists in `src/dungeon/layout_test.gd`.

### Known gaps / next steps (priority order)

1. **Human playtesting on real hardware.** Tune time-to-kill, enemy density and
   the healing loops by feel; check GPU frame time with many lights.
2. **Art.** Replace the Blender placeholders with final art (see ASSETS.md).
   Add hit-reaction and death frames once characters are hand-made.
3. **Enemy roster.** The architecture already supports flying (`EnemyData.flying`)
   and summoner behaviours. A boss with phases is the next big content beat.
4. **Skill tree.** Attributes and perk-bearing gear exist; a node-based passive
   tree can reuse `Build.stat()` / perk hooks.
5. **Procedural dungeons.** Rooms are already data (rects + beats) over an ASCII
   grid; stitching authored room chunks is the planned route.
6. Options menu (rebinding, volume, screen shake strength), save/load of character.
