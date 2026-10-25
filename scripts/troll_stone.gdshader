// The troll gone to stone (2026-10-25): laid over its body, stone up to
// `top` (world height) and nothing above it, so the stone is seen climbing it
// from its feet; faceted greys, dark cracks wandering over it, a pale line of
// dust where the stone is still taking it. `opacity` fades it all.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform float top = -1000.0;
uniform float edge = 0.3;
uniform float opacity = 1.0;
uniform vec4 stone : source_color = vec4(0.44, 0.43, 0.41, 1.0);
uniform vec4 crack : source_color = vec4(0.13, 0.12, 0.11, 1.0);
uniform vec4 dust : source_color = vec4(0.78, 0.74, 0.66, 1.0);

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
	float k = top - wp.y;
	if (k < 0.0 || opacity <= 0.001) {
		discard;
	}
	// facets: a grey of its own to each cell
	float t = hash(floor(wp * 4.0));
	vec3 col = stone.rgb * (0.8 + 0.35 * t);
	// cracks wandering over it
	float n = sin(wp.x * 6.3 + sin(wp.y * 4.7 + wp.z * 2.1) * 2.2) * sin(wp.z * 5.9 + sin(wp.y * 3.9 + wp.x * 1.7) * 2.2);
	float line = smoothstep(0.07, 0.0, abs(n));
	col = mix(col, crack.rgb, line * 0.85);
	// the edge it is still climbing: pale dust
	float band = smoothstep(edge, 0.0, k);
	col = mix(col, dust.rgb, band * 0.7);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
	ALPHA = opacity;
}
