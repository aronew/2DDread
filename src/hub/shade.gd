class_name Shade
extends Node2D
## A figure in the hub, drawn procedurally until there is painted art for them:
##   SOUL    a lingering soul: a translucent hooded wraith, green-white, floating and swaying;
##   SMITH   the Forge's keeper: the same, warmed orange by the coals;
##   CHARON  the ferryman turned barkeep: tall, solid black robe with gold trim, coin eyes,
##           a soul-fire lantern at his side.
## say() shows a speech line over their head for a few seconds.

enum { SOUL, SMITH, CHARON }

var npc_id := ""
var gpos := Vector2.ZERO
var lines: Array = []
var look := SOUL
var _t := 0.0
var _phase := 0.0
var _bubble: Bubble


func setup(id: String, g: Vector2, lines_: Array, look_: int) -> void:
	npc_id = id
	gpos = g
	lines = lines_
	look = look_
	position = Iso.to_screen(g)
	_phase = randf() * TAU
	_t = randf() * 10.0


func _ready() -> void:
	_bubble = Bubble.new()
	_bubble.z_index = 45
	add_child(_bubble)
	if look != SOUL:
		var l := PointLight2D.new()
		l.texture = VFX.T.light
		l.color = Color(0.45, 1.0, 0.55) if look == CHARON else Color(1.0, 0.55, 0.25)
		l.energy = 1.4
		l.texture_scale = 1.6
		l.scale = Vector2(1, Iso.K)
		l.height = 60.0
		l.position = Vector2(Iso.m(0.5) if look == CHARON else 0.0, -Iso.h(1.1))
		add_child(l)


func say(text: String) -> void:
	_bubble.show_text(text)


func _process(dt: float) -> void:
	_t += dt
	queue_redraw()


func _p(x_m: float, h_m: float) -> Vector2:
	return Vector2(Iso.m(x_m), -Iso.h(h_m))


