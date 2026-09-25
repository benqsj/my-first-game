class_name HuntingLight
extends Node3D

## Avtandil's Hunter's Mark in flight: a gold glint thrown off his pointing
## hand, arcing onto the prey — a bright head, a short comet's tail and a
## scatter of sparks that twinkle out behind it. No line is left hanging in
## the air (thrown on the run it stretched back to where he had been). It only
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
var _core: MeshInstance3D
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
	cap.radius = 0.03
	cap.height = 1.0
	_streak.mesh = cap
	var tail := SkillFx.glow(GOLD, 3.0, true, 0.55)
	_streak.material_override = tail
	_streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_streak)
	_core = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.07
	ball.height = 0.14
	_core.mesh = ball
	_core.material_override = SkillFx.glow(Color(1.0, 0.93, 0.7), 6.0)
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)
	_motes = SkillFx.particles(self, _from, {
		"amount": 60, "life": 0.35, "speed": Vector2(0.05, 0.35), "spread": 180.0,
		"gravity": Vector3(0, -0.6, 0), "damping": 2.0, "size": Vector2(0.015, 0.035), "grow": 0.1,
		"colors": [Color(1, 0.97, 0.8, 1), GOLD, Color(1, 0.45, 0.1, 0)],
	})
	SkillFx.flash(self, _from, GOLD, 0.14, 0.1, 3.0)


func _process(delta: float) -> void:
	if _done:
		return
	_age += delta
	if _quarry != null and is_instance_valid(_quarry):
		_to = _aim_of(_quarry)
	var u := clampf(_age / _time, 0.0, 1.0)
	var at := _from.lerp(_to, pow(u, 1.15)) + Vector3.UP * _arc * sin(PI * u)
	var ahead := _from.lerp(_to, pow(minf(u + 0.05, 1.0), 1.15)) + Vector3.UP * _arc * sin(PI * minf(u + 0.05, 1.0))
	var length := minf(0.6, _from.distance_to(at) + 0.1)
	var dir := (ahead - at).normalized() if ahead.distance_squared_to(at) > 0.00001 else (_to - _from).normalized()
	SkillFx.place_rod(_streak, at - dir * length, at)
	_core.global_position = at
	_core.scale = Vector3.ONE * (0.85 + 0.25 * sin(_age * 60.0))
	_motes.global_position = at
	if u >= 1.0:
		_done = true
		_streak.hide()
		_core.hide()
		_motes.emitting = false
		arrived.emit(at)
		var tw := create_tween()
		tw.tween_interval(0.5)
		tw.tween_callback(queue_free)


## A creature's chest, or thereabouts.
static func _aim_of(who: Node3D) -> Vector3:
	var h: Variant = who.get(&"body_height")
	var s := 1.0
	if who is Fighter:
		s = float(who.get(&"visual_scale"))
	return who.global_position + Vector3.UP * (float(h) * s * 0.6 if h != null else 1.0)
