shader_type canvas_item;
// Covers a painted prop that broke (or a chest that opened): drawn in the prop's own
// silhouette, slightly enlarged and soft-edged, just above the room painting, it shows
// the painting's floor from `clone` px to the side (a clean spot RoomPaint picked), so the
// painted urn / candles / nest disappear with the prop. TEXTURE is the prop's sprite
// (only its alpha is used).

uniform sampler2D painting : filter_linear, repeat_disable;
uniform vec2 paint_size;
uniform vec2 w2i_x;
uniform vec2 w2i_y;
uniform vec2 w2i_o;
uniform vec2 clone = vec2(256.0, 0.0);

varying vec2 world_pos;
varying vec4 vcol;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vcol = COLOR;
}

void fragment() {
	// soft silhouette: the prop's alpha, blurred a little
	vec2 px = TEXTURE_PIXEL_SIZE * 3.0;
	float a = texture(TEXTURE, UV).a * 0.4;
	a += texture(TEXTURE, UV + vec2(px.x, 0.0)).a * 0.15;
	a += texture(TEXTURE, UV - vec2(px.x, 0.0)).a * 0.15;
	a += texture(TEXTURE, UV + vec2(0.0, px.y)).a * 0.15;
	a += texture(TEXTURE, UV - vec2(0.0, px.y)).a * 0.15;
	a = smoothstep(0.05, 0.45, a);
	vec2 src = world_pos + clone;
	vec2 p = w2i_x * src.x + w2i_y * src.y + w2i_o;
	vec4 c = texture(painting, clamp(p / paint_size, vec2(0.0), vec2(1.0)));
	COLOR = vec4(c.rgb, c.a * a) * vcol;
}
