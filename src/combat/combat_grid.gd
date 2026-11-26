class_name CombatGrid
extends RefCounted
## Uniform spatial hash over enemies in ground space. Rebuilt once per frame;
## projectile, explosion and AI separation queries read from it.

const CELL := 160.0

var _cells := {}


func rebuild(enemies: Array) -> void:
	_cells.clear()
	for e in enemies:
		if not e.alive:
			continue
		var k := Vector2i(floori(e.gpos.x / CELL), floori(e.gpos.y / CELL))
		if _cells.has(k):
			_cells[k].append(e)
		else:
			_cells[k] = [e]


## Enemies whose hit circle may overlap the given circle.
func query(center: Vector2, radius: float) -> Array:
	var out: Array = []
	var r := radius + 120.0  # max enemy radius margin
	var x0 := floori((center.x - r) / CELL)
	var x1 := floori((center.x + r) / CELL)
	var y0 := floori((center.y - r) / CELL)
	var y1 := floori((center.y + r) / CELL)
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var k := Vector2i(x, y)
			if _cells.has(k):
				for e in _cells[k]:
					if e.alive and e.gpos.distance_to(center) <= radius + e.radius:
						out.append(e)
	return out


## Closest enemy along segment a->b (ground) within `thickness`, excluding `skip`.
## Returns {enemy, t} or {} if none.
func segment_first(a: Vector2, b: Vector2, thickness: float, skip: Dictionary = {}) -> Dictionary:
	var mid := (a + b) * 0.5
	var half := a.distance_to(b) * 0.5
	var best := {}
	var best_t := INF
	var d := b - a
	var len2 := d.length_squared()
	for e in query(mid, half + thickness):
		if skip.has(e.get_instance_id()):
			continue
		var t := 0.0
		if len2 > 0.0001:
			t = clampf((e.gpos - a).dot(d) / len2, 0.0, 1.0)
		var p := a + d * t
		var rr: float = e.radius + thickness
		if p.distance_squared_to(e.gpos) <= rr * rr and t < best_t:
			best_t = t
			best = {"enemy": e, "t": t}
	return best
