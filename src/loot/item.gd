class_name Item
extends RefCounted
## A piece of loot: a weapon or gear piece with rarity, rolled stat affixes
## and behaviour perks.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC }

const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"]
const RARITY_COLORS := [
	Color(0.82, 0.82, 0.8), Color(0.35, 0.95, 0.4), Color(0.3, 0.6, 1.0),
	Color(0.75, 0.35, 1.0), Color(1.0, 0.6, 0.12), Color(1.0, 0.18, 0.25)]
const POWER := [1.0, 1.08, 1.17, 1.28, 1.42, 1.6]

const STAT_LABELS := {
	"damage_pct": ["+%d%% Damage", 100.0],
	"fire_rate_pct": ["+%d%% Fire Rate", 100.0],
	"crit_chance": ["+%d%% Critical Chance", 100.0],
	"crit_damage": ["+%d%% Critical Damage", 100.0],
	"reload_speed_pct": ["+%d%% Reload Speed", 100.0],
	"mag_pct": ["+%d%% Magazine Size", 100.0],
	"projectile_speed_pct": ["+%d%% Projectile Speed", 100.0],
	"stagger_pct": ["+%d%% Stagger", 100.0],
	"burn_chance": ["%d%% chance to Ignite", 100.0],
	"shock_chance": ["%d%% chance to Shock", 100.0],
	"pierce": ["Shots pierce +%d enemy", 1.0],
	"ricochet": ["Shots ricochet +%d time", 1.0],
	"chain": ["Hits chain to +%d enemy", 1.0],
	"max_hp": ["+%d Max Health", 1.0],
	"armor": ["+%d Armour", 1.0],
	"move_speed_pct": ["+%d%% Move Speed", 100.0],
	"cooldown_pct": ["-%d%% Ability Cooldowns", 100.0],
	"ability_power_pct": ["+%d%% Ability Power", 100.0],
	"explosion_radius_pct": ["+%d%% Explosion Radius", 100.0],
	"life_on_kill": ["+%d Health on Kill", 1.0],
	"elite_damage_pct": ["+%d%% Damage vs Elites", 100.0],
	"melee_damage_pct": ["+%d%% Melee Damage", 100.0],
	"dash_charges": ["+%d Dash Charge", 1.0],
}

var kind: StringName = &"weapon"     # weapon | armor | core | relic
var base_id: StringName = &"rifle"
var rarity: int = Rarity.COMMON
var level := 1
var stats := {}                      # stat -> value
var perks: Array = []                # perk ids
var unique_name := ""


func is_weapon() -> bool:
	return kind == &"weapon"


func power_mult() -> float:
	return POWER[rarity] * (1.0 + 0.06 * (level - 1))


func color() -> Color:
	return RARITY_COLORS[rarity]


func rarity_name() -> String:
	return RARITY_NAMES[rarity]


func base_name() -> String:
	if is_weapon():
		var d: WeaponData = WeaponDB.get_data(base_id)
		return d.display_name if d else String(base_id)
	match kind:
		&"armor": return "Plated Harness"
		&"core": return "Reactor Core"
		&"relic": return "Void Relic"
	return "Item"


func display_name() -> String:
	if unique_name != "":
		return unique_name
	return base_name()


## Weapon affixes apply only to that weapon.
func local_stats() -> Dictionary:
	return stats if is_weapon() else {}


func describe() -> Array:
	var lines: Array = []
	for k in stats:
		var lab: Array = STAT_LABELS.get(k, ["%s %%d" % k, 1.0])
		lines.append([lab[0] % int(round(stats[k] * lab[1])), Color(0.75, 0.85, 1.0)])
	for p in perks:
		lines.append(["%s — %s" % [PerkLib.title(p), PerkLib.desc(p)], color() if rarity >= Rarity.LEGENDARY else Color(0.95, 0.85, 0.5)])
	return lines


func score() -> float:
	return rarity * 10.0 + level + stats.size() + perks.size() * 4.0
