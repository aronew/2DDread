class_name LavaShore
extends Node2D
## The cliffs of the Phlegethon's island rooms until they are painted: every floor edge that
## drops into the lava toward the camera (+i and +j faces) gets a ragged basalt face, black
## at the top and glowing orange where it meets the lava; every shore edge gets a hot seam
## along the waterline, warm lights here and there, and embers rise off the lava near the
## camera. Drawn under the floor (z -21), so floor tiles in front cover the faces.

const FACE_H := 1.5
const TOP := Color(0.12, 0.08, 0.1)
const FOOT := Color(1.8, 0.5, 0.08)
const SEAM := Color(2.2, 0.8, 0.15, 0.9)

var _faces: Array = []     # [a, b, h_a, h_b] in screen space (top edge points and depths)
var _seams: Array = []     # [a, b]
var _shore_g: Array = []   # ground points on the shore, for embers
var _ember_t := 0.0


func setup(d: Dungeon) -> void:
	z_index = -21
	var n := 0
	for c in d.floor_kind:
		if d.bridges.has(c):
			continue
		for e in [[Vector2i(0, 1), Vector2(0, 1), Vector2(1, 1)], [Vector2i(1, 0), Vector2(1, 0), Vector2(1, 1)],
				[Vector2i(0, -1), Vector2(0, 0), Vector2(1, 0)], [Vector2i(-1, 0), Vector2(0, 0), Vector2(0, 1)]]:
			var nb: Vector2i = c + e[0]
			if d.floor_kind.has(nb):
				continue
			var ga := Iso.tile_to_ground(Vector2(c) + e[1])
			var gb := Iso.tile_to_ground(Vector2(c) + e[2])
			var front: bool = e[0].x + e[0].y > 0
			if front:
				_faces.append([ga, gb, _depth(Vector2(c) + e[1]), _depth(Vector2(c) + e[2])])
			_seams.append([Iso.to_screen(ga), Iso.to_screen(gb), front])
			_shore_g.append((ga + gb) * 0.5)
			n += 1
			if n % 6 == 0:
				d.add_light(Iso.to_screen((ga + gb) * 0.5) + Vector2(0, 30), Color(1.0, 0.45, 0.15), 1.0, 3.2, 70.0, 1)
	queue_redraw()


## Ragged cliffs: the face depth varies along the shore (the same at a shared corner).
func _depth(t: Vector2) -> float:
	return FACE_H * (0.75 + 0.5 * fposmod(sin(t.x * 12.9898 + t.y * 78.233) * 43758.5453, 1.0))


func _process(dt: float) -> void:
	_ember_t -= dt
	if _ember_t > 0.0 or _shore_g.is_empty() or Game.camera == null:
		return
	_ember_t = 0.12
	var cam: Vector2 = Game.camera.global_position
	for k in 6:
		var g: Vector2 = _shore_g[randi() % _shore_g.size()]
		var s := Iso.to_screen(g)
		if s.distance_to(cam) < 1100.0:
			VFX.emit("embers", s + Vector2(0, 40), -PI / 2, Color(2.4, 0.9, 0.3), 0.05)
			return


func _draw() -> void:
	for f in _faces:
		var a: Vector2 = f[0]
		var b: Vector2 = f[1]
		var pts := PackedVector2Array([Iso.to_screen(a), Iso.to_screen(b), Iso.lift(b, -f[3]), Iso.lift(a, -f[2])])
		draw_polygon(pts, PackedColorArray([TOP, TOP, FOOT, FOOT]))
		draw_line(pts[0], pts[3], Color(0.02, 0.01, 0.02), 2.0, true)
		draw_line(pts[1], pts[2], Color(0.02, 0.01, 0.02), 2.0, true)
	for s in _seams:
		if not s[2]:
			# the back shores: a dark lip of cooled rock and a hot seam where it meets the lava
			draw_line(s[0], s[1], Color(0.05, 0.02, 0.02), 9.0, true)
			draw_line(s[0] + Vector2(0, 5), s[1] + Vector2(0, 5), SEAM, 2.5, true)
	for f in _faces:
		draw_line(Iso.lift(f[0], -f[2]), Iso.lift(f[1], -f[3]), SEAM, 3.0, true)
