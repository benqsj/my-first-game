// The glade's floor (2026-10-23): scanned moss, wet forest mud and fallen
// leaves (Poly Haven, CC0) mixed by large soft patches; the mud glistens.
shader_type spatial;

uniform sampler2D moss_col : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_col : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaf_col : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaf_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D patches : filter_linear, repeat_enable;   // a soft seamless noise
uniform float moss_scale = 0.28;
uniform float mud_scale = 0.22;
uniform float leaf_scale = 0.3;
uniform float mud_amount = 0.5;
uniform float leaf_amount = 0.45;
uniform vec2 centre = vec2(0.0);
uniform float trodden_r = 18.0;  // the glade's middle, worn to mud
uniform vec4 moss_tint : source_color = vec4(1.0);

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 nrm(sampler2D t, vec2 uv) {
	vec3 n = texture(t, uv).xyz * 2.0 - 1.0;
	n.z = sqrt(max(0.0, 1.0 - dot(n.xy, n.xy)));
	return n;
}

void fragment() {
	vec2 p = wp.xz;
	float a = texture(patches, p * 0.012).r;
	float b = texture(patches, p * 0.041 + vec2(0.37, 0.71)).r;
	float d = length(p - centre);
	float worn = 1.0 - smoothstep(trodden_r * 0.4, trodden_r, d);
	float mud = smoothstep(0.55, 0.7, a * 0.7 + b * 0.3 + worn * 0.3 + (mud_amount - 0.45));
	float leaf = smoothstep(0.5, 0.68, (1.0 - a) * 0.5 + b * 0.5 + (leaf_amount - 0.35)) * (1.0 - mud);
	vec3 c = texture(moss_col, p * moss_scale).rgb * moss_tint.rgb;
	vec3 n = nrm(moss_nor, p * moss_scale);
	float r = 0.92;
	c = mix(c, texture(leaf_col, p * leaf_scale).rgb, leaf);
	n = mix(n, nrm(leaf_nor, p * leaf_scale), leaf);
	vec3 mc = texture(mud_col, p * mud_scale).rgb * vec3(0.6, 0.48, 0.36);
	// puddles in the lowest of the mud
	float wet = smoothstep(0.82, 0.95, a * 0.6 + b * 0.4 + worn * 0.15) * mud;
	c = mix(c, mc, mud);
	n = normalize(mix(n, nrm(mud_nor, p * mud_scale), mud));
	n = normalize(mix(n, vec3(0.0, 0.0, 1.0), wet * 0.85));
	r = mix(r, 0.42, mud);
	r = mix(r, 0.14, wet);
	c *= 1.0 - wet * 0.35;
	ALBEDO = c;
	ROUGHNESS = r;
	SPECULAR = 0.5;
	NORMAL_MAP = n * 0.5 + 0.5;
}
