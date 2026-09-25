class_name AirSwirl
extends Node3D

## A little whirl of air at the head of the drawn arrow while the Piercing
## Arrow is held: five white bands turning round the arrowhead, motes whirling
## round it and air drawn in to it from round him. Small and see-through — the shot itself is the
## big wind ([WindBlast]); this is the breath before it. Follows the arrow on
## the string ([method SkinnedArcherRig.arrow_tip]); shows only while there is
## one, fades in, and goes after `time`.

var _rig: Node
var _time: float = 1.0
var _age: float = 0.0
var _bands: Array[MeshInstance3D] = []
var _mats: Array[StandardMaterial3D] = []
var _motes: GPUParticles3D
var _inflow: GPUParticles3D
var _glinted: bool = false


func start(rig: Node, time: float) -> void:
	_rig = rig
	_time = time


func _ready() -> void:
	top_level = true
	for k in 5:
		var mi := MeshInstance3D.new()
		mi.mesh = WindBlast._band_mesh(3.0)
		var mat := WindBlast._band_material().duplicate() as StandardMaterial3D
		mat.albedo_color.a = 0.0
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_bands.append(mi)
		_mats.append(mat)
	_motes = SkillFx.particles(self, global_position, {
		"amount": 60, "life": 0.4, "speed": Vector2(0.0, 0.15), "sphere": 0.22, "orbit": -5.0,
		"tangent": 8.0, "damping": 1.0, "size": Vector2(0.018, 0.04), "grow": 0.4, "local": true,
		"add": false,
		"colors": [Color(1, 1, 1, 0.0), Color(WindBlast.AIR.r, WindBlast.AIR.g, WindBlast.AIR.b, 0.85),
			Color(WindBlast.AIR.r, WindBlast.AIR.g, WindBlast.AIR.b, 0.0)],
	})
	_motes.emitting = false
	# Air drawn in from round him to the arrowhead, spiralling.
	_inflow = SkillFx.particles(self, global_position, {
		"amount": 70, "life": 0.5, "speed": Vector2(0.0, 0.05), "sphere": 0.9, "orbit": -12.0,
		"tangent": 7.0, "damping": 0.5, "size": Vector2(0.02, 0.045), "grow": 0.3, "local": true,
		"add": false,
		"colors": [Color(1, 1, 1, 0.0), Color(WindBlast.AIR.r, WindBlast.AIR.g, WindBlast.AIR.b, 0.7),
			Color(1, 1, 1, 0.0)],
	})
	_inflow.emitting = false


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
	_inflow.emitting = on
	for mi in _bands:
		mi.visible = on
	if not on:
		return
	var tip: Vector3 = _rig.call(&"arrow_tip")
	_motes.global_position = tip
	_inflow.global_position = tip
	var fade := clampf(_age / 0.3, 0.0, 1.0) * clampf((_time - _age) / 0.1, 0.0, 1.0)
	# Tension: the whirl tightens and quickens as the release comes, and the
	# head catches a glint just before it goes.
	var tense := clampf(_age / maxf(_time, 0.01), 0.0, 1.0)
	if not _glinted and _time - _age < 0.14:
		_glinted = true
		SkillFx.flash(get_parent(), tip, WindBlast.AIR, 0.28, 0.14, 4.0)
	var up := Vector3.RIGHT if absf(dir.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var base := Basis.looking_at(dir, up)
	for k in _bands.size():
		var r := (0.11 + 0.06 * float(k)) * (1.15 - 0.4 * tense)
		var turn := _age * (13.0 - 2.0 * float(k)) * (1.0 + 1.2 * tense) + float(k) * 1.6
		# Each band a little behind the last, winding back along the shaft.
		var at := tip + dir * (0.08 - 0.08 * float(k))
		_bands[k].global_transform = Transform3D(base.rotated(dir, turn).scaled(Vector3(r, r, 0.16)), at)
		_mats[k].albedo_color.a = (1.0 - 0.1 * float(k)) * fade
