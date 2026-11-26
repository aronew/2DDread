class_name Dungeon
extends Node2D
## Builds a dungeon from an ASCII layout and answers spatial queries:
## grid collision for actors, DDA raycasts for shots/LOS, flow-field pathing.
## Visuals: chunked normal-mapped floor, y-sorted wall blocks (fade when they
## occlude the player), contact AO and static light sources.

const FLOOR_SHEET := "res://assets/sprites/env/floor_tiles"
const WALL_SHEET := "res://assets/sprites/env/wall_blocks"
const LOW_SHEET := "res://assets/sprites/env/low_blocks"

enum Block { NONE, WALL, LOW, DOOR }

const FLOOR_CHAR := {"g": 2, "h": 3, "l": 4, "v": 5, "w": 6, ",": 7, "o": 8, "c": 9, "r": 10, "z": 2, ":": 0}
const WALL_CHAR := {"P": 0, "W": 3, "M": 2, "I": 4, "R": 5, "K": 6, "O": 7, "Q": 8}
const LOW_CHAR := {"=": 0, "x": 1, "|": 2}
const PROP_CHAR := {"b": "barrel", "k": "crate", "n": "canisters", "C": "chest", "e": "eggs",
	"*": "crystals", "p": "pylon", "t": "cryotube"}
const NEIGH8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]
const CHUNK := 4  # small chunks keep per-item 2D light counts under the renderer limit

var floor_kind := {}      # Vector2i -> floor tile index
var block := {}           # Vector2i -> Block
var block_kind := {}      # Vector2i -> sheet frame index
var block_nodes := {}     # Vector2i -> Node2D
var props_by_cell := {}   # Vector2i -> Array of Prop
var props: Array = []
var door_cells: Array = []
var shock_cells: Array = []
var breakables := {}      # Vector2i -> hp
var start_cell := Vector2i.ZERO
var exit_cell := Vector2i(-1, -1)
var flow := {}
var visited := {}         # cells revealed for the minimap

var entities: Node2D
var decals: Node2D
var _flow_target := Vector2i(1 << 20, 1 << 20)
var _faded := {}
var _ao: Node2D
var lights_by_tier: Array = [[], [], []]   # 0 key, 1 accent, 2 fill — graphics presets toggle tiers
var _last_visit_cell := Vector2i(1 << 20, 0)
var _floor_root: Node2D
var _light_tex: Texture2D
var _add_mat: CanvasItemMaterial


func build(layout: Array, entities_: Node2D, decals_: Node2D) -> void:
	entities = entities_
	decals = decals_
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_light_tex = make_light_texture()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var pending_props: Array = []
	for j in layout.size():
		var row: String = layout[j]
		for i in row.length():
			var ch := row[i]
			if ch == " ":
				continue
			var c := Vector2i(i, j)
			floor_kind[c] = _auto_floor(rng)
			if FLOOR_CHAR.has(ch):
				floor_kind[c] = FLOOR_CHAR[ch]
			if WALL_CHAR.has(ch):
				block[c] = Block.WALL
				var k: int = WALL_CHAR[ch]
				if ch == "P" and rng.randf() < 0.35:
					k = 1
				block_kind[c] = k
				if ch == "K":
					breakables[c] = 180.0
			elif LOW_CHAR.has(ch):
				block[c] = Block.LOW
				block_kind[c] = LOW_CHAR[ch]
			elif PROP_CHAR.has(ch):
				pending_props.append([c, PROP_CHAR[ch]])
			match ch:
				"S":
					start_cell = c
				"D":
					door_cells.append(c)
				"X":
					exit_cell = c
				"z":
					shock_cells.append(c)
	_build_floor()
	_build_blocks()
	_build_ao()
	_build_lights()
	for pp in pending_props:
		add_prop(pp[0], pp[1])


