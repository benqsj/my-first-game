class_name Sheath
extends RefCounted

## Where a sword sits in a scabbard, worked out off the two meshes ([SkinnedRig]
## `_fit_sheath`). Both are rigid on one bone of the figure each: the sword on
## `weapon_r`, the scabbard on whatever the pack put it on. Each is read in its
## bone's frame at rest: the blade's line (grip to point), its guard (where the
## mesh is widest across that line) and the way the guard runs (the blade's
## width); the scabbard's line, its mouth (the end that is higher at rest), its
## length and the way it is wide. The socket is the sword's bone placed so the
## blade runs down the scabbard, the guard at the mouth, the flats together.


## The blade of `mesh` (rigid on `bone` of `skel`), in the bone's frame:
## {"axis": grip to point, "guard": the guard's middle, "flat": the way the
## guard runs, "length": guard to point}. Empty if it cannot be read.
static func blade(mesh: MeshInstance3D, skel: Skeleton3D, bone: StringName) -> Dictionary:
	var pts := _points(mesh, skel, bone)
	if pts.size() < 4:
		return {}
	var tip := Vector3.ZERO
	for p in pts:
		if p.length_squared() > tip.length_squared():
			tip = p
	var d := tip.normalized()
	var widest := -1.0
	var guard_t := 0.0
	var flat := Vector3.ZERO
	for p in pts:
		var t := p.dot(d)
		var across := p - d * t
		if across.length() > widest:
			widest = across.length()
			guard_t = t
			flat = across
	if flat.length_squared() < 1e-8:
		flat = d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT)
	return {"axis": d, "guard": d * guard_t, "flat": flat.normalized(), "length": tip.length() - guard_t}


## The socket for `the_blade` ([method blade]) in the scabbard `mesh`, on the
## figure's skeleton `skel`: {"bone": index, "at": the sword bone's transform
## in the scabbard bone's frame, "where": &"back" or &"hips", "length": the
## scabbard's, "mesh": it}. Empty if it cannot be read.
static func socket(mesh: MeshInstance3D, skel: Skeleton3D, the_blade: Dictionary) -> Dictionary:
	if mesh == null or the_blade.is_empty():
		return {}
	var bone := _main_bone(mesh, skel)
	if bone < 0:
		return {}
	var pts := _points(mesh, skel, skel.get_bone_name(bone))
	if pts.size() < 4:
		return {}
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= float(pts.size())
	var p1 := c
	for p in pts:
		if p.distance_squared_to(c) > p1.distance_squared_to(c):
			p1 = p
	var p2 := p1
	for p in pts:
		if p.distance_squared_to(p1) > p2.distance_squared_to(p1):
			p2 = p
	var u := (p2 - p1).normalized()
	if u.length_squared() < 0.5:
		return {}
	# the mouth is the end that is higher at rest
	var rest := skel.get_bone_global_rest(bone)
	if (rest * p1).y > (rest * p2).y:
		u = -u
	var lo := INF
	var hi := -INF
	var widest := -1.0
	var wide := Vector3.ZERO
	for p in pts:
		var t := (p - c).dot(u)
		lo = minf(lo, t)
		hi = maxf(hi, t)
		var across := (p - c) - u * t
		if across.length() > widest:
			widest = across.length()
			wide = across
	var mouth := c + u * hi
	var into := -u
	var s := (wide - into * wide.dot(into)).normalized()
	if s.length_squared() < 0.5:
		s = into.cross(Vector3.UP).normalized()
	var d: Vector3 = the_blade["axis"]
	var f: Vector3 = the_blade["flat"]
	f = (f - d * f.dot(d)).normalized()
	var sword_frame := Basis(d, f, d.cross(f))
	var sheath_frame := Basis(into, s, into.cross(s))
	var turn := sheath_frame * sword_frame.transposed()
	# the guard just proud of the mouth
	var at := Transform3D(turn, mouth + u * GUARD_PROUD - turn * (the_blade["guard"] as Vector3))
	var chest := skel.find_bone("chest_joint")
	var high := (rest * mouth).y
	var where := &"back"
	if chest >= 0 and high < skel.get_bone_global_rest(chest).origin.y * 0.85:
		where = &"hips"
	return {"bone": bone, "at": at, "where": where, "length": hi - lo, "mesh": mesh}

## How far the guard stands out of the mouth, metres.
const GUARD_PROUD := 0.015


