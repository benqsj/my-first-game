shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// The lands round the core ([Lands]): the ground lifted out of a height grid
// and dressed from the v4 map's cover.
//
// The mesh is a flat grid; each vertex is a cell corner and takes its height
// from `height_tex` (one texel a metre, fetched exactly, so the drawn ground is
// the HeightMapShape3D the bodies stand on). UV.x carries the grid's step, for
// the slope; UV.y = 1 marks a skirt vertex, let down under the chunk's edge so
// a coarse chunk next to a fine one shows no crack.
//
// The cover is twelve layers from `splat_a/b/c` (see vepxis-art/map/v4
// export_game.py). Grass is painted the way the core's house-style ground is
// (terrain_ground.gdshader, the same colours and mottle), tinted to each land's
// own green, so the seam with the core does not show.

uniform sampler2D height_tex : filter_nearest, repeat_disable;
uniform sampler2D splat_a : filter_linear, repeat_disable;   // grass, needles, litter, heather
uniform sampler2D splat_b : filter_linear, repeat_disable;   // rock, scree, snow, dirt
uniform sampler2D splat_c : filter_linear, repeat_disable;   // gravel, mud, crop, flowers
uniform sampler2D tint_tex : filter_linear, repeat_disable;   // rgb grass tint x2, a crop id*40
uniform sampler2D crop_tex : filter_nearest, repeat_disable;  // the same, read exactly for the crop id
uniform sampler2D mottle : filter_linear_mipmap, repeat_enable;
uniform sampler2D bump : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 origin = vec2(-300.0, -470.0);
uniform vec2 grid_size = vec2(601.0, 891.0);
// The core, drawn by Terrain and Marsh: nothing of this is drawn inside it.
uniform vec4 core = vec4(-120.0, -455.0, 120.0, 180.0);
uniform float skirt = 1.5;

uniform vec3 grass_a : source_color = vec3(0.20, 0.30, 0.10);
uniform vec3 grass_b : source_color = vec3(0.33, 0.42, 0.14);
uniform vec3 grass_dry : source_color = vec3(0.52, 0.48, 0.24);
uniform vec3 needles : source_color = vec3(0.12, 0.17, 0.11);
uniform vec3 litter : source_color = vec3(0.40, 0.27, 0.14);
uniform vec3 heather : source_color = vec3(0.36, 0.25, 0.37);
uniform vec3 heather_green : source_color = vec3(0.33, 0.35, 0.21);
uniform vec3 rock : source_color = vec3(0.36, 0.35, 0.32);
uniform vec3 scree : source_color = vec3(0.41, 0.39, 0.35);
uniform vec3 snow : source_color = vec3(0.90, 0.92, 0.95);
uniform vec3 dirt : source_color = vec3(0.42, 0.32, 0.20);
uniform vec3 gravel : source_color = vec3(0.45, 0.42, 0.36);
uniform vec3 mud : source_color = vec3(0.26, 0.21, 0.14);
uniform vec3 crop_1 : source_color = vec3(0.70, 0.58, 0.26);  // wheat
uniform vec3 crop_2 : source_color = vec3(0.64, 0.58, 0.36);  // barley
uniform vec3 crop_3 : source_color = vec3(0.30, 0.35, 0.13);  // sunflower (heads in yellow)
uniform vec3 crop_4 : source_color = vec3(0.36, 0.42, 0.17);  // poppy (flecked red)
uniform vec3 crop_5 : source_color = vec3(0.62, 0.58, 0.34);  // hay
uniform vec3 crop_6 : source_color = vec3(0.40, 0.31, 0.20);  // fallow

varying vec3 wpos;
varying vec3 wnrm;

float hat(ivec2 c) {
	c = clamp(c, ivec2(0), ivec2(grid_size) - 1);
	return texelFetch(height_tex, c, 0).r;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ivec2 c = ivec2(round(w.xz - origin));
	int s = max(int(UV.x + 0.5), 1);
	float h = hat(c);
	float hl = hat(c + ivec2(-s, 0));
	float hr = hat(c + ivec2(s, 0));
	float hd = hat(c + ivec2(0, -s));
	float hu = hat(c + ivec2(0, s));
	VERTEX.y = h - UV.y * skirt;
	NORMAL = normalize(vec3(hl - hr, 2.0 * float(s), hd - hu));
	TANGENT = normalize(vec3(1.0, 0.0, 0.0) - NORMAL * NORMAL.x);
	BINORMAL = normalize(cross(TANGENT, NORMAL));
	wpos = vec3(w.x, VERTEX.y, w.z);
	wnrm = NORMAL;
}