func _auto_floor(rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	if r < 0.46:
		return 0
	if r < 0.84:
		return 1
	if r < 0.9:
		return 6
	if r < 0.94:
		return 9
	if r < 0.97:
		return 5
	return 3


# ------------------------------------------------------------------ queries

func is_floor(c: Vector2i) -> bool:
	return floor_kind.has(c) and block.get(c, Block.NONE) == Block.NONE


func walk_blocked(c: Vector2i, flying := false) -> bool:
	if not floor_kind.has(c):
		return not flying
	var b: int = block.get(c, Block.NONE)
	if b == Block.NONE:
		return false
	if b == Block.LOW and flying:
		return false
	return true


func shot_blocked(c: Vector2i) -> bool:
	var b: int = block.get(c, Block.NONE)
	return b == Block.WALL or b == Block.DOOR


## Moves a circle through the grid with sub-stepping; returns the new ground position.
func move_circle(g: Vector2, motion: Vector2, r: float, flying := false) -> Vector2:
	var steps := clampi(int(ceil(motion.length() / maxf(r * 0.7, 8.0))), 1, 10)
	var d := motion / steps
	var p := g
	for _s in steps:
		p += d
		p = resolve(p, r, flying)
	return p


func resolve(g: Vector2, r: float, flying := false) -> Vector2:
	var t := Iso.ground_to_tile(g)
	var rt := r / Iso.TILE_GPX
	for _iter in 2:
		var x0 := floori(t.x - rt)
		var x1 := floori(t.x + rt)
		var y0 := floori(t.y - rt)
		var y1 := floori(t.y + rt)
		for cx in range(x0, x1 + 1):
			for cy in range(y0, y1 + 1):
				if not walk_blocked(Vector2i(cx, cy), flying):
					continue
				var closest := Vector2(clampf(t.x, cx, cx + 1), clampf(t.y, cy, cy + 1))
				var diff := t - closest
				var dist := diff.length()
				if dist >= rt:
					continue
				if dist > 0.00001:
					t += diff / dist * (rt - dist)
				else:
					# centre inside the block: push out along the shallowest axis
					var pen := [t.x - cx, cx + 1 - t.x, t.y - cy, cy + 1 - t.y]
					var m: int = pen.find(pen.min())
					match m:
						0: t.x = cx - rt
						1: t.x = cx + 1 + rt
						2: t.y = cy - rt
						3: t.y = cy + 1 + rt
	var out := Iso.tile_to_ground(t)
	# props
	var c := Iso.cell_of(out)
	for ox in range(-1, 2):
		for oy in range(-1, 2):
			var arr = props_by_cell.get(c + Vector2i(ox, oy))
			if arr == null:
				continue
			for p in arr:
				if not p.blocks_movement or not p.alive:
					continue
				var dv: Vector2 = out - p.gpos
				var rr: float = r + p.radius
				var dl := dv.length()
				if dl < rr:
					out = p.gpos + (dv / maxf(dl, 0.001)) * rr if dl > 0.001 else p.gpos + Vector2(rr, 0)
	return out


## DDA through tile space. mode: "shot" (walls/doors) or "walk" (anything blocking movement).
func raycast(a: Vector2, b: Vector2, mode := "shot") -> Dictionary:
	var ta := Iso.ground_to_tile(a)
	var tb := Iso.ground_to_tile(b)
	var d := tb - ta
	var cell := Vector2i(floori(ta.x), floori(ta.y))
	if _ray_blocks(cell, mode):
		return {"hit": true, "t": 0.0, "point": a, "normal": -(b - a).normalized(), "cell": cell}
	var sx := 1 if d.x > 0 else -1
	var sy := 1 if d.y > 0 else -1
	var tdx := INF if absf(d.x) < 1e-9 else absf(1.0 / d.x)
	var tdy := INF if absf(d.y) < 1e-9 else absf(1.0 / d.y)
	var tmx := INF
	if absf(d.x) >= 1e-9:
		tmx = ((cell.x + 1 - ta.x) if d.x > 0 else (ta.x - cell.x)) * tdx
	var tmy := INF
	if absf(d.y) >= 1e-9:
		tmy = ((cell.y + 1 - ta.y) if d.y > 0 else (ta.y - cell.y)) * tdy
	var t := 0.0
	var axis := 0
	for _i in 512:
		if tmx < tmy:
			t = tmx
			tmx += tdx
			cell.x += sx
			axis = 0
		else:
			t = tmy
			tmy += tdy
			cell.y += sy
			axis = 1
		if t > 1.0:
			break
		if _ray_blocks(cell, mode):
			var nt := Vector2(-sx, 0) if axis == 0 else Vector2(0, -sy)
			return {"hit": true, "t": t, "point": a + (b - a) * t,
				"normal": Iso.tile_to_ground(nt).normalized(), "cell": cell}
	return {"hit": false}


func _ray_blocks(c: Vector2i, mode: String) -> bool:
	if mode == "walk":
		return walk_blocked(c)
	return shot_blocked(c)


func has_los(a: Vector2, b: Vector2) -> bool:
	return not raycast(a, b, "shot").hit


## Props whose circle intersects segment a->b; returns {prop, t} of the closest.
func segment_prop(a: Vector2, b: Vector2, thickness: float) -> Dictionary:
	var best := {}
	var best_t := INF
	var ca := Iso.cell_of(a)
	var cb := Iso.cell_of(b)
	var x0 := mini(ca.x, cb.x) - 1
	var x1 := maxi(ca.x, cb.x) + 1
	var y0 := mini(ca.y, cb.y) - 1
	var y1 := maxi(ca.y, cb.y) + 1
	if (x1 - x0) * (y1 - y0) > 64:
		return best
	var d := b - a
	var len2 := maxf(d.length_squared(), 0.0001)
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var arr = props_by_cell.get(Vector2i(x, y))
			if arr == null:
				continue
			for p in arr:
				if not p.alive or not p.blocks_shots:
					continue
				var t := clampf((p.gpos - a).dot(d) / len2, 0.0, 1.0)
				var rr: float = p.radius + thickness
				if (a + d * t).distance_squared_to(p.gpos) <= rr * rr and t < best_t:
					best_t = t
					best = {"prop": p, "t": t}
	return best


## Spawn point on a ring around `center` (surround pressure), falling back to any floor in the room.
func ring_floor_in(rect: Rect2i, center: Vector2, r_min: float, r_max: float, angle: float, rng: RandomNumberGenerator) -> Vector2:
	for i in 24:
		var a := angle + rng.randf_range(-0.6, 0.6) * (1.0 + i * 0.15)
		var g := center + Vector2.from_angle(a) * rng.randf_range(r_min, r_max)
		var c := Iso.cell_of(g)
		if rect.has_point(c) and is_floor(c) and not props_by_cell.has(c) and not shock_cells.has(c) \
				and has_los(center, g):
			return g
	return random_floor_in(rect, center, r_min, rng, false)


func random_floor_in(rect: Rect2i, avoid_g: Vector2, min_dist: float, rng: RandomNumberGenerator, far := false) -> Vector2:
	var best := Vector2.INF
	var best_d := -1.0
	for _i in 40:
		var c := Vector2i(rng.randi_range(rect.position.x, rect.end.x - 1), rng.randi_range(rect.position.y, rect.end.y - 1))
		if not is_floor(c) or props_by_cell.has(c) or shock_cells.has(c):
			continue
		var g := Iso.cell_center(c) + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40))
		var dd := g.distance_to(avoid_g)
		if dd < min_dist:
			continue
		if not far:
			return g
		if dd > best_d:
			best_d = dd
			best = g
	if best == Vector2.INF:
		return Iso.cell_center(Vector2i(rect.get_center()))
	return best


