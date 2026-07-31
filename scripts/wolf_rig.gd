class_name WolfRig
extends Node3D

## Procedural animation for the wolf monster.
##
## Same shape of problem as [TarielRig]: the model is a hierarchy of named joint
## nodes with no skeleton and no clips, so every pose is a rotation applied on
## top of the joint's rest orientation (its `extras.rest` in the source file).
##
## The one thing this rig does that the knight's does not is change gait. The
## creature runs on all fours and rears onto its hind legs to fight, and those
## are two different poses of the same joints, so both are written out as
## offsets from rest and cross-faded by a single `stance` value. Everything else
## — stride, claw swipes, tail — is layered on whatever that blend produced.
##
## Angles follow the model's own axes: it faces +Z, so a positive X rotation on
## a limb swings that limb backwards.

const REST := {
	"m_hips": Vector3(0.0, 0.0, 0.0),
	"m_spine": Vector3(0.62, 0.0, 0.0),
	"m_chest": Vector3(0.0, 0.0, 0.0),
	"m_neck": Vector3(-0.5, 0.0, 0.0),
	"m_head": Vector3(0.0, 0.0, 0.0),
	"m_jaw": Vector3(0.0, 0.0, 0.0),
	"m_shoulder_l": Vector3(0.2, 0.0, -0.35),
	"m_upperarm_l_end": Vector3(-0.95, 0.0, 0.0),
	"m_forearm_l_end": Vector3(-0.3, 0.0, 0.0),
	"m_hand_l": Vector3(0.0, 0.0, 0.0),
	"m_shoulder_r": Vector3(0.2, 0.0, 0.35),
	"m_upperarm_r_end": Vector3(-0.95, 0.0, 0.0),
	"m_forearm_r_end": Vector3(-0.3, 0.0, 0.0),
	"m_hand_r": Vector3(0.0, 0.0, 0.0),
	"m_hip_l": Vector3(-0.55, 0.0, -0.05),
	"m_thigh_l_end": Vector3(1.15, 0.0, 0.0),
	"m_shin_l_end": Vector3(-0.62, 0.0, 0.0),
	"m_foot_l": Vector3(0.0, 0.0, 0.0),
	"m_hip_r": Vector3(-0.55, 0.0, 0.05),
	"m_thigh_r_end": Vector3(1.15, 0.0, 0.0),
	"m_shin_r_end": Vector3(-0.62, 0.0, 0.0),
	"m_foot_r": Vector3(0.0, 0.0, 0.0),
	"m_tail_root": Vector3(-0.9, 0.0, 0.0),
}

const TAIL_CHAIN: Array[String] = ["m_tail_root", "m_tail_j0", "m_tail_j1", "m_tail_j2", "m_tail_j3", "m_tail_j4"]

## Offsets from rest that put the creature down on all fours: torso levelled
## out, neck lifted so it still looks ahead, front legs straightened to reach
## the ground.
const ON_ALL_FOURS := {
	"m_spine": Vector3(0.2, 0.0, 0.0),
	"m_neck": Vector3(-0.45, 0.0, 0.0),
	"m_head": Vector3(-0.2, 0.0, 0.0),
	"m_shoulder_l": Vector3(-0.95, 0.0, 0.0),
	"m_shoulder_r": Vector3(-0.95, 0.0, 0.0),
	"m_upperarm_l_end": Vector3(0.85, 0.0, 0.0),
	"m_upperarm_r_end": Vector3(0.85, 0.0, 0.0),
	"m_hip_l": Vector3(0.15, 0.0, 0.0),
	"m_hip_r": Vector3(0.15, 0.0, 0.0),
	"m_tail_root": Vector3(0.35, 0.0, 0.0),
}

## Offsets from rest for the upright fighting stance: spine stood up, arms
## carried forward with the claws ready.
const REARED := {
	"m_spine": Vector3(-0.5, 0.0, 0.0),
	"m_neck": Vector3(0.2, 0.0, 0.0),
	"m_shoulder_l": Vector3(-0.25, 0.0, -0.2),
	"m_shoulder_r": Vector3(-0.25, 0.0, 0.2),
	"m_upperarm_l_end": Vector3(-0.25, 0.0, 0.0),
	"m_upperarm_r_end": Vector3(-0.25, 0.0, 0.0),
	"m_hip_l": Vector3(0.3, 0.0, 0.0),
	"m_hip_r": Vector3(0.3, 0.0, 0.0),
	"m_tail_root": Vector3(-0.2, 0.0, 0.0),
}

## Limbs that come off when the knight cuts one. The value is the joint whose
## subtree is hidden; the key is only there to read back in a log.
const SEVERABLE := {
	"head": "m_head",
	"left arm": "m_shoulder_l",
	"right arm": "m_shoulder_r",
	"left leg": "m_hip_l",
	"right leg": "m_hip_r",
	"tail": "m_tail_root",
}

