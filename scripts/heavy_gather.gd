class_name HeavyGather
extends Node3D
## What gathers on the blade while a heavy blow is held back (the charged
## heavy, gameplay_plan.md, 2026-10-22): sparks drawn in to it, a light that
## grows with the gathering, the blade's middle glowing; let go full, a flash.
## Follows the blade (its base to its tip; the hand with no blade).

const GOLD := Color(1.0, 0.78, 0.36)
const CORE := Color(1.0, 0.95, 0.8)

var _rig: Node
var _time: float = 1.0
var _age: float = 0.0
var _light: OmniLight3D
var _inflow: GPUParticles3D
var _orb: MeshInstance3D
var _orb_mat: StandardMaterial3D


## Gathers on `rig`'s blade over `time` seconds.
static func on(rig: Node, time: float) -> HeavyGather:
	var into := Blood.world_of(rig) if rig != null else null
	if into == null:
		return null
	var g := HeavyGather.new()
	g._rig = rig
	g._time = maxf(time, 0.1)
	into.add_child(g)
	return g


func _ready() -> void:
	top_level = true
	var at := _blade()
	global_position = at
	_light = OmniLight3D.new()
	_light.light_color = GOLD
	_light.omni_range = 3.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.set_meta(&"designed_shadow", false)
	add_child(_light)
	_orb = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 12
	s.rings = 6
	_orb.mesh = s
	_orb_mat = SkillFx.glow(CORE, 3.0)
	_orb.material_override = _orb_mat
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_orb)
	_inflow = SkillFx.particles(self, at, {
		"amount": 64, "life": 0.4, "speed": Vector2(0.0, 0.1), "sphere": 0.75,
		"orbit": -7.0, "tangent": 4.0, "damping": 1.0, "size": Vector2(0.012, 0.03),
		"local": true, "grow": 0.3,
		"colors": [Color(1, 1, 1, 0.0), GOLD, Color(1, 0.95, 0.8, 1.0)],
	})


func _process(delta: float) -> void:
	_age += delta
	if _rig == null or not is_instance_valid(_rig):
		queue_free()
		return
	var at := _blade()
	global_position = at
	var u := clampf(_age / _time, 0.0, 1.0)
	_light.light_energy = 0.5 + 2.5 * u + (0.6 * sin(_age * 30.0) if u >= 1.0 else 0.0)
	var r := 0.03 + 0.11 * u + 0.012 * sin(_age * 24.0)
	_orb.scale = Vector3.ONE * r
	_inflow.amount_ratio = 0.3 + 0.7 * u


## Let go: gone, with a flash on the blade if it was gathered `share` enough.
func let_go(share: float) -> void:
	if share >= 0.5 and is_inside_tree():
		var into := get_parent()
		var ahead := Vector3.FORWARD
		if _rig is Node3D:
			ahead = -(_rig as Node3D).global_basis.z
		ParryFlash.burst(into, global_position, ahead, 0.5 + 0.5 * share)
	queue_free()


## The blade's middle, a little towards its tip; the body's chest with none.
func _blade() -> Vector3:
	var base: Variant = _rig.get(&"_blade_base")
	var tip: Variant = _rig.get(&"_blade_tip")
	if base is Node3D and tip is Node3D and is_instance_valid(base) and is_instance_valid(tip):
		return (base as Node3D).global_position.lerp((tip as Node3D).global_position, 0.62)
	if _rig is Node3D:
		return (_rig as Node3D).global_position + Vector3.UP * 1.2
	return global_position
