shader_type canvas_item;
// The room painting on the floor layer (RoomPaint): its outer EDGE px fade out, so it
// blends into the tiles beyond it.

uniform float edge = 56.0;

varying vec4 vcol;   // modulate only (in fragment(), COLOR already includes the texture)

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	vec2 d = min(px, 1.0 / TEXTURE_PIXEL_SIZE - px);
	c.a *= clamp(min(d.x, d.y) / edge, 0.0, 1.0);
	COLOR = c * vcol;
}
