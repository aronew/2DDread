class_name Terrace
extends Node2D
## Changes of floor level: terrace drops and stairs, on the game's one flat ground plane.
##
## The trick: at the 2:1 camera, a drop of LEVEL_M (1.633 m) moves a point 128 px down on
## screen, exactly what one cell of depth does (+1 i and +1 j). So a floor one level lower
## is simply laid out one cell further down-right in the layout, and gameplay (collision,
## shots, pathing) stays flat and unchanged. Between the two floors, the layout leaves a
## row of `_` cells (void) per level; this node paints the drop's stone face over it.
## Stairs (`/` cells, walkable) are drawn from their true 3D geometry, so a body standing
## on a stair cell stands on the steps. Geometry comes from the layout's TERRACES list, in
## the upper floor's layout coordinates:
##
## * {"face": [i0, i1, j], "drop": n}: the upper floor's front edge runs along row line j
##   from i0 to i1 and drops n levels toward +j. ("dir": "i" -> [j0, j1, i], dropping
##   toward +i.) Its top edge is the upper floor's edge; its foot meets the lower floor
##   n cells further down-right.
## * {"stair": [i0, i1, j0], "run": r, "drop": n, "steps": k, "cheek": true}: a stair cut
##   into the upper floor, i0..i1 wide, descending n levels toward +j over r cells from row
##   line j0. On screen it covers rows j0 .. j0 + r + n, shifted right by n; mark the cells
##   it covers `/` and the rest of the drop rows `_`. "cheek" draws the cut stone side on
##   its -i edge (the +i side faces away from the camera). ("dir": "i" -> [j0, j1, i0].)
##   Floor tiles beside it hide what the upper floor hides; faces drawn after it hide the
##   rest.
##
## Drawn once, as polygons above the floor tiles (z -19) and under room paintings, so a
## painting of the room covers it like the rest of the floor.

const LEVEL_M := 128.0 / Iso.HPX_PER_M       # 1.633 m: one level, one cell of depth on screen
const FACE_TEX := [null, preload("res://assets/sprites/env/terrace_face_1.png"),
	preload("res://assets/sprites/env/terrace_face_2.png")]
const TREAD_TEX := preload("res://assets/sprites/env/stair_tread.png")
const TREAD_M := 2.0                          # metres one repeat of stair_tread.png covers
const COPE_M := 0.14                          # the capstone lip along a face's top edge
const INK := Color(0.045, 0.035, 0.05)
const LIT := Color(1.12, 1.12, 1.1)           # faces toward +j turn to the key light
const SHADE := Color(0.8, 0.8, 0.86)          # faces toward +i turn away from it
const RISER := Color(0.62, 0.64, 0.7)
const TREAD := Color(1.05, 1.05, 1.03)
const NOSE := Color(1.45, 1.42, 1.3)

var defs: Array = []
var dungeon: Dungeon


func setup(defs_: Array, d: Dungeon) -> void:
	defs = defs_
	dungeon = d
	z_index = -19      # floor tiles are -20, pit capstones -18, room paintings -14
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	queue_redraw()


## Screen point of (u across, v along the descent, h metres) for a def's local frame.
func _pt(def: Dictionary, u: float, v: float, h: float) -> Vector2:
	var a: Array = def.get("face", def.get("stair"))
	var t: Vector2
	if def.get("dir", "j") == "i":
		t = Vector2(float(a[2]) + v, float(a[0]) + u)
	else:
		t = Vector2(float(a[0]) + u, float(a[2]) + v)
	return Iso.lift(Iso.tile_to_ground(t), h)


func _width(def: Dictionary) -> float:
	var a: Array = def.get("face", def.get("stair"))
	return float(a[1]) - float(a[0])


func _draw() -> void:
	# stairs first: the faces beside them are nearer and cover what they hide
	for def in defs:
		if def.has("stair"):
			_draw_stair(def)
	for def in defs:
		if def.has("face"):
			_draw_face(def)


