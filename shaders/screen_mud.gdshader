// Mud over the screen (ScreenMud): up to twelve ragged splats, each dripping,
// thick in the middle and wet-shining, thinning to a ragged rim.
shader_type canvas_item;

uniform vec4 blobs[12];   // xy centre (0-1 of the screen), z radius (of its height), w strength
uniform float seeds[12];
uniform int count = 0;
uniform float aspect = 1.7778;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
// Value noise with a quintic fade: no grid showing through.
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int o = 0; o < 4; o++) {
		v += a * noise(p);
		p = turn * p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 sp = uv * vec2(aspect, 1.0);
	float thick = 0.0;
	for (int i = 0; i < 12; i++) {
		if (i >= count) { break; }
		vec4 b = blobs[i];
		float sd = seeds[i];
		vec2 d = (uv - b.xy) * vec2(aspect, 1.0);
		float r = max(b.z, 0.001);
		// The rim wanders with a smooth noise round the splat and in and out.
		float wobble = fbm(d / r * 1.6 + sd) - 0.5;
		float dist = length(d) / r + wobble * 0.55;
		float body = 1.0 - smoothstep(0.55, 0.95, dist);
		// Thicker towards the middle.
		float depth = body * (0.6 + 0.4 * (1.0 - smoothstep(0.0, 0.7, dist)));
		// A couple of runs from its lower edge (y grows downwards on the screen).
		float lane = d.x / r;
		float drip = 0.0;
		for (int k = 0; k < 2; k++) {
			float x0 = (hash(vec2(sd, float(k))) - 0.5) * 1.1;
			float len = 0.6 + 1.4 * hash(vec2(float(k), sd + 3.0));
			float w = 0.08 * (1.0 - smoothstep(0.0, len, d.y / r));
			float along = step(0.0, d.y) * (1.0 - smoothstep(len * 0.8, len, d.y / r));
			drip = max(drip, (1.0 - smoothstep(w * 0.5, w, abs(lane - x0))) * along);
		}
		// A few flecks thrown off it.
		float fleck = smoothstep(0.78, 0.84, noise(d / r * 7.0 + sd * 5.0))
				* (1.0 - smoothstep(1.0, 1.7, length(d) / r)) * step(0.9, length(d) / r);
		thick = max(thick, max(depth, max(drip * 0.8, fleck * 0.7)) * b.w);
	}
	float grain = fbm(sp * 9.0);
	vec3 dark = vec3(0.09, 0.06, 0.03);
	vec3 brown = vec3(0.27, 0.18, 0.09);
	vec3 col = mix(dark, brown, grain * 0.8 + 0.1);
	// Wet: a soft sheen where it lies thick, broken up by the grain.
	float sheen = smoothstep(0.65, 1.0, thick) * smoothstep(0.55, 0.8, fbm(sp * 4.0 + 7.0));
	col += vec3(0.22, 0.18, 0.13) * sheen * 0.6;
	float alpha = smoothstep(0.02, 0.35, thick) * 0.96;
	COLOR = vec4(col, alpha);
}
