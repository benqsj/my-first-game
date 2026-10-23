// The forest's low poly leaves, vines and ferns (2026-10-23): faceted, their
// colour in the vertex, both sides drawn, the sun coming through them from
// behind, stirring a little in the wind.
shader_type spatial;
render_mode cull_disabled;

uniform float sway = 0.08;
uniform vec3 backlight = vec3(0.28, 0.4, 0.12);

uniform float bright = 1.2;   // the palette lifted a little in the dim wood

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * 0.8 + w.x * 0.13 + w.z * 0.17;
	float bend = clamp((w.y - MODEL_MATRIX[3].y) * 0.15, 0.0, 1.0);
	VERTEX += (inverse(mat3(MODEL_MATRIX)) * vec3(sin(t), 0.0, cos(t * 0.83))) * sway * bend;
}

void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * bright;
	ROUGHNESS = 0.8;
	SPECULAR = 0.25;
	BACKLIGHT = backlight;
}
