class_name PostFX
extends CanvasLayer
## Drives the post-process shader: flashes, aberration kicks, damage pulses.

var rect: ColorRect
var mat: ShaderMaterial
var _flash := Color(0, 0, 0, 0)
var _flash_dur := 0.1
var _flash_t := 0.0
var _aberr := 0.0
var _damage := 0.0
var _t := 0.0


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = preload("res://src/vfx/shaders/post.gdshader")
	rect.material = mat
	add_child(rect)
	VFX.post = self


func flash(color: Color, dur: float) -> void:
	_flash = color
	_flash_dur = dur
	_flash_t = dur


func aberration_kick(a: float) -> void:
	_aberr = maxf(_aberr, a)


func damage_pulse(a: float) -> void:
	_damage = maxf(_damage, a)
	_aberr = maxf(_aberr, a * 0.6)


func _process(dt: float) -> void:
	_t += dt
	_flash_t = maxf(0.0, _flash_t - dt)
	_aberr = move_toward(_aberr, 0.0, dt * 2.5)
	_damage = move_toward(_damage, 0.0, dt * 2.0)
	var fc := _flash
	fc.a = _flash.a * (_flash_t / maxf(0.001, _flash_dur))
	mat.set_shader_parameter("flash_color", fc)
	mat.set_shader_parameter("aberration", _aberr)
	mat.set_shader_parameter("damage", _damage)
	var pl = Game.player
	var low := 0.0
	if pl and pl.alive:
		low = clampf(1.0 - pl.hp / (pl.max_hp * 0.3), 0.0, 1.0)
	mat.set_shader_parameter("low_health", low)
	mat.set_shader_parameter("time_s", _t)
