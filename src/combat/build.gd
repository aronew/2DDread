class_name Build
extends RefCounted
## Aggregates everything that defines a character build: attributes, level,
## gear affixes, timed buffs, and behaviour perks. Combat calls the hook
## methods; perks react (explode, chain, refund ammo, stack buffs...).

const ATTRS := ["might", "agility", "vitality", "tech"]
const ATTR_DESC := {
	"might": "+3% damage",
	"agility": "+1.2% move speed, +0.8% crit",
	"vitality": "+12 max HP, +2 armour",
	"tech": "+4% ability power, -2% cooldowns",
}

var player
var stats := {}
var perks: Array = []
var buffs: Array = []           # {id, stat, value, t, stacks, max}
var attributes := {"might": 0, "agility": 0, "vitality": 0, "tech": 0}
var attr_points := 0


func _init(p) -> void:
	player = p


func stat(name: String, default := 0.0) -> float:
	return stats.get(name, default)


func mult(name: String) -> float:
	return 1.0 + stats.get(name, 0.0)


func _add(name: String, v: float) -> void:
	stats[name] = stats.get(name, 0.0) + v


func recalc() -> void:
	stats.clear()
	_add("damage_pct", 0.03 * attributes["might"])
	_add("move_speed_pct", 0.012 * attributes["agility"])
	_add("crit_chance", 0.008 * attributes["agility"])
	_add("max_hp", 12.0 * attributes["vitality"])
	_add("armor", 2.0 * attributes["vitality"])
	_add("ability_power_pct", 0.04 * attributes["tech"])
	_add("cooldown_pct", 0.02 * attributes["tech"])
	var lvl: int = player.level
	_add("max_hp", 8.0 * (lvl - 1))
	_add("damage_pct", 0.025 * (lvl - 1))
	# gear: every affix is global
	for slot in player.gear:
		var it = player.gear[slot]
		if it:
			for k in it.stats:
				_add(k, it.stats[k])
	for b in buffs:
		_add(b["stat"], b["value"] * b["stacks"])
	# the Soul Forge's permanent upgrades and Charon's drink for this crossing
	var mb: Dictionary = Meta.stat_bonus()
	for k in mb:
		_add(k, mb[k])
	# perks from gear (global) and weapons (bound to that weapon)
	perks.clear()
	for slot in player.gear:
		var it = player.gear[slot]
		if it:
			for pid in it.perks:
				perks.append(PerkLib.create(pid, self, null))
	for w in player.weapons:
		if w and w.item:
			for pid in w.item.perks:
				perks.append(PerkLib.create(pid, self, w))
	for p in perks:
		var sb: Dictionary = p.stat_bonus()
		for k in sb:
			_add(k, sb[k])
	for w in player.weapons:
		if w:
			w.recalc(self)
	if player.launcher:
		player.launcher.recalc(self)
	Events.stats_changed.emit()


func spend_point(attr: String) -> bool:
	if attr_points <= 0 or not attributes.has(attr):
		return false
	attr_points -= 1
	attributes[attr] += 1
	recalc()
	player.on_stats_changed()
	return true


func add_buff(id: String, stat_name: String, value: float, dur: float, max_stacks := 1) -> void:
	for b in buffs:
		if b["id"] == id:
			b["t"] = dur
			b["stacks"] = mini(b["max"], b["stacks"] + 1)
			recalc()
			return
	buffs.append({"id": id, "stat": stat_name, "value": value, "t": dur, "stacks": 1, "max": max_stacks})
	recalc()


func buff_stacks(id: String) -> int:
	for b in buffs:
		if b["id"] == id:
			return b["stacks"]
	return 0


func process(dt: float) -> void:
	var changed := false
	for b in buffs:
		b["t"] -= dt
		if b["t"] <= 0.0:
			changed = true
	if changed:
		buffs = buffs.filter(func(b): return b["t"] > 0.0)
		recalc()
	for p in perks:
		p.process(dt)


# ------------------------------------------------------------------ hooks

func before_hit(e, info: DamageInfo) -> void:
	info.amount *= mult("damage_pct") if info.weapon == null else 1.0
	if e.is_elite:
		info.amount *= mult("elite_damage_pct")
	if info.is_ability:
		info.amount *= mult("ability_power_pct")
	if info.is_melee:
		info.amount *= mult("melee_damage_pct")
	for p in perks:
		if p.applies(info):
			p.before_hit(e, info)


func after_hit(e, info: DamageInfo, dealt: float, killed: bool) -> void:
	for p in perks:
		if p.applies(info):
			p.after_hit(e, info, dealt, killed)
	if killed:
		on_kill(e, info)


func on_kill(e, info: DamageInfo) -> void:
	var lok := stat("life_on_kill")
	if lok > 0.0:
		player.heal(lok, false)
	for p in perks:
		if p.applies(info):
			p.on_kill(e, info)


func on_fire(w, projs: Array) -> void:
	for p in perks:
		if p.weapon == null or p.weapon == w:
			p.on_fire(w, projs)


func on_dash(a: Vector2, b: Vector2) -> void:
	for p in perks:
		p.on_dash(a, b)


func on_explosion(g: Vector2, r: float, info: DamageInfo) -> void:
	for p in perks:
		p.on_explosion(g, r, info)
