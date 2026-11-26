class_name PitFire
extends Node2D
## Soul-fire chasms: void cells enclosed by walkable floor on all four sides
## (within a few cells), as opposed to the open abyss around the level and the gaps
## between rooms, which walls enclose.
## Seen from the game camera, each pit shows its far walls (the faces of the floor
## beyond it). Those get dark stone walls dropping into a green glow (drawn under
## the floor, so the near rim hides what it should), and painted flame strips that
## stand along them and lick past the rim (pit_flames.gdshader sways and flickers
## them by TIME), with a faint additive copy on top so they bloom.
## Everything is drawn once; tier-1 green lights let the fire light the stone around.

const TEX := preload("res://assets/sprites/env/pit_flames.png")   # 4 strips side by side
const SHADER := preload("res://src/vfx/shaders/pit_flames.gdshader")
const REACH := 8              # how far to look for enclosing floor
const SLAB_M := 0.42          # the floor tile's own side already covers this much
const DARK_M := 1.6           # the wall is darkest this far below the rim...
const GLOW_M := 3.0           # ...glows brightest here, behind the flames...
const DIM_M := 4.8            # ...and falls away into the bottomless dark
const FLAME_M := 2.8          # flames rise from this deep
const RISE_M := 0.55          # only the tips peek over the rim, so walkways stay readable
const OVERLAP := 0.35         # each strip spills this far past its half of the wall
const LIGHT := Color(0.35, 1.0, 0.55)
const STONE_LIT := Color(0.17, 0.24, 0.2)
const STONE_SHADE := Color(0.1, 0.15, 0.13)
const DEEP := Color(0.03, 0.08, 0.05)
const GLOW := Color(0.2, 0.85, 0.42)
const GLOW_DIM := Color(0.05, 0.3, 0.16)
const DEEP2 := Color(0.015, 0.06, 0.04)
const INK := Color(0.02, 0.03, 0.03)

var cells: Array = []
var _pit := {}
var walls: Array = []         # [p0 screen, p1 screen, depth m, lit, along m]


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


static func _screen(t: Vector2) -> Vector2:
	return Iso.to_screen(Iso.tile_to_ground(t))


func setup(pits: Array, d: Dungeon) -> void:
	cells = pits
	for c in cells:
		_pit[c] = true
	cells.sort_custom(func(a, b): return a.x + a.y < b.x + b.y)
	# far walls: the -i and -j sides of a pit cell face the camera when the cell
	# beyond them isn't pit. How deep we can see depends on how wide the pit is.
	for c in cells:
		if not _pit.has(c + Vector2i(-1, 0)):
			walls.append(_wall(Vector2(c.x, c.y), Vector2(c.x, c.y + 1), _run(c, Vector2i(1, 0)), false, c.y * 2.0 + c.x * 5.3))
		if not _pit.has(c + Vector2i(0, -1)):
			walls.append(_wall(Vector2(c.x, c.y), Vector2(c.x + 1, c.y), _run(c, Vector2i(0, 1)), true, c.x * 2.0 + c.y * 7.1 + 40.0))
	var m := ShaderMaterial.new()
	m.shader = SHADER
	material = m
	var glow := Glow.new()
	glow.fire = self
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	gm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.material = gm
	add_child(glow)
	var stone := Stone.new()
	stone.fire = self
	stone.z_index = -10            # under the floor (z -20 overall), above the abyss
	var sm := CanvasItemMaterial.new()
	sm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	stone.material = sm
	add_child(stone)
	for c in cells:
		if (c.x + c.y) % 2 == 0:
			d.add_light(Iso.to_screen(Iso.cell_center(c)) - Vector2(0, 20), LIGHT, 0.9, 4.0, 40.0, 1)
	queue_redraw()


func _run(c: Vector2i, dir: Vector2i) -> int:
	var n := 0
	while _pit.has(c + dir * n):
		n += 1
	return n


func _wall(t0: Vector2, t1: Vector2, run: int, lit: bool, along: float) -> Array:
	# the chasm is bottomless: its far wall shows all the way down to where the near
	# rim hides it, which is 192 px (3.2 m of height) per cell of pit width
	var depth := run * 3.2
	return [_screen(t0), _screen(t1), depth, lit, along]


