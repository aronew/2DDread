class_name ExitPortal
extends Node2D
## Descent portal. Hidden until the final arena is cleared, then it tears open: a tall
## purple-and-black vortex standing upright on a glowing rune circle, swirling, sucking
## motes in, unmistakably a way out. Stepping in takes the player to the next, more
## dangerous depth.

const W := 105.0          # half-width of the gateway (screen px)
const H := 175.0          # half-height
const CENTER_H_M := 2.2   # its centre stands this high above the floor
const PURPLE := Color(0.62, 0.22, 1.0)
const MAGENTA := Color(1.0, 0.3, 0.9)

var gpos := Vector2.ZERO
var active := false
var _t := 0.0
var _open := 0.0          # 0..1 opening animation
var _light: PointLight2D
var _used := false
var _mote_t := 0.0
var _void: VoidCore


func setup(g: Vector2) -> void:
	gpos = g
	position = Iso.to_screen(g)
	material = VFX.add_mat
	z_index = 0           # y-sorted in the entities layer, like a wall or an actor
	visible = false


func _ready() -> void:
	_light = PointLight2D.new()
	_light.texture = VFX.T.light
	_light.color = PURPLE
	_light.energy = 0.0
	_light.texture_scale = 4.0
	_light.scale = Vector2(1, Iso.K)
	_light.height = 90.0
	add_child(_light)
	# the black heart of the vortex is drawn normally (not additive), over the glow, inside
	# the swirling rims
	_void = VoidCore.new()
	_void.portal = self
	add_child(_void)


func activate() -> void:
	active = true
	visible = true
	_open = 0.0
	var c := Iso.lift(gpos, CENTER_H_M)
	VFX.flash_layer(VFX.T.star6, c, 0.0, Color(2.6, 1.4, 3.2, 1.0), Vector2(0.5, 0.5), Vector2(4.0, 4.0), 0.4)
	VFX.ring(gpos, Iso.m(4.0), PURPLE * 1.8, 0.9, 0.05)
	VFX.light_flash(c, PURPLE, 3.5, 7.0, 0.6)
	VFX.shake(0.35)
	if VFX.post:
		VFX.post.shockwave(c, 260.0, 0.6, 1.0)
	Audio.play("legendary_drop", gpos, 0.0, 0.7)
	Events.message.emit("A PORTAL TEARS OPEN", Color(0.8, 0.5, 1.0))


func _process(dt: float) -> void:
	if not active:
		return
	_t += dt
	_open = minf(1.0, _open + dt / 0.7)
	_light.energy = (2.2 + 0.5 * sin(_t * 3.0)) * _open
	_light.position = Vector2(0, -Iso.h(CENTER_H_M))
	_mote_t -= dt
	if _mote_t <= 0.0:
		_mote_t = 0.05
		# motes spiral in toward the gateway
		var a := randf() * TAU
		var from := Iso.lift(gpos, CENTER_H_M) + Vector2(cos(a) * W * 1.8, sin(a) * H * 1.2)
		VFX.emit("embers", from, (Iso.lift(gpos, CENTER_H_M) - from).angle(), Color(1.8, 0.7, 2.8), 0.04)
	queue_redraw()
	_void.queue_redraw()
	var pl = Game.player
	if _open >= 1.0 and not _used and pl and pl.alive and pl.gpos.distance_to(gpos) < Iso.m(1.3):
		_used = true
		Game.world.descend()


func _shape() -> float:
	# overshoot as it tears open, then settle
	return _open * (1.0 + 0.18 * sin(minf(_open, 1.0) * PI))


func _draw() -> void:
	if not active:
		return
	var k := _shape()
	var c := Vector2(0, -Iso.h(CENTER_H_M))
	# rune circle on the floor
	var floor_r := Iso.m(1.9) * k
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Iso.K))
	draw_arc(Vector2.ZERO, floor_r, 0.0, TAU, 64, PURPLE * Color(2.2, 2.2, 2.2, 0.9), 5.0, true)
	draw_arc(Vector2.ZERO, floor_r * 0.8, _t, _t + TAU * 0.8, 48, MAGENTA * Color(2.0, 2.0, 2.0, 0.6), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# outer glow
	draw_texture_rect(VFX.T.glow, Rect2(c - Vector2(W, H) * 1.9 * k, Vector2(W, H) * 3.8 * k), false, PURPLE * Color(1.4, 1.4, 1.4, 0.7))
	# swirling rims: arcs of an upright ellipse turning in opposite directions
	draw_set_transform(c, 0.0, Vector2(W * k, H * k))
	for i in 4:
		var rr := 1.0 - i * 0.12
		var spin := _t * (2.2 - i * 0.4) * (1.0 if i % 2 == 0 else -1.0)
		var col := (PURPLE if i % 2 == 0 else MAGENTA) * Color(2.4, 2.4, 2.4, 0.95 - i * 0.15)
		draw_arc(Vector2.ZERO, rr, spin, spin + TAU * 0.72, 48, col, (0.09 - i * 0.015), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The black void inside the gateway, with a slow purple swirl.
class VoidCore extends Node2D:
	var portal

	func _draw() -> void:
		if portal == null or not portal.active:
			return
		var k: float = portal._shape()
		var c := Vector2(0, -Iso.h(ExitPortal.CENTER_H_M))
		draw_set_transform(c, 0.0, Vector2(ExitPortal.W * k * 0.8, ExitPortal.H * k * 0.8))
		draw_circle(Vector2.ZERO, 1.0, Color(0.02, 0.0, 0.04, 1.0))
		for i in 3:
			var a: float = portal._t * (0.8 + i * 0.5) + i * 2.1
			draw_arc(Vector2.ZERO, 0.3 + i * 0.22, a, a + 2.4, 32, Color(0.45, 0.12, 0.75, 0.9), 0.05, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
