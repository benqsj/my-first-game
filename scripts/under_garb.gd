class_name UnderGarb
extends RefCounted

## What a woman wears under her breeches, in another cut than the pack's
## (the user's word, 2026-10-07: her underthings in another shape). The
## look's "smalls": "" the pack's own, "shorts" short drawers to mid-thigh
## (her bare body's hips and thighs drawn in the cloth's colour), "skirt" a
## short underskirt over them (a flared ring of cloth from the hips).

## Where the cloth's colour is on the body texture (its gradient strip, the
## underthings' quadrant), and where her skin's is.
const CLOTH_UV := Vector2(0.018344, 0.703866)
## The drawers' hem and waist (metres up the figure).
## The cloth's band on her legs (the user's word, 2026-10-07: as long as
## the drawers were, but down to the knees).
const HEM := 0.58
const WAIST := 0.86
const SKIRT_TOP := 1.21
const SKIRT_HEM := 0.84

static var _made: Dictionary = {}


## `mesh` (her bare legs, cut from the body) with the drawers drawn on it:
## every triangle between the hem and the waist on the hips or thighs in the
## cloth's colour. The triangles are made each their own corners, so the
## colour stops at an edge and does not run along the texture's strip.
static func shorts(mesh: Mesh, skin: Skin) -> Mesh:
	var key := "s%d" % mesh.get_instance_id()
	if _made.has(key):
		return _made[key]
	var names := _names(skin)
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var index: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var per := floori(float(bones.size()) / float(verts.size()))
		var b := []
		b.resize(Mesh.ARRAY_MAX)
		var nv := PackedVector3Array()
		var nn := PackedVector3Array()
		var nuv := PackedVector2Array()
		var nb := PackedInt32Array()
		var nw := PackedFloat32Array()
		var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
		for t in floori(index.size() / 3.0):
			var hips := 0
			var poly := []
			for q in 3:
				var v := index[t * 3 + q]
				var bone := _main(bones, weights, per, v, names)
				hips += 1 if (bone.contains("thigh") or bone.contains("knee") or bone.contains("oatTail")) else 0
				var bw := {}
				for j in per:
					if weights[v * per + j] > 0.0:
						bw[bones[v * per + j]] = float(bw.get(bones[v * per + j], 0.0)) + weights[v * per + j]
				poly.append({"p": verts[v], "n": normals[v], "uv": uvs[v], "w": bw})
			var pieces := [[poly, false]]
			if hips >= 2:
				# cut along the hem and the waist: the cloth between them
				pieces = []
				for low: Array in _clip(poly, HEM):
					pieces.append([low, false])
				for mid: Array in _clip(poly, HEM, true):
					for under: Array in _clip(mid, WAIST):
						pieces.append([under, true])
					for over: Array in _clip(mid, WAIST, true):
						pieces.append([over, false])
			for piece: Array in pieces:
				var pts: Array = piece[0]
				for k in range(1, pts.size() - 1):
					for corner: Dictionary in [pts[0], pts[k], pts[k + 1]]:
						nv.append(corner.p)
						nn.append(corner.n)
						nuv.append(CLOTH_UV if piece[1] else corner.uv)
						var pairs := (corner.w as Dictionary).keys()
						pairs.sort_custom(func(x: Variant, y: Variant) -> bool:
							return float(corner.w[x]) > float(corner.w[y]))
						var total := 0.0
						for j in mini(per, pairs.size()):
							total += float(corner.w[pairs[j]])
						for j in per:
							if j < pairs.size():
								nb.append(int(pairs[j]))
								nw.append(float(corner.w[pairs[j]]) / maxf(total, 0.0001))
							else:
								nb.append(0)
								nw.append(0.0)
		b[Mesh.ARRAY_VERTEX] = nv
		b[Mesh.ARRAY_NORMAL] = nn
		b[Mesh.ARRAY_TEX_UV] = nuv
		b[Mesh.ARRAY_BONES] = nb
		b[Mesh.ARRAY_WEIGHTS] = nw
		var flags: int = mesh.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b, [], {}, flags)
		out.surface_set_material(s, mesh.surface_get_material(s))
	out.set_meta(&"from", mesh.get_meta(&"from", PackedInt32Array()))
	_made[key] = out
	return out


