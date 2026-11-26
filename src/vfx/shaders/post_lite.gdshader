shader_type canvas_item;
// Low-cost post: vignette, damage edge and flashes as a plain alpha overlay.
// Never reads the screen texture, so it costs no full-frame copy.

uniform float damage = 0.0;
uniform float low_health = 0.0;
uniform vec4 flash_color : source_color = vec4(0.0);
uniform float vignette = 0.42;
uniform float time_s = 0.0;

void fragment() {
	float d = length(SCREEN_UV - 0.5);
	float dark = 1.0 - smoothstep(0.85, 0.25, d * (1.0 + vignette));
	vec4 o = vec4(0.0, 0.0, 0.0, dark * 0.8);
	float edge = smoothstep(0.35, 0.75, d) * clamp(damage + low_health * (0.35 + 0.25 * sin(time_s * 5.0)), 0.0, 1.0) * 0.6;
	o = mix(o, vec4(0.8, 0.02, 0.02, 1.0), edge);
	o = mix(o, vec4(flash_color.rgb, 1.0), flash_color.a);
	COLOR = o;
}
