class_name GameCamera
extends Camera2D
## Follows the player with aim look-ahead. Trauma-based shake (squared so
## small hits stay subtle), directional kick for recoil, zoom punch.

const BASE_ZOOM := 0.95
var zoom_mult := 1.0   # dev flag --zoom
var trauma := 0.0
var _kick := Vector2.ZERO
var _noise := FastNoiseLite.new()
var _t := 0.0
var _zoom_punch := 0.0
var target_node: Node2D
var lookahead := 0.18


func _ready() -> void:
	_noise.frequency = 4.0
	zoom = Vector2(BASE_ZOOM, BASE_ZOOM) * zoom_mult
	VFX.camera = self
	Game.camera = self
	make_current()


func add_trauma(t: float) -> void:
	trauma = clampf(trauma + t, 0.0, 1.0)


func kick(dir: Vector2, amount: float) -> void:
	_kick -= dir * amount


func punch(amount: float) -> void:
	_zoom_punch = maxf(_zoom_punch, amount)


func snap() -> void:
	if target_node:
		global_position = target_node.global_position


func _process(dt: float) -> void:
	_t += dt
	if target_node:
		var want := target_node.global_position + Vector2(0, -50)
		var pl = Game.player
		if pl and pl.alive and pl.input_override == null:
			var m := get_global_mouse_position()
			var la := (m - target_node.global_position) * lookahead
			want += la.limit_length(300.0)
		elif pl and pl.alive:
			want += Iso.to_screen(pl.aim_dir) * 120.0
		if pl and pl.alive:
			# lead the camera along the run, so speed reads and you see where you're going
			want += Iso.to_screen(pl.vel).limit_length(Iso.m(14.0)) * 0.11
		global_position = global_position.lerp(want, 1.0 - exp(-16.0 * dt))
	trauma = maxf(0.0, trauma - dt * 1.6)
	var s := trauma * trauma
	var sh := Vector2(_noise.get_noise_2d(_t * 60.0, 0.0), _noise.get_noise_2d(0.0, _t * 60.0)) * 34.0 * s
	_kick = _kick.lerp(Vector2.ZERO, 1.0 - exp(-18.0 * dt))
	offset = sh + _kick
	rotation = _noise.get_noise_2d(_t * 40.0, 99.0) * 0.025 * s
	_zoom_punch = move_toward(_zoom_punch, 0.0, dt * 0.25)
	var z := BASE_ZOOM * zoom_mult * (1.0 + _zoom_punch)
	zoom = Vector2(z, z)
