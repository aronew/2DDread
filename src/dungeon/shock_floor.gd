class_name ShockFloor
extends Node2D
## Environmental hazard: grid plates cycle idle -> warning flicker -> active
## arcs. Alternating rows fire out of phase so there is always a safe beat to
## dash through. Hurts enemies too.

const IDLE := 1.6
const WARN := 0.7
const ACTIVE := 0.8

var cells: Array = []
var groups := {}   # row -> phase offset
var _t := 0.0
var _tick := 0.0


func setup(cells_: Array) -> void:
	cells = cells_
	for c in cells:
		if not groups.has(c.y):
			groups[c.y] = float(groups.size()) * (IDLE + WARN + ACTIVE) * 0.5
	material = VFX.add_mat
	z_index = -10


func _phase(c: Vector2i) -> int:
	var cycle := IDLE + WARN + ACTIVE
	var t := fposmod(_t + groups[c.y], cycle)
	if t < IDLE:
		return 0
	if t < IDLE + WARN:
		return 1
	return 2


func _process(dt: float) -> void:
	_t += dt
	_tick -= dt
	if _tick <= 0.0:
		_tick = 0.25
		for c in cells:
			if _phase(c) != 2:
				continue
			var g := Iso.cell_center(c)
			if randf() < 0.5:
				var a := Iso.to_screen(g + Vector2(randf_range(-60, 60), randf_range(-60, 60)))
				VFX.lightning(a, a + Vector2(randf_range(-60, 60), -randf_range(20, 70)), Color(1.2, 1.6, 4.0), 2.5, 0.12, 1.6)
			var pl = Game.player
			if pl and pl.alive and Iso.cell_of(pl.gpos) == c:
				var d := DamageInfo.make(9.0, DamageInfo.Type.SHOCK, self)
				d.is_dot = true
				pl.take_damage(d)
			for e in Game.grid.query(g, Iso.TILE_GPX * 0.7):
				if Iso.cell_of(e.gpos) == c:
					var d := DamageInfo.make(14.0, DamageInfo.Type.SHOCK, self)
					d.is_dot = true
					d.status = {&"shock": 0.5}
					e.take_damage(d)
	queue_redraw()


func _draw() -> void:
	for c in cells:
		var ph := _phase(c)
		var col := Color(0.35, 0.6, 1.0)
		var a := 0.06
		if ph == 1:
			a = 0.12 + 0.25 * (1.0 if fmod(_t, 0.16) < 0.08 else 0.0)
		elif ph == 2:
			a = 0.45 + 0.15 * sin(_t * 40.0)
		var pts := PackedVector2Array()
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			pts.append(Iso.to_screen(Iso.tile_to_ground(Vector2(c) + Vector2(0.06, 0.06) + corner * 0.88)))
		draw_colored_polygon(pts, col * Color(2.0, 2.0, 2.0, a))
		pts.append(pts[0])
		draw_polyline(pts, col * Color(2.5, 2.5, 2.5, minf(1.0, a * 2.0)), 2.0)
