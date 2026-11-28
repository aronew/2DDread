class_name SoulRing
extends Node2D
## The titan's nova: a ring of magenta fire racing out across the ground from where it
## stood. It burns the player once as it passes, unless they dash through it (i-frames)
## or outrun it. The titan's red circle and roar telegraph it a second ahead.

const WIDTH_M := 0.9

var center := Vector2.ZERO
var r := 0.0
var max_r := 0.0
var speed := 0.0
var damage := 0.0
var source = null
var _hit := false
var _fade := 1.0
var _ember_t := 0.0


func setup(c: Vector2, max_radius: float, dur: float, dmg: float, src) -> void:
	center = c
	max_r = max_radius
	speed = max_radius / maxf(0.2, dur)
	damage = dmg
	source = src
	r = Iso.m(1.0)
	position = Iso.to_screen(center)
	z_index = 2
	material = VFX.add_mat
	add_to_group("soul_rings")


func _process(dt: float) -> void:
	r += speed * dt
	if r >= max_r:
		_fade -= dt * 4.0
		if _fade <= 0.0:
			queue_free()
			return
	var pl = Game.player
	if not _hit and pl and pl.alive and _fade > 0.5:
		var d: float = pl.gpos.distance_to(center)
		if absf(d - r) < Iso.m(WIDTH_M) * 0.5 + pl.radius and Game.dungeon.has_los(center, pl.gpos):
			_hit = true
			if not pl.invulnerable():
				var info := DamageInfo.make(damage, DamageInfo.Type.FIRE, source)
				info.direction = (pl.gpos - center).normalized()
				info.knockback = Iso.m(10.0)
				pl.take_damage(info)
	_ember_t -= dt
	if _ember_t <= 0.0:
		_ember_t = 0.05
		var a := randf() * TAU
		VFX.emit("embers", Iso.to_screen(center + Vector2.from_angle(a) * r), -PI / 2, Color(2.6, 0.6, 2.4), 0.06)
	queue_redraw()


## Seconds until the ring reaches distance d (the bot dashes through just before it does).
func eta(d: float) -> float:
	return (d - r) / maxf(1.0, speed)


func _draw() -> void:
	var w := Iso.m(WIDTH_M)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Iso.K))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(1.6, 0.3, 1.5, 0.35 * _fade), w * 2.2, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(2.8, 0.6, 2.6, 0.9 * _fade), w * 0.7, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(3.2, 2.4, 3.2, _fade), w * 0.18, true)
