shader_type spatial;

// Venom in the air: a wet, living green. Its skin wobbles, a darker core shows
// through where it is thick, and its rim glows the way light catches the edge
// of something translucent. Used for the gob and the drops it sheds.

render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 core_color : source_color = vec3(0.09, 0.3, 0.03);
uniform vec3 skin_color : source_color = vec3(0.46, 0.94, 0.16);
uniform vec3 glow_color : source_color = vec3(0.4, 1.0, 0.12);
uniform float glow_strength = 1.5;
uniform float wobble = 0.07;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
	float n = texture(noise_tex, VERTEX.xy * 0.8 + vec2(TIME * 0.9, TIME * 0.55)).r - 0.5;
	VERTEX += NORMAL * n * wobble * 2.0;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.4);
	float swirl = texture(noise_tex, local_pos.xz * 1.4 + vec2(0.0, TIME * 0.35)).r;
	ALBEDO = mix(core_color, skin_color, 0.3 + 0.7 * swirl * (0.4 + 0.6 * rim));
	ROUGHNESS = 0.1;
	SPECULAR = 0.75;
	EMISSION = glow_color * glow_strength * (rim * 1.1 + swirl * 0.25);
	ALPHA = mix(0.82, 1.0, rim);
}
