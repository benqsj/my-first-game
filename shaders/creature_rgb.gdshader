shader_type spatial;
// Polysplit's Biped Creatures as the pack's own shader draws them
// (RGBRecolor_BipedCreatures.shadergraph, CREATURES_PACK.md §4). The texture
// is a mask: its red, green and blue are three flat colours, its brightness
// the bands of shade. The block in the lower right (in the pack's UVs) is the
// face: eyes, brows and mouth, cut out by the mask's alpha. In it, the two
// thin strips are the eyes (white x2 + green as it is + cornea), and the rest
// lips and brows (red as the lip colour, green as colour 2). The eye white
// is added twice, as the graph adds it.
render_mode cull_back;

uniform sampler2D mask_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 color1 : source_color = vec3(1.0, 0.24, 0.24);
uniform vec3 color2 : source_color = vec3(0.15, 0.97, 0.25);
uniform vec3 color3 : source_color = vec3(0.15, 0.53, 0.82);
uniform vec3 eye_white : source_color = vec3(0.8);
uniform vec3 cornea : source_color = vec3(0.2, 0.87, 0.95);
uniform vec3 lip : source_color = vec3(0.81, 0.02, 0.16);
uniform vec3 metal_rgb = vec3(0.0);
uniform vec3 smooth_rgb = vec3(0.0);

bool _rect(vec2 uv, vec2 centre, vec2 size) {
	vec2 d = abs(uv - centre);
	return d.x < size.x * 0.5 && d.y < size.y * 0.5;
}

void fragment() {
	vec4 t = texture(mask_tex, UV);
	// the pack's UVs (Unity's, v up)
	vec2 u = vec2(UV.x, 1.0 - UV.y);
	bool face = _rect(u, vec2(0.75, 0.375), vec2(0.49, 0.24));
	vec3 col;
	if (!face) {
		col = t.r * color1 + t.g * color2 + t.b * color3;
		METALLIC = clamp(dot(t.rgb, metal_rgb), 0.0, 1.0);
		ROUGHNESS = clamp(1.0 - dot(t.rgb, smooth_rgb), 0.04, 1.0);
	} else {
		vec3 f = t.rgb * t.a;
		bool eye = _rect(u, vec2(0.75, 0.4325), vec2(0.49, 0.025))
				|| _rect(u, vec2(0.75, 0.325), vec2(0.49, 0.025));
		if (eye) {
			col = 2.0 * f.r * eye_white + vec3(f.g) + f.b * cornea;
		} else {
			col = f.r * lip + f.g * color2;
		}
		METALLIC = 0.0;
		ROUGHNESS = 1.0;
	}
	ALBEDO = col;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
