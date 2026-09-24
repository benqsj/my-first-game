// The look of a blade's cut through the air (see scripts/blade_arc.gd).
// UV.x is the age of a point of the arc (0 at the blade, 1 where it dies),
// UV.y runs across it from the hilt side (0) to the edge the tip swept (1).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 glow_color : source_color = vec4(0.78, 0.87, 1.0, 1.0);
uniform float intensity = 1.0;
uniform float distortion = 0.012;
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
	float tail = pow(1.0 - age, 1.4 + (1.0 - across) * 1.6);
	// The first sliver at the blade itself is softened, so the arc grows out
	// of the steel instead of starting at a hard line.
	float lead = smoothstep(0.0, 0.035, age);

	// A bright hairline along the path of the tip...
	float edge = exp(-pow((1.0 - across) * 16.0, 2.0));
	// ...a pale sheet behind it, thickest near the edge...
	float body = pow(across, 2.4);
	// ...and wind streaks running back along the arc, drifting as it ages.
	float n = noise(vec2(age * 5.0 - TIME * 3.0, across * 22.0));
	float streak = smoothstep(0.45, 0.95, n) * smoothstep(0.1, 0.7, across);
	// The tail frays: the older a point, the more of it the noise eats.
	float fray = smoothstep(age - 0.25, age + 0.05, noise(vec2(age * 9.0 + TIME * 1.5, across * 7.0)) * 0.9 + 0.2);

	float glow = (edge * 1.25 + body * 0.75 + streak * 0.65) * tail * lead * fray * intensity;

	// The air the blade has just gone through is bent a little.
	float warp_amount = distortion * body * tail * lead * intensity;
	vec2 warp = (vec2(n, noise(vec2(across * 13.0, age * 7.0 + TIME))) - 0.5) * 2.0 * warp_amount;
	vec3 behind = textureLod(screen, SCREEN_UV + warp, 0.0).rgb;

	vec3 colour = mix(glow_color.rgb, core_color.rgb, clamp(edge * 1.2, 0.0, 1.0));
	float cover = clamp(max(glow, body * tail * lead * intensity) * 1.15, 0.0, 1.0);
	ALBEDO = behind + colour * glow;
	ALPHA = cover;
}
