class_name AirSwirl
extends Node3D

## A little whirl of air at the head of the drawn arrow while the Piercing
## Arrow is held: three pale bands turning round the arrowhead and a few
## motes drawn round and in. Small and see-through — the shot itself is the
## big wind ([WindBlast]); this is the breath before it. Follows the arrow on
## the string ([method SkinnedArcherRig.arrow_tip]); shows only while there is
## one, fades in, and goes after `time`.

var _rig: Node
var _time: float = 1.0
var _age: float = 0.0
var _bands: Array[MeshInstance3D] = []
var _mats: Array[StandardMaterial3D] = []
var _motes: GPUParticles3D


func start(rig: Node, time: float) -> void:
	_rig = rig
	_time = time


func _ready() -> void:
	top_level = true
	for k in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = WindBlast._band_mesh(2.4)
		var mat := WindBlast._band_material().duplicate() as StandardMaterial3D
		mat.albedo_color.a = 0.0
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_bands.append(mi)
		_mats.append(mat)
	_motes = SkillFx.particles(self, global_position, {
		"amount": 26, "life": 0.35, "speed": Vector2(0.0, 0.1), "sphere": 0.14, "orbit": -4.0,
		"tangent": 6.0, "damping": 1.0, "size": Vector2(0.012, 0.028), "grow": 0.4, "local": true,
		"add": false,
		"colors": [Color(1, 1, 1, 0.0), Color(WindBlast.AIR.r, WindBlast.AIR.g, WindBlast.AIR.b, 0.55),
			Color(WindBlast.AIR.r, WindBlast.AIR.g, WindBlast.AIR.b, 0.0)],
	})
	_motes.emitting = false


func _process(delta: float) -> void:
	_age += delta
	if _rig == null or not is_instance_valid(_rig) or _age > _time:
		queue_free()
		return
	var dir := Vector3.ZERO
	if _rig.has_method(&"arrow_dir"):
		dir = _rig.call(&"arrow_dir")
	var on := dir.length_squared() > 0.5
	_motes.emitting = on
	for mi in _bands:
		mi.visible = on
	if not on:
		return
	var tip: Vector3 = _rig.call(&"arrow_tip")
	_motes.global_position = tip
	var fade := clampf(_age / 0.3, 0.0, 1.0) * clampf((_time - _age) / 0.1, 0.0, 1.0)
	var up := Vector3.RIGHT if absf(dir.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var base := Basis.looking_at(dir, up)
	for k in _bands.size():
		var r := 0.07 + 0.035 * float(k)
		var turn := _age * (11.0 - 2.0 * float(k)) + float(k) * 2.1
		# Each band a little behind the last, winding back along the shaft.
		var at := tip + dir * (0.06 - 0.07 * float(k))
		_bands[k].global_transform = Transform3D(base.rotated(dir, turn).scaled(Vector3(r, r, 0.12)), at)
		_mats[k].albedo_color.a = (0.5 - 0.1 * float(k)) * fade
