class_name Recoil
extends RefCounted

## What a parried blow does to the body that threw it.
##
## Every creature that swings at a player reels the same way when the swing is
## thrown back off a shield, whatever animates it — the orc's baked clips, the
## Bestiary creatures' library, Arkdeva's limbs posed in code:
##
## 1. **The rebound** (`REBOUND` seconds). The weapon goes back the way it came:
##    the clip that threw it is run backwards, fast, and on top of that the
##    swinging arm is thrown up and back and the chest goes back with it.
## 2. **The fold.** The blow's force spent, the body gives: it doubles forward
##    over itself, head down, and hangs there open.
## 3. **The recovery.** It straightens and comes back to its guard.
##
## The rebound and the fold are layered on top of whatever the clip says, bone
## by bone, as turns about the creature's own side-to-side axis — so they read
## the same on any skeleton, whichever way its bones happen to point.
##
## `STAGGER` is how long the creature stands open, and every peer plays this
## off the same act, so the reel is the same in every window.

## Seconds of the rebound, and of the whole reel.
const REBOUND := 0.3
const STAGGER := 1.6
## How much more a blow landed on a reeling creature takes off.
const RIPOSTE := 1.5


## 0 → 1 → 0 over the rebound, peaking early: the jolt.
static func back(t: float) -> float:
	if t <= 0.0 or t >= REBOUND * 2.0:
		return 0.0
	var x := t / (REBOUND * 2.0)
	# A fast rise and a slower settle.
	return sin(PI * pow(x, 0.6))


## 0 → 1 → 0 through the middle of the reel: the fold.
static func fold(t: float) -> float:
	var from := REBOUND * 1.1
	var to := STAGGER - 0.15
	if t <= from or t >= to:
		return 0.0
	var x := (t - from) / (to - from)
	# Drops into it, holds, comes up out of it.
	return smoothstep(0.0, 0.25, x) * (1.0 - smoothstep(0.7, 1.0, x))


## Turns `bone` by `angle` radians about `axis`, where `axis` is in the
## skeleton's own space. The turn is made in that space and put back into the
## bone's, so a positive angle about the creature's right-hand axis always
## tips the bone *back*, however the bone itself is oriented.
static func bend(skeleton: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
	if bone < 0 or absf(angle) < 0.0001:
		return
	var parent := skeleton.get_bone_parent(bone)
	var above := Quaternion.IDENTITY
	if parent >= 0:
		above = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	var local := skeleton.get_bone_pose_rotation(bone)
	var turn := Quaternion(axis.normalized(), angle)
	skeleton.set_bone_pose_rotation(bone, (above.inverse() * turn * above * local).normalized())


## The creature's side-to-side axis, in its skeleton's space. A turn about it
## by a positive angle tips things back, away from where it faces (-Z).
static func side_axis(skeleton: Skeleton3D, body: Node3D) -> Vector3:
	var right := body.global_transform.basis.x.normalized()
	return (skeleton.global_transform.basis.inverse() * right).normalized()


## The first of `names` the skeleton has, or -1.
static func find(skeleton: Skeleton3D, names: Array) -> int:
	for n in names:
		var i := skeleton.find_bone(String(n))
		if i >= 0:
			return i
	return -1


## The reel, `t` seconds in, laid over the pose the clip has just written.
## `bones` holds indices under "spine", "chest", "head", "arm_r", "arm_l",
## "forearm_r" (any may be -1); `two_handed` throws both arms.
static func pose(skeleton: Skeleton3D, body: Node3D, bones: Dictionary, t: float,
		two_handed: bool = false) -> void:
	var jolt := back(t)
	var give := fold(t)
	if jolt <= 0.0 and give <= 0.0:
		return
	var axis := side_axis(skeleton, body)
	# Order matters: parents first, so each child's turn is made in the space
	# its parent has already been turned into.
	bend(skeleton, int(bones.get("spine", -1)), axis, 0.28 * jolt - 0.42 * give)
	bend(skeleton, int(bones.get("chest", -1)), axis, 0.22 * jolt - 0.4 * give)
	bend(skeleton, int(bones.get("head", -1)), axis, 0.3 * jolt - 0.45 * give)
	bend(skeleton, int(bones.get("arm_r", -1)), axis, 1.0 * jolt + 0.25 * give)
	bend(skeleton, int(bones.get("forearm_r", -1)), axis, 0.5 * jolt)
	if two_handed:
		bend(skeleton, int(bones.get("arm_l", -1)), axis, 0.9 * jolt + 0.25 * give)
	else:
		# The free arm flung out for balance.
		bend(skeleton, int(bones.get("arm_l", -1)), axis, 0.45 * jolt - 0.2 * give)


## The bones [method pose] needs, by the names the rigs in this game use.
static func bones_of(skeleton: Skeleton3D) -> Dictionary:
	return {
		"spine": find(skeleton, ["Spine", "spine_01", "spine", "Spine1"]),
		"chest": find(skeleton, ["Spine01", "Spine2", "spine_03", "spine_02", "chest"]),
		"head": find(skeleton, ["Head", "head"]),
		"arm_r": find(skeleton, ["RightArm", "upperarm_r", "arm_r", "UpperArm_R"]),
		"forearm_r": find(skeleton, ["RightForeArm", "lowerarm_r", "forearm_r"]),
		"arm_l": find(skeleton, ["LeftArm", "upperarm_l", "arm_l", "UpperArm_L"]),
	}
