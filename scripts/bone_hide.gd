class_name BoneHide
extends SkeletonModifier3D
## One bone (and all under it) shrunk away, laid over whatever clip plays:
## the golem's fist while it is flying off its arm (2026-10-15); or swollen
## (above 1: its fists through its volley of air, 2026-10-26).

var bone_name: String = ""
## 1 shown as the clip has it, 0 gone, above 1 swollen.
var shown: float = 1.0


func _process_modification() -> void:
	if absf(shown - 1.0) < 0.001 or bone_name.is_empty():
		return
	var skel := get_skeleton()
	if skel == null:
		return
	var b := skel.find_bone(bone_name)
	if b < 0:
		return
	skel.set_bone_pose_scale(b, skel.get_bone_pose_scale(b) * maxf(shown, 0.001))
