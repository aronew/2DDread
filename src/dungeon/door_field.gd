class_name DoorField
extends Node2D
## Energy gate standing in a doorway cell. Visible (red, humming) only while
## the dungeon marks the cell as a locked door.

var cell := Vector2i.ZERO
var dungeon: Dungeon
var _along_j := true
var _t := 0.0
var _a := 0.0


func setup(c: Vector2i, d: Dungeon) -> void:
	cell = c
	dungeon = d
	var up := c + Vector2i(0, -1)
	var dn := c + Vector2i(0, 1)
	_along_j = dungeon.door_cells.has(up) or dungeon.door_cells.has(dn) or dungeon.block.get(up, 0) == Dungeon.Block.WALL
	position = Iso.to_screen(Iso.cell_center(c))
	material = VFX.add_mat


func _process(dt: float) -> void:
	_t += dt
	var locked: bool = dungeon.block.get(cell, 0) == Dungeon.Block.DOOR
	_a = move_toward(_a, 1.0 if locked else 0.0, dt * 4.0)
	visible = _a > 0.01
	if visible:
		queue_redraw()


func _draw() -> void:
	var c := Iso.cell_center(cell)
	var p0: Vector2
	var p1: Vector2
	if _along_j:
		p0 = Iso.tile_to_ground(Vector2(cell.x + 0.5, cell.y))
		p1 = Iso.tile_to_ground(Vector2(cell.x + 0.5, cell.y + 1))
	else:
		p0 = Iso.tile_to_ground(Vector2(cell.x, cell.y + 0.5))
		p1 = Iso.tile_to_ground(Vector2(cell.x + 1, cell.y + 0.5))
	var o := Iso.to_screen(c)
	var h := 2.7 * _a
	var a := Iso.lift(p0, 0) - o
	var b := Iso.lift(p1, 0) - o
	var at := Iso.lift(p0, h) - o
	var bt := Iso.lift(p1, h) - o
	var base := Color(1.0, 0.18, 0.12)
	draw_colored_polygon(PackedVector2Array([a, b, bt, at]), base * Color(1.2, 1.2, 1.2, 0.18 + 0.05 * sin(_t * 9.0)))
	for i in 7:
		var k := fposmod(i / 7.0 + _t * 0.35, 1.0)
		var l0 := a.lerp(at, k)
		var l1 := b.lerp(bt, k)
		draw_line(l0, l1, base * Color(2.2, 2.2, 2.2, 0.35 * (1.0 - absf(k - 0.5) * 1.4)), 2.0)
	draw_line(a, b, base * Color(3, 3, 3, 0.9), 3.0)
	draw_line(at, bt, base * Color(3, 3, 3, 0.6), 2.0)
	draw_line(a, at, base * Color(3, 3, 3, 0.9), 3.0)
	draw_line(b, bt, base * Color(3, 3, 3, 0.9), 3.0)
