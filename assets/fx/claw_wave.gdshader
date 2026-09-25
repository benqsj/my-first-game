// The wolf-man's claw wave (see scripts/claw_wave.gd): three sickle blades of
// torn air, the marks of three claws, flying at you.
// UV.x runs along a blade (0 and 1 its points), UV.y across it (1 the cutting
// edge, which leads). COLOR.r tells the three blades apart.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.9, 1.0);
uniform vec4 glow_color : source_color = vec4(0.95, 0.13, 0.06, 1.0);
uniform float intensity = 1.0;
uniform float distortion = 0.022;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
// How much of it is left, 0 to 1.
instance uniform float fade = 1.0;
// 1: not the blade itself but the air it tore, left hanging behind it.
instance uniform float ghost = 0.0;

varying float blade;

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

void vertex() {
	blade = COLOR.r;
}

void fragment() {
	float u = clamp(UV.x, 0.0, 1.0);
	float v = clamp(UV.y, 0.0, 1.0);
	// To a point at both ends.
	float tips = pow(sin(3.14159 * u), 0.7);
	// A white-hot hairline along the cutting edge...
	float sharp = mix(5.0, 9.0, ghost);
	float edge = exp(-pow((1.0 - v) * sharp, 2.0));
	// ...a red sheet of torn air behind it...
	float sheet = smoothstep(0.0, 0.85, v) * (1.0 - ghost);
	// ...streaked, the streaks racing back along it.
	float n = noise(vec2(u * 9.0 - TIME * 7.0 + blade * 7.0, v * 3.0 + blade * 3.0));
	float streak = smoothstep(0.35, 0.9, n);
	// The ghost frays away as it goes.
	float fray = mix(1.0, smoothstep(0.25, 0.75, noise(vec2(u * 14.0 + blade * 5.0, TIME * 2.0)) + fade * 0.4), ghost);
	float flicker = 0.85 + 0.15 * sin(TIME * 43.0 + blade * 9.0);

	float glow = (edge * 1.6 + sheet * 0.85 + streak * sheet * 0.7) * tips * fade * fray * intensity * flicker;
	glow *= mix(1.0, 0.85, ghost);

	float warp_amount = distortion * (sheet + edge * 0.5 + ghost * 0.6) * tips * fade;
	vec2 warp = (vec2(n, noise(vec2(v * 13.0, u * 7.0 + TIME))) - 0.5) * 2.0 * warp_amount;
	vec3 behind = textureLod(screen, SCREEN_UV + warp, 0.0).rgb;
	// A shade of dark behind the sheet, so it reads on a bright field as well.
	behind *= 1.0 - 0.4 * sheet * tips * fade;

	vec3 colour = mix(glow_color.rgb, core_color.rgb, clamp(edge * 1.3 - ghost * 0.4, 0.0, 1.0));
	ALBEDO = behind + colour * glow;
	ALPHA = clamp(max(glow, (sheet * 0.65 + ghost * 0.35) * tips * fade) * 1.1, 0.0, 1.0);
}
