class_name VenomBlade
extends Node3D

## The Assassin's Poisoned Blade, as it is drawn: a vial from the belt, the
## venom poured down the blade from the tip to the guard (it greens as it
## goes), the vial tossed away, the excess flicked off — and then the blade
## glowing and dripping for as long as the poison lasts.
##
## Only looks. That the blade poisons is [Player]'s to decide
## (`_venom_until`, and [method Player.blade_hit] where a cut lands).
##
## The timings are those of `DG_Poison_Coat` (baked in Blender from the
## preview, `vepxis-art/tools/v4_poison.py`), in clip frames at 30 a second.

const VENOM := Color(0.38, 1.0, 0.16)
const DARK := Color(0.1, 0.4, 0.05)
const SHOW_VIAL := 8.0
const POUR_FROM := 20.0
const POUR_TO := 44.0
const TOSS := 48.0
const FLICK := 58.0
const DONE := 70.0

var _rig: Node
var _rate: float = 1.4
var _lasts: float = 10.0
var _age: float = 0.0

var _coat: MeshInstance3D
var _coat_mat: StandardMaterial3D
var _vial: Node3D
var _stream: MeshInstance3D
var _drips: GPUParticles3D
var _fumes: GPUParticles3D
var _light: OmniLight3D
var _tossed: bool = false
var _flicked: bool = false


## Starts it on `rig`, the coat played at `rate`, the poison lasting `lasts`
## seconds after the coat is done.
func start(rig: Node, rate: float, lasts: float) -> void:
	_rig = rig
	_rate = maxf(rate, 0.01)
	_lasts = lasts


func _ready() -> void:
	top_level = true
	_coat = SkillFx.rod(self, Vector3.ZERO, Vector3.ZERO, VENOM, 0.011, 2.4)
	_coat_mat = _coat.material_override as StandardMaterial3D
	_coat_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_coat.hide()
	_stream = SkillFx.rod(self, Vector3.ZERO, Vector3.ZERO, VENOM, 0.005, 2.0)
	_stream.hide()
	_vial = _make_vial()
	add_child(_vial)
	_vial.hide()
	_drips = SkillFx.particles(self, Vector3.ZERO, {
		"amount": 14, "life": 0.6, "speed": Vector2(0.0, 0.2), "spread": 30.0, "dir": Vector3.DOWN,
		"gravity": Vector3(0, -9.0, 0), "size": Vector2(0.012, 0.02), "box": Vector3(0.02, 0.02, 0.02),
		"add": false, "grow": 0.05,
		"colors": [VENOM, VENOM, Color(VENOM.r, VENOM.g, VENOM.b, 0.0)],
	})
	_drips.emitting = false
	_fumes = SkillFx.particles(self, Vector3.ZERO, {
		"amount": 16, "life": 1.2, "speed": Vector2(0.05, 0.25), "spread": 40.0,
		"gravity": Vector3(0, 0.25, 0), "size": Vector2(0.05, 0.1), "box": Vector3(0.05, 0.05, 0.05),
		"grow": 0.3, "colors": [Color(0.4, 0.9, 0.2, 0.0), Color(0.35, 0.8, 0.15, 0.35), Color(0.2, 0.4, 0.1, 0.0)],
	})
	_fumes.emitting = false
	_light = OmniLight3D.new()
	_light.light_color = VENOM
	_light.omni_range = 1.6
	_light.light_energy = 0.0
	add_child(_light)


