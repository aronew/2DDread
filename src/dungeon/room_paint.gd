class_name RoomPaint
extends Sprite2D
## A generated painting of a room, laid back over that room (workflow in
## docs/paint_guides/README.md: the game renders a paint guide, an image generator
## repaints it, tools/rooms/import_room_paint.py imports it to assets/rooms/NAME.png +
## .json with the guide's camera transform and a coarse mask of where it has floor).
##
## * The painting itself is the room's floor layer: drawn above the tiles, pits, capstones
##   and bridges (which it hides) and below decals, telegraphs and actors. Its abyss was
##   keyed out on import, so the soul-fire void shows around the painted floor, and its
##   outer edge fades into the tiles beyond (room_paint.gdshader).
## * Walls, columns and props inside it keep their own sprites for shape and y-sorting but
##   draw the painting through paint_cutout.gdshader, so they match it exactly and still
##   hide whoever walks behind them. Their glow sprites and contact shadows are hidden
##   (the painting has its own light and shadows).
## * Floor tiles are dropped only where the painting has floor, so a room bigger than the
##   painting carries on in tiles without a gap. Gameplay (collision, pits, encounters) is
##   untouched: it still comes from the layout.

const CUTOUT := preload("res://src/vfx/shaders/paint_cutout.gdshader")
const PATCH := preload("res://src/vfx/shaders/paint_patch.gdshader")
const PATCH_SCALE := 1.55         # the patch covers the prop's silhouette, enlarged this much
                                  # (SOL rarely paints a prop exactly where the layout has it)
## Clone offsets (screen px) tried in order for a broken prop's patch: sideways first, so
## the floor comes from the same depth and its perspective matches.
const CLONE_TRY := [Vector2(256, 0), Vector2(-256, 0), Vector2(384, 0), Vector2(-384, 0),
	Vector2(512, 0), Vector2(-512, 0), Vector2(128, 64), Vector2(-128, 64), Vector2(128, -64), Vector2(-128, -64)]
const FLOOR_SHADER := preload("res://src/vfx/shaders/room_paint.gdshader")
const EDGE_PX := 56.0            # the painting's outer edge fades over this many px
const KEEP_OWN := ["eggs"]       # prop kinds drawn with their own sprites inside a painting

var paints_walls := false      # painted with the ENCLOSE walls (import ... walls)
var mean := Color.BLACK        # the painting's average colour (import), for tinting kit walls
var resource_path_hint := ""
var w2i := Transform2D.IDENTITY  # world -> painting pixel
var size_px := Vector2.ZERO
var _mask := PackedByteArray()   # coarse floor mask, 0..15 per cell
var _mask_step := 16
var _mask_w := 0
var _mask_h := 0
var _cut_mat: ShaderMaterial


## Lays each painting (base path without extension) over the dungeon.
static func apply(paths: Array, d: Dungeon) -> Array:
	var out: Array = []
	var painted := {}
	for p in paths:
		var txt := FileAccess.get_file_as_string(String(p) + ".json")
		if txt == "" or not ResourceLoader.exists(String(p) + ".png"):
			push_warning("RoomPaint: missing %s(.png/.json)" % p)
			continue
		var info: Dictionary = JSON.parse_string(txt)
		var rp := RoomPaint.new()
		rp.setup(load(String(p) + ".png"), info)
		rp.resource_path_hint = String(p).get_file()
		d.add_child(rp)
		rp.mark_floor(d, painted)
		out.append(rp)
	d.room_paints = out
	# walls, columns and props draw the painting that shows at their base: where paintings
	# overlap (room 4's upper and lower halves), the topmost one with something painted there
	var with_walls := out.filter(func(r): return r.paints_walls)
	var kit_tint := _kit_tint(out)
	for c in d.block_nodes:
		# walls the game added around rooms (ENCLOSE) only draw paintings made with them;
		# older paintings show abyss there, so those walls keep their own art
		# look a metre up the wall: at the foot of a camera-side wall the painting is often
		# already black (the wall face is painted above its base)
		var at: Vector2 = d.block_nodes[c].position
		var pool: Array = with_walls if d.auto_walls.has(c) else out
		var rp := _pick(pool, at - Vector2(0, Iso.h(1.0)))
		if rp == null:
			rp = _pick(pool, at)
		if rp:
			rp._cut(d.block_nodes[c])
			if d.auto_walls.has(c):
				painted[c] = true   # no kit tile under it (it peeked out under painted walls)
			if d.near_walls.has(c) and rp.paints_walls:
				backfill_tries += 1
				rp._backfill(c, d)
		elif d.block.get(c, 0) == Dungeon.Block.WALL:
			_tint_kit(d.block_nodes[c], kit_tint)
	if not painted.is_empty():
		d.set_painted_cells(painted)
	for pr in d.props:
		# nests keep their own sprite: they pulse and glow while they spawn and vanish when
		# broken, a tell the fight depends on (the painting can't show either)
		if not is_instance_valid(pr):
			continue
		var rp := _pick(out, pr.position)
		if rp == null:
			continue
		pr.set_meta("painted", true)   # painted into the room: patch it out when it breaks
		if not KEEP_OWN.has(pr.kind):
			rp._cut(pr)
	return out


