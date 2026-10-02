class_name RunLean
extends SkeletonModifier3D
## A lean forward from the hips while he runs (to try, F9; the user asked
## whether a run would read more natural bent a little at the waist): the
## lowest spine bone turned about the skeleton's side axis, the trunk above
## with it. `degrees` the lean, `weight` how much of it (the rig eases it in
## while the run plays).

@export var degrees := 0.0
var weight := 0.0

var _spine := -2


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null or degrees == 0.0 or weight <= 0.0:
		return
	if _spine == -2:
		_spine = skel.find_bone("spine_01")
	if _spine < 0:
		return
	var g := skel.get_bone_global_pose(_spine)
	var turn := Basis(Vector3.RIGHT, deg_to_rad(degrees) * weight)
	skel.set_bone_global_pose(_spine, Transform3D(turn * g.basis, g.origin))
