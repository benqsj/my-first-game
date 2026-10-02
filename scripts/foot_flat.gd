class_name FootFlat
extends SkeletonModifier3D
## Feet flat on the ground, on the UE mannequin.
##
## The hero's own Mixamo clips carried onto the mannequin (vepxis-art
## tools/h2m.gd) bend the feet where the knees bend deep: crouched, the feet
## pointed down and the toes curled under, the boots folded over (the user saw
## it, 2026-10-02). Near the ground this turns each foot back to how it stands
## at rest, keeping only which way it points along the ground, and lays the
## toes flat; off the ground (a step, a jump) it lets the clip's foot be.
## Only while `active` (the rig sets it while one of those clips plays).

const FEET: Array = [[&"foot_l", &"ball_l"], [&"foot_r", &"ball_r"]]
## The ankle's height (skeleton space, m) up to which the foot is laid flat
## wholly, and from which it is left as the clip has it.
@export var flat_below := 0.16
@export var free_above := 0.32

var _bones: Array = []


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	if _bones.is_empty():
		for pair: Array in FEET:
			_bones.append([skel.find_bone(pair[0]), skel.find_bone(pair[1])])
	for pair: Array in _bones:
		var f: int = pair[0]
		var b: int = pair[1]
		if f < 0 or b < 0:
			continue
		var pose := skel.get_bone_global_pose(f)
		var w := 1.0 - smoothstep(flat_below, free_above, pose.origin.y)
		if w <= 0.0:
			continue
		var rest := skel.get_bone_global_rest(f)
		var ball_rest := skel.get_bone_global_rest(b).origin - rest.origin
		var ball_now := skel.get_bone_global_pose(b).origin - pose.origin
		ball_rest.y = 0.0
		ball_now.y = 0.0
		if ball_rest.length() < 0.001 or ball_now.length() < 0.001:
			continue
		# the rest foot turned about the vertical to point where this one does
		var yaw := ball_rest.normalized().signed_angle_to(ball_now.normalized(), Vector3.UP)
		var flat := Basis(Vector3.UP, yaw) * rest.basis.orthonormalized()
		var now_q := pose.basis.orthonormalized().get_rotation_quaternion()
		var want := now_q.slerp(flat.get_rotation_quaternion(), w)
		skel.set_bone_global_pose(f, Transform3D(Basis(want).scaled(pose.basis.get_scale()), pose.origin))
		skel.set_bone_pose_rotation(b, skel.get_bone_pose_rotation(b).slerp(skel.get_bone_rest(b).basis.get_rotation_quaternion(), w))
