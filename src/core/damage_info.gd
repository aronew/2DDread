class_name DamageInfo
extends RefCounted
## Everything a hit carries. Perks inspect and mutate this before it lands.

enum Type { PHYSICAL, FIRE, SHOCK, TOXIC, EXPLOSIVE, VOID }

const TYPE_COLORS := {
	Type.PHYSICAL: Color(1.0, 0.92, 0.85),
	Type.FIRE: Color(1.0, 0.55, 0.15),
	Type.SHOCK: Color(0.55, 0.75, 1.0),
	Type.TOXIC: Color(0.55, 1.0, 0.3),
	Type.EXPLOSIVE: Color(1.0, 0.7, 0.3),
	Type.VOID: Color(0.8, 0.45, 1.0),
}

var amount := 0.0
var type: int = Type.PHYSICAL
var crit := false
var crit_mult := 2.0
var source: Object = null          # attacker node
var weapon: Object = null          # Weapon that produced it (for weapon-bound perks)
var direction := Vector2.ZERO      # ground-space unit vector (knockback direction)
var knockback := 0.0               # ground px/s impulse
var stagger := 0.0                 # stagger build-up
var status := {}                   # StringName -> chance (0..1)
var hit_pos := Vector2.ZERO        # ground position of the impact
var is_melee := false
var is_explosion := false
var is_ability := false
var is_dot := false
var proc_depth := 0                # chained effects increment this to stop infinite loops
var execute := false               # melee finisher on staggered enemies
var tags := {}


static func make(amount_: float, type_: int = Type.PHYSICAL, source_ = null) -> DamageInfo:
	var d := DamageInfo.new()
	d.amount = amount_
	d.type = type_
	d.source = source_ if is_instance_valid(source_) else null
	return d


func copy() -> DamageInfo:
	var d := DamageInfo.new()
	d.amount = amount
	d.type = type
	d.crit = crit
	d.crit_mult = crit_mult
	d.source = source if is_instance_valid(source) else null
	d.weapon = weapon
	d.direction = direction
	d.knockback = knockback
	d.stagger = stagger
	d.status = status.duplicate()
	d.hit_pos = hit_pos
	d.is_melee = is_melee
	d.is_explosion = is_explosion
	d.is_ability = is_ability
	d.is_dot = is_dot
	d.proc_depth = proc_depth
	d.tags = tags.duplicate()
	return d


func color() -> Color:
	return TYPE_COLORS.get(type, Color.WHITE)
