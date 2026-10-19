class_name PortalLook
extends Node3D

## A dungeon's gate as it stands (the user's word, 2026-10-19: "ლამაზად
## გაკეთებული მოშავო მოიასამისფრო პორტალი"): a pointed arch of dark stone,
## and in it a slow black-and-violet whirl, motes drawn into it, a violet
## light on the ground before it. No ring on the ground: the light alone.
##
## Built in code, the same for the five gates in the open world and the way
## out of a dungeon; `tint` gives each its own violet.

## The whirl's colour at its rim (its heart is near black).
@export var tint: Color = Color(0.55, 0.22, 0.95)
## The opening's height; the arch is built round it.
@export var tall: float = 3.9
@export var wide: float = 2.5

var _light: OmniLight3D
var _veil: MeshInstance3D
var _t: float = 0.0

const VEIL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 rim : source_color = vec4(0.55, 0.22, 0.95, 1.0);
uniform float speed = 0.35;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void fragment() {
	// The opening: an oval with a pointed top, 0 at its heart, 1 at its edge.
	vec2 q = (UV - vec2(0.5, 0.55)) * vec2(2.0, 2.2);
	float edge = length(vec2(q.x, q.y * (q.y < 0.0 ? 1.12 : 0.92)));
	if (edge > 1.0) { discard; }
	float r = edge;
	float a = atan(q.y, q.x);
	// The whirl: noise in polar space, turned faster near the heart.
	float turn = TIME * speed + 1.6 / (r + 0.35);
	vec2 p = vec2(cos(a + turn), sin(a + turn)) * (1.4 + r * 2.2);
	float swirl = fbm(p * 1.6 + vec2(TIME * 0.12, 0.0));
	float arms = 0.5 + 0.5 * sin(a * 3.0 + turn * 2.2 + swirl * 5.0);
	float glow = smoothstep(0.15, 1.0, r) * (0.55 + 0.45 * arms) * (0.6 + 0.8 * swirl);
	vec3 deep = vec3(0.02, 0.0, 0.05);
	vec3 col = mix(deep, rim.rgb * 1.6, clamp(glow, 0.0, 1.0));
	col += rim.rgb * pow(smoothstep(0.82, 1.0, r), 2.0) * 1.4;
	ALBEDO = col;
	ALPHA = clamp(0.92 - smoothstep(0.93, 1.0, r) * 0.8, 0.0, 1.0);
}
"""

const STONE_SHADER := """
shader_type spatial;
uniform vec4 stone : source_color = vec4(0.10, 0.09, 0.12, 1.0);
uniform vec4 vein : source_color = vec4(0.55, 0.22, 0.95, 1.0);
varying vec3 wpos;
float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 cell = floor(wpos * vec3(2.2, 3.0, 2.2));
	float n = hash(cell);
	ALBEDO = stone.rgb * (0.75 + 0.5 * n);
	ROUGHNESS = 0.85;
	// Faint violet veins that breathe with the gate.
	float v = smoothstep(0.985, 1.0, hash(floor(wpos * 9.0)));
	EMISSION = vein.rgb * v * (0.6 + 0.4 * sin(TIME * 1.3 + n * 6.0));
}
"""


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	_t += delta
	if _light != null:
		_light.light_energy = 2.4 + sin(_t * 1.7) * 0.35 + sin(_t * 4.3) * 0.12


func _build() -> void:
	var stone := ShaderMaterial.new()
	var stone_shader := Shader.new()
	stone_shader.code = STONE_SHADER
	stone.shader = stone_shader
	stone.set_shader_parameter("vein", tint)
	var half := wide * 0.5
	var post := 0.62
	# Two posts, a step at their feet, and a pointed arch of three stones.
	for side: float in [-1.0, 1.0]:
		_box(stone, Vector3(post, tall * 0.78, post), Vector3(side * (half + post * 0.5), tall * 0.39, 0.0))
		_box(stone, Vector3(post * 1.35, 0.35, post * 1.35), Vector3(side * (half + post * 0.5), 0.175, 0.0))
		# The springing stones leaning in to the keystone.
		var lean := _box(stone, Vector3(post * 0.9, half * 1.25, post * 0.95),
				Vector3(side * half * 0.5, tall * 0.78 + half * 0.36, 0.0))
		lean.rotation.z = side * 0.9
	_box(stone, Vector3(post * 0.85, post * 1.2, post * 1.05), Vector3(0.0, tall * 0.78 + half * 0.78, 0.0))
	# Spikes of the same stone at the arch's shoulders.
	for side: float in [-1.0, 1.0]:
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.16
		cone.height = 0.9
		cone.radial_segments = 5
		spike.mesh = cone
		spike.material_override = stone
		spike.position = Vector3(side * (half + post * 0.5), tall * 0.78 + 0.45, 0.0)
		add_child(spike)

	_veil = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(wide + 0.05, tall + 0.2)
	_veil.mesh = quad
	var veil := ShaderMaterial.new()
	var veil_shader := Shader.new()
	veil_shader.code = VEIL_SHADER
	veil.shader = veil_shader
	veil.set_shader_parameter("rim", tint)
	_veil.material_override = veil
	_veil.position = Vector3(0.0, tall * 0.5 + 0.05, 0.0)
	_veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_veil)

	# Motes drifting in from round about and swallowed.
	var motes := GPUParticles3D.new()
	motes.amount = 48
	motes.lifetime = 2.6
	motes.position = Vector3(0.0, tall * 0.5, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	pm.emission_sphere_radius = 2.4
	pm.radial_accel_min = -1.6
	pm.radial_accel_max = -0.9
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(tint, 0.0))
	fade.add_point(0.3, Color(tint.lightened(0.3), 0.9))
	fade.set_color(fade.get_point_count() - 1, Color(tint, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	motes.process_material = pm
	var dot := QuadMesh.new()
	dot.size = Vector2(0.07, 0.07)
	var dot_mat := StandardMaterial3D.new()
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot_mat.vertex_color_use_as_albedo = true
	dot_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dot.material = dot_mat
	motes.draw_pass_1 = dot
	motes.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	add_child(motes)

	_light = OmniLight3D.new()
	_light.light_color = tint.lightened(0.15)
	_light.light_energy = 2.4
	_light.omni_range = 8.0
	_light.position = Vector3(0.0, tall * 0.45, 0.9)
	add_child(_light)


func _box(mat: Material, size: Vector3, at: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = at
	add_child(mesh)
	# Solid, so the hero walks round the posts rather than through them.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	mesh.add_child(body)
	return mesh
