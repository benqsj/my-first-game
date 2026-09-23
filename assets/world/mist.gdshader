shader_type spatial;

// A bank of mist: an upright card turned to face the camera about the vertical,
// with a noise wisp cut out of it that drifts sideways.
//
// Softened three ways, because a card is only mist until one of its edges
// shows: its own outline is faded to nothing, it fades where it passes into the
// ground or the water or a wall (the depth buffer says how close), and it fades
// out as the camera walks into it.

render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;
uniform sampler2D wisp : filter_linear_mipmap, repeat_enable;

uniform vec4 tint : source_color = vec4(0.66, 0.7, 0.72, 1.0);
uniform float density = 0.42;
// Metres over which the mist fades into whatever it meets.
uniform float soft_edge = 2.5;
// Distances from the camera over which a card fades in.
uniform float near_fade_start = 2.0;
uniform float near_fade_end = 9.0;
uniform float drift = 0.006;

varying vec4 seed;

void vertex() {
	seed = INSTANCE_CUSTOM;
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 back = normalize(cross(right, vec3(0.0, 1.0, 0.0)));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(right, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(back, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	// Soft oval outline.
	vec2 d = (UV - 0.5) * 2.0;
	float outline = 1.0 - smoothstep(0.25, 1.0, length(d * vec2(1.0, 1.15)));
	// Heavier at the foot than the top, the way mist lies. UV.y runs downwards.
	outline *= 0.55 + 0.45 * UV.y;

	vec2 uv = UV * vec2(1.2, 0.45) + seed.xy * 7.0 + vec2(TIME * drift * (0.6 + seed.z), 0.0);
	float wisps = texture(wisp, uv).r;
	wisps = smoothstep(0.25, 0.85, wisps);

	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	behind.xyz /= behind.w;
	float into = clamp((VERTEX.z - behind.z) / soft_edge, 0.0, 1.0);
	float near = smoothstep(near_fade_start, near_fade_end, -VERTEX.z);

	ALBEDO = tint.rgb;
	ALPHA = clamp(outline * wisps * density * into * near * (0.7 + 0.3 * seed.w), 0.0, 1.0);
}
