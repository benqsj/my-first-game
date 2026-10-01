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
	faces = [&"darkelf", &"anna", &"anna_bare", &"anna_harness", &"anna_corset", &"anna_garter",
			&"anna_gold", &"anna_catsuit", &"anna_huntress"]
	face_skulls = faces.duplicate()
	face_names = ["THE DARK ELF", "THE NIGHT ELF", "THE NIGHT ELF, BARE", "THE NIGHT ELF: HARNESS",
			"THE NIGHT ELF: CORSET", "THE NIGHT ELF: SILK", "THE NIGHT ELF: GOLD",
			"THE NIGHT ELF: CATSUIT", "THE NIGHT ELF: HUNTRESS"]
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
		# She stands taller than his hunter's crouch (the hips and spine turn
		# only part of the way his do), and her middle spine bone shares the
		# bend between his two, so her waist bends rather than creases.
		&"anna": {"scene": "res://assets/avtandil_anna/avtandil_anna.glb", "prefix": "an",
			"hips": &"CC_Base_Hip", "map": anna_map,
			"damp": {&"CC_Base_Hip": 0.55, &"CC_Base_Waist": 0.5, &"CC_Base_Spine01": 0.5, &"CC_Base_Spine02": 0.5},
			"mids": {&"CC_Base_Spine01": [&"spine_01", &"spine_02", 0.5]}},
	}
	figure_faces = {
		&"darkelf": {"figure": &"darkelf", "show": ["body", "noir", "harness"]},
		&"anna": {"figure": &"anna", "show": ["body", "hair", "bra", "thong"]},
		&"anna_bare": {"figure": &"anna", "show": ["body", "hair", "thong"]},
		# Her outfits, each cut out of her own skin (vepxis-art anna_prep.py):
		# leather straps and thigh boots; a corset with silver lacing; silk
		# cups, garters and stockings.
		&"anna_harness": {"figure": &"anna", "show": ["body", "hair", "thong", "fit_harness"]},
		&"anna_corset": {"figure": &"anna", "show": ["body", "hair", "thong", "fit_corset"]},
		&"anna_garter": {"figure": &"anna", "show": ["body", "hair", "thong", "fit_garter"]},
		# Gold armour over the thong; a catsuit cut open at the front, back
		# and hips; a leather tube top, hot pants and knee boots.
		&"anna_gold": {"figure": &"anna", "show": ["body", "hair", "thong", "fit_gold"]},
		&"anna_catsuit": {"figure": &"anna", "show": ["body", "hair", "fit_catsuit"]},
		&"anna_huntress": {"figure": &"anna", "show": ["body", "hair", "thong", "fit_huntress"]},
	}


## The colour her outfit is dyed (an index into `TINTS`), picked on the hero
## select beside the look. Only THE NIGHT ELF's clothes take it: the leather
## and the silk (her bra and thong too), and the gold armour, which keeps its
## shine (white makes it silver); never the silver trim or her skin.
var tint: int = 0
## What each colour is called, for the picker; empty while she wears a look
## with no clothes of hers to dye, so the picker fades out.
var tint_names: Array:
	get:
		return TINT_NAMES if _dyeable() else []
const TINT_NAMES := ["BLACK", "CRIMSON", "VIOLET", "EMERALD", "MIDNIGHT", "WHITE", "GOLD"]
## Albedo (sRGB), metallic, roughness. Black is the colour the model came in.
const TINTS := [
	[Color(0, 0, 0), -1.0, -1.0],
	[Color(0.55, 0.03, 0.06), 0.0, 0.32],
	[Color(0.30, 0.07, 0.50), 0.0, 0.32],
	[Color(0.03, 0.36, 0.16), 0.0, 0.32],
	[Color(0.05, 0.09, 0.36), 0.0, 0.32],
	[Color(0.90, 0.90, 0.92), 0.0, 0.38],
	[Color(0.86, 0.62, 0.24), 0.9, 0.28],
]
const DYED_MATERIALS := ["fit_leather", "fit_nylon", "fit_gold"]
var _dyes: Dictionary = {}


func _dyeable() -> bool:
	return face >= 0 and face < faces.size() and String(faces[face]).begins_with("anna")


## Dyes THE NIGHT ELF's clothes (see `TINTS`); kept across looks.
func set_tint(index: int) -> void:
	tint = posmod(index, TINTS.size())
	_apply_tint()


