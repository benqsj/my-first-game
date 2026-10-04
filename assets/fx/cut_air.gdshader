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
	vec3 col = bent + rim_color.rgb * edge * rim;
	ALBEDO = col;
	ALPHA = clamp(mask * 3.0 + edge * rim, 0.0, 1.0);
}
