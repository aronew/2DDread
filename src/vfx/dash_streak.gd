class_name DashStreak
extends Line2D
## The golden streak of light a dash leaves behind the gunslinger: points are fed while
## dashing and for a moment after, and each fades out LIFE seconds after it was laid.
## Lives in the additive FX layer; rebuilt with the level.

const LIFE := 0.3
const TAIL := 0.05     # keep laying points this long after the dash ends

var _pts: Array = []   # [screen point, age]
var _after := 0.0


func _ready() -> void:
	material = VFX.add_mat
	width = 40.0
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(1.0, 1.0))
	width_curve = c
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1.8, 0.7, 0.2, 0.0), Color(2.6, 1.7, 0.7, 0.7), Color(3.4, 3.0, 2.2, 1.0)])
	gradient = g


func feed(p: Vector2, dashing: bool) -> void:
	var dt := get_process_delta_time()
	if dashing:
		_after = TAIL
	else:
		_after -= dt
	if _after > 0.0:
		_pts.append([p, 0.0])
	for q in _pts:
		q[1] += dt
	while not _pts.is_empty() and _pts[0][1] > LIFE:
		_pts.pop_front()
	var line := PackedVector2Array()
	for q in _pts:
		line.append(q[0])
	points = line if line.size() >= 2 else PackedVector2Array()
	modulate.a = 1.0 if _after > 0.0 else clampf(1.0 - (_pts[0][1] / LIFE if not _pts.is_empty() else 1.0), 0.0, 1.0)
