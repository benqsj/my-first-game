shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// The ground as a walker sees it, and cheap: the "new" look (see [Looks]).
//
// Six photographed CC0 grounds, and each pixel only reads the ones that are
// actually there (a weight under a hair and the texture is not touched), one
// sample of colour and, near the camera, one of normal each. The photographed
// look (`terrain_ground` with `realistic`) reads every texture twice over at
// every pixel; this reads two or three, once.
//
//  * forest floor — fallen leaves, twigs and moss — under the trees, from the
//    ground mask's red (where the trunks stand);
//  * grassy ground under the meadows, from the mask's green (where the grass
//    clumps were planted);
//  * bare earth with the odd sprig and leaf everywhere else in the open, so
//    ground with no grass on it still reads as ground rather than as paint;
//  * worn earth on the tracks (vertex alpha < 1) and steep banks, rock where it
//    is too steep for soil, mud where the marsh darkens the vertex colour.
//
// Where two meet they are blended by height — the brighter (higher) of the two
// photographs wins the edge — so leaves lie over earth in drifts and grass
// breaks up in tufts, rather than one fading evenly into the other.
// Repetition is broken by a slow wash of brightness and hue from the old
// ground's noise (one tiny texture), not by sampling everything twice.

uniform sampler2D ground_mask : hint_default_black, filter_linear, repeat_disable; // r wood, g grass
uniform vec4 mask_rect = vec4(-116.0, -452.0, 232.0, 628.0);  // x, z, size x, size z

uniform sampler2D mottle : filter_linear_mipmap, repeat_enable;

uniform sampler2D t_floor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_floor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_grass : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_bare : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_bare : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_earth : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_earth : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_rock : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_mud : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_mud : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

// Metres per repeat, per ground.
uniform float tile_floor = 3.0;
uniform float tile_grass = 3.5;
uniform float tile_bare = 4.0;
uniform float tile_earth = 3.5;
uniform float tile_rock = 5.0;
uniform float tile_mud = 4.0;
// Each photograph pulled towards the scene's light and one another.
uniform vec3 tone_floor : source_color = vec3(0.6, 0.62, 0.5);
uniform vec3 tone_grass : source_color = vec3(0.78, 0.84, 0.66);
uniform vec3 tone_bare : source_color = vec3(0.74, 0.8, 0.68);
uniform vec3 tone_earth : source_color = vec3(0.95, 0.92, 0.88);
uniform vec3 tone_rock : source_color = vec3(0.9, 0.9, 0.9);
uniform vec3 tone_mud : source_color = vec3(0.9, 0.88, 0.85);
// How sharp the height-blended edges are (smaller is sharper).
uniform float blend_depth = 0.18;
// Past this the ground's relief is not read at all: at that distance a pixel
// covers a hand's breadth and the bumps cannot be seen.
uniform float normal_distance = 40.0;
// How much of the open ground grows grass even where no clump stands.
uniform float open_grass = 0.95;

varying vec3 wpos;
varying vec3 wnrm;
varying float view_dist;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	view_dist = length(wpos - CAMERA_POSITION_WORLD);
	TANGENT = normalize(vec3(1.0, 0.0, 0.0) - NORMAL * NORMAL.x);
	BINORMAL = normalize(cross(TANGENT, NORMAL));
}

float lum(vec3 c) {
	return dot(c, vec3(0.3, 0.55, 0.15));
}

