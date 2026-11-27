class_name LayoutTemple
extends RefCounted
## Look-test level (run with --level=temple): one room composed like the owner's
## soul-fire temple mockup (docs/concept/mockup_01_soul_fire_temple.webp), to judge
## how close room composition and camera framing get us before changing anything
## bigger. Same legend as LayoutTest, plus O pillar, Q broken pillar and : plain floor.
## Composed like the mockup, running left to right: the back wall is a V. The mural wall
## (reliefs, fire alcoves) comes down from the upper left to a pillar at the inside
## corner, and a waist-high meander wall rises from it to the upper right. A soul-fire
## chasm runs along the mural wall's base (with a narrow ledge), crossed by two gold
## walkways with sunburst tiles at their ends. The open fight floor spreads right of the
## corner, with the laurel emblem; the near edges break off into the abyss.

const MAP := [
	"         U:::O::::::    ",
	"         U::::::::::O:  ",
	"         U::k:::::::::: ",
	"         U:,::::::::::: ",
	"         U::::::::::::: ",
	"         U::::::o:::::: ",
	"MWRWMWPWMP:::::::::::p: ",
	":n:l::k::l:O::::::::::: ",
	":  h     h   :::::::::: ",
	":  h     h   :w::::w::: ",
	":::l:::::l:::::::::::*: ",
	"::::::::::S:::::::::::: ",
	"::Q::::,::::::::kQ::::  ",
	"::::::::::::::::::n:::  ",
	" ::::w::::::n:::::::::  ",
	"   ::::::::::::::::     ",
	"      ::::::::::        ",
	"                        ",
]

const ROOMS := [
	{
		"id": "temple", "name": "THE SOUL-FIRE TEMPLE", "rect": [0, 0, 22, 16], "lock": false,
		"beats": [
			{"trigger": "enter_delay", "delay": 1.0, "spawn": [["mite", 6], ["spitter", 2], ["bloater", 2]], "far": true},
			{"trigger": {"remaining": 3}, "spawn": [["brute", 1], ["mite", 5], ["spitter", 2]]},
		],
	},
]
