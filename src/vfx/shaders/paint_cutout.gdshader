shader_type canvas_item;
// A wall, column or prop inside a painted room (RoomPaint) draws the room painting
// instead of its own art, within its own silhouette: it looks exactly like the painting
// but still y-sorts over whoever stands behind it.
// * Where the painting is abyss (keyed out on import), the sprite turns transparent: the
//   painting decides the silhouette, so a wall painted lower than the kit's stays lower.
// * Toward the painting's outer edge (EDGE px), and outside it, the sprite's own art
//   fades back in.
// * Lit softly and without its normal map: the painting has its own light, so the
//   room's lights only tint it (a light right against a flat surface would otherwise
//   make a hard bright dot, and side-facing normals made walls darker than the floor).

uniform sampler2D painting : filter_linear, repeat_disable;
uniform vec2 paint_size;
// world (canvas) position -> painting pixel: img = w2i_x * x + w2i_y * y + w2i_o
uniform vec2 w2i_x;
uniform vec2 w2i_y;
uniform vec2 w2i_o;
uniform float edge = 56.0;

varying vec2 world_pos;
varying vec4 vcol;   // modulate only (in fragment(), COLOR already includes the texture)

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vcol = COLOR;
}

void fragment() {
	vec4 own = texture(TEXTURE, UV);
	vec2 px = w2i_x * world_pos.x + w2i_y * world_pos.y + w2i_o;
	vec2 d = min(px, paint_size - px);
	float k = clamp(min(d.x, d.y) / edge, 0.0, 1.0);
	vec4 p = texture(painting, clamp(px / paint_size, vec2(0.0), vec2(1.0)));
	COLOR = vec4(mix(own.rgb, p.rgb, k), own.a * mix(1.0, p.a, k)) * vcol;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void light() {
	LIGHT = vec4(COLOR.rgb * LIGHT_COLOR.rgb * LIGHT_ENERGY * 0.3, LIGHT_COLOR.a);
}
