class_name WhipVisual
extends Node2D
## Draws Fury's Lash: a tapered leather rope with a dark ink outline, running
## from the gunslinger's hand to the tip, with an ember glow on the tip.
## The rope is procedural (two Line2Ds, no sprite sheet), so its reach can
## change on every crack. It is only updated while the whip is out.
## Lives under the Player node: every point is in player-local screen space.

const N := 20
const INK := Color(0.045, 0.02, 0.03)
const TIP_GLOW := Color(2.4, 1.45, 0.5)

var ink: Line2D
var rope: Line2D
var tip_glow: Sprite2D


func _ready() -> void:
	z_index = 2   # above the entity layer so the rope never hides behind bodies
	ink = _line(11.0)
	ink.default_color = INK
	rope = _line(5.5)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 0.86, 1.0])
	g.colors = PackedColorArray([Color(0.42, 0.2, 0.1), Color(0.66, 0.34, 0.15), Color(1.2, 0.62, 0.2), TIP_GLOW])
	rope.gradient = g
	tip_glow = Sprite2D.new()
	tip_glow.texture = VFX.T.core
	tip_glow.material = VFX.add_mat
	tip_glow.scale = Vector2(0.32, 0.32)
	add_child(tip_glow)
	visible = false


func _line(w: float) -> Line2D:
	var l := Line2D.new()
	l.width = w
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(0.7, 0.62))
	c.add_point(Vector2(1.0, 0.32))
	l.width_curve = c
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.material = VFX.unshaded_mat
	add_child(l)
	return l


func show_rope(pts: PackedVector2Array, glow: float) -> void:
	visible = true
	ink.points = pts
	rope.points = pts
	tip_glow.position = pts[pts.size() - 1]
	tip_glow.modulate = TIP_GLOW * Color(1, 1, 1, clampf(glow, 0.0, 1.0))


func hide_rope() -> void:
	visible = false


## Rope from a to b (local screen px). `extend` reels the tip in/out along the
## line, `wave` is a sideways S-curve travelling down the rope (unrolling
## loop), `sag` bows the middle (negative = arched overhead, positive = slack).
static func rope_points(a: Vector2, b: Vector2, extend: float, wave: float, wave_phase: float, sag: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var d := (b - a) * extend
	var perp := d.orthogonal().normalized() if d.length() > 1.0 else Vector2.UP
	for i in N:
		var u := float(i) / (N - 1)
		var env := sin(u * PI)
		var p := a + d * u
		p += perp * wave * sin(u * TAU * 1.25 - wave_phase) * env * (0.35 + 0.65 * u)
		p.y += sag * env
		pts.append(p)
	return pts


## Spinning whirl: the rope curls out from the hand to a tip on a circle.
static func whirl_points(center_g: Vector2, origin: Vector2, angle: float, radius_g: float, hand: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in N:
		var u := float(i) / (N - 1)
		var a := angle - (1.0 - u) * 1.1
		var g := center_g + Vector2.from_angle(a) * radius_g * u
		var p := Iso.lift(g, lerpf(1.2, 0.85, u)) - origin
		pts.append(hand.lerp(p, smoothstep(0.0, 0.25, u)))
	return pts
