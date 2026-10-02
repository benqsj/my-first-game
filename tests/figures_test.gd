extends SceneTree
## Every look worn on a figure of its own (see [FigureFollower]) on every hero:
## the figure shown and the rig's own meshes not, the look's mesh and its arms
## shown, the figure's hands where the rig's are give or take its build, the
## blade's cut off the figure's hands, the bow's string on the figure's bow;
## and the rig's own look again with every figure put away.

const HEROES := {
	"Tariel": "res://scenes/player/tariel_rigged_visuals.tscn",
	"the assassin": "res://scenes/player/rogue_rigged_visuals.tscn",
	"Avtandil": "res://scenes/player/avtandil_rigged_visuals.tscn",
	"the mage": "res://scenes/player/mage_rigged_visuals.tscn",
	"the warrior": "res://scenes/player/warrior_rigged_visuals.tscn",
}
const CLIP_AT := 0.45

var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _hand(skel: Skeleton3D, bone: String) -> Vector3:
	return skel.global_transform * skel.get_bone_global_pose(skel.find_bone(bone)).origin


func _run() -> void:
	for hero: String in HEROES:
		var body := Node3D.new()
		root.add_child(body)
		var rig := (load(HEROES[hero]) as PackedScene).instantiate() as SkinnedRig
		body.add_child(rig)
		for i in 4:
			await process_frame
		var anim: AnimationPlayer = rig._anim
		var clip := String(anim.get_animation_list()[0])
		for key: StringName in rig.figure_faces:
			rig.set_face(rig.faces.find(key))
			anim.play(clip)
			anim.seek(anim.get_animation(clip).length * CLIP_AT, true)
			for i in 3:
				await process_frame
			var fig := rig._figure
			var skel := rig._figure_skel
			var spec: Dictionary = rig.figures[rig.figure_faces[key]["figure"]]
			var prefix := String(spec["prefix"]) + "_"
			var rig_shown: Array[String] = []
			for mesh: MeshInstance3D in rig.find_children(rig.mesh_prefix + "_*", "MeshInstance3D", true, false):
				if mesh.is_visible_in_tree() and not fig.is_ancestor_of(mesh):
					rig_shown.append(String(mesh.name))
			var look_shown := 0
			var arms_shown := 0
			for mesh: MeshInstance3D in fig.find_children(prefix + "*", "MeshInstance3D", true, false):
				if not mesh.is_visible_in_tree():
					continue
				var part := String(mesh.name).trim_prefix(prefix)
				# (the maker's, YOUR OWN: "w_<id>" in the sword hand, "o_<id>" the other)
				if part.begins_with("arm_") or part.begins_with("w_") or part.begins_with("o_") \
						or part in ["sword", "shield", "tower_shield"]:
					arms_shown += 1
				else:
					look_shown += 1
			# The figure's hand bone by the rig's: the map says which it follows.
			var map: Dictionary = spec["map"]
			var fig_hand := ""
			for b: StringName in map:
				if map[b] == &"hand_r":
					fig_hand = String(b)
			var off := _hand(skel, fig_hand).distance_to(_hand(rig._skel, "hand_r"))
			_check("%s as %s: the figure worn, his own meshes put away" % [hero, key],
					fig != null and fig.visible and rig_shown.is_empty() and look_shown >= 1 and arms_shown >= 1,
					"%d of the look, %d arms, his shown: %s" % [look_shown, arms_shown, rig_shown])
			_check("%s as %s: the figure's hand by his" % [hero, key], off < 0.4, "%.2f m off" % off)
			if rig._blade_tip != null:
				_check("%s as %s: the cut off the figure's hand" % [hero, key],
						rig._blade_tip.get_parent() == rig._figure_mount, str(rig._blade_tip.get_parent().name))
			if rig._blade_tip_l != null:
				_check("%s as %s: the off hand's cut off the figure's off hand" % [hero, key],
						rig._blade_tip_l.get_parent() == rig._figs[rig.figure_faces[key]["figure"]]["mount_l"],
						str(rig._blade_tip_l.get_parent().name))
			if rig.face_moves.has(key):
				var moves: Dictionary = rig.face_moves[key]
				var missing: Array[String] = []
				for c: StringName in rig.flurry:
					if not anim.has_animation(c):
						missing.append(String(c))
				for h: Dictionary in rig.heavy:
					if not anim.has_animation(h["clip"]):
						missing.append(String(h["clip"]))
				var hidden_shown := 0
				for a: String in moves.get("hide_arms", []):
					var m := fig.find_child(prefix + a, true, false) as MeshInstance3D
					hidden_shown += 1 if m != null and m.visible else 0
				_check("%s as %s: fights his own way, with what he holds" % [hero, key],
						str(rig.flurry) == str(moves["flurry"]) and missing.is_empty() and hidden_shown == 0
						and rig._off_hand_on == bool(moves.get("off_hand", true)),
						"flurry %s, missing %s, %d hidden arms shown" % [rig.flurry, missing, hidden_shown])
			if rig is SkinnedArcherRig:
				var bow: BowModifier = (rig as SkinnedArcherRig)._bow_mod
				var tip := _hand(skel, "bow_tip_u")
				if rig.on_mannequin():
					# the pack's bow on the mannequin's figure: its tip off its mesh
					var archer := rig as SkinnedArcherRig
					tip = (skel.global_transform * skel.get_bone_global_pose(skel.find_bone("weapon_l"))) \
							* (archer._bow_ends[0] if not archer._bow_ends.is_empty() else Vector3.ZERO)
				var d := bow.string_u.global_position.distance_to(tip)
				_check("%s as %s: the string on the figure's bow" % [hero, key], d < 0.03, "%.3f m off its tip" % d)
		# A hero only ever worn on figures (the elf) has no look of his own to go back to.
		var own := -1
		for f in rig.faces.size():
			if not rig.figure_faces.has(rig.faces[f]):
				own = f
				break
		if own < 0:
			body.queue_free()
			await process_frame
			continue
		rig.set_face(own)
		await process_frame
		var shown := 0
		for id: StringName in rig._figs:
			shown += 1 if (rig._figs[id]["node"] as Node3D).visible else 0
		_check("%s in his own look again: every figure put away" % hero, shown == 0 and rig._figure == null,
				"%d shown" % shown)
		_check("%s in his own look: fights as he did" % hero, str(rig.flurry) == str(rig._own_moves["flurry"])
				and rig._off_hand_on, str(rig.flurry))
		if rig is SkinnedArcherRig:
			var bow: BowModifier = (rig as SkinnedArcherRig)._bow_mod
			for i in 2:
				await process_frame
			var d := bow.string_u.global_position.distance_to(_hand(rig._skel, "bow_tip_u"))
			_check("%s in his own look: the string on his own bow" % hero, d < 0.03, "%.3f m" % d)
		body.queue_free()
		await process_frame
	print("figures_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)
