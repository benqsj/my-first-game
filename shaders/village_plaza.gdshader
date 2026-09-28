shader_type spatial;
// The village square's cobbles (Poly Haven "cobblestone_large_01", CC0, 4 m a
// tile), laid on the ground as one flat sheet: its edge follows the stones
// (a rounded box broken by the stones' own light and dark), cut, not blended,
// so it stays in the opaque pass.
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec2 half_size = vec2(18.0, 6.0);
uniform float corner = 4.0;
uniform float fray = 2.2;
uniform float tile = 4.0;

varying vec3 world_pos;
varying vec2 local_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_pos = VERTEX.xz;
}

void fragment() {
	vec2 uv = world_pos.xz / tile;
	vec3 col = texture(albedo_tex, uv).rgb;
	ALBEDO = col * tint;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	ROUGHNESS = texture(rough_tex, uv).r;
	vec2 q = abs(local_pos) - (half_size - vec2(corner));
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner;
	float lum = dot(col, vec3(0.33));
	ALPHA = clamp(-d / fray + (lum - 0.35) * 1.6, 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
