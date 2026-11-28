class_name GroundFog
extends Node2D
## A low veil of mist drifting over the floor: two layers of noise scrolling slowly in
## world space (so it stays put as the camera moves), pale green-grey, thin enough never
## to hide a fight (off on the Low preset). Drawn above the floor and room paintings (z -13) and below decals,
## hazards and actors, as one quad around the camera.

const TINT := Color(0.78, 0.88, 0.86)
const DENSITY := 0.25
const SIZE := Vector2(3600, 2400)

var _mat: ShaderMaterial


func _ready() -> void:
	z_as_relative = false
	z_index = -13
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 tint : source_color;
uniform float density = 0.2;
varying vec2 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec2 g = vec2(wp.x, wp.y * 2.0) / 1500.0;   // ground-space, so wisps lie flat
	float a = texture(noise_tex, g + vec2(TIME * 0.011, TIME * 0.005)).r;
	float b = texture(noise_tex, g * 2.6 + vec2(-TIME * 0.019, TIME * 0.008)).r;
	float f = smoothstep(0.38, 0.9, a * 0.7 + b * 0.45);
	COLOR = vec4(tint.rgb, f * density);
}
"""
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("noise_tex", preload("res://src/vfx/fog_noise.tres"))
	_mat.set_shader_parameter("tint", TINT)
	_mat.set_shader_parameter("density", DENSITY)
	material = _mat
	Game.graphics_changed.connect(_apply_preset)
	_apply_preset()


## Off on the Low preset (a full-screen layer: cheap on a GPU, not free on weak ones) and
## in paint guides, which show the room itself.
func _apply_preset() -> void:
	visible = Game.gfx.get("post", true) and not OS.get_cmdline_user_args().has("--paint-guide")


func _draw() -> void:
	draw_rect(Rect2(-SIZE * 0.5, SIZE), Color.WHITE)
