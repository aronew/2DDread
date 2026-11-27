class_name PitFire
extends Node2D
## Soul-fire pits: void cells enclosed by walkable floor on all four sides (within a
## few cells), as opposed to the open abyss around the level and the gaps between
## rooms, which walls enclose. Built after the owner's pit pack
## (tools/blender/textures/kit_2026-11-27_pits): a narrow row of capstones at floor
## level around the opening, plain masonry dropping about 1.4 m, and green soul-fire
## burning low inside, so the lip always stays readable.
##
## Three layers, all drawn once (the flames move in their shader):
## * Interior: the pit's far walls (painted masonry from the pack, pit_wall.png), green
##   light rising up them, a glowing bed at their foot and the pack's painted flames
##   (pit_flames.png). It sits just above the floor but is clipped to the pit openings,
##   so the near rim hides what it should at any pit size, and the masonry paints over
##   the floor tiles' own edge where it shows inside a pit.
## * Coping: capstones from env/pit_coping, one piece per grid corner (a 4-bit mask of
##   which of the four cells around it are pit; see build_env.py), so every pit shape
##   gets clean corners. Normal-mapped, so torches and the fire light them.
## * Tier-1 green lights so the fire lights the stone around the pit.

const WALL_TEX := preload("res://assets/sprites/env/pit_wall.png")
const FLAME_TEX := preload("res://assets/sprites/env/pit_flames.png")
const SHADER := preload("res://src/vfx/shaders/pit_flames.gdshader")
const COPING_SHEET := "res://assets/sprites/env/pit_coping"
const REACH := 8                         # how far to look for enclosing floor
const WALL_M := 1.4                      # the masonry drops this far, onto the soul-fire bed
const COPE_M := 0.12                     # the capstones' front face covers the wall's top
const WALL_TEX_M := Vector2(1.5, 0.73)   # metres one repeat of pit_wall.png covers
const FLAME_TEX_M := Vector2(2.0, 0.87)  # metres one repeat of pit_flames.png covers
const BED_M := 1.3                       # the bed's glow fades this far below the wall foot
const LIGHT := Color(0.35, 1.0, 0.55)
# wall tint from just under the capstones, through the dark middle, to the fire-lit foot
const STONE_TOP := Color(0.95, 1.0, 0.97)
const STONE_MID := Color(0.7, 1.0, 0.82)
const STONE_FOOT := Color(1.8, 3.6, 2.3)
const SHADE := 0.78                      # the faces turned away from the key light
const BED := Color(0.3, 1.0, 0.52)
const BED_DEEP := Color(0.02, 0.16, 0.08, 0.85)  # what the bed fades to
const FLAME_SCALE := 1.3                 # flames stand this much taller than the painted strip

var cells: Array = []
var _pit := {}
var walls: Array = []         # [p0 screen, p1 screen (floor level), along m, lit]
var _holes: Array = []        # [PackedVector2Array diamond, Rect2] per pit cell, screen space


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


static func _hash(a: int, b: int) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)


