class_name LayoutTemple
extends RefCounted
## Look-test level (run with --level=temple): one room composed like the owner's
## soul-fire temple mockup (docs/concept/mockup_01_soul_fire_temple.webp), the first
## room of the temple dungeon. Same legend as LayoutTest, plus O pillar, Q broken
## pillar, : plain floor and B bridge deck (over a pit; Dungeon works out its axis and
## end pieces).
##
## Laid out like the mockup, so the way runs left to right with nothing in front of it.
## Screen directions: +i (right in this map) is down-right, +j (down in this map) is
## down-left, so the map's left column and top row are the room's two back walls.
## * Back walls (drawn 6 m tall, Dungeon._is_back_wall): the mural wall (hooded reliefs
##   W, soul-fire niches M) up the left column to a corner column (O), then the frieze
##   wall (P, Greek-key band) with columns and a niche around the back of the arena.
## * A band of soul-fire pits runs down-right from the mural wall's base (a narrow ledge
##   with candles between them), crossed by two gold bridges (B) to the lower floor.
## * The player starts just above the bridges; the open arena spreads to the right with
##   the laurel-skull emblem, a broken column and urns. The near edges break off into the
##   abyss, except for a gold bridge (B, row 3) across the abyss to the next room.
##
## Room 2, THE HOODED SANCTUM (columns 26-37): a compact nave, about one screen, so one
## painting covers it (paint guide sanctum_01). Its back wall (top row) is the hooded
## mural with soul-fire niches and columns, with a short frieze return down its left
## column; the bridge arrives below that. A soul-fire moat (two cells wide) splits the
## nave front to back, crossed by one short bridge in the middle and by the narrow ledges
## behind and in front of it. Columns and broken columns flank the moat; the descent
## far side keeps a cluster of candles, with a laurel-skull plate in front of it. (Props
## follow the owner's painting, sanctum_01: amphorae in the back-left corner, candles by
## the far bank; the two dark shrubs on the floor are painted only.) Its right edge has
## a gold bridge (row 3) on to room 3. (The exit portal used to wait here; it moved to
## room 3, onto floor the painting shows as plain stone.)
##
## Room 3, THE BONE ALTAR (columns 42-54): no pit; a ritual hall. Painted by the owner
## (altar_01); its props follow the painting: the back wall is frieze (P) with small
## doors and bronze roundels, a hooded mural (W) behind the altar and a short frieze
## return down its left corner, above where the bridge arrives. A raised gold-edged
## processional curb (h) runs from the bridge to a stone altar (=, two cells) with a
## sunburst plate at its front end; two columns stand behind it and two broken columns
## (candles painted at their feet) in front, with a sunburst plate before it. An
## amphora (k) stands by the back wall. Three bone nests (e), two of them beside
## explosive fire urns (b), spawn hounds until they're broken; SOL painted them as
## low shrubs, so nests keep their own sprites (RoomPaint.dress). The painting's other
## shrubs are painted only. Fight: witches and a flaming skull while the nests pour out
## hounds; once the nests are down, a shielded elite Legionnaire. Clearing it drops a
## chest and opens the exit portal (X) at the far right, which descends to the next depth.

const MAP := [
	"OPPPPMPPPOPPPPMPPPPO      OWMWOWMWOWMO    OPPPOPWPOPPPO",
	"W::::::O:::::::O:::::     Pk::k:::::::    P:::k:::::eb:",
	"M:::::::::::::::::::::    P::O:  ::O::    P::O:::::O:::",
	"W::::::::::::::::k::::BBBB:::::  :::::BBBB:hhhh:=l:::::",
	"M::::::::o:::::::::p::    :::::BB:::::    ::::::=::::::",
	"W:::k:::::::::::::::::    :::Q:  ::Q:o    :e,:::::::w::",
	"O::::::::::Q::::::::*:    ::::,  :::n:    b::Q::o::Q:X:",
	"W:::::::::::::::::::n:     ::::::::::      ::::e:::::::",
	"M::::S::::::::::::::::      ::::::           ::::::::",
	"Wn  B  B    ::::w:::::",
	"M:  B  B    :::::::::",
	"W:::::::::::::::::::k:",
	"M::Q::,::::::::::::::",
	"W:n:::::::::::w::::n",
	" :::Q:::::,:::::::::",
	"   ::::::::::::::::",
	"      ::::::::::",
	"",
]

## Room paintings laid over the layout (RoomPaint; docs/paint_guides/README.md).
## assets/rooms/temple_01: the owner's SOL painting with the tall back walls
## (docs/paint_guides/temple_01_painted_sol_v2_tall.webp), painted at paint guide
## temple_01's camera; the floor layout is the same as when that guide was taken.
## assets/rooms/sanctum_01: the owner's SOL painting of room 2
## (docs/paint_guides/sanctum_01_painted_sol.webp), painted at paint guide sanctum_01.
const PAINTS: Array = ["res://assets/rooms/temple_01", "res://assets/rooms/sanctum_01", "res://assets/rooms/altar_01"]

const ROOMS := [
	{
		"id": "temple", "name": "THE SOUL-FIRE TEMPLE", "rect": [0, 0, 22, 17], "lock": false,
		"beats": [
			{"trigger": "enter_delay", "delay": 1.0, "spawn": [["mite", 6], ["spitter", 2], ["bloater", 2]], "far": true},
			{"trigger": {"remaining": 3}, "spawn": [["brute", 1], ["mite", 5], ["spitter", 2]]},
		],
	},
	{
		"id": "sanctum", "name": "THE HOODED SANCTUM", "rect": [26, 1, 37, 8], "lock": false,
		"beats": [
			{"trigger": "enter", "spawn": [["spitter", 2], ["mite", 4]], "far": true},
			{"trigger": {"remaining": 2}, "spawn": [["brute", 1], ["mite", 3], ["bloater", 1]], "far": true},
		],
	},
	{
		"id": "altar", "name": "THE BONE ALTAR", "rect": [42, 1, 54, 8], "lock": false,
		"beats": [
			{"trigger": "enter", "spawn": [["spitter", 2], ["mite", 3], ["bloater", 1]], "far": true, "nests": true},
			{"trigger": {"remaining": 2}, "spawn": [["brute", 1, {"elite": ["shielded"]}], ["mite", 3], ["spitter", 1]], "far": true},
		],
		"reward": "chest",
		"exit": true,
	},
]
