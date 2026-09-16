class_name SkeletonAnim
extends Node3D

## Plays the Quaternius "Universal Animation Library 2" clips on any *skinned*
## model whose bones carry the Unreal mannequin names.
##
## This is the sibling of [AnimRetarget], and the two exist for opposite reasons.
## Tariel is a hierarchy of rigid parts with no skeleton, so that script has to
## solve a correction per joint and pose the parts by hand. The monsters out of
## the Bestiary kit arrive the other way round: a real [Skeleton3D], skinned, and
## already built to the same bone convention as the library — `pelvis`,
## `spine_01`, `upperarm_l`, `thigh_l`, `foot_l`, the lot. Nothing has to be
## solved. Every bone is matched by name and the pose is carried across as a
## *delta from rest*:
##
##     target_pose = target_rest · (source_rest⁻¹ · source_pose)
##
## which is the whole retarget. Because it is relative to each rig's own rest,
## proportions survive: the Imp is 1.4 m tall and the Puglin 0.75 m against the
## mannequin's 1.6 m, and both walk with their own legs rather than being
## stretched onto the mannequin's.
##
## The kit's rigs are missing the pinky chain and the toe leaves. Those are
## simply skipped — a bone with no counterpart keeps its rest pose, which for a
## finger nobody will ever see is exactly right.
##
## The library is never drawn. Its meshes are hidden and its player is stepped by
## hand from [method advance], so the pose read out belongs to the frame being
## drawn rather than to whenever the mixer last ran.

## Emitted when a one-shot clip reaches its end.
signal clip_finished(clip: StringName)

const SOURCE_SCENE := "res://assets/anim/ual2.glb"

## Bones the retarget leaves alone. Fingers are below the size of a pixel at the
## distance these creatures are fought at, and copying twenty of them per monster
## per frame is the bulk of what this script would otherwise cost.
const SKIP_PREFIXES: PackedStringArray = [
	"index_", "middle_", "pinky_", "ring_", "thumb_",
]

var _skeleton: Skeleton3D
var _player: AnimationPlayer
var _target: Skeleton3D

## Parallel arrays, built once: which bone of the library feeds which bone of the
## target, and the two rest bases the delta is measured between.
var _src_bone := PackedInt32Array()
var _dst_bone := PackedInt32Array()
var _src_rest_inverse: Array[Basis] = []
var _dst_rest: Array[Basis] = []

var _src_pelvis: int = -1
var _dst_pelvis: int = -1
var _pelvis_rest: Vector3 = Vector3.ZERO
var _dst_pelvis_rest: Vector3 = Vector3.ZERO
## How much shorter the target is than the mannequin, which is how far the hip
## travel written into a clip has to be brought down.
var _pelvis_scale: float = 1.0
## Ratio of this body's leg to the mannequin's, which is what decides how far one
## of its strides actually carries it. Set apart from `_pelvis_scale` because a
## creature can be squat — the Puglin's legs are shorter than its height alone
## would suggest, and it takes correspondingly smaller steps.
var _limb_scale: float = 1.0

var _weight: float = 0.0
var _target_weight: float = 0.0
var _fade_speed: float = 10.0
var _clip: StringName = &""
var _ready_to_play: bool = false


## Points the layer at a skeleton and works out the bone pairing. Returns false
## if the library is missing or nothing matched, in which case the caller should
## carry on without animation rather than crash.
func setup(target: Skeleton3D) -> bool:
	if target == null:
		push_warning("SkeletonAnim: no skeleton to drive.")
		return false
	if not ResourceLoader.exists(SOURCE_SCENE):
		push_warning("SkeletonAnim: %s is missing, clips disabled." % SOURCE_SCENE)
		return false

	_target = target

	var scene: Node3D = (load(SOURCE_SCENE) as PackedScene).instantiate()
	scene.name = "AnimSource"
	add_child(scene)

	_skeleton = scene.find_child("Skeleton3D", true, false) as Skeleton3D
	_player = scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _skeleton == null or _player == null:
		push_warning("SkeletonAnim: no skeleton or animation player in the library.")
		scene.queue_free()
		return false

	# The mannequin is a source of angles, not a thing in the world.
	for mesh in scene.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).visible = false
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_player.animation_finished.connect(_on_clip_finished)

	_pair_bones()
	if _src_bone.is_empty():
		push_warning("SkeletonAnim: no bone of '%s' matched the library." % target.name)
		scene.queue_free()
		return false

	_ready_to_play = true
	return true


func _pair_bones() -> void:
	for dst in _target.get_bone_count():
		var bone_name := _target.get_bone_name(dst)
		if _is_skipped(bone_name):
			continue
		var src := _skeleton.find_bone(bone_name)
		if src < 0:
			continue
		_src_bone.append(src)
		_dst_bone.append(dst)
		_src_rest_inverse.append(_skeleton.get_bone_rest(src).basis.orthonormalized().inverse())
		_dst_rest.append(_target.get_bone_rest(dst).basis.orthonormalized())

	_src_pelvis = _skeleton.find_bone("pelvis")
	_dst_pelvis = _target.find_bone("pelvis")
	if _src_pelvis >= 0 and _dst_pelvis >= 0:
		_pelvis_rest = _skeleton.get_bone_rest(_src_pelvis).origin
		_dst_pelvis_rest = _target.get_bone_rest(_dst_pelvis).origin
		# Measured from where the hips stand off the ground, not from the bone's
		# offset from its parent, so a rig with a different root still scales.
		var src_height := _skeleton.get_bone_global_rest(_src_pelvis).origin.y
		var dst_height := _target.get_bone_global_rest(_dst_pelvis).origin.y
		_pelvis_scale = dst_height / maxf(src_height, 0.01)

	_limb_scale = _leg_length(_target) / maxf(_leg_length(_skeleton), 0.01)


