class_name Loot
extends RefCounted
## Item generation (rarity, affixes, perks) and drop placement.

const RARITY_WEIGHTS := [58.0, 27.0, 10.5, 3.4, 0.95, 0.15]

const WEAPON_AFFIXES := {
	"damage_pct": [0.06, 0.2], "fire_rate_pct": [0.05, 0.16], "crit_chance": [0.02, 0.07],
	"crit_damage": [0.15, 0.55], "reload_speed_pct": [0.1, 0.3], "mag_pct": [0.12, 0.35],
	"projectile_speed_pct": [0.1, 0.3], "stagger_pct": [0.15, 0.45], "burn_chance": [0.08, 0.22],
	"shock_chance": [0.08, 0.22],
}
const WEAPON_BEHAVIOUR := {"pierce": [1, 1], "ricochet": [1, 2], "chain": [1, 2]}
const GEAR_AFFIXES := {
	"max_hp": [12.0, 45.0], "armor": [4.0, 16.0], "move_speed_pct": [0.03, 0.09],
	"damage_pct": [0.04, 0.12], "crit_chance": [0.02, 0.05], "cooldown_pct": [0.05, 0.14],
	"ability_power_pct": [0.08, 0.22], "explosion_radius_pct": [0.1, 0.25], "life_on_kill": [2.0, 6.0],
	"elite_damage_pct": [0.1, 0.3], "melee_damage_pct": [0.15, 0.45],
}
const GEAR_IMPLICIT := {&"armor": ["max_hp", 20.0], &"core": ["cooldown_pct", 0.05], &"relic": ["damage_pct", 0.05]}
const LEGENDARY_NAMES := {
	&"fifth_shot": "the Fifth Seal", &"dash_trail": "Stormstep", &"crit_kill_chain": "Thunder Verdict",
	&"big_boom": "Cataclysm", &"kill_speed": "Bloodrush", &"killstreak_dmg": "the Carnage Engine",
	&"elite_reset": "Apex Predator", &"vampiric": "the Hemophage",
}


static func rng() -> RandomNumberGenerator:
	return Game.rng


static func roll_rarity(luck := 0.0, min_r := 0) -> int:
	var w := RARITY_WEIGHTS.duplicate()
	for i in range(1, w.size()):
		w[i] *= 1.0 + luck * i
	var total := 0.0
	for i in range(min_r, w.size()):
		total += w[i]
	var r := rng().randf() * total
	for i in range(min_r, w.size()):
		r -= w[i]
		if r <= 0.0:
			return i
	return min_r


static func _roll(range_: Array, rarity: int) -> float:
	var t := clampf(rng().randf() * 0.7 + rarity * 0.07, 0.0, 1.0)
	return lerpf(range_[0], range_[1], t)


static func make_weapon(base: StringName, rarity: int, level: int) -> Item:
	var it := Item.new()
	it.kind = &"weapon"
	it.base_id = base
	it.rarity = rarity
	it.level = level
	var n_stats: int = [rng().randi_range(0, 1), 1, 2, 2, 2, 3][rarity]
	var keys := WEAPON_AFFIXES.keys()
	keys.shuffle()
	for i in n_stats:
		it.stats[keys[i]] = _roll(WEAPON_AFFIXES[keys[i]], rarity)
	if rarity >= Item.Rarity.RARE:
		var beh := WEAPON_BEHAVIOUR.keys()
		var pick: String = beh[rng().randi() % beh.size()]
		# arc/rail already pierce or chain: give them perks instead of redundant affixes
		if not (base in [&"rail"] and pick == "pierce"):
			var rr: Array = WEAPON_BEHAVIOUR[pick]
			it.stats[pick] = float(rng().randi_range(rr[0], rr[1]))
	if rarity >= Item.Rarity.EPIC:
		var wp := PerkLib.WEAPON_PERKS.duplicate()
		if base in [&"arc", &"rail"]:
			wp.erase(&"split")
		it.perks.append(wp[rng().randi() % wp.size()])
	if rarity >= Item.Rarity.LEGENDARY:
		var lp: StringName = PerkLib.LEGENDARY[rng().randi() % PerkLib.LEGENDARY.size()]
		it.perks.append(lp)
		it.unique_name = "%s of %s" % [WeaponDB.get_data(base).display_name, LEGENDARY_NAMES.get(lp, "Legend")]
	if rarity >= Item.Rarity.MYTHIC:
		var mp: StringName = PerkLib.MYTHIC[rng().randi() % PerkLib.MYTHIC.size()]
		it.perks.append(mp)
		it.unique_name = "%s, %s" % [WeaponDB.get_data(base).display_name, LEGENDARY_NAMES.get(mp, "Mythic")]
	return it