## Kit walls no painting covers (e.g. room 1 west, painted before rooms had walls) are
## tinted toward the paintings' average colour, so they don't stand out in grey.
const KIT_MEAN := Color(0.26, 0.28, 0.25)   # the kit wall sheet's average, as drawn (x1.3)


static func _kit_tint(paints: Array) -> Color:
	var sum := Vector3.ZERO
	var n := 0
	for rp in paints:
		if rp.mean != Color.BLACK:
			sum += Vector3(rp.mean.r, rp.mean.g, rp.mean.b)
			n += 1
	if n == 0:
		return Color(1.3, 1.3, 1.3)
	sum /= n
	return Color(1.3 * sum.x / KIT_MEAN.r, 1.3 * sum.y / KIT_MEAN.g, 1.3 * sum.z / KIT_MEAN.b)


static func _tint_kit(n: Node, tint: Color) -> void:
	for ch in n.get_children():
		if ch is Sprite2D and (ch as Sprite2D).region_enabled and (ch as Sprite2D).material == null:
			(ch as Sprite2D).self_modulate = tint
			return


## A camera-side wall in a painting is painted into the floor layer too, so fading its
## sprite would still show the painted wall. A backfill the wall's shape, just above the
## painting, shows real painted floor cloned from deeper in the room instead: hidden
## behind the wall while it stands, it's what you see when the wall fades near you.
func _backfill(c: Vector2i, d: Dungeon) -> void:
	var pts := PackedVector2Array()
	for t in [Vector2(c.x, c.y), Vector2(c.x + 1, c.y), Vector2(c.x + 1, c.y + 1), Vector2(c.x, c.y + 1)]:
		var b := Iso.to_screen(Iso.tile_to_ground(t))
		pts.append(b)
		pts.append(b - Vector2(0, Iso.h(BACKFILL_H)))
	var hull := Geometry2D.convex_hull(pts)
	# borrow from this painting, else from a neighbour's (corridor walls at a room boundary
	# have their clean floor in the next room's painting)
	var src: RoomPaint = self
	var clone := _clone_for_area(hull, d)
	if clone == Vector2.INF:
		for other in d.room_paints:
			if other != self:
				clone = other._clone_for_area(hull, d)
				if clone != Vector2.INF:
					src = other
					break
	var poly := Polygon2D.new()
	poly.polygon = hull
	poly.z_as_relative = false
	poly.z_index = -13
	if clone == Vector2.INF:
		# nowhere clean to borrow from (the frame's bottom edge): shadowed floor colour
		backfill_misses += 1
		if OS.get_cmdline_user_args().has("--debug-backfill"):
			print("[paint] flat backfill for near wall ", c, " in ", resource_path_hint)
		var base: Color = mean if mean != Color.BLACK else Color(0.18, 0.3, 0.27)
		poly.color = Color(base.r * 0.7, base.g * 0.7, base.b * 0.7)
		d.add_child(poly)
		return
	var m := ShaderMaterial.new()
	m.shader = PATCH
	m.set_shader_parameter("painting", src.texture)
	m.set_shader_parameter("paint_size", src.size_px)
	m.set_shader_parameter("w2i_x", src.w2i.x)
	m.set_shader_parameter("w2i_y", src.w2i.y)
	m.set_shader_parameter("w2i_o", src.w2i.origin)
	m.set_shader_parameter("clone", clone)
	poly.material = m
	d.add_child(poly)