func _apply_tint() -> void:
	for node in find_children("an_*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var key := String(mesh.name).trim_prefix("an_")
		if not (key.begins_with("fit_") or key == "bra" or key == "thong") or mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var base := mesh.mesh.surface_get_material(i) as BaseMaterial3D
			if base == null or not DYED_MATERIALS.any(func(m: String) -> bool: return base.resource_name.begins_with(m)):
				continue
			if tint == 0:
				mesh.set_surface_override_material(i, null)
				continue
			var dye_key := "%s/%d" % [base.resource_name, tint]
			if not _dyes.has(dye_key):
				var dyed := base.duplicate() as BaseMaterial3D
				var t: Array = TINTS[tint]
				dyed.albedo_color = t[0]
				# Metal stays metal, whatever its colour.
				if base.metallic < 0.5:
					dyed.metallic = t[1]
					dyed.roughness = t[2]
				_dyes[dye_key] = dyed
			mesh.set_surface_override_material(i, _dyes[dye_key])


## Her roll: Tariel's quick roll back up to the run, carried onto Avtandil's
## skeleton (his dive forward sprawls on its back — not hers).
const ROLL_FROM := "res://assets/tariel_rigged/tariel_rigged.glb"
const ROLL_CLIP := &"Roll_Quick_To_Run"
const ROLL_LIBRARY := &"elf"


func _ready() -> void:
	super()
	var roll := borrow_clip(ROLL_FROM, ROLL_CLIP, ROLL_LIBRARY)
	if roll != &"":
		clips[&"roll"] = roll
		roll_share = 0.8


## Copies `clip` from another rig of the same bone names (`scene`) onto this
## one's skeleton: each bone turned from its rest as the other's is turned
## from its own (local turn carried through the two rests), the hips' travel
## scaled by the two hips' heights. Returns the clip's name in this rig's
## player ("<library>/<clip>"), or &"" if it could not be had.
func borrow_clip(scene: String, clip: StringName, library: StringName) -> StringName:
	if _anim == null or _skel == null or not ResourceLoader.exists(scene):
		return &""
	var src_root := (load(scene) as PackedScene).instantiate()
	var src_anim := src_root.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	var src_skel := src_root.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	if src_anim == null or src_skel == null or not src_anim.has_animation(clip):
		src_root.free()
		return &""
	var from := src_anim.get_animation(clip)
	# Where this rig's clips point at its skeleton.
	var prefix := ""
	for n in _anim.get_animation_list():
		var a := _anim.get_animation(n)
		for t in a.get_track_count():
			var path := String(a.track_get_path(t))
			if path.contains(":"):
				prefix = path.get_slice(":", 0)
				break
		if prefix != "":
			break
	var h_src := src_skel.get_bone_global_rest(maxi(src_skel.find_bone("pelvis"), 0)).origin.y
	var h_dst := _skel.get_bone_global_rest(maxi(_skel.find_bone("pelvis"), 0)).origin.y
	var k := h_dst / h_src if h_src > 0.01 else 1.0
	var out := Animation.new()
	out.length = from.length
	out.loop_mode = from.loop_mode
	for t in from.get_track_count():
		var path := String(from.track_get_path(t))
		if not path.contains(":"):
			continue
		var bone := path.get_slice(":", 1)
		var bs := src_skel.find_bone(bone)
		var bd := _skel.find_bone(bone)
		if bs < 0 or bd < 0:
			continue
		var type := from.track_get_type(t)
		if type == Animation.TYPE_ROTATION_3D:
			var r_src := src_skel.get_bone_rest(bs).basis.get_rotation_quaternion()
			var r_dst := _skel.get_bone_rest(bd).basis.get_rotation_quaternion()
			var fix := r_src.inverse() * r_dst
			var nt := out.add_track(Animation.TYPE_ROTATION_3D)
			out.track_set_path(nt, NodePath(prefix + ":" + bone))
			for i in from.track_get_key_count(t):
				var q: Quaternion = from.track_get_key_value(t, i)
				out.rotation_track_insert_key(nt, from.track_get_key_time(t, i), (q * fix).normalized())
		elif type == Animation.TYPE_POSITION_3D and bone == "pelvis":
			var p_src := src_skel.get_bone_rest(bs).origin
			var p_dst := _skel.get_bone_rest(bd).origin
			var nt := out.add_track(Animation.TYPE_POSITION_3D)
			out.track_set_path(nt, NodePath(prefix + ":" + bone))
			for i in from.track_get_key_count(t):
				var v: Vector3 = from.track_get_key_value(t, i)
				out.position_track_insert_key(nt, from.track_get_key_time(t, i), p_dst + (v - p_src) * k)
	src_root.free()
	var lib: AnimationLibrary
	if _anim.has_animation_library(library):
		lib = _anim.get_animation_library(library)
	else:
		lib = AnimationLibrary.new()
		_anim.add_animation_library(library, lib)
	lib.add_animation(clip, out)
	return StringName("%s/%s" % [library, clip])


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
	_apply_tint()


## Her outfits are whole bodies of the figure: the one put on is shown, the
## other hidden (the rig's own rule hides every garb under a whole figure).
func set_garb(index: int) -> void:
	super(index)
	for i in garbs.size():
		var mesh := find_child(String(garbs[i]), true, false) as MeshInstance3D
		if mesh != null:
			mesh.visible = i == garb
