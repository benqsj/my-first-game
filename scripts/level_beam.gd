class_name LevelBeam
extends Node3D

## A new level, seen: a column of white light comes down out of the sky onto
## the hero and stands on him — the way a ship's beam takes someone up — with
## motes of light rising through it, a ring of light on the ground spreading
## out from his feet, and the ground around him lit. Then it thins and is gone.
##
## Hung under the hero ([method on]) so it moves with him. Built in code, no
## assets: two open cylinders (a broad pale one and a bright core) with an
## additive shader that brightens towards the middle of the column and streams
## downward; a flat disc for the glow and the ring; rising particles; a light.
## Every peer makes its own ([Leveling] calls it on each), nothing replicated.

## How long it stands, all told.
const LIFE := 3.0
## Coming down, in seconds.
const DESCEND := 0.35
## Thinning away, at the end.
const FADE := 0.9
## How high the column reaches.
const HEIGHT := 70.0

const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float strength = 1.0;
// 0: nothing yet, 1: down to the ground.
uniform float reach = 0.0;
uniform float height = 70.0;
uniform float sharpness = 1.6;

varying float along;
varying float around;

void vertex() {
	along = clamp((VERTEX.y + height * 0.5) / height, 0.0, 1.0);
	around = atan(VERTEX.z, VERTEX.x);
}

void fragment() {
	// Bright where the column is seen through its middle, soft at its edges.
	float core = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), sharpness);
	// Down from the sky: only what the front has reached.
	float front = 1.0 - reach;
	float shown = smoothstep(front - 0.004, front + 0.004, along);
	// Brightest near the ground and at the front coming down, fading up high.
	float high = 1.0 - smoothstep(0.08, 0.9, along);
	float head = exp(-pow((along - front) / 0.01, 2.0)) * (1.0 - reach) * 3.0;
	// Light streaming down it.
	float stream = 0.72 + 0.28 * sin(along * height * 0.9 + TIME * 16.0 + sin(around * 3.0) * 2.0);
	stream *= 0.85 + 0.15 * sin(around * 7.0 - TIME * 3.0);
	float foot = 1.0 + 1.5 * (1.0 - smoothstep(0.0, 0.03, along));
	ALBEDO = tint.rgb;
	ALPHA = clamp(core * shown * (high * stream * foot + head) * strength, 0.0, 1.0);
}
"""

const GROUND_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.85, 0.92, 1.0, 1.0);
uniform float glow = 1.0;
// The spreading ring: how far out (0..1 of the disc) and how bright.
uniform float ring = 0.0;
uniform float ring_strength = 1.0;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float pool = pow(max(1.0 - d, 0.0), 2.2) * glow;
	float band = exp(-pow((d - ring) / 0.035, 2.0)) * ring_strength;
	float runes = 0.0;
	// A thin circle drawn at the beam's foot, turning.
	float a = atan(UV.y - 0.5, UV.x - 0.5);
	runes = exp(-pow((d - 0.32) / 0.012, 2.0)) * (0.6 + 0.4 * sin(a * 12.0 + TIME * 2.0)) * glow;
	ALBEDO = tint.rgb;
	ALPHA = clamp(pool + band + runes, 0.0, 1.0);
}
"""

var _age: float = 0.0
var _outer: ShaderMaterial
var _inner: ShaderMaterial
var _ground: ShaderMaterial
var _light: OmniLight3D
var _motes: GPUParticles3D
var _outer_mesh: MeshInstance3D
var _inner_mesh: MeshInstance3D


## Puts a beam on `hero`. Returns it (for a test to watch).
static func on(hero: Node3D, tint: Color = Color(0.82, 0.9, 1.0)) -> LevelBeam:
	if hero == null or not hero.is_inside_tree():
		return null
	var old := hero.get_node_or_null(^"LevelBeam")
	if old != null:
		old.queue_free()
		old.name = "LevelBeamOld"
	var beam := LevelBeam.new()
	beam.name = "LevelBeam"
	hero.add_child(beam)
	beam._build(tint)
	return beam


