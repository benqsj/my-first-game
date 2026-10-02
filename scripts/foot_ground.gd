class_name FootGround
extends SkeletonModifier3D
## The feet on the ground where it is, on the UE mannequin.
##
## Every clip is made on flat ground: on a slope the foot uphill of the body
## went into it (running across a 15-30 degree hillside the ankle went 0.1-0.2
## m under the ground, the boot half gone: the user saw it, 2026-10-02) and the
## one downhill hung over it. Each frame, while the body is on the floor, each
## foot is looked for under itself (a ray down at the ankle) and kept as high
## over the ground there as the clip holds it over flat ground; the hips come
## down by as much as the lower foot needs (eased), and each leg is bent to its
## foot by two-bone IK in the plane its knee already bends in. A foot near the
## ground is tilted to lie along it.

const LEGS: Array = [[&"thigh_l", &"calf_l", &"foot_l"], [&"thigh_r", &"calf_r", &"foot_r"]]
## How far the hips may come down, and a foot be lifted (m).
@export var max_drop := 0.3
@export var max_lift := 0.45
## A foot this close to its ground (over what it stands at on flat) is laid
## along the slope wholly; from `tilt_free` up not at all.
@export var tilt_near := 0.06
@export var tilt_free := 0.2
@export var max_tilt_deg := 32.0

var _body: CharacterBody3D
var _bones: Array = []
var _pelvis := -1
var _drop := 0.0


func _ready() -> void:
	var at: Node = self
	while at != null and not at is CharacterBody3D:
		at = at.get_parent()
	_body = at as CharacterBody3D


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null or _body == null:
		return
	if _bones.is_empty():
		for leg: Array in LEGS:
			_bones.append([skel.find_bone(leg[0]), skel.find_bone(leg[1]), skel.find_bone(leg[2])])
		_pelvis = skel.find_bone("pelvis")
	var dt := get_process_delta_time()
	if not _body.is_on_floor() or _pelvis < 0:
		_drop = move_toward(_drop, 0.0, dt * 2.0)
		if _drop != 0.0:
			_shift_pelvis(skel, _drop)
		return
	var to_world := skel.global_transform
	var from_world := to_world.affine_inverse()
	var floor_y := _body.global_position.y
	var space := skel.get_world_3d().direct_space_state
	# where each foot's ground is, and how much it is off from where the clip
	# would have it over flat ground
	var wants: Array = []
	var lowest := 0.0
	for leg: Array in _bones:
		if int(leg[0]) < 0 or int(leg[1]) < 0 or int(leg[2]) < 0:
			wants.append(null)
			continue
		var ankle := to_world * skel.get_bone_global_pose(leg[2]).origin
		var over := ankle.y - floor_y  # its height over flat ground, as the clip has it
		var ray := PhysicsRayQueryParameters3D.create(Vector3(ankle.x, floor_y + 0.9, ankle.z),
				Vector3(ankle.x, floor_y - 0.9, ankle.z), 1, [_body.get_rid()])
		var hit := space.intersect_ray(ray)
		if hit.is_empty():
			wants.append(null)
			continue
		var need := clampf((hit["position"] as Vector3).y + over - ankle.y, -max_drop, max_lift)
		wants.append({"need": need, "normal": hit["normal"], "over": over})
		lowest = minf(lowest, need)
	var drop_to := clampf(lowest, -max_drop, 0.0)
	_drop = lerpf(_drop, drop_to, 1.0 - exp(-14.0 * dt))
	_shift_pelvis(skel, _drop)
	for i in _bones.size():
		var want: Variant = wants[i]
		if want == null:
			continue
		var leg: Array = _bones[i]
		var lift := float(want["need"]) - _drop
		var foot_was := skel.get_bone_global_pose(leg[2])
		if absf(lift) > 0.002:
			_reach(skel, leg, foot_was.origin + from_world.basis * Vector3(0.0, lift, 0.0))
		# laid along the ground near it
		var w := 1.0 - smoothstep(tilt_near, tilt_free, float(want["over"]))
		var n := (from_world.basis * (want["normal"] as Vector3)).normalized()
		var up := (from_world.basis * Vector3.UP).normalized()
		var angle := minf(up.angle_to(n), deg_to_rad(max_tilt_deg)) * w
		var now := skel.get_bone_global_pose(leg[2])
		var basis := foot_was.basis
		if angle > 0.001:
			var axis := up.cross(n).normalized()
			basis = Basis(axis, angle) * basis
		skel.set_bone_global_pose(leg[2], Transform3D(basis, now.origin))


func _shift_pelvis(skel: Skeleton3D, by_world: float) -> void:
	var p := skel.get_bone_global_pose(_pelvis)
	var down := skel.global_transform.affine_inverse().basis * Vector3(0.0, by_world, 0.0)
	skel.set_bone_global_pose(_pelvis, Transform3D(p.basis, p.origin + down))


## Bends thigh and calf so the ankle comes to `target` (skeleton space), the
## knee kept in the plane it bends in now.
func _reach(skel: Skeleton3D, leg: Array, target: Vector3) -> void:
	var hip_t := skel.get_bone_global_pose(leg[0])
	var knee_t := skel.get_bone_global_pose(leg[1])
	var ankle_t := skel.get_bone_global_pose(leg[2])
	var hip := hip_t.origin
	var knee := knee_t.origin
	var ankle := ankle_t.origin
	var a := hip.distance_to(knee)
	var b := knee.distance_to(ankle)
	var to := target - hip
	var d := clampf(to.length(), absf(a - b) + 0.001, a + b - 0.001)
	var dir := to.normalized()
	# the bend's side: where the knee is off the hip-ankle line now
	var pole := knee - hip
	pole = pole - dir * pole.dot(dir)
	if pole.length() < 0.0001:
		pole = (hip_t.basis * Vector3(0, 0, 1)) - dir * (hip_t.basis * Vector3(0, 0, 1)).dot(dir)
	pole = pole.normalized()
	var along := (a * a - b * b + d * d) / (2.0 * d)
	var side := sqrt(maxf(a * a - along * along, 0.0))
	var knee_new := hip + dir * along + pole * side
	var ankle_new := hip + dir * d
	# the thigh turned from its old line to the new, the calf the same
	var r1 := Quaternion((knee - hip).normalized(), (knee_new - hip).normalized())
	skel.set_bone_global_pose(leg[0], Transform3D(Basis(r1) * hip_t.basis, hip))
	var knee_now := skel.get_bone_global_pose(leg[1])
	var ankle_now := skel.get_bone_global_pose(leg[2]).origin
	var r2 := Quaternion((ankle_now - knee_now.origin).normalized(), (ankle_new - knee_now.origin).normalized())
	skel.set_bone_global_pose(leg[1], Transform3D(Basis(r2) * knee_now.basis, knee_now.origin))
	# the foot keeps the turn it had in the world
	var foot_now := skel.get_bone_global_pose(leg[2])
	skel.set_bone_global_pose(leg[2], Transform3D(ankle_t.basis, foot_now.origin))
