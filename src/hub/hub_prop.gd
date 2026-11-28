class_name HubProp
extends Node2D
## Hub set pieces drawn procedurally until the hub is painted:
##   anvil  the Soul Forge's anvil, glowing coals under it, sparks now and then;
##   ferry  Charon's boat moored in the soul-fire lake, a lantern on its curled prow,
##          rocking gently;
##   bar    bottles, mugs and a candle standing along the bar counter.

var kind := ""
var gpos := Vector2.ZERO
var _t := 0.0
var _spark_t := 0.0


func setup(kind_: String, g: Vector2) -> void:
	kind = kind_
	gpos = g
	position = Iso.to_screen(g)


func _ready() -> void:
	var l := PointLight2D.new()
	l.texture = VFX.T.light
	l.color = Color(1.0, 0.5, 0.2) if kind != "ferry" else Color(0.45, 1.0, 0.6)
	l.energy = 1.6
	l.texture_scale = 2.2
	l.scale = Vector2(1, Iso.K)
	l.height = 50.0
	l.position = _ground_pt(1.9, 0.0, 1.6) if kind == "ferry" else Vector2(0, -Iso.h(0.6 if kind == "anvil" else 1.4))
	if kind == "bar":
		l.energy = 0.9
	add_child(l)


func _process(dt: float) -> void:
	_t += dt
	if kind == "anvil":
		_spark_t -= dt
		if _spark_t <= 0.0:
			_spark_t = randf_range(0.6, 1.6)
			VFX.emit("sparks", Iso.lift(gpos, 0.9), -PI / 2 + randf_range(-0.6, 0.6), Color(2.4, 1.2, 0.4), 0.08)
	queue_redraw()


## A point a metres along the tile i axis, b along the tile j axis from gpos, h metres up,
## in local screen coordinates.
func _ground_pt(a: float, b: float, h: float) -> Vector2:
	var o := Iso.tile_to_ground(Vector2.ZERO)
	var u := (Iso.tile_to_ground(Vector2(1, 0)) - o).normalized()
	var v := (Iso.tile_to_ground(Vector2(0, 1)) - o).normalized()
	return Iso.lift(gpos + u * Iso.m(a) + v * Iso.m(b), h) - position


func _ink_poly(pts: PackedVector2Array, fill: Color, line := Color(0.02, 0.02, 0.03), w := 2.5) -> void:
	draw_colored_polygon(pts, fill)
	var o := pts.duplicate()
	o.append(pts[0])
	draw_polyline(o, line, w, true)


func _draw() -> void:
	match kind:
		"anvil":
			_draw_anvil()
		"bar":
			_draw_bar()
		_:
			_draw_ferry()


const COUNTER_H := 1.02
const BOTTLES := [[-2.5, 0.0, Color(0.2, 0.5, 0.3)], [-2.2, 0.06, Color(0.45, 0.15, 0.4)], [-1.2, -0.05, Color(0.5, 0.3, 0.12)],
	[0.4, 0.0, Color(0.2, 0.45, 0.5)], [0.7, 0.08, Color(0.2, 0.5, 0.3)], [2.1, -0.04, Color(0.55, 0.2, 0.15)]]
const MUGS := [[-1.7, 0.1], [-0.4, -0.08], [1.4, 0.05], [2.5, 0.1]]


func _draw_bar() -> void:
	for b in BOTTLES:
		var base := _ground_pt(b[0], b[1], COUNTER_H)
		var col: Color = b[2]
		var body := Rect2(base - Vector2(5, 26), Vector2(10, 26))
		draw_rect(body.grow(1.5), Color(0.02, 0.02, 0.03))
		draw_rect(body, col)
		draw_rect(Rect2(base - Vector2(2, 38), Vector2(4, 13)), Color(0.02, 0.02, 0.03))
		draw_rect(Rect2(base - Vector2(1, 37), Vector2(2, 11)), col.lightened(0.2))
		draw_line(base + Vector2(-3, -23), base + Vector2(-3, -6), Color(1, 1, 1, 0.35), 1.5)
	for m in MUGS:
		var base := _ground_pt(m[0], m[1], COUNTER_H)
		var r := Rect2(base - Vector2(6, 13), Vector2(12, 13))
		draw_rect(r.grow(1.5), Color(0.02, 0.02, 0.03))
		draw_rect(r, Color(0.45, 0.3, 0.16))
		draw_rect(Rect2(r.position, Vector2(12, 3)), Color(0.9, 0.82, 0.6))
		draw_arc(base + Vector2(7, -7), 4.0, -PI / 2, PI / 2, 8, Color(0.02, 0.02, 0.03), 2.0)
	var cp := _ground_pt(0.0, 0.0, COUNTER_H)
	var f := 1.0 + 0.12 * sin(_t * 9.0)
	draw_rect(Rect2(cp - Vector2(3, 16), Vector2(6, 16)), Color(0.9, 0.86, 0.75))
	draw_texture_rect(VFX.T.glow, Rect2(cp - Vector2(24, 44), Vector2(48, 48)), false, Color(2.0, 1.2, 0.5, 0.6))
	draw_circle(cp + Vector2(0, -20), 3.0 * f, Color(3.0, 2.2, 0.9))


