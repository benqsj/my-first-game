extends SceneTree
## The hero select's maker (YOUR OWN, [PolysplitLook]) on every hero, in both
## genders and every class the pack has for it: the figure of the look's gender
## worn and the hero's own meshes put away; every part the look names has a
## mesh in the figure and is shown, and nothing else of the look's kinds is;
## the hat's hair; the figure's hands by the rig's; the arm in hand, the cut
## off it and as long as it; the colours; and the hero's own look again after.
##   Godot --headless --path . --script res://tests/maker_test.gd

const HEROES := {
	&"tariel": "res://scenes/player/tariel_rigged_visuals.tscn",
	&"warrior": "res://scenes/player/warrior_rigged_visuals.tscn",
	&"rogue": "res://scenes/player/rogue_rigged_visuals.tscn",
	&"avtandil": "res://scenes/player/avtandil_rigged_visuals.tscn",
	&"mage": "res://scenes/player/mage_rigged_visuals.tscn",
}
const CLIP_AT := 0.45

var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _at(skel: Skeleton3D, bone: String) -> Vector3:
	return skel.global_transform * skel.get_bone_global_pose(skel.find_bone(bone)).origin


## The figure's meshes shown, by name without the prefix.
func _shown(fig: Node3D) -> Array[String]:
	var out: Array[String] = []
	for mesh: MeshInstance3D in fig.find_children("ps_*", "MeshInstance3D", true, false):
		if mesh.visible:
			out.append(String(mesh.name).trim_prefix("ps_"))
	return out