signal severed(part: String)

#region Exported tuning
@export_group("Stance")
## How far the hips drop between reared and on all fours, in metres.
@export var crouch_drop: float = 0.18
## How fast the creature changes gait.
@export var stance_speed: float = 5.0

@export_group("Stride")
@export var stride_length: float = 1.9
@export var run_stride_bonus: float = 1.6
@export var hip_swing: float = 0.62
@export var knee_bend: float = 0.55
## Front-leg reach while running on all fours.
@export var foreleg_swing: float = 0.7
@export var hip_bob: float = 0.06

@export_group("Attack")
@export var swipe_duration: float = 0.5
## How far the arm carries through the swipe, in radians.
@export var swipe_reach: float = 2.1

@export_group("Idle")
@export var breath_rate: float = 2.2
@export var breath_amount: float = 0.035

@export_group("Secondary motion")
@export var tail_stiffness: float = 7.0
@export var tail_swing: float = 0.5
#endregion

var _joints: Dictionary = {}
var _base: Dictionary = {}
var _hips_base_y: float = 0.0

var _phase: float = 0.0
var _speed_blend: float = 0.0
var _stance: float = 1.0
var _swipe_timer: float = 0.0
var _swipe_left: bool = true
var _tail_angles: PackedFloat32Array = PackedFloat32Array()

## Mesh nodes making up each severable limb, so a hit can be tested against
## where the limb actually is rather than where its joint happens to sit.
var _limb_meshes: Dictionary = {}

var _trail_l: SwordTrail
var _trail_r: SwordTrail
var _lost: Dictionary = {}
var _rng := RandomNumberGenerator.new()
## Where the last limb came off, so the blow can bleed from the right place.
var last_cut_point: Vector3 = Vector3.ZERO


func _ready() -> void:
	for joint_name: String in REST:
		var node := find_child(joint_name, true, false) as Node3D
		if node == null:
			push_warning("WolfRig: joint '%s' is missing." % joint_name)
			continue
		_joints[joint_name] = node
		_base[joint_name] = REST[joint_name]
		node.rotation = REST[joint_name]
	for joint_name in TAIL_CHAIN:
		if _joints.has(joint_name):
			continue
		var node := find_child(joint_name, true, false) as Node3D
		if node != null:
			_joints[joint_name] = node
			_base[joint_name] = REST.get(joint_name, Vector3.ZERO)
			node.rotation = _base[joint_name]

	_tail_angles.resize(TAIL_CHAIN.size())
	var hips := _joints.get("m_hips") as Node3D
	if hips != null:
		_hips_base_y = hips.position.y

	for part: String in SEVERABLE:
		var joint := _joints.get(SEVERABLE[part]) as Node3D
		if joint == null:
			continue
		var meshes: Array[MeshInstance3D] = []
		for m in joint.find_children("*", "MeshInstance3D", true, false):
			meshes.append(m as MeshInstance3D)
		_limb_meshes[part] = meshes

	_rng.randomize()
	_setup_trails()


## Hangs an air-cutting streak off each paw, so the claws read the same way the
## knight's blade does.
func _setup_trails() -> void:
	_trail_l = _make_trail("m_hand_l", "m_claw_l1")
	_trail_r = _make_trail("m_hand_r", "m_claw_r1")


func _make_trail(wrist_name: String, claw_name: String) -> SwordTrail:
	var wrist := find_child(wrist_name, true, false) as Node3D
	var claw := find_child(claw_name, true, false) as Node3D
	if wrist == null or claw == null:
		return null
	var trail := SwordTrail.new()
	trail.tint = Color(0.85, 0.92, 1.0, 0.4)
	trail.sample_count = 12
	trail.fade_time = 0.18
	add_child(trail)
	trail.setup(wrist, claw)
	return trail


## Driven once a frame by the controller. `stance_target` is 1 on all fours and
## 0 reared up on the hind legs.
func animate(delta: float, planar_speed: float, speed_ratio: float, stance_target: float) -> void:
	if _joints.is_empty():
		return

	_swipe_timer = maxf(_swipe_timer - delta, 0.0)
	_speed_blend = lerpf(_speed_blend, clampf(speed_ratio, 0.0, 1.0), 1.0 - exp(-10.0 * delta))
	_stance = lerpf(_stance, clampf(stance_target, 0.0, 1.0), 1.0 - exp(-stance_speed * delta))

	var stride := stride_length + run_stride_bonus * _speed_blend
	_phase = wrapf(_phase + TAU * planar_speed / maxf(stride, 0.01) * delta, 0.0, TAU)

	var t := Time.get_ticks_msec() / 1000.0
	_pose_stance()
	_pose_gait()
	_pose_arms(t)
	_pose_tail(delta)
	_plant_feet()

	var swiping := _swipe_timer > 0.0
	if _trail_l != null:
		_trail_l.emitting = swiping and _swipe_left
	if _trail_r != null:
		_trail_r.emitting = swiping and not _swipe_left