func setup(pits: Array, d: Dungeon) -> void:
	cells = pits
	for c in cells:
		_pit[c] = true
	cells.sort_custom(func(a, b): return a.x + a.y < b.x + b.y)
	for c in cells:
		var poly := PackedVector2Array([_screen(Vector2(c.x, c.y)), _screen(Vector2(c.x + 1, c.y)),
			_screen(Vector2(c.x + 1, c.y + 1)), _screen(Vector2(c.x, c.y + 1))])
		var r := Rect2(poly[0], Vector2.ZERO)
		for p in poly:
			r = r.expand(p)
		_holes.append([poly, r])
	# far walls: the -i and -j sides of a pit cell face the camera when the cell beyond
	# them isn't pit (-j faces turn toward the key light, -i faces away)
	for c in cells:
		if not _pit.has(c + Vector2i(-1, 0)):
			walls.append([_screen(Vector2(c.x, c.y)), _screen(Vector2(c.x, c.y + 1)), c.y * 2.0 + c.x * 3.1, false])
		if not _pit.has(c + Vector2i(0, -1)):
			walls.append([_screen(Vector2(c.x, c.y)), _screen(Vector2(c.x + 1, c.y)), c.x * 2.0 + c.y * 3.7, true])
	var interior := Interior.new()
	interior.fire = self
	interior.z_index = -8                 # hazards are z -11: this lands just above the floor (-20)
	interior.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var um := CanvasItemMaterial.new()
	um.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	interior.material = um
	add_child(interior)
	var rays := Rays.new()
	rays.fire = self
	rays.z_index = -8
	var am := CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	am.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	rays.material = am
	add_child(rays)
	var flames := Flames.new()
	flames.fire = self
	flames.z_index = -8
	flames.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var fm := ShaderMaterial.new()
	fm.shader = SHADER
	flames.material = fm
	add_child(flames)
	var glow := Flames.new()
	glow.fire = self
	glow.tint = Color(0.35, 0.5, 0.38)
	glow.z_index = -8
	glow.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	glow.material = am
	add_child(glow)
	_build_coping()
	for c in cells:
		if (c.x + c.y) % 2 == 0:
			# high enough to light the capstones' tops evenly instead of glinting off their bevels
			d.add_light(Iso.to_screen(Iso.cell_center(c)) - Vector2(0, 20), LIGHT, 0.9, 4.0, 130.0, 1)


## One coping piece per grid corner that touches both pit and floor.
func _build_coping() -> void:
	var sheet := SheetDB.get_sheet(COPING_SHEET)
	if sheet == null:
		return
	var verts := {}
	for c in cells:
		for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			verts[c + o] = true
	var keys := verts.keys()
	keys.sort_custom(func(a, b): return a.x + a.y < b.x + b.y or (a.x + a.y == b.x + b.y and a.x < b.x))
	var tiles: Array = []
	for v in keys:
		var mask := 0
		if _pit.has(v + Vector2i(-1, -1)): mask |= 1
		if _pit.has(v + Vector2i(0, -1)): mask |= 2
		if _pit.has(v + Vector2i(-1, 0)): mask |= 4
		if _pit.has(v): mask |= 8
		if mask == 0 or mask == 15:
			continue
		tiles.append([_screen(Vector2(v.x, v.y)), sheet.region(0, mask)])
	var ch := Dungeon.TileChunk.new()
	ch.setup(sheet.tex, sheet, tiles)
	ch.z_index = -7
	add_child(ch)


## Draws the parallelogram p + a*s + b*t (s, t in 0..1) clipped to the pit openings.
## uv = uv0 + du*s + dv*t; the vertex colour runs from c0 (t=0) to c1 (t=1).
func clip_quad(ci: CanvasItem, p: Vector2, a: Vector2, b: Vector2, uv0: Vector2, du: Vector2, dv: Vector2,
		c0: Color, c1: Color, tex: Texture2D) -> void:
	var quad := PackedVector2Array([p, p + a, p + a + b, p + b])
	var box := Rect2(p, Vector2.ZERO).expand(p + a).expand(p + b).expand(p + a + b)
	var det := a.x * b.y - a.y * b.x
	if absf(det) < 0.001:
		return
	for h in _holes:
		if not box.intersects(h[1]):
			continue
		for poly in Geometry2D.intersect_polygons(quad, h[0]):
			if poly.size() < 3:
				continue
			var uvs := PackedVector2Array()
			var cols := PackedColorArray()
			for q in poly:
				var r: Vector2 = q - p
				var s := (r.x * b.y - r.y * b.x) / det
				var t := (a.x * r.y - a.y * r.x) / det
				uvs.append(uv0 + du * s + dv * t)
				cols.append(c0.lerp(c1, clampf(t, 0.0, 1.0)))
			ci.draw_polygon(poly, cols, uvs, tex)


