shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// The ground, blended from what the land is doing where it is drawn:
//  * grass, in two or three greens, with drier yellowing patches;
//  * bare earth on the worn tracks (vertex alpha < 1) and on the steeper banks;
//  * rock where a slope is too steep to hold soil;
//  * the marsh strips tint their own vertex colour darker towards the water:
//    that darkening is read as wet mud.
// `realistic` off: painted flat colours, broken up by noise (the house style).
// `realistic` on: photographed CC0 textures (ambientCG, Poly Haven), laid in
// world space, a second, turned sampling of each blended in to hide the tile.

uniform bool realistic = false;

// house style
uniform vec3 grass_a : source_color = vec3(0.20, 0.30, 0.10);
uniform vec3 grass_b : source_color = vec3(0.33, 0.42, 0.14);
uniform vec3 grass_dry : source_color = vec3(0.52, 0.48, 0.24);
uniform vec3 earth : source_color = vec3(0.40, 0.30, 0.19);
uniform vec3 rock : source_color = vec3(0.44, 0.43, 0.40);
uniform vec3 mud : source_color = vec3(0.20, 0.16, 0.11);
uniform sampler2D mottle : filter_linear_mipmap, repeat_enable;      // the old ground's colour noise
uniform sampler2D bump : hint_normal, filter_linear_mipmap, repeat_enable;

// realistic
uniform sampler2D t_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_grass : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_meadow : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_meadow : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_dry : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_dry : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_earth : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_earth : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_rock : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_mud : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_mud : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile = 4.0;          // metres per repeat of a texture
uniform float real_tint = 0.8;     // how far the photos are pulled towards the scene's light

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// A tangent frame that follows the world's x and z, so maps laid in world
	// space bend the light the right way.
	TANGENT = normalize(vec3(1.0, 0.0, 0.0) - NORMAL * NORMAL.x);
	BINORMAL = normalize(cross(TANGENT, NORMAL));
}

float n2(vec2 p) {
	return texture(mottle, p).g;
}

// A texture sampled twice, the second time turned and scaled, mixed by a slow
// noise: no two tiles of it read alike from a distance.
vec4 untiled(sampler2D t, vec2 uv, float mixer) {
	vec2 uv2 = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * uv * 0.63 + vec2(0.37, 0.71);
	return mix(texture(t, uv), texture(t, uv2), smoothstep(0.3, 0.7, mixer));
}

void fragment() {
	vec2 xz = wpos.xz;
	float slope = 1.0 - clamp(wnrm.y, 0.0, 1.0);
	float macro = n2(xz * 0.0045);
	float mid = n2(xz * 0.021 + vec2(0.3, 0.7));
	float fine = n2(xz * 0.11);

	// where what grows
	float dry = smoothstep(0.52, 0.72, n2(xz * 0.009 + vec2(0.61, 0.13)) + slope * 0.35);
	float track = 1.0 - COLOR.a;
	float bank = smoothstep(0.24, 0.4, slope + (mid - 0.5) * 0.12);
	float earthy = max(track, bank * 0.8);
	float stony = smoothstep(0.42, 0.58, slope + (fine - 0.5) * 0.1);
	float wet = clamp(1.0 - dot(COLOR.rgb, vec3(0.333)), 0.0, 1.0) * 3.0;
	wet = clamp(wet, 0.0, 1.0);

	vec3 alb;
	vec3 nrm = vec3(0.5, 0.5, 1.0);
	float rough = 0.95;
	if (!realistic) {
		vec3 g = mix(grass_a, grass_b, smoothstep(0.35, 0.7, macro));
		g *= 0.85 + 0.3 * mid;
		g = mix(g, grass_dry * (0.9 + 0.2 * fine), dry * 0.75);
		alb = mix(g, earth * (0.85 + 0.3 * fine), earthy);
		alb = mix(alb, rock * (0.8 + 0.4 * fine), stony);
		alb = mix(alb, mud, wet);
		nrm = texture(bump, xz * 0.05).rgb;
		rough = 1.0;
	} else {
		vec2 uv = xz / tile;
		float mixer = macro;
		vec3 ga = untiled(t_grass, uv, mixer).rgb;
		vec3 gb = untiled(t_meadow, uv * 0.5, mixer).rgb;
		vec3 g = mix(ga, gb, smoothstep(0.4, 0.75, mid));
		vec3 d = untiled(t_dry, uv * 0.8, mixer).rgb * vec3(1.25, 1.08, 0.55);  // the same grass, gone to hay
		vec3 e = untiled(t_earth, uv * 0.9, mixer).rgb;
		vec3 m = untiled(t_mud, uv, mixer).rgb;
		// rock laid three ways, so a bank does not smear it
		vec3 bw = pow(abs(wnrm), vec3(4.0));
		bw /= (bw.x + bw.y + bw.z);
		vec3 r = texture(t_rock, wpos.zy / tile).rgb * bw.x + texture(t_rock, xz / tile).rgb * bw.y
				+ texture(t_rock, wpos.xy / tile).rgb * bw.z;
		alb = mix(g, d, dry * 0.8);
		alb = mix(alb, e, earthy);
		alb = mix(alb, r, stony);
		alb = mix(alb, m, wet);
		alb *= mix(0.85, 1.12, macro) * real_tint;

		vec3 ng = mix(untiled(n_grass, uv, mixer).rgb, untiled(n_meadow, uv * 0.5, mixer).rgb, smoothstep(0.4, 0.75, mid));
		nrm = mix(ng, untiled(n_dry, uv * 0.8, mixer).rgb, dry * 0.8);
		nrm = mix(nrm, untiled(n_earth, uv * 0.9, mixer).rgb, earthy);
		nrm = mix(nrm, texture(n_rock, xz / tile).rgb, stony);
		nrm = mix(nrm, untiled(n_mud, uv, mixer).rgb, wet);
		rough = mix(0.92, 0.6, wet);
	}
	// hollows a touch darker, crowns a touch lighter
	alb *= clamp(1.0 + wpos.y * 0.012, 0.9, 1.08);
	ALBEDO = alb * COLOR.rgb * mix(vec3(1.0), vec3(1.25), wet);  // the marsh's tint, not doubled on the mud
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = realistic ? 1.0 : 0.7;
	ROUGHNESS = rough;
	SPECULAR = 0.2;
}
