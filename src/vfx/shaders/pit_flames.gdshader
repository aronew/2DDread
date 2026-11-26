shader_type canvas_item;
render_mode unshaded;
// Painted soul-fire strips standing along chasm walls (PitFire). The texture holds
// four flame strips side by side, each faded at its base and sides. A gentle sway
// (stronger toward the tips) and flicker driven by TIME keep it alive with no
// script work per frame. `gain` > 1 lets the hottest parts bloom.

uniform float gain = 1.15;

void fragment() {
	float tip = 1.0 - UV.y;   // UV.y: 0 at the flame tips, 1 at the base
	float sway = sin(TIME * 2.4 + FRAGCOORD.x * 0.021 + UV.y * 7.0) * 0.006 * tip;
	vec4 c = texture(TEXTURE, UV + vec2(sway, 0.0));
	float flick = 0.88 + 0.12 * sin(TIME * 6.1 + FRAGCOORD.x * 0.027) * sin(TIME * 3.3 + FRAGCOORD.y * 0.019);
	COLOR = vec4(c.rgb * gain * flick, c.a);
}