# ------------------------------------------------------------------ flow field

func update_flow(target: Vector2i) -> void:
	if target == _flow_target:
		return
	_flow_target = target
	flow.clear()
	if walk_blocked(target):
		return
	var q: Array[Vector2i] = [target]
	flow[target] = 0
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		var d: int = flow[c]
		if d > 48:
			continue
		for o in NEIGH8:
			var n: Vector2i = c + o
			if flow.has(n) or walk_blocked(n):
				continue
			if o.x != 0 and o.y != 0 and (walk_blocked(Vector2i(c.x + o.x, c.y)) or walk_blocked(Vector2i(c.x, c.y + o.y))):
				continue
			flow[n] = d + 1
			q.append(n)


func invalidate_flow() -> void:
	_flow_target = Vector2i(1 << 20, 1 << 20)


## Ground-space direction toward the flow target from g (ZERO if unknown).
func flow_dir(g: Vector2) -> Vector2:
	var c := Iso.cell_of(g)
	if not flow.has(c):
		return Vector2.ZERO
	var best_c := c
	var best_d: int = flow[c]
	for o in NEIGH8:
		var n: Vector2i = c + o
		if flow.has(n) and flow[n] < best_d:
			if o.x != 0 and o.y != 0 and (not flow.has(Vector2i(c.x + o.x, c.y)) or not flow.has(Vector2i(c.x, c.y + o.y))):
				continue
			best_d = flow[n]
			best_c = n
	if best_c == c:
		return Vector2.ZERO
	return (Iso.cell_center(best_c) - g).normalized()


