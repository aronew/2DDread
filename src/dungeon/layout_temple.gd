class_name LayoutTemple
extends RefCounted
## Look-test level (run with --level=temple): one room composed like the owner's
## soul-fire temple mockup (docs/concept/mockup_01_soul_fire_temple.webp), to judge
## how close room composition and camera framing get us before changing anything
## bigger. Same legend as LayoutTest, plus O pillar, Q broken pillar and : plain floor.
## Back walls (top of the screen) carry reliefs, fire alcoves and friezes; a soul-fire
## chasm is crossed by a gold walkway with sunburst tiles at each end; pillars, candles,
## amphorae and braziers frame it; the front edge breaks off into the abyss.

const MAP := [
	"PWMPPMWPPPMWPMPP ",
	"Mnk::p:t:::k::p: ",
	"P::::::::O:::O:: ",
	"W::,:::::::::::: ",
	"P:::::O:::::::k: ",
	"M:    n:w::::::: ",
	"P:    :::::::::: ",
	"Plhhhhl:::o::w:  ",
	"W:    :::S::::n  ",
	"P:    :::::::::  ",
	"M:    *n:::,Q::  ",
	"PO:::::::::::::  ",
	"P:::w::xQ        ",
	"                 ",
]

const ROOMS := [
	{
		"id": "temple", "name": "THE SOUL-FIRE TEMPLE", "rect": [1, 1, 14, 11], "lock": false,
		"beats": [
			{"trigger": "enter_delay", "delay": 1.0, "spawn": [["mite", 6], ["spitter", 2], ["bloater", 2]], "far": true},
			{"trigger": {"remaining": 3}, "spawn": [["brute", 1], ["mite", 5], ["spitter", 2]]},
		],
	},
]
