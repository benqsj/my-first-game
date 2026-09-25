class_name HuntingLight
extends Node3D

## Avtandil's Hunter's Mark in flight: a gold glint thrown off his pointing
## hand, arcing onto the prey, a thin line left in the air behind it. It only
## draws; what lands is decided by whoever threw it ([method Player.net_hunters_mark]).

signal arrived(at: Vector3)

const GOLD := Color(1.0, 0.72, 0.25)

var _from := Vector3.ZERO
var _quarry: Node3D
var _to := Vector3.ZERO
var _time: float = 0.3
var _age: float = 0.0
var _arc: float = 0.6
var _streak: MeshInstance3D
var _line: MeshInstance3D
var _line_mat: StandardMaterial3D
var _motes: GPUParticles3D
var _done: bool = false


## Throws it from `from` at `quarry` (its aim point, as it moves), over `time`.
func throw(from: Vector3, quarry: Node3D, aim: Vector3, time: float = 0.3) -> void:
	_from = from
	_quarry = quarry
	_to = aim
	_time = maxf(time, 0.05)
	_arc = clampf(from.distance_to(aim) * 0.05, 0.2, 1.0)


func _ready() -> void:
	top_level = true
	_streak = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.05
	cap.height = 1.0
	_streak.mesh = cap
	_streak.material_override = SkillFx.glow(GOLD, 4.0)
	_streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_streak)
	_line = SkillFx.rod(self, _from, _from, GOLD, 0.008, 2.0)
	_line_mat = _line.material_override as StandardMaterial3D
	_motes = SkillFx.particles(self, _from, {
		"amount": 40, "life": 0.5, "speed": Vector2(0.1, 0.5), "spread": 180.0,
		"gravity": Vector3(0, 0.4, 0), "damping": 1.5, "size": Vector2(0.02, 0.04),
		"colors": [Color(1, 0.95, 0.7, 1), GOLD, Color(1, 0.2, 0.1, 0)],
	})
	SkillFx.flash(self, _from, GOLD, 0.25, 0.15, 3.0)


func _process(delta: float) -> void:
	if _done:
		return
	_age += delta
	if _quarry != null and is_instance_valid(_quarry):
		_to = _aim_of(_quarry)
	var u := clampf(_age / _time, 0.0, 1.0)
	var at := _from.lerp(_to, pow(u, 1.15)) + Vector3.UP * _arc * sin(PI * u)
	var ahead := _from.lerp(_to, pow(minf(u + 0.05, 1.0), 1.15)) + Vector3.UP * _arc * sin(PI * minf(u + 0.05, 1.0))
	var length := minf(1.8, _from.distance_to(at) + 0.2)
	var dir := (ahead - at).normalized() if ahead.distance_squared_to(at) > 0.00001 else (_to - _from).normalized()
	SkillFx.place_rod(_streak, at - dir * length * 0.5, at + dir * 0.05)
	_motes.global_position = at
	SkillFx.place_rod(_line, _from, at)
	if u >= 1.0:
		_done = true
		_streak.hide()
		_motes.emitting = false
		arrived.emit(at)
		var tw := create_tween()
		tw.tween_property(_line_mat, "albedo_color:a", 0.0, 0.45)
		tw.tween_interval(0.5)
		tw.tween_callback(queue_free)


## A creature's chest, or thereabouts.
static func _aim_of(who: Node3D) -> Vector3:
	var h: Variant = who.get(&"body_height")
	var s := 1.0
	if who is Fighter:
		s = float(who.get(&"visual_scale"))
	return who.global_position + Vector3.UP * (float(h) * s * 0.6 if h != null else 1.0)
