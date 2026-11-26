# DREAD

An isometric action-RPG twin-stick shooter (vertical slice) built in **Godot 4.7** with GDScript.
It plays fast and aggressive, with movement, gunplay, abilities and loot pulling against each other:
dash through formations, flank armoured brutes, pop bloaters inside crowds, execute staggered
enemies for health, and build around behaviour-changing legendaries.

> The art is placeholder, pre-rendered from procedural 3D models in Blender with colour, normal and
> emission passes. See [`docs/ASSETS.md`](docs/ASSETS.md) to drop in your own art.

![Hatchery combat](docs/screenshots/hatchery_combat.png)

## Run it

1. Open the folder in **Godot 4.7.x**. Godot imports the assets on first open.
2. Press **F5**. The main scene is `scenes/main.tscn`.

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | WASD | Left stick |
| Aim | Mouse (soft-locks onto enemies under the cursor) | Right stick (aim assist) |
| Fire weapon | LMB | RT |
| Havoc grenade launcher | RMB | LT |
| Dash (i-frames, 2 charges) | Space / Shift | A / LB |
| Shock Nova | Q | X |
| Seeker Swarm | E | Y |
| Rend: melee, executes staggered enemies | F / V | B / RB |
| Reload | R | R3 |
| Switch weapon | 1 2 3 / mouse wheel | D-pad |
| Inventory, attributes | Tab / I | Back |
| Pause | Esc | Start |
| Debug / performance overlay | F3 | — |
| Cycle graphics preset (Low / Medium / High) | F4 | — |

## What's in the slice

### Weapons
Each weapon is a data-driven `WeaponData` resource in `data/weapons/`.

| Weapon | Behaviour |
|---|---|
| **VIGIL Pulse Rifle** | Automatic pulse bolts; accuracy blooms under sustained fire. |
| **BREACHER Scattergun** | 10 pellets, loads shell by shell, huge knockback, falls off hard at range. |
| **TESLA Arc Caster** | Lightning that chains between targets. Runs on heat, never ammo. |
| **LANCE Rail Rifle** | Charged shot that pierces everything in a line. Loot drop. |
| **HAVOC Launcher** (RMB) | Lobbed grenades on recharging charges. |

### Enemies
Every attack is telegraphed on the ground before it lands.

| Enemy | Role |
|---|---|
| **Mite** | Flanking swarmer. Plants, then lunges in a straight line you can dodge. |
| **Spitter** | Ranged zoner. Kites and leads its shots; acid leaves puddles. |
| **Brute** | Frontal armour (70%) with a weak back (+60%) and slow turning. Slams in a marked circle, charges in a line, and stuns itself on walls. |
| **Bloater** | Explodes on players **and** enemies. Shoot it while it's next to its friends. |

- **Elites** can roll any of four affixes: **Frenzied**, **Shielded** (shield regenerates; breaking it staggers), **Volatile** (mines) and **Molten** (fire trail).

### Abilities
- **Shock Nova:** knocks enemies back, applies shock, and erases enemy projectiles.
- **Seeker Swarm:** homing missiles.
- **Rend:** lunges, parries projectiles, and executes staggered enemies for a health burst.

### Loot and progression
- **Rarities:** six, from Common to Mythic.
- **Stat affixes:** standard rolled bonuses.
- **Behaviour affixes:** pierce, ricochet, chain, split, crit-explode, ammo-on-kill, momentum.
- **Legendary perks:** for example, *every 5th shot explodes*, *dash leaves a lightning trail*, *critical kills chain lightning*, *kill streaks stack damage*.
- **XP and levels:** with four attributes to spend points in.

### Dungeon
The slice is one hand-built level:

1. Landing bay.
2. Conduit.
3. Hidden vault, behind a breakable wall.
4. Locked Hatchery arena, where nests spawn mites until you destroy them.
5. Shock-plate corridor.
6. Reactor arena with an elite finale.
7. Descent portal to the next depth, where enemies are stronger.

### Feel
- Hit-stop on impact.
- Trauma-based camera shake and recoil kicks.
- Dynamic normal-mapped lights from muzzle flashes and explosions.
- HDR bloom.
- Dissolve deaths and gore decals.
- Damage numbers.
- Post-processing: chromatic aberration kicks, low-health pulse.
- Two-layer music that rises with combat intensity.

## Project layout

```
src/autoload/   InputSetup, Events (signal bus), Game, Audio, VFX
src/core/       Iso projection math, sprite-sheet loader, DamageInfo
src/player/     Player controller + legs/torso compositor
src/combat/     WeaponData/Weapon, ProjectileSystem, Combat, Build (stats+perk hooks), perks, hazards
src/enemies/    EnemyData, Enemy base FSM, archetypes, elite affixes
src/abilities/  Shock Nova, Seeker Swarm, Rend
src/loot/       Item, Loot generation, pickups
src/dungeon/    Layout (ASCII), Dungeon (grid collision/raycasts/flow field/visuals), encounters, doors, hazards
src/ui/         HUD, inventory
src/vfx/        Shaders, camera, post-fx, telegraphs, procedural textures
src/debug/      BotDriver (automated playtester)
data/           Weapon and enemy .tres definitions (tune here)
tools/blender/  Asset pipeline (bpy)
tools/audio/    SFX/music synthesis
docs/           PLAN.md (architecture & decisions), ASSETS.md (art contract)
```

## Developer tools

```bash
# compile-check every script
godot --headless --path . res://tools/dev/check_scripts.tscn

# headless automated playthrough (prints a combat log)
godot --headless --path . --fixed-fps 60 -- --bot --quit-after=120

# harder probe: sloppy human-like aim, no dodging
godot --headless --path . --fixed-fps 60 -- --bot --bot-human --bot-nododge --quit-after=120

# rendered run with screenshots every 3 s of game time, starting in an arena
godot --path . --fixed-fps 30 -- --bot --start=hatchery --shots=/tmp/shots --shot-every=3 --quit-after=20

# jump straight to a room / depth while playing
godot --path . -- --start=reactor --depth=2
```

Rooms you can pass to `--start`: `landing`, `conduit`, `vault`, `hatchery`, `spine`, `reactor`.

## Performance & graphics presets

F4 cycles **Low / Medium / High** (saved to `user://settings.cfg`). On first launch the game picks
Low for integrated GPUs and Medium otherwise, and steps down automatically (up to twice) if the frame
rate stays under ~45 FPS. F3 shows FPS, frame/script time, draw calls, video memory and the GPU name.

| | Low | Medium | High |
|---|---|---|---|
| Bloom | off | wide levels only | full |
| HDR 2D | off | on | on |
| Background fog | flat colour | 2 texture layers | 3 layers + shafts + motes |
| Static lights | key lights | + accents | + overhead fill pools |
| Post-process | overlay only (no screen copy) | full | full |
| Render cap on >1080p screens | 1080p | 1080p | native |
| Particles | 50% | 80% | 100% |

Sprites import as VRAM-compressed (DXT/BC) textures: ~122 MB of video memory instead of ~544 MB.

## Exporting

Sprite-sheet metadata (`assets/sprites/**/*.json`) is read at runtime with `FileAccess`. In the
export preset, add `*.json` under **Resources → Filters to export non-resource files**.
