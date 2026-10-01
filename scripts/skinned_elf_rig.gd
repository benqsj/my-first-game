class_name SkinnedElfRig
extends SkinnedArcherRig

## The elf: a second archer on the hero select, beside Avtandil. She shoots,
## rolls and climbs as he does — his rig, his clips, his bow — but is only ever
## worn on a figure of her own skeleton, which follows his ([FigureFollower]):
##
## * THE DARK ELF: blend-swap's animated dark elf (CC-BY), on its mocap
##   (CMU-named) skeleton, her own bow left out for his (vepxis-art
##   tools/bl_mixfig.py, VX_FIG=darkelf).
## * THE NIGHT ELF and THE NIGHT ELF, BARE: Anna Ipati by Jungle Jim
##   (Sketchfab, CC-BY), a realistic woman made a dark elf (slate skin, silver
##   hair, pointed ears) and lighter by vepxis-art tools/anna_prep.py, on her
##   own Character Creator skeleton (VX_FIG=anna). The bare look leaves off
##   the bra.


func _configure() -> void:
	super()
	faces = [&"darkelf", &"anna", &"anna_bare"]
	face_skulls = faces.duplicate()
	face_names = ["THE DARK ELF", "THE NIGHT ELF", "THE NIGHT ELF, BARE"]
	whole_faces = faces.duplicate()
	# Her outfits in the bag: the green she came in, the same dyed black-violet
	# and silver, and black leather straps on the bare skin (vepxis-art
	# tools/bl_mixfig.py, noir_garb and harness_garb).
	garbs = [&"de_body", &"de_noir", &"de_harness"]
	var bow_bones := {&"bow_l": &"bow_l", &"bow_limb_l": &"bow_limb_l", &"bow_tip_l": &"bow_tip_l",
			&"bow_limb_u": &"bow_limb_u", &"bow_tip_u": &"bow_tip_u", &"draw_r": &"draw_r"}
	# The mocap skeleton's limbs are named as Mixamo's are; its spine is
	# LowerBack, Spine, Spine1 (the lower back rides the hips).
	var elf_map := SkinnedRig.mixamo_map(bow_bones)
	elf_map.erase(&"Spine2")
	elf_map[&"Spine1"] = &"spine_02"
	# Character Creator's skeleton: the waist and the upper chest take his two
	# spine bones (the bone between rides); the twist bones ride their limbs.
	var anna_map := {&"CC_Base_Hip": &"pelvis", &"CC_Base_Waist": &"spine_01", &"CC_Base_Spine02": &"spine_02",
			&"CC_Base_NeckTwist01": &"neck_01", &"CC_Base_Head": &"head"}
	for s in [["L", "l"], ["R", "r"]]:
		var S: String = s[0]
		var lo: String = s[1]
		anna_map[StringName("CC_Base_%s_Clavicle" % S)] = StringName("clavicle_" + lo)
		anna_map[StringName("CC_Base_%s_Upperarm" % S)] = StringName("upperarm_" + lo)
		anna_map[StringName("CC_Base_%s_Forearm" % S)] = StringName("lowerarm_" + lo)
		anna_map[StringName("CC_Base_%s_Hand" % S)] = StringName("hand_" + lo)
		anna_map[StringName("CC_Base_%s_Thigh" % S)] = StringName("thigh_" + lo)
		anna_map[StringName("CC_Base_%s_Calf" % S)] = StringName("calf_" + lo)
		anna_map[StringName("CC_Base_%s_Foot" % S)] = StringName("foot_" + lo)
		anna_map[StringName("CC_Base_%s_ToeBase" % S)] = StringName("ball_" + lo)
	anna_map.merge(bow_bones)
	figures = {
		&"darkelf": {"scene": "res://assets/avtandil_darkelf/avtandil_darkelf.glb", "prefix": "de",
			"hips": &"Hips", "map": elf_map},
		&"anna": {"scene": "res://assets/avtandil_anna/avtandil_anna.glb", "prefix": "an",
			"hips": &"CC_Base_Hip", "map": anna_map},
	}
	figure_faces = {
		&"darkelf": {"figure": &"darkelf", "show": ["body", "noir", "harness"]},
		&"anna": {"figure": &"anna", "show": ["body", "hair", "bra", "thong"]},
		&"anna_bare": {"figure": &"anna", "show": ["body", "hair", "thong"]},
	}


## Avtandil's own heads (THE RANGER, THE HUNTER) and outfits are in the model she shares;
## none of them is one of her faces, so none is ever shown.
func set_face(index: int) -> void:
	super(index)
	set_garb(garb)
	# His outfits are not hers to wear (her garbs are her own two).
	for name: String in ["avtandil_ranger", "avtandil_wanderer"]:
		var mesh := find_child(name, true, false) as MeshInstance3D
		if mesh != null:
			mesh.visible = false
	for node in find_children(mesh_prefix + "_face_*", "MeshInstance3D", true, false):
		var key := StringName(String(node.name).trim_prefix(mesh_prefix + "_face_"))
		if not faces.has(key):
			(node as MeshInstance3D).visible = false


## Her outfits are whole bodies of the figure: the one put on is shown, the
## other hidden (the rig's own rule hides every garb under a whole figure).
func set_garb(index: int) -> void:
	super(index)
	for i in garbs.size():
		var mesh := find_child(String(garbs[i]), true, false) as MeshInstance3D
		if mesh != null:
			mesh.visible = i == garb
