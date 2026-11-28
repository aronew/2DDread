class_name Meta
extends RefCounted
## Progress that survives between dives and between sessions (user://progress.cfg):
## * souls: the currency. Every kill sends souls into the gunslinger (the green motes),
##   clearing a room banks a few more; spent at the hub (The Last Obol).
## * forge: permanent upgrades bought at the Soul Forge (UPGRADES), applied in Build.recalc.
## * drink: one of Charon's drinks (DRINKS), poured at the bar; it lasts one crossing
##   and is gone when you come back to the hub.
## * best_depth: the deepest depth reached; the ferry can take you to any depth up to
##   one past it.
## Bot runs, stills and paint guides never read or write the save (they start blank);
## --fresh starts a blank save for one session without touching the file.

const PATH := "user://progress.cfg"

## id: [name, description, stat, value per level, max level, base cost]
const UPGRADES := {
	"hide": ["Iron Hide", "+15 max health", "max_hp", 15.0, 5, 25],
	"rounds": ["Hellfire Rounds", "+6% damage", "damage_pct", 0.06, 5, 30],
	"plating": ["Grave Plating", "+3 armour", "armor", 3.0, 5, 20],
	"oath": ["Sharpened Oath", "+2.5% critical chance", "crit_chance", 0.025, 4, 35],
	"stride": ["Ferryman's Stride", "+4% move speed", "move_speed_pct", 0.04, 3, 30],
	"shadow": ["Second Shadow", "+1 dash charge", "dash_charges", 1.0, 1, 160],
}

## id: [name, flavour, {stat: value}, cost]
const DRINKS := {
	"lethe": ["Lethe Gin", "Forget your fear. +20% damage.", {"damage_pct": 0.2}, 15],
	"stout": ["Charon's Stout", "Dark and heavy. +40 max health.", {"max_hp": 40.0}, 15],
	"nectar": ["Nectar of Nyx", "Night moves fast. -20% cooldowns, +8% move speed.", {"cooldown_pct": 0.2, "move_speed_pct": 0.08}, 20],
	"brimstone": ["Brimstone Rye", "Burns going down. +6% crit chance, +10% damage.", {"crit_chance": 0.06, "damage_pct": 0.1}, 20],
}

static var souls := 0
static var forge := {}          # id -> level
static var drink := ""          # the drink poured for the current crossing
static var best_depth := 1
static var shores := {}         # shore id -> true once reached by the ferry (the temple always is)
static var crossings := 0       # how many times the gunslinger has come back to the hub
static var lines_heard := {}    # npc id -> index of the next line
static var _loaded := false
static var _no_save := false


static func load_save() -> void:
	if _loaded:
		return
	_loaded = true
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "--bot" or a == "--fresh" or a == "--paint-guide" or a.begins_with("--look") or a.begins_with("--shots"):
			_no_save = true
	if _no_save:
		return
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	souls = int(cf.get_value("meta", "souls", 0))
	forge = cf.get_value("meta", "forge", {})
	drink = str(cf.get_value("meta", "drink", ""))
	best_depth = int(cf.get_value("meta", "best_depth", 1))
	shores = cf.get_value("meta", "shores", {})
	crossings = int(cf.get_value("meta", "crossings", 0))
	lines_heard = cf.get_value("meta", "lines_heard", {})


static func save() -> void:
	if _no_save:
		return
	var cf := ConfigFile.new()
	cf.set_value("meta", "souls", souls)
	cf.set_value("meta", "forge", forge)
	cf.set_value("meta", "drink", drink)
	cf.set_value("meta", "best_depth", best_depth)
	cf.set_value("meta", "shores", shores)
	cf.set_value("meta", "crossings", crossings)
	cf.set_value("meta", "lines_heard", lines_heard)
	cf.save(PATH)


static func add_souls(n: int) -> void:
	souls += n
	Events.souls_changed.emit(souls, n)


## Souls a kill is worth: a few for fodder, more for heavies and elites, a hoard for a boss,
## all scaled up with depth.
static func kill_value(e) -> int:
	var v := 1.0
	if e.data.boss:
		v = 120.0
	elif e.data.id == &"brute":
		v = 3.0
	if e.is_elite and not e.data.boss:
		v += 8.0
	return int(round(v * (1.0 + 0.25 * (Game.depth - 1))))


static func level(id: String) -> int:
	return int(forge.get(id, 0))


static func cost(id: String) -> int:
	var u: Array = UPGRADES[id]
	return int(round(float(u[5]) * pow(1.7, level(id))))


static func maxed(id: String) -> bool:
	return level(id) >= int(UPGRADES[id][4])


static func buy(id: String) -> bool:
	if maxed(id) or souls < cost(id):
		return false
	add_souls(-cost(id))
	forge[id] = level(id) + 1
	save()
	return true


static func pour(id: String) -> bool:
	if drink != "" or souls < int(DRINKS[id][3]):
		return false
	add_souls(-int(DRINKS[id][3]))
	drink = id
	save()
	return true


## Every permanent and drink bonus, added to the build like gear stats.
static func stat_bonus() -> Dictionary:
	var b := {}
	for id in forge:
		if UPGRADES.has(id):
			var u: Array = UPGRADES[id]
			b[u[2]] = b.get(u[2], 0.0) + float(u[3]) * int(forge[id])
	if DRINKS.has(drink):
		var st: Dictionary = DRINKS[drink][2]
		for k in st:
			b[k] = b.get(k, 0.0) + float(st[k])
	return b


## The next line an NPC says (each NPC works through its lines, then repeats the last few).
static func next_line(npc: String, lines: Array) -> String:
	var i := int(lines_heard.get(npc, 0))
	lines_heard[npc] = i + 1
	if i >= lines.size():
		i = lines.size() - 1 - (i % mini(3, lines.size()))
	return lines[i]
