shader_type canvas_item;
render_mode blend_add, unshaded;
// Additive emission layer + optional silhouette rim. The rim is computed from
// the diffuse atlas alpha so characters pop against dark floors regardless of
// scene lighting (player = cyan, enemies = red, elites = gold).

uniform sampler2D body_tex : filter_linear;
uniform float intensity = 2.2;
uniform float emit_on = 1.0;
uniform vec4 rim_color : source_color = vec4(0.0);
uniform float rim_px = 1.6;

void fragment() {
	vec3 col = texture(TEXTURE, UV).rgb * intensity * emit_on;
	if (rim_color.a > 0.0) {
		vec2 px = TEXTURE_PIXEL_SIZE * rim_px;
		float a = texture(body_tex, UV).a;
		float n = 0.0;
		n = max(n, texture(body_tex, UV + vec2(px.x, 0.0)).a);
		n = max(n, texture(body_tex, UV - vec2(px.x, 0.0)).a);
		n = max(n, texture(body_tex, UV + vec2(0.0, px.y)).a);
		n = max(n, texture(body_tex, UV - vec2(0.0, px.y)).a);
		n = max(n, texture(body_tex, UV + px * 0.7).a);
		n = max(n, texture(body_tex, UV - px * 0.7).a);
		float rim = clamp(n - a, 0.0, 1.0);
		col += rim_color.rgb * rim * rim_color.a * 2.0;
	}
	COLOR = vec4(col, 1.0) * COLOR;
}
