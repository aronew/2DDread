class_name LayoutPhlegethon
extends RefCounted
## THE SECOND SHORE: the Phlegethon, the underworld's river of fire. After the owner's lava
## mockup (docs/concept/mockup_03_phlegethon_lava.webp: ashen-purple rock islands with
## laurel plates, a giant half-buried skull, bone heaps, ruined arches, braziers of coals,
## all floating in a sea of molten lava) and their room-layout sketch
## (docs/concept/layout_sketch_phlegethon.webp), kept to its numbering and branches:
## 1 the landing -> 2 the ossuary -> 3 a crossroads of three wings (a side branch) and
## 4 a top room with a long hall south -> 5 a dead-end vault (side branch) -> 6 -> 7 the finale.
## Sketch x is map i and sketch y is map j, so on screen room 1 is far right and room 7 far
## left. Rooms are islands with ragged edges (generated once, then fixed here), joined by
## stone causeways over the lava (plain floor: LavaShore gives them cliffs on both sides); a lone space inside a room is a sinkhole showing the
## lava below. No walls enclose it and there are no soul-fire pits: every void is the lava
## sea (World draws it, lava_sea.gdshader) and Dungeon.fly_margin keeps flyers near shore.
## Same legend as LayoutTemple.

const LAVA := true

const MAP := [
	"",
	"",
	"                                                          ::",
	"                                                       :::k*:::::",
	"                                                       ::Q::::::*",
	"                                                      :::Q:S::::::",
	"                                                      :Q:::::::::k",
	"                                                      :::::::::::",
	"                                                      :::::::w:::",
	"                                                       :: ::::: :",
	"                                                       :*::::::::",
	"                                                       ::::::::::",
	"                                                        ::::::",
	"                                                          Q::",
	"                                                          ::Q",
	"                                                          ::: ::::",
	"                                :*                       ::::::  :",
	"                               ::::::::::::          :QOQ::::::::::",
	"                               :Q::::::: *k         ::Q:::::::,:::::",
	"                               :Q ::::::::::        ::::::::::::::e:",
	"                               ::::::::::::::::::::::::::::::::::::",
	"                               ::::: :::::::::::::::::::::::::: ::::",
	"                               ::::::::::::::::::::::::: ::: :::::::",
	"                              *:::::::::::::        ::::::::::::::::",
	"                              :k:::::::::::         :e:::::::::::::",
	"                               :::::::::::*          ::::::::::::::",
	"                                ::::::::::           :::w::::::::::",
	"                                  ::::::             ::::::::::::::",
	"                                  ::::::             n:::::::::::::",
	"         ::                       :::::Q:             ::::::::::",
	"     ::  :::                     ::O::O::                 :::",
	"   ::*::::::::                   ::::::::                 :::",
	"   :k::::::::::                  ::::::::                 :::",
	"   :Q:::::::O::       ::*        :::: :::                 :::",
	"   Q:::::::::::    ::::::::k:     ::::::                ::::::",
	"   ::::::::::::   ::Q::::::::    :::::::               :::::::        :::::::*::",
	"   ::::::::::::::::::::::::::::::::O::::      ::::    ::::::::       ::::::::::::",
	"   :::::X:::::::::::::: ::::::::::::::::   ::::OQ:::  :::::::::     ::::::::::::::",
	"   :::o::::::::::::::::::::::::::::::::::  ::: ::::::::::::::::     :::::::::::Q:Q",
	"   ::::::::::::   :::::::::::    ::::::::   e:::::::::::::: ::::    :::::::::::::",
	"   ::::::::::::   ::::::::Q:     ::::::::   :::::::::::::::::::::   :::::::Q:::::",
	"   ::::::::::::    k::::::::     ::::::::   *:::::::  ::::::::::Q::::::::::::::::",
	"   :O:::::::Q:        Q:*k:       ::::O::    :k:: :   :::::::::k:::: :::::::::e::",
	"   :::::::::::                  :::::::::              :::::::::::   ::::::::::::",
	"   :::::::::::                  :::::::::                 :::::::      :: :: ::::",
	"        :k:::                     :O:::::                   ::: :",
	"                                  ::::::",
	"                                  ::::::",
	"                                  *k:::",
	"                                   :::",
	"                                   :::",
	"                                   :::",
	"                                  :Q:::",
	"                                ::::::::::",
	"                               ::*::::::*:",
	"                               :::::::::::",
	"                               :::::::::::",
	"                               ::: ::::::::",
	"                              :::::: ::::::",
	"                              :::::::::::::",
	"                                ::::::::::",
	"                                *::::::::*",
	"                                ::::::::::",
	"                                  :::::::",
	"",
	"",
	"",
	"",
]

