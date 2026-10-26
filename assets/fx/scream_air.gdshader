shader_type spatial;
// A ghoul's scream ([GhoulFighter]): a ball of air thrown from its mouth that
// bends the world behind it in ripples. It draws only what is behind it, moved, and the
// move fades to nothing at its edge, so it has no outline of its own.
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float life = 0.0;

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float body = smoothstep(0.05, 0.7, facing);
	float strength = (1.0 - life) * (1.0 - life);
	float ripple = sin(facing * 18.0 - life * 20.0);
	vec2 off = NORMAL.xy * 0.035 * strength * body * (0.6 + 0.4 * ripple);
	ALBEDO = textureLod(screen, SCREEN_UV - off, 0.0).rgb;
	ALPHA = 1.0;
}