## A short underskirt for the body `mesh` (her bare body, skinned by `skin`):
## a ring round her hips at SKIRT_TOP, flared out to SKIRT_HEM, its top on
## the pelvis and its hem half on the thigh beneath each side, so it swings
## with her stride.
static func skirt(mesh: Mesh, skin: Skin) -> Mesh:
	var key := "k%d" % mesh.get_instance_id()
	if _made.has(key):
		return _made[key]
	var names := _names(skin)
	var pelvis := names.find("pelvis_joint")
	var l_thigh := names.find("L_thigh_joint")
	var r_thigh := names.find("R_thigh_joint")
	var a := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	# her hips: the middle and the reach every way at the skirt's top
	const SIDES := 20
	var centre := Vector3.ZERO
	var n := 0
	for v in verts:
		if absf(v.y - SKIRT_TOP) < 0.05:
			centre += v
			n += 1
	if n == 0:
		return null
	centre /= n
	var reach := PackedFloat32Array()
	reach.resize(SIDES)
	for v in verts:
		if absf(v.y - SKIRT_TOP) < 0.06 or absf(v.y - (SKIRT_TOP - 0.1)) < 0.05:
			var d := Vector2(v.x - centre.x, v.z - centre.z)
			var k := posmod(roundi(d.angle() / TAU * SIDES), SIDES)
			reach[k] = maxf(reach[k], d.length())
	var st := SurfaceTool.new()
	st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := [[SKIRT_TOP, 1.0, 0.012, 0.0], [lerpf(SKIRT_TOP, SKIRT_HEM, 0.45), 1.08, 0.02, 0.3],
			[SKIRT_HEM, 1.16, 0.035, 0.6]]
	var at := []
	for ring: Array in rings:
		var row := []
		for k in SIDES:
			var ang := TAU * k / SIDES
			var r := maxf(reach[k], reach[posmod(k - 1, SIDES)])
			r = maxf(r, reach[posmod(k + 1, SIDES)]) * float(ring[1]) + float(ring[2])
			row.append(Vector3(centre.x + cos(ang) * r, float(ring[0]), centre.z + sin(ang) * r))
		at.append(row)
	for i in rings.size() - 1:
		for k in SIDES:
			var quad := [at[i][k], at[i][(k + 1) % SIDES], at[i + 1][(k + 1) % SIDES], at[i + 1][k]]
			var down := [float(rings[i][3]), float(rings[i][3]), float(rings[i + 1][3]), float(rings[i + 1][3])]
			var normal := ((quad[1] as Vector3) - (quad[0] as Vector3)).cross((quad[3] as Vector3) - (quad[0] as Vector3)).normalized()
			if normal.dot(Vector3((quad[0] as Vector3).x - centre.x, 0, (quad[0] as Vector3).z - centre.z)) < 0.0:
				normal = -normal
			for q: int in [0, 1, 2, 0, 2, 3]:
				var p: Vector3 = quad[q]
				var thigh := l_thigh if p.x > centre.x else r_thigh
				var w := float(down[q])
				st.set_normal(normal)
				st.set_uv(CLOTH_UV + Vector2(0, -0.02 * w))
				st.set_bones(PackedInt32Array([pelvis, thigh, 0, 0]))
				st.set_weights(PackedFloat32Array([1.0 - w, w, 0.0, 0.0]))
				st.add_vertex(p)
	var out := st.commit()
	var mat := (mesh.surface_get_material(0) as BaseMaterial3D)
	if mat != null:
		mat = mat.duplicate() as BaseMaterial3D
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		out.surface_set_material(0, mat)
	_made[key] = out
	return out


## The part of the convex polygon `poly` below the height `y` (above it with
## `above`), as one polygon in a list (none if nothing is there); the new
## corners on the cut are blended from the two they lie between.
static func _clip(poly: Array, y: float, above: bool = false) -> Array:
	var out := []
	var n := poly.size()
	for k in n:
		var a: Dictionary = poly[k]
		var b: Dictionary = poly[(k + 1) % n]
		var a_in := ((a.p as Vector3).y >= y) == above
		var b_in := ((b.p as Vector3).y >= y) == above
		if a_in:
			out.append(a)
		if a_in != b_in:
			var f := (y - (a.p as Vector3).y) / ((b.p as Vector3).y - (a.p as Vector3).y)
			var w := {}
			for bone: Variant in (a.w as Dictionary):
				w[bone] = float(w.get(bone, 0.0)) + float(a.w[bone]) * (1.0 - f)
			for bone: Variant in (b.w as Dictionary):
				w[bone] = float(w.get(bone, 0.0)) + float(b.w[bone]) * f
			out.append({"p": (a.p as Vector3).lerp(b.p, f), "n": (a.n as Vector3).lerp(b.n, f).normalized(),
					"uv": (a.uv as Vector2).lerp(b.uv, f), "w": w})
	return [out] if out.size() >= 3 else []


static func _names(skin: Skin) -> PackedStringArray:
	var names := PackedStringArray()
	if skin != null:
		for k in skin.get_bind_count():
			names.append(String(skin.get_bind_name(k)))
	return names


static func _main(bones: PackedInt32Array, weights: PackedFloat32Array, per: int, v: int, names: PackedStringArray) -> String:
	var best := -1.0
	var bone := ""
	for j in per:
		var k := bones[v * per + j]
		if weights[v * per + j] > best and k < names.size():
			best = weights[v * per + j]
			bone = names[k]
	return bone
