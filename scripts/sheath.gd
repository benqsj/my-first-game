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
## {"axis": guard to point, "guard": the guard's middle, "flat": the way the
## blade is wide, "length": guard to point}. Empty if it cannot be read.
##
## The line is the mesh's own long axis (its principal axis), not the way from
## the bone to the point: the bone sits in the grip off the blade's line, and a
## line through it lay a few degrees and centimetres off, so the blade stood
## out through the scabbard's side.
static func blade(mesh: MeshInstance3D, skel: Skeleton3D, bone: StringName) -> Dictionary:
	var pts := _points(mesh, skel, bone)
	if pts.size() < 4:
		return {}
	var frame := _axes(pts)
	var c: Vector3 = frame[0]
	var d: Vector3 = frame[1]
	# the point is the end farther from the bone (the hand)
	var lo := INF
	var hi := -INF
	for p in pts:
		var t := (p - c).dot(d)
		lo = minf(lo, t)
		hi = maxf(hi, t)
	if (c + d * lo).length() > (c + d * hi).length():
		d = -d
		var keep := lo
		lo = -hi
		hi = -keep
	# the guard: the slice across the line where the mesh is widest
	var slices := 40
	var width := PackedFloat32Array()
	width.resize(slices)
	for p in pts:
		var t := (p - c).dot(d)
		var i := clampi(int((t - lo) / maxf(hi - lo, 0.001) * slices), 0, slices - 1)
		var across := ((p - c) - d * t).length()
		width[i] = maxf(width[i], across)
	var best := 0
	for i in slices:
		if width[i] > width[best]:
			best = i
	var t0 := lo + (hi - lo) * float(best) / slices
	var t1 := lo + (hi - lo) * float(best + 1) / slices
	var guard := Vector3.ZERO
	var n := 0
	for p in pts:
		var t := (p - c).dot(d)
		if t >= t0 and t <= t1:
			guard += p
			n += 1
	guard = guard / float(maxi(n, 1)) if n > 0 else c + d * (t0 + t1) * 0.5
	var g := (guard - c).dot(d)
	return {"axis": d, "guard": guard, "flat": frame[2], "length": hi - g}


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
	var frame := _axes(pts)
	var c: Vector3 = frame[0]
	var u: Vector3 = frame[1]
	var s: Vector3 = frame[2]
	# the mouth is the end that is higher at rest
	var rest := skel.get_bone_global_rest(bone)
	var lo := INF
	var hi := -INF
	var top := -INF
	var top_t := 0.0
	for p in pts:
		var t := (p - c).dot(u)
		lo = minf(lo, t)
		hi = maxf(hi, t)
		var y := (rest * p).y
		if y > top:
			top = y
			top_t = t
	if top_t < 0.0:
		u = -u
		var keep := lo
		lo = -hi
		hi = -keep
	# the mouth's middle: the scabbard's last few centimetres at that end
	var mouth := Vector3.ZERO
	var n := 0
	for p in pts:
		if (p - c).dot(u) >= hi - MOUTH_DEPTH:
			mouth += p
			n += 1
	mouth = mouth / float(n) if n > 0 else c + u * hi
	# its line through the mouth's middle, the way the scabbard runs
	mouth = mouth - u * (mouth - c).dot(u) + u * hi
	var into := -u
	var d: Vector3 = the_blade["axis"]
	var f: Vector3 = the_blade["flat"]
	f = (f - d * f.dot(d)).normalized()
	s = (s - into * s.dot(into)).normalized()
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

## How deep from its end the mouth's middle is taken, metres.
const MOUTH_DEPTH := 0.04


## [centre, long axis, middle axis, short axis] of `pts`: their mean and the
## principal axes of their spread (Jacobi on the 3x3 covariance).
static func _axes(pts: PackedVector3Array) -> Array:
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= float(pts.size())
	var m := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	for p in pts:
		var q := p - c
		var v := [q.x, q.y, q.z]
		for i in 3:
			for j in 3:
				m[i][j] += v[i] * v[j]
	var e := [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
	for sweep in 30:
		for pq: Array in [[0, 1], [0, 2], [1, 2]]:
			var a: int = pq[0]
			var b: int = pq[1]
			if absf(m[a][b]) < 1e-12:
				continue
			var theta: float = (float(m[b][b]) - float(m[a][a])) / (2.0 * float(m[a][b]))
			var t := signf(theta) / (absf(theta) + sqrt(theta * theta + 1.0))
			if theta == 0.0:
				t = 1.0
			var cs := 1.0 / sqrt(t * t + 1.0)
			var sn := t * cs
			for k in 3:
				var mka: float = m[k][a]
				var mkb: float = m[k][b]
				m[k][a] = cs * mka - sn * mkb
				m[k][b] = sn * mka + cs * mkb
			for k in 3:
				var mak: float = m[a][k]
				var mbk: float = m[b][k]
				m[a][k] = cs * mak - sn * mbk
				m[b][k] = sn * mak + cs * mbk
			for k in 3:
				var eka: float = e[k][a]
				var ekb: float = e[k][b]
				e[k][a] = cs * eka - sn * ekb
				e[k][b] = sn * eka + cs * ekb
	var order := [0, 1, 2]
	order.sort_custom(func(i: int, j: int) -> bool: return float(m[i][i]) > float(m[j][j]))
	var axes: Array = [c]
	for i: int in order:
		axes.append(Vector3(e[0][i], e[1][i], e[2][i]).normalized())
	return axes


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
