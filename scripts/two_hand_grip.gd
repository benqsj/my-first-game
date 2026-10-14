class_name TwoHandGrip
extends SkeletonModifier3D
## The other hand on the haft (the orc's great weapons, the user's word
## 2026-10-14: its second hand seemed not to hold the sword): over whatever
## its clip does, while its left hand is near the weapon's line it is drawn
## onto it — the arm bent to reach (two-bone, its elbow kept on the side it
## was), the hand turned as the clip had it. The clips were made for a man;
## on the orc's longer, broader arms the hand fell beside the grip. Where the
## clip's hand is far from the weapon (at rest on the shoulder, a blow with
## one hand) it is left alone.

## The hand that holds the weapon, and the weapon's line in its frame.
@export var hand_bone: String = "R_equip_joint"
@export var axis: Vector3 = Vector3.RIGHT
## Where along the line the other hand may hold (in the holding hand's frame,
## the skeleton's units): from, to.
@export var along: Vector2 = Vector2(-0.3, -0.08)
## Hands no closer than this along the line.
@export var apart: float = 0.08
## The other arm: upper, fore, the hand, the point of the hand that grips.
@export var upper_bone: String = "L_shoulder_joint"
@export var fore_bone: String = "L_elbow_joint"
@export var wrist_bone: String = "L_wrist_joint"
@export var grip_bone: String = "L_equip_joint"
## Off the line: drawn fully onto it within `near`, let go by `far`.
@export var near: float = 0.45
@export var far: float = 0.85

var _b := PackedInt32Array()


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	if _b.is_empty():
		for n in [hand_bone, upper_bone, fore_bone, wrist_bone, grip_bone]:
			_b.append(skel.find_bone(n))
	for b in _b:
		if b < 0:
			return
	var hand := skel.get_bone_global_pose(_b[0])
	var up := skel.get_bone_global_pose(_b[1])
	var fore := skel.get_bone_global_pose(_b[2])
	var wrist := skel.get_bone_global_pose(_b[3])
	var grip := skel.get_bone_global_pose(_b[4])
	var line := (hand.basis * axis).normalized()
	var rel := grip.origin - hand.origin
	var t := clampf(rel.dot(line), along.x, along.y)
	if absf(t) < apart:
		t = apart * (1.0 if t >= 0.0 else -1.0)
	var target := hand.origin + line * t
	var off := grip.origin.distance_to(target)
	var w := 1.0 - smoothstep(near, far, off)
	if w <= 0.001:
		return
	target = grip.origin.lerp(target, w)
	# two bones: the shoulder to the elbow, the elbow to the gripping point
	var a := up.origin
	var b := fore.origin
	var e := grip.origin
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(e)
	var to := target - a
	var d := clampf(to.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	if to.length_squared() < 0.000001:
		return
	var dir := to.normalized()
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var pole := (b - a) - dir * (b - a).dot(dir)
	if pole.length_squared() < 0.000001:
		pole = up.basis.z
	pole = pole.normalized()
	var b2 := a + dir * x + pole * h
	var q1 := _turn(b - a, b2 - a)
	var up2 := Transform3D(q1 * up.basis, a)
	var e_after := b2 + q1 * (e - b)
	var q2 := _turn(e_after - b2, a + dir * d - b2)
	var fore2 := Transform3D(q2 * q1 * fore.basis, b2)
	skel.set_bone_global_pose(_b[1], up2)
	skel.set_bone_global_pose(_b[2], fore2)
	# the hand as the clip had it, where the arm now puts it
	var wrist_at := b2 + q2 * q1 * (wrist.origin - b)
	skel.set_bone_global_pose(_b[3], Transform3D(wrist.basis, wrist_at))


## The turn that takes `from` onto `to`.
static func _turn(from: Vector3, to: Vector3) -> Basis:
	var f := from.normalized()
	var t := to.normalized()
	var c := f.cross(t)
	if c.length_squared() < 0.0000001:
		return Basis.IDENTITY
	return Basis(c.normalized(), f.signed_angle_to(t, c.normalized()))
