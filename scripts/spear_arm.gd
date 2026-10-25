class_name SpearArm
extends SkeletonModifier3D
## An arm put where a spear is held and cast (the troll's tree thrown, the
## user, 2026-10-25: no clip had a spear's cast; the one it had held the tree
## low by its hip and swung it over): over whatever its clip does, the hand
## is reached out along `reach` from the shoulder (two bones, its elbow
## turned toward `pole_hint`), the hand turned with the forearm. `weight`
## blends it in and out.

@export var upper_bone: String = "R_shoulder_joint"
@export var fore_bone: String = "R_elbow_joint"
@export var wrist_bone: String = "R_wrist_joint"
@export var grip_bone: String = "R_equip_joint"

## In the world: the way from the shoulder to the hand, its length the share
## of the arm's whole length reached.
var reach: Vector3 = Vector3.FORWARD * 0.8
## In the world: the way the elbow is turned.
var pole_hint: Vector3 = Vector3.DOWN
var weight: float = 0.0
## Or, `aim` on, the hand put on a point in the world (`aim_at`): its grip
## brought to just there (the troll's hands onto the trunk it tears up,
## 2026-10-26, the user: its hands missed the tree).
var aim: bool = false
var aim_at: Vector3 = Vector3.ZERO

var _b := PackedInt32Array()


func _process_modification() -> void:
	if weight <= 0.001:
		return
	var skel := get_skeleton()
	if skel == null:
		return
	if _b.is_empty():
		for n in [upper_bone, fore_bone, wrist_bone, grip_bone]:
			_b.append(skel.find_bone(n))
	for b in _b:
		if b < 0:
			return
	var up := skel.get_bone_global_pose(_b[0])
	var fore := skel.get_bone_global_pose(_b[1])
	var wrist := skel.get_bone_global_pose(_b[2])
	var grip := skel.get_bone_global_pose(_b[3])
	var inv := skel.global_transform.basis.inverse()
	var a := up.origin
	var b := fore.origin
	var e := grip.origin
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(e)
	var target: Vector3
	if aim:
		target = skel.global_transform.affine_inverse() * aim_at
	else:
		var want := inv * reach
		if want.length_squared() < 0.000001:
			return
		target = a + want.normalized() * reach.length() * (l1 + l2)
	target = e.lerp(target, clampf(weight, 0.0, 1.0))
	var to := target - a
	if to.length_squared() < 0.000001:
		return
	var d := clampf(to.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var dir := to.normalized()
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	# the elbow: from where the clip had it toward the hint
	var cur := (b - a) - dir * (b - a).dot(dir)
	var hint := inv * pole_hint
	hint = hint - dir * hint.dot(dir)
	var pole := Vector3.ZERO
	if cur.length_squared() > 0.000001:
		pole += cur.normalized() * (1.0 - weight)
	if hint.length_squared() > 0.000001:
		pole += hint.normalized() * weight
	if pole.length_squared() < 0.000001:
		pole = up.basis.z - dir * up.basis.z.dot(dir)
	pole = pole.normalized()
	var b2 := a + dir * x + pole * h
	var q1 := _turn(b - a, b2 - a)
	var e_after := b2 + q1 * (e - b)
	var q2 := _turn(e_after - b2, a + dir * d - b2)
	skel.set_bone_global_pose(_b[0], Transform3D(q1 * up.basis, a))
	skel.set_bone_global_pose(_b[1], Transform3D(q2 * q1 * fore.basis, b2))
	# the hand turned with the forearm, where the arm now puts it
	var wrist_at := b2 + q2 * q1 * (wrist.origin - b)
	skel.set_bone_global_pose(_b[2], Transform3D(q2 * q1 * wrist.basis, wrist_at))


## The turn that takes `from` onto `to`.
static func _turn(from: Vector3, to: Vector3) -> Basis:
	var f := from.normalized()
	var t := to.normalized()
	var c := f.cross(t)
	if c.length_squared() < 0.0000001:
		return Basis.IDENTITY
	return Basis(c.normalized(), f.signed_angle_to(t, c.normalized()))
