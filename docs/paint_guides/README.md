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
| `arena_01_guide.png` / `_lines.png` / `_guide.json` | **room 7, THE WEAVER'S DEEP**, the boss arena (`--look=136.5,11.5 --zoom=0.46`). `arena_01_painted_sol_jade.webp` is the owner's SOL painting, in the game as `assets/rooms/arena_jade`. Prompt below |
| `lethe_01_guide.png` / `_lines.png` / `_guide.json` | **room 6, THE ISLES OF LETHE** (`--look=112.75,8.25 --zoom=0.49`: the whole room, the corridor from room 5 and room 5's doorway walls in one frame). `lethe_01_painted_sol_jade.webp` is the owner's SOL painting, in the game as `assets/rooms/lethe_jade`. Prompt below |
| `shades_01_guide.png` / `_lines.png` / `_guide.json` | **room 5, THE HALL OF SHADES** (`--look=90.55,9.05 --zoom=0.525`, the whole hall in one frame). `shades_01_painted_sol.webp` is the owner's SOL painting, in the game as `assets/rooms/shades_01` (everything left of column 80, i.e. the Undercroft, clipped out). Prompt below |
| `stair_01_guide.png` / `_lines.png` / `_guide.json` | **room 4, upper half: THE GREAT STAIR** (the gallery and the stair down; `--look=65.94,2.44 --zoom=0.62`). `stair_01_painted_sol.webp` is the owner's SOL painting, in the game as `assets/rooms/stair_01` (gallery only). It stops at column 76; before import its painted right end (columns 75-76 and the edge lip) was copied one cell further along +i, so the floor reaches column 77 |
| `undercroft_01_guide.png` / `_lines.png` / `_guide.json` | **room 4, lower half: THE UNDERCROFT** (the hall two levels down; `--look=71.94,12.98 --zoom=0.66`). `undercroft_01_painted_sol.webp` is the owner's SOL painting, in the game as `assets/rooms/undercroft_01` (everything below the terrace's top edge) |
| `altar_01_guide.png` / `_lines.png` / `_guide.json` | **room 3, THE BONE ALTAR** (`--look=46.1,1.8 --zoom=0.72`). `altar_01_painted_sol.webp` is the owner's SOL painting of it, in the game as `assets/rooms/altar_01` |
| `sanctum_01_guide.png` / `_lines.png` / `_guide.json` | **room 2, THE HOODED SANCTUM** (`--look=29.6,1.8 --zoom=0.72`). Prompt below. `sanctum_01_painted_sol.webp` is the owner's SOL painting of it, in the game as `assets/rooms/sanctum_01` |
| `temple_01_*` | the first guide (closer framing). `temple_01_painted_sol.webp` is the first SOL painting (low walls); `temple_01_painted_sol_v2_tall.webp` added tall walls at this guide's framing (the floor layout didn't change when the walls grew, so this guide's camera still fits); **`temple_01_painted_sol_v3.webp` is the one in the game**: the owner's inked restyle of v2 (same edges, heavy ink, purple shadows) |

