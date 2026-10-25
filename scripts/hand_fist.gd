class_name HandFist
extends SkeletonModifier3D
## A hand closed (the user's word, 2026-10-25: the troll's club was not in its
## hand at all): over whatever its clip does, each finger of the hand bent at
## its joints about the line across the palm (from the little finger's root
## to the first finger's), so a fist closes round what the hand holds or
## round nothing. Each joint is set from its rest turned by its bend, not added
## to the clip's: the pack's clips were made for an open hand.
##
## For Polysplit's skeleton (CREATURES_PACK.md): `side` "R" or "L". `close`
## 0..1 is how far (eased towards `want` by the owner: a fist for blows, round
## a haft for a weapon).

@export var side: String = "R"
@export_range(0.0, 1.0) var close: float = 1.0
## Degrees at each finger's three joints, and the thumb's.
@export var finger_bend: Vector3 = Vector3(80.0, 90.0, 60.0)
@export var thumb_bend: Vector3 = Vector3(20.0, 35.0, 30.0)

const FINGERS := ["index", "mid", "ring", "pinky"]

## [bone, rest rotation, axis in the bone's frame, degrees]
var _joints: Array = []
var _made: bool = false


func _make(skel: Skeleton3D) -> void:
	_made = true
	var p := side + "_"
	var a := skel.find_bone(p + "indexFinger_joint1")
	var b := skel.find_bone(p + "pinkyFinger_joint1")
	if a < 0 or b < 0:
		return
	# across the palm, in the skeleton's frame at rest; the bend goes the way
	# that brings the finger towards the palm (the side the equip joint is on)
	var across := (skel.get_bone_global_rest(a).origin - skel.get_bone_global_rest(b).origin).normalized()
	var wrist := skel.find_bone(p + "wrist_joint")
	var equip := skel.find_bone(p + "equip_joint")
	var mid := skel.find_bone(p + "midFinger_joint1")
	var sign := 1.0
	if wrist >= 0 and equip >= 0 and mid >= 0:
		var along := (skel.get_bone_global_rest(mid).origin - skel.get_bone_global_rest(wrist).origin).normalized()
		var palm := skel.get_bone_global_rest(equip).origin - skel.get_bone_global_rest(wrist).origin
		palm -= along * palm.dot(along)
		# turning `along` about `across` by a little: does it go palm-wards?
		var turned := along.rotated(across, 0.3)
		sign = 1.0 if (turned - along).dot(palm) > 0.0 else -1.0
	for f: String in FINGERS:
		for k in 3:
			_add(skel, "%s%sFinger_joint%d" % [p, f, k + 1], across, finger_bend[k] * sign)
	for k in 3:
		_add(skel, "%sthumbFinger_joint%d" % [p, k + 1], across, thumb_bend[k] * sign)


func _add(skel: Skeleton3D, name: String, across: Vector3, degrees: float) -> void:
	var i := skel.find_bone(name)
	if i < 0:
		return
	var g := skel.get_bone_global_rest(i).basis.orthonormalized()
	var axis := (g.inverse() * across).normalized()
	_joints.append([i, skel.get_bone_rest(i).basis.get_rotation_quaternion(), axis, degrees])


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	if not _made:
		_make(skel)
	if close <= 0.001:
		return
	for j: Array in _joints:
		var turn := Quaternion(j[2] as Vector3, deg_to_rad(float(j[3]) * close))
		skel.set_bone_pose_rotation(int(j[0]), (j[1] as Quaternion) * turn)
