// The forest's realistic surfaces (2026-10-23): scanned textures (Poly Haven,
// CC0) laid on in world space from three sides, so the Blender shapes need
// no UVs, with moss growing over whatever faces the sky.
shader_type spatial;
render_mode cull_back;

uniform sampler2D base_col : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D moss_col : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 moss_tint : source_color = vec4(1.0);
uniform float scale = 0.35;       // tiles per metre
uniform float moss_scale = 0.25;
uniform float moss_amount = 0.8;  // 0 none .. 1 lots
uniform float moss_up = 0.45;     // how much a face must look up to get moss
uniform float moss_low = 0.0;     // extra moss near the ground, under this height (world, above the floor)
uniform float floor_y = 0.0;
uniform float normal_depth = 1.0;

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tri_nb(vec3 n, vec3 bw, vec3 p, float s) {
	vec3 tx = texture(base_nor, p.zy * s).xyz * 2.0 - 1.0;
	vec3 ty = texture(base_nor, p.xz * s).xyz * 2.0 - 1.0;
	vec3 tz = texture(base_nor, p.xy * s).xyz * 2.0 - 1.0;
	// (imported as normal maps the blue may be gone: rebuild it)
	tx.z = sqrt(max(0.0, 1.0 - dot(tx.xy, tx.xy)));
	ty.z = sqrt(max(0.0, 1.0 - dot(ty.xy, ty.xy)));
	tz.z = sqrt(max(0.0, 1.0 - dot(tz.xy, tz.xy)));
	tx.xy *= normal_depth; ty.xy *= normal_depth; tz.xy *= normal_depth;
	// whiteout blend
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * bw.x + ty.xzy * bw.y + tz.xyz * bw.z);
}

vec3 tri_nm(vec3 n, vec3 bw, vec3 p, float s) {
	vec3 tx = texture(moss_nor, p.zy * s).xyz * 2.0 - 1.0;
	vec3 ty = texture(moss_nor, p.xz * s).xyz * 2.0 - 1.0;
	vec3 tz = texture(moss_nor, p.xy * s).xyz * 2.0 - 1.0;
	// (imported as normal maps the blue may be gone: rebuild it)
	tx.z = sqrt(max(0.0, 1.0 - dot(tx.xy, tx.xy)));
	ty.z = sqrt(max(0.0, 1.0 - dot(ty.xy, ty.xy)));
	tz.z = sqrt(max(0.0, 1.0 - dot(tz.xy, tz.xy)));
	tx.xy *= normal_depth; ty.xy *= normal_depth; tz.xy *= normal_depth;
	// whiteout blend
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * bw.x + ty.xzy * bw.y + tz.xyz * bw.z);
}

#define TRI(t, s) (texture(t, wp.zy * (s)) * bw.x + texture(t, wp.xz * (s)) * bw.y + texture(t, wp.xy * (s)) * bw.z)

void fragment() {
	vec3 n = normalize(wn);
	vec3 bw = pow(abs(n), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec3 col = TRI(base_col, scale).rgb * tint.rgb;
	float rough = texture(base_rough, wp.zy * scale).g * bw.x + texture(base_rough, wp.xz * scale).g * bw.y
			+ texture(base_rough, wp.xy * scale).g * bw.z;
	vec3 nw = tri_nb(n, bw, wp, scale);
	// moss: on what faces up, broken up by its own texture at a large scale
	float var = texture(moss_col, wp.xz * 0.045).g;
	float up = nw.y * 0.75 + n.y * 0.25;
	float low = moss_low > 0.0 ? (1.0 - smoothstep(0.0, moss_low, wp.y - floor_y)) * 0.6 : 0.0;
	float m = smoothstep(moss_up - 0.18, moss_up + 0.18, up + (var - 0.4) * 0.9 + low) * moss_amount;
	vec3 mcol = TRI(moss_col, moss_scale).rgb * moss_tint.rgb;
	vec3 mn = tri_nm(n, bw, wp, moss_scale);
	col = mix(col, mcol, m);
	nw = normalize(mix(nw, mn, m));
	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.95, m);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
