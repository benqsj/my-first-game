class_name CryptWater
extends Node

## The flooded crypt's water alive under whoever is in it (the user's word,
## 2026-10-24: a wake, the feet seen in it or treading on it): every few steps
## a body takes in it, a ring spreading from where it trod (and for the
## heroes a splash of drops); foam round each one standing in it; the light's
## pools under the vaults' holes. Feeds the water's shader ([CryptTomb]
## SHALLOW): `drops` (x, z, time, strength), `bodies` (x, z, radius, on),
## `pools` (x, z, radius, power), `now`. Each peer's own: only for the eye.

const DROPS := 24
const BODIES := 8
## How far a body goes between two rings, and how high above the water's
## floor it may be and still tread in it.
const STRIDE := 0.7
const WADE := 0.6

var _d: Dungeon
var _water: MeshInstance3D
var _mat: ShaderMaterial
var _half: Vector2
var _pools_local: Array[Vector3] = []
var _drops: Array[Vector4] = []
var _next := 0
var _last: Dictionary = {}
var _splashes: Array[GPUParticles3D] = []
var _splash_next := 0
var _tick := 0


func setup(d: Dungeon, water: MeshInstance3D, mat: ShaderMaterial, half: Vector2, pools: Array[Vector3]) -> void:
	_d = d
	_water = water
	_mat = mat
	_half = half
	_pools_local = pools


func _ready() -> void:
	_drops.resize(DROPS)
	for k in DROPS:
		_drops[k] = Vector4.ZERO
	var g := _water.global_position
	_mat.set_shader_parameter("centre", Vector2(g.x, g.z))
	var room := _water.get_parent() as Node3D
	var pools: Array[Vector4] = []
	for p in _pools_local:
		var at := room.global_position + Vector3(p.x, 0.0, p.y)
		pools.append(Vector4(at.x, at.z, p.z, 1.0))
	while pools.size() < 4:
		pools.append(Vector4.ZERO)
	_mat.set_shader_parameter("pools", pools)
	for k in 4:
		_splashes.append(_make_splash())


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _physics_process(_delta: float) -> void:
	_tick += 1
	if _tick % 2 != 0 or not is_instance_valid(_water):
		return
	var now := _now()
	var g := _water.global_position
	var floor_y := g.y
	var standing: Array[Vector4] = []
	var who: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group(&"player"):
		who.append(n as Node3D)
	for n in get_tree().get_nodes_in_group(&"enemy"):
		who.append(n as Node3D)
	for body in who:
		if body == null or not is_instance_valid(body) or not body.is_visible_in_tree():
			continue
		var at := body.global_position
		if absf(at.x - g.x) > _half.x or absf(at.z - g.z) > _half.y or at.y - floor_y > WADE \
				or at.y < floor_y - 1.0:
			continue
		if "is_dead" in body and bool(body.get("is_dead")):
			continue
		var big := 0.55 if body.is_in_group(&"enemy") and "body_radius" in body \
				and float(body.get("body_radius")) > 0.5 else 0.38
		if standing.size() < BODIES:
			standing.append(Vector4(at.x, at.z, big, 0.8))
		var key := body.get_instance_id()
		var last: Vector3 = _last.get(key, at + Vector3(99.0, 0.0, 0.0))
		var gone := Vector2(at.x - last.x, at.z - last.z).length()
		if gone > STRIDE:
			_last[key] = at
			if gone < 20.0:
				_drop(Vector2(at.x, at.z), now, 1.0 if big > 0.5 else 0.7)
				if body.is_in_group(&"player"):
					_splash(Vector3(at.x, floor_y + 0.05, at.z))
	while standing.size() < BODIES:
		standing.append(Vector4.ZERO)
	_mat.set_shader_parameter("bodies", standing)
	_mat.set_shader_parameter("drops", _drops)
	_mat.set_shader_parameter("now", now)


func _drop(at: Vector2, now: float, power: float) -> void:
	_drops[_next] = Vector4(at.x, at.y, now, power)
	_next = (_next + 1) % DROPS


## A few drops thrown up where a hero trod.
func _splash(at: Vector3) -> void:
	if _splashes.is_empty():
		return
	var p := _splashes[_splash_next]
	_splash_next = (_splash_next + 1) % _splashes.size()
	if not is_instance_valid(p):
		return
	p.global_position = at
	p.restart()


func _make_splash() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.2
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.4
	pm.gravity = Vector3(0.0, -9.0, 0.0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color(0.85, 0.95, 1.0, 0.8))
	fade.set_color(fade.get_point_count() - 1, Color(0.85, 0.95, 1.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = PlaceBuild.soft_dot()
	q.material = qm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
	add_child(p)
	return p