float n2(vec2 p) {
	return texture(mottle, p).g;
}

void fragment() {
	vec2 xz = wpos.xz;
	if (xz.x > core.x + 0.01 && xz.x < core.z - 0.01 && xz.y > core.y + 0.01 && xz.y < core.w - 0.01) {
		discard;
	}
	vec2 uv = (xz - origin + 0.5) / grid_size;
	vec4 a = texture(splat_a, uv);
	vec4 b = texture(splat_b, uv);
	vec4 c = texture(splat_c, uv);
	vec4 tint = texture(tint_tex, uv);

	float slope = 1.0 - clamp(wnrm.y, 0.0, 1.0);
	float macro = n2(xz * 0.0045);
	float mid = n2(xz * 0.021 + vec2(0.3, 0.7));
	float fine = n2(xz * 0.11);
	float speck = n2(xz * 0.47 + vec2(0.17, 0.41));

	// grass as the core paints it, in the land's own green
	float dry = smoothstep(0.52, 0.72, n2(xz * 0.009 + vec2(0.61, 0.13)) + slope * 0.35);
	vec3 g = mix(grass_a, grass_b, smoothstep(0.35, 0.7, macro));
	g *= 0.85 + 0.3 * mid;
	g = mix(g, grass_dry * (0.9 + 0.2 * fine), dry * 0.75);
	g *= tint.rgb * 2.0;

	float crop_id = floor(texture(crop_tex, uv).a * 255.0 / 40.0 + 0.5);
	vec3 crop = crop_6;
	float furrow = step(0.55, sin(xz.x * 0.9 + xz.y * 0.25));
	if (crop_id < 1.5) crop = crop_1;
	else if (crop_id < 2.5) crop = crop_2;
	else if (crop_id < 3.5) crop = mix(crop_3, vec3(0.85, 0.66, 0.12), step(0.66, speck));
	else if (crop_id < 4.5) crop = mix(crop_4, vec3(0.72, 0.12, 0.08), step(0.6, speck));
	else if (crop_id < 5.5) crop = crop_5;
	crop *= 1.0 - 0.08 * furrow;

	vec3 hea = mix(heather_green, heather, smoothstep(0.45, 0.6, mid + (fine - 0.5) * 0.4));
	vec3 flw = g;
	flw = mix(flw, vec3(0.9, 0.88, 0.8), step(0.72, speck) * 0.6);
	flw = mix(flw, vec3(0.85, 0.7, 0.18), step(speck, 0.26) * 0.6);

	float wsum = a.r + a.g + a.b + a.a + b.r + b.g + b.b + b.a + c.r + c.g + c.b + c.a;
	vec3 alb = g * a.r
			+ needles * (0.85 + 0.3 * mid) * a.g
			+ litter * (0.85 + 0.3 * fine) * a.b
			+ hea * a.a
			+ rock * (0.8 + 0.4 * fine) * b.r
			+ scree * (0.85 + 0.3 * speck) * b.g
			+ snow * b.b
			+ dirt * (0.85 + 0.3 * fine) * b.a
			+ gravel * (0.8 + 0.4 * speck) * c.r
			+ mud * c.g
			+ crop * c.b
			+ flw * c.a;
	alb = wsum > 0.01 ? alb / wsum : mud;
	// a cliff the map did not call rock is rock anyway
	float stony = smoothstep(0.5, 0.66, slope + (fine - 0.5) * 0.1) * (1.0 - b.b);
	alb = mix(alb, rock * (0.8 + 0.4 * fine), stony);
	alb *= clamp(1.0 + (wpos.y - 8.0) * 0.004, 0.92, 1.08);
	ALBEDO = alb;
	NORMAL_MAP = texture(bump, xz * 0.05).rgb;
	NORMAL_MAP_DEPTH = 0.7;
	ROUGHNESS = mix(1.0, 0.55, b.b);
	SPECULAR = mix(0.2, 0.4, b.b);
}
