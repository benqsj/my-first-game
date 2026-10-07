shader_type spatial;
// NecroPOLY's one palette texture, either as the kit has it (`ours` = 0) or
// brought into our wood (`ours` = 1): a little drained and darker, warmer,
// and moss on whatever faces the sky, in patches. F9 flips it ([NecroPlaces]).

uniform sampler2D palette : source_color, filter_linear_mipmap;
uniform float ours : hint_range(0.0, 1.0) = 1.0;
uniform vec3 tint : source_color = vec3(0.86, 0.85, 0.70);
uniform float drain : hint_range(0.0, 1.0) = 0.38;
uniform float darken : hint_range(0.0, 1.5) = 0.72;
// how much of the kit's near-white is taken down (its stone reads as plaster)
uniform float tame_white : hint_range(0.0, 1.0) = 0.38;
uniform vec3 moss : source_color = vec3(0.20, 0.25, 0.11);
uniform float moss_amount : hint_range(0.0, 1.0) = 0.65;
uniform float grime : hint_range(0.0, 1.0) = 0.35;

varying vec3 world_normal;
varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = texture(palette, UV).rgb;
	vec3 o = c;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	o = mix(c, vec3(l), drain) * tint * darken;
	o *= 1.0 - tame_white * smoothstep(0.5, 0.95, l);
	float n = noise(world_pos.xz * 0.45) * 0.6 + noise(world_pos.xz * 2.1 + world_pos.y) * 0.4;
	float up = smoothstep(0.45, 0.92, normalize(world_normal).y);
	float m = up * smoothstep(0.38, 0.68, n) * moss_amount;
	// streaks of damp down the walls
	float streak = noise(vec2(world_pos.x * 3.0 + world_pos.z * 3.0, world_pos.y * 0.4));
	o *= 1.0 - grime * streak * (1.0 - up);
	o = mix(o, moss * (0.75 + 0.5 * n), m);
	ALBEDO = mix(c, o, ours);
	ROUGHNESS = 0.93;
	SPECULAR = 0.3;
}