## The owner's paintings (2026-11-28, Archive_42), one per guide (docs/paint_guides/phl_*),
## each clipped to the islands it owns with tools/rooms/rect_clip.py. The owner painted their
## own props (giant skulls, rib cages, a three-skeleton monument, skull pillars, braziers of
## coals): the map's prop letters, columns and sinkholes were moved to match them, so this
## map no longer comes from tools/rooms/gen_phlegethon.py.
const PAINTS := [
	"res://assets/rooms/phl_ashfall", "res://assets/rooms/phl_ossuary",
	"res://assets/rooms/phl_crossroads_west", "res://assets/rooms/phl_crossroads_east",
	"res://assets/rooms/phl_gauntlet_court", "res://assets/rooms/phl_gauntlet_hall",
	"res://assets/rooms/phl_vault", "res://assets/rooms/phl_forgegate", "res://assets/rooms/phl_throne"]

const ROOMS := [
	{
		# 1: Charon's boat leaves you on a bare island; hounds come up out of the ash
		"id": "ashfall", "name": "THE ASHFALL LANDING", "rect": [54, 2, 65, 12], "lock": false,
		"beats": [
			{"trigger": "enter_delay", "delay": 1.0, "spawn": [["mite", 5], ["spitter", 1]], "far": true},
			{"trigger": {"remaining": 1}, "spawn": [["mite", 3], ["bloater", 2]], "far": true},
		],
	},
	{
		# 2: the giant's skull lies at the back; bone nests breed hounds, witches circle
		"id": "ossuary", "name": "THE GIANT'S OSSUARY", "rect": [52, 16, 67, 29], "lock": false,
		"beats": [
			{"trigger": "enter", "spawn": [["mite", 4], ["spitter", 2]], "far": true, "nests": true},
			{"trigger": {"remaining": 2}, "spawn": [["brute", 1], ["spitter", 2], ["bloater", 2]], "far": true},
		],
		"reward": "chest",
	},
	{
		# 3: a crossroads of three islands; each wing wakes in turn
		"id": "crossroads", "name": "THE BURNING CROSSROADS", "rect": [44, 34, 81, 44], "lock": false,
		"beats": [
			{"trigger": "enter", "spawn": [["mite", 4, {"area": [54, 34, 64, 44]}], ["brute", 1, {"area": [54, 34, 64, 44]}]], "far": true},
			{"trigger": {"remaining": 2}, "spawn": [["spitter", 2, {"area": [68, 35, 81, 44]}], ["mite", 4, {"area": [68, 35, 81, 44]}]], "far": true, "nests": true},
			{"trigger": {"remaining": 2}, "spawn": [["brute", 1, {"elite": ["molten"], "area": [44, 36, 51, 43]}], ["bloater", 3], ["mite", 3, {"area": [44, 36, 51, 43]}]], "far": true},
		],
		"reward": "chest",
	},
	{
		# 4: a square court, then a long colonnade south: Legionnaires hold the hall while
		# witches and skulls come over the lava at its sides
		"id": "gauntlet", "name": "THE CINDER GAUNTLET", "rect": [30, 16, 43, 48], "lock": false,
		"beats": [
			{"trigger": "enter", "spawn": [["mite", 5, {"area": [30, 16, 43, 26]}], ["spitter", 2, {"area": [30, 16, 43, 26]}]], "far": true},
			{"trigger": {"remaining": 2}, "spawn": [["brute", 2, {"area": [33, 34, 40, 46]}], ["bloater", 3], ["spitter", 1]], "far": true},
			{"trigger": {"remaining": 2}, "spawn": [["brute", 1, {"elite": ["shielded"], "area": [33, 30, 40, 40]}], ["mite", 4], ["spitter", 2]], "far": true},
		],
	},
	{
		# 5: a dead end: the molten vault, guarded by a frenzied elite; the best chest on the shore
		"id": "vault", "name": "THE MOLTEN VAULT", "rect": [31, 52, 42, 63], "lock": false,
		"beats": [
			{"trigger": "enter_delay", "delay": 0.8, "spawn": [["brute", 1, {"elite": ["frenzied", "molten"]}], ["mite", 4], ["bloater", 2]], "far": true},
		],
		"reward": "legendary",
	},
	{
		# 6: the gate to the throne: broken columns, fire urns, witches crossing the lava
		"id": "forgegate", "name": "THE FORGE GATE", "rect": [18, 33, 28, 42], "lock": false,
		"beats": [
			{"trigger": "enter", "spawn": [["spitter", 3], ["mite", 4]], "far": true},
			{"trigger": {"remaining": 2}, "spawn": [["brute", 2], ["bloater", 3]], "far": true},
		],
		"reward": "chest",
	},
	{
		# 7: the finale (the shore's keeper will rise here; for now a volatile elite and the
		# last of the shore's host); holds the exit portal back to the hub
		"id": "throne", "name": "THE THRONE OF CINDERS", "rect": [2, 30, 14, 45], "lock": false,
		"beats": [
			{"trigger": "enter_delay", "delay": 1.0, "spawn": [["brute", 1, {"elite": ["volatile"]}], ["mite", 4], ["spitter", 2]], "far": true},
			{"trigger": {"remaining": 2}, "spawn": [["brute", 1, {"elite": ["molten", "shielded"]}], ["bloater", 3], ["spitter", 2], ["mite", 3]], "far": true},
		],
		"reward": "legendary",
		"exit": true,
	},
]
