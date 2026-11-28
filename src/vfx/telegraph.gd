class_name Telegraph
extends Node2D
## Ground-plane attack warning. An outline marks the danger zone and an inner
## fill grows until the attack lands, so players can read exactly when to dash.

var _kind := 0
var _g := Vector2.ZERO
var _b := Vector2.ZERO
var _r := 0.0
var _w := 0.0
var _dur := 1.0
var _t := 0.0
var _color := Color.RED
var _done := false


func setup_circle(g: Vector2, radius: float, dur: float, color: Color) -> void:
	_kind = 0
	_g = g
	_r = radius
	_dur = maxf(dur, 0.01)
	_color = color
	material = VFX.add_mat
	z_index = 2


func setup_line(a: Vector2, b: Vector2, width: float, dur: float, color: Color) -> void:
	_kind = 1
	_g = a
	_b = b
	_w = width
	_dur = maxf(dur, 0.01)
	_color = color
	material = VFX.add_mat
	z_index = 2


func set_line(a: Vector2, b: Vector2) -> void:
	_g = a
	_b = b


func move_to(g: Vector2) -> void:
	var d := g - _g
	_g = g
	_b += d


func cancel() -> void:
	_done = true
	queue_free()


func _process(dt: float) -> void:
	_t += dt
	if _t >= _dur + 0.12:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var p := clampf(_t / _dur, 0.0, 1.0)
	var pulse := 0.75 + 0.25 * sin(_t * 26.0)
	var fade := 1.0 if _t < _dur else clampf(1.0 - (_t - _dur) / 0.12, 0, 1)
	var edge := _color * Color(2.2, 2.2, 2.2, 0.9 * pulse * fade)
	var fill := _color * Color(1.2, 1.2, 1.2, (0.05 + 0.16 * p) * fade)
	if _kind == 0:
		var c := Iso.to_screen(_g)
		draw_polyline(_ellipse(c, _r, 40), edge, 3.0, true)
		# (a fill only a few px across is squashed flat by the iso ellipse and fails to
		# triangulate)
		if p > 0.02 and _r * p > 8.0:
			draw_colored_polygon(_ellipse(c, _r * p, 32), fill)
		if _r > 8.0:
			draw_colored_polygon(_ellipse(c, _r, 32), _color * Color(1, 1, 1, 0.04 * fade))
		draw_polyline(_ellipse(c, _r * p, 40), edge * Color(1, 1, 1, 0.6), 2.0, true)
	else:
		var d := (_b - _g)
		var n := d.orthogonal().normalized() * _w * 0.5
		var full := PackedVector2Array([Iso.to_screen(_g + n), Iso.to_screen(_b + n), Iso.to_screen(_b - n), Iso.to_screen(_g - n), Iso.to_screen(_g + n)])
		draw_polyline(full, edge, 3.0, true)
		var e := _g + d * p
		if p > 0.02 and _w > 0.5:
			draw_colored_polygon(PackedVector2Array([Iso.to_screen(_g + n), Iso.to_screen(e + n), Iso.to_screen(e - n), Iso.to_screen(_g - n)]), fill)


static func _ellipse(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * Iso.K))
	return pts
