shader_type spatial;
// Polysplit's Advanced Weapons as the pack's own shader draws them
// (RGBRecolor_AdvancedWeapons.shadergraph, WEAPONS_PACK.md): the style's
// pre-coloured texture, metal and gloss by the RGB mask's three channels
// (the style's R/G/B Metallic and Smoothness), and for the styles that have
// it (ornate, obsidian) the "imbue" glow: a rim and slow noise moving over
// the weapon in the style's colour.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D mask_tex : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform vec3 metal_rgb = vec3(0.0);
uniform vec3 smooth_rgb = vec3(0.0, 0.4, 0.25);
uniform bool imbue = false;
uniform vec3 imbue_color : source_color = vec3(1.0);
uniform float imbue_strength = 0.5;
uniform vec2 imbue_tiling = vec2(1.0);
uniform float imbue_scroll = 0.5;
uniform float edge_strength = 0.6;
// how bright the glow is in this game's light (the pack's is for Unity's)
uniform float glow_gain = 1.0;

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

// Unity's Simple Noise: value noise, three octaves
float _rand(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float _value(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	f = f * f * (3.0 - 2.0 * f);
	float a = _rand(i);
	float b = _rand(i + vec2(1.0, 0.0));
	float c = _rand(i + vec2(0.0, 1.0));
	float d = _rand(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float _simple_noise(vec2 uv, float scale) {
	float t = 0.0;
	for (int i = 0; i < 3; i++) {
		float freq = pow(2.0, float(i));
		float amp = pow(0.5, float(3 - i));
		t += _value(uv * scale / freq) * amp;
	}
	return t;
}

void fragment() {
	vec4 col = texture(albedo_tex, UV);
	ALBEDO = col.rgb;
	// the mask's lower-right block (the faces' decals) has no metal or gloss
	bool decal = UV.x > 0.505 && UV.x < 0.995 && UV.y > 0.505 && UV.y < 0.745;
	vec3 m = decal ? vec3(0.0) : texture(mask_tex, UV).rgb;
	METALLIC = clamp(dot(m, metal_rgb), 0.0, 1.0);
	ROUGHNESS = clamp(1.0 - dot(m, smooth_rgb), 0.04, 1.0);
	if (imbue) {
		// the pack's fresnel power: EdgeGlowStrength remapped [10, 1] -> [-100, 1]
		float power = -100.0 + (edge_strength - 10.0) * (101.0 / -9.0);
		float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), max(power, 0.5));
		float dodge = clamp(fres / max(1.0 - fres, 1e-3), 0.0, 10.0);
		vec3 rim = dodge * edge_strength * imbue_color + vec3(fres * fres);
		vec2 nuv = vec2(obj_pos.z, obj_pos.y) * imbue_tiling + TIME * vec2(-imbue_scroll, 0.0);
		float n = _simple_noise(nuv, 10.0);
		vec3 glow = n * n * 1.25 * imbue_strength * imbue_color;
		EMISSION = (rim + glow) * glow_gain;
	}
}
