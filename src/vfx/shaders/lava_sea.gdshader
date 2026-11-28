shader_type canvas_item;
// The Phlegethon's sea of molten lava under the island rooms (behind the level, on the
// background layer). Anchored to the ground plane, so it stays put under the islands as the
// camera moves: bright orange lava, darker red currents winding through it, yellow-hot
// seams, and drifting plates of black crust, all slowly flowing. One pre-baked seamless
// noise texture, 4 reads a pixel.

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec2 cam = vec2(0.0);
uniform float zoom = 1.0;
uniform float time_s = 0.0;
uniform int quality = 1;

void fragment() {
	vec2 vp = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = UV * vp;
	vec2 world = cam + (px - vp * 0.5) / zoom;
	vec2 m = vec2(world.x, world.y * 2.0) / 90.51;   // ground metres
	float t = time_s;
	float warp = texture(noise_tex, m * 0.018 + vec2(t * 0.0035, t * 0.002)).r;
	float n1 = texture(noise_tex, m * 0.035 + vec2(warp * 0.55, t * 0.006)).r;
	float n2 = texture(noise_tex, m * 0.09 + vec2(t * 0.012, warp * 0.8)).r;
	float heat = n1 * 0.62 + n2 * 0.48;
	vec3 deep = vec3(0.42, 0.05, 0.02);
	vec3 orange = vec3(1.0, 0.4, 0.05);
	vec3 hot = vec3(1.15, 0.78, 0.28);
	vec3 col = mix(deep, orange, smoothstep(0.32, 0.58, heat));
	col = mix(col, hot, smoothstep(0.7, 0.86, heat));
	// black crust plates drifting on the surface
	float cr = texture(noise_tex, m * 0.05 - vec2(t * 0.004, warp * 0.3) + vec2(3.1, 1.7)).r;
	// darker currents winding through the lava (contours of the flow)
	float band = 1.0 - abs(fract(heat * 4.0 + warp * 0.6) - 0.5) * 2.0;
	col = mix(col, deep * 1.3, smoothstep(0.82, 0.97, band) * 0.55 * (1.0 - smoothstep(0.75, 0.9, heat)));
	float crust = smoothstep(0.76, 0.8, cr);
	col = mix(col, vec3(0.09, 0.03, 0.03), crust * 0.85);
	col += vec3(1.0, 0.35, 0.05) * smoothstep(0.72, 0.76, cr) * (1.0 - crust) * 0.35;   // glowing crust rims
	if (quality >= 2) {
		// a slow shimmer of heat over the brightest seams
		float sh = texture(noise_tex, m * 0.22 + vec2(0.0, t * 0.05)).r;
		col += hot * smoothstep(0.75, 0.9, sh) * smoothstep(0.6, 0.8, heat) * 0.18;
	}
	COLOR = vec4(col, 1.0);
}
