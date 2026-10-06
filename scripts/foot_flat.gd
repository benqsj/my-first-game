class_name FootFlat
extends SkeletonModifier3D
## Feet flat on the ground, on the UE mannequin.
##
## The hero's own Mixamo clips carried onto the mannequin (vepxis-art
## tools/h2m.gd) bend the feet where the knees bend deep: crouched, the feet
## pointed down and the toes curled under, the boots folded over (the user saw
## it, 2026-10-02). Near the ground this brings each sole level by the least
## turn that does it (so it keeps which way it points), and lays the toes
## flat; off the ground (a step, a jump) it lets the clip's foot be.
## Only while `active` (the rig sets it while one of those clips plays).
##
## Only a foot under a standing shin, though: in a roll or a dive the ankle
## stays near the ground while the shin lies along it or goes over the body,
## and turning that foot back to how it stands wrung it round on the leg (the
## user saw it, 2026-10-07: every roll but the rogue's flip). So the shin's
## lean fades it out (`shin_upright`..`shin_lying`), and so does a foot whose
## toes point up more than along the ground (its way along the ground too
## short to read). And whatever is left may tip the foot but not turn it
## round the shin by more than `max_twist_deg`. Measured over every clip of
## the five heroes' libraries (2026-10-07): the old way turned a foot out of
## the knee's plane by up to 56 degrees in 122 clips (walks, crouches, casts,
## rolls), this way by 23 at most.

const FEET: Array = [[&"foot_l", &"ball_l", &"calf_l"], [&"foot_r", &"ball_r", &"calf_r"]]
## The ankle's height (skeleton space, m) up to which the foot is laid flat
## wholly, and from which it is left as the clip has it.
@export var flat_below := 0.16
@export var free_above := 0.32
## How upright the shin (ankle to knee, the y of its direction) must be for
## the foot to be laid flat wholly, and below which it is left alone.
@export var shin_upright := 0.6
@export var shin_lying := 0.3
## How far (degrees) the foot may be turned about the shin from where the clip
## has it: laying it flat may tip it, never wring it round the leg.
@export var max_twist_deg := 8.0
## Laid flat by the shortest turn that brings the sole level (true), or
## turned back to the rest pose pointed along the ground (false, as before).
@export var level_by_arc := true

var _bones: Array = []


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	if _bones.is_empty():
		for pair: Array in FEET:
			_bones.append([skel.find_bone(pair[0]), skel.find_bone(pair[1]), skel.find_bone(pair[2])])
	for pair: Array in _bones:
		var f: int = pair[0]
		var b: int = pair[1]
		var k: int = pair[2]
		if f < 0 or b < 0 or k < 0:
			continue
		var pose := skel.get_bone_global_pose(f)
		var w := 1.0 - smoothstep(flat_below, free_above, pose.origin.y)
		if w <= 0.0:
			continue
		var shin := skel.get_bone_global_pose(k).origin - pose.origin
		if shin.length() < 0.001:
			continue
		w *= smoothstep(shin_lying, shin_upright, shin.normalized().y)
		if w <= 0.0:
			continue
		var rest := skel.get_bone_global_rest(f)
		var ball_rest := skel.get_bone_global_rest(b).origin - rest.origin
		var ball_now := skel.get_bone_global_pose(b).origin - pose.origin
		var ball_len := ball_now.length()
		var toes_up := ball_now.y > 0.0
		ball_rest.y = 0.0
		ball_now.y = 0.0
		if ball_rest.length() < 0.001 or ball_now.length() < 0.001:
			continue
		# toes pointing up (a roll's feet coming over): which way the foot
		# points along the ground is noise. Pointing down is the crouch this
		# is for, and is laid flat.
		if toes_up:
			w *= smoothstep(0.35, 0.6, ball_now.length() / maxf(ball_len, 0.001))
			if w <= 0.0:
				continue
		var now_q := pose.basis.orthonormalized().get_rotation_quaternion()
		var flat_q: Quaternion
		if level_by_arc:
			# the sole's up, as it is at rest, brought level by the least turn
			var sole_up := (pose.basis.orthonormalized() * (rest.basis.orthonormalized().inverse() * Vector3.UP)).normalized()
			flat_q = Quaternion(sole_up, Vector3.UP) * now_q
		else:
			# the rest foot turned about the vertical to point where this one does
			var yaw := ball_rest.normalized().signed_angle_to(ball_now.normalized(), Vector3.UP)
			flat_q = (Basis(Vector3.UP, yaw) * rest.basis.orthonormalized()).get_rotation_quaternion()
		var want := now_q.slerp(flat_q, w)
		want = _untwisted(want, now_q, shin.normalized())
		skel.set_bone_global_pose(f, Transform3D(Basis(want).scaled(pose.basis.get_scale()), pose.origin))
		skel.set_bone_pose_rotation(b, skel.get_bone_pose_rotation(b).slerp(skel.get_bone_rest(b).basis.get_rotation_quaternion(), w))


## `want` with its turn from `now` about `axis` (the shin) held to
## `max_twist_deg`: the turn split into a twist about the axis and a swing.
func _untwisted(want: Quaternion, now: Quaternion, axis: Vector3) -> Quaternion:
	var turn := (want * now.inverse()).normalized()
	var v := Vector3(turn.x, turn.y, turn.z)
	var along := axis * v.dot(axis)
	var twist := Quaternion(along.x, along.y, along.z, turn.w)
	if twist.length_squared() < 1e-9:
		return want
	twist = twist.normalized()
	var swing := turn * twist.inverse()
	var angle := twist.get_angle()
	if angle > PI:
		angle -= TAU
	var limit := deg_to_rad(max_twist_deg)
	if absf(angle) <= limit:
		return want
	var held := Quaternion(twist.get_axis(), clampf(angle, -limit, limit))
	return (swing * held * now).normalized()
