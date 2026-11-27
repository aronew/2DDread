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
## * Back walls: the tall mural wall (hooded reliefs W, soul-fire niches M) along the
##   left column, running up-right on screen from the lower left to a column (O), where
##   the waist-high Greek-key wall (U) takes over and wraps the back of the arena.
## * A band of soul-fire pits runs down-right from the mural wall's base (a narrow ledge
##   with candles between them), crossed by two gold bridges (B) to the lower floor.
## * The player starts just above the bridges; the open arena spreads to the right with
##   the laurel-skull emblem, a broken column and urns. The near edges break off into the
##   abyss.

const MAP := [
	"UUUUUUUUUUUUUUUUUUUU    ",
	"U::::::O:::::::O:::::   ",
	"U:::::::::::::::::::::  ",
	"U::::::::::::::::k::::  ",
	"U::::::::o:::::::::p::  ",
	"U:::k:::::::::::::::::  ",
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

const ROOMS := [
	{
		"id": "temple", "name": "THE SOUL-FIRE TEMPLE", "rect": [0, 0, 22, 17], "lock": false,
		"beats": [
			{"trigger": "enter_delay", "delay": 1.0, "spawn": [["mite", 6], ["spitter", 2], ["bloater", 2]], "far": true},
			{"trigger": {"remaining": 3}, "spawn": [["brute", 1], ["mite", 5], ["spitter", 2]]},
		],
	},
]
