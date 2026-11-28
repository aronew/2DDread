class_name SoulGeyser
extends Node2D
## A soul-fire geyser: a column of green fire that erupts out of a soul-fire lake over the
## bridge cell beside it, on a fixed cycle (the layout's GEYSERS list; room 6, the Isles of
## Lethe). Telegraphed like every attack: for WARN seconds the lake simmers, a red ring marks
## the bridge and a hiss sounds; then the column erupts and burns whoever is in the ring,
## enemies as well as the player (lure hounds onto a bridge, dash through with i-frames).
## Geysers share one clock with per-geyser offsets, so they take turns and a bridge is never
## blocked for long. Drawing is only redone while a geyser warns or erupts.

const IDLE := 2.4
const WARN := 1.1
const ERUPT := 0.7
const RADIUS_M := 1.6
const DAMAGE := 22.0           # to the player
const ENEMY_DAMAGE := 55.0     # enemies take more: luring them in should pay off
const COLUMN_W_M := 1.7
const COLUMN_H_M := 3.4
const FLAME_TEX := preload("res://assets/sprites/env/pit_flames.png")
const FLAME_SHADER := preload("res://src/vfx/shaders/pit_flames.gdshader")
const GREEN := Color(0.35, 1.0, 0.55)

var src_g := Vector2.ZERO     # ground point the column rises from (the lake cell's centre)
var hit_g := Vector2.ZERO     # centre of the ring it burns, over the bridge
var radius := 0.0
var offset := 0.0
var _t := 0.0
var _phase := 0               # 0 idle, 1 warn, 2 erupt
var _hit := {}                # instance ids already burnt in this eruption
var _bubble := 0.0
var _column: Column


static func cycle() -> float:
	return IDLE + WARN + ERUPT


func setup(def: Dictionary) -> void:
	var f: Array = def["from"]
	var a: Array = def["at"]
	src_g = Iso.cell_center(Vector2i(int(f[0]), int(f[1])))
	hit_g = src_g.lerp(Iso.cell_center(Vector2i(int(a[0]), int(a[1]))), 0.65)
	radius = Iso.m(RADIUS_M)
	offset = float(def.get("offset", 0.0)) * cycle()
	add_to_group("geysers")
	_column = Column.new()
	_column.position = Iso.to_screen(src_g)
	_column.z_as_relative = false
	_column.z_index = 1                    # just above the entity layer: a glowing column
	_column.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var m := ShaderMaterial.new()
	m.shader = FLAME_SHADER
	m.set_shader_parameter("gain", 1.6)
	_column.material = m
	add_child(_column)


## Where this cycle is: 0 idle, 1 warn, 2 erupt, and how far into that phase (0..1).
func _state(t: float) -> Vector2:
	var u := fposmod(t + offset, cycle())
	if u < IDLE:
		return Vector2(0, u / IDLE)
	if u < IDLE + WARN:
		return Vector2(1, (u - IDLE) / WARN)
	return Vector2(2, (u - IDLE - WARN) / ERUPT)


## True while a geyser is warning or erupting over this ground point (the bot steers by it).
static func danger_at(tree: SceneTree, g: Vector2, margin := 0.0) -> SoulGeyser:
	for n in tree.get_nodes_in_group("geysers"):
		var gy := n as SoulGeyser
		if gy and gy._phase != 0 and g.distance_to(gy.hit_g) < gy.radius + margin:
			return gy
	return null


func _process(dt: float) -> void:
	_t += dt
	var st := _state(_t)
	var ph := int(st.x)
	if ph != _phase:
		_enter(ph)
	_phase = ph
	match ph:
		0:
			_bubble -= dt
			if _bubble <= 0.0:
				_bubble = randf_range(0.5, 1.1)
				VFX.emit("souls", Iso.lift(src_g, 0.1), -PI / 2, GREEN * Color(1.6, 1.6, 1.6, 0.6), 0.15)
			if _column.height > 0.0:
				_column.set_shape(0.0, 0.0)
		1:
			# the lake simmers higher and brighter as the warning runs out
			_column.set_shape(lerpf(0.25, 0.8, st.y), lerpf(0.5, 0.9, st.y))
		2:
			var rise := minf(1.0, st.y * 5.0)
			var fall := 1.0 - smoothstep(0.7, 1.0, st.y)
			_column.set_shape(COLUMN_H_M * rise * fall + 0.3, fall)
			_burn()


