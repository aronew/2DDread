class_name LayoutTest
extends RefCounted
## Hand-authored vertical-slice dungeon. Columns = tile i (screen down-right),
## rows = tile j (screen down-left).
##
## Legend
##   (space) void / abyss          .  floor (auto variant)
##   P frieze/column wall   W relief wall   M soul-fire alcove   I banner+torch wall   R rock wall
##   K cracked breakable wall (secret)
##   g grate  h meander border  l sunburst  v soul drain  o laurel emblem  c rune stain  , moss+bones  w cracked  r rock
##   z shock-plate hazard floor
##   = altar (low)  x rubble (low)  | soul-fire pit balustrade (low)   — low blocks stop movement, not bullets
##   b fire urn (explodes)  k amphorae (supplies)  n candles  C chest  e bone nest (spawns hounds)
##   * soul brazier  p candelabra  t broken statue
##   S player start   D door (locks during encounters)   X exit portal (opens when the slice is cleared)

const MAP := [
	"            RWRRRRWRR                  ",
	"            W.*....*R                  ",
	"            W...C...R                  ",
	"            R...o...W                  ",
	"            Wn.....*W                  ",
	"            RWRRwWRWR                  ",
	"               RwR  MRRMMMRRRRMMRRR    ",
	" WIPPPWPIPII   RwR  M*...........*R    ",
	" P.........P   RwR  M.............M    ",
	" W.kn...bp.P   RwR  M..e...g...e..M    ",
	" P....l....PIIPIKIPIP..,..........M    ",
	" P............|...b.D...,...,.....M    ",
	" W...S....v.h..g...hD.....x.x.,...M    ",
	" P...o.......b...|..D...g..o..g,..R    ",
	" P.....l...PIIIIIPIII,....x.x.....R    ",
	" I.p.....k.W        M.,..........,M    ",
	" P.........P        R......,......M    ",
	" PPPPPPPIWIW        M,.e...g...e..R    ",
	"                    R.,........,..M    ",
	"                    R*...........*R    ",
	"                    RRMMRRDDDRRRRRM    ",
	"                         I.h.I         ",
	"                         P...I         ",
	"                         PzzzP         ",
	"                         P...I         ",
	"                         IzzzI         ",
	"                         I...I         ",
	"                         P.h.I         ",
	"                 PMMPWPWPIDDDPPIWMMPWP ",
	"                 M.........c.........P ",
	"                 P.t...b..c......c.t.M ",
	"                 Mc........l.........M ",
	"                 M....p.c.......p....P ",
	"                 M..v..c......c...v..W ",
	"                 P...x..............cM ",
	"                 W...c...==.==.......W ",
	"                 P..c....=.g.=....c..M ",
	"                 P..b.....oMo....cb..W ",
	"                 Pc......=.g.=.......M ",
	"                 I......c==.==.c.....P ",
	"                 W............c..x...I ",
	"                 M..v.............v.cM ",
	"                 M...cp.....c...p..c.M ",
	"                 P.........l.........I ",
	"                 P.t.......X...b.c.t.M ",
	"                 Pc......c......c....P ",
	"                 IIWPPMWMMWPPPIMPPMPPM ",
]

## Rooms: interior rects (inclusive, tile coords) + encounter beats.
## Beat trigger: "enter" or {"remaining": n}. Spawn entries: [enemy_id, count] or
## [enemy_id, count, {"elite": [affix, ...]}].
const ROOMS := [
	{
		"id": "landing", "name": "THE THRESHOLD", "rect": [2, 8, 10, 16], "lock": false,
		"beats": [
			{"trigger": "enter_delay", "delay": 2.5, "spawn": [["mite", 4]], "far": true},
			{"trigger": {"remaining": 1}, "spawn": [["mite", 3], ["spitter", 1]]},
		],
	},
	{
		"id": "conduit", "name": "BONE CORRIDOR", "rect": [12, 11, 19, 13], "lock": false,
		"beats": [
			{"trigger": "enter", "spawn": [["mite", 5], ["bloater", 1]], "far": true},
		],
	},
	{
		"id": "vault", "name": "FORGOTTEN RELIQUARY", "rect": [13, 1, 19, 4], "lock": false, "secret": true,
		"beats": [
			{"trigger": "enter", "spawn": [["spitter", 1, {"elite": ["frenzied"]}], ["mite", 4]], "far": true},
		],
	},
	{
		"id": "hatchery", "name": "THE KENNELS", "rect": [21, 7, 33, 19], "lock": true,
		"beats": [
			{"trigger": "enter", "spawn": [["mite", 12], ["spitter", 3]], "far": true},
			{"trigger": {"remaining": 4}, "spawn": [["bloater", 3], ["mite", 8], ["spitter", 1]], "nests": true},
			{"trigger": {"remaining": 3}, "spawn": [["brute", 1], ["mite", 7], ["spitter", 2]]},
		],
		"reward": "chest",
	},
	{
		"id": "spine", "name": "THE STORMWALK", "rect": [26, 21, 28, 27], "lock": false,
		"beats": [
			{"trigger": "enter", "spawn": [["mite", 5]], "far": true},
		],
	},
	{
		"id": "reactor", "name": "HALL OF THE LEGION", "rect": [18, 29, 36, 45], "lock": true,
		"beats": [
			{"trigger": "enter", "spawn": [["mite", 10], ["spitter", 3], ["brute", 1]], "far": true},
			{"trigger": {"remaining": 4}, "spawn": [["bloater", 3], ["spitter", 3], ["mite", 10]]},
			{"trigger": {"remaining": 3}, "spawn": [["brute", 1, {"elite": ["shielded", "volatile"]}], ["brute", 1], ["mite", 8], ["bloater", 2]], "boss": true},
		],
		"reward": "legendary",
		"exit": true,
	},
]
