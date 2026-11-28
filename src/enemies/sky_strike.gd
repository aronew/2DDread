class_name SkyStrike
extends Node2D
## A telegraphed strike from above (the titan's arena): a red circle on the floor, then
##   "rock"   a chunk of the ceiling falls into it (shaken loose by a stomp or a crash);
##   "venom"  a glob of venom the titan spat arcs in and splashes, leaving a burning pool.
## It hurts the player and enemies (spiderlings) caught in it. The bot reads the circle
## through the "ground_danger" group (hit_g, radius).

var hit_g := Vector2.ZERO
var from_g := Vector2.ZERO
var radius := 0.0
var delay := 1.0
var damage := 20.0
var kind := "rock"
var source = null
var _t := 0.0
var _tele: Telegraph


func setup(target: Vector2, r_m: float, delay_s: float, dmg: float, kind_: String, src, from := Vector2.ZERO) -> void:
	hit_g = target
	radius = Iso.m(r_m)
	delay = delay_s
	damage = dmg
	kind = kind_
	source = src
	from_g = from if from != Vector2.ZERO else target
	z_index = 3
	add_to_group("ground_danger")


func _ready() -> void:
	_tele = VFX.telegraph_circle(hit_g, radius, delay)


func _process(dt: float) -> void:
	_t += dt
	if _t >= delay:
		_impact()
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var u := clampf(_t / delay, 0.0, 1.0)
	if kind == "rock":
		# falls only in the last 40%: a dark tumbling chunk with dust trailing
		if u < 0.6:
			return
		var k := (u - 0.6) / 0.4
		var h := lerpf(9.0, 0.0, k * k)
		var c := Iso.lift(hit_g, h)
		var r := radius * 0.45
		var rot := _t * 9.0
		var pts := PackedVector2Array()
		for i in 7:
			var a := rot + i * TAU / 7.0
			pts.append(c + Vector2(cos(a), sin(a) * 0.8) * r * (0.75 + 0.25 * sin(i * 2.3)))
		draw_colored_polygon(pts, Color(0.18, 0.2, 0.2))
		pts.append(pts[0])
		draw_polyline(pts, Color(0.02, 0.02, 0.03), 3.0, true)
		draw_line(c, c - Vector2(0, 60), Color(0.5, 0.5, 0.5, 0.25), r * 0.8)
	else:
		# a venom glob arcing from the titan's mouth
		var g := from_g.lerp(hit_g, u)
		var h := 1.6 + 4.5 * sin(u * PI)
		var c := Iso.lift(g, h)
		draw_texture_rect(VFX.T.glow, Rect2(c - Vector2(30, 30), Vector2(60, 60)), false, Color(2.2, 0.5, 2.0, 0.8))
		draw_circle(c, 9.0, Color(3.0, 1.2, 2.8))


func _impact() -> void:
	if is_instance_valid(_tele):
		_tele.cancel()
	var col := Color(1.0, 0.3, 0.9) if kind == "venom" else Color(0.6, 0.58, 0.55)
	if kind == "rock":
		VFX.debris(hit_g, 2.0, 18)
		VFX.emit("smoke", Iso.lift(hit_g, 0.3), -PI / 2, Color(0.35, 0.34, 0.33, 0.7), 0.7)
		VFX.decal(hit_g, VFX.T.scorch, Color(0, 0, 0, 0.4), radius * 1.6)
		Audio.play("wall_break", hit_g, -6.0, randf_range(0.8, 1.1))
		VFX.shake(0.18)
	else:
		VFX.gore(hit_g, col, 1.2)
		VFX.flash_layer(VFX.T.star6, Iso.lift(hit_g, 0.3), randf() * TAU, Color(2.6, 0.8, 2.4, 1.0),
			Vector2(0.4, 0.4), Vector2(1.6, 1.4), 0.14)
		Audio.play("acid_splash", hit_g)
		var pool := GroundHazard.new()
		pool.setup(hit_g, radius * 0.9, 3.0, source, "acid")
		pool.color = Color(1.0, 0.3, 0.9)
		pool.type = DamageInfo.Type.VOID
		Game.world.add_hazard(pool)
	VFX.ring(hit_g, radius, col * 1.4, 0.25, 0.2)
	var pl = Game.player
	if pl and pl.alive and pl.gpos.distance_to(hit_g) < radius + pl.radius:
		var d := DamageInfo.make(damage, DamageInfo.Type.PHYSICAL if kind == "rock" else DamageInfo.Type.VOID, source)
		d.direction = (pl.gpos - hit_g).normalized() if pl.gpos.distance_to(hit_g) > 1.0 else Vector2.RIGHT
		d.knockback = Iso.m(6.0)
		pl.take_damage(d)
	if kind == "rock":
		for e in Game.grid.query(hit_g, radius):
			if e != source and is_instance_valid(e) and e.alive:
				var d := DamageInfo.make(damage * 2.0, DamageInfo.Type.PHYSICAL, self)
				d.direction = (e.gpos - hit_g).normalized()
				e.take_damage(d)
