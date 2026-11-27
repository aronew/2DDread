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
