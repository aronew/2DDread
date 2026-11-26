class_name GroundHazard
extends Node2D
## Lingering damage zone (burning ground, acid pools). Ticks on everything inside,
## enemies included — area denial cuts both ways.

var gpos := Vector2.ZERO
var radius := 100.0
var duration := 4.0
var tick := 0.4
var dps := 14.0
var type: int = DamageInfo.Type.FIRE
var color := Color(1.0, 0.45, 0.12)
var hurts_player := true
var hurts_enemies := true
var source: Object = null

var _t := 0.0
var _tick_t := 0.0
var _light: PointLight2D
var _emit_t := 0.0


func setup(g: Vector2, r: float, dur: float, src: Object, kind := "fire") -> void:
	gpos = g
	radius = r
	duration = dur
	source = src
	if kind == "acid":
		type = DamageInfo.Type.TOXIC
		color = Color(0.45, 1.0, 0.2)
		dps = 10.0
		hurts_enemies = false
	position = Iso.to_screen(g)
	material = VFX.add_mat
	z_index = 1


func _ready() -> void:
	_light = PointLight2D.new()
	_light.texture = VFX.T.light
	_light.color = color
	_light.energy = 0.9
	_light.height = 40.0
	_light.texture_scale = radius * 2.6 / 256.0
	_light.scale = Vector2(1, Iso.K)
	add_child(_light)


func _process(dt: float) -> void:
	_t += dt
	var life := 1.0 - _t / duration
	if life <= 0.0:
		queue_free()
		return
	_light.energy = (0.7 + 0.3 * sin(_t * 17.0) * sin(_t * 7.0)) * minf(1.0, life * 3.0)
	_emit_t -= dt
	if _emit_t <= 0.0:
		_emit_t = 0.07
		var off := Vector2.from_angle(randf() * TAU) * radius * randf() * 0.8
		var kind := "embers" if type == DamageInfo.Type.FIRE else "blood"
		VFX.emit(kind, Iso.to_screen(gpos + off), -PI / 2, color * 2.5, 0.18)
	_tick_t -= dt
	if _tick_t <= 0.0:
		_tick_t = tick
		_apply()
	queue_redraw()


func _apply() -> void:
	var amount := dps * tick
	if hurts_enemies:
		for e in Game.grid.query(gpos, radius):
			var d := DamageInfo.make(amount, type, source)
			d.is_dot = true
			d.hit_pos = e.gpos
			d.status = {&"burn": 0.25} if type == DamageInfo.Type.FIRE else {}
			e.take_damage(d)
	var pl = Game.player
	if hurts_player and pl and pl.alive and pl.gpos.distance_to(gpos) < radius + pl.radius * 0.5:
		var d := DamageInfo.make(amount * 0.7, type, source)
		d.is_dot = true
		pl.take_damage(d)


func _draw() -> void:
	var life := clampf(1.0 - _t / duration, 0, 1)
	var a := minf(1.0, life * 3.0) * (0.1 + 0.04 * sin(_t * 9.0))
	draw_colored_polygon(Telegraph._ellipse(Vector2.ZERO, radius, 28), color * Color(1.0, 1.0, 1.0, a))
	draw_polyline(Telegraph._ellipse(Vector2.ZERO, radius, 28), color * Color(1.6, 1.6, 1.6, a * 2.5), 2.0, true)