func _draw_face(def: Dictionary) -> void:
	var w := _width(def)
	var drop: int = int(def.get("drop", 1))
	var d := drop * LEVEL_M
	var lit := LIT if def.get("dir", "j") == "j" else SHADE
	var tex: Texture2D = FACE_TEX[clampi(drop, 1, 2)]
	var p0 := _pt(def, 0, 0, 0)
	var p1 := _pt(def, w, 0, 0)
	var q1 := _pt(def, w, 0, -d)
	var q0 := _pt(def, 0, 0, -d)
	# a soft contact shadow on the lower floor along the foot
	var s0 := _pt(def, 0, 0.32, -d)
	var s1 := _pt(def, w, 0.32, -d)
	var dark := Color(0, 0, 0, 0.5)
	var clear := Color(0, 0, 0, 0)
	draw_polygon(PackedVector2Array([q0, q1, s1, s0]), PackedColorArray([dark, dark, clear, clear]))
	# the masonry: texture x runs along the face (2 m per repeat), y from lip to foot
	var uw := w * Iso.TILE_M / 2.0
	draw_polygon(PackedVector2Array([p0, p1, q1, q0]), PackedColorArray([lit, lit, lit * 0.8, lit * 0.8]),
		PackedVector2Array([Vector2(0, 0), Vector2(uw, 0), Vector2(uw, 1), Vector2(0, 1)]), tex)
	# capstone lip and ink
	var c0 := _pt(def, 0, 0, -COPE_M)
	var c1 := _pt(def, w, 0, -COPE_M)
	draw_polygon(PackedVector2Array([p0, p1, c1, c0]), PackedColorArray([NOSE, NOSE, lit, lit]),
		PackedVector2Array([Vector2(0, 0), Vector2(uw, 0), Vector2(uw, 0.07), Vector2(0, 0.07)]), TREAD_TEX)
	draw_line(p0, p1, INK, 2.5, true)
	draw_line(c0, c1, Color(INK, 0.7), 1.5, true)
	draw_line(q0, q1, Color(INK, 0.8), 2.0, true)
	draw_line(p0, q0, INK, 2.0, true)
	draw_line(p1, q1, INK, 2.0, true)


func _draw_stair(def: Dictionary) -> void:
	var w := _width(def)
	var run: float = float(def.get("run", 1))
	var drop: int = int(def.get("drop", 1))
	var d := drop * LEVEL_M
	var n: int = int(def.get("steps", maxi(4, roundi(d / 0.3))))
	var dv := run / n
	var dh := d / n
	var occ := _occluders(def, run, drop)
	var wm := w * Iso.TILE_M / TREAD_M        # tread texture repeats across
	for k in n:
		var v0 := k * dv
		var v1 := (k + 1) * dv
		var ht := -k * dh
		var hb := -(k + 1) * dh
		var jit := fposmod(k * 0.37, 1.0)     # each step a different strip of the slab texture
		# riser (faces +j, toward the camera, under the nosing's shadow)
		var r := PackedVector2Array([_pt(def, 0, v0, ht), _pt(def, w, v0, ht), _pt(def, w, v0, hb), _pt(def, 0, v0, hb)])
		var ruv := PackedVector2Array([Vector2(jit, 0.5), Vector2(jit + wm, 0.5), Vector2(jit + wm, 0.5 + dh / TREAD_M), Vector2(jit, 0.5 + dh / TREAD_M)])
		_clipped(r, PackedColorArray([RISER, RISER, RISER * 0.75, RISER * 0.75]), ruv, occ)
		# tread
		var t := PackedVector2Array([_pt(def, 0, v0, hb), _pt(def, w, v0, hb), _pt(def, w, v1, hb), _pt(def, 0, v1, hb)])
		var tv := Vector2(jit, jit * 0.6)
		var tm := dv * Iso.TILE_M / TREAD_M
		var tuv := PackedVector2Array([tv, tv + Vector2(wm, 0), tv + Vector2(wm, tm), tv + Vector2(0, tm)])
		_clipped(t, PackedColorArray([NOSE, NOSE, TREAD, TREAD]), tuv, occ)
		# ink at the nosing and in the riser's foot
		_clipped_line(_pt(def, 0, v0, ht), _pt(def, w, v0, ht), Color(INK, 0.85), 2.0, occ)
		_clipped_line(_pt(def, 0, v0, hb), _pt(def, w, v0, hb), Color(INK, 0.55), 1.5, occ)
	if def.get("cheek", false):
		# the stone the stair was cut from, on its -u side: from the upper floor down to
		# the stepped profile of the stair
		var vh: Array = [Vector2(0, 0), Vector2(run, 0), Vector2(run, -d)]
		for k in range(n - 1, -1, -1):
			vh.append(Vector2(k * dv, -(k + 1) * dh))
			if k > 0:
				vh.append(Vector2(k * dv, -k * dh))   # (k = 0 is the first point again)
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		for q in vh:
			pts.append(_pt(def, 0, q.x, q.y))
			# the face texture: x along the cheek (2 m per repeat), y from the lip down
			uvs.append(Vector2(q.x * Iso.TILE_M / 2.0, -q.y / d))
			cols.append(SHADE)
		draw_polygon(pts, cols, uvs, FACE_TEX[clampi(drop, 1, 2)])
		pts.append(pts[0])
		draw_polyline(pts, INK, 2.0, true)
	# the stair's outer edges
	_clipped_line(_pt(def, w, 0, 0), _pt(def, w, run, -d), INK, 2.0, occ)
	_clipped_line(_pt(def, 0, run, -d), _pt(def, w, run, -d), Color(INK, 0.6), 1.5, occ)


