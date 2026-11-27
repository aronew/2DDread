shader_type canvas_item;
// Screen-space finishing: shockwave distortion, vignette, chromatic aberration kicks,
// damage edge pulse, low-health desaturation, full-screen flash and fine film grain.
// Shockwaves: up to 4 rings (PostFX.shockwave), each vec4(centre uv, radius, strength);
// flattened 2:1 so they lie on the isometric ground like everything else.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float aberration = 0.0;
uniform float damage = 0.0;
uniform float low_health = 0.0;
uniform vec4 flash_color : source_color = vec4(0.0);
uniform float vignette = 0.42;
uniform float time_s = 0.0;
uniform vec4 waves[4];
uniform float aspect = 1.7778;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 wave_glow = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		vec4 w = waves[i];
		if (w.w <= 0.0) {
			continue;
		}
		vec2 dv = (uv - w.xy) * vec2(aspect, 2.0);
		float dist = length(dv);
		float ring = (dist - w.z) / (0.035 + w.z * 0.25);
		float k = exp(-ring * ring) * w.w;
		uv -= normalize(dv + vec2(1e-5)) * k * 0.014 / vec2(aspect, 2.0) * 1.8;
		wave_glow += vec3(1.0, 0.85, 0.6) * k * 0.05;
	}
	vec2 c = uv - 0.5;
	float d = length(c);
	vec2 off = c * (0.0025 + aberration * 0.012) * d;
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum) * vec3(1.1, 0.85, 0.85), low_health * 0.45);
	float vig = smoothstep(0.85, 0.25, d * (1.0 + vignette));
	col *= mix(1.0, vig, 0.85);
	float edge = smoothstep(0.35, 0.75, d);
	col = mix(col, vec3(0.8, 0.02, 0.02), edge * clamp(damage + low_health * (0.35 + 0.25 * sin(time_s * 5.0)), 0.0, 1.0) * 0.6);
	col = mix(col, flash_color.rgb, flash_color.a);
	col += wave_glow;
	col += (hash(uv * 1000.0 + time_s) - 0.5) * 0.025;
	COLOR = vec4(col, 1.0);
}