## Starts a claw swipe, alternating paws so it never rakes with the same one twice.
func swipe() -> void:
	_swipe_left = not _swipe_left
	_swipe_timer = swipe_duration


func is_swiping() -> bool:
	return _swipe_timer > 0.0


## Takes a limb off if the blade passed within `tolerance` of the creature.
##
## Which limb goes is picked at random from what is left rather than by what the
## edge was nearest: a fight where the same cut always lands the same way stops
## being interesting after the second one.
func sever_along_edge(from: Vector3, to: Vector3, tolerance: float) -> String:
	if not _blade_reaches(from, to, tolerance):
		return ""
	var remaining: Array[String] = []
	for part: String in SEVERABLE:
		if not _lost.has(part):
			remaining.append(part)
	if remaining.is_empty():
		return ""
	return _take(remaining[_rng.randi() % remaining.size()])


## True when the blade passed close enough to any limb still attached.
func _blade_reaches(from: Vector3, to: Vector3, tolerance: float) -> bool:
	for part: String in SEVERABLE:
		if _lost.has(part):
			continue
		var joint := _joints.get(SEVERABLE[part]) as Node3D
		if joint == null:
			continue
		# Measure to the limb itself: an arm is a metre long, and judging it by
		# its shoulder pivot alone would miss a cut through the middle of it.
		var distance := INF
		for m: MeshInstance3D in _limb_meshes.get(part, []):
			var centre := m.global_transform * m.get_aabb().get_center()
			distance = minf(distance, Geometry3D.get_closest_point_to_segment(centre, from, to).distance_to(centre))
		var pivot := joint.global_position
		distance = minf(distance, Geometry3D.get_closest_point_to_segment(pivot, from, to).distance_to(pivot))
		if distance <= tolerance:
			return true
	return false


## Detaches a limb: it stops following the body and drops where it was cut.
func _take(part: String) -> String:
	_lost[part] = true
	var joint := _joints[SEVERABLE[part]] as Node3D
	var where := joint.global_transform
	joint.visible = false

	# Built as a real node with the limb hung under it, rather than the limb
	# duplicated and given a script afterwards: a script attached after the node
	# is already in the tree never gets its _ready, so the piece would hang in
	# the air instead of falling.
	var world := Blood.world_of(self)
	if world == null:
		world = get_parent()
	var piece := SeveredLimb.new()
	piece.name = "SeveredLimb"
	world.add_child(piece)
	piece.global_transform = where

	var visual := joint.duplicate() as Node3D
	visual.visible = true
	visual.transform = Transform3D.IDENTITY
	piece.add_child(visual)

	var away := where.origin - global_position
	away.y = 0.0
	piece.launch(away)
	last_cut_point = where.origin

	severed.emit(part)
	return part


func lost_parts() -> int:
	return _lost.size()


func has_lost(part: String) -> bool:
	return _lost.has(part)


## True once both arms are gone: nothing left to fight with.
func is_disarmed() -> bool:
	return _lost.has("left arm") and _lost.has("right arm")


## Keeps the hind paws on the ground whatever the pose is doing.
##
## The creature swaps between two very different gaits and strides in both, and
## the legs are digitigrade, so where its feet end up is not something worth
## hand-tuning per pose. Measure the lowest foot after posing and lift the hips
## by that much: the stance can then be changed freely without it sinking into
## the floor or hovering over it.
func _plant_feet() -> void:
	var hips := _joints.get("m_hips") as Node3D
	if hips == null:
		return
	force_update_transform()

	var lowest := INF
	for foot_name in ["m_foot_l", "m_foot_r"]:
		var foot := find_child(foot_name, true, false) as Node3D
		if foot == null or not foot.visible:
			continue
		for m in foot.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if not mi.visible:
				continue
			var in_rig := global_transform.affine_inverse() * mi.global_transform
			lowest = minf(lowest, (in_rig * mi.get_aabb()).position.y)
	if is_inf(lowest):
		return
	hips.position.y -= lowest


#region Poses
func _pose_stance() -> void:
	# Blend the two gait poses first; everything after this layers on top.
	for joint_name: String in REST:
		var down: Vector3 = ON_ALL_FOURS.get(joint_name, Vector3.ZERO)
		var up: Vector3 = REARED.get(joint_name, Vector3.ZERO)
		_pose_joint(joint_name, up.lerp(down, _stance))

	var hips := _joints.get("m_hips") as Node3D
	if hips != null:
		hips.position.y = _hips_base_y - crouch_drop * _stance


