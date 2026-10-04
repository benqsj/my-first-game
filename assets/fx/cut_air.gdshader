// The cut as bent air (see BladeArc: F1 / F2 switches the heroes' cut to it).
// UV.x = age (0 at the blade .. 1 where it dies); UV.y = across (0 at the hilt ..
// 1 the edge the tip swept). Nothing is painted: what is behind the arc is drawn
// again, pushed about by two noises sliding along the swing (tex/cut_air_*), a
// little soft like heat haze, the colours split a hair at the strongest bend, so
// the air looks cut and wobbles shut behind the blade. A faint rim marks only the
// fresh edge.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D streak_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D break_tex : filter_linear_mipmap, repeat_enable;
// how far the air is pushed, as a share of the screen
uniform float strength = 0.022;
// colour split at the strongest bend (0 none)
uniform float split = 0.1;
// the bent air a little soft, like heat haze (0 sharp)
uniform float haze = 0.6;
// the faint rim on the fresh edge
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim = 0.22;
// a hint of tint in the bent air (0 none)
uniform vec4 tint : source_color = vec4(0.85, 0.92, 1.0, 1.0);
uniform float tint_amount = 0.06;
uniform float brighten = 0.04;
uniform float erosion = 0.9;
// the cut itself: along the line the tip swept the air is torn and pulled
// apart to both sides, so a seam shows through the haze (0 none)
uniform float seam = 0.0;
// how far in from the edge the seam runs, and how wide its pull is (shares of the arc)
uniform float seam_at = 0.86;
uniform float seam_width = 0.12;
// a pressure wave rolled out across the arc behind the blade (0 none)
uniform float wave = 0.0;

void fragment() {
	float age = clamp(UV.x, 0.0, 1.0);
	float across = clamp(UV.y, 0.0, 1.0);
	float lead = smoothstep(0.0, 0.05, age);
	// where the air is bent: most along the edge, gone at the hilt, dying along the arc
	float body = smoothstep(0.05, 0.85, across) * pow(1.0 - age, 1.3);
	// the tail closes up unevenly
	float n_break = texture(break_tex, vec2(age * 1.2 + TIME * 0.07, across * 0.5)).r;
	float t = age * erosion;
	float keep = smoothstep(t - 0.12, t + 0.12, n_break * 0.85 + 0.15);
	float mask = body * keep * lead;
	// the push: two samples of the streak map, sliding back along the swing
	vec2 uv1 = vec2(age * 0.35 - TIME * 0.3, across * 0.7);
	vec2 uv2 = vec2(age * 0.55 + TIME * 0.2, across * 0.9 + 0.37);
	vec2 push = vec2(texture(streak_tex, uv1).r, texture(streak_tex, uv2).r) - 0.5;
	// and a ripple across the arc, like a wake
	push.y += sin(across * 9.0 - age * 6.0 - TIME * 9.0) * 0.3;
	vec2 off = push * strength * mask * 2.0;
	// across the arc, on the screen: which way is out from the hilt
	vec2 g = vec2(dFdx(across), dFdy(across));
	vec2 out_dir = length(g) > 1e-6 ? normalize(g) : vec2(0.0, 1.0);
	// the seam: each side pulled away from the line, hardest right at it
	float d = across - seam_at;
	float pull = sign(d) * (1.0 - smoothstep(0.0, seam_width, abs(d))) * smoothstep(0.0, 0.02, abs(d));
	float seam_life = pow(1.0 - age, 1.6) * keep * lead;
	off += out_dir * pull * seam * strength * 1.6 * seam_life;
	// the pressure wave: a bulge rolling out from the edge as the arc ages
	float front = 1.0 - age * 1.4;
	float bulge = exp(-pow((across - front) * 7.0, 2.0)) * wave * strength * (1.0 - age);
	off += out_dir * bulge * keep;
	vec2 suv = SCREEN_UV + off;
	float s = split * length(off);
	float lod = haze * 2.0 * mask;
	vec3 bent;
	bent.r = textureLod(screen, suv + vec2(s, 0.0), lod).r;
	bent.g = textureLod(screen, suv, lod).g;
	bent.b = textureLod(screen, suv - vec2(s, 0.0), lod).b;
	bent *= 1.0 + brighten * mask;
	bent = mix(bent, bent * tint.rgb * 1.08, tint_amount * mask);
	// the fresh edge: a thin, faint line where the tip just went
	float edge = smoothstep(0.93, 1.0, across) * pow(1.0 - age, 3.0) * lead;
	// the seam's own glint, a hair of light along the tear
	edge += exp(-pow(d * 70.0, 2.0)) * seam * 0.35 * seam_life;
	vec3 col = bent + rim_color.rgb * edge * rim;
	ALBEDO = col;
	float seam_mask = (1.0 - smoothstep(0.0, seam_width * 1.2, abs(d))) * seam_life * step(0.001, seam);
	ALPHA = clamp(max(mask * 3.0, seam_mask * 3.0) + edge * rim, 0.0, 1.0);
}
