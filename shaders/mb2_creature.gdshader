// Monster Bundle 2's creatures (Mb2Creature, 2026-10-31). The pack colours
// each face by where its UV falls in a 7x7 palette (one png per colour set).
// Two paints (the user's word, 2026-10-31): the pack's own ("default"), and
// ours ("my-color"): each face flat, its own colour, the palette muted and a
// touch warm, as the forest and the marble world are.
shader_type spatial;
render_mode cull_back;

uniform sampler2D palette : source_color, filter_nearest;
uniform bool mine = false;
uniform float mine_sat = 0.6;     // how much of the pack's colour is kept
uniform float mine_bright = 0.95;
uniform vec3 mine_tint : source_color = vec3(1.0, 0.96, 0.9);

void fragment() {
	vec3 c = texture(palette, UV).rgb;
	if (mine) {
		float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
		c = mix(vec3(l), c, mine_sat) * mine_tint * mine_bright;
		// each face flat: its normal from the face itself
		NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		ROUGHNESS = 0.9;
		SPECULAR = 0.3;
		RIM = 0.15;
		RIM_TINT = 0.6;
	} else {
		ROUGHNESS = 0.75;
		SPECULAR = 0.4;
	}
	ALBEDO = c;
}
