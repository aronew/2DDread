shader_type canvas_item;
// The abyss beneath the platforms: layered drifting fog with parallax, faint
// light shafts and dust. Driven by camera position for depth.

uniform vec2 cam = vec2(0.0);
uniform float zoom = 1.0;
uniform vec4 deep : source_color = vec4(0.01, 0.03, 0.04, 1.0);
uniform vec4 mist : source_color = vec4(0.05, 0.28, 0.26, 1.0);
uniform vec4 glow : source_color = vec4(0.25, 0.9, 0.75, 1.0);
uniform float time_s = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 px = UV * (1.0 / SCREEN_PIXEL_SIZE);
	vec3 col = deep.rgb;
	// three parallax layers of mist, the deepest moving slowest
	for (int i = 0; i < 3; i++) {
		float depth = 0.25 + float(i) * 0.22;
		vec2 p = (px / zoom + cam * depth) * (0.0016 - float(i) * 0.0003) + vec2(time_s * 0.01 * (float(i) + 1.0), 0.0);
		float n = fbm(p + fbm(p * 1.7 + time_s * 0.02));
		float m = smoothstep(0.35, 0.95, n);
		col = mix(col, mist.rgb * (0.6 + 0.5 * float(i)), m * (0.35 + 0.15 * float(i)));
	}
	// slanted light shafts
	vec2 sp = px / zoom + cam * 0.4;
	float shaft = smoothstep(0.75, 1.0, noise(vec2((sp.x + sp.y * 0.6) * 0.004, time_s * 0.05)));
	col += glow.rgb * shaft * 0.07;
	// drifting motes
	vec2 mp = (px / zoom + cam * 0.6) * 0.02 + vec2(0.0, -time_s * 0.4);
	float mote = step(0.995, hash(floor(mp))) * smoothstep(0.5, 0.0, length(fract(mp) - 0.5));
	col += glow.rgb * mote * 0.8;
	COLOR = vec4(col, 1.0);
}
