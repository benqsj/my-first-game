class_name MageWind
extends Node3D

## The air that carries the mage when he leaves the ground: a vortex turning
## under his feet and wisps of it streaming down and round, as if the wind he
## rides were being pushed out beneath him.
##
## Two flat discs of spiralling light, turning opposite ways, under the soles,
## and a ring of wisps that orbit and fall away. How much of it there is follows
## `amount`, which the rig sets every frame: none on the ground, all of it in
## the air, more again while he floats.

var amount: float = 0.0

var _shown: float = 0.0
var _discs: Array[MeshInstance3D] = []
var _mats: Array[StandardMaterial3D] = []
var _wisps: GPUParticles3D
var _spin: float = 0.0

static var _swirl: ImageTexture = null


func _ready() -> void:
	for i in 2:
		var disc := MeshInstance3D.new()
		var quad := PlaneMesh.new()
		quad.size = Vector2(1.0, 1.0)
		disc.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_texture = _swirl_texture()
		mat.albedo_color = Color(0.75, 0.9, 1.0, 0.0) if i == 0 else Color(1.0, 0.85, 0.5, 0.0)
		mat.disable_receive_shadows = true
		disc.material_override = mat
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.position = Vector3(0.0, 0.06 - 0.12 * i, 0.0)
		add_child(disc)
		_discs.append(disc)
		_mats.append(mat)

	_wisps = GPUParticles3D.new()
	_wisps.amount = 60
	_wisps.lifetime = 0.7
	_wisps.local_coords = false
	_wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3.UP
	m.emission_ring_radius = 0.42
	m.emission_ring_inner_radius = 0.25
	m.emission_ring_height = 0.05
	m.direction = Vector3.DOWN
	m.spread = 20.0
	m.initial_velocity_min = 1.2
	m.initial_velocity_max = 2.4
	m.gravity = Vector3.ZERO
	m.orbit_velocity_min = 0.9
	m.orbit_velocity_max = 1.4
	m.radial_velocity_min = 0.3
	m.radial_velocity_max = 0.8
	m.damping_min = 1.0
	m.damping_max = 2.0
	m.scale_min = 0.6
	m.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.9, 0.97, 1.0, 0.0))
	ramp.add_point(0.15, Color(0.9, 0.97, 1.0, 0.8))
	ramp.set_color(ramp.get_point_count() - 1, Color(1.0, 0.8, 0.45, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	m.particle_flag_align_y = true
	_wisps.process_material = m
	var streak := QuadMesh.new()
	streak.size = Vector2(0.035, 0.26)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = GlowTail._edge_texture()
	streak.material = mat
	_wisps.draw_pass_1 = streak
	_wisps.emitting = false
	add_child(_wisps)


func _process(delta: float) -> void:
	_shown = move_toward(_shown, amount, delta / 0.25)
	_spin += delta * (5.0 + 3.0 * _shown)
	var breath := 1.0 + 0.08 * sin(_spin * 1.7)
	for i in _discs.size():
		var disc := _discs[i]
		disc.visible = _shown > 0.01
		disc.rotation.y = _spin * (1.0 if i == 0 else -1.4)
		var s := (1.15 + 0.45 * i) * lerpf(0.6, 1.0, minf(_shown, 1.0)) * breath
		disc.scale = Vector3(s, 1.0, s)
		var c := _mats[i].albedo_color
		c.a = clampf(_shown, 0.0, 1.3) * (0.75 if i == 0 else 0.5)
		_mats[i].albedo_color = c
	_wisps.emitting = _shown > 0.3
	_wisps.amount_ratio = clampf(_shown, 0.0, 1.0)


## Three arms of light winding out from a clear middle.
static func _swirl_texture() -> ImageTexture:
	if _swirl != null:
		return _swirl
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var dx := (x - c) / c
			var dy := (y - c) / c
			var r := sqrt(dx * dx + dy * dy)
			if r > 1.0:
				img.set_pixel(x, y, Color(1, 1, 1, 0))
				continue
			var a := atan2(dy, dx)
			var arm := 0.5 + 0.5 * cos(3.0 * a - r * 9.0)
			var band := smoothstep(0.18, 0.35, r) * (1.0 - smoothstep(0.75, 1.0, r))
			var v := pow(arm, 3.0) * band + 0.25 * band * (1.0 - smoothstep(0.3, 0.6, r))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(v, 0.0, 1.0)))
	_swirl = ImageTexture.create_from_image(img)
	return _swirl