## The flames (this node sits above the floor so tips can rise past the rim).
func _draw() -> void:
	draw_flames(self, Color.WHITE)


## One upright strip per wall segment: sheared along the wall so the flames stay
## vertical on screen, from the wall's foot up past the rim.
func draw_flames(ci: CanvasItem, tint: Color) -> void:
	for w in walls:
		var p0: Vector2 = w[0]
		var p1: Vector2 = w[1]
		var depth: float = w[2]
		var k: int = posmod(int(w[4] * 3.7), 4)
		var mid := (p0 + p1) * 0.5
		# two strips per wall segment keep the tongues small; a deeper, dimmer row goes
		# first where the pit is deep enough to show it, then the row at the rim
		for half in [[p0, mid], [mid, p1]]:
			var a: Vector2 = half[0]
			var b: Vector2 = half[1]
			var e := (b - a) * OVERLAP
			if depth > 4.5:
				_strip(ci, a - e, b + e, minf(depth, 5.2), 1.6, (k + 2) % 4, tint * Color(0.65, 0.65, 0.65))
			_strip(ci, a - e, b + e, minf(depth, FLAME_M), -RISE_M, k, tint)
			k = (k + 1) % 4


## One strip from `bottom_m` below the rim up to `top_m` below it (negative = above).
func _strip(ci: CanvasItem, a: Vector2, b: Vector2, bottom_m: float, top_m: float, k: int, tint: Color) -> void:
	var down := Vector2(0, Iso.h(bottom_m))
	var up := Vector2(0, Iso.h(top_m))
	var u0 := k * 0.25
	var pts := PackedVector2Array([a + up, b + up, b + down, a + down])
	var uvs := PackedVector2Array([Vector2(u0, 0), Vector2(u0 + 0.25, 0), Vector2(u0 + 0.25, 1), Vector2(u0, 1)])
	ci.draw_polygon(pts, PackedColorArray([tint, tint, tint, tint]), uvs, TEX)


class Glow extends Node2D:
	var fire

	func _draw() -> void:
		fire.draw_flames(self, Color(0.4, 0.55, 0.42))


## Stone walls dropping into a green glow, drawn under the floor tiles.
class Stone extends Node2D:
	var fire

	func _draw() -> void:
		# the pit floor itself is the animated soul-fire abyss (void_bg) showing through
		for w in fire.walls:
			var p0: Vector2 = w[0]
			var p1: Vector2 = w[1]
			var depth: float = w[2]
			var stone: Color = PitFire.STONE_LIT if w[3] else PitFire.STONE_SHADE
			# stone under the rim, darkening, then lit green by the fire below
			var stops := [[PitFire.SLAB_M, stone], [PitFire.DARK_M, PitFire.DEEP], [PitFire.GLOW_M, PitFire.GLOW],
				[PitFire.DIM_M, PitFire.GLOW_DIM], [maxf(depth, PitFire.DIM_M + 0.1), PitFire.DEEP2]]
			for i in stops.size() - 1:
				var z0: float = stops[i][0]
				var z1: float = minf(stops[i + 1][0], depth)
				if z1 <= z0:
					break
				var c0: Color = stops[i][1]
				var c1: Color = c0.lerp(stops[i + 1][1], (z1 - z0) / maxf(stops[i + 1][0] - z0, 0.001))
				var o0 := Vector2(0, Iso.h(z0))
				var o1 := Vector2(0, Iso.h(z1))
				draw_polygon(PackedVector2Array([p0 + o0, p1 + o0, p1 + o1, p0 + o1]), PackedColorArray([c0, c0, c1, c1]))
			var top := Vector2(0, Iso.h(PitFire.SLAB_M))
			# masonry courses and an ink line under the rim, so it reads as built stone
			draw_line(p0 + top, p1 + top, PitFire.INK, 3.0)
			var k := 1
			while PitFire.SLAB_M + k * 0.55 < minf(depth, PitFire.GLOW_M) - 0.3:
				var o := Vector2(0, Iso.h(PitFire.SLAB_M + k * 0.55))
				draw_line(p0 + o, p1 + o, PitFire.INK * Color(1, 1, 1, 0.6), 2.0)
				k += 1