The step-by-step recipe for a new room is section 0 of `CLAUDE.md`. Helpers:
`tools/rooms/guide_lines.py` (line art from a guide), `tools/rooms/check_paint.py`
(overlay a painting on a guide's lines), `tools/rooms/import_room_paint.py`.

Make a new guide (any room, any framing):

```bash
VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json xvfb-run -a -s "-screen 0 1536x1024x24" \
  godot --path . --resolution 1536x1024 --fixed-fps 30 --audio-driver Dummy -- \
  --level=temple --look=5.0,7.6 --zoom=0.72 --paint-guide --shots=/tmp/guide --shot-every=5 --quit-after=2.2
```

## The current style (v3)

Every room painting in the game is now the owner's **v3** restyle: SOL repainted each
earlier painting with heavy black ink, flat cel shading and purple-tinted shadows (same
edges, so the layouts still match; only some props changed, and the layout's props were
moved to match). The `*_painted_sol.webp` files are the v3 versions (room 1:
`temple_01_painted_sol_v3.webp`; older versions are in git history). For a new room,
attach one of them as a style reference with the mockup, so the room comes out in the
same style.

**Repaint wanted (2026-11-27):** rooms are now enclosed (corridors between rooms, walls
on every edge, camera-side walls that fade near the player) and the background is black.
The current paintings predate that: the new walls keep their own art over them, and the
right half of room 1 was never painted. Next guides to paint:
`temple_east_01_guide.png` / `_lines.png` (room 1's right half, `--look=15.5,7.5
--zoom=0.8 --no-paint`), then fresh guides of each room with its new walls. Ask SOL to
paint the camera-side walls (the low dark blocks along the bottom edges of the guide) as
solid temple walls seen from behind, and to keep the area beyond the walls pure black.

Room 1's right half came back painted (`temple_east_01_painted_sol.webp`, imported
with `walls`): SOL painted the camera-side walls as solid blocks with Greek-key bands and
followed the guide closely. Use that phrasing for the next rooms.

### The jade set (in the game since 2026-11-27)

The owner repainted all seven paintings with a jade/teal palette and more irregular
stone (`*_painted_sol_jade.webp`: room 1 west from `temple_01`, room 1 east from
`temple_east_01`, rooms 2-5 from the `_02` guides below). Matching each to its guide was
automatic: edge correlation against every guide's line art picked the right one with a
clear margin. Each was clipped to its room with `tools/rooms/band_clip.py PAINTING
GUIDE_JSON OUT I0 I1` (bands in CLAUDE.md section 0), room 4's two halves also with the
terrace-edge `clip_paint.py` polygons above, then imported with `walls` (except room 1
west) as `assets/rooms/<room>_jade`. `--paint-set=v3` shows the previous set.

### Round 2: rooms 2-5 with their new walls (guides rendered 2026-11-27)

Same cameras as the `_01` guides (checked: identical `world_to_image`), so the floors,
pits and props sit exactly where the current paintings have them; what's new is the
walls on every side and the corridors in place of the bridges.

| Room | Attach (image 1 / optional image 3) | Room's prompt below |
|---|---|---|
| 2, Hooded Sanctum | `sanctum_02_lines.png` / `sanctum_02_guide.png` | room 2 |
| 3, Bone Altar | `altar_02_lines.png` / `altar_02_guide.png` | room 3 |
| 4, Great Stair (upper half) | `stair_02_lines.png` / `stair_02_guide.png` | room 4, gallery |
| 4, Undercroft (lower half) | `undercroft_02_lines.png` / `undercroft_02_guide.png` | room 4, Undercroft |
| 5, Hall of Shades | `shades_02_lines.png` / `shades_02_guide.png` | room 5 |

Image 2 is always the mockup; add one v3 painting (e.g. `temple_01_painted_sol_v3.webp`)
as a style reference if SOL takes it. Use each room's prompt below (swap `_01` for `_02`)
and add these lines to its "What things are" list:

> - The dark blocks along the bottom and right edges, nearest the camera, are solid
>   temple walls seen from behind, as tall as the others: dark green stone with a gold
>   Greek-key band, ending in a flat cap. Paint them solid.
> - The walled passages leading out of the room at the sides are stone corridors to the
>   next rooms: same floor, walls on both sides.
> - Everything outside the walls is pure black.

Import each with `walls` (`import_room_paint.py PAINTING GUIDE_JSON NAME walls`), using
the `_02` guide JSON. Neighbouring rooms and corridors at the frame edges will be painted
too: black them out with `clip_paint.py` where they belong to another room's painting
(room 4's two halves were split along the terrace edge this way; do the same again).

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

How they were imported: the two paintings agreed on the architecture but not on the
props where they overlap (the upper one painted shrubs at the stair head, the lower one
green-flame bowls), so each owns half of the room, cut along the terrace's top edge
with `tools/rooms/clip_paint.py`, and the layout's props follow whichever painting owns
their spot (all braziers became shrubs or urns):

```bash
EDGE="59,8 64,8 68,8 68,6 72,6 72,8 78,8"   # the gallery's front edge, around the stair
python3 tools/rooms/clip_paint.py docs/paint_guides/stair_01_painted_sol.webp docs/paint_guides/stair_01_guide.json /tmp/stair.png \
  "17,50 $EDGE 143,-57 243,43 117,150" "55,-100 55,100 -200,100 -200,-100"   # below the edge; room 3
python3 tools/rooms/clip_paint.py docs/paint_guides/undercroft_01_painted_sol.webp docs/paint_guides/undercroft_01_guide.json /tmp/under.png \
  "17,50 $EDGE 143,-57 -57,-257 -183,-150"                                     # above the edge
python3 tools/rooms/import_room_paint.py /tmp/stair.png docs/paint_guides/stair_01_guide.json stair_01
python3 tools/rooms/import_room_paint.py /tmp/under.png docs/paint_guides/undercroft_01_guide.json undercroft_01
```

(The lower painting's stair-head bowl also poked into the stair's top-right corner; those
few pixels were patched with the step beside them.) Both are in `LayoutTemple.PAINTS`,
the lower one last. A repainted `stair_01` that includes the gallery's right end
(columns 76-77: amphorae by the back wall, a fire urn near the edge) would finish the room.

## Prompt for SOL: the second shore, the Phlegethon (river of fire)

Nine guides, one painting each (rooms 3 and 4 of the owner's sketch are too wide for one
frame, so they have two):

| Guide | Room | `--look` | `--zoom` |
|---|---|---|---|
| `phl_ashfall` | 1 the Ashfall Landing | 60,7.5 | 0.6 |
| `phl_ossuary` | 2 the Giant's Ossuary | 60,22.5 | 0.5 |
| `phl_crossroads_west` | 3 the Burning Crossroads, west wing and centre | 52,39.5 | 0.52 |
| `phl_crossroads_east` | 3 the Burning Crossroads, east wing | 72,39.5 | 0.55 |
| `phl_gauntlet_court` | 4 the Cinder Gauntlet, the court | 36.5,21.5 | 0.58 |
| `phl_gauntlet_hall` | 4 the Cinder Gauntlet, the colonnade | 36.5,40 | 0.52 |
| `phl_vault` | 5 the Molten Vault | 36.5,57.5 | 0.6 |
| `phl_forgegate` | 6 the Forge Gate | 23,37.5 | 0.6 |
| `phl_throne` | 7 the Throne of Cinders | 8,37.5 | 0.56 |

Attach the room's `phl_*_lines.png` (image 1), the owner's lava mockup
`docs/concept/mockup_03_phlegethon_lava.webp` (image 2, the style AND the content) and the
room's `phl_*_guide.png` (image 3). Use the temple prompt above, with "in the exact style of
image 2", and this list:

> What things are:
> - Islands of ashen purple-grey rock floating in a sea of lava, deep in the underworld.
>   The flat grey areas are the islands' floors: big worn cobbles and old paving, ash and
>   cinders in the cracks, a few cracked slabs. Keep the open floor calm and readable.
> - The orange-lit edges dropping off the islands are ragged black basalt cliffs, glowing
>   orange at the bottom. Paint them like the mockup's island edges, with small black spikes
>   of rock along the rims.
> - Everything that is pure black in image 3 is lava: paint it **pure black** (the game draws
>   the moving lava there itself). Do not paint lava.
> - The narrow strips joining islands are paved stone causeways with low broken posts.
> - Small orange squares inside a floor are sinkholes down to the lava: keep them black.
> - The round gold shape is a large laurel wreath worked into the floor, like the mockup.
> - The bronze tripod bowls are braziers full of glowing coals; the lidded urns are amphorae
>   (keep them where they are); the cluster of pale candles is a heap of skulls and bones;
>   the tall dark columns are ruined Greek columns, the short broken ones broken columns.
> - (Room 2 only) The broken columns at the back stand around a GIANT half-buried skull with
>   a gold laurel, like the mockup: paint it there, among bone heaps and huge ribs.
>
> Light: hot orange from below at every edge, ember glow from the braziers, dark ashen floors.

**Done 2026-11-28** (all nine, see CLAUDE.md section 0). For a repaint: find the guide that
fits with `check_paint.py`, read where its props and holes sit with
`tools/rooms/grid_overlay.py PAINTING GUIDE_JSON src/dungeon/layout_phlegethon.gd OUT`, move
the map's letters to match, clip with `tools/rooms/rect_clip.py PAINTING GUIDE_JSON OUT
"i0,j0,i1,j1 ..."` to the islands it owns, import with
`holes=src/dungeon/layout_phlegethon.gd`, and check `tools/rooms/paint_coverage.py`.

Import each with its own guide (no `walls`: the shore has none), e.g.
`python3 tools/rooms/import_room_paint.py PAINTING docs/paint_guides/phl_ossuary_guide.json phl_ossuary`,
clip it to its own island with `tools/rooms/clip_paint.py` if it covers a neighbour, and list
it in `LayoutPhlegethon.PAINTS`. The map comes from `tools/rooms/gen_phlegethon.py`: once a
room is painted, never regenerate the map.

## Prompt for SOL: the hub, The Last Obol (Charon's tavern on the Styx)

Attach `hub_lines.png` (image 1), the mockup (image 2), `hub_guide.png` (image 3) and one of
the jade room paintings, e.g. `lethe_01_painted_sol_jade.webp` (image 4). Use the temple
prompt above with "in the exact style of image 4 (image 2 is the overall mood)" and this list:

> What things are:
> - A tavern at the dead end of the river Styx, deep in the underworld, where Charon the
>   ferryman stopped ferrying and opened a bar on his old stone dock. Souls who could not
>   pay the coin linger here. Warm and moody, a place to rest between fights, but still the
>   same dark green temple stone, gold trim and green soul-fire as the dungeon.
> - The big stone floor on the left is the tavern quay: worn, warm-lit slabs, a few rugs
>   and spilled-wine stains, the laurel-skull plate set in the floor.
> - The row of six low blocks near the back wall is the bar counter: dark polished stone
>   topped with old wood, gold trim along its edge. Behind it, on the back wall, paint
>   shelves of bottles and amphorae between the niches. The four single low blocks are
>   tavern tables of stone and wood, with a stool or two.
> - In the back corner between the two bronze braziers is the Soul Forge: paint the floor
>   there scorched, with a coal pit glowing orange. Leave the spot itself plain (an anvil
>   is drawn there by the game).
> - The two long walls at the back (top, and left) are towering temple walls: hooded-figure
>   murals with gold laurels, arched niches with green soul-fire, gold Greek-key bands.
> - The burning pit on the right is the river Styx: green soul-fire water in a stone basin,
>   glowing from below. The long gold-edged walkway across it is a pier of old stone and
>   wood; the two rubble islets are broken statues half-sunk in the fire. The white
>   railing at the front is a stone balustrade along the water.
> - The stone strip on the far right is the ferry landing, with mooring posts. Leave the
>   water beside its lower end calm (Charon's boat is drawn there by the game).
> - The walls along the bottom and right edges are the near walls; keep them as they are.
> - Paint NO people, ghosts or figures anywhere: the game draws Charon and the souls.
>
> Light: warm candle and lantern pools in the tavern, cold green glow from the Styx,
> orange from the forge, dark corners.

Then check alignment with `hub_lines.png`, import it with `hub_guide.json` as `hub_jade`
with `walls`, and add `"res://assets/rooms/hub_jade"` to `LayoutHub.PAINTS`.

## Prompt for SOL: room 7, the Weaver's Deep (the boss arena)

Attach `arena_01_lines.png` (image 1), the mockup (image 2), `arena_01_guide.png` (image 3)
and one of the jade room paintings, e.g. `lethe_01_painted_sol_jade.webp` (image 4). Use the
temple prompt above with "in the exact style of image 4 (image 2 is the overall mood)" and
this list:

> What things are:
> - The lair of a titan: a vast, open, ancient arena deep in the underworld temple, where
>   a giant spider-god lives. Paint the floor as one great ritual floor of huge worn
>   stone slabs, cracked and scored by enormous claws, with faint grey cobweb strands in
>   the corners and a few scattered bones. Keep the open floor calm and readable: the
>   boss fight happens here.
> - The two long walls at the back (top, and left) are towering temple walls, about three
>   times a person's height: hooded-figure murals with gold laurel branches, arched niches
>   with green soul-fire, gold Greek-key bands, dark stone blocks up to a heavy cornice,
>   tall fluted columns against them. Hang thick old cobwebs between some columns.
> - The gap in the left wall, at the far left, is a stone corridor in from the previous
>   room; paint the floor at the top-left corner pure black.
> - The four tall shapes standing on square bases in the open floor are massive fluted
>   stone columns, scarred by claws.
> - The two long gold lines are bands of gold Greek-key inlay; the round gold shape between
>   them is a large laurel-and-skull floor plate.
> - The two bronze tripod bowls with green flames at the back are soul braziers; keep the
>   floor between them plain stone: a portal glows there. The lidded urns in the two front
>   corners are sealed fire urns; the small clusters are lit candles.
> - The tall walls along the bottom and right edges are the near walls of the arena; keep
>   them as they are.
>
> Light: dim and ominous, green from the niches and braziers, warm pools at the candles,
> darker toward the corners.

Then check alignment with `arena_01_lines.png`, clip it to room 7's band with
`tools/rooms/band_clip.py PAINTING docs/paint_guides/arena_01_guide.json OUT 125 200`, import
it with `arena_01_guide.json` as `arena_jade` with `walls`, and add
`"res://assets/rooms/arena_jade"` to `LayoutTemple.PAINTS`.

## Prompt for SOL: room 6, the Isles of Lethe

Attach `lethe_01_lines.png` (image 1), the mockup (image 2), `lethe_01_guide.png` (image 3)
and one of the jade room paintings, e.g. `shades_02_painted_sol_jade.webp` (image 4), so it
comes out in the current style. Use the temple prompt above with "in the exact style of
image 4 (image 2 is the overall mood)" and this list:

> What things are:
> - A temple hall flooded with a lake of bright green soul-fire, the Isles of Lethe. The
>   large dark areas in image 3 are the lake: paint them as a glowing pool of green flame
>   a little below the floor, with low stone rims and flames licking up their inner walls,
>   not as black holes.
> - The two long walls at the back (top, and left) are towering temple walls, about three
>   times a person's height: hooded-figure murals with gold laurel branches, arched niches
>   with green soul-fire, gold Greek-key bands, dark stone blocks up to a heavy cornice,
>   tall fluted columns against them. A narrow stone ledge runs along the foot of the back
>   wall; the grey heap in the middle of it is fallen rubble, and a small rubble islet
>   stands in the fire just below it.
> - The floor at the far left is the west quay, entered by a stone corridor from the
>   previous room at the top left. The floor at the far right is the east quay. The big
>   floor in the middle is the central isle, with two broken columns, a bronze tripod
>   brazier and laurel-and-skull floor plates. The small floor at the bottom middle is a
>   little isle.
> - The three narrow strips edged in gold, with gold sunburst plates at their ends, are
>   stone bridges over the fire: quay to isle, isle to quay, isle to the little isle.
> - The white railing along the front is a low stone balustrade at the edge of the lake.
> - The two low heaps of bones and roots (on the ledge and on the little isle) are bone
>   nests with a faint green glow. The vase pairs are red-orange Greek amphorae, the lidded
>   urns are sealed fire urns, the small clusters are lit candles; the two bronze tripod
>   bowls on the east quay are soul braziers, and the floor between them stays plain stone
>   (a portal glows there).
> - The tall walls at the bottom left and right edges are the near walls of the room; keep
>   them as they are.
>
> Light: the lake lights everything green from below; warm pools around the candles; dark
> corners and a dark ceiling.

Then check alignment with `lethe_01_lines.png`, clip it to room 6's band with
`tools/rooms/band_clip.py PAINTING docs/paint_guides/lethe_01_guide.json OUT 102 200`,
import it with `lethe_01_guide.json` as `lethe_jade` with `walls`, and add
`"res://assets/rooms/lethe_jade"` to `LayoutTemple.PAINTS`.

## Prompt for SOL: room 5, the Hall of Shades

Attach `shades_01_lines.png` (image 1), the mockup (image 2), `shades_01_guide.png`
(image 3) and one of the v3 room paintings, e.g. `altar_01_painted_sol.webp` (image 4), so
it comes out in the same style. Use the temple prompt above, with "Paint image 1 ... in the
exact style of image 4 (image 2 is the overall mood)" and this list:

> What things are:
> - A big square temple hall, the Hall of Shades. The two long walls at the back (left
>   and top) are towering temple walls, about three times a person's height: hooded-figure
>   murals with gold laurel branches, arched niches with green soul-fire, gold Greek-key
>   bands, dark stone blocks up to a heavy cornice, with tall fluted stone columns against
>   them.
> - The narrow strip at the far left, edged in gold, is a stone bridge over the black
>   abyss; it enters the hall through a doorway at the front end of the left wall. Paint
>   the room at the top-left corner of the frame pure black.
> - The four square blocks standing in the hall are shrine pillars, chest-to-head high:
>   a hooded figure carved on each face between gold laurels, a gold Greek-key base,
>   green soul-fire glow at their feet.
> - The two long gold lines across the floor are bands of gold Greek-key inlay framing
>   the open central field; the round gold shapes are laurel-and-skull floor plates.
> - The vase pairs are red-orange Greek amphorae, the lidded urns are sealed fire urns,
>   the small clusters are lit candles, the low box at the front right is a stone table,
>   and the two bronze tripod bowls with green flames in the back-right corner are soul
>   braziers. Keep the floor between those two braziers plain stone: a portal glows there.
> - The front and right edges of the floor break off into black abyss.
>
> Light: dim green from the niches and braziers, warm pools around the candles, dark
> corners.

Then check alignment with `shades_01_lines.png`, black out the Undercroft corner at the
top left (`clip_paint.py ... "80,-100 80,100 -200,100 -200,-100"`), import with
`shades_01_guide.json` as `shades_01`, and add `"res://assets/rooms/shades_01"` to
`LayoutTemple.PAINTS`.

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
