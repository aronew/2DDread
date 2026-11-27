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
##   abyss.

const MAP := [
	"OPPPPMPPPOPPPPMPPPPO    ",
	"W::::::O:::::::O:::::   ",
	"M:::::::::::::::::::::  ",
	"W::::::::::::::::k::::  ",
	"M::::::::o:::::::::p::  ",
	"W:::k:::::::::::::::::  ",
	"O::::::::::Q::::::::*:  ",
	"W:::::::::::::::::::n:  ",
	"M::::S::::::::::::::::  ",
	"Wn  B  B    ::::w:::::  ",
	"M:  B  B    :::::::::   ",
	"W:::::::::::::::::::k:  ",
	"M::Q::,::::::::::::::   ",
	"W:n:::::::::::w::::n    ",
	" :::Q:::::,:::::::::    ",
	"   ::::::::::::::::     ",
	"      ::::::::::        ",
	"                        ",
]

## Room paintings laid over the layout (RoomPaint; docs/paint_guides/README.md).
## assets/rooms/temple_01 (the owner's first SOL painting) was painted from the old,
## low-walled version of this room; it no longer matches the tall back walls, so it's
## off until the room is repainted from paint guide temple_02.
const PAINTS: Array = []

const ROOMS := [
	{
		"id": "temple", "name": "THE SOUL-FIRE TEMPLE", "rect": [0, 0, 22, 17], "lock": false,
		"beats": [
			{"trigger": "enter_delay", "delay": 1.0, "spawn": [["mite", 6], ["spitter", 2], ["bloater", 2]], "far": true},
			{"trigger": {"remaining": 3}, "spawn": [["brute", 1], ["mite", 5], ["spitter", 2]]},
		],
	},
]
