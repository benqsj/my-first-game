// The forest's low poly, solid things (2026-10-23): each face its own colour
// (the vertex colour from Blender), flat-shaded, a touch darker at their feet
// where the light does not get in, a soft rim where the sun is behind.
shader_type spatial;
render_mode cull_back;

uniform float foot_dark = 0.35;   // how much darker at the foot (0 none)
uniform float foot_height = 2.5;  // metres over the piece's origin it fades out by
uniform float glow = 0.0;         // a little light of its own (the mushrooms)
uniform vec4 glow_col : source_color = vec4(1.0, 0.45, 0.12, 1.0);
uniform float roughness = 0.9;

varying float above;

uniform float bright = 1.2;   // the palette lifted a little in the dim wood

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	above = wp.y - MODEL_MATRIX[3].y;
}

void fragment() {
	float ao = mix(1.0 - foot_dark, 1.0, smoothstep(0.0, foot_height, above));
	// (the importer keeps vertex colours as sRGB: back to linear)
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * bright * ao;
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
	RIM = 0.15;
	RIM_TINT = 0.6;
	EMISSION = glow_col.rgb * glow;
}
