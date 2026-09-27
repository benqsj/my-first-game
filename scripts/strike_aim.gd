class_name StrikeAim
extends SkeletonModifier3D

## A cut thrown at what it is meant for, however low that is.
##
## Mixamo's swings cut at the height of a man's chest. Something shorter — a
## puglin, a wolf down on its belly — is under the blade, and the swing goes
## over it however well it is aimed. This bends the swing down to it: the knees
## give (the hips let down, the thighs and shins folding so the feet stay where
## they are), and the trunk leans in over the hips towards it, the head held up.
## Laid over whatever the swing is doing, so the swing is still the swing, only
## lower; and turned a little towards it if it has moved aside since the cut
## began.
##
## Runs after the AnimationPlayer and the [StrideModifier], before the cape.

## Where the cut is aimed, in the world; `weight` how much of the bend is on
## (0 to 1, eased by the rig).
var target: Vector3 = Vector3.ZERO
var weight: float = 0.0
## The height over his feet a swing cuts at on its own (metres).
var natural: float = 1.2
## The most the knees may let the hips down (metres), and the share of the
## drop they take; the most the trunk leans (radians).
var squat_max: float = 0.3
var squat_share: float = 0.35
var lean_max: float = 0.9
## The most it turns towards the target at the waist (radians).
var turn_max: float = 0.5

var _bones := {}


func _ready() -> void:
	active = true


func _process_modification() -> void:
	if weight <= 0.001:
		return
	var skel := get_skeleton()
	if skel == null:
		return
	if _bones.is_empty():
		for n in ["root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head",
				"thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r"]:
			_bones[n] = skel.find_bone(n)
	var body := skel.global_transform
	var feet := body.origin.y
	var fwd := -body.basis.z.normalized()
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		return
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var drop := clampf(feet + natural - target.y, 0.0, 1.4) * weight
	# Turned towards it at the waist, if it is off to one side.
	var to := target - body.origin
	to.y = 0.0
	var turn := 0.0
	if to.length_squared() > 0.04:
		turn = clampf(fwd.signed_angle_to(to.normalized(), Vector3.UP), -turn_max, turn_max) * weight
	if drop < 0.01 and absf(turn) < 0.01:
		return

	# The knees give first.
	var squat := minf(drop * squat_share, squat_max)
	if squat > 0.005 and _bones["pelvis"] >= 0:
		var pel: int = _bones["pelvis"]
		var parent := skel.get_bone_parent(pel)
		var pg := skel.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
		var down_s := body.basis.inverse() * Vector3(0.0, -squat, 0.0)
		var down_local := pg.basis.inverse() * down_s
		skel.set_bone_pose_position(pel, skel.get_bone_pose_position(pel) + down_local)
		for side in ["l", "r"]:
			_fold_leg(skel, body, right, side, squat)
	# Then the trunk leans in over the hips for the rest.
	var rest := drop - squat
	var lean := clampf(rest / 0.8, 0.0, 1.0) * lean_max
	var spine := ["spine_01", "spine_02", "spine_03"]
	var shares := [0.4, 0.35, 0.25]
	for i in spine.size():
		var b: int = _bones[spine[i]]
		if b < 0:
			continue
		_turn_world(skel, body, b, right, -lean * float(shares[i]))
		if absf(turn) > 0.001:
			_turn_world(skel, body, b, Vector3.UP, turn * float(shares[i]))
	# The head held up to look at it.
	var neck: int = _bones["neck_01"]
	if neck >= 0 and lean > 0.01:
		_turn_world(skel, body, neck, right, lean * 0.45)


## Folds a leg so the hips can come down `squat` metres over a foot that stays
## put: the thigh forward, the shin back twice as far, the foot level again.
func _fold_leg(skel: Skeleton3D, body: Transform3D, right: Vector3, side: String, squat: float) -> void:
	var thigh: int = _bones["thigh_" + side]
	var calf: int = _bones["calf_" + side]
	var foot: int = _bones["foot_" + side]
	if thigh < 0 or calf < 0:
		return
	var hip := skel.get_bone_global_pose(thigh).origin
	var knee := skel.get_bone_global_pose(calf).origin
	var ankle := skel.get_bone_global_pose(foot).origin if foot >= 0 else knee
	var reach := (knee - hip).length() + (ankle - knee).length()
	var bend := acos(clampf(1.0 - squat / maxf(reach, 0.1), -1.0, 1.0))
	_turn_world(skel, body, thigh, right, bend)
	_turn_world(skel, body, calf, right, -bend * 2.0)
	if foot >= 0:
		_turn_world(skel, body, foot, right, bend)


## Turns a bone about a world axis, `angle` radians (right-handed about it).
func _turn_world(skel: Skeleton3D, body: Transform3D, bone: int, axis: Vector3, angle: float) -> void:
	var gp := skel.get_bone_global_pose(bone)
	var axis_s := (body.basis.inverse() * axis).normalized()
	var turned := Basis(axis_s, angle) * gp.basis.orthonormalized()
	var parent := skel.get_bone_parent(bone)
	var pb := skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	skel.set_bone_pose_rotation(bone, (pb.inverse() * turned).get_rotation_quaternion())
