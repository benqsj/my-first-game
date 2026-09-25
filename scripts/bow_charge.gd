class_name BowCharge
extends Node3D

## What gathers on the arrow while Avtandil holds a skill shot: for the
## Piercing Arrow, wind and light drawn in to a star at the arrowhead that grows
## with the draw, rings closing on it; for the Fire Arrow, the head catching
## and burning. Follows his bow hand; gone when the arrow is.

const WIND := Color(0.3, 0.82, 1.0)
const CORE := Color(1.0, 0.96, 0.85)
const FIRE := Color(1.0, 0.45, 0.08)

var _rig: Node
var _kind: StringName = &"wind"
var _time: float = 1.0
var _age: float = 0.0
var _next_ring: float = 0.0

var _orb: MeshInstance3D
var _orb_mat: StandardMaterial3D
var _inflow: GPUParticles3D
var _flame: GPUParticles3D
var _light: OmniLight3D


## `kind` is &"wind" or &"fire"; it lasts `time` seconds.
func start(rig: Node, kind: StringName, time: float) -> void:
	_rig = rig
	_kind = kind
	_time = time


func _ready() -> void:
	top_level = true
	var at := _hand()
	_light = OmniLight3D.new()
	_light.light_color = WIND if _kind == &"wind" else FIRE
	_light.omni_range = 1.6
	_light.light_energy = 0.0
	add_child(_light)
	if _kind == &"wind":
		_orb = MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		_orb.mesh = s
		_orb_mat = SkillFx.glow(CORE, 4.0)
		_orb.material_override = _orb_mat
		_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_orb)
		_inflow = SkillFx.particles(self, at, {
			"amount": 60, "life": 0.45, "speed": Vector2(0.0, 0.1), "sphere": 0.55,
			"orbit": -9.0, "tangent": 5.0, "damping": 1.0, "size": Vector2(0.015, 0.035),
			"local": true, "grow": 0.3,
			"colors": [Color(1, 1, 1, 0.0), WIND, Color(1, 1, 1, 1.0)],
		})
	else:
		SkillFx.burst(get_parent(), at, FIRE, 24, Vector2(1.0, 3.0), Vector3.UP, 80.0,
				Vector2(0.01, 0.025), Vector3(0, -4, 0), 0.4)
		_flame = SkillFx.particles(self, at, {
			"amount": 36, "life": 0.35, "speed": Vector2(0.2, 0.5), "spread": 20.0,
			"gravity": Vector3(0, 2.2, 0), "size": Vector2(0.1, 0.2), "sphere": 0.03,
			"tex": SkillFx.flame(), "quad": Vector2(0.5, 1.0), "add": false, "grow": 0.2,
			"colors": [Color(1.0, 0.62, 0.18, 0.0), Color(1.0, 0.5, 0.08, 0.95), Color(0.92, 0.2, 0.02, 0.85),
				Color(0.25, 0.03, 0.0, 0.0)],
		})


func _process(delta: float) -> void:
	_age += delta
	if _rig == null or not is_instance_valid(_rig) or _age > _time:
		queue_free()
		return
	var at := _hand()
	var u := clampf(_age / maxf(_time, 0.01), 0.0, 1.0)
	_light.global_position = at
	if _kind == &"wind":
		var r := 0.02 + 0.08 * u + 0.012 * sin(_age * 25.0)
		_orb.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * r), at)
		_inflow.global_position = at
		_light.light_energy = 0.4 + 1.0 * u
		if _age >= _next_ring:
			_next_ring = _age + 0.16
			var ahead := _ahead()
			SkillFx.ring(get_parent(), at + ahead * 0.25, ahead, WIND, 0.45, 0.04, 0.2, 0.05, 2.0)
	else:
		_flame.global_position = at
		_light.light_energy = 0.6 + 0.25 * sin(_age * 22.0)


## Where it gathers: on the head of the drawn arrow (the bow hand before the
## arrow is on the string).
func _hand() -> Vector3:
	if _rig != null and is_instance_valid(_rig):
		if _rig.has_method(&"arrow_tip"):
			return _rig.call(&"arrow_tip")
		if _rig.has_method(&"bow_hand"):
			return _rig.call(&"bow_hand")
	return global_position


## Which way the arrow points: from the draw hand past the bow hand.
func _ahead() -> Vector3:
	if _rig != null and is_instance_valid(_rig) and _rig.has_method(&"arrow_dir"):
		var along: Vector3 = _rig.call(&"arrow_dir")
		if along.length_squared() > 0.5:
			return along
	var fwd := Vector3.FORWARD
	var n3 := _rig as Node3D
	if n3 != null:
		fwd = -n3.global_transform.basis.z
	fwd.y = 0.0
	return fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD
