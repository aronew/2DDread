class_name PitFire
extends Node2D
## Soul-fire in chasms: void cells enclosed by walkable floor on all four sides
## (within a few cells), as opposed to the open abyss around the level and the
## gaps between rooms, which walls enclose. Each pit cell gets
## a painted flame strip rising past the floor edge, all drawn once by this one
## canvas item (no per-frame script work), plus a tier-1 green
## light on every other cell so the fire lights the stone around the pit.

const TEX := preload("res://assets/sprites/env/pit_flames.png")
const REACH := 8                         # how far to look for enclosing floor
const LIGHT := Color(0.35, 1.0, 0.55)
const TINT := Color(1.1, 1.2, 1.1)   # >1 so the hottest parts bloom

var cells: Array = []


## Void cells inside the level's footprint that walkable floor encloses on all four sides.
static func find_pits(d: Dungeon) -> Array:
	if d.floor_kind.is_empty():
		return []
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	for c in d.floor_kind:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var out: Array = []
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var c := Vector2i(x, y)
			if d.floor_kind.has(c):
				continue
			if _closed(d, c, Vector2i(1, 0)) and _closed(d, c, Vector2i(-1, 0)) \
					and _closed(d, c, Vector2i(0, 1)) and _closed(d, c, Vector2i(0, -1)):
				out.append(c)
	return out


static func _closed(d: Dungeon, c: Vector2i, dir: Vector2i) -> bool:
	for k in range(1, REACH + 1):
		var n := c + dir * k
		if d.floor_kind.has(n):
			return d.block.get(n, Dungeon.Block.NONE) != Dungeon.Block.WALL
	return false


func setup(pits: Array, d: Dungeon) -> void:
	cells = pits
	# far cells first so nearer strips draw over them
	cells.sort_custom(func(a, b): return a.x + a.y < b.x + b.y)
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED   # painted light: lamps don't shade it
	material = m
	# a faint additive copy on top makes the fire bloom without washing out its shapes
	var glow := Glow.new()
	glow.fire = self
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	gm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.material = gm
	add_child(glow)
	for c in cells:
		if (c.x + c.y) % 2 == 0:
			d.add_light(Iso.to_screen(Iso.cell_center(c)) - Vector2(0, 30), LIGHT, 0.9, 4.0, 50.0, 1)
	queue_redraw()


func _draw() -> void:
	draw_strips(self, TINT)


## The texture holds four flame strips side by side, each faded at its base and sides.
func draw_strips(ci: CanvasItem, tint: Color) -> void:
	var sw := float(TEX.get_width()) / 4.0
	var sh := float(TEX.get_height())
	for c in cells:
		var s := Iso.to_screen(Iso.cell_center(c))
		# as wide as the cell, from the pit's near half up past its far edge
		var dst := Rect2(s.x - Iso.TILE_W * 0.5, s.y - 125.0, Iso.TILE_W, 172.0)
		var k := posmod(c.x * 7 + c.y * 13, 4)
		ci.draw_texture_rect_region(TEX, dst, Rect2(k * sw, 0.0, sw, sh), tint)


class Glow extends Node2D:
	var fire

	func _draw() -> void:
		fire.draw_strips(self, Color(0.45, 0.6, 0.45))
