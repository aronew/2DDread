shader_type canvas_item;
render_mode unshaded;
// Painted soul-fire burning along the foot of pit walls (PitFire). The texture is the
// owner's painted flame strip, repeating along x (tips at the top). A gentle sway
// (stronger toward the tips) and flicker driven by TIME keep it alive with no
// script work per frame. `gain` > 1 lets the hottest parts bloom.

uniform float gain = 1.15;

varying vec4 vcol;   // the vertex colour (row dimming); fragment COLOR already includes the texture

void vertex() {
	vcol = COLOR;
}

void fragment() {
	float tip = 1.0 - UV.y;   // UV.y: 0 at the flame tips, 1 at the base
	float sway = sin(TIME * 2.4 + FRAGCOORD.x * 0.021 + UV.y * 7.0) * 0.006 * tip;
	vec4 c = texture(TEXTURE, UV + vec2(sway, 0.0));
	float flick = 0.88 + 0.12 * sin(TIME * 6.1 + FRAGCOORD.x * 0.027) * sin(TIME * 3.3 + FRAGCOORD.y * 0.019);
	COLOR = vec4(c.rgb * gain * flick * vcol.rgb, c.a * vcol.a);
}
