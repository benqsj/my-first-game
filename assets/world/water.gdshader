shader_type spatial;

// The mere's surface: dark and still, clearer where it is shallow, with two
// slow ripple maps sliding over each other so it never quite settles.
//
// How deep the water is at a pixel is read off the depth buffer rather than
// worked out from the terrain, so it is right over anything standing in the
// water — the island's shore, a post, a player's boots — without this knowing
// what any of them are.

render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;
uniform sampler2D ripple_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ripple_b : hint_normal, filter_linear_mipmap, repeat_enable;

uniform vec3 shallow_color : source_color = vec3(0.17, 0.2, 0.17);
uniform vec3 deep_color : source_color = vec3(0.025, 0.04, 0.045);
// Metres of water it takes to hide the bed completely.
uniform float murk = 1.6;
uniform float ripple_scale = 0.045;
uniform float ripple_speed = 0.012;
uniform float ripple_strength = 0.35;
// A lighter rim where the water meets something, in metres.
uniform float edge_width = 0.12;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	behind.xyz /= behind.w;
	// Water between this pixel of the surface and whatever is under it, along
	// the view ray.
	float thickness = max(VERTEX.z - behind.z, 0.0);
	float murkiness = clamp(thickness / murk, 0.0, 1.0);

	vec2 uv = world_pos.xz * ripple_scale;
	vec3 n1 = texture(ripple_a, uv + vec2(TIME * ripple_speed, TIME * ripple_speed * 0.4)).rgb;
	vec3 n2 = texture(ripple_b, uv * 1.7 - vec2(TIME * ripple_speed * 0.6, -TIME * ripple_speed)).rgb;
	NORMAL_MAP = mix(n1, n2, 0.5);
	NORMAL_MAP_DEPTH = ripple_strength;

	float rim = 1.0 - smoothstep(0.0, edge_width, thickness);
	ALBEDO = mix(shallow_color, deep_color, murkiness) + vec3(0.08) * rim;
	ALPHA = mix(0.45, 0.94, murkiness);
	ROUGHNESS = 0.07;
	SPECULAR = 0.55;
	METALLIC = 0.0;
}