static func make_gear(slot: StringName, rarity: int, level: int) -> Item:
	var it := Item.new()
	it.kind = slot
	it.base_id = slot
	it.rarity = rarity
	it.level = level
	var imp: Array = GEAR_IMPLICIT[slot]
	it.stats[imp[0]] = imp[1] * (1.0 + 0.1 * (level - 1))
	var n_stats: int = [1, 1, 2, 3, 3, 4][rarity]
	var keys := GEAR_AFFIXES.keys()
	keys.shuffle()
	var added := 0
	for k in keys:
		if added >= n_stats:
			break
		var v := _roll(GEAR_AFFIXES[k], rarity)
		if k in ["max_hp", "armor", "life_on_kill"]:
			v *= 1.0 + 0.08 * (level - 1)
		it.stats[k] = it.stats.get(k, 0.0) + v
		added += 1
	if rarity >= Item.Rarity.EPIC and rng().randf() < 0.25:
		it.stats["dash_charges"] = 1.0
	if rarity >= Item.Rarity.LEGENDARY:
		var lp: StringName = PerkLib.LEGENDARY[rng().randi() % PerkLib.LEGENDARY.size()]
		it.perks.append(lp)
		it.unique_name = "%s of %s" % [it.base_name(), LEGENDARY_NAMES.get(lp, "Legend")]
	if rarity >= Item.Rarity.MYTHIC:
		var mp: StringName = PerkLib.MYTHIC[rng().randi() % PerkLib.MYTHIC.size()]
		it.perks.append(mp)
	return it


static func random_item(level: int, min_rarity := 0, luck := 0.0) -> Item:
	var r := roll_rarity(luck, min_rarity)
	if rng().randf() < 0.55:
		var bases := WeaponDB.LOOTABLE
		return make_weapon(bases[rng().randi() % bases.size()], r, level)
	var slots := [&"armor", &"core", &"relic"]
	return make_gear(slots[rng().randi() % 3], r, level)


static func item_level() -> int:
	var pl = Game.player
	return maxi(1, (pl.level if pl else 1) + Game.depth - 1)


# ------------------------------------------------------------------ drops

static func scatter(g: Vector2, spread_m := 1.2) -> Vector2:
	var p := g + Vector2.from_angle(rng().randf() * TAU) * Iso.m(rng().randf_range(0.3, spread_m))
	if Game.dungeon and Game.dungeon.walk_blocked(Iso.cell_of(p)):
		return g
	return p


static func drop_from_enemy(e) -> void:
	var g: Vector2 = e.gpos
	var xp: int = int(e.data.xp * (2.5 if e.is_elite else 1.0) * (1.0 + 0.2 * (Game.depth - 1)))
	var orbs := clampi(xp / 6, 1, 10)
	for i in orbs:
		Pickup.spawn(&"xp", g, {"value": maxi(1, xp / orbs)})
	var pl = Game.player
	var hp_frac: float = pl.hp / pl.max_hp if pl else 1.0
	# health/ammo pity: the lower you are, the more the enemies give back
	if rng().randf() < 0.07 + (1.0 - hp_frac) * 0.18 or e.is_elite:
		Pickup.spawn(&"health", g, {"value": 12.0 if not e.is_elite else 40.0})
	if rng().randf() < 0.09 + pl.ammo_need() * 0.2:
		Pickup.spawn(&"ammo", g, {"value": 0.12})
	var chance: float = e.data.loot_chance * (1.0 + 0.15 * (Game.depth - 1))
	if e.is_elite:
		spawn_item(g, random_item(item_level(), Item.Rarity.RARE, 0.8))
		if rng().randf() < 0.5:
			spawn_item(g, random_item(item_level(), Item.Rarity.UNCOMMON, 0.4))
	elif rng().randf() < chance:
		spawn_item(g, random_item(item_level(), 0, 0.0))


static func drop_supplies(g: Vector2, n: int, item_chance: float) -> void:
	for i in n:
		Pickup.spawn(&"ammo" if rng().randf() < 0.6 else &"health", g, {"value": 0.15 if i % 2 == 0 else 15.0})
	if rng().randf() < item_chance:
		spawn_item(g, random_item(item_level(), 0, 0.2))


static func drop_chest(g: Vector2, quality: String) -> void:
	match quality:
		"legendary":
			spawn_item(g, random_item(item_level() + 1, Item.Rarity.LEGENDARY, 1.5))
			spawn_item(g, random_item(item_level(), Item.Rarity.RARE, 0.8))
			spawn_item(g, random_item(item_level(), Item.Rarity.UNCOMMON, 0.4))
		"epic":
			spawn_item(g, random_item(item_level(), Item.Rarity.EPIC, 1.0))
			spawn_item(g, random_item(item_level(), Item.Rarity.UNCOMMON, 0.4))
		_:
			spawn_item(g, random_item(item_level(), Item.Rarity.RARE, 0.6))
			spawn_item(g, random_item(item_level(), 0, 0.3))
	for i in 3:
		Pickup.spawn(&"health" if i == 0 else &"ammo", g, {"value": 20.0 if i == 0 else 0.2})
	for i in 6:
		Pickup.spawn(&"xp", g, {"value": 6 * Game.depth})


static func spawn_item(g: Vector2, it: Item) -> void:
	Pickup.spawn(&"item", g, {"item": it})
	Events.item_dropped.emit(it, g)
	if it.rarity >= Item.Rarity.LEGENDARY:
		Audio.play("legendary_drop", g)
		VFX.light_flash(Iso.lift(g, 1.0), it.color(), 3.0, 5.0, 1.2)
