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
		&"darkelf": {"figure": &"darkelf", "show": ["body"]},
	}


## Avtandil's own heads (THE RANGER, THE HUNTER) are in the model she shares;
## none of them is one of her faces, so none is ever shown.
func set_face(index: int) -> void:
	super(index)
	for node in find_children(mesh_prefix + "_face_*", "MeshInstance3D", true, false):
		var key := StringName(String(node.name).trim_prefix(mesh_prefix + "_face_"))
		if not faces.has(key):
			(node as MeshInstance3D).visible = false
