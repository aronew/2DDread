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
| `stair_01_guide.png` / `_lines.png` / `_guide.json` | **room 4, upper half: THE GREAT STAIR** (the gallery and the stair down), waiting for its SOL painting (`--look=65.94,2.44 --zoom=0.62`). Prompt below |
| `undercroft_01_guide.png` / `_lines.png` / `_guide.json` | **room 4, lower half: THE UNDERCROFT** (the hall two levels down), waiting for its SOL painting (`--look=71.94,12.98 --zoom=0.66`). Prompt below |
| `altar_01_guide.png` / `_lines.png` / `_guide.json` | **room 3, THE BONE ALTAR** (`--look=46.1,1.8 --zoom=0.72`). `altar_01_painted_sol.webp` is the owner's SOL painting of it, in the game as `assets/rooms/altar_01` |
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

Imported as `altar_01` (`altar_01_painted_sol.webp`). SOL dropped the banners, torches,
braziers and candles (shrubs and small doors instead) and added ruin fragments on the
abyss in the top-left corner, which were blacked out before import. The layout's props
were changed to match; the bone nests keep their own sprites over the painted shrubs.

## Prompt for SOL: room 4, the Great Stair and the Undercroft (two paintings)

Room 4 is too big for one image, so it has two guides that overlap at the stair. Paint
the upper one first; for the lower one, attach the finished upper painting too if SOL
takes a fourth image, so the stair and the terrace faces match. This room has **two
floor levels**: the Undercroft lies 3.3 m below the gallery. Always attach the
`_guide.png` as well: the line art alone doesn't show that the terrace faces are walls
going down.

**Upper painting (`stair_01`):** attach `stair_01_lines.png` (image 1), the mockup
(image 2) and `stair_01_guide.png` (image 3). Use the temple prompt above with this
"What things are" list:

> What things are:
> - This room has two floor levels. The big floor in the middle is a raised gallery. The
>   lower floor at the bottom left is a sunken hall, about twice a person's height below
>   it.
> - The long wall at the back (top, running down to the right) is a towering temple wall,
>   about three times a person's height: hooded-figure murals with gold laurel branches,
>   arched niches with green soul-fire, gold Greek-key bands, dark green stone blocks up
>   to a heavy cornice, with tall fluted stone columns against it. The short block at the
>   top left is the corner of the same wall, with a column.
> - The narrow strip at the far left, edged in gold, is the stone bridge the player
>   arrives on, over the black abyss. Paint everything left of it pure black.
> - The thin gold lines on the gallery floor are a processional strip of gold Greek-key
>   inlay leading to the stair.
> - At the front edge of the gallery, the floor drops away: the two tall green walls with
>   a gold Greek-key band along their top edge are the stone faces of the terrace, going
>   straight down to the lower floor. Between them, a wide stone staircase descends
>   toward the viewer, cut into the terrace (its left side is a solid stone wall, its
>   steps run down to the lower floor). Keep every step where its lines are.
> - The two bronze tripod bowls with green flames flanking the top of the stair, and the
>   others, are soul-fire braziers. The short shape on a square base is a broken column.
> - The vase pairs are red-orange Greek amphorae, the lidded urns are sealed fire urns,
>   the small clusters are lit candles. The round gold shapes on the floor are a
>   laurel-and-skull emblem and a sunburst plate.
> - At the bottom left, the walls, columns and niches belong to the lower hall.

**Lower painting (`undercroft_01`):** attach `undercroft_01_lines.png` (image 1), the
mockup (image 2), `undercroft_01_guide.png` (image 3) and, if SOL takes it, the finished
upper painting (image 4). Same prompt, with this list:

> What things are:
> - This is a sunken hall, the Undercroft. The floor at the top right is a raised gallery
>   about twice a person's height above it: its front edge is a tall green stone terrace
>   wall with a gold Greek-key band along the top. A wide stone staircase comes down from
>   the gallery in the middle of that wall, toward the viewer, onto the hall's floor.
>   (If image 4 is attached, it is my painting of the gallery: match its stair, walls
>   and floor.)
> - The wall along the left is a towering temple wall: hooded-figure murals with gold
>   laurel branches, arched niches with green soul-fire, gold Greek-key bands, dark green
>   stone blocks; the two lower blocks nearest the stair are only as tall as the terrace.
>   Fluted stone columns stand against it.
> - The four tall shapes on square bases in the hall are fluted stone columns. The long
>   low block in the middle is a stone sarcophagus with gold trim.
> - The bronze tripod bowls with green flames are soul-fire braziers, the vase pairs are
>   red-orange Greek amphorae, the lidded urn is a sealed fire urn, the small clusters
>   are lit candles, the round gold shape on the floor is a laurel-and-skull emblem.
> - Keep the bare floor in front of the sarcophagus plain stone: a portal glows there.
>
> Light: dim and cold, a crypt; green from the braziers and niches, warm only at the
> candles. The hall's front and right edges break off into black abyss.

Import each with its own guide's camera: `stair_01` with `stair_01_guide.json`,
`undercroft_01` with `undercroft_01_guide.json`, and add both to `LayoutTemple.PAINTS`
in that order (the lower one on top). Black out anything SOL paints left of the bridge
in `stair_01` before importing: that part of the frame is room 3, which has its own
painting.

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
