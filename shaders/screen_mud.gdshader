// Mud over the screen (ScreenMud): up to sixteen ragged splats, thick and
// wet-shining in the middle, dripping, and round them the view smeared and
// blurred as through a dirty glass; a brown film over the whole screen while
// there is much of it.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 blobs[16];   // xy centre (0-1 of the screen), z radius (of its height), w strength
uniform float seeds[16];
uniform int count = 0;
uniform float aspect = 1.7778;
uniform float film = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
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
	float smear = 0.0;
	vec2 push = vec2(0.0);
	for (int i = 0; i < 16; i++) {
		if (i >= count) { break; }
		vec4 b = blobs[i];
		float sd = seeds[i];
		vec2 d = (uv - b.xy) * vec2(aspect, 1.0);
		float r = max(b.z, 0.001);
		float wobble = fbm(d / r * 1.6 + sd) - 0.5;
		float dist = length(d) / r + wobble * 0.55;
		float body = 1.0 - smoothstep(0.55, 0.95, dist);
		float depth = body * (0.6 + 0.4 * (1.0 - smoothstep(0.0, 0.7, dist)));
		float lane = d.x / r;
		float drip = 0.0;
		for (int k = 0; k < 3; k++) {
			float x0 = (hash(vec2(sd, float(k))) - 0.5) * 1.2;
			float len = 0.8 + 1.8 * hash(vec2(float(k), sd + 3.0));
			float w = 0.09 * (1.0 - smoothstep(0.0, len, d.y / r));
			float along = step(0.0, d.y) * (1.0 - smoothstep(len * 0.8, len, d.y / r));
			drip = max(drip, (1.0 - smoothstep(w * 0.5, w, abs(lane - x0))) * along);
		}
		// Round drops thrown off round it: one maybe in each cell of a grid.
		vec2 g = d / r * 4.0 + sd;
		vec2 cell = floor(g);
		vec2 at = vec2(hash(cell), hash(cell + 7.3)) * 0.6 + 0.2;
		float size = 0.07 + 0.16 * hash(cell + 3.1);
		float on = step(0.5, hash(cell + 11.0));
		float fleck = on * (1.0 - smoothstep(size * 0.75, size, length(fract(g) - at)))
				* (1.0 - smoothstep(1.0, 2.0, length(d) / r)) * step(0.85, length(d) / r);
		thick = max(thick, max(depth, max(drip * 0.85, fleck * 0.75)) * b.w);
		// Round the splat the glass is smeared: the view blurred and pushed.
		float halo = (1.0 - smoothstep(0.7, 2.2, dist)) * b.w;
		smear = max(smear, halo);
		push += normalize(d + 0.0001) * halo * 0.012;
	}
	float grain = fbm(sp * 9.0);
	vec3 dark = vec3(0.08, 0.05, 0.025);
	vec3 brown = vec3(0.27, 0.17, 0.08);
	vec3 mud = mix(dark, brown, grain * 0.8 + 0.1);
	float sheen = smoothstep(0.65, 1.0, thick) * smoothstep(0.55, 0.8, fbm(sp * 4.0 + 7.0));
	mud += vec3(0.24, 0.2, 0.14) * sheen * 0.65;
	// Behind: the view, blurred where smeared and browned.
	float streaks = fbm(vec2(sp.x * 3.0, sp.y * 14.0));
	float s_all = clamp(smear + film * 0.35 * streaks, 0.0, 1.0);
	vec3 view = textureLod(screen_tex, SCREEN_UV + push, s_all * 4.0).rgb;
	view = mix(view, view * vec3(0.62, 0.5, 0.36), s_all * 0.8);
	float mud_a = smoothstep(0.02, 0.35, thick) * 0.97;
	vec3 col = mix(view, mud, mud_a);
	COLOR = vec4(col, max(mud_a, s_all));
}
