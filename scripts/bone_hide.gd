class_name BoneHide
extends SkeletonModifier3D
## One bone (and all under it) shrunk away, laid over whatever clip plays:
## the golem's fist while it is flying off its arm (2026-10-15).

var bone_name: String = ""
## 1 shown as the clip has it, 0 gone.
var shown: float = 1.0


func _process_modification() -> void:
	if shown >= 0.999 or bone_name.is_empty():
		return
	var skel := get_skeleton()
	if skel == null:
		return
	var b := skel.find_bone(bone_name)
	if b < 0:
		return
	skel.set_bone_pose_scale(b, skel.get_bone_pose_scale(b) * maxf(shown, 0.001))