func _draw() -> void:
	var tall := 2.35 if look == CHARON else 1.75
	var bob := 0.0 if look == CHARON else 0.18 + 0.07 * sin(_t * 1.7 + _phase)
	var sway := 0.0 if look == CHARON else 0.06 * sin(_t * 0.6 + _phase)
	var body: Color
	var rim: Color
	var eyes: Color
	match look:
		CHARON:
			body = Color(0.05, 0.05, 0.07, 0.97)
			rim = Color(0.93, 0.74, 0.38, 1.0)
			eyes = Color(2.6, 2.0, 0.8)
		SMITH:
			body = Color(1.0, 0.58, 0.3, 0.5)
			rim = Color(1.6, 0.9, 0.5, 0.9)
			eyes = Color(3.0, 1.6, 0.6)
		_:
			body = Color(0.5, 1.0, 0.85, 0.42)
			rim = Color(0.9, 1.6, 1.4, 0.8)
			eyes = Color(1.6, 3.0, 2.4)
	# a pool of light on the floor under them
	var gr := Iso.m(0.8 if look == CHARON else 0.6)
	draw_texture_rect(VFX.T.glow, Rect2(Vector2(-gr, -gr * Iso.K), Vector2(gr, gr * Iso.K) * 2.0), false,
		Color(body.r, body.g, body.b, 0.35 if look != CHARON else 0.0))
	# the robe: hood, shoulders, a wide skirt dissolving into wisps (Charon's is solid to the floor)
	var w := 0.36 if look == CHARON else 0.3
	var pts := PackedVector2Array()
	pts.append(_p(sway, tall + bob))
	pts.append(_p(sway + w * 0.55, tall - 0.18 + bob))
	pts.append(_p(sway * 0.7 + w, tall - 0.5 + bob))
	pts.append(_p(sway * 0.4 + w * 1.15, 0.9 + bob))
	var hem := 6
	for k in hem + 1:
		var u := 1.0 - float(k) / hem
		var x := (u * 2.0 - 1.0) * w * 1.2
		var y := bob + (0.0 if look == CHARON else 0.12 + 0.12 * sin(_t * 3.0 + k * 1.7 + _phase)) - (0.08 if k % 2 == 1 else 0.0)
		pts.append(_p(x, maxf(0.0, y)))
	pts.append(_p(-sway * 0.4 - w * 1.15, 0.9 + bob))
	pts.append(_p(sway * 0.7 - w, tall - 0.5 + bob))
	pts.append(_p(sway - w * 0.55, tall - 0.18 + bob))
	draw_colored_polygon(pts, body)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0.02, 0.02, 0.03, 0.9 if look == CHARON else 0.55), 3.0, true)
	draw_polyline(outline, rim, 1.2, true)
	if look == CHARON:
		# gold trim down the front of the robe
		draw_line(_p(0.0, tall - 0.35), _p(0.0, 0.05), rim, 2.0, true)
		draw_line(_p(-w * 1.1, 0.12), _p(w * 1.1, 0.12), rim, 2.0, true)
	# the hood's dark hollow and two eyes in it
	var face := _p(sway, tall - 0.32 + bob)
	var fr := Iso.m(0.13)
	draw_colored_polygon(PackedVector2Array([face + Vector2(0, -fr * 1.2), face + Vector2(fr, 0), face + Vector2(0, fr * 1.1), face + Vector2(-fr, 0)]),
		Color(0.0, 0.0, 0.0, 0.9))
	var blink := 1.0 if fmod(_t + _phase, 4.0) > 0.12 else 0.1
	draw_circle(face + Vector2(-fr * 0.42, 0), 2.6, eyes * Color(1, 1, 1, blink))
	draw_circle(face + Vector2(fr * 0.42, 0), 2.6, eyes * Color(1, 1, 1, blink))
	if look == CHARON:
		# the soul-fire lantern hanging from his hand
		var lp := _p(0.52, 1.05)
		draw_line(_p(0.32, 1.25), lp + Vector2(0, -12), Color(0.1, 0.08, 0.06), 2.0, true)
		draw_texture_rect(VFX.T.glow, Rect2(lp - Vector2(34, 34), Vector2(68, 68)), false, Color(0.5, 1.6, 0.7, 0.7))
		draw_rect(Rect2(lp - Vector2(7, 11), Vector2(14, 20)), Color(0.08, 0.06, 0.04), false, 2.0)
		var f := 1.0 + 0.15 * sin(_t * 13.0)
		draw_circle(lp, 5.0 * f, Color(1.2, 3.2, 1.6))


## A speech line over a figure's head, fading after a few seconds.
class Bubble extends Node2D:
	const LIFE := 5.0
	var text := ""
	var _t := 0.0
	var _font: Font

	func _ready() -> void:
		var fv := FontVariation.new()
		fv.base_font = load("res://assets/fonts/Cinzel.ttf")
		fv.variation_opentype = {"weight": 600}
		_font = fv

	func show_text(t: String) -> void:
		text = t
		_t = LIFE
		queue_redraw()

	func _process(dt: float) -> void:
		if _t > 0.0:
			_t -= dt
			queue_redraw()

	func _draw() -> void:
		if _t <= 0.0 or text == "":
			return
		var a := clampf(_t / 0.6, 0.0, 1.0) * clampf((LIFE - _t) / 0.15, 0.0, 1.0)
		var width := 380.0
		var size := 17
		var lines_h := _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, size).y
		var top := -Iso.h(2.6) - lines_h - 10.0
		var r := Rect2(Vector2(-width * 0.5 - 12, top - 8), Vector2(width + 24, lines_h + 18))
		draw_rect(r, Color(0.03, 0.03, 0.04, 0.82 * a))
		draw_rect(r, Color(0.93, 0.74, 0.38, 0.75 * a), false, 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(-8, r.end.y), Vector2(8, r.end.y), Vector2(0, r.end.y + 10)]), Color(0.03, 0.03, 0.04, 0.82 * a))
		draw_multiline_string_outline(_font, Vector2(-width * 0.5, top + size), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, -1, 3, Color(0, 0, 0, a))
		draw_multiline_string(_font, Vector2(-width * 0.5, top + size), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, -1, Color(0.95, 0.92, 0.85, a))
