class_name ExitPortal
extends Node2D
## Descent portal. Dormant until the final arena is cleared; stepping in takes
## the player to the next, more dangerous depth.

var gpos := Vector2.ZERO
var active := false
var _t := 0.0
var _light: PointLight2D
var _used := false


func setup(g: Vector2) -> void:
	gpos = g
	position = Iso.to_screen(g)
	material = VFX.add_mat
	z_index = -9


func _ready() -> void:
	_light = PointLight2D.new()
	_light.texture = VFX.T.light
	_light.color = Color(0.4, 0.8, 1.0)
	_light.energy = 0.3
	_light.texture_scale = 3.0
	_light.scale = Vector2(1, Iso.K)
	_light.height = 60.0
	add_child(_light)


func activate() -> void:
	active = true
	VFX.ring(gpos, Iso.m(3.5), Color(0.4, 0.8, 1.0), 0.8, 0.05)
	Events.message.emit("DESCENT PORTAL OPEN", Color(0.5, 0.85, 1.0))


func _process(dt: float) -> void:
	_t += dt
	_light.energy = (1.6 + 0.4 * sin(_t * 3.0)) if active else 0.3
	queue_redraw()
	var pl = Game.player
	if active and not _used and pl and pl.alive and pl.gpos.distance_to(gpos) < Iso.m(1.1):
		_used = true
		Game.world.descend()


func _draw() -> void:
	var r := Iso.m(1.3)
	var a := 1.0 if active else 0.25
	var col := Color(0.4, 0.8, 1.0)
	for i in 3:
		var rr := r * (1.0 - i * 0.25)
		var start := _t * (1.5 + i) * (1 if i % 2 == 0 else -1)
		var pts := PackedVector2Array()
		for k in 24:
			var ang := start + k / 24.0 * TAU * 0.7
			pts.append(Vector2(cos(ang) * rr, sin(ang) * rr * Iso.K))
		draw_polyline(pts, col * Color(2.5, 2.5, 2.5, a * 0.8), 4.0 - i, true)
	draw_colored_polygon(Telegraph._ellipse(Vector2.ZERO, r, 32), col * Color(1, 1, 1, 0.15 * a))
	if active:
		draw_texture_rect(VFX.T.spark, Rect2(Vector2(-30, -260), Vector2(60, 260)), false, col * Color(2, 2, 2, 0.35 + 0.1 * sin(_t * 5.0)))
