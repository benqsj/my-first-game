shader_type spatial;
// Green veins glowing up through a hero while a ghoul's venom works in him
// ([HeroPoison]): laid over his meshes, as strong as the venom (`amount`).
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
uniform float amount = 0.0;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float v = n2(UV * 90.0) * 0.6 + n2(UV * 230.0) * 0.4;
	float line = 1.0 - smoothstep(0.0, 0.022, abs(v - 0.5));
	float pulse = 0.55 + 0.45 * sin(TIME * 4.0 + UV.y * 30.0);
	ALBEDO = vec3(0.25, 0.85, 0.08) * line * amount * pulse * 0.45;
	ALPHA = 1.0;
}
