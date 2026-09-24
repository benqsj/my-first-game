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

## The cycle the legs come from, and where in it they are (seconds).
var cycle: Animation
var time: float = 0.0
## 0 = the swing's own legs, 1 = the cycle's.
var weight: float = 0.0

var _tracks: Array[Vector2i] = []
var _tracks_for: Animation


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
	for tb in _tracks:
		var leg := cycle.rotation_track_interpolate(tb.x, at)
		var own := skel.get_bone_pose_rotation(tb.y)
		skel.set_bone_pose_rotation(tb.y, own.slerp(leg, weight))


func _find_tracks(skel: Skeleton3D) -> void:
	_tracks.clear()
	_tracks_for = cycle
	for t in cycle.get_track_count():
		if cycle.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name := String(cycle.track_get_path(t).get_concatenated_subnames())
		if bone_name in LEG_BONES:
			var bone := skel.find_bone(bone_name)
			if bone >= 0:
				_tracks.append(Vector2i(t, bone))
