# Paint guides: using generated art (SOL) for whole rooms

The game renders a room at its exact camera; an image generator repaints that frame in
the mockup's style; the game lays the painting back over the same room. Gameplay
(collision, pits, enemies) still comes from the layout, so the painting only has to keep
the architecture where it is.

## Files

| File | What it is |
|---|---|
| `temple_02_guide.png` | **current** 1536×1024 frame of the temple room (`--level=temple`), tall back walls, no HUD, no player |
| `temple_02_lines.png` | the same frame as line art, for generators that follow outlines more strictly |
| `temple_02_guide.json` | where the frame looks: `world_to_image` maps game positions to image pixels |
| `altar_01_guide.png` / `_lines.png` / `_guide.json` | **room 3, THE BONE ALTAR**, waiting for its SOL painting (`--look=46.1,1.8 --zoom=0.72`). Prompt below |
| `sanctum_01_guide.png` / `_lines.png` / `_guide.json` | **room 2, THE HOODED SANCTUM** (`--look=29.6,1.8 --zoom=0.72`). Prompt below. `sanctum_01_painted_sol.webp` is the owner's SOL painting of it, in the game as `assets/rooms/sanctum_01` |
| `temple_01_*` | the first guide (closer framing). `temple_01_painted_sol.webp` is the first SOL painting (low walls); **`temple_01_painted_sol_v2_tall.webp` is the one in the game**: tall walls, painted at this guide's framing (the floor layout didn't change when the walls grew, so this guide's camera still fits) |

