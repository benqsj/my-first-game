class_name Footsteps
extends Node

## A footfall sound each time a foot comes down on the ground, timed off the
## feet themselves: each foot bone's height over the body's origin is watched,
## and a foot that has been lifted and comes back down to the ground plays a
## step. So the sound keeps with the legs at any pace and on any clip — a run,
## a walk, a strafe — with no per-clip timings to keep up to date.
##
## Added by `Player` to its rig. Plays for everybody's heroes, not just your
## own: it reads only the pose and the speed, both of which every peer has.

const STEPS: Array[String] = [
	"res://unverified/sounds/persons/run/step_1.wav", "res://unverified/sounds/persons/run/step_2.wav",
	"res://unverified/sounds/persons/run/step_3.wav", "res://unverified/sounds/persons/run/step_4.wav",
	"res://unverified/sounds/persons/run/step_5.wav", "res://unverified/sounds/persons/run/step_6.wav",
	"res://unverified/sounds/persons/run/step_7.wav", "res://unverified/sounds/persons/run/step_8.wav",
	"res://unverified/sounds/persons/run/step_9.wav", "res://unverified/sounds/persons/run/step_10.wav",
]

## Height over the lowest a foot has been that counts as lifted, and as down.
@export var lift_height: float = 0.08
@export var plant_height: float = 0.045
## Below this planar speed the body is standing: shuffles make no sound.
@export var min_speed: float = 1.2
## Speed at which the step is at full loudness; slower is quieter.
@export var run_speed: float = 5.0
@export var volume_db: float = -16.0
## Two steps closer than this are one (a foot bouncing on the plant).
@export var min_gap: float = 0.16

var _skel: Skeleton3D
var _rig: Node
var _feet: Array[int] = []
var _lifted: Array[bool] = []
var _floor: Array[float] = []
var _last_step: float = -10.0
var _clock: float = 0.0
var _last_index: int = -1
## Steps heard so far, for the tests.
var steps_played: int = 0


## `rig` is the node holding the model; finds the skeleton and its two feet.
## A rig that changes skeletons (YOUR OWN on the mannequin, see
## [method SkinnedRig.skeleton_now]) is asked which one moves each frame.
func attach(rig: Node) -> bool:
	_rig = rig
	var found := rig.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return false
	return _use(found.front() as Skeleton3D)


func _use(skel: Skeleton3D) -> bool:
	_skel = skel
	_feet.clear()
	_lifted.clear()
	_floor.clear()
	for side: String in ["l", "r"]:
		var bone := _find_foot(side)
		if bone >= 0:
			_feet.append(bone)
			_lifted.append(false)
			_floor.append(INF)
	if _feet.is_empty():
		return false
	Sfx.warm(STEPS)
	return true


func _find_foot(side: String) -> int:
	for bone_name: String in ["foot_" + side, "foot." + side.to_upper(), "Foot_" + side.to_upper(),
			"mixamorig:%sFoot" % ("Left" if side == "l" else "Right")]:
		var i := _skel.find_bone(bone_name)
		if i >= 0:
			return i
	return -1


## Called once a frame after the rig has posed. `speed` is the planar speed,
## `grounded` whether the body is on the floor, `body` the hero.
func tick(delta: float, speed: float, grounded: bool, body: Node3D) -> void:
	_clock += delta
	if _rig != null and is_instance_valid(_rig) and _rig.has_method(&"skeleton_now"):
		var now := _rig.call(&"skeleton_now") as Skeleton3D
		if now != null and now != _skel:
			_use(now)
	if _skel == null or not is_instance_valid(_skel):
		return
	var base_y := body.global_position.y
	for k in _feet.size():
		var y := (_skel.global_transform * _skel.get_bone_global_pose(_feet[k])).origin.y - base_y
		# The lowest the foot sits, easing back up slowly so a slope or a
		# crouch does not leave the reference stuck low.
		_floor[k] = minf(y, _floor[k] + delta * 0.1) if _floor[k] < INF else y
		var over := y - _floor[k]
		if not grounded or speed < min_speed:
			_lifted[k] = false
			continue
		if over > lift_height:
			_lifted[k] = true
		elif _lifted[k] and over < plant_height:
			_lifted[k] = false
			_step(speed, body)


func _step(speed: float, body: Node3D) -> void:
	if _clock - _last_step < min_gap:
		return
	_last_step = _clock
	steps_played += 1
	var i := randi() % STEPS.size()
	if i == _last_index:
		i = (i + 1) % STEPS.size()
	_last_index = i
	var loud := clampf(inverse_lerp(min_speed, run_speed, speed), 0.0, 1.0)
	Sfx.play(body, STEPS[i], body, Vector3.ZERO, lerpf(0.95, 1.05, randf()),
			volume_db + lerpf(-3.0, 0.0, loud))