func _build(tint: Color) -> void:
	# Straight up, whatever way the hero is turned.
	top_level = true
	global_position = (get_parent() as Node3D).global_position
	_outer = _beam_material(tint, 0.45, 1.3)
	_inner = _beam_material(Color(1.0, 1.0, 1.0), 0.85, 3.0)
	_outer_mesh = _column(1.25, 1.05, _outer)
	_inner_mesh = _column(0.42, 0.36, _inner)

	var disc := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(7.0, 7.0)
	disc.mesh = plane
	var gs := Shader.new()
	gs.code = GROUND_SHADER
	_ground = ShaderMaterial.new()
	_ground.shader = gs
	_ground.set_shader_parameter(&"tint", tint)
	_ground.set_shader_parameter(&"glow", 0.0)
	disc.material_override = _ground
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position = Vector3(0.0, 0.06, 0.0)
	add_child(disc)

	_light = OmniLight3D.new()
	_light.light_color = tint.lerp(Color(1, 1, 1), 0.5)
	_light.omni_range = 9.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, 2.2, 0.0)
	add_child(_light)

	_motes = GPUParticles3D.new()
	_motes.amount = 90
	_motes.lifetime = 1.6
	_motes.emitting = false
	_motes.local_coords = false
	_motes.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 14, 6))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.95
	pm.emission_ring_inner_radius = 0.2
	pm.emission_ring_height = 0.3
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 6.0
	pm.gravity = Vector3(0.0, 1.5, 0.0)
	pm.tangential_accel_min = 1.5
	pm.tangential_accel_max = 3.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	_motes.process_material = pm
	var dot := SphereMesh.new()
	dot.radius = 0.035
	dot.height = 0.07
	dot.radial_segments = 6
	dot.rings = 3
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.vertex_color_use_as_albedo = true
	dm.albedo_color = tint.lerp(Color(1, 1, 1), 0.6)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot.material = dm
	_motes.draw_pass_1 = dot
	add_child(_motes)
	_apply(0.0)


func _beam_material(tint: Color, strength: float, sharpness: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = BEAM_SHADER
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter(&"tint", tint)
	m.set_shader_parameter(&"strength", strength)
	m.set_shader_parameter(&"height", HEIGHT)
	m.set_shader_parameter(&"sharpness", sharpness)
	m.set_shader_parameter(&"reach", 0.0)
	return m


func _column(top: float, bottom: float, material: ShaderMaterial) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = HEIGHT
	mesh.cap_top = false
	mesh.cap_bottom = false
	mesh.radial_segments = 32
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Its foot on the ground under the hero.
	node.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	add_child(node)
	return node


func _process(delta: float) -> void:
	_age += delta
	var parent := get_parent() as Node3D
	if parent != null:
		# Follows him, but stays upright.
		global_position = parent.global_position
	_apply(_age)
	if _age >= LIFE:
		queue_free()


## Everything at `age` seconds.
func _apply(age: float) -> void:
	var reach := clampf(age / DESCEND, 0.0, 1.0)
	reach = 1.0 - pow(1.0 - reach, 2.0)
	var landed := clampf((age - DESCEND) / 0.25, 0.0, 1.0)
	var out := 1.0 - clampf((age - (LIFE - FADE)) / FADE, 0.0, 1.0)
	# A flash as it lands, then a slow breathing while it stands.
	var flash := exp(-pow((age - DESCEND - 0.05) / 0.12, 2.0))
	var breathe := 0.9 + 0.1 * sin(age * 9.0)
	var thin := lerpf(0.35, 1.0, out)
	for m: ShaderMaterial in [_outer, _inner]:
		m.set_shader_parameter(&"reach", reach)
	_outer.set_shader_parameter(&"strength", (0.45 + 0.6 * flash) * breathe * out)
	_inner.set_shader_parameter(&"strength", (0.85 + 1.2 * flash) * breathe * out)
	_outer_mesh.scale = Vector3(thin * (1.0 + 0.25 * flash), 1.0, thin * (1.0 + 0.25 * flash))
	_inner_mesh.scale = Vector3(thin, 1.0, thin)
	_ground.set_shader_parameter(&"glow", landed * out * (1.0 + flash))
	var spread := clampf((age - DESCEND) / 1.1, 0.0, 1.0)
	_ground.set_shader_parameter(&"ring", 0.2 + 0.8 * spread)
	_ground.set_shader_parameter(&"ring_strength", landed * (1.0 - spread) * 1.5)
	_light.light_energy = (2.5 * landed + 7.0 * flash) * out
	_motes.emitting = age > DESCEND and age < LIFE - FADE * 0.8