func _run() -> void:
	for hero: StringName in HEROES:
		var body := Node3D.new()
		root.add_child(body)
		var rig := (load(HEROES[hero]) as PackedScene).instantiate() as SkinnedRig
		body.add_child(rig)
		for i in 4:
			await process_frame
		var custom := rig.faces.find(SkinnedRig.CUSTOM)
		_check("%s: the maker's face, last" % hero, custom == rig.faces.size() - 1 and custom > 0,
				str(rig.faces))
		if custom < 0:
			body.queue_free()
			continue
		_check("%s: no maker's figure loaded before it is worn" % hero,
				not rig._figs.has(&"psm") and not rig._figs.has(&"psf"), str(rig._figs.keys()))
		var anim: AnimationPlayer = rig._anim
		var clip := String(rig.clips[&"idle"])
		for g: String in ["m", "f"]:
			for cls: String in PolysplitLook.classes(hero, g):
				var look := PolysplitLook.dress(PolysplitLook.default_look(hero, g), hero, cls)
				rig.set_look(look)
				rig.set_face(custom)
				anim.play(clip)
				anim.seek(anim.get_animation(clip).length * CLIP_AT, true)
				for i in 2:
					await process_frame
				var tag := "%s %s %s" % [hero, g, cls]
				var fig := rig._figure
				var want_fig := &"psf" if g == "f" else &"psm"
				_check("%s: the figure of the look's gender worn" % tag,
						fig != null and fig.visible and rig._figs.has(want_fig) and fig == rig._figs[want_fig]["node"])
				if fig == null:
					continue
				# The rig's own meshes, all put away.
				var own: Array[String] = []
				for mesh: MeshInstance3D in rig._skel.find_children("*", "MeshInstance3D", true, false):
					if mesh.is_visible_in_tree():
						own.append(String(mesh.name))
				_check("%s: his own meshes put away" % tag, own.is_empty(), str(own))
				# Every part the look names is a mesh, shown; nothing else.
				var worn := rig.get_look()
				var on := PolysplitLook.shown(worn)
				var shown := _shown(fig)
				var missing: Array[String] = []
				for key: String in on:
					if key.ends_with("_"):
						continue
					if not shown.has(key):
						missing.append(key)
				var extra: Array[String] = []
				for key in shown:
					if on.has(key) or key in ["shield", "tower_shield"]:
						continue
					var by_prefix := false
					for pre: String in on:
						by_prefix = by_prefix or (pre.ends_with("_") and key.begins_with(pre))
					if not by_prefix:
						extra.append(key)
				_check("%s: the look's parts shown, and only they" % tag, missing.is_empty() and extra.is_empty(),
						"missing %s, besides %s" % [missing, extra])
				# The hat's hair: under a hat with a "b" cut, that and not the whole.
				var hat: Dictionary = PolysplitLook.HATS.get(String(worn["hat"]), {})
				var hair := int(worn["hair"])
				if hat.get("hair", "full") == "b" and hair > 0:
					_check("%s: the hair cut for the hat" % tag,
							shown.has("hairb_%d" % hair) and not shown.has("hair_%d" % hair), str(shown))
				# Hands.
				var off := _at(rig._figure_skel, "R_wrist_joint").distance_to(_at(rig._skel, "hand_r"))
				_check("%s: the figure's hand by his" % tag, off < 0.35, "%.2f m off" % off)
				# The arm in hand, and the cut off it.
				var w := String(worn["w"])
				var arm_key := "arm_bow" if w == "own_bow" else "w_" + w
				_check("%s: %s in hand" % [tag, w], shown.has(arm_key), str(shown))
				if PolysplitLook.BLADES.has(w):
					var mesh := fig.find_child("ps_w_" + w, true, false) as MeshInstance3D
					var reach := rig._reach(mesh, &"weapon_r", rig._blade_at[1].normalized())
					var tip := rig._blade_tip.position.length()
					_check("%s: the cut off the figure's hand, as long as the %s" % [tag, w],
							rig._blade_tip.get_parent() == rig._figure_mount and reach > 0.15
							and absf(tip - reach * 0.96) < 0.01,
							"%s, tip %.2f, reach %.2f" % [rig._blade_tip.get_parent().name, tip, reach])
					# and the blade's tip where the mesh's far end is, in the world
					var far := rig._blade_tip.global_position.distance_to(
							rig._blade_base.global_position)
					_check("%s: the cut along the blade" % tag, far > 0.1, "%.2f m" % far)
				var o := String(worn["o"])
				if o == "his_shield":
					_check("%s: his own shield on" % tag,
							shown.has("shield") != shown.has("tower_shield"), str(shown))
				elif o != "none":
					_check("%s: %s in the other hand" % [tag, o], shown.has("o_" + o), str(shown))
				_check("%s: the off hand's ring only for a blade in it" % tag,
						rig._off_hand_on == PolysplitLook.BLADES.has(o), "%s %s" % [o, rig._off_hand_on])
		# The colours: the figure's own materials, dyed.
		var look := rig.get_look()
		look["skin"] = 5
		look["cloth"] = 9
		rig.set_look(look)
		var dyed := 0
		var mats: Dictionary = rig._figure.get_meta(&"ps_mats", {})
		for m: BaseMaterial3D in mats.values():
			var path := m.albedo_texture.resource_path if m.albedo_texture != null else ""
			if path.ends_with("body_5.png") or path.ends_with("objects_9.png"):
				dyed += 1
		_check("%s: dyed (skin 5, cloth 9)" % hero, dyed == mats.size() and dyed >= 2, "%d of %d" % [dyed, mats.size()])
		# His own body and clothes only: another class's top, legs or cape
		# give way to his class's (hats and arms are free).
		var g_now := String(rig.get_look()["g"])
		var mine := PolysplitLook.classes(hero, g_now)
		var other := ""
		for c: String in PolysplitLook.CLASSES[g_now]:
			if not mine.has(c):
				other = c
				break
		var foreign := rig.get_look()
		foreign["cls"] = other
		foreign["top"] = other
		foreign["bottom"] = other
		foreign["extras"] = (PolysplitLook.CLASSES[g_now][other]["extras"] as Array).duplicate()
		var mended := PolysplitLook.normalized(foreign, hero)
		_check("%s: no %s's clothes on him" % [hero, other], mine.has(String(mended["cls"]))
				and mine.has(String(mended["top"])) and mine.has(String(mended["bottom"]))
				and (mended["extras"] as Array).all(func(x: Variant) -> bool:
					return PolysplitLook.extras(hero, g_now).has(String(x))), str(mended))
		# A look given whole on the wire comes back the same.
		var back := PolysplitLook.from_wire(PolysplitLook.to_wire(rig.get_look()))
		_check("%s: the look over the wire" % hero,
				PolysplitLook.to_wire(PolysplitLook.normalized(back, hero)) == PolysplitLook.to_wire(rig.get_look()))
		# His own look again (the first; for one only ever worn on a figure of
		# his own, the assassin's FOX MASK, that figure and not the maker's).
		rig.set_face(0)
		await process_frame
		var figs := 0
		for id: StringName in [&"psm", &"psf"]:
			figs += 1 if rig._figs.has(id) and (rig._figs[id]["node"] as Node3D).visible else 0
		var own_shown := 0
		for mesh: MeshInstance3D in rig._skel.find_children("*", "MeshInstance3D", true, false):
			own_shown += 1 if mesh.is_visible_in_tree() else 0
		var on_figure := rig.wearing_figure()
		_check("%s: his own look again, the maker's figures put away" % hero, figs == 0
				and (on_figure or (own_shown > 0 and rig._figure == null)),
				"%d figures, %d of his meshes" % [figs, own_shown])
		if not rig._blade_at.is_empty():
			_check("%s: his own cut again" % hero, rig._blade_tip.position.is_equal_approx(rig._blade_at[1]))
		body.queue_free()
		await process_frame
	print("maker_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)