func _enter(ph: int) -> void:
	if ph == 1:
		VFX.telegraph_circle(hit_g, radius, WARN)
		Audio.play("bloater_prime", hit_g)
	elif ph == 2:
		_hit.clear()
		var top := Iso.lift(src_g, 1.4)
		VFX.light_flash(top, GREEN, 2.4, 5.5, ERUPT + 0.2, 110.0)
		VFX.emit("embers", Iso.lift(src_g, 0.4), -PI / 2, GREEN * 3.0, 0.9)
		VFX.emit("souls", Iso.lift(src_g, 0.6), -PI / 2, GREEN * 2.4, 0.8)
		VFX.ring(hit_g, radius, GREEN * 1.4, 0.3)
		VFX.shake(0.12)
		Audio.play("explosion_small", hit_g)


## Everyone in the ring is burnt once per eruption: the player, enemies (flying ones too).
func _burn() -> void:
	var pl = Game.player
	if pl and pl.alive and not _hit.has(pl.get_instance_id()):
		if pl.gpos.distance_to(hit_g) < radius + pl.radius:
			_hit[pl.get_instance_id()] = true
			var d := DamageInfo.make(DAMAGE, DamageInfo.Type.FIRE, self)
			d.direction = (pl.gpos - src_g).normalized()
			pl.take_damage(d)
	for e in Game.grid.query(hit_g, radius):
		if not _hit.has(e.get_instance_id()):
			_hit[e.get_instance_id()] = true
			var d := DamageInfo.make(ENEMY_DAMAGE, DamageInfo.Type.FIRE, self)
			d.direction = (e.gpos - src_g).normalized()
			d.knockback = Iso.m(4.0)
			d.stagger = 40.0
			d.status = {&"burn": 1.0}
			e.take_damage(d)


## The fire column: an additive glow core with tiers of the pit's painted flame tongues
## stacked up it, narrowing toward the top, so it reads as a pillar of soul-fire.
class Column extends Node2D:
	var height := 0.0
	var alpha := 0.0
	var glow: Glow

	func _ready() -> void:
		glow = Glow.new()
		glow.material = VFX.add_mat
		glow.show_behind_parent = true
		add_child(glow)

	func set_shape(h_m: float, a: float) -> void:
		if absf(h_m - height) < 0.01 and absf(a - alpha) < 0.01:
			return
		height = h_m
		alpha = a
		queue_redraw()
		if glow:
			glow.height = h_m
			glow.alpha = a
			glow.queue_redraw()

	func _draw() -> void:
		if height <= 0.01 or alpha <= 0.01:
			return
		var tex: Texture2D = SoulGeyser.FLAME_TEX
		var w := SoulGeyser.COLUMN_W_M * Iso.PX_PER_M
		var h := height * Iso.HPX_PER_M
		var tiers := 1 if height < 1.2 else 3
		var th := h / tiers * 1.45
		for k in tiers:
			var u := float(k) / maxf(1.0, tiers - 1.0)
			var tw := w * lerpf(1.0, 0.45, u)
			var y_top := -h * float(k + 1) / tiers - th * 0.15
			# a different stretch of the strip per tier, so the tongues don't repeat
			var src := Rect2(fposmod(k * 337.0, tex.get_width() * 0.5), 0, tex.get_width() * 0.5, tex.get_height())
			draw_texture_rect_region(tex, Rect2(-tw * 0.5, y_top, tw, th), src, Color(1.2, 1.25, 1.2, alpha * lerpf(1.0, 0.8, u)))


	class Glow extends Node2D:
		var height := 0.0
		var alpha := 0.0

		func _draw() -> void:
			if height <= 0.01 or alpha <= 0.01:
				return
			var w := SoulGeyser.COLUMN_W_M * Iso.PX_PER_M
			var h := height * Iso.HPX_PER_M
			var g: Texture2D = VFX.T.glow
			var c := SoulGeyser.GREEN
			# the pool of light where it leaves the lake, then the column's hot core
			draw_texture_rect(g, Rect2(-w * 1.3, -w * 0.45, w * 2.6, w * 0.9), false, c * Color(1.6, 1.6, 1.6, 0.8 * alpha))
			draw_texture_rect(g, Rect2(-w * 0.75, -h * 1.05, w * 1.5, h * 1.15), false, c * Color(1.4, 1.5, 1.4, 0.75 * alpha))
			draw_texture_rect(g, Rect2(-w * 0.3, -h * 0.95, w * 0.6, h * 0.95), false, Color(1.6, 2.2, 1.7, 0.7 * alpha))
