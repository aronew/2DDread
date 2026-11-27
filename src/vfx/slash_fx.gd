class_name SlashFX
extends Node2D
## A sword slash: a crescent of hellfire swept around the player on the ground plane at
## blade height (Hades-style). It reveals from the start angle to the end angle over
## `sweep` seconds with a white-hot leading edge and the blade itself at the front, then
## burns out over `fade` seconds. Additive; drawn in the FX layer. Short-lived, so it
## simply redraws every frame while alive.

var center := Vector2.ZERO     # ground
var height := 1.0              # metres above the ground
var a0 := 0.0                  # ground angles (radians), swept from a0 to a1
var a1 := 1.0
var r_in := 0.0                # ground px
var r_out := 0.0
var sweep := 0.07
var fade := 0.14
var core := Color(1.9, 1.15, 0.55)
var outer := Color(1.35, 0.32, 0.07)
var _t := 0.0

const SEG := 22


static func spawn(g: Vector2, h_m: float, from_a: float, to_a: float, rin_m: float, rout_m: float,
		sweep_t := 0.07, fade_t := 0.14, core_c := Color(1.9, 1.15, 0.55), outer_c := Color(1.35, 0.32, 0.07)) -> SlashFX:
	var s := SlashFX.new()
	s.center = g
	s.height = h_m
	s.a0 = from_a
	s.a1 = to_a
	s.r_in = Iso.m(rin_m)
	s.r_out = Iso.m(rout_m)
	s.sweep = sweep_t
	s.fade = fade_t
	s.core = core_c
	s.outer = outer_c
	s.material = VFX.add_mat
	VFX.fx.add_child(s)
	return s


func _process(dt: float) -> void:
	_t += dt
	if _t >= sweep + fade:
		queue_free()
		return
	queue_redraw()


func _pt(a: float, r: float) -> Vector2:
	return Iso.lift(center + Vector2.from_angle(a) * r, height)


func _draw() -> void:
	var k := minf(1.0, _t / sweep)                         # how far the sweep has got
	var life := 1.0 - clampf((_t - sweep) / fade, 0.0, 1.0)  # burn-out after the sweep
	var lead := lerpf(a0, a1, 1.0 - (1.0 - k) * (1.0 - k))
	var n := maxi(2, int(SEG * absf(lead - a0) / maxf(0.01, absf(a1 - a0))) + 2)
	var mid := (r_in + r_out) * 0.5
	var outer_pts := PackedVector2Array()
	var inner_pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in n:
		var u := float(i) / (n - 1)          # 0 at the trailing end, 1 at the leading edge
		var a := lerpf(a0, lead, u)
		var taper := 0.08 + 0.92 * sin(clampf(u, 0.0, 1.0) * PI * 0.5)   # thin tail, full at the front
		var half := (r_out - r_in) * 0.5 * taper
		outer_pts.append(_pt(a, mid + half))
		inner_pts.append(_pt(a, mid - half * 0.6))
		cols.append(outer.lerp(core, u * u) * Color(1, 1, 1, (0.25 + 0.75 * u) * life))
	# a strip of quads (one big polygon fails to triangulate where the tail pinches)
	for i in n - 1:
		var q := PackedVector2Array([outer_pts[i], outer_pts[i + 1], inner_pts[i + 1], inner_pts[i]])
		var qc := PackedColorArray([cols[i], cols[i + 1], cols[i + 1] * Color(1, 1, 1, 0.55), cols[i] * Color(1, 1, 1, 0.55)])
		draw_primitive(q, qc, PackedVector2Array())
	# white-hot rim along the outer edge
	var rim := PackedVector2Array()
	for i in n:
		rim.append(outer_pts[i])
	if rim.size() >= 2:
		draw_polyline(rim, core * Color(1.2, 1.1, 1.0, 0.85 * life), 3.0, true)
	# the blade itself at the leading edge while the sweep is on
	if k < 1.0 or _t < sweep + 0.03:
		var hilt := _pt(lead, Iso.m(0.35))
		var tip := _pt(lead, r_out * 1.02)
		draw_line(hilt, tip, Color(2.2, 1.9, 1.5), 4.0, true)
