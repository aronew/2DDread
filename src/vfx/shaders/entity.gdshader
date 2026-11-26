shader_type canvas_item;
// Lit sprite with hit flash, tint (status effects / elites) and death dissolve.
// Normal mapping comes from the sprite's CanvasTexture automatically.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_color : source_color = vec4(1.0, 0.45, 0.15, 1.0);
uniform vec2 noise_scale = vec2(8.0, 8.0);
uniform sampler2D noise_tex : repeat_enable, filter_linear;

void fragment() {
	vec4 c = COLOR;
	c.rgb = mix(c.rgb, c.rgb * tint.rgb * 1.7 + tint.rgb * 0.08, tint_amount);
	c.rgb = mix(c.rgb, flash_color.rgb * 1.6, flash);
	if (dissolve > 0.0) {
		float n = texture(noise_tex, UV * noise_scale).r;
		float edge = n - dissolve;
		if (edge < 0.0) {
			discard;
		}
		c.rgb += dissolve_color.rgb * 7.0 * (1.0 - smoothstep(0.0, 0.09, edge));
	}
	COLOR = c;
}
