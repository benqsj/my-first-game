class_name BulkModifier
extends SkeletonModifier3D
## A creature broadened at the shoulders over whatever its clip does (the
## orc's, the user's word 2026-10-14: its shoulders too narrow, broader
## without its body or its poses going wrong): its chest widened across
## (`chest_width`, the chest bone scaled along its own sideways axis, so what
## is skinned to the chest spreads) and each collarbone set out sideways by
## `shoulder_out` (in the skeleton's units), the arms with it; their globals
## are put back as they were but for that, so nothing else is scaled or
## turned. Every peer runs it.

@export var chest_bone: String = "chest_joint"
@export var clavicles: PackedStringArray = PackedStringArray(["L_clavicle_joint", "R_clavicle_joint"])
## The other children of the chest, kept where they were (the neck).
@export var keep: PackedStringArray = PackedStringArray(["neck_joint"])
@export var chest_width: float = 1.18
@export var shoulder_out: float = 0.06

var _chest := -1
var _clav := PackedInt32Array()
var _keep := PackedInt32Array()


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	if _chest < 0:
		_chest = skel.find_bone(chest_bone)
		for n in clavicles:
			_clav.append(skel.find_bone(n))
		for n in keep:
			_keep.append(skel.find_bone(n))
	if _chest < 0:
		return
	var chest := skel.get_bone_global_pose(_chest)
	# the children as they were, before the chest changes
	var clav_was: Array[Transform3D] = []
	for b in _clav:
		clav_was.append(skel.get_bone_global_pose(b) if b >= 0 else Transform3D.IDENTITY)
	var keep_was: Array[Transform3D] = []
	for b in _keep:
		keep_was.append(skel.get_bone_global_pose(b) if b >= 0 else Transform3D.IDENTITY)
	# wider across: the chest's own sideways axis is the one from one
	# collarbone to the other
	var across := Vector3.RIGHT
	if _clav.size() == 2 and _clav[0] >= 0 and _clav[1] >= 0:
		across = (clav_was[0].origin - clav_was[1].origin).normalized()
	var local_across := (chest.basis.inverse() * across).normalized()
	var stretch := Basis.IDENTITY.scaled(Vector3.ONE) 
	# scale along `local_across` only: I + (k - 1) a aᵀ
	var k := chest_width - 1.0
	var a := local_across
	stretch = Basis(Vector3(1.0 + k * a.x * a.x, k * a.x * a.y, k * a.x * a.z),
			Vector3(k * a.y * a.x, 1.0 + k * a.y * a.y, k * a.y * a.z),
			Vector3(k * a.z * a.x, k * a.z * a.y, 1.0 + k * a.z * a.z))
	skel.set_bone_global_pose(_chest, Transform3D(chest.basis * stretch, chest.origin))
	for i in _clav.size():
		var b := _clav[i]
		if b < 0:
			continue
		var was: Transform3D = clav_was[i]
		var out := (was.origin - chest.origin)
		out = out - out.project(chest.basis.y.normalized())
		var side := out.normalized() if out.length_squared() > 0.000001 else across
		skel.set_bone_global_pose(b, Transform3D(was.basis, was.origin + side * shoulder_out))
	for i in _keep.size():
		if _keep[i] >= 0:
			skel.set_bone_global_pose(_keep[i], keep_was[i])
