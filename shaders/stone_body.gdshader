// Drawn over a creature of the marble world (its material_overlay; StoneCrack,
// 2026-10-30): it cracks where a blow lands and only there, along a net of
// cells laid in the model's rest pose (so it stays on the body as it moves);
// struck again there the cracks open further, and a cell hurt enough breaks
// off whole, showing wet blood under it. At its death a wave of cracks runs
// over all of it from where it was last struck ([MarbleShatter] then breaks
// it apart along this same net).
//
// `rest` holds each corner's place in the rest pose (metres, by VERTEX_ID);
// a GLSL twin of [method StoneCrack.cell_of] / [method StoneCrack.hurt_at]
// decides the same cells on the CPU.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

const int MOST = 24;
uniform sampler2D rest : filter_nearest;
uniform int rest_w = 256;
// the blows: rest place and reach (w); how hard (power)
uniform vec4 hit_at[MOST];
uniform float hit_power[MOST];
uniform int hit_count = 0;
// its death: cracks run out from `wave_from` to `wave_reach`
uniform vec3 wave_from = vec3(0.0);
uniform float wave_reach = -1.0;
// a piece's size, metres
uniform float cell = 0.26;
uniform vec4 seam : source_color = vec4(0.06, 0.02, 0.018, 1.0);
uniform vec4 blood : source_color = vec4(0.42, 0.015, 0.012, 1.0);
uniform vec4 blood_dark : source_color = vec4(0.16, 0.0, 0.0, 1.0);

varying vec3 rp;

// an integer hash of a cell (pcg3d): the same on the CPU (StoneCrack.h3)
vec3 h3(vec3 c) {
	uvec3 v = uvec3(ivec3(floor(c + 0.5)) + 65536);
	v = v * 1664525u + 1013904223u;
	v.x += v.y * v.z; v.y += v.z * v.x; v.z += v.x * v.y;
	v ^= v >> 16u;
	v.x += v.y * v.z; v.y += v.z * v.x; v.z += v.x * v.y;
	return vec3(v) / 4294967295.0;
}

float hurt_at(vec3 p) {
	float h = 0.0;
	for (int k = 0; k < MOST; k++) {
		if (k >= hit_count) {
			break;
		}
		float d = distance(p, hit_at[k].xyz) / hit_at[k].w;
		h += hit_power[k] * pow(clamp(1.0 - d, 0.0, 1.0), 0.7);
	}
	if (wave_reach > 0.0) {
		h += 0.42 * clamp((wave_reach - distance(p, wave_from)) / 0.35, 0.0, 1.0);
	}
	return h;
}

void vertex() {
	rp = texelFetch(rest, ivec2(VERTEX_ID % rest_w, VERTEX_ID / rest_w), 0).xyz;
}

void fragment() {
	float here = hurt_at(rp);
	if (here < 0.02) {
		discard;
	}
	vec3 p = rp / cell;
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 9.0;
	float d2 = 9.0;
	vec3 c1 = vec3(0.0);
	vec3 c2 = vec3(0.0);
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 r = g + h3(i + g) - f;
				float d = dot(r, r);
				if (d < d1) {
					d2 = d1; c2 = c1;
					d1 = d; c1 = i + g;
				} else if (d < d2) {
					d2 = d; c2 = i + g;
				}
			}
		}
	}
	float edge = sqrt(d2) - sqrt(d1);
	float r1 = h3(c1 + 17.0).x;
	float r2 = h3(c2 + 17.0).x;
	// a crack along this border once it is hurt enough, each border its own share
	float share = fract(r1 * 7.13 + r2 * 3.71);
	float open = step(share, here * 2.4 - 0.1);
	float px = fwidth(edge);
	float line = (1.0 - smoothstep(px * 0.8, px * 2.2, edge)) * open;
	// a whole cell broken off: judged at its own middle, so it goes whole
	vec3 mid = (c1 + h3(c1)) * cell;
	float broken = step(0.6, hurt_at(mid) + (r1 - 0.5) * 0.3);
	float a = max(broken, line);
	if (a < 0.02) {
		discard;
	}
	if (broken > 0.5) {
		// wet blood, darker in the hollow, a dark rim where it broke
		float hollow = clamp(edge * 2.2, 0.0, 1.0);
		vec3 b = mix(blood.rgb, blood_dark.rgb, 0.35 + 0.4 * hollow + 0.2 * r1);
		float rim = 1.0 - smoothstep(px * 1.2, px * 3.5, edge);
		ALBEDO = mix(b, seam.rgb, rim * 0.8);
		ROUGHNESS = 0.22;
		SPECULAR = 0.7;
	} else {
		ALBEDO = seam.rgb;
		ROUGHNESS = 1.0;
	}
	ALPHA = a;
}
