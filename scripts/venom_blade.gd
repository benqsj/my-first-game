class_name VenomBlade
extends Node3D

## The Assassin's Poisoned Blade, as it is drawn: the knife brought up before
## his chest, two fingers of the other hand run along it from the guard to the
## point — the blade greening behind them as they go, a green breath off the
## fingers — then the excess flicked off with a snap of the wrist, and the blade
## glowing and dripping for as long as the poison lasts.
##
## Only looks. That the blade poisons is [Player]'s to decide
## (`_venom_until`, and [method Player.blade_hit] where a cut lands).
##
## The timings are those of `DG_Poison_Coat` (built in Blender by
## `vepxis-art/tools/dg9_build.py`), in clip frames at 30 a second.

const VENOM := Color(0.38, 1.0, 0.16)
const DARK := Color(0.1, 0.4, 0.05)
const WIPE_FROM := 13.0
const WIPE_TO := 29.0
const FLICK := 33.0
const DONE := 46.0

var _rig: Node
## The venom's colour: the poisoner's people's ([method RogueSkills.venom_of]).
var tint: Color = VENOM
var _rate: float = 1.4
var _lasts: float = 10.0
var _age: float = 0.0

var _coat: MeshInstance3D
var _coat_mat: StandardMaterial3D
var _drips: GPUParticles3D
var _fumes: GPUParticles3D
var _breath: GPUParticles3D
var _light: OmniLight3D
var _flicked: bool = false


## Starts it on `rig`, the coat played at `rate`, the poison lasting `lasts`
## seconds after the coat is done.
func start(rig: Node, rate: float, lasts: float) -> void:
	_rig = rig
	_rate = maxf(rate, 0.01)
	_lasts = lasts


func _ready() -> void:
	top_level = true
	_coat = SkillFx.rod(self, Vector3.ZERO, Vector3.ZERO, tint, 0.011, 2.4)
	_coat_mat = _coat.material_override as StandardMaterial3D
	_coat_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_coat.hide()
	_drips = SkillFx.particles(self, Vector3.ZERO, {
		"amount": 14, "life": 0.6, "speed": Vector2(0.0, 0.2), "spread": 30.0, "dir": Vector3.DOWN,
		"gravity": Vector3(0, -9.0, 0), "size": Vector2(0.012, 0.02), "box": Vector3(0.02, 0.02, 0.02),
		"add": false, "grow": 0.05,
		"colors": [tint, tint, Color(tint, 0.0)],
	})
	_drips.emitting = false
	_fumes = SkillFx.particles(self, Vector3.ZERO, {
		"amount": 10, "life": 1.0, "speed": Vector2(0.03, 0.15), "spread": 40.0,
		"gravity": Vector3(0, 0.2, 0), "size": Vector2(0.03, 0.06), "box": Vector3(0.04, 0.04, 0.04),
		"grow": 0.25, "colors": [Color(tint, 0.0), Color(tint.darkened(0.15), 0.25), Color(tint.darkened(0.6), 0.0)],
	})
	_fumes.emitting = false
	# Off the fingertips as they run down the blade.
	_breath = SkillFx.particles(self, Vector3.ZERO, {
		"amount": 12, "life": 0.45, "speed": Vector2(0.02, 0.1), "spread": 60.0,
		"gravity": Vector3(0, 0.3, 0), "size": Vector2(0.015, 0.03), "box": Vector3(0.015, 0.015, 0.015),
		"grow": 0.15, "colors": [Color(tint.lightened(0.2), 0.0), Color(tint.lightened(0.1), 0.5), Color(tint.darkened(0.5), 0.0)],
	})
	_breath.emitting = false
	# Only the blade and the hand at it are lit green: a small, faint light (a
	# big one turned his whole body green).
	_light = OmniLight3D.new()
	_light.light_color = tint
	_light.omni_range = 0.7
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

	# How much of the blade is wet: from the guard out as the fingers go.
	var wet := clampf((frame - WIPE_FROM) / (WIPE_TO - WIPE_FROM), 0.0, 1.0)
	wet = wet * wet * (3.0 - 2.0 * wet)
	if frame >= WIPE_FROM:
		_coat.show()
		SkillFx.place_rod(_coat, base, base + along * (0.08 + 0.92 * wet))
	var done_at := DONE / 30.0 / _rate
	var left := _lasts - (_age - done_at)
	var fade := clampf(left / 1.2, 0.0, 1.0)
	_coat_mat.albedo_color.a = fade * (0.85 + 0.15 * sin(_age * 6.0))
	_light.global_position = base + along * 0.6
	_light.light_energy = 0.15 * wet * fade
	_drips.global_position = base + along * lerpf(0.1, 0.6, wet)
	_fumes.global_position = base + along * 0.6
	_drips.emitting = frame >= WIPE_TO and left > 0.5
	_fumes.emitting = frame >= WIPE_TO and left > 1.0
	var wiping := frame >= WIPE_FROM and frame <= WIPE_TO + 1.0
	_breath.emitting = wiping
	if wiping:
		_breath.global_position = base + along * (0.08 + 0.92 * wet)
	if frame >= FLICK and not _flicked:
		_flicked = true
		SkillFx.burst(get_parent(), tip - along * 0.3, tint, 26, Vector2(1.5, 4.0),
				(along.cross(Vector3.UP)).normalized(), 50.0, Vector2(0.012, 0.022), Vector3(0, -9, 0), 0.5)
	if left <= 0.0:
		queue_free()
