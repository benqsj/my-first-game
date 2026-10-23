// The oaks' crowns (2026-10-23): leaf-cluster cards, cut out, lit through
// from behind, each cluster a little different in colour, stirring in the wind.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D leaves : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float sway = 0.12;

varying float hue;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	hue = fract(sin(dot(floor(w * 0.25), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float t = TIME * 0.9 + w.x * 0.15 + w.z * 0.11;
	VERTEX += (inverse(mat3(MODEL_MATRIX)) * vec3(sin(t), sin(t * 1.3) * 0.4, cos(t * 0.8))) * sway;
	// light the cards as if the crown were round: normals pointing out and up
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.5));
}

void fragment() {
	vec4 c = texture(leaves, UV);
	ALBEDO = c.rgb * tint.rgb * mix(0.8, 1.15, hue) * vec3(1.0, mix(0.95, 1.05, hue), 1.0);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.75;
	SPECULAR = 0.3;
	BACKLIGHT = vec3(0.32, 0.42, 0.14);
}
