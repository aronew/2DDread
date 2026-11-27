shader_type canvas_item;
// Lit sprite with hit flash, tint (status effects / elites) and death dissolve, plus a
// style pass so the Blender-rendered characters sit in the hand-inked room paintings:
// * ink: a thick dark outline around the silhouette and inked lines where the colour
//   changes sharply inside it (the paintings' heavy black linework);
// * cel: the shading pulled toward flat bands (posterize) instead of smooth gradients;
// * grade: the deepest shadows pushed cool (the style's purple-tinted shadows) and a
//   touch more saturation, so the gunslinger's red still reads against the jade.
// Normal mapping comes from the sprite's CanvasTexture automatically. style = 0 turns the
// pass off (the original look).

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_color : source_color = vec4(1.0, 0.45, 0.15, 1.0);
uniform vec2 noise_scale = vec2(8.0, 8.0);
uniform sampler2D noise_tex : repeat_enable, filter_linear;

uniform float style : hint_range(0.0, 1.0) = 1.0;
uniform float ink_px = 2.0;                       // outline width, texture px
uniform vec4 ink_color : source_color = vec4(0.03, 0.05, 0.06, 1.0);
uniform float inner_ink : hint_range(0.0, 1.0) = 0.55;
uniform float bands = 4.0;
uniform float cel : hint_range(0.0, 1.0) = 0.55;
uniform vec4 shadow_tint : source_color = vec4(0.78, 0.84, 1.0, 1.0);   // cool, a little purple
uniform float saturation = 1.15;

varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 c = tex * vcol;
	if (style > 0.0) {
		vec2 px = TEXTURE_PIXEL_SIZE * ink_px;
		// outline: the strongest alpha around this pixel
		float around = 0.0;
		around = max(around, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
		around = max(around, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
		around = max(around, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
		around = max(around, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
		around = max(around, texture(TEXTURE, UV + px * 0.7).a);
		around = max(around, texture(TEXTURE, UV - px * 0.7).a);
		around = max(around, texture(TEXTURE, UV + vec2(px.x, -px.y) * 0.7).a);
		around = max(around, texture(TEXTURE, UV + vec2(-px.x, px.y) * 0.7).a);
		if (tex.a > 0.02) {
			// inner ink: luminance edges (Sobel-ish, one texel)
			vec2 t = TEXTURE_PIXEL_SIZE;
			float l = lum(texture(TEXTURE, UV + vec2(t.x, 0.0)).rgb) - lum(texture(TEXTURE, UV - vec2(t.x, 0.0)).rgb);
			float u = lum(texture(TEXTURE, UV + vec2(0.0, t.y)).rgb) - lum(texture(TEXTURE, UV - vec2(0.0, t.y)).rgb);
			float edge = smoothstep(0.2, 0.42, length(vec2(l, u)));
			// cel: pull luminance toward flat bands, keep hue
			float y = max(lum(c.rgb), 1e-4);
			float q = (floor(y * bands) + 0.5) / bands;
			c.rgb *= mix(1.0, q / y, cel * style);
			// grade: cool the shadows toward the jade rooms, a touch more saturation
			float sh = 1.0 - smoothstep(0.03, 0.2, y);
			c.rgb = mix(c.rgb, c.rgb * shadow_tint.rgb, sh * style);
			float g = lum(c.rgb);
			c.rgb = mix(vec3(g), c.rgb, mix(1.0, saturation, style));
			c.rgb = mix(c.rgb, ink_color.rgb, edge * inner_ink * style);
			// the silhouette's own soft edge goes to ink too
			c.rgb = mix(c.rgb, ink_color.rgb, (1.0 - smoothstep(0.35, 0.9, tex.a)) * style);
			c.a = max(c.a, around * vcol.a * style);
		} else {
			c = vec4(ink_color.rgb, around * vcol.a * style);
		}
	}
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