## Masonry walls and the glowing bed at their foot.
class Interior extends Node2D:
	var fire

	func _draw() -> void:
		var mid_m := 0.6
		for w in fire.walls:
			var p0: Vector2 = w[0]
			var p1: Vector2 = w[1]
			var along: float = w[2]
			var k: float = 1.0 if w[3] else PitFire.SHADE
			var a := p1 - p0
			var u0 := along / PitFire.WALL_TEX_M.x
			var du := Vector2(2.0 / PitFire.WALL_TEX_M.x, 0.0)
			# two bands, so the tint can fall dark in the middle and catch the fire below
			var bands := [[PitFire.COPE_M - 0.04, mid_m, PitFire.STONE_TOP, PitFire.STONE_MID],
				[mid_m, PitFire.WALL_M, PitFire.STONE_MID, PitFire.STONE_FOOT]]
			for band in bands:
				var z0: float = band[0]
				var z1: float = band[1]
				var c0: Color = band[2] * Color(k, k, k)
				var c1: Color = band[3] * Color(k, k, k)
				fire.clip_quad(self, p0 + Vector2(0, Iso.h(z0)), a, Vector2(0, Iso.h(z1 - z0)),
					Vector2(u0, z0 / PitFire.WALL_TEX_M.y), du, Vector2(0, (z1 - z0) / PitFire.WALL_TEX_M.y),
					c0, c1, PitFire.WALL_TEX)
			# the soul-fire bed below the wall's foot, fading into the abyss
			var bed := PitFire.BED
			fire.clip_quad(self, p0 + Vector2(0, Iso.h(PitFire.WALL_M - 0.02)), a, Vector2(0, Iso.h(PitFire.BED_M)),
				Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, bed, PitFire.BED_DEEP, null)


## Green light rising up the walls in soft vertical streaks, like the mockup's pits.
class Rays extends Node2D:
	var fire
	var _tex: Texture2D

	func _ready() -> void:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.width = 64
		gt.height = 4
		_tex = gt
		queue_redraw()

	func _draw() -> void:
		for w in fire.walls:
			var p0: Vector2 = w[0]
			var p1: Vector2 = w[1]
			var a := p1 - p0
			var seed_i := int(w[2] * 7.0)
			var n := 3
			for i in n:
				var r1 := PitFire._hash(seed_i, i)
				var r2 := PitFire._hash(seed_i + 31, i)
				var width := 0.1 + 0.16 * r2              # of the 2 m wall
				var s0 := (i + 0.15 + 0.7 * r1) / n - width * 0.5
				var top := 0.15 + 0.4 * PitFire._hash(seed_i + 77, i)
				var strength := 0.3 + 0.25 * r2
				var c := Color(0.3, 1.0, 0.5, strength)
				fire.clip_quad(self, p0 + a * s0 + Vector2(0, Iso.h(top)), a * width, Vector2(0, Iso.h(PitFire.WALL_M - top)),
					Vector2(0, 0.5), Vector2(1, 0), Vector2.ZERO, Color(c.r, c.g, c.b, 0.0), c, _tex)


## The pack's painted flames along each wall's foot (twice: once through the sway
## shader, once dim and additive on top so the hottest parts bloom).
class Flames extends Node2D:
	var fire
	var tint := Color.WHITE

	func _draw() -> void:
		for w in fire.walls:
			var p0: Vector2 = w[0]
			var p1: Vector2 = w[1]
			var along: float = w[2]
			var a := p1 - p0
			# a dim, deeper row first (seen where the pit is wide), then the row at the foot
			for row in [[PitFire.WALL_M + 0.95, 0.75, 0.45, 5.3], [PitFire.WALL_M + 0.06, 1.0, 1.0, 0.0]]:
				var foot: float = row[0]
				var hm: float = PitFire.FLAME_TEX_M.y * PitFire.FLAME_SCALE * row[1] \
					* (0.85 + 0.3 * PitFire._hash(int(along * 5.0 + row[3]), 3))
				var c: Color = tint * Color(row[2], row[2], row[2])
				fire.clip_quad(self, p0 + Vector2(0, Iso.h(foot - hm)), a, Vector2(0, Iso.h(hm)),
					Vector2(along / PitFire.FLAME_TEX_M.x + 0.37 * PitFire._hash(int(along + row[3]), 9), 0.0),
					Vector2(2.0 / PitFire.FLAME_TEX_M.x / PitFire.FLAME_SCALE / row[1], 0.0), Vector2(0, 1), c, c, PitFire.FLAME_TEX)
