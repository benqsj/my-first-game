class_name LowPolyLod
extends RefCounted

## A lighter copy of a faceted low poly mesh for things seen only far off
## (2026-10-28: the swamp's deep wood was 150 oaks of ~13 000 triangles each,
## ~7 ms of its 20 ms frame at High on the M1).
##
## Godot's own LODs do little for these meshes: every face has its own
## corners (that is what makes it faceted), and the simplifier will not
## merge corners that are apart. So here the corners are first welded by
## position, the mesh is simplified with [method ImporterMesh.generate_lods],
## and the faces are split again, each with its own flat normal and the
## colour its corners had, so it still reads as faceted.
##
## Made once per mesh and kept ([member _made]). Only position and vertex
## colour are kept (all the low poly shaders read), so it is for meshes drawn
## by `lp_solid` / `lp_foliage`, not textured ones.

static var _made: Dictionary = {}


## `mesh` with about `keep` of its triangles (0..1), the same surfaces and
## materials. Returns `mesh` itself if it cannot be made lighter.
static func far_mesh(mesh: Mesh, keep: float = 0.25) -> Mesh:
	var key := "%d_%.2f" % [mesh.get_instance_id(), keep]
	if _made.has(key):
		return _made[key]
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var src_c: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var src_i: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if src_i.is_empty():
			src_i.resize(src_v.size())
			for k in src_v.size():
				src_i[k] = k
		# weld the corners by position
		var at := {}
		var v := PackedVector3Array()
		var c := PackedColorArray()
		var remap := PackedInt32Array()
		remap.resize(src_v.size())
		for k in src_v.size():
			var p := src_v[k].snapped(Vector3.ONE * 0.0005)
			var w: int = at.get(p, -1)
			if w < 0:
				w = v.size()
				at[p] = w
				v.append(src_v[k])
				c.append(src_c[k] if k < src_c.size() else Color.WHITE)
			remap[k] = w
		var idx := PackedInt32Array()
		idx.resize(src_i.size())
		for k in src_i.size():
			idx[k] = remap[src_i[k]]
		var welded := []
		welded.resize(Mesh.ARRAY_MAX)
		welded[Mesh.ARRAY_VERTEX] = v
		welded[Mesh.ARRAY_COLOR] = c
		welded[Mesh.ARRAY_INDEX] = idx
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, welded)
		im.generate_lods(180.0, 180.0, [])
		var lighter := idx
		var want := int(float(idx.size()) * keep)
		for lod in im.get_surface_lod_count(0):
			var li := im.get_surface_lod_indices(0, lod)
			lighter = li
			if li.size() <= want:
				break
		# faces split again: flat, each the colour of its corners
		var fv := PackedVector3Array()
		var fn := PackedVector3Array()
		var fc := PackedColorArray()
		for k in range(0, lighter.size() - 2, 3):
			var a := v[lighter[k]]
			var b := v[lighter[k + 1]]
			var e := v[lighter[k + 2]]
			var n := (e - a).cross(b - a).normalized()
			var col := (c[lighter[k]] + c[lighter[k + 1]] + c[lighter[k + 2]]) / 3.0
			for p: Vector3 in [a, b, e]:
				fv.append(p)
				fn.append(n)
				fc.append(col)
		var flat := []
		flat.resize(Mesh.ARRAY_MAX)
		flat[Mesh.ARRAY_VERTEX] = fv
		flat[Mesh.ARRAY_NORMAL] = fn
		flat[Mesh.ARRAY_COLOR] = fc
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, flat)
		out.surface_set_material(s, mesh.surface_get_material(s))
	_made[key] = out
	return out
