shader_type canvas_item;
// The abyss beneath the platforms: parallax fog layers sampled from one
// pre-baked seamless noise texture (cheap: 2-4 texture reads per pixel).
// quality 1 = two fog layers, 2 = three layers + light shafts + motes.

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform int quality = 1;
uniform vec2 cam = vec2(0.0);
uniform float zoom = 1.0;
uniform vec4 deep : source_color = vec4(0.01, 0.03, 0.04, 1.0);
uniform vec4 mist : source_color = vec4(0.05, 0.28, 0.26, 1.0);
uniform vec4 glow : source_color = vec4(0.25, 0.9, 0.75, 1.0);
uniform float time_s = 0.0;

void fragment() {
	vec2 px = UV / SCREEN_PIXEL_SIZE;
	vec2 world = px / zoom;
	vec3 col = deep.rgb;
	int layers = quality >= 2 ? 3 : 2;
	for (int i = 0; i < layers; i++) {
		float fi = float(i);
		float depth = 0.25 + fi * 0.22;
		vec2 p = (world + cam * depth) * (0.00055 - fi * 0.00009) + vec2(time_s * 0.004 * (fi + 1.0), fi * 0.37);
		float n = texture(noise_tex, p).r;
		float m = smoothstep(0.45, 0.85, n);
		col = mix(col, mist.rgb * (0.6 + 0.5 * fi), m * (0.4 + 0.15 * fi));
	}
	if (quality >= 2) {
		vec2 sp = world + cam * 0.4;
		float shaft = smoothstep(0.62, 0.9, texture(noise_tex, vec2((sp.x + sp.y * 0.6) * 0.0004, time_s * 0.01)).r);
		col += glow.rgb * shaft * 0.07;
		vec2 mp = (world + cam * 0.6) * 0.01 + vec2(0.0, -time_s * 0.2);
		float mote = smoothstep(0.86, 0.9, texture(noise_tex, mp).r);
		col += glow.rgb * mote * 0.35;
	}
	COLOR = vec4(col, 1.0);
}
