class_name ArmHold
extends SkeletonModifier3D
## The shield arm held where it was through a blow that got through (the
## user, 2026-10-04: in the heavy flinches the shield flew up and turned over
## — "ugly"). Every frame it is not holding it notes the arm's pose; asked to
## [method hold], it lays that pose back over whatever the hit clip does to
## the arm, fading in at once and out at the end, so the body reels (the back,
## the head, the legs are the clip's) and the shield stays before him. On the
## mannequin, before [HitLean]: the lean still bends the back with the arm on
## it.

## The left arm, from the shoulder out.
const CHAIN: Array = [&"clavicle_l", &"upperarm_l", &"lowerarm_l", &"hand_l"]
## The one held as the body holds it (skeleton space) rather than in its parent.
const UPPER := &"upperarm_l"
## How quickly it takes the arm over and gives it back (seconds).
const FADE_IN := 0.04
const FADE_OUT := 0.25

var _bones := PackedInt32Array()
var _kept: Array[Quaternion] = []
var _left := 0.0
var _total := 0.0
var _weight := 0.0
var _upper := -1
var _kept_upper := Quaternion.IDENTITY


## Holds the arm as it was for `seconds`.
func hold(seconds: float) -> void:
	_left = maxf(seconds, 0.0)
	_total = _left


## Lets it go now (a fall, a death, a swing).
func release() -> void:
	_left = 0.0


## Whether it is holding the arm, and how much (for a test).
func holding() -> float:
	return _weight


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	if _bones.is_empty():
		for b: StringName in CHAIN:
			var i := skel.find_bone(b)
			if i >= 0:
				_bones.append(i)
				_kept.append(skel.get_bone_pose_rotation(i))
		_upper = skel.find_bone(UPPER)
	var dt := get_process_delta_time()
	if dt <= 0.0:
		dt = get_physics_process_delta_time()
	if _left > 0.0:
		_left = maxf(_left - dt, 0.0)
		var since := _total - _left
		_weight = minf(since / FADE_IN, 1.0) * minf(_left / FADE_OUT, 1.0)
	else:
		_weight = 0.0
	if _weight <= 0.0:
		# not holding: what the clips do now is what is kept — the shoulder
		# and the hand in their parents, the upper arm as the body holds it
		for k in _bones.size():
			_kept[k] = skel.get_bone_pose_rotation(_bones[k])
		if _upper >= 0:
			_kept_upper = skel.get_bone_global_pose(_upper).basis.get_rotation_quaternion()
		return
	for k in _bones.size():
		var b := _bones[k]
		if b == _upper:
			# the upper arm held as the body held it, not as the chest now
			# leans: thrown back, the shield does not go up over his head
			var g := skel.get_bone_global_pose(b)
			var q := g.basis.get_rotation_quaternion().slerp(_kept_upper, _weight)
			skel.set_bone_global_pose(b, Transform3D(Basis(q).scaled(g.basis.get_scale()), g.origin))
			continue
		var now := skel.get_bone_pose_rotation(b)
		skel.set_bone_pose_rotation(b, now.slerp(_kept[k], _weight))