# ------------------------------------------------------------------ doors & breakables

func set_doors_locked(cells: Array, locked: bool) -> void:
	for c in cells:
		if locked:
			block[c] = Block.DOOR
		else:
			block.erase(c)
	invalidate_flow()


func damage_cell(c: Vector2i, amount: float) -> void:
	if not breakables.has(c):
		return
	breakables[c] -= amount
	var g := Iso.cell_center(c)
	VFX.debris(g, 1.6, 6)
	if breakables[c] <= 0.0:
		breakables.erase(c)
		block.erase(c)
		floor_kind[c] = 6
		if block_nodes.has(c):
			block_nodes[c].queue_free()
			block_nodes.erase(c)
		VFX.explosion(g, Iso.m(2.2), Color(1.0, 0.6, 0.25), false)
		VFX.debris(g, 2.5, 22)
		Audio.play("wall_break", g)
		Events.message.emit("HIDDEN PASSAGE REVEALED", Color(1.0, 0.75, 0.3))
		_build_ao()
		invalidate_flow()


# ------------------------------------------------------------------ props

func add_prop(c: Vector2i, kind: String) -> Prop:
	var p := Prop.new()
	p.setup(kind, Iso.cell_center(c), self)
	entities.add_child(p)
	props.append(p)
	if not props_by_cell.has(c):
		props_by_cell[c] = []
	props_by_cell[c].append(p)
	if p.light_color.a > 0.0:
		add_light(Iso.to_screen(p.gpos) - Vector2(0, Iso.h(p.light_height_m)), p.light_color, p.light_energy, p.light_range_m, 90.0, 0)
	return p


func remove_prop(p: Prop) -> void:
	var c := Iso.cell_of(p.gpos)
	if props_by_cell.has(c):
		props_by_cell[c].erase(p)
		if props_by_cell[c].is_empty():
			props_by_cell.erase(c)
	props.erase(p)


# ------------------------------------------------------------------ visuals

func _build_floor() -> void:
	var sheet := SheetDB.get_sheet(FLOOR_SHEET)
	_floor_root = Node2D.new()
	_floor_root.name = "Floor"
	_floor_root.z_index = -20
	add_child(_floor_root)
	var chunks := {}
	for c in floor_kind:
		var k := Vector2i(floori(float(c.x) / CHUNK), floori(float(c.y) / CHUNK))
		if not chunks.has(k):
			chunks[k] = []
		chunks[k].append(c)
	var keys := chunks.keys()
	keys.sort_custom(func(a, b): return a.x + a.y < b.x + b.y or (a.x + a.y == b.x + b.y and a.x < b.x))
	for k in keys:
		var cells: Array = chunks[k]
		cells.sort_custom(func(a, b): return a.x + a.y < b.x + b.y or (a.x + a.y == b.x + b.y and a.x < b.x))
		var tiles: Array = []
		for c in cells:
			tiles.append([Iso.to_screen(Iso.cell_center(c)), sheet.region(0, floor_kind[c])])
		var ch := TileChunk.new()
		ch.setup(sheet.tex, sheet, tiles)
		_floor_root.add_child(ch)
		if sheet.emit:
			var ce := TileChunk.new()
			ce.setup(sheet.emit, sheet, tiles)
			ce.material = _add_mat
			ce.modulate = Color(1.8, 1.8, 1.8)
			ce.z_index = 1
			_floor_root.add_child(ce)


class TileChunk extends Node2D:
	var tex: Texture2D
	var tiles: Array
	var size: Vector2
	var origin: Vector2

	func setup(t: Texture2D, sheet, tiles_: Array) -> void:
		tex = t
		tiles = tiles_
		size = Vector2(sheet.fw, sheet.fh)
		origin = sheet.origin

	func _draw() -> void:
		for t in tiles:
			draw_texture_rect_region(tex, Rect2(t[0] - origin, size), t[1])