## Diamonds of the floor cells around a stair that keep their tiles: the upper floor beside
## the stair hides the part of it that runs under that floor.
func _occluders(def: Dictionary, run: float, drop: int) -> Array:
	var out: Array = []
	var box := Rect2(_pt(def, 0, 0, 0), Vector2.ZERO)
	for p in [_pt(def, _width(def), 0, 0), _pt(def, 0, run, -drop * LEVEL_M), _pt(def, _width(def), run, -drop * LEVEL_M)]:
		box = box.expand(p)
	for c in dungeon.floor_kind:
		if dungeon.stairs.has(c):
			continue
		var poly := PackedVector2Array([Iso.to_screen(Iso.tile_to_ground(Vector2(c.x, c.y))),
			Iso.to_screen(Iso.tile_to_ground(Vector2(c.x + 1, c.y))),
			Iso.to_screen(Iso.tile_to_ground(Vector2(c.x + 1, c.y + 1))),
			Iso.to_screen(Iso.tile_to_ground(Vector2(c.x, c.y + 1)))])
		var r := Rect2(poly[0], Vector2.ZERO).expand(poly[1]).expand(poly[2]).expand(poly[3])
		if r.grow(-1.0).intersects(box):
			out.append(poly)
	return out


## Draws a textured quad minus the occluding diamonds (uv/colour mapped bilinearly from
## the quad's corners).
func _clipped(quad: PackedVector2Array, cols: PackedColorArray, uvs: PackedVector2Array, occ: Array) -> void:
	var polys: Array = [quad]
	var qr := Rect2(quad[0], Vector2.ZERO).expand(quad[1]).expand(quad[2]).expand(quad[3])
	for o in occ:
		var orr := Rect2(o[0], Vector2.ZERO).expand(o[1]).expand(o[2]).expand(o[3])
		if not orr.intersects(qr):
			continue
		var next: Array = []
		for p in polys:
			next.append_array(Geometry2D.clip_polygons(p, o))
		polys = next
	var a := quad[1] - quad[0]
	var b := quad[3] - quad[0]
	var det := a.x * b.y - a.y * b.x
	if absf(det) < 0.001:
		return
	for p in polys:
		if p.size() < 3 or absf(_area(p)) < 1.0:
			continue
		var puv := PackedVector2Array()
		var pc := PackedColorArray()
		for q in p:
			var rr: Vector2 = q - quad[0]
			var s := clampf((rr.x * b.y - rr.y * b.x) / det, 0.0, 1.0)
			var t := clampf((a.x * rr.y - a.y * rr.x) / det, 0.0, 1.0)
			var top: Vector2 = uvs[0].lerp(uvs[1], s)
			var bot: Vector2 = uvs[3].lerp(uvs[2], s)
			puv.append(top.lerp(bot, t))
			pc.append(cols[0].lerp(cols[1], s).lerp(cols[3].lerp(cols[2], s), t))
		draw_polygon(p, pc, puv, TREAD_TEX)


static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		a += p[i].x * q.y - q.x * p[i].y
	return a * 0.5


func _clipped_line(a: Vector2, b: Vector2, col: Color, width: float, occ: Array) -> void:
	var segs: Array = [[a, b]]
	for o in occ:
		var next: Array = []
		for sg in segs:
			for piece in Geometry2D.clip_polyline_with_polygon(PackedVector2Array([sg[0], sg[1]]), o):
				if piece.size() >= 2:
					next.append([piece[0], piece[piece.size() - 1]])
		segs = next
	for sg in segs:
		draw_line(sg[0], sg[1], col, width, true)
