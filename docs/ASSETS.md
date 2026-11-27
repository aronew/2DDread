# Art & Audio Asset Contract

**Style target:** hand-inked, cel-shaded mythic underworld (Hades-like): thick ink
silhouettes, 3-band toon shading with purple-tinted shadows, gold trim, green soul-fire and
warm torchlight. The placeholder art gets this look from `common.render_stylized()`, which
renders flat-albedo / lighting / depth+material / normal / emission passes and composites
them into banded shading + ink lines (supersampled 2×). Tune it via `common.STYLE`.

Everything visual in the game is loaded from sprite sheets described by a small
JSON file. The current art is **placeholder** rendered by the Blender pipeline in
`tools/blender/`. Replace it with your own environment, enemy and character art
by dropping in files that follow this contract. No code changes are needed.

## 1. The projection (match this and everything lines up)

| Property | Value |
|---|---|
| Camera | Orthographic, yaw **45°**, pitch **30°** (= asin 0.5): classic 2:1 isometric |
| Ground scale | **90.51 px per metre** horizontally |
| Height scale | **78.38 px per metre** of vertical height on screen |
| Grid cell | 2 m × 2 m → screen diamond **256 × 128 px** (2:1) |
| Character | ~1.9 m tall ≈ 150 px from feet to hat |

If you model in 3D, reuse the rig in `tools/blender/common.py` (`setup_camera`,
`setup_lights`). It reproduces the projection exactly. If you paint in 2D, draw
on top of a 256×128 diamond guide and keep vertical edges vertical.

**Directions.** Directional sheets store one direction per row.
- **Row 0:** facing screen-right.
- **Row 4 (of 16):** facing the camera (screen-down).
- **Row 8:** facing left.
- **Row 12:** facing away.

Rows are evenly spaced, going clockwise on screen.

## 2. Sheet files

For a sheet named `mite_run` in `assets/sprites/enemies/`:

```
mite_run.json      required — metadata
mite_run_c.png     required — colour (RGBA, straight alpha)
mite_run_n.png     optional — normal map (lights relight the sprite)
mite_run_e.png     optional — emission (RGB, black = no glow, drawn additively + bloom)
```

```json
{
  "name": "mite_run",
  "frame_w": 128, "frame_h": 128,
  "origin": [64, 84],
  "rows": 16, "cols": 8,
  "dirs": 16,
  "files": {"color": "mite_run_c.png", "normal": "mite_run_n.png", "emit": "mite_run_e.png"}
}
```

* `origin` is the pixel that sits on the entity's ground position: feet for
  characters, base centre for props, diamond centre for tiles and walls.
* Leave `normal` or `emit` out of `files` if you don't have them. Sprites
  without normals are lit flat. Sprites without emission still get the
  gameplay silhouette rim (cyan player / red enemy / gold elite).

### Normal map encoding

These are not tangent-space normal maps. Normals live in a top-down frame
that matches Godot's `Light2D.height` model:

* **R:** points screen-right.
* **G:** points screen-up, meaning away from the camera on the ground.
* **B:** points world-up.

| Surface | RGB |
|---|---|
| Flat floor / top of anything | (128, 128, 255) |
| Wall face facing screen lower-right | (218, 37, 128) |
| Wall face facing screen lower-left | (37, 37, 128) |

`tools/blender/common.py → normal_override_material()` generates these.

## 3. Sheets the game expects

| Sheet | Layout | Notes |
|---|---|---|
| `player/player_legs` | 16 dirs × 9 cols (8 run frames + 1 idle) | meta `bob_m`: 8 pelvis offsets (m) so the torso bobs in sync |
| `player/player_torso_<rifle\|shotgun\|arc\|rail>` | 32 dirs, grid 4 rows × 8 cols, row-major | meta `muzzle_m`: [forward, left, height] in metres; optional `muzzle2_m` = second barrel (twin revolvers alternate) |
| `ui/portrait.png` | single image | HUD portrait shown in the gold diamond |
| `enemies/<name>_<anim>` | 16 dirs × N frames | names come from `EnemyData.sheet_move` / `sheet_attack` (hound, witch, legion, skull) |
| `env/floor_tiles` | 1 row × N kinds | 264×184 frames, origin (132,70); slab sides hang below the diamond so platform edges form automatically |
| `env/wall_blocks` | 1 row × N kinds | 260×400 frames, origin (130,318); 3 m tall full-cell blocks. Kind `cut` is a waist-high wall the game uses for near-side walls automatically |
| `env/low_blocks` | 1 row × N kinds | movement blockers that bullets pass over |
| `env/pit_coping` | 1 row × 16 pieces | 264×160 frames, origin (132,70) = a tile **vertex**. Column = 4-bit mask of which cells around the vertex are pit (bit 0 = cell (−1,−1), 1 = (0,−1), 2 = (−1,0), 3 = (0,0)); 0 and 15 are empty |
| `env/pit_wall.png`, `env/pit_flames.png` | single images | not sheets: PitFire draws them at runtime. `pit_wall` tiles both ways (1.5 m × 0.73 m per repeat), `pit_flames` tiles along x (2 m × 0.87 m), flame tips at the top |
| `props/<name>` | 1 row × frames | chest: frame 1 = open; eggs: frame 1 = swollen |

