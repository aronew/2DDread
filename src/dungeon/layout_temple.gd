class_name LayoutTemple
extends RefCounted
## The temple dungeon, the game's default level (--level=test opens the original test
## level). Room 1 was composed like the owner's soul-fire temple mockup
## (docs/concept/mockup_01_soul_fire_temple.webp). Same legend as LayoutTest, plus O pillar, Q broken
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
## low shrubs, so nests keep their own sprites (RoomPaint.KEEP_OWN). The painting's other
## shrubs are painted only. Fight: witches and a flaming skull while the nests pour out
## hounds; once the nests are down, a shielded elite Legionnaire. Clearing it drops a
## chest and opens the exit portal (X) at the far right, which descends to the next depth.

## Room 4, THE GREAT STAIR + THE UNDERCROFT (columns 59-79, rows 0-19): bigger, L-shaped
## and on two floor levels (see Terrace). The bridge arrives on a long upper gallery: its
## back wall is murals, niches and columns, with a gold processional band leading to a
## grand stair cut into the gallery's front terrace and flanked by braziers. The path
## turns there and goes down the stair (toward the camera) into the Undercroft, a sunken
## hall two levels (3.27 m) below: on screen it starts two cells further down-right, at
## row 10, behind rows 8-9 of terrace face (`_`) and stair (`/`). Its left wall is 3 m next
## to the terrace (taller would hide the gallery) and 6 m further down. A nave of columns
## and a sarcophagus lead to the exit portal. Fights: hounds and witches on the gallery,
## then a Legionnaire and skulls; in the Undercroft, a Legionnaire and hounds while Hex
## Witches shoot down from the gallery, then a molten elite. Two paint guides (stair_01,
## undercroft_01) overlap at the stair.

## Room 5, THE HALL OF SHADES (columns 84-99, rows 4-16): the biggest single hall, one
## painting (paint guide shades_01). A bridge from the Undercroft's right edge (row 14)
## enters through a doorway at the front of its left wall. Tall walls of murals (W),
## soul-fire niches (M) and columns enclose the back and left; four hooded shrine blocks
## (W, freestanding 3 m) stand around an open central field between two gold Greek-key
## bands, with a laurel-skull plate in the middle and three more along the front. The exit
## portal waits in the back-right corner between two braziers. Props follow the owner's
## painting (shades_01). Fight: three waves (hounds and witches; a
## Legionnaire, skulls and witches; a frenzied elite Legionnaire with hounds), then a
## chest and the portal.

const MAP := [
	"OPPPPMPPPOPPPPMPPPPO      OWMWOWMWOWMO    OPPPOPWPOPPPO    OPMPOPWPOWMWOPWPOMO",
	"W::::::O:::::::O:::::     Pk::k:::::::    P:::k:::::eb:    P:::::k:::::::k::::",
	"M:::::::::::::::::::::::::P::O:  ::O::::::P::O:::::O:::::::P::::::::::::::::::",
	"W::::::::::::::::k:::::::::::::  ::::::::::hhhh:=l::::::::::hhhhhhh:l:::::::::",
	"M::::::::o:::::::::p:::::::::::BB:::::::::::::::=:::::::::::::o:::::::::::n:::      OMWMOPWPOMWMOPWO",
	"W:::k:::::::::::::::::    :::Q:  ::Q:o    :e,:::::::w::    :::::Q::::::::::::b      W:k:::n:::n:::k:",
	"O::::::::::Q::::::::*:    ::::,  :::k:    b::Q::o::Q:::    ::b:::::n////k:::::      Mb::::::::::*X*:",
	"W:::::::::::::::::::n:     ::::::::::      ::::e:::::::    :n:::::::_///::::::      O::hhhhhhhhhhh::",
	"M::::S::::::::::::::::      ::::::           ::::::::           _____///______      W:::W:n:::::W:::",
	"Wn  B  B    ::::w:::::                                           _____///______     M:::::::::::::::",
	"M:  B  B    :::::::::                                              P:k::::k:::::    W:::::::o:::::::",
	"W:::::::::::::::::::k:                                             M::::::::::::    O:::::::::::::b:",
	"M::Q::,::::::::::::::                                              P::::o:::::::    M:::::::::::::::",
	"W:n:::::::::::w::::n                                               M::O:::::O:::::::W:::W:::::n:W:=:",
	" :::Q:::::,:::::::::                                               W:::::=:::::::::::::hhhhhhhhhhh::",
	"   ::::::::::::::::                                                Ok::::=::::::::::::::o:::o:::o:k:",
	"      ::::::::::                                                   W::O:::::O:::    ::::::::::::::::",
	"                                                                   M:b:::::::k::",
	"                                                                   P:::::::::n::",
	"                                                                   O::,:::::::::",
]