func _draw_anvil() -> void:
	var pulse := 0.8 + 0.2 * sin(_t * 2.3)
	draw_texture_rect(VFX.T.glow, Rect2(Vector2(-90, -50), Vector2(180, 100)), false, Color(1.8, 0.7, 0.25, 0.55 * pulse))
	# stone block
	var top := []
	for p in [[-0.45, -0.3], [0.45, -0.3], [0.45, 0.3], [-0.45, 0.3]]:
		top.append(p)
	var hb := 0.45
	var blk_top := PackedVector2Array()
	var blk_bot := PackedVector2Array()
	for p in top:
		blk_top.append(_ground_pt(p[0], p[1], hb))
		blk_bot.append(_ground_pt(p[0], p[1], 0.0))
	_ink_poly(Geometry2D.convex_hull(blk_top + blk_bot), Color(0.13, 0.16, 0.15))
	_ink_poly(blk_top, Color(0.2, 0.24, 0.22), Color(0.02, 0.02, 0.03), 1.5)
	# coals glowing in a slot in the block
	draw_line(_ground_pt(-0.3, 0.31, 0.2), _ground_pt(0.3, 0.31, 0.2), Color(3.0, 1.2, 0.3) * pulse, 5.0, true)
	# iron anvil: waist, face, horn
	var ia := PackedVector2Array()
	for p in [[-0.25, -0.12], [0.2, -0.12], [0.2, 0.12], [-0.25, 0.12]]:
		ia.append(_ground_pt(p[0], p[1], hb + 0.3))
		ia.append(_ground_pt(p[0] * 0.6, p[1], hb))
	_ink_poly(Geometry2D.convex_hull(ia), Color(0.1, 0.1, 0.12))
	var face := PackedVector2Array([_ground_pt(-0.4, -0.16, 0.8), _ground_pt(0.3, -0.16, 0.8), _ground_pt(0.62, 0.0, 0.8),
		_ground_pt(0.3, 0.16, 0.8), _ground_pt(-0.4, 0.16, 0.8)])
	var face_lo := PackedVector2Array()
	for p in face:
		face_lo.append(p + Vector2(0, Iso.h(0.12)))
	_ink_poly(Geometry2D.convex_hull(face + face_lo), Color(0.14, 0.14, 0.17))
	_ink_poly(face, Color(0.3, 0.3, 0.34), Color(0.02, 0.02, 0.03), 1.5)
	# the glowing strip of a blade being worked
	draw_line(_ground_pt(-0.25, 0.0, 0.82), _ground_pt(0.2, 0.02, 0.82), Color(3.2, 1.6, 0.5) * pulse, 3.0, true)


func _draw_ferry() -> void:
	var rock := 0.04 * sin(_t * 1.1)
	var heave := 0.05 * sin(_t * 0.8)
	var L := 4.4
	var B := 1.35
	var hd := 0.42 + heave
	var n := 18
	var rim := PackedVector2Array()
	var wl := PackedVector2Array()
	for k in n:
		var ang := float(k) / n * TAU
		var a := cos(ang) * L * 0.5
		var s := sin(ang)
		var b := s * B * 0.5 * pow(maxf(0.0, 1.0 - pow(absf(cos(ang)), 3.0)), 0.6)
		rim.append(_ground_pt(a, b, hd + rock * s))
		wl.append(_ground_pt(a * 0.92, b * 0.85, 0.0))
	# green light of the lake on the hull, then the hull, the deck and the gold rail
	draw_texture_rect(VFX.T.glow, Rect2(Vector2(-200, -90), Vector2(400, 180)), false, Color(0.4, 1.4, 0.7, 0.35))
	_ink_poly(Geometry2D.convex_hull(rim + wl), Color(0.12, 0.08, 0.06), Color(0.02, 0.01, 0.01), 3.0)
	var deck := PackedVector2Array()
	for k in n:
		var p: Vector2 = rim[k]
		deck.append(p.lerp(_ground_pt(0.0, 0.0, hd), 0.12))
	draw_colored_polygon(deck, Color(0.26, 0.17, 0.11))
	# planks across the deck
	for k in range(-3, 4):
		var a := k * 0.5
		draw_line(_ground_pt(a, -B * 0.4, hd), _ground_pt(a, B * 0.4, hd), Color(0.14, 0.09, 0.06), 1.5, true)
	var r2 := rim.duplicate()
	r2.append(rim[0])
	draw_polyline(r2, Color(0.93, 0.74, 0.38), 2.0, true)
	# the curled prow at the far (+i) end with its lantern, and a pole at the stern
	var curl := PackedVector2Array()
	for k in 12:
		var u := float(k) / 11.0
		var a := L * 0.5 + 0.25 * sin(u * PI * 0.9)
		var h := hd + 1.3 * u - 0.35 * maxf(0.0, u - 0.7) / 0.3
		curl.append(_ground_pt(a - 0.3 * maxf(0.0, u - 0.75) / 0.25, 0.0, h))
	draw_polyline(curl, Color(0.02, 0.01, 0.01), 7.0, true)
	draw_polyline(curl, Color(0.93, 0.74, 0.38), 3.0, true)
	var lp := _ground_pt(L * 0.5 + 0.2, 0.0, hd + 1.05)
	var f := 1.0 + 0.15 * sin(_t * 11.0)
	draw_texture_rect(VFX.T.glow, Rect2(lp - Vector2(40, 40), Vector2(80, 80)), false, Color(0.5, 1.6, 0.7, 0.8))
	draw_circle(lp, 6.0 * f, Color(1.2, 3.2, 1.6))
	draw_line(_ground_pt(-L * 0.42, 0.1, hd), _ground_pt(-L * 0.55, 0.35, hd + 2.4), Color(0.02, 0.01, 0.01), 5.0, true)
	draw_line(_ground_pt(-L * 0.42, 0.1, hd), _ground_pt(-L * 0.55, 0.35, hd + 2.4), Color(0.35, 0.24, 0.15), 2.5, true)
