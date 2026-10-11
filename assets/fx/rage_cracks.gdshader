shader_type spatial;
// The ogre enraged (2026-10-11, the user's word: its second phase must show):
// molten cracks through its skin — voronoi cell edges in the body's own
// space, glowing and breathing — and a hot rim. An additive overlay.
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 glow : source_color = vec4(1.0, 0.25, 0.05, 1.0);
uniform float cell = 6.0;       // cells per metre (body space)
uniform float width = 0.07;    // the crack's half-width (cell units)
uniform float strength = 2.6;
uniform float rim = 0.35;
uniform float beat = 1.0;       // set from script: the rage's pulse

varying vec3 body_pos;

void vertex() {
	body_pos = VERTEX;
}

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123);
}

// distance to the nearest voronoi edge
float edge(vec3 x) {
	vec3 n = floor(x);
	vec3 f = fract(x);
	vec3 mr;
	float md = 8.0;
	for (int k = -1; k <= 1; k++)
	for (int j = -1; j <= 1; j++)
	for (int i = -1; i <= 1; i++) {
		vec3 g = vec3(float(i), float(j), float(k));
		vec3 r = g + hash3(n + g) - f;
		float d = dot(r, r);
		if (d < md) { md = d; mr = r; }
	}
	md = 8.0;
	for (int k = -1; k <= 1; k++)
	for (int j = -1; j <= 1; j++)
	for (int i = -1; i <= 1; i++) {
		vec3 g = vec3(float(i), float(j), float(k));
		vec3 r = g + hash3(n + g) - f;
		if (dot(mr - r, mr - r) > 0.00001)
			md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
	}
	return md;
}

void fragment() {
	float e = edge(body_pos * cell);
	float crack = 1.0 - smoothstep(width * 0.4, width, e);
	// not every edge burns: patches of it, slowly shifting
	float patchy = smoothstep(0.15, 0.55, hash3(floor(body_pos * cell * 0.4)).x);
	float breathe = 0.65 + 0.35 * sin(TIME * 3.0 + body_pos.y * 4.0);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 c = glow.rgb * (crack * patchy * strength * breathe * beat + fres * rim * beat);
	ALBEDO = c;
}
