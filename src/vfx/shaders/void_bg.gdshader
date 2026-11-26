shader_type canvas_item;
// The underworld abyss beneath the platforms: dark depths with rising green
// soul-fire, all sampled from one pre-baked seamless noise texture
// (2-5 texture reads per pixel). quality 1 = fog + flames, 2 = + embers/shafts.

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform int quality = 1;
uniform vec2 cam = vec2(0.0);
uniform float zoom = 1.0;
uniform vec4 deep : source_color = vec4(0.005, 0.03, 0.025, 1.0);
uniform vec4 mist : source_color = vec4(0.04, 0.3, 0.17, 1.0);
uniform vec4 fire : source_color = vec4(0.3, 1.0, 0.5, 1.0);
uniform float time_s = 0.0;

void fragment() {
	vec2 px = UV / SCREEN_PIXEL_SIZE;
	vec2 world = px / zoom;
	vec3 col = deep.rgb;
	// slow parallax fog
	vec2 p0 = (world + cam * 0.3) * 0.00045 + vec2(time_s * 0.003, 0.0);
	float fog = smoothstep(0.4, 0.85, texture(noise_tex, p0).r);
	col = mix(col, mist.rgb, fog * 0.55);
	// soul-fire tongues: noise stretched vertically, scrolling up
	vec2 p1 = (world + cam * 0.45) * vec2(0.0016, 0.0007) + vec2(0.0, time_s * 0.06);
	float n1 = texture(noise_tex, p1).r;
	vec2 p2 = (world + cam * 0.45) * vec2(0.0035, 0.0015) + vec2(0.37, time_s * 0.11);
	float n2 = texture(noise_tex, p2).r;
	float flame = smoothstep(0.55, 0.85, n1 * 0.65 + n2 * 0.5);
	col = mix(col, fire.rgb * 0.75, flame * 0.55);
	col += fire.rgb * smoothstep(0.8, 0.95, n1 * 0.6 + n2 * 0.55) * 0.35;
	if (quality >= 2) {
		vec2 mp = (world + cam * 0.6) * 0.012 + vec2(0.0, time_s * 0.35);
		float ember = smoothstep(0.86, 0.9, texture(noise_tex, mp).r);
		col += fire.rgb * ember * 0.45;
		vec2 sp = world + cam * 0.4;
		float shaft = smoothstep(0.62, 0.9, texture(noise_tex, vec2((sp.x + sp.y * 0.6) * 0.0004, time_s * 0.01)).r);
		col += fire.rgb * shaft * 0.05;
	}
	COLOR = vec4(col, 1.0);
}
