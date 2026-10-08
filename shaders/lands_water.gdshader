shader_type spatial;

// The rivers and lakes of the lands round the core ([Lands]).
//
// One surface over every wet cell, at the water's own level (it falls down the
// rivers, and down the falls as a sheet). `flow_tex` says, per metre, which way
// the water runs (rg, 0.5 = still), whether it is glacial (b: turquoise) and
// how broken it is (a: falls and rapids, drawn as foam). The ripples are slid
// along the flow in two phases half a cycle apart and cross-faded, so the
// water runs without the pattern ever stretching out. How deep it is at a
// pixel comes from the depth buffer, as the mere's water.gdshader does.

render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;
uniform sampler2D flow_tex : filter_linear, repeat_disable;
uniform sampler2D ripple_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ripple_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 origin = vec2(-300.0, -470.0);
uniform vec2 grid_size = vec2(601.0, 891.0);
uniform float cell = 1.0;

uniform vec3 fresh_shallow : source_color = vec3(0.24, 0.32, 0.27);
uniform vec3 fresh_deep : source_color = vec3(0.06, 0.12, 0.12);
uniform vec3 glacial_shallow : source_color = vec3(0.36, 0.70, 0.68);
uniform vec3 glacial_deep : source_color = vec3(0.04, 0.32, 0.38);
uniform vec3 foam_color : source_color = vec3(0.92, 0.95, 0.96);
uniform vec3 sky_tint : source_color = vec3(0.58, 0.64, 0.68);
uniform float murk = 1.8;
uniform float ripple_scale = 0.06;
uniform float ripple_strength = 0.45;
// How far (in ripple-map units) the pattern is carried in one cycle, and how
// long a cycle lasts (s).
uniform float flow_reach = 0.35;
uniform float flow_cycle = 2.2;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	behind.xyz /= behind.w;
	float thickness = max(VERTEX.z - behind.z, 0.0);
	float murkiness = clamp(thickness / murk, 0.0, 1.0);

	vec2 cell_uv = ((world_pos.xz - origin) / cell + 0.5) / grid_size;
	vec4 f = texture(flow_tex, cell_uv);
	vec2 dir = (f.rg - 0.5) * 2.0;
	float moving = clamp(length(dir) * 2.5, 0.0, 1.0);
	float glacial = f.b;
	float broken = f.a;

	vec2 uv = world_pos.xz * ripple_scale;
	float p0 = fract(TIME / flow_cycle);
	float p1 = fract(TIME / flow_cycle + 0.5);
	float blend = abs(p0 * 2.0 - 1.0);
	vec2 d = dir * flow_reach;
	vec3 fa = mix(texture(ripple_a, uv - d * p0).rgb, texture(ripple_a, uv - d * p1 + 0.37).rgb, blend);
	vec3 fb = mix(texture(ripple_b, uv * 1.9 - d * 1.6 * p0).rgb, texture(ripple_b, uv * 1.9 - d * 1.6 * p1 + 0.61).rgb, blend);
	// still water: the mere's two slow drifts
	vec3 sa = texture(ripple_a, uv + vec2(TIME * 0.012, TIME * 0.005)).rgb;
	vec3 sb = texture(ripple_b, uv * 1.7 - vec2(TIME * 0.007, -TIME * 0.012)).rgb;
	NORMAL_MAP = mix(mix(sa, sb, 0.5), mix(fa, fb, 0.5), moving);
	NORMAL_MAP_DEPTH = ripple_strength * (1.0 + moving * 0.6 + broken * 1.5);

	vec3 shallow = mix(fresh_shallow, glacial_shallow, glacial);
	vec3 deep = mix(fresh_deep, glacial_deep, glacial);
	vec3 col = mix(shallow, deep, murkiness);
	// foam: on the falls and rapids, and a thin lace where running water meets the bank
	float lace = (1.0 - smoothstep(0.0, 0.12, thickness)) * moving;
	float streak = mix(fa.r, fb.g, 0.5);
	float foam = clamp(broken * 1.4 + lace * 0.25 * moving, 0.0, 1.0) * smoothstep(0.35, 0.6, streak + broken * 0.5);
	// at a grazing look the water shows the sky, not its own dark depth
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 4.0);
	col = mix(col, sky_tint, fres * 0.65);
	col = mix(col, foam_color, foam);
	ALBEDO = col;
	ALPHA = clamp(mix(0.5, 0.95, murkiness) + foam * 0.5 + broken * 0.3, 0.0, 1.0);
	ROUGHNESS = mix(0.06, 0.4, foam);
	SPECULAR = 0.55;
	METALLIC = 0.0;
}
