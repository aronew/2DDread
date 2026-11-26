class_name Iso
extends RefCounted
## Projection helpers. Three spaces are used throughout the game:
##
## * screen  — Godot 2D coordinates (node positions, y-sorted).
## * ground  — gameplay space: (screen.x, screen.y / K). Uniform metric,
##             1 m = PX_PER_M. All speeds, radii and distances live here.
## * tile    — continuous grid coordinates; cell (i, j) spans [i, i+1) x [j, j+1).
##             Walls are axis-aligned squares here, which makes collision exact.
##
## These match the Blender render rig (tools/blender/common.py).

const K := 0.75                      # vertical foreshortening (sin of camera pitch)
const PX_PER_M := 90.50967           # ground px per metre
const HPX_PER_M := 59.8664           # screen px per metre of height above ground
const TILE_W := 256.0
const TILE_H := 192.0
const TILE_M := 2.0
const TILE_GPX := 181.01934          # one tile edge in ground px


static func to_screen(g: Vector2) -> Vector2:
	return Vector2(g.x, g.y * K)


static func to_ground(s: Vector2) -> Vector2:
	return Vector2(s.x, s.y / K)


static func ground_to_tile(g: Vector2) -> Vector2:
	return Vector2((g.x + g.y) / 256.0, (g.y - g.x) / 256.0)


static func tile_to_ground(t: Vector2) -> Vector2:
	return Vector2((t.x - t.y) * 128.0, (t.x + t.y) * 128.0)


static func cell_of(g: Vector2) -> Vector2i:
	var t := ground_to_tile(g)
	return Vector2i(floori(t.x), floori(t.y))


static func cell_center(c: Vector2i) -> Vector2:
	return tile_to_ground(Vector2(c.x + 0.5, c.y + 0.5))


static func m(meters: float) -> float:
	return meters * PX_PER_M


static func h(meters: float) -> float:
	return meters * HPX_PER_M


## Screen position of a point `height_m` above ground point g.
static func lift(g: Vector2, height_m: float) -> Vector2:
	return Vector2(g.x, g.y * K - height_m * HPX_PER_M)


## Sprite direction index for a ground-space direction (0 = screen right, CCW toward camera).
static func dir_index(gdir: Vector2, n: int) -> int:
	var a := atan2(gdir.y, gdir.x)
	return posmod(int(round(a / TAU * n)), n)


## Lateral (model +Y / "left") unit vector for a facing direction in ground space.
static func left_of(gdir: Vector2) -> Vector2:
	return Vector2(gdir.y, -gdir.x)
