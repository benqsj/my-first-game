shader_type canvas_item;
// Venom in him ([HeroPoison]), on his own screen: the edges go green and
// veins creep in from them, throbbing; as strong as the venom (`amount`).
uniform float amount = 0.0;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	if (amount <= 0.001) { discard; }
	vec2 c = UV - 0.5;
	c.x *= 1.7;
	float r = length(c);
	float pulse = 0.82 + 0.18 * sin(TIME * 5.0);
	float edge = smoothstep(0.42 - amount * 0.12, 1.0, r);
	float v = n2(UV * vec2(26.0, 15.0)) * 0.55 + n2(UV * vec2(70.0, 40.0)) * 0.45;
	float vein = 1.0 - smoothstep(0.0, 0.018, abs(v - 0.5));
	vein *= smoothstep(0.62 - amount * 0.22, 0.95, r);
	float a = edge * 0.55 * amount * pulse + vein * 0.5 * amount * pulse;
	COLOR = vec4(mix(vec3(0.12, 0.42, 0.05), vec3(0.45, 0.95, 0.2), vein), clamp(a, 0.0, 0.85));
}
