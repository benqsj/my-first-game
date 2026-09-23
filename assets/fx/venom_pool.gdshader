shader_type spatial;

// A pool of venom on the ground. Laid on the modelled splat, whose UVs are a
// flat map of it: the middle is (0.5, 0.5) and its furthest runs reach the
// edge of the square.
//
// * `spread` (0 to 1) is how far it has run out from the middle — the front is
//   ragged, pushed about by noise, so it floods out rather than growing.
// * `dry` (0 to 1) eats it away: the thin edges first, then holes through the
//   rest, and the surface goes from wet and glossy to dull as it does.
// * While it is wet it bubbles: spots come up bright and sink again.
//
// Both are per-instance, so every pool on the ground shares the one material.

render_mode blend_mix, cull_disabled, depth_draw_opaque, specular_schlick_ggx, shadows_disabled;

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 deep_color : source_color = vec3(0.03, 0.1, 0.015);
uniform vec3 body_color : source_color = vec3(0.14, 0.38, 0.04);
uniform vec3 edge_color : source_color = vec3(0.42, 0.78, 0.16);
uniform vec3 glow_color : source_color = vec3(0.22, 0.7, 0.05);

instance uniform float spread = 1.0;
instance uniform float dry = 0.0;
instance uniform float seed = 0.0;

void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;
	vec2 at = UV + vec2(seed * 0.37, seed * 0.61);
	float n = texture(noise_tex, at * 2.5).r;
	float front = spread * 1.05 - r + (n - 0.5) * 0.18;
	if (front < 0.0) {
		discard;
	}
	float keep = 1.0 - r * 0.55 + (n - 0.5) * 0.9 - dry * 1.5;
	if (keep < 0.0) {
		discard;
	}
	// Bubbles: a few cells of a grid each hold one, which swells on its own
	// clock and pops. Drawn as a bright ring round a lighter dome.
	vec2 g = at * 16.0;
	vec2 cell = floor(g);
	float h = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float life = fract(TIME * 0.4 + h * 7.0);
	vec2 f = fract(g) - 0.5 + vec2(h - 0.5, fract(h * 13.7) - 0.5) * 0.35;
	float rad = (0.06 + 0.3 * life) * step(0.72, h);
	float d = length(f);
	float dome = smoothstep(rad, rad * 0.6, d);
	float ring = dome - smoothstep(rad * 0.85, rad * 0.45, d);
	float bubble = (ring * 1.4 + dome * 0.25) * (1.0 - life * life) * step(r, 0.8);
	float rim = smoothstep(0.06, 0.0, min(front, keep * 0.5));
	vec3 col = mix(deep_color, body_color, smoothstep(0.05, 0.75, r) * 0.8 + n * 0.2);
	col = mix(col, edge_color, rim * 0.7);
	col = mix(col, edge_color, clamp(bubble, 0.0, 1.0) * 0.7);
	ALBEDO = col * mix(1.0, 0.55, dry);
	ROUGHNESS = mix(0.05, 0.7, dry);
	SPECULAR = 0.8;
	EMISSION = glow_color * (0.06 + bubble * 0.6 + rim * 0.15) * (1.0 - dry);
	ALPHA = clamp(keep * 5.0, 0.0, 1.0) * 0.95;
}
