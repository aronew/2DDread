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
const FLOOR_SHADER := preload("res://src/vfx/shaders/room_paint.gdshader")
const EDGE_PX := 56.0            # the painting's outer edge fades over this many px
const KEEP_OWN := ["eggs"]       # prop kinds drawn with their own sprites inside a painting

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
		d.add_child(rp)
		rp.dress(d, painted)
		out.append(rp)
	if not painted.is_empty():
		d.set_painted_cells(painted)
	return out


func setup(tex: Texture2D, info: Dictionary) -> void:
	texture = tex
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
func has_floor(world: Vector2) -> bool:
	if not covers(world, EDGE_PX):
		return false
	if _mask.is_empty():
		return true
	var p := w2i * world
	var mx := clampi(int(p.x / _mask_step), 0, _mask_w - 1)
	var my := clampi(int(p.y / _mask_step), 0, _mask_h - 1)
	return _mask[my * _mask_w + mx] >= 12


## Switches the walls and props it covers to the painting, and marks the floor cells it
## paints so their tiles are dropped.
func dress(d: Dungeon, painted: Dictionary) -> void:
	for c in d.floor_kind:
		# the whole diamond must be painted floor, or the tile stays
		var ok := true
		for t in [Vector2(0.5, 0.5), Vector2(0.15, 0.15), Vector2(0.85, 0.15), Vector2(0.15, 0.85), Vector2(0.85, 0.85)]:
			if not has_floor(Iso.to_screen(Iso.tile_to_ground(Vector2(c) + t))):
				ok = false
				break
		if ok:
			painted[c] = true
	for c in d.block_nodes:
		var n: Node2D = d.block_nodes[c]
		if covers(n.position):
			_cut(n)
	for pr in d.props:
		# nests keep their own sprite: they pulse and glow while they spawn and vanish when
		# broken, a tell the fight depends on (the painting can't show either)
		if is_instance_valid(pr) and covers(pr.position) and not KEEP_OWN.has(pr.kind):
			_cut(pr)


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