const BACKFILL_H := 2.9   # a hair under the near wall sprite (3 m), so it never shows past it
const BACKFILL_TRY := [Vector2(0, -300), Vector2(128, -300), Vector2(-128, -300), Vector2(0, -380),
	Vector2(256, -340), Vector2(-256, -340), Vector2(0, -460), Vector2(128, -440), Vector2(-128, -440),
	Vector2(0, -540), Vector2(256, -500), Vector2(-256, -500), Vector2(384, -400), Vector2(-384, -400),
	Vector2(512, -460), Vector2(-512, -460), Vector2(384, -600), Vector2(-384, -600), Vector2(0, -680),
	Vector2(256, -700), Vector2(-256, -700), Vector2(640, -520), Vector2(-640, -520)]
## Floor kinds that are plain stone: cloning anything else (emblems, sunbursts, gold bands)
## would repeat a feature where it doesn't belong.
const PLAIN_FLOOR := [0, 1, 6, 7]
static var backfill_misses := 0   # walls left without a backfill (no clean spot found)
static var backfill_tries := 0


## An offset into the room where the whole area is open plain stone (cloning an emblem or
## a gold band would repeat it where it doesn't belong). Offsets go up-screen and along both
## floor axes (-i and -j), which matters in 3-wide corridors where straight up hits the
## far wall.
func _clone_for_area(area: PackedVector2Array, d: Dungeon) -> Vector2:
	var tries: Array = BACKFILL_TRY.duplicate()
	for k in range(2, 8):
		tries.append(Vector2(128, -64) * k)    # toward -j
		tries.append(Vector2(-128, -64) * k)   # toward -i
	for off in tries:
		if _area_clean(area, off, d, true):
			return off
	return Vector2.INF


func _area_clean(area: PackedVector2Array, off: Vector2, d: Dungeon, strict: bool) -> bool:
	var r := Rect2(area[0], Vector2.ZERO)
	for p in area:
		r = r.expand(p)
	for fx in [0.1, 0.5, 0.9]:
		for fy in [0.0, 0.33, 0.66, 1.0]:
			var q: Vector2 = r.position + r.size * Vector2(fx, fy)
			if not Geometry2D.is_point_in_polygon(q, area) and fy > 0.0 and fy < 1.0:
				continue
			q += off
			var cc := Iso.cell_of(Iso.to_ground(q))
			if not d.is_floor(cc) or d.props_by_cell.has(cc) or d.is_bridge(cc) or d.is_stair(cc) \
					or not has_floor(q, 0.0):
				return false
			if strict and not PLAIN_FLOOR.has(d.floor_kind.get(cc, -1)):
				return false
	return true


## None if no painting shows anything there (the thing keeps its own sprite rather than
## turning invisible against painted abyss).
static func _pick(paints: Array, world: Vector2) -> RoomPaint:
	for margin in [EDGE_PX, 0.0]:
		for k in range(paints.size() - 1, -1, -1):
			if paints[k].has_floor(world, margin):
				return paints[k]
	return null


func setup(tex: Texture2D, info: Dictionary) -> void:
	texture = tex
	paints_walls = info.get("walls", false)
	if info.has("mean"):
		mean = Color(info["mean"][0], info["mean"][1], info["mean"][2])
	centered = false
	var m: Array = info["world_to_image"]
	w2i = Transform2D(Vector2(m[0], m[1]), Vector2(m[2], m[3]), Vector2(m[4], m[5]))
	size_px = Vector2(info["size"][0], info["size"][1])
	transform = w2i.affine_inverse()   # painting pixels -> world
	z_index = -14                      # above floor/pits/coping/bridges/AO, below decals (-12)
	var fm := ShaderMaterial.new()
	fm.shader = FLOOR_SHADER
	fm.set_shader_parameter("edge", EDGE_PX)
	material = fm
	if info.has("mask"):
		var mk: Dictionary = info["mask"]
		_mask_step = int(mk["step"])
		_mask_w = int(mk["w"])
		_mask_h = int(mk["h"])
		var data: String = mk["data"]
		_mask.resize(data.length())
		for i in data.length():
			_mask[i] = data.substr(i, 1).hex_to_int()
	_cut_mat = ShaderMaterial.new()
	_cut_mat.shader = CUTOUT
	_cut_mat.set_shader_parameter("painting", tex)
	_cut_mat.set_shader_parameter("paint_size", size_px)
	_cut_mat.set_shader_parameter("w2i_x", w2i.x)
	_cut_mat.set_shader_parameter("w2i_y", w2i.y)
	_cut_mat.set_shader_parameter("w2i_o", w2i.origin)
	_cut_mat.set_shader_parameter("edge", EDGE_PX)


