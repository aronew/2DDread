class_name PostFX
extends CanvasLayer
## Drives the post-process shader: shockwaves, flashes, aberration kicks, damage pulses.

const FULL := preload("res://src/vfx/shaders/post.gdshader")
const LITE := preload("res://src/vfx/shaders/post_lite.gdshader")

var rect: ColorRect
var mat: ShaderMaterial
var _flash := Color(0, 0, 0, 0)
var _flash_dur := 0.1
var _flash_t := 0.0
var _aberr := 0.0
var _damage := 0.0
var _t := 0.0
var _waves: Array = []          # {pos (world), r (screen px), t, dur, s}
var _waves_live := false


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = FULL
	rect.material = mat
	add_child(rect)
	VFX.post = self


## Full = screen-reading shader (aberration, desaturation); lite = alpha overlay only.
func set_full(full: bool) -> void:
	mat.shader = FULL if full else LITE


func flash(color: Color, dur: float) -> void:
	_flash = color
	_flash_dur = dur
	_flash_t = dur


## A ring of distortion expanding from a world point (canvas coords) to `radius_px`
## (screen px at zoom 1) over `dur` seconds. Only the full post shader shows it.
func shockwave(world_pos: Vector2, radius_px: float, dur := 0.35, strength := 1.0) -> void:
	if mat.shader != FULL:
		return
	if _waves.size() >= 4:
		_waves.pop_front()
	_waves.append({"pos": world_pos, "r": radius_px, "t": 0.0, "dur": dur, "s": strength})


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
	_update_waves(dt)


func _update_waves(dt: float) -> void:
	if _waves.is_empty():
		if _waves_live:
			_waves_live = false
			mat.set_shader_parameter("waves", PackedVector4Array([Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]))
		return
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var ct := vp.get_canvas_transform()
	var zoom := ct.get_scale().x
	var out := PackedVector4Array()
	for w in _waves:
		w["t"] += dt
	_waves = _waves.filter(func(w): return w["t"] < w["dur"])
	for w in _waves:
		var k: float = w["t"] / w["dur"]
		var sp: Vector2 = ct * (w["pos"] as Vector2)
		var ease := 1.0 - pow(1.0 - k, 3.0)
		var r: float = w["r"] * zoom * ease / size.y * 2.0   # in the shader's flattened units
		out.append(Vector4(sp.x / size.x, sp.y / size.y, r, w["s"] * (1.0 - k)))
	while out.size() < 4:
		out.append(Vector4.ZERO)
	mat.set_shader_parameter("waves", out)
	mat.set_shader_parameter("aspect", size.x / size.y)
	_waves_live = true
