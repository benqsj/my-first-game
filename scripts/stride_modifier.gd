class_name StrideModifier
extends SkeletonModifier3D

## The legs of a walk or run cycle, laid under a sword swing.
##
## Mixamo's swings are played standing on the spot. Thrown out of a run, the
## body keeps its pace (the first cut of a flurry is meant to carry the charge)
## while the clip's feet stay planted, so he skated across the ground under
## the swing. This puts the stride back: while a swing plays and the body is
## moving, the thighs, calves, feet and toes are taken from the locomotion
## cycle that fits the way he is travelling, at the phase the run was at when
## the button went down, and the swing keeps the hips, the trunk and the arms.
##
## Runs after the AnimationPlayer has posed the skeleton, like [BowModifier],
## and before the cape's spring bones, so the cape still meets the legs it is
## actually hanging over.

const LEG_BONES: PackedStringArray = [
	"thigh_l", "calf_l", "foot_l", "ball_l",
	"thigh_r", "calf_r", "foot_r", "ball_r",
]

## The trunk and the shield arm too, for a clip that is the sword arm's
## alone (the sword put away or drawn on the run): the clip's own back is a man
## standing, and laid over a run it straightened him up mid-stride.
const UPPER_BONES: PackedStringArray = [
	"spine_01", "spine_02", "spine_03", "neck_01", "head",
	"clavicle_l", "upperarm_l", "lowerarm_l", "hand_l",
]
## Whether the trunk and the other arm come from the cycle as well.
var upper: bool = false
var _upper_tracks: Array[Vector2i] = []

## The cycle the legs come from, and where in it they are (seconds).
var cycle: Animation
var time: float = 0.0
## 0 = the swing's own legs, 1 = the cycle's.
var weight: float = 0.0

var _tracks: Array[Vector2i] = []
var _tracks_for: Animation
## The cycle's hips (position track, bone), or (-1, -1): the legs come with
## the height they were made at. Under a crouched clip (Kevin's block on the
## mannequin) a walk's straight legs from the clip's low hips went into the
## ground.
var _hips := Vector2i(-1, -1)
## The cycle's hips turn (rotation track, bone) and the bone over them whose
## turn in the world is kept: the legs hang off the hips, so under a clip
## standing square-on to its guard (Kevin's block) a walk's legs stepped out
## sideways while the body went ahead, and slid. The hips are turned as the
## cycle turns them, the trunk above left as the clip has it.
var _hips_turn := Vector2i(-1, -1)
var _trunk: int = -1


func _ready() -> void:
	active = true


func _process_modification() -> void:
	if weight <= 0.001 or cycle == null:
		return
	var skel := get_skeleton()
	if skel == null:
		return
	if _tracks_for != cycle:
		_find_tracks(skel)
	var at := fposmod(time, maxf(cycle.length, 0.01))
	if _hips_turn.x >= 0:
		var trunk_was := skel.get_bone_global_pose(_trunk) if _trunk >= 0 else Transform3D()
		var hips_own := skel.get_bone_pose_rotation(_hips_turn.y)
		skel.set_bone_pose_rotation(_hips_turn.y, hips_own.slerp(cycle.rotation_track_interpolate(_hips_turn.x, at), weight))
		if _trunk >= 0 and not upper:
			var hips_now := skel.get_bone_global_pose(_hips_turn.y)
			skel.set_bone_pose_rotation(_trunk, (hips_now.basis.orthonormalized().inverse()
					* trunk_was.basis.orthonormalized()).get_rotation_quaternion())
	for tb in _tracks:
		var leg := cycle.rotation_track_interpolate(tb.x, at)
		var own := skel.get_bone_pose_rotation(tb.y)
		skel.set_bone_pose_rotation(tb.y, own.slerp(leg, weight))
	if upper:
		for tb in _upper_tracks:
			var q := cycle.rotation_track_interpolate(tb.x, at)
			skel.set_bone_pose_rotation(tb.y, skel.get_bone_pose_rotation(tb.y).slerp(q, weight))
	if _hips.x >= 0:
		var at_hips := cycle.position_track_interpolate(_hips.x, at)
		var own_hips := skel.get_bone_pose_position(_hips.y)
		# the height only (up as the hips' parent sees it: the mannequin's root
		# lies on its back): the clip keeps where the hips are over the feet
		var parent := skel.get_bone_parent(_hips.y)
		var up := Vector3.UP
		if parent >= 0:
			up = (skel.get_bone_global_pose(parent).basis.inverse() * Vector3.UP).normalized()
		var rise := (at_hips - own_hips).dot(up) * weight
		skel.set_bone_pose_position(_hips.y, own_hips + up * rise)


func _find_tracks(skel: Skeleton3D) -> void:
	_tracks.clear()
	_upper_tracks.clear()
	_tracks_for = cycle
	_hips = Vector2i(-1, -1)
	_hips_turn = Vector2i(-1, -1)
	_trunk = skel.find_bone("spine_01")
	for t in cycle.get_track_count():
		if cycle.track_get_type(t) == Animation.TYPE_ROTATION_3D \
				and String(cycle.track_get_path(t).get_concatenated_subnames()) == "pelvis":
			var pb := skel.find_bone("pelvis")
			if pb >= 0 and _trunk >= 0 and skel.get_bone_parent(_trunk) == pb:
				_hips_turn = Vector2i(t, pb)
		if cycle.track_get_type(t) == Animation.TYPE_POSITION_3D \
				and String(cycle.track_get_path(t).get_concatenated_subnames()) == "pelvis":
			var hb := skel.find_bone("pelvis")
			if hb >= 0:
				_hips = Vector2i(t, hb)
		if cycle.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name := String(cycle.track_get_path(t).get_concatenated_subnames())
		if bone_name in LEG_BONES:
			var bone := skel.find_bone(bone_name)
			if bone >= 0:
				_tracks.append(Vector2i(t, bone))
		elif bone_name in UPPER_BONES:
			var ub := skel.find_bone(bone_name)
			if ub >= 0:
				_upper_tracks.append(Vector2i(t, ub))