func _pose_gait() -> void:
	var s := sin(_phase)
	var swing := hip_swing * _speed_blend
	var bend := knee_bend * _speed_blend

	# Hind legs always stride.
	_add_offset("m_hip_l", Vector3(swing * s, 0.0, 0.0))
	_add_offset("m_hip_r", Vector3(-swing * s, 0.0, 0.0))
	_add_offset("m_thigh_l_end", Vector3(maxf(0.0, sin(_phase - 0.6)) * bend, 0.0, 0.0))
	_add_offset("m_thigh_r_end", Vector3(maxf(0.0, sin(_phase - 0.6 + PI)) * bend, 0.0, 0.0))

	# On all fours the forelegs stride too, diagonally opposed to the hind legs
	# the way a real four-legged run works. Reared up they are free for clawing,
	# so the reach fades out with the stance.
	var fore := foreleg_swing * _speed_blend * _stance
	_add_offset("m_shoulder_l", Vector3(-swing * s * _stance * 0.5 - fore * s, 0.0, 0.0))
	_add_offset("m_shoulder_r", Vector3(swing * s * _stance * 0.5 + fore * s, 0.0, 0.0))
	_add_offset("m_upperarm_l_end", Vector3(maxf(0.0, sin(_phase + PI)) * bend * _stance, 0.0, 0.0))
	_add_offset("m_upperarm_r_end", Vector3(maxf(0.0, sin(_phase)) * bend * _stance, 0.0, 0.0))

	var hips := _joints.get("m_hips") as Node3D
	if hips != null:
		hips.position.y -= absf(sin(_phase)) * hip_bob * _speed_blend
	_add_offset("m_hips", Vector3(0.0, 0.0, sin(_phase) * 0.05 * _speed_blend))


func _pose_arms(t: float) -> void:
	var breathe := sin(t * breath_rate) * breath_amount * (1.0 - _speed_blend)
	_add_offset("m_chest", Vector3(breathe, 0.0, 0.0))

	if _swipe_timer <= 0.0:
		return

	# A rake across the body: wind the arm back and out, then drive it through
	# and let the shoulders follow so it is not just the limb moving.
	var a := 1.0 - _swipe_timer / maxf(swipe_duration, 0.001)
	var side := -1.0 if _swipe_left else 1.0
	var arm := "m_shoulder_l" if _swipe_left else "m_shoulder_r"
	var elbow := "m_upperarm_l_end" if _swipe_left else "m_upperarm_r_end"

	var reach := 0.0
	var across := 0.0
	var fold := 0.0
	if a < 0.3:
		var w := smoothstep(0.0, 1.0, a / 0.3)
		reach = -1.0 * w
		across = -0.9 * side * w
		fold = -0.9 * w
	else:
		var e := 1.0 - pow(1.0 - (a - 0.3) / 0.7, 3.0)
		reach = lerpf(-1.0, -0.2, e)
		across = lerpf(-0.9 * side, swipe_reach * side * 0.55, e)
		fold = lerpf(-0.9, 0.25, e)

	_add_offset(arm, Vector3(reach, across, 0.0))
	_add_offset(elbow, Vector3(fold, 0.0, 0.0))
	_add_offset("m_chest", Vector3(0.0, across * 0.3, 0.0))
	_add_offset("m_jaw", Vector3(0.35 * sin(a * PI), 0.0, 0.0))


func _pose_tail(delta: float) -> void:
	# The tail trails the body rather than being posed: each link chases the one
	# in front, so it sweeps in sequence.
	var drive := -tail_swing * _speed_blend + 0.25 * (1.0 - _stance)
	var flutter := sin(_phase * 1.5) * 0.12 * _speed_blend
	var weight := 1.0 - exp(-tail_stiffness * delta)
	var last := maxf(TAIL_CHAIN.size() - 1.0, 1.0)
	for i in TAIL_CHAIN.size():
		var target := (drive + flutter) * (0.4 + 0.6 * float(i) / last)
		_tail_angles[i] = lerpf(_tail_angles[i], target, weight * (1.0 - 0.1 * i))
		_add_offset(TAIL_CHAIN[i], Vector3(_tail_angles[i], 0.0, 0.0))
#endregion


func _pose_joint(joint_name: String, offset: Vector3) -> void:
	var node := _joints.get(joint_name) as Node3D
	if node != null:
		node.rotation = _base[joint_name] + offset


func _add_offset(joint_name: String, offset: Vector3) -> void:
	var node := _joints.get(joint_name) as Node3D
	if node != null:
		node.rotation += offset