func covers(world: Vector2, margin := 0.0) -> bool:
	var p := w2i * world
	return p.x >= margin and p.y >= margin and p.x <= size_px.x - margin and p.y <= size_px.y - margin


## True where the painting shows solid floor (or anything opaque) around this point.
func has_floor(world: Vector2, margin := EDGE_PX) -> bool:
	if not covers(world, margin):
		return false
	if _mask.is_empty():
		return true
	var p := w2i * world
	var mx := clampi(int(p.x / _mask_step), 0, _mask_w - 1)
	var my := clampi(int(p.y / _mask_step), 0, _mask_h - 1)
	return _mask[my * _mask_w + mx] >= 12


## Marks the floor cells it paints, so their tiles are dropped.
func mark_floor(d: Dungeon, painted: Dictionary) -> void:
	for c in d.floor_kind:
		# the whole diamond must be painted floor, or the tile stays
		var ok := true
		for t in [Vector2(0.5, 0.5), Vector2(0.15, 0.15), Vector2(0.85, 0.15), Vector2(0.15, 0.85), Vector2(0.85, 0.85)]:
			if not has_floor(Iso.to_screen(Iso.tile_to_ground(Vector2(c) + t))):
				ok = false
				break
		if ok:
			painted[c] = true


## A painted prop broke (or a chest opened): cover its painted copy with floor cloned
## from a clean spot beside it, so it doesn't stay behind in the painting.
static func patch_prop(pr) -> void:
	var d: Dungeon = Game.dungeon
	if d == null or d.room_paints.is_empty() or not pr.has_meta("painted"):
		return
	var rp := _pick(d.room_paints, pr.position)
	if rp:
		rp._patch(pr)


func _patch(pr) -> void:
	var body: Sprite2D = pr.get("_body")
	if body == null:
		return
	var clone := _clone_offset(pr)
	if clone == Vector2.INF:
		return
	var s := Sprite2D.new()
	var tex: Texture2D = body.texture
	if tex is CanvasTexture:
		tex = (tex as CanvasTexture).diffuse_texture   # silhouette only; lit flat like the painting
	s.texture = tex
	s.region_enabled = true
	s.region_rect = body.region_rect
	s.offset = body.offset
	s.position = pr.position
	s.scale = Vector2(PATCH_SCALE, PATCH_SCALE)
	s.z_as_relative = false
	s.z_index = -13                   # above the painting (-14), below decals (-12)
	var m := ShaderMaterial.new()
	m.shader = PATCH
	m.set_shader_parameter("painting", texture)
	m.set_shader_parameter("paint_size", size_px)
	m.set_shader_parameter("w2i_x", w2i.x)
	m.set_shader_parameter("w2i_y", w2i.y)
	m.set_shader_parameter("w2i_o", w2i.origin)
	m.set_shader_parameter("clone", clone)
	s.material = m
	Game.dungeon.add_child(s)


## A nearby offset whose spot is clean: open floor where the prop stands, and higher up
## (where the prop rises in front of whatever is behind it) floor or wall but no other
## prop, pit or abyss. Walls are fine there: behind a prop against a wall, the wall goes on.
func _clone_offset(pr) -> Vector2:
	var d: Dungeon = Game.dungeon
	var h_px: float = Iso.h(2.0) * PATCH_SCALE
	for off in CLONE_TRY:
		var ok := true
		for k in 5:
			var sp: Vector2 = pr.position + off + Vector2(0, -h_px * k / 4.0)
			for dx in [-90.0, 0.0, 90.0]:
				var q: Vector2 = sp + Vector2(dx, 0)
				var c := Iso.cell_of(Iso.to_ground(q))
				var bad: bool = d.props_by_cell.has(c) or d.is_bridge(c) or d.is_stair(c) \
					or not d.floor_kind.has(c) or (k <= 1 and (not d.is_floor(c) or not has_floor(q)))
				if bad:
					ok = false
					break
			if not ok:
				break
		if ok:
			return off
	return Vector2.INF


func _cut(n: Node) -> void:
	var body_done := false
	for ch in n.get_children():
		if not ch is Sprite2D:
			continue
		var s := ch as Sprite2D
		if not s.region_enabled:
			s.visible = false            # contact shadow: the painting has its own
		elif not body_done and s.material == null:
			s.material = _cut_mat
			s.self_modulate = Color.WHITE
			body_done = true
		else:
			s.visible = false            # glow layers: the painting has its own light
