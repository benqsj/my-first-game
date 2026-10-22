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
## Its own step sounds instead of a man's (a creature's heavier tread), how
## they are pitched, and the two foot bones by name (left, right) where they
## are not a man's.
var sounds: Array[String] = []
var pitch: float = 1.0
var bone_names: PackedStringArray = PackedStringArray()
## How big a puff of dust goes up off each footfall (0: none).
var dust: float = 0.0

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
## Where each foot was when the skeleton was last posed, every modifier done
## (its `skeleton_updated`), in the skeleton's frame. A modifier's pose is only
## there while the skeleton is drawn: read later in the frame the bones are
## back to the clip's, and under a clip that stands while a stride is laid on
## its legs (a sword drawn on the run, a cut) the feet never lifted and the
## steps went quiet.
var _posed: Array[Vector3] = []


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
	if _skel != null and is_instance_valid(_skel) and _skel.skeleton_updated.is_connected(_on_posed):
		_skel.skeleton_updated.disconnect(_on_posed)
	_skel = skel
	_posed.clear()
	if not skel.skeleton_updated.is_connected(_on_posed):
		skel.skeleton_updated.connect(_on_posed)
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
	Sfx.warm(_sounds())
	return true


func _sounds() -> Array[String]:
	return sounds if not sounds.is_empty() else STEPS


func _on_posed() -> void:
	if _skel == null or not is_instance_valid(_skel):
		return
	_posed.resize(_feet.size())
	for k in _feet.size():
		_posed[k] = _skel.get_bone_global_pose(_feet[k]).origin


func _find_foot(side: String) -> int:
	if bone_names.size() == 2:
		return _skel.find_bone(bone_names[0 if side == "l" else 1])
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
		var foot := _posed[k] if k < _posed.size() else _skel.get_bone_global_pose(_feet[k]).origin
		var y := (_skel.global_transform * foot).y - base_y
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
			_step(speed, body, _skel.global_transform * foot)


func _step(speed: float, body: Node3D, at: Vector3) -> void:
	if _clock - _last_step < min_gap:
		return
	_last_step = _clock
	steps_played += 1
	var all := _sounds()
	var i := randi() % all.size()
	if i == _last_index:
		i = (i + 1) % all.size()
	_last_index = i
	var loud := clampf(inverse_lerp(min_speed, run_speed, speed), 0.0, 1.0)
	Sfx.play(body, all[i], body, Vector3.ZERO, pitch * lerpf(0.95, 1.05, randf()),
			volume_db + lerpf(-3.0, 0.0, loud))
	if dust > 0.0:
		# a dull low puff off the heel, a little more at a run: earth, not a ring
		var k := dust * lerpf(0.7, 1.0, loud)
		SkillFx.particles(Blood.world_of(body), Vector3(at.x, body.global_position.y + 0.06, at.z), {
			"amount": 4, "life": 0.7, "one_shot": true, "explosiveness": 0.9, "add": false,
			"speed": Vector2(0.25, 0.7) * k, "dir": Vector3.UP, "spread": 80.0, "gravity": Vector3(0, -0.4, 0),
			"damping": 2.0, "size": Vector2(0.14, 0.28) * k, "grow": 0.3, "sphere": 0.12 * k,
			"colors": [Color(0.6, 0.55, 0.47, 0.0), Color(0.58, 0.53, 0.46, 0.22), Color(0.55, 0.5, 0.45, 0.0)],
		})