void fragment() {
	vec2 xz = wpos.xz;
	float slope = 1.0 - clamp(wnrm.y, 0.0, 1.0);
	float macro = texture(mottle, xz * 0.0045).g;
	float mid = texture(mottle, xz * 0.021 + vec2(0.3, 0.7)).g;

	vec2 muv = (xz - mask_rect.xy) / mask_rect.zw;
	vec2 m = texture(ground_mask, muv).rg;

	// What each ground's share is, before the edges are worked out.
	float track = 1.0 - COLOR.a;
	float bank = smoothstep(0.24, 0.4, slope + (mid - 0.5) * 0.12);
	float earthy = max(track, bank * 0.8);
	float stony = smoothstep(0.42, 0.58, slope + (mid - 0.5) * 0.1);
	float wet = clamp((1.0 - dot(COLOR.rgb, vec3(0.333))) * 3.0, 0.0, 1.0);

	float w_floor = smoothstep(0.22, 0.7, m.r + (mid - 0.5) * 0.25);
	float grassy = max(m.g, open_grass * smoothstep(0.14, 0.44, macro + (mid - 0.5) * 0.5));
	float w_grass = smoothstep(0.1, 0.55, grassy) * (1.0 - w_floor);
	float w_bare = (1.0 - w_floor) * (1.0 - w_grass);
	float keep = (1.0 - earthy) * (1.0 - stony) * (1.0 - wet);
	w_floor *= keep;
	w_grass *= keep;
	w_bare *= keep;
	float w_earth = earthy * (1.0 - stony) * (1.0 - wet);
	float w_rock = stony * (1.0 - wet);
	float w_mud = wet;

	bool near = view_dist < normal_distance;
	// Taken here, outside the branches below: a texture read inside a branch
	// not every pixel takes cannot find its own mip level.
	vec2 gx = dFdx(xz);
	vec2 gy = dFdy(xz);
	// Each ground read only if it is there.
	vec3 c_floor = vec3(0.0), c_grass = vec3(0.0), c_bare = vec3(0.0);
	vec3 c_earth = vec3(0.0), c_rock = vec3(0.0), c_mud = vec3(0.0);
	vec2 n_f = vec2(0.5), n_g = vec2(0.5), n_b = vec2(0.5), n_e = vec2(0.5), n_r = vec2(0.5), n_m = vec2(0.5);
	float cut = 0.004;
	if (w_floor > cut) {
		vec2 uv = xz / tile_floor;
		vec2 ax = gx / tile_floor;
		vec2 ay = gy / tile_floor;
		c_floor = textureGrad(t_floor, uv, ax, ay).rgb * tone_floor;
		if (near) n_f = textureGrad(n_floor, uv, ax, ay).rg;
	}
	if (w_grass > cut) {
		vec2 uv = xz / tile_grass;
		vec2 ax = gx / tile_grass;
		vec2 ay = gy / tile_grass;
		c_grass = textureGrad(t_grass, uv, ax, ay).rgb * tone_grass;
		if (near) n_g = textureGrad(n_grass, uv, ax, ay).rg;
	}
	if (w_bare > cut) {
		vec2 uv = xz / tile_bare;
		vec2 ax = gx / tile_bare;
		vec2 ay = gy / tile_bare;
		c_bare = textureGrad(t_bare, uv, ax, ay).rgb * tone_bare;
		if (near) n_b = textureGrad(n_bare, uv, ax, ay).rg;
	}
	if (w_earth > cut) {
		vec2 uv = xz / tile_earth;
		vec2 ax = gx / tile_earth;
		vec2 ay = gy / tile_earth;
		c_earth = textureGrad(t_earth, uv, ax, ay).rgb * tone_earth;
		if (near) n_e = textureGrad(n_earth, uv, ax, ay).rg;
	}
	if (w_rock > cut) {
		vec2 uv = xz / tile_rock;
		vec2 ax = gx / tile_rock;
		vec2 ay = gy / tile_rock;
		c_rock = textureGrad(t_rock, uv, ax, ay).rgb * tone_rock;
		if (near) n_r = textureGrad(n_rock, uv, ax, ay).rg;
	}
	if (w_mud > cut) {
		vec2 uv = xz / tile_mud;
		vec2 ax = gx / tile_mud;
		vec2 ay = gy / tile_mud;
		c_mud = textureGrad(t_mud, uv, ax, ay).rgb * tone_mud;
		if (near) n_m = textureGrad(n_mud, uv, ax, ay).rg;
	}

	// Height blend: the share plus how high the photograph stands there.
	float h_floor = w_floor + lum(c_floor) * step(cut, w_floor);
	float h_grass = w_grass + lum(c_grass) * step(cut, w_grass);
	float h_bare = w_bare + lum(c_bare) * step(cut, w_bare);
	float h_earth = w_earth + lum(c_earth) * step(cut, w_earth);
	float h_rock = w_rock + lum(c_rock) * step(cut, w_rock);
	float h_mud = w_mud + lum(c_mud) * step(cut, w_mud);
	float top = max(max(max(h_floor, h_grass), max(h_bare, h_earth)), max(h_rock, h_mud)) - blend_depth;
	float b_floor = max(h_floor - top, 0.0) * step(cut, w_floor);
	float b_grass = max(h_grass - top, 0.0) * step(cut, w_grass);
	float b_bare = max(h_bare - top, 0.0) * step(cut, w_bare);
	float b_earth = max(h_earth - top, 0.0) * step(cut, w_earth);
	float b_rock = max(h_rock - top, 0.0) * step(cut, w_rock);
	float b_mud = max(h_mud - top, 0.0) * step(cut, w_mud);
	float sum = max(b_floor + b_grass + b_bare + b_earth + b_rock + b_mud, 0.0001);

	vec3 alb = (c_floor * b_floor + c_grass * b_grass + c_bare * b_bare
			+ c_earth * b_earth + c_rock * b_rock + c_mud * b_mud) / sum;
	// The slow wash that keeps one tile from reading like the next.
	alb *= mix(0.86, 1.1, macro) * mix(vec3(1.0), vec3(1.06, 1.02, 0.9), smoothstep(0.4, 0.8, mid));
	alb *= clamp(1.0 + wpos.y * 0.012, 0.9, 1.08);
	ALBEDO = alb * COLOR.rgb * mix(vec3(1.0), vec3(1.25), wet);

	if (near) {
		vec2 n = (n_f * b_floor + n_g * b_grass + n_b * b_bare + n_e * b_earth + n_r * b_rock + n_m * b_mud) / sum;
		NORMAL_MAP = vec3(n, 1.0);
		NORMAL_MAP_DEPTH = 1.0 - smoothstep(normal_distance * 0.6, normal_distance, view_dist);
	}
	ROUGHNESS = mix(0.95, 0.62, wet);
	SPECULAR = 0.2;
}
