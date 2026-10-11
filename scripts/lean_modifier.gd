class_name LeanModifier
extends SkeletonModifier3D
## A creature's body bent forward from the waist over whatever its clip does
## (the ogre's grab, the user's word 2026-10-11: "it needs to bend more"):
## `bend` degrees at full `amount`, about the creature's own left-right axis,
## split over `bones` (lowest first), so all above — the arms, what the hands
## hold — goes down and forward with it. Every peer runs it.

@export var bones: PackedStringArray = PackedStringArray(["waist_joint"])
@export var shares: PackedFloat32Array = PackedFloat32Array([1.0])
@export var bend: float = 24.0
## 0..1, set from the creature each frame.
var amount: float = 0.0
## The way the creature faces, in the world (set with `amount`).
var facing: Vector3 = Vector3.FORWARD

var _idx := PackedInt32Array()


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null or amount <= 0.001:
		return
	if _idx.is_empty():
		for n in bones:
			_idx.append(skel.find_bone(n))
	var f := Vector3(facing.x, 0.0, facing.z)
	if f.length_squared() < 0.0001:
		return
	# about the axis that tips the upper body forward, in skeleton space
	var axis := (skel.global_basis.inverse() * Vector3.UP.cross(f.normalized())).normalized()
	for k in _idx.size():
		var b := _idx[k]
		if b < 0:
			continue
		var share := shares[k] if k < shares.size() else 0.0
		var g := skel.get_bone_global_pose(b)
		var turn := Basis(axis, deg_to_rad(bend * share * amount))
		skel.set_bone_global_pose(b, Transform3D(turn * g.basis, g.origin))
