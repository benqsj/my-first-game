extends SceneTree

## Compares the Quaternius animation library's skeleton against a monster kit's,
## bone by bone, to find out whether a clip can be copied straight across.
##
##     godot --path . --headless --script res://tools/inspect_skeletons.gd

const LIBRARY := "res://assets/anim/ual2.glb"
const MONSTERS := {
	"Imp": "res://assets/monsters/Bestiary - Dungeon Monsters Kit[Standard]/Exports/GLB (Godot-Unreal)/Imp.glb",
	"Puglin": "res://assets/monsters/Bestiary - Dungeon Monsters Kit[Standard]/Exports/GLB (Godot-Unreal)/Puglin.glb",
}


func _init() -> void:
	var lib := (load(LIBRARY) as PackedScene).instantiate()
	var lib_skel := lib.find_child("Skeleton3D", true, false) as Skeleton3D
	var lib_player := lib.find_child("AnimationPlayer", true, false) as AnimationPlayer
	print("library bones: ", lib_skel.get_bone_count())
	print("clips: ", lib_player.get_animation_list())
	var lib_names := _names(lib_skel)
	print("library bone names: ", lib_names)

	for id: String in MONSTERS:
		var scene := (load(MONSTERS[id]) as PackedScene).instantiate()
		var skel := scene.find_child("Skeleton3D", true, false) as Skeleton3D
		print("\n=== ", id, " bones=", skel.get_bone_count())
		var names := _names(skel)
		var missing := []
		for n in lib_names:
			if not names.has(n):
				missing.append(n)
		var extra := []
		for n in names:
			if not lib_names.has(n):
				extra.append(n)
		print("  in library but not here: ", missing)
		print("  here but not in library: ", extra)
		print("  skeleton xform in scene: ", skel.global_transform if skel.is_inside_tree() else skel.transform)
		# Rest pose comparison on a handful of joints, to see whether the two are
		# built to the same convention.
		for bone in ["pelvis", "spine_01", "upperarm_l", "thigh_l", "foot_l", "Head"]:
			var a := lib_skel.find_bone(bone)
			var b := skel.find_bone(bone)
			if a < 0 or b < 0:
				continue
			print("  %-12s lib_rest=%s   mon_rest=%s" % [bone,
					_short(lib_skel.get_bone_global_rest(a)), _short(skel.get_bone_global_rest(b))])
		scene.free()
	lib.free()
	quit()


func _names(skel: Skeleton3D) -> Array:
	var out := []
	for i in skel.get_bone_count():
		out.append(skel.get_bone_name(i))
	return out


func _short(t: Transform3D) -> String:
	var e := t.basis.get_euler() * 180.0 / PI
	return "pos(%.3f,%.3f,%.3f) rot(%.0f,%.0f,%.0f)" % [t.origin.x, t.origin.y, t.origin.z, e.x, e.y, e.z]
