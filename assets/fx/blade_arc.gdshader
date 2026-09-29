// The look of a blade's (or a claw's) cut through the air (see scripts/blade_arc.gd).
// UV.x is the age of a point of the arc (0 at the blade, 1 where it dies),
// UV.y runs across it from the hilt side (0) to the edge the tip swept (1).
//
// What it is made of, from the edge in: a hot hairline where the tip went (for
// a claw, `strands` of them side by side, the marks of the claws), a soft halo
// round it in the glow colour, a thin sheet behind thinning to nothing at the
// hilt, wind streaks running back along it, the air behind it bent a little,
// and a tail that frays away. Additive in the light, so it glows against the
// dark of the wood without ever painting over it as a flat grey crescent.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 glow_color : source_color = vec4(0.72, 0.84, 1.0, 1.0);
uniform float intensity = 1.0;
uniform float distortion = 0.012;
// Lines drawn along the edge: 1 for a blade, 3 for a claw.
uniform int strands = 1;
// How far apart the lines are, as a share of the arc's width.
uniform float strand_gap = 0.11;
// How much of the pale sheet behind the edge shows (0: only the lines).
uniform float sheet = 0.45;
// 0: the glowing hairline and its halo (the orc's axe, the wolf's claws).
// 1: a smear — a broad pale sheet of brushed streaks from the hilt to past the
// tip, crisp at the edge the tip swept, lingering and going to a dusky smoke
// as it ages (the cut in the air of the user's Dragonwilds videos).
uniform float smear = 0.0;
uniform vec4 smoke_color : source_color = vec4(0.52, 0.55, 0.62, 1.0);
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 s = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), s.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), s.x), s.y);
}

void fragment() {
	float age = clamp(UV.x, 0.0, 1.0);
	float across = clamp(UV.y, 0.0, 1.0);

	// Everything dies away along the arc; the hilt side sooner than the edge.
	float tail = pow(1.0 - age, 1.2 + (1.0 - across) * 1.8);
	// The first sliver at the blade is softened, so the arc grows out of the
	// steel instead of starting at a hard line.
	float lead = smoothstep(0.0, 0.03, age);

	// The hairlines: thin and hot at the blade, spreading a little and cooling
	// as they age.
	float width = mix(34.0, 16.0, age);
	float edge = 0.0;
	float halo = 0.0;
	for (int k = 0; k < 4; k++) {
		if (k >= strands) {
			break;
		}
		float at = 1.0 - float(k) * strand_gap;
		// A claw's inner marks are a touch shorter-lived than the outer one.
		float keep = 1.0 - float(k) * 0.18 * age;
		float d = across - at;
		edge += exp(-pow(d * width, 2.0)) * keep;
		halo += exp(-pow(d * 5.5, 2.0)) * keep;
	}
	edge = min(edge, 1.5);
	halo = min(halo, 1.0) * 0.45;
	// The pale sheet behind, thickest near the edge, gone at the hilt.
	float body = pow(across, 2.6) * sheet;
	// Wind streaks running back along the arc, drifting as it ages.
	float n = noise(vec2(age * 5.0 - TIME * 3.0, across * 26.0));
	float streak = smoothstep(0.5, 0.95, n) * smoothstep(0.2, 0.8, across) * (0.4 + sheet);
	// The tail frays: the older a point, the more of it the noise eats.
	float fray = smoothstep(age - 0.25, age + 0.05, noise(vec2(age * 9.0 + TIME * 1.5, across * 7.0)) * 0.9 + 0.2);

	float fade = tail * lead * fray * intensity;
	float hot = edge * 1.6 * fade;
	float soft = (halo + body * 0.8 + streak * 0.6) * fade;

	// The air the blade has just gone through is bent a little.
	float warp_amount = distortion * (body + halo) * tail * lead * intensity;
	vec2 warp = (vec2(n, noise(vec2(across * 13.0, age * 7.0 + TIME))) - 0.5) * 2.0 * warp_amount;
	vec3 behind = textureLod(screen, SCREEN_UV + warp, 0.0).rgb;

	// Added to what is behind it, never painted over it: light, not paint.
	vec3 light = core_color.rgb * hot + glow_color.rgb * soft;
	vec3 glow_out = behind + light;
	float glow_alpha = clamp((hot + soft) * 4.0, 0.0, 1.0);

	// The smear: a sheet over the whole width, brushed with fine streaks that
	// run along the swing, thinner toward the hilt, the tip's edge crisp.
	float s_tail = pow(1.0 - age, 0.9 + (1.0 - across) * 0.7);
	float brush = 0.3 + 0.7 * smoothstep(0.25, 0.85, noise(vec2(age * 2.5 - TIME * 0.6, across * 64.0)));
	brush *= 0.8 + 0.2 * noise(vec2(age * 7.0, across * 17.0));
	float s_body = mix(0.12, 1.0, pow(across, 1.6)) * sheet * brush;
	float s_edge = exp(-pow((across - 1.0) * 14.0, 2.0));
	// Its far end frays into wisps rather than stopping on a line.
	float s_fray = smoothstep(age - 0.35, age + 0.1, noise(vec2(age * 6.0 + TIME, across * 9.0)) * 0.9 + 0.25);
	float s_a = clamp((s_body + s_edge * 0.8) * s_tail * lead * s_fray * intensity, 0.0, 0.8);
	// White at the blade, going to a grey-blue smoke as it ages.
	vec3 s_col = mix(core_color.rgb, smoke_color.rgb, smoothstep(0.25, 0.95, age));
	vec3 smear_out = mix(behind, s_col, s_a) + core_color.rgb * s_edge * s_tail * lead * 0.35 * intensity;
	float smear_alpha = clamp(s_a * 3.0 + s_edge * s_tail, 0.0, 1.0);

	ALBEDO = mix(glow_out, smear_out, smear);
	ALPHA = mix(glow_alpha, smear_alpha, smear);
}