func _build_blocks() -> void:
	var wsheet := SheetDB.get_sheet(WALL_SHEET)
	var lsheet := SheetDB.get_sheet(LOW_SHEET)
	for c in block:
		var b: int = block[c]
		if b == Block.WALL:
			block_nodes[c] = _block_sprite(c, wsheet, block_kind[c])
		elif b == Block.LOW:
			block_nodes[c] = _block_sprite(c, lsheet, block_kind[c])


func _block_sprite(c: Vector2i, sheet, idx: int) -> Node2D:
	var n := Node2D.new()
	n.position = Iso.to_screen(Iso.cell_center(c))
	var s := Sprite2D.new()
	s.self_modulate = Color(1.3, 1.3, 1.3)
	s.texture = sheet.tex
	s.region_enabled = true
	s.region_rect = sheet.region(0, idx)
	s.offset = sheet.offset()
	n.add_child(s)
	if sheet.emit:
		var e := Sprite2D.new()
		e.texture = sheet.emit
		e.region_enabled = true
		e.region_rect = s.region_rect
		e.offset = s.offset
		e.material = _add_mat
		e.modulate = Color(1.15, 1.15, 1.15) if sheet.name == "wall_blocks" else Color(0.75, 0.75, 0.75)
		n.add_child(e)
	entities.add_child(n)
	return n


func _build_ao() -> void:
	if _ao:
		_ao.queue_free()
	_ao = AOLayer.new()
	_ao.dungeon = self
	_ao.z_index = -15
	add_child(_ao)


class AOLayer extends Node2D:
	var dungeon

	func _draw() -> void:
		var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for c in dungeon.floor_kind:
			if dungeon.block.get(c, 0) == Dungeon.Block.WALL:
				continue
			for o in dirs:
				var n: Vector2i = c + o
				var b: int = dungeon.block.get(n, 0)
				var strength := 0.0
				if b == Dungeon.Block.WALL:
					strength = 0.62
				elif b == Dungeon.Block.LOW and dungeon.block.get(c, 0) == 0:
					strength = 0.32
				if strength <= 0.0:
					continue
				var p0: Vector2
				var p1: Vector2
				var inward := Vector2(-o.x, -o.y)
				if o.x != 0:
					var ex: int = c.x + (1 if o.x > 0 else 0)
					p0 = Vector2(ex, c.y)
					p1 = Vector2(ex, c.y + 1)
				else:
					var ey: int = c.y + (1 if o.y > 0 else 0)
					p0 = Vector2(c.x, ey)
					p1 = Vector2(c.x + 1, ey)
				var depth := 0.42
				var pts := PackedVector2Array([
					Iso.to_screen(Iso.tile_to_ground(p0)), Iso.to_screen(Iso.tile_to_ground(p1)),
					Iso.to_screen(Iso.tile_to_ground(p1 + inward * depth)), Iso.to_screen(Iso.tile_to_ground(p0 + inward * depth))])
				var dark := Color(0, 0, 0, strength)
				var clear := Color(0, 0, 0, 0)
				draw_polygon(pts, PackedColorArray([dark, dark, clear, clear]))


