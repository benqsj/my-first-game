class_name RunLean
extends SkeletonModifier3D
## The assassin's run, leaning into it (ASSASSIN_BUFF, the user's word
## 2026-10-05): the back bent forward over the hips by `amount` radians, a
## share at each spine joint, and the head bent back up by part of it so he
## still looks where he is going. Laid over whatever run clip plays; the rig
## sets `amount` (eased) from his pace each frame.

const CHAIN: Array = [&"spine_01", &"spine_02", &"spine_03", &"neck_01", &"Head", &"head"]
const SHARES: Array = [0.4, 0.35, 0.25, -0.25, -0.2, -0.2]

## How far forward (radians), and which way is forward (world space).
var amount: float = 0.0
var forward: Vector3 = Vector3.FORWARD

var _bones: Array[int] = []
var _shares: Array[float] = []


func _bind() -> void:
	_bones.clear()
	_shares.clear()
	var skel := get_skeleton()
	if skel == null:
		return
	for i in CHAIN.size():
		var b := skel.find_bone(String(CHAIN[i]))
		if b >= 0:
			_bones.append(b)
			_shares.append(float(SHARES[i]))


func _process_modification() -> void:
	if absf(amount) < 0.002:
		return
	var skel := get_skeleton()
	if skel == null:
		return
	if _bones.is_empty():
		_bind()
	var fwd := Vector3(forward.x, 0.0, forward.z)
	if fwd.length_squared() < 0.0001:
		return
	fwd = fwd.normalized()
	# turning up towards ahead: about up x ahead
	var axis := Vector3.UP.cross(fwd).normalized()
	var frame := skel.global_basis.orthonormalized()
	var inverse := frame.inverse()
	for i in _bones.size():
		var bone := _bones[i]
		var turn := inverse * Basis(axis, amount * _shares[i]) * frame
		var parent := skel.get_bone_parent(bone)
		var above := Basis.IDENTITY
		if parent >= 0:
			above = skel.get_bone_global_pose(parent).basis.orthonormalized()
		var local := Quaternion((above.inverse() * turn * above).orthonormalized())
		skel.set_bone_pose_rotation(bone, (local * skel.get_bone_pose_rotation(bone)).normalized())