## Room paintings laid over the layout (RoomPaint; docs/paint_guides/README.md).
## assets/rooms/temple_01: the owner's SOL painting with the tall back walls
## (docs/paint_guides/temple_01_painted_sol_v2_tall.webp), painted at paint guide
## temple_01's camera; the floor layout is the same as when that guide was taken.
## assets/rooms/sanctum_01: the owner's SOL painting of room 2
## (docs/paint_guides/sanctum_01_painted_sol.webp), painted at paint guide sanctum_01.
## Wall in every open floor edge (Dungeon._enclose_floor): rooms and the corridors between
## them are enclosed on all sides, near walls fading out around the player.
const ENCLOSE := true

const PAINTS: Array = ["res://assets/rooms/temple_01", "res://assets/rooms/sanctum_01", "res://assets/rooms/altar_01",
	"res://assets/rooms/stair_01", "res://assets/rooms/undercroft_01",
	"res://assets/rooms/shades_01"]

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
	},
	{
		"id": "gallery", "name": "THE GREAT STAIR", "rect": [59, 1, 77, 9], "lock": false,
		"beats": [
			{"trigger": "enter", "spawn": [["mite", 4], ["spitter", 2]], "far": true},
			{"trigger": {"remaining": 2}, "spawn": [["brute", 1], ["mite", 3], ["bloater", 2]], "far": true},
		],
	},
	{
		# Hex Witches appear up on the gallery and shoot down into the hall
		"id": "undercroft", "name": "THE UNDERCROFT", "rect": [68, 10, 79, 19], "lock": false,
		"beats": [
			{"trigger": "enter", "spawn": [["brute", 1], ["mite", 4], ["spitter", 2, {"area": [73, 1, 77, 7]}]], "far": true},
			{"trigger": {"remaining": 2}, "spawn": [["brute", 1, {"elite": ["molten"]}], ["bloater", 2], ["spitter", 1, {"area": [60, 1, 66, 7]}]], "far": true},
		],
		"reward": "chest",
	},
	{
		"id": "shades", "name": "THE HALL OF SHADES", "rect": [85, 5, 99, 16], "lock": false,
		"beats": [
			{"trigger": "enter", "spawn": [["mite", 5], ["spitter", 2]], "far": true},
			{"trigger": {"remaining": 3}, "spawn": [["brute", 1], ["bloater", 2], ["spitter", 2]], "far": true},
			{"trigger": {"remaining": 2}, "spawn": [["brute", 1, {"elite": ["frenzied"]}], ["mite", 4], ["bloater", 1]], "far": true},
		],
		"reward": "chest",
		"exit": true,
	},
]

## Changes of floor level (Terrace): room 4's gallery drops two levels (3.27 m) to the
## Undercroft. Coordinates are the gallery's; on screen the Undercroft sits two cells
## further down-right, so its floor starts at row 10.
const TERRACES: Array = [
	{"face": [64, 68, 8], "drop": 2},     # runs on behind the hall's left wall
	{"face": [72, 78, 8], "drop": 2},
	{"stair": [68, 72, 6], "run": 2, "drop": 2, "steps": 10, "cheek": true},
]
