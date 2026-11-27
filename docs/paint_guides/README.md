# Paint guides: using generated art (SOL) for whole rooms

The game renders a room at its exact camera; an image generator repaints that frame in
the mockup's style; the game lays the painting back over the same room. Gameplay
(collision, pits, enemies) still comes from the layout, so the painting only has to keep
the architecture where it is.

## Files

| File | What it is |
|---|---|
| `temple_01_guide.png` | 1536×1024 frame of the temple room (`--level=temple`), no HUD, no player |
| `temple_01_lines.png` | the same frame as line art, for generators that follow outlines more strictly |
| `temple_01_guide.json` | where the frame looks: `world_to_image` maps game positions to image pixels |

Make a new guide (any room, any framing):

```bash
VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json xvfb-run -a -s "-screen 0 1536x1024x24" \
  godot --path . --resolution 1536x1024 --fixed-fps 30 --audio-driver Dummy -- \
  --level=temple --look=5.2,8.3 --zoom=0.8 --paint-guide --shots=/tmp/guide --shot-every=5 --quit-after=2.2
```

## Prompt for SOL

Attach `temple_01_guide.png` (and optionally `temple_01_lines.png`) plus
`docs/concept/mockup_01_soul_fire_temple.webp`, then:

> Image 1 is a screenshot of my game room. The last image is the art style I want.
> Repaint image 1 as a finished hand-painted game background in the exact style of the
> last image.
>
> Keep the layout identical to image 1: same camera angle, same framing, same 1536×1024
> size. Every wall, column, pit, bridge, floor edge and prop stays in exactly the same
> place and size. Do not add, move or remove any architecture.
>
> Style: Hades-like hand-inked painting, thick dark ink outlines, three-band cel shading
> with purple-tinted shadows. Dark green-black stone with gold Greek-key trim. Hooded-
> figure murals with gold laurels and green soul-fire niches on the left wall. Bright
> green soul-fire glowing inside the pits, with light shafts on their walls. Small worn
> stone pavers with cracks, a few missing stones, rubble and green moss patches. Warm
> glowing candles. Black abyss outside the floor. Keep the walkable floor calm and fairly
> low-contrast so characters stand out.
>
> Empty room: no characters, no enemies, no projectiles, no UI, no text.

Send the result back as a PNG file (not pasted inline) so it can be imported.

## Limits

- One generated image is about one screen of sharp detail. Rooms bigger than a screen
  need several overlapping paintings (or outpainting from the first one).
- Small shifts are fine (the importer can nudge the painting into place), but moved or
  invented walls won't match collision, so ask SOL to fix those before importing.
- Painted rooms are one-off art: best for hand-built rooms. Procedural rooms use the
  modular kit, which SOL can also paint piece by piece from exact-camera guides.