The step-by-step recipe for a new room is section 0 of `CLAUDE.md`. Helpers:
`tools/rooms/guide_lines.py` (line art from a guide), `tools/rooms/check_paint.py`
(overlay a painting on a guide's lines), `tools/rooms/import_room_paint.py`.

Make a new guide (any room, any framing):

```bash
VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json xvfb-run -a -s "-screen 0 1536x1024x24" \
  godot --path . --resolution 1536x1024 --fixed-fps 30 --audio-driver Dummy -- \
  --level=temple --look=5.0,7.6 --zoom=0.72 --paint-guide --shots=/tmp/guide --shot-every=5 --quit-after=2.2
```

## Prompt for SOL

Attach `temple_02_lines.png` (image 1) and `docs/concept/mockup_01_soul_fire_temple.webp`
(image 2); if SOL takes a third image, add `temple_02_guide.png` (it shows which shapes
are pits, walls and floor). Then:

> Image 1 is line art of my game room, seen from the game's camera. Image 2 is the art
> style I want.
>
> Paint image 1 as a finished, full-colour game background in the exact style of image 2.
>
> Keep the layout identical to image 1: same camera angle, same framing, same 1536×1024
> landscape size. Every wall, column, pit, bridge, floor edge, urn and candle stays
> exactly where its lines are, at the same height. Do not add, move or remove any
> architecture.
>
> What things are:
> - The two long walls at the back (left and top) are towering temple walls, about three
>   times a person's height. Lower part: hooded-figure murals with gold laurel branches
>   and arched niches with green soul-fire. Above that: a gold Greek-key band and dark
>   green stone blocks up to a heavy cornice. Tall fluted stone columns stand against them.
> - The three rectangular holes are soul-fire pits: a narrow stone lip, dark masonry walls
>   inside, bright green fire glowing low inside.
> - The two strips between the pits are bridges with gold Greek-key bands and gold
>   sunburst plates at their ends.
> - The round shapes on square bases are broken stone columns.
> - The two vases are red-orange Greek amphorae; the small clusters are lit candles.
> - The small round shape on the floor at the right is a gold laurel-and-skull emblem.
>
> Style: Hades-like hand-inked painting, thick dark ink outlines, three-band cel shading
> with purple-tinted shadows, dark green-black stone with gold accents. The floor is
> small worn stone pavers with cracks, a few missing stones, rubble and green moss
> patches; keep it calm and fairly low-contrast so characters stand out. Green light from
> the pits and niches spills onto the stone around them, with a warm glow around the
> candles. Pure black outside the floor edges.
>
> Empty room: no characters, no enemies, no projectiles, no UI, no text.

Send the result back as a PNG file (not pasted inline) so it can be imported.

## Prompt for SOL: room 2, the Hooded Sanctum

Attach `sanctum_01_lines.png` (image 1), the mockup (image 2) and, if SOL takes a third
image, `sanctum_01_guide.png`. Use the temple prompt above with this "What things are"
list in place of the temple's:

> What things are:
> - The long wall at the back (top, running down to the right) is a towering temple wall,
>   about three times a person's height: hooded-figure murals with gold laurel branches,
>   between arched niches with green soul-fire; gold Greek-key bands above; dark green
>   stone blocks up to a heavy cornice. Tall fluted stone columns stand against it.
> - The short block at the top left is the corner of the same wall (Greek-key bands, no
>   mural), with a column at its corner.
> - The long narrow strip at the far left, edged in gold, is a stone bridge over the
>   black abyss, leading back to the previous room (the floor in the top-left corner).
> - The two rectangular holes in the middle are a soul-fire moat: a narrow stone lip, dark
>   masonry walls inside, bright green fire glowing low inside. The short strip between
>   them is a bridge with gold Greek-key bands and gold sunburst plates at its ends.
> - The two tall shapes on square bases are fluted stone columns; the two short ones are
>   broken columns.
> - The two vase pairs are red-orange Greek amphorae; the small clusters are lit candles;
>   the two bronze tripod bowls with green flames are soul-fire braziers; the thin stand
>   by the back wall at the right is a candelabra.
> - The round gold shape on the floor at the front right is a laurel-and-skull emblem.
>   Keep the bare floor between the two braziers plain stone: a portal glows there.

Then check alignment with `sanctum_01_lines.png` and import with
`sanctum_01_guide.json` as `sanctum_01` (section 0 of `CLAUDE.md`), and add
`"res://assets/rooms/sanctum_01"` to `LayoutTemple.PAINTS`.

## Prompt for SOL: room 3, the Bone Altar

Attach `altar_01_lines.png` (image 1), the mockup (image 2) and, if SOL takes a third
image, `altar_01_guide.png`. Use the temple prompt above, replacing its "What things
are" list and its light sentence with these:

> What things are:
> - The long wall at the back (top, running down to the right) is a towering temple wall,
>   about three times a person's height: long crimson cloth banners hang between gold
>   Greek-key bands, with bronze wall torches burning warm orange beside them. In its
>   middle, behind the altar, is one hooded-figure relief with gold laurel branches. Dark
>   green stone blocks rise to a heavy cornice; tall fluted stone columns stand against it.
> - The short block at the top left is the corner of the same wall (Greek-key bands), with
>   a column at its corner.
> - The long narrow strip at the far left, edged in gold, is a stone bridge over the
>   black abyss, back to the previous room (the floor in the top-left corner).
> - The thin gold line on the floor from the bridge to the middle is a processional strip
>   of gold Greek-key inlay.
> - The long block in the middle is a stone sacrificial altar with a gold rim and dark
>   carved panels. Gold sunburst plates are set in the floor at its two ends, and two
>   bronze tripod braziers with green flames stand beside it.
> - The two tall shapes on square bases are fluted stone columns; the two short ones are
>   broken columns.
> - The three low heaps are nests of old bones and gnarled roots with a faint green glow
>   inside. The two lidded urns are sealed fire urns with glowing orange cracks.
> - The vase pair at the bottom is red-orange Greek amphorae; the small clusters are lit
>   candles. The round gold shape on the floor is a laurel-and-skull emblem.
> - Keep the bare floor just right of the amphorae at the bottom plain stone: a portal
>   glows there.
>
> Light: this room is lit warm orange by the torches and candles, with green only from
> the braziers and the bone nests. Keep the floor calm and the corners dark.

Then check alignment with `altar_01_lines.png` and import with `altar_01_guide.json` as
`altar_01`, and add `"res://assets/rooms/altar_01"` to `LayoutTemple.PAINTS`.

## Importing a painting

```bash
python3 tools/rooms/import_room_paint.py PAINTING docs/paint_guides/temple_02_guide.json temple_02
```

writes `assets/rooms/temple_02.png/.json`. Use the camera JSON of the guide the painting
actually follows (overlay its `_lines.png` on the painting to check: pits, columns and
urns should line up); then list `"res://assets/rooms/temple_02"` in
the layout's `PAINTS` (see `layout_temple.gd`) and run `godot --headless --path . --import`.
`--no-paint` shows the room without it. The painting must have **pure black** outside
the floor: that black, where it touches the image border, becomes transparent.

## Limits

- One generated image is about one screen of sharp detail. Rooms bigger than a screen
  need several overlapping paintings (or outpainting from the first one).
- Small shifts are fine (the importer can nudge the painting into place), but moved or
  invented walls won't match collision, so ask SOL to fix those before importing.
- Painted rooms are one-off art: best for hand-built rooms. Procedural rooms use the
  modular kit, which SOL can also paint piece by piece from exact-camera guides.
