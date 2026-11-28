class_name Projectile
extends RefCounted
## Plain data for one projectile. Simulated and drawn by ProjectileSystem.

var team := 0                 # 0 = player, 1 = enemy
var pos := Vector2.ZERO       # ground position
var prev := Vector2.ZERO
var vel := Vector2.ZERO       # ground px/s
var height := 1.3             # metres above ground (visual + lob arcs)
var vz := 0.0                 # m/s, for lobbed projectiles
var gravity := 0.0            # m/s^2
var lob := false
var info: DamageInfo
var crit_chance := 0.0
var crit_mult := 2.0
var pierce := 0
var ricochet := 0
var max_range := 2000.0
var traveled := 0.0
var falloff_start := 1e9
var falloff_min := 1.0
var radius := 10.0
var explode_radius := 0.0
var split := 0
var chain := 0
var homing: Object = null
var homing_turn := 0.0
var kind: StringName = &"bolt"
var color := Color.WHITE
var width := 4.0
var length := 60.0
var size := 1.0               # draw scale for shard-like enemy shots (the titan's are 2.6x)
var impact_style := "metal"
var weapon = null
var hit_ids := {}
var dead := false
var age := 0.0
var trail := PackedVector2Array()
var tags := {}


## Ballistic arc that lands on `target` (ground). Speed is horizontal ground px/s.
func setup_lob(from: Vector2, target: Vector2, h0: float, speed: float) -> void:
	lob = true
	gravity = 26.0
	var d := target - from
	var dist := clampf(d.length(), Iso.m(2.0), Iso.m(15.0))
	var dir := d.normalized() if d.length() > 1.0 else Vector2.RIGHT
	var t := maxf(0.25, dist / speed)
	vel = dir * (dist / t)
	vz = (0.5 * gravity * t * t - h0) / t
	max_range = dist + Iso.m(4.0)
