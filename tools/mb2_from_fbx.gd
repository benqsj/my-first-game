extends SceneTree
## Monster Bundle 2 (2026-10-31): the monsters Blender's FBX reader cannot
## open (in-between shapes; meshes bound to what it does not know: the bone
## dragon, the gazer, the plant monster, the spiders, the weeper) are made
## with Godot's own reader instead, as `vepxis-art/tools/mb2_convert.py` makes
## the rest: the pack's FBX read from vepxis-art, its one long take cut into the
## clips Unity names (`packs/monster_bundle2/clips.json`, 30 frames a second),
## sized to <height> m and stood on y 0, saved as `<kind>.scn` beside a
## `looks.json` and the pack's palettes in `tex/` ([Mb2Creature]).
##
## godot --headless --path . --script res://tools/mb2_from_fbx.gd --
##     <kind> <fbx, absolute> <height> <clips.json key>

const OUT := "res://assets/monsters_mb2/"
const PACK := "~/Projects/vepxis-art/packs/monster_bundle2/"
const FPS := 30.0
const BODYISH := ["body", "eye", "mouth", "teeth", "tooth", "horn", "tail", "wing", "tongue", "hair", "head", "nail", "claw", "skin", "fur"]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var kind := a[0]
	var fbx := a[1]
	var height := float(a[2])
	var ck := a[3]
	var pack := PACK.replace("~", OS.get_environment("HOME"))
	var doc := FBXDocument.new()
	var st := FBXState.new()
	if doc.append_from_file(fbx, st) != OK:
		print("MB2FAIL read ", fbx)
		quit(1)
		return
	var fig := doc.generate_scene(st) as Node3D
	var root := Node3D.new()
	root.name = "Mb2_" + kind
	get_root().add_child(root)
	root.add_child(fig)
	# the clips
	var players := fig.find_children("*", "AnimationPlayer", true, false)
	var clip_names: Array[String] = []
	var clip_frames := {}
	if ck.begins_with("dir:"):
		# one FBX a clip (`Treant@Jog.fbx`), bones without a skin: put on
		# the figure's skeleton by bone name
		var skel := fig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player: AnimationPlayer
		if players.is_empty():
			player = AnimationPlayer.new()
			player.name = "AnimationPlayer"
			fig.add_child(player)
		else:
			player = players[0] as AnimationPlayer
		var skel_path := String(_rel_path(fig, skel))
		var lib := AnimationLibrary.new()
		for clip_file in _fbxs(ck.substr(4)):
			var cdoc := FBXDocument.new()
			var cst := FBXState.new()
			if cdoc.append_from_file(clip_file, cst) != OK:
				continue
			var cscene := cdoc.generate_scene(cst)
			var cps := cscene.find_children("*", "AnimationPlayer", true, false)
			if cps.is_empty():
				cscene.free()
				continue
			var cp := cps[0] as AnimationPlayer
			var src: Animation = null
			for t: StringName in cp.get_animation_list():
				if String(t) != "RESET":
					src = cp.get_animation(t)
					break
			if src == null:
				cscene.free()
				continue
			var anim := _onto(src, skel, skel_path)
			var cname := clip_file.get_file().get_basename().get_slice("@", clip_file.get_file().get_basename().get_slice_count("@") - 1)
			lib.add_animation(StringName(cname), anim)
			clip_names.append(cname)
			cscene.free()
		for l in player.get_animation_library_list():
			player.remove_animation_library(l)
		player.add_animation_library("", lib)
		print("MB2 clips from files: ", clip_names.size())
	elif not players.is_empty():
		var player := players[0] as AnimationPlayer
		var take := StringName("")
		for t: StringName in player.get_animation_list():
			if String(t) != "RESET":
				take = t
				break
		var long := player.get_animation(take)
		var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pack + "clips.json"))
		var lib := AnimationLibrary.new()
		for c: Array in (all[ck] as Dictionary)["clips"]:
			var cname := String(c[0])
			if cname.to_lower() == "tpose":
				continue
			lib.add_animation(StringName(cname), _slice(long, float(c[1]) / FPS, float(c[2]) / FPS))
			clip_names.append(cname)
			clip_frames[cname] = [c[1], c[2]]
		for l in player.get_animation_library_list():
			player.remove_animation_library(l)
		player.add_animation_library("", lib)
		print("MB2 take ", take, " ", long.length, " s, ", clip_names.size(), " clips")
	# size: the body as the skin puts it, standing in its idle (some of the
	# pack's skeletons are in other units than their meshes: the mesh's own
	# box says nothing then)
	var box := _skinned_box(fig, clip_names)
	var tall := box.size.y
	if tall < 0.25 * maxf(box.size.x, box.size.z):
		tall = maxf(box.size.x, box.size.z)
	var k := height / maxf(tall, 0.0001)
	var holder := Node3D.new()
	holder.name = "Sized"
	root.remove_child(fig)
	root.add_child(holder)
	holder.add_child(fig)
	holder.scale = Vector3.ONE * k
	holder.position = Vector3(-box.get_center().x * k, -box.position.y * k, -box.get_center().z * k)
	print("MB2SIZE box ", box, " k ", k)
	# palettes
	var chdir := fbx.get_base_dir().get_base_dir()
	var out_abs := ProjectSettings.globalize_path(OUT + kind + "/")
	DirAccess.make_dir_recursive_absolute(out_abs + "tex")
	var groups := {}
	for png in _pngs(chdir):
		var n := png.get_file().get_basename()
		var g := "body"
		var re := RegEx.create_from_string("(?i)^(armou?r|sword|body|weapon|axe|shield|cloth)\\b")
		var hit := re.search(n)
		if hit != null:
			g = hit.get_string(1).to_lower().replace("armour", "armor")
		if not groups.has(g):
			groups[g] = []
		(groups[g] as Array).append(n.replace(" ", "_"))
		DirAccess.copy_absolute(png, out_abs + "tex/" + n.replace(" ", "_") + ".png")
	# (black and dark last: the first is the one it wears unless picked)
	for g: String in groups:
		(groups[g] as Array).sort_custom(func(x: String, y: String) -> bool:
			var xd := x.to_lower().contains("black") or x.to_lower().contains("dark")
			var yd := y.to_lower().contains("black") or y.to_lower().contains("dark")
			return x < y if xd == yd else yd)
	# parts and shapes
	var parts := []
	for n in fig.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		var shapes: Array[String] = []
		var am := m.mesh as ArrayMesh
		if am != null:
			for i in am.get_blend_shape_count():
				var s := String(am.get_blend_shape_name(i))
				shapes.append(s.get_slice(".", s.get_slice_count(".") - 1))
		parts.append({"name": String(m.name), "group": _group_of(String(m.name), groups), "shapes": shapes})
	for n in _all(root):
		if n != root:
			n.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	var path := OUT + kind + "/" + kind + ".scn"
	var err := ResourceSaver.save(packed, path)
	var looks := {"key": kind, "height": height, "scale": k, "groups": groups, "parts": parts,
			"clips": clip_names, "clip_frames": clip_frames, "fps": FPS, "made_by": "mb2_from_fbx.gd"}
	var f := FileAccess.open(OUT + kind + "/looks.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(looks, " "))
	f.close()
	print("MB2DONE ", path, " err ", err, " parts ", parts.size())
	quit(0)


func _pngs(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.to_lower().ends_with(".png"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		if not sub.begins_with("tex_") and not sub.begins_with("Eye"):
			out.append_array(_pngs(dir + "/" + sub))
	out.sort()
	return out


func _group_of(name: String, groups: Dictionary) -> String:
	var l := name.to_lower()
	for g: String in groups:
		if g != "body" and g != "armor" and l.contains(g):
			return g
	if groups.has("armor") and not BODYISH.any(func(b: String) -> bool: return l.contains(b)):
		return "armor"
	return "body"


## The box of the body as skinned, in `fig`'s space, posed in the first
## frame of its standing clip.
func _skinned_box(fig: Node3D, clip_names: Array[String]) -> AABB:
	var players := fig.find_children("*", "AnimationPlayer", true, false)
	var skels := fig.find_children("*", "Skeleton3D", true, false)
	if not players.is_empty() and not skels.is_empty() and not clip_names.is_empty():
		var player := players[0] as AnimationPlayer
		var stand := clip_names[0]
		for c in clip_names:
			var low := c.to_lower()
			if low == "idle":
				stand = c
				break
			if low.contains("idle") and not low.contains("break") and not low.contains("to") and stand == clip_names[0]:
				stand = c
		var anim := player.get_animation(StringName(stand))
		var root := player.get_node_or_null(player.root_node)
		for t in anim.get_track_count():
			var path := anim.track_get_path(t)
			var node := root.get_node_or_null(NodePath(String(path).get_slice(":", 0))) if root != null else null
			var sk := node as Skeleton3D
			if sk == null:
				continue
			var bone := sk.find_bone(String(path.get_concatenated_subnames()))
			if bone < 0:
				continue
			match anim.track_get_type(t):
				Animation.TYPE_POSITION_3D:
					sk.set_bone_pose_position(bone, anim.position_track_interpolate(t, 0.0))
				Animation.TYPE_ROTATION_3D:
					sk.set_bone_pose_rotation(bone, anim.rotation_track_interpolate(t, 0.0))
				Animation.TYPE_SCALE_3D:
					sk.set_bone_pose_scale(bone, anim.scale_track_interpolate(t, 0.0))
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for n in fig.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		var am := m.mesh as ArrayMesh
		var sk := m.get_node_or_null(m.skeleton) as Skeleton3D
		if am == null:
			continue
		if m.skin == null or sk == null:
			var b := fig.transform * _rel(m, fig) * m.get_aabb()
			lo = lo.min(b.position)
			hi = hi.max(b.end)
			continue
		var to_fig := fig.transform * _rel(sk, fig)
		var by_name := {}
		for i in m.skin.get_bind_count():
			var bb := m.skin.get_bind_bone(i)
			if bb < 0:
				bb = sk.find_bone(String(m.skin.get_bind_name(i)))
			by_name[i] = bb
		for surf in am.get_surface_count():
			var arrays := am.surface_get_arrays(surf)
			var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var bones := arrays[Mesh.ARRAY_BONES] as PackedInt32Array
			var weights := arrays[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array
			if bones.is_empty() or verts.is_empty():
				continue
			var per := int(bones.size() / float(verts.size()))
			var step := maxi(1, int(verts.size() / 4000.0))
			for v in range(0, verts.size(), step):
				var p := Vector3.ZERO
				var wsum := 0.0
				for j in per:
					var w := weights[v * per + j]
					if w <= 0.0:
						continue
					var bi := bones[v * per + j]
					var bone := int(by_name.get(bi, -1))
					if bone < 0:
						continue
					p += (sk.get_bone_global_pose(bone) * m.skin.get_bind_pose(bi) * verts[v]) * w
					wsum += w
				if wsum <= 0.0:
					continue
				p = to_fig * (p / wsum)
				lo = lo.min(p)
				hi = hi.max(p)
	if lo.x == INF:
		return AABB(Vector3.ZERO, Vector3.ONE)
	return AABB(lo, hi - lo)


## Where `n` is under `top` (the tree is not running yet: no global transforms).
func _rel(n: Node3D, top: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var at: Node = n
	while at != null and at != top:
		if at is Node3D:
			xf = (at as Node3D).transform * xf
		at = at.get_parent()
	return xf


func _rel_path(top: Node, n: Node) -> NodePath:
	var names: Array[String] = []
	var at: Node = n
	while at != null and at != top:
		names.push_front(String(at.name))
		at = at.get_parent()
	return NodePath("/".join(names))


func _fbxs(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.to_lower().ends_with(".fbx"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_fbxs(dir + "/" + sub))
	out.sort()
	return out


## A clip of bones made as nodes (or another skeleton) put on `skel`: each
## track to the bone of the same name; its moves scaled when the file is in
## other units than the figure (the treant's are in centimetres).
func _onto(src: Animation, skel: Skeleton3D, skel_path: String) -> Animation:
	var anim := Animation.new()
	anim.length = src.length
	anim.loop_mode = src.loop_mode
	var ratios: Array[float] = []
	var bone_of := {}
	for t in src.get_track_count():
		var path := src.track_get_path(t)
		var bone := String(path.get_concatenated_subnames())
		if bone == "":
			bone = String(path.get_name(path.get_name_count() - 1))
		if skel.find_bone(bone) < 0:
			continue
		bone_of[t] = bone
		if src.track_get_type(t) == Animation.TYPE_POSITION_3D and src.track_get_key_count(t) > 0:
			var rest := skel.get_bone_rest(skel.find_bone(bone)).origin.length()
			var moved := (src.track_get_key_value(t, 0) as Vector3).length()
			if rest > 0.0001 and moved > 0.0001:
				ratios.append(moved / rest)
	ratios.sort()
	var unit := 1.0
	if not ratios.is_empty():
		var mid := ratios[int(ratios.size() / 2.0)]
		if mid > 8.0 or mid < 0.125:
			unit = pow(10.0, roundf(log(1.0 / mid) / log(10.0)))
	for t: int in bone_of:
		var type := src.track_get_type(t)
		if type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var i := anim.add_track(type)
		anim.track_set_path(i, NodePath(skel_path + ":" + String(bone_of[t])))
		anim.track_set_interpolation_type(i, src.track_get_interpolation_type(t))
		for k in src.track_get_key_count(t):
			var v: Variant = src.track_get_key_value(t, k)
			if type == Animation.TYPE_POSITION_3D:
				v = (v as Vector3) * unit
			anim.track_insert_key(i, src.track_get_key_time(t, k), v)
	return anim


func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


## The part of `src` between `t0` and `t1` seconds, from 0.
func _slice(src: Animation, t0: float, t1: float) -> Animation:
	var anim := Animation.new()
	anim.length = maxf(t1 - t0, 1.0 / FPS)
	for t in src.get_track_count():
		var type := src.track_get_type(t)
		var i := anim.add_track(type)
		anim.track_set_path(i, src.track_get_path(t))
		anim.track_set_interpolation_type(i, src.track_get_interpolation_type(t))
		var edge := func(at: float) -> Variant:
			match type:
				Animation.TYPE_POSITION_3D:
					return src.position_track_interpolate(t, at)
				Animation.TYPE_ROTATION_3D:
					return src.rotation_track_interpolate(t, at)
				Animation.TYPE_SCALE_3D:
					return src.scale_track_interpolate(t, at)
				Animation.TYPE_BLEND_SHAPE:
					return src.blend_shape_track_interpolate(t, at)
				Animation.TYPE_VALUE:
					return src.value_track_interpolate(t, at)
			return null
		var v0: Variant = edge.call(t0)
		if v0 != null:
			anim.track_insert_key(i, 0.0, v0)
		for k in src.track_get_key_count(t):
			var kt := src.track_get_key_time(t, k)
			if kt > t0 + 0.0001 and kt < t1 - 0.0001:
				anim.track_insert_key(i, kt - t0, src.track_get_key_value(t, k))
		var v1: Variant = edge.call(t1)
		if v1 != null:
			anim.track_insert_key(i, t1 - t0, v1)
	return anim
