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
	ALBEDO = behind + light;
	ALPHA = clamp((hot + soft) * 4.0, 0.0, 1.0);
}