Wall and floor index order is listed in each JSON's `kinds` array. The ASCII
legend in `src/dungeon/layout_test.gd` maps characters to those indices. Floor kinds
11–18 are bridge decks (`bridge_<i|j>_<single|start|end|mid>`); layouts don't name them
directly, they mark bridge cells `B` and the game picks the piece.

The coiled whip on the left hip is part of the legs sheet. The whip's rope is
not a sprite: `src/player/whip_visual.gd` draws it live (an ink outline plus a
leather gradient with an ember tip), so its reach can change on every crack.

The legs and torso split exists so the legs follow movement while the torso
follows aim. Both layers share the same feet origin. If you author a single
full-body character instead, put it all in the torso sheets and give the legs
sheet transparent frames.

## 4. Swapping art

1. Export your frames into the layout above. Any frame size works as long as
   the JSON says so.
2. Overwrite the PNG/JSON files and reopen Godot (it re-imports automatically).
3. For a new enemy, add `data/enemies/<id>.tres` pointing at your sheet names,
   then a behaviour class (see `src/enemies/`).

To regenerate the placeholder art:

```bash
/path/to/python-with-bpy tools/blender/build_player.py
/path/to/python-with-bpy tools/blender/build_enemies.py
/path/to/python-with-bpy tools/blender/build_env.py
```

These scripts need the `bpy` module (`pip install bpy==5.3.0`) plus `pillow` and `numpy`.

## 5. Painted textures (environment)

Floors and walls can be painted instead of modelled in flat colours. Paint a flat,
straight-on texture (never isometric), save it in `tools/blender/textures/`, and the
Blender kit wraps it onto the existing blocks. The game camera, shading bands, ink lines,
normal maps and glow passes all still come from the renderer, so the result matches the
rest of the art and the sheet contract above doesn't change.

| Texture | Shape | Used for |
|---|---|---|
| `floor_flag.png` | square, tiles both ways, covers one 2 m cell | the main floor (`.`) and under floor details |
| `floor_cracked.png`, `floor_moss.png` | same as above | `w` and `,` cells |
| `floor_border_meander.png` | ~3:1 strip, tiles left–right | the gold Greek-key walkway (`h`) |
| `floor_emblem_skull.png` | square, single image | the laurel emblem (`o`), as a raised plate |
| `wall_ashlar.png` | 2:3, one wall face 2 × 3 m, tiles left–right | every built wall block; gold band 17–32% down |
| `soulfire_flames.png` | 2:1, flames on black | glowing back of the `M` fire alcoves |

Rules for new textures: albedo only (no baked light or shadows), seamless where the
table says so, and the palette and readability rules from the prompt book. Which file
each kind uses lives in `tools/blender/build_env.py → PAINTED`. After adding or
replacing one, run `build_env.py -- floors walls` and then `godot --headless --path .
--import`.

### Painted props

The prop sheets are currently the owner's painted sprites, imported by
`tools/blender/import_painted_props.py` (sizes and glow sources are in its `PROPS`
table). To swap in new painted props, replace the PNGs in
`tools/blender/textures/kit_2026-11-27/sprites/` (transparent background, one object per
image, same file names) and run the script, then `godot --headless --path . --import`.

## 6. Audio

Every combat action calls `Audio.play("<name>", ground_pos)`. Files live in
`assets/audio/<name>.wav`. The current set is synthesized by
`tools/audio/gen_sfx.py`. Replace any file with a recording of the same name.
Volume, pitch variation, rate limit and voice count per sound are in
`src/autoload/audio.gd → SFX`. Music is two seamless loops (`music_calm`,
`music_combat`) cross-faded by combat intensity.
