class_name SkinnedElfRig
extends SkinnedArcherRig

## The elf: a second archer on the hero select, beside Avtandil. She shoots,
## rolls and climbs as he does — his rig, his clips, his bow — but is only ever
## worn on a figure of her own skeleton, which follows his ([FigureFollower]):
##
## * THE DARK ELF: blend-swap's animated dark elf (CC-BY), on its mocap
##   (CMU-named) skeleton, her own bow left out for his (vepxis-art
##   tools/bl_mixfig.py, VX_FIG=darkelf).


func _configure() -> void:
	super()
	faces = [&"darkelf"]
	face_skulls = faces.duplicate()
	face_names = ["THE DARK ELF"]
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
	figures = {
		&"darkelf": {"scene": "res://assets/avtandil_darkelf/avtandil_darkelf.glb", "prefix": "de",
			"hips": &"Hips", "map": elf_map},
	}
	figure_faces = {
		&"darkelf": {"figure": &"darkelf", "show": ["body", "noir", "harness"]},
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
