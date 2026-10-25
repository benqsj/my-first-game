class_name TrollSun
extends Node3D
## A shaft of sunlight down into the troll's ground (the user's pick,
## 2026-10-25: a troll is turned to stone by the sun). Drawn as a column of
## soft gold light down from above with motes turning in it and a warm pool
## of light where it meets the ground; no ring. The troll, made to stand in
## it a while, stiffens into stone and goes down ([TrollFighter]); the shaft
## then fades, and comes back a while later.

const RADIUS := 1.9
const TALL := 26.0
const GOLD := Color(1.0, 0.86, 0.55)

var active: bool = true
var _outer: StandardMaterial3D
var _inner: StandardMaterial3D
var _light: SpotLight3D
var _motes: GPUParticles3D
var _shown: float = 1.0


## Every peer: a shaft standing on the ground at `at`.
static func make(into: Node, at: Vector3) -> TrollSun:
	if into == null:
		return null
	var s := TrollSun.new()
	s.name = "TrollSun"
	into.add_child(s)
	s.global_position = at
	s._build()
	return s


func _build() -> void:
	_outer = _glow_mat(0.09)
	_inner = _glow_mat(0.07)
	_add_column(RADIUS * 0.8, RADIUS * 1.05, _outer)
	_add_column(RADIUS * 0.45, RADIUS * 0.6, _inner)
	_light = SpotLight3D.new()
	_light.light_color = GOLD
	_light.light_energy = 7.0
	_light.spot_range = TALL * 0.9
	_light.spot_angle = 7.0
	_light.shadow_enabled = false
	add_child(_light)
	_light.position = Vector3.UP * (TALL * 0.75)
	_light.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_motes = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(RADIUS * 0.7, 3.5, RADIUS * 0.7)
	pm.gravity = Vector3(0.0, -0.08, 0.0)
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.12
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(GOLD, 0.0))
	fade.set_color(1, Color(GOLD, 0.0))
	fade.add_point(0.3, Color(GOLD, 0.8))
	fade.add_point(0.7, Color(GOLD, 0.6))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	_motes.process_material = pm
	_motes.amount = 30
	_motes.lifetime = 4.0
	_motes.preprocess = 4.0
	var quad := QuadMesh.new()
	# (the motes themselves this small: a quad of 1 m drew white squares
	# filling the view)
	quad.size = Vector2(0.06, 0.06)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# (gone near the view too: one that drifted by the camera drew a great
	# white square)
	qm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	qm.distance_fade_min_distance = 3.0
	qm.distance_fade_max_distance = 8.0
	quad.material = qm
	_motes.draw_pass_1 = quad
	add_child(_motes)
	_motes.position = Vector3.UP * 3.5


func _glow_mat(alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.albedo_color = Color(GOLD, alpha)
	# (gone near the view: from inside it, or close by, it washed the whole
	# view over)
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 2.5
	m.distance_fade_max_distance = 9.0
	m.set_meta(&"alpha", alpha)
	return m


func _add_column(top: float, bottom: float, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = TALL
	c.radial_segments = 14
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	mi.mesh = c
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = Vector3.UP * (TALL * 0.5)


## Whether `at` stands in it (flat).
func covers(at: Vector3) -> bool:
	var d := at - global_position
	d.y = 0.0
	return active and d.length() <= RADIUS


## Every peer: faded out (spent on the troll) or back.
func set_active(on: bool) -> void:
	active = on
	var tw := create_tween()
	tw.tween_method(_show, _shown, 1.0 if on else 0.0, 1.5 if on else 0.8)


func _show(k: float) -> void:
	_shown = k
	_outer.albedo_color.a = float(_outer.get_meta(&"alpha")) * k
	_inner.albedo_color.a = float(_inner.get_meta(&"alpha")) * k
	_light.light_energy = 7.0 * k
	_motes.emitting = k > 0.3