## A scabbard across the back with its mouth over the wrong shoulder (the
## pack's swordsman wears his hilt over his left, and a right hand draws over
## the right) is turned over to the other side: its mesh mirrored across the
## figure's middle, in place, once. A scabbard at the hip is left alone (the
## fighter's, at the left hip, is drawn across the body).
static func put_mouth_over_sword_shoulder(mesh: MeshInstance3D, skel: Skeleton3D) -> void:
	if mesh == null or mesh.mesh == null or mesh.has_meta(&"mirrored"):
		return
	var bone := _main_bone(mesh, skel)
	var left := skel.find_bone("L_shoulder_joint")
	var chest := skel.find_bone("chest_joint")
	if bone < 0 or left < 0 or chest < 0:
		return
	var pts := _points(mesh, skel, skel.get_bone_name(bone))
	if pts.is_empty():
		return
	var rest := skel.get_bone_global_rest(bone)
	var top := rest * pts[0]
	for p in pts:
		var q := rest * p
		if q.y > top.y:
			top = q
	var chest_y := skel.get_bone_global_rest(chest).origin.y
	var left_x := skel.get_bone_global_rest(left).origin.x
	if top.y < chest_y * 0.85 or signf(top.x) != signf(left_x) or absf(top.x) < 0.05:
		return
	mesh.mesh = mirrored_x(mesh.mesh as ArrayMesh)
	mesh.set_meta(&"mirrored", true)


## `source` mirrored across its x = 0 plane: positions, normals and tangents
## turned over, and each triangle wound the other way so it still faces out.
static func mirrored_x(source: ArrayMesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for i in verts.size():
			verts[i].x = -verts[i].x
		arrays[Mesh.ARRAY_VERTEX] = verts
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
			for i in normals.size():
				normals[i].x = -normals[i].x
			arrays[Mesh.ARRAY_NORMAL] = normals
		if arrays[Mesh.ARRAY_TANGENT] != null:
			var tangents := arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array
			for i in range(0, tangents.size(), 4):
				tangents[i] = -tangents[i]
				tangents[i + 3] = -tangents[i + 3]
			arrays[Mesh.ARRAY_TANGENT] = tangents
		if arrays[Mesh.ARRAY_INDEX] != null:
			var index := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			for i in range(0, index.size() - 2, 3):
				var keep := index[i + 1]
				index[i + 1] = index[i + 2]
				index[i + 2] = keep
			arrays[Mesh.ARRAY_INDEX] = index
		out.add_surface_from_arrays(source.surface_get_primitive_type(s), arrays)
		out.surface_set_material(s, source.surface_get_material(s))
	return out


## The bone `mesh` is bound to most.
static func _main_bone(mesh: MeshInstance3D, skel: Skeleton3D) -> int:
	if mesh.skin == null or mesh.mesh == null:
		return -1
	var weight := {}
	for s in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(s)
		var bones: Variant = arrays[Mesh.ARRAY_BONES]
		var weights: Variant = arrays[Mesh.ARRAY_WEIGHTS]
		if bones == null or weights == null:
			continue
		var b := bones as PackedInt32Array
		var w := weights as PackedFloat32Array
		for i in mini(b.size(), w.size()):
			if w[i] > 0.01:
				weight[b[i]] = float(weight.get(b[i], 0.0)) + w[i]
	var best := -1
	var most := 0.0
	for k: int in weight:
		if float(weight[k]) > most:
			most = weight[k]
			best = k
	if best < 0 or best >= mesh.skin.get_bind_count():
		return -1
	var named := mesh.skin.get_bind_name(best)
	return skel.find_bone(String(named)) if named != &"" else mesh.skin.get_bind_bone(best)


## The vertices of `mesh` in `bone`'s frame at rest.
static func _points(mesh: MeshInstance3D, skel: Skeleton3D, bone: StringName) -> PackedVector3Array:
	var out := PackedVector3Array()
	if mesh == null or mesh.skin == null or mesh.mesh == null or skel == null:
		return out
	var at := skel.find_bone(String(bone))
	var bind := Transform3D()
	var found := false
	for i in mesh.skin.get_bind_count():
		var named := mesh.skin.get_bind_name(i)
		if named == bone or (named == &"" and mesh.skin.get_bind_bone(i) == at):
			bind = mesh.skin.get_bind_pose(i)
			found = true
	if not found:
		return out
	for s in mesh.mesh.get_surface_count():
		for v: Vector3 in mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			out.append(bind * v)
	return out
