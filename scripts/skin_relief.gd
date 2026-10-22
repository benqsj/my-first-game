class_name SkinRelief
extends RefCounted
## The bare chest drawn (the user's word, 2026-10-23: a man stripped of his
## clothes showed nothing, no chest, nothing): the pack's body is skin of one
## flat colour, its few faces too broad to show a man's build, so the torso is
## drawn with a shader of its own. Its breast muscles, the groove down the
## breastbone, the belly's six blocks, the collarbones, and at the back the
## shoulder blades and the spine, are a height field laid over the body by
## where each point stands in the figure's rest pose (carried in UV2 and the
## vertex colour, since the body skins away from it as he moves); the field
## bends the light (bump) and darkens its grooves. The colour is the pack's
## skin as dyed ([PolysplitLook.dye]).
##
## Men only: her body is left as it was.

const KEY := &"skin_relief"

const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness = 0.85;
uniform float specular = 0.4;
// How deep the build shows (1 the drawn depth).
uniform float depth = 1.0;
varying vec3 rest;
varying vec3 rest_n;
float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a; vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}
void vertex() {
	rest = vec3(UV2.x, UV2.y, COLOR.r * 0.8 - 0.4);
	rest_n = COLOR.gba * 2.0 - 1.0;
}
// x: height (m), y: how dark (the grooves).
vec2 build(vec3 p, vec3 n) {
	float ax = abs(p.x);
	float y = p.y;
	float front = smoothstep(0.15, 0.55, n.z) * (1.0 - smoothstep(0.24, 0.30, ax));
	float back = smoothstep(0.15, 0.55, -n.z) * (1.0 - smoothstep(0.22, 0.28, ax));
	float h = 0.0;
	float dark = 0.0;
	// the breast: two broad slabs of muscle, their lower edge rising to the arm
	float edge = 1.472 + 0.32 * max(ax - 0.05, 0.0);
	float mid = smoothstep(0.003, 0.018, ax);
	float pec = smoothstep(edge, edge + 0.045, y) * (1.0 - smoothstep(1.55, 1.65, y))
			* (1.0 - smoothstep(0.14, 0.21, ax)) * mid;
	pec *= 0.7 + 0.3 * (1.0 - smoothstep(0.0, 0.1, abs(ax - 0.085)));
	h += pec * 0.02;
	// the shadow under it, deepest in the middle, and the breastbone's groove
	float under = (smoothstep(edge - 0.05, edge, y) * (1.0 - smoothstep(edge, edge + 0.01, y)))
			* (1.0 - smoothstep(0.14, 0.2, ax));
	dark += under * (0.32 + 0.18 * (1.0 - smoothstep(0.0, 0.1, ax)));
	dark += (1.0 - mid) * smoothstep(edge, edge + 0.04, y) * (1.0 - smoothstep(1.6, 1.65, y)) * 0.22;
	// its top and outer edge a little lit, its lower curve a little shaded
	dark -= pec * smoothstep(1.5, 1.58, y) * 0.06;
	dark += pec * (1.0 - smoothstep(edge + 0.01, edge + 0.05, y)) * 0.1;
	// the belly: six blocks between the breast and the belt
	float top = edge - 0.012;
	float inside = step(1.215, y) * step(y, top) * (1.0 - smoothstep(0.072, 0.09, ax));
	float bx = smoothstep(0.004, 0.022, ax) * (1.0 - smoothstep(0.05, 0.082, ax));
	float dy = min(min(abs(y - 1.415), abs(y - 1.352)), min(abs(y - 1.29), abs(y - top)));
	float by = smoothstep(0.003, 0.022, dy);
	h += inside * bx * by * 0.005;
	dark += inside * (1.0 - bx * by) * 0.11;
	// the flank: the belly's edge, a long shallow groove down each side
	float flank = (1.0 - smoothstep(0.0, 0.012, abs(ax - 0.088))) * step(1.24, y) * step(y, edge);
	dark += flank * 0.12;
	// the collarbones, from the throat out to the shoulder
	float clav = 1.0 - smoothstep(0.0, 0.011, seg(vec2(ax, y), vec2(0.022, 1.668), vec2(0.165, 1.688)));
	h += clav * 0.005;
	float hollow = 1.0 - smoothstep(0.0, 0.016, seg(vec2(ax, y), vec2(0.03, 1.648), vec2(0.15, 1.665)));
	dark += hollow * 0.1;
	// the back: the shoulder blades and the spine's groove
	float blade = 1.0 - smoothstep(0.4, 1.0, length(vec2((ax - 0.095) / 0.07, (y - 1.565) / 0.085)));
	float spine = (1.0 - smoothstep(0.004, 0.02, ax)) * smoothstep(1.22, 1.26, y) * (1.0 - smoothstep(1.62, 1.67, y));
	float bh = blade * 0.009 - spine * 0.005;
	float bd = spine * 0.14;
	return vec2(h * front + bh * back, dark * front + bd * back);
}
void fragment() {
	vec2 b = build(rest, rest_n);
	vec3 c = texture(albedo_tex, UV).rgb * albedo.rgb;
	ALBEDO = c * (1.0 - b.y * depth);
	ROUGHNESS = roughness;
	SPECULAR = specular;
	// the height field bends the light (Mikkelsen's bump from the screen's
	// derivatives: no tangents needed)
	float hgt = b.x * depth;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhx = dFdx(hgt);
	float dhy = dFdy(hgt);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);
}
"""

static var _shader: Shader
## The body's meshes with their rest pose written in, by the mesh they came from.
static var _made: Dictionary = {}


## Draws the build on `figure`'s bare torso (if it has one and is a man's).
## Called after [method PolysplitLook.dye], every time: the skin's colour is
## taken again from the dyed material.
static func dress(figure: Node3D) -> void:
	if figure == null or bool(figure.get_meta(&"ps_female", false)):
		return
	for body: MeshInstance3D in figure.find_children(PolysplitLook.PREFIX + "topbody", "MeshInstance3D", true, false):
		_dress_one(body)


static func _dress_one(body: MeshInstance3D) -> void:
	if body.mesh == null:
		return
	if not body.has_meta(KEY):
		if body.mesh.get_blend_shape_count() > 0:
			return
		var plain := body.mesh
		var was: Array = []
		for i in plain.get_surface_count():
			was.append(body.get_active_material(i))
		var key := plain.get_instance_id()
		if not _made.has(key):
			_made[key] = _with_rest(plain)
		body.mesh = _made[key]
		var made: Array = []
		for i in body.mesh.get_surface_count():
			var m := ShaderMaterial.new()
			m.shader = _get_shader()
			made.append(m)
			body.set_surface_override_material(i, m)
		body.set_meta(KEY, [was, made])
	var kept: Array = body.get_meta(KEY)
	var srcs: Array = kept[0]
	var mats: Array = kept[1]
	for i in mats.size():
		var src: BaseMaterial3D = srcs[i] as BaseMaterial3D if i < srcs.size() else null
		var m := mats[i] as ShaderMaterial
		if src == null or m == null:
			continue
		m.set_shader_parameter(&"albedo_tex", src.albedo_texture)
		m.set_shader_parameter(&"albedo", src.albedo_color)
		m.set_shader_parameter(&"roughness", src.roughness)
		m.set_shader_parameter(&"specular", src.metallic_specular)


static func _get_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	return _shader


## A copy of `plain` with each corner's rest place in UV2 (across, up) and
## its colour (r: depth, g b a: its rest normal), the rest as it was.
static func _with_rest(plain: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for i in plain.get_surface_count():
		var arrays := plain.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uv2 := PackedVector2Array()
		uv2.resize(verts.size())
		var col := PackedColorArray()
		col.resize(verts.size())
		for k in verts.size():
			var p := verts[k]
			var n := norms[k] if k < norms.size() else Vector3.FORWARD
			uv2[k] = Vector2(p.x, p.y)
			col[k] = Color(clampf((p.z + 0.4) / 0.8, 0.0, 1.0), n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5)
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		arrays[Mesh.ARRAY_COLOR] = col
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
				plain.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.surface_set_material(i, plain.surface_get_material(i))
	return out
