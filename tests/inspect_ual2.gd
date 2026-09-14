extends SceneTree

## Dumps how Godot imported the UAL2 animation library: node layout, bone rests
## in skeleton space, and the animation list. Used to verify the retarget
## assumptions against the real imported data rather than the raw glTF.
##   godot --headless --script res://tests/inspect_ual2.gd

const SOURCE := "res://assets/anim/ual2.glb"
const BONES := [
	"root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head",
	"clavicle_l", "upperarm_l", "lowerarm_l", "hand_l",
	"clavicle_r", "upperarm_r", "lowerarm_r", "hand_r",
	"thigh_l", "calf_l", "foot_l", "ball_l",
	"thigh_r", "calf_r", "foot_r", "ball_r",
]


func _initialize() -> void:
	var scene: Node3D = load(SOURCE).instantiate()
	root.add_child(scene)

	print("--- tree ---")
	_dump(scene, 0)

	var skel := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	print("\n--- skeleton: %s, %d bones ---" % [skel.name, skel.get_bone_count()])
	print("skeleton global transform: ", skel.global_transform)
	print("scene global transform: ", scene.global_transform)

	print("\n--- bone global rests (skeleton space) ---")
	for bone_name in BONES:
		var idx := skel.find_bone(bone_name)
		if idx < 0:
			print("%-12s MISSING" % bone_name)
			continue
		var t := skel.get_bone_global_rest(idx)
		print("%-12s parent=%-12s pos=%s\n             X=%s Y=%s Z=%s" % [
			bone_name,
			skel.get_bone_name(skel.get_bone_parent(idx)) if skel.get_bone_parent(idx) >= 0 else "-",
			_v(t.origin), _v(t.basis.x), _v(t.basis.y), _v(t.basis.z)])

	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	print("\n--- animations (%d) ---" % player.get_animation_list().size())
	for anim_name in player.get_animation_list():
		var anim := player.get_animation(anim_name)
		print("%-26s %5.2fs  loop=%s  tracks=%d" % [anim_name, anim.length, anim.loop_mode, anim.get_track_count()])

	var first := player.get_animation(player.get_animation_list()[1])
	print("\n--- sample track paths of '%s' ---" % player.get_animation_list()[1])
	for i in mini(6, first.get_track_count()):
		print("  ", first.track_get_path(i), "  type=", first.track_get_type(i))

	quit()


func _v(v: Vector3) -> String:
	return "(%+.3f,%+.3f,%+.3f)" % [v.x, v.y, v.z]


func _dump(n: Node, d: int) -> void:
	var extra := ""
	if n is MeshInstance3D:
		extra = " [mesh, skin=%s]" % ((n as MeshInstance3D).skin != null)
	print("%s%s (%s)%s" % ["  ".repeat(d), n.name, n.get_class(), extra])
	for c in n.get_children():
		_dump(c, d + 1)