## Hip to heel, in the skeleton's own frame. Falls back to the pelvis height so a
## rig with unexpected leg bone names still gets a sensible number.
static func _leg_length(skeleton: Skeleton3D) -> float:
	var thigh := skeleton.find_bone("thigh_l")
	var foot := skeleton.find_bone("foot_l")
	if thigh < 0 or foot < 0:
		var pelvis := skeleton.find_bone("pelvis")
		return skeleton.get_bone_global_rest(pelvis).origin.y if pelvis >= 0 else 1.0
	return (skeleton.get_bone_global_rest(thigh).origin
			- skeleton.get_bone_global_rest(foot).origin).length()


static func _is_skipped(bone_name: String) -> bool:
	for prefix in SKIP_PREFIXES:
		if bone_name.begins_with(prefix):
			return true
	return false


#region Playback
## Starts a clip. `fade` is the cross-fade in seconds; `weight` caps how far the
## clip overrides the skeleton's rest pose.
func play(clip: StringName, fade: float = 0.15, speed: float = 1.0,
		weight: float = 1.0) -> bool:
	if not _ready_to_play or not _player.has_animation(clip):
		return false
	if _clip == clip and _player.is_playing():
		# Already running: only the strength and the rate are being changed, and
		# restarting would snap the cycle back to its first frame.
		_target_weight = clampf(weight, 0.0, 1.0)
		_fade_speed = 1.0 / maxf(fade, 0.01)
		_player.speed_scale = maxf(speed, 0.0)
		return true
	_clip = clip
	_target_weight = clampf(weight, 0.0, 1.0)
	_fade_speed = 1.0 / maxf(fade, 0.01)
	_player.play(clip, -1.0, speed)
	return true


## Retimes the running clip without restarting it — what a walk cycle needs so
## the feet keep up with the ground under them.
func set_speed(speed: float) -> void:
	if _ready_to_play and _player.is_playing():
		_player.speed_scale = maxf(speed, 0.0)


func stop(fade: float = 0.2) -> void:
	_target_weight = 0.0
	_fade_speed = 1.0 / maxf(fade, 0.01)


func has_clip(clip: StringName) -> bool:
	return _ready_to_play and _player.has_animation(clip)


func clip_length(clip: StringName) -> float:
	if not _ready_to_play:
		return 0.0
	var anim := _player.get_animation(clip)
	return anim.length if anim != null else 0.0


## How much ground one cycle of a walk clip covers on *this* body, in metres.
##
## Read off the clip rather than typed in, so swapping the walk for another one
## keeps the feet planted without a number being changed anywhere: the feet are
## furthest apart at mid-stride, which is one step, and a cycle is two of them.
## Brought onto the target by leg length, which is what decides how far a stride
## carries a creature.
func measure_stride(clip: StringName) -> float:
	const STEPS := 32
	if not has_clip(clip):
		return 0.0
	var anim := _player.get_animation(clip)
	if anim == null or anim.length <= 0.0:
		return 0.0
	var left := _skeleton.find_bone("foot_l")
	var right := _skeleton.find_bone("foot_r")
	if left < 0 or right < 0:
		return 0.0

	var step := 0.0
	var was := _player.current_animation
	_player.play(clip)
	for i in STEPS:
		_player.seek(anim.length * float(i) / STEPS, true)
		var gap := (_skeleton.get_bone_global_pose(left).origin
				- _skeleton.get_bone_global_pose(right).origin)
		gap.y = 0.0
		step = maxf(step, gap.length())
	_player.stop()
	if not was.is_empty():
		_player.play(was)
	return step * 2.0 * _limb_scale


func current_clip() -> StringName:
	return _clip


func weight() -> float:
	return _weight


## Steps the library on and writes the retargeted pose onto the model. Call once
## a frame, before anything reads the skeleton.
func advance(delta: float) -> void:
	if not _ready_to_play:
		return

	_weight = move_toward(_weight, _target_weight, _fade_speed * delta)
	if _weight <= 0.001:
		if _player.is_playing():
			_player.stop()
			_rest_pose()
		return

	if not _player.is_playing() and not _clip.is_empty():
		_player.play(_clip)
	_player.advance(delta)

	for i in _src_bone.size():
		var pose := _skeleton.get_bone_pose_rotation(_src_bone[i])
		var wanted := Quaternion(_dst_rest[i] * (_src_rest_inverse[i] * Basis(pose)))
		if _weight >= 0.999:
			_target.set_bone_pose_rotation(_dst_bone[i], wanted)
		else:
			# Fading in or out: blend against the model's own rest, which is the
			# pose it holds when nothing is driving it.
			var rest := _target.get_bone_rest(_dst_bone[i]).basis.get_rotation_quaternion()
			_target.set_bone_pose_rotation(_dst_bone[i], rest.slerp(wanted, _weight))

	if _dst_pelvis >= 0:
		var travel := _skeleton.get_bone_pose_position(_src_pelvis) - _pelvis_rest
		_target.set_bone_pose_position(_dst_pelvis,
				_dst_pelvis_rest + travel * _pelvis_scale * _weight)


## Puts every driven bone back where the model was built to stand.
func _rest_pose() -> void:
	for i in _src_bone.size():
		var dst := _dst_bone[i]
		_target.set_bone_pose_rotation(dst, _target.get_bone_rest(dst).basis.get_rotation_quaternion())
	if _dst_pelvis >= 0:
		_target.set_bone_pose_position(_dst_pelvis, _dst_pelvis_rest)


func _on_clip_finished(clip: StringName) -> void:
	clip_finished.emit(clip)
#endregion