func _process(delta: float) -> void:
	_age += delta
	if _rig == null or not is_instance_valid(_rig):
		queue_free()
		return
	var frame := _age * 30.0 * _rate
	var blade := PackedVector3Array()
	if _rig.has_method(&"blade_points"):
		blade = _rig.call(&"blade_points")
	if blade.size() < 2:
		return
	var base := blade[0]
	var tip := blade[1]
	var along := tip - base

	# How much of the blade is wet: from the tip back as the pour runs.
	var wet := clampf((frame - POUR_FROM) / (POUR_TO - POUR_FROM), 0.0, 1.0)
	if frame >= POUR_FROM:
		_coat.show()
		SkillFx.place_rod(_coat, tip - along * (0.05 + 0.95 * wet), tip)
	var done_at := DONE / 30.0 / _rate
	var left := _lasts - (_age - done_at)
	var fade := clampf(left / 1.2, 0.0, 1.0)
	_coat_mat.albedo_color.a = fade * (0.85 + 0.15 * sin(_age * 6.0))
	_light.global_position = base + along * 0.6
	_light.light_energy = 0.5 * wet * fade
	var mid := base + along * lerpf(1.0, 0.3, wet)
	_drips.global_position = mid
	_fumes.global_position = base + along * 0.6
	_drips.emitting = frame >= POUR_FROM and left > 0.5
	_fumes.emitting = frame >= POUR_FROM + 6.0 and left > 1.0

	# The vial, while it is in hand.
	if frame >= SHOW_VIAL and not _tossed:
		var hand := base
		if _rig.has_method(&"bone_position"):
			hand = _rig.call(&"bone_position", &"hand_l")
		_vial.show()
		var point := tip - along * (0.05 + 0.95 * wet)
		var pouring := frame >= POUR_FROM - 3.0 and frame <= POUR_TO + 2.0
		var up := Vector3.UP
		if frame >= POUR_FROM - 6.0:
			# Tipped, its mouth down at the blade.
			up = (point - hand).normalized().lerp(Vector3.DOWN, 0.3).normalized()
		_vial.global_transform = Transform3D(_basis_up(up), hand + up * 0.02)
		var mouth := _vial.global_position + up * 0.13
		if pouring and mouth.distance_to(point) < 0.8:
			_stream.show()
			SkillFx.place_rod(_stream, mouth, point)
		else:
			_stream.hide()
		if frame >= TOSS:
			_toss(up)
	if frame >= FLICK and not _flicked:
		_flicked = true
		SkillFx.burst(get_parent(), tip - along * 0.3, VENOM, 26, Vector2(1.5, 4.0),
				(along.cross(Vector3.UP)).normalized(), 50.0, Vector2(0.012, 0.022), Vector3(0, -9, 0), 0.5)
	if left <= 0.0:
		queue_free()


## The vial goes over his shoulder, turning, and is gone.
func _toss(up: Vector3) -> void:
	_tossed = true
	_stream.hide()
	var thrown := _vial
	var from := thrown.global_position
	var into := get_parent()
	remove_child(thrown)
	into.add_child(thrown)
	thrown.global_position = from
	var back := -up.slide(Vector3.UP).normalized() if up.slide(Vector3.UP).length_squared() > 0.001 else Vector3.BACK
	var tw := thrown.create_tween().set_parallel(true)
	tw.tween_property(thrown, "global_position", from + back * 1.2 + Vector3.UP * 0.9, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(thrown, "rotation", thrown.rotation + Vector3(7.0, 3.0, 1.0), 0.8)
	tw.chain().tween_property(thrown, "global_position", from + back * 2.0 + Vector3.DOWN * 1.2, 0.45).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(thrown.queue_free)


static func _basis_up(up: Vector3) -> Basis:
	var y := up.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y)).orthonormalized()


## A small green glass bottle with a cork, standing on Y.
func _make_vial() -> Node3D:
	var v := Node3D.new()
	v.name = "Vial"
	var body := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.04
	s.height = 0.09
	body.mesh = s
	body.position = Vector3.UP * 0.045
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.3, 0.85, 0.2, 0.75)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.emission_enabled = true
	glass.emission = VENOM
	glass.emission_energy_multiplier = 1.2
	glass.roughness = 0.1
	body.material_override = glass
	v.add_child(body)
	var neck := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.012
	c.bottom_radius = 0.015
	c.height = 0.04
	neck.mesh = c
	neck.position = Vector3.UP * 0.105
	neck.material_override = glass
	v.add_child(neck)
	var cork := MeshInstance3D.new()
	var k := CylinderMesh.new()
	k.top_radius = 0.013
	k.bottom_radius = 0.012
	k.height = 0.02
	cork.mesh = k
	cork.position = Vector3.UP * 0.135
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.3, 0.15)
	cork.material_override = wood
	v.add_child(cork)
	return v