func _build_lights() -> void:
	# light spill from emissive wall faces into the room
	var face_dirs := [Vector2i(1, 0), Vector2i(0, 1)]  # the two camera-facing faces
	var count := 0
	for c in block:
		if block[c] != Block.WALL:
			continue
		var k: int = block_kind[c]
		var col := Color(0, 0, 0, 0)
		var energy := 0.0
		count += 1
		# grazing uplights along walls so the illustrated faces read in the dark
		if count % 3 == 0 and k in [0, 1, 5]:
			for o in face_dirs:
				var n: Vector2i = c + o
				if is_floor(n):
					var gw := Iso.tile_to_ground(Vector2(c.x + 0.5, c.y + 0.5) + Vector2(o) * 0.75)
					add_light(Iso.to_screen(gw), Color(1.0, 0.82, 0.6) if k != 5 else Color(0.4, 0.9, 0.6), 0.5, 3.4, 40.0, 1)
					break
		match k:
			2: col = Color(0.35, 1.0, 0.55); energy = 0.95   # soul-fire alcove
			4: col = Color(1.0, 0.6, 0.25); energy = 0.85    # torch sconce
			6: col = Color(0.35, 1.0, 0.55); energy = 0.9    # cracked wall glow
		if energy <= 0.0:
			continue
		if k == 4 and count % 2 == 0:
			continue
		for o in face_dirs:
			var n: Vector2i = c + o
			if not is_floor(n):
				continue
			var g := Iso.tile_to_ground(Vector2(c.x + 0.5, c.y + 0.5) + Vector2(o) * 0.85)
			add_light(Iso.to_screen(g) - Vector2(0, Iso.h(1.6)), col, energy, 4.2, 90.0, 0 if k in [2, 6] else 1)
	for c in floor_kind:
		if block.has(c):
			continue
		match floor_kind[c]:
			4:
				add_light(Iso.to_screen(Iso.cell_center(c)) - Vector2(0, 20), Color(1.0, 0.8, 0.45), 0.35, 3.0, 90.0, 1)
			5:
				add_light(Iso.to_screen(Iso.cell_center(c)) - Vector2(0, 10), Color(0.35, 1.0, 0.55), 0.45, 2.6, 60.0, 1)
			_:
				# soft overhead fill on a loose grid: pools of light, not flat ambience
				if c.x % 4 == 1 and c.y % 4 == 1:
					var cool: bool = (c.x / 4 + c.y / 4) % 2 == 0
					add_light(Iso.to_screen(Iso.cell_center(c)) - Vector2(0, 160), Color(1.0, 0.86, 0.68) if cool else Color(0.55, 0.95, 0.75),
						0.42, 6.0, 260.0, 2)


func add_light(screen_pos: Vector2, color: Color, energy: float, range_m: float, height := 90.0, tier := 0) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.position = screen_pos
	l.color = color
	l.energy = energy
	l.height = height
	l.texture_scale = Iso.m(range_m) * 2.0 / 256.0
	l.scale = Vector2(1.0, Iso.K)
	l.shadow_enabled = false
	l.visible = tier <= int(Game.gfx.get("lights", 2))
	add_child(l)
	lights_by_tier[clampi(tier, 0, 2)].append(l)
	return l


## Graphics preset hook: show light tiers up to `level`.
func apply_light_level(level: int) -> void:
	for t in 3:
		for l in lights_by_tier[t]:
			if is_instance_valid(l):
				l.visible = t <= level


func light_count() -> int:
	var n := 0
	for t in 3:
		for l in lights_by_tier[t]:
			if is_instance_valid(l) and l.visible:
				n += 1
	return n


static func make_light_texture() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.75, 0.75, 0.75, 1), Color(0.22, 0.22, 0.22, 1), Color(0, 0, 0, 1)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t


# ------------------------------------------------------------------ per-frame

func _process(dt: float) -> void:
	var pl = Game.player
	if pl == null:
		return
	_fade_occluders(pl, dt)
	var pc := Iso.cell_of(pl.gpos)
	if pc != _last_visit_cell:
		_last_visit_cell = pc
		for ox in range(-5, 6):
			for oy in range(-5, 6):
				visited[pc + Vector2i(ox, oy)] = true


func _fade_occluders(pl, dt: float) -> void:
	var p: Vector2 = pl.position
	var pc := Iso.cell_of(pl.gpos)
	var want := {}
	for ox in range(-1, 4):
		for oy in range(-1, 4):
			var c := pc + Vector2i(ox, oy)
			if not block_nodes.has(c) or block.get(c, 0) != Block.WALL:
				continue
			var n: Node2D = block_nodes[c]
			var dy := n.position.y - p.y
			if dy > 0.0 and dy < 300.0 and absf(n.position.x - p.x) < 190.0:
				want[c] = true
	for c in want:
		_faded[c] = true
	for c in _faded.keys():
		if not block_nodes.has(c):
			_faded.erase(c)
			continue
		var n: Node2D = block_nodes[c]
		var target := 0.28 if want.has(c) else 1.0
		n.modulate.a = move_toward(n.modulate.a, target, dt * 4.0)
		if target == 1.0 and n.modulate.a >= 1.0:
			_faded.erase(c)
