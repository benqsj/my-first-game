class_name StaticBatch
extends RefCounted

## Many small meshes that never move, drawn as a few big ones.
##
## The lands' places ([LandsPlaces]) are put up out of boxes, cylinders and the
## kit's props: thousands of [MeshInstance3D]s, each its own draw call and its
## own draw call again in every shadow cascade it falls in. Seen from the spawn
## that was about 4 000 of the frame's 6 000 draws. Godot does not batch 3D
## meshes by itself, so this does it once, at load: every plain mesh straight
## under a holder is copied into one mesh per (square of the map, material,
## shadow, size), and the originals are freed.
##
## Size matters twice. A piece the size of a crate is not worth drawing past
## [constant SMALL_REACH] and a wall is worth drawing as far as the fog lets
## anything be seen, so pieces of different sizes go into different batches and
## each batch is given the reach of its size (kept as `designed_range` metadata,
## which [Graphics] scales and caps to the setting's reach). And the smallest
## pieces cast no shadow: at their size, under trees and walls, it cannot be seen.
##
## What is left alone: anything with children or a script (the land gate, a lit
## fire), anything see-through (the light shafts) and anything that is not
## plain triangles. Those, and the kit's buildings, which are scenes, get a
## reach of their own size by [method range_rest].

## Below this a piece is small (the length of its box's diagonal, metres).
const SMALL := 2.5
## Below this a piece is middling; above, large.
const MIDDLE := 10.0
## How far each size is drawn on High, before [Graphics] scales it. Large is
## drawn as far as the setting's reach.
const SMALL_REACH := 70.0
const MIDDLE_REACH := 150.0
## Small pieces under this diagonal cast no shadow.
const NO_SHADOW := 1.6

## The batches made, by [method merge], for a test to read.
static var last_counts: Dictionary = {}


## The side of the squares each size is batched on, metres. A batch is culled
## and ranged as one box, so the small pieces go on small squares: on one big
## square the crate at its far corner is drawn as long as the near one is.
const CELL := [32.0, 64.0, 96.0]


## Bumped whenever what a merge makes changes, so old caches are not read.
const CACHE_VERSION := 1


## Copies the plain meshes straight under `holder` into batches on squares
## [constant CELL] metres on a side, and frees them. Returns
## {"pieces": n, "batches": m}.
##
## **Cached.** Building the batches is most of a level's load (5.5 s of the
## lands' places on the M1: every piece's arrays are read back from the
## renderer, twice). With a `cache_key` — anything that changes when what is
## put up changes — the batches are kept in `user://batch_cache/` the first
## time and read from there after (a fraction of a second); the pieces are
## still picked out the same way and freed. `-- no_batch_cache` builds afresh.
static func merge(holder: Node3D, cache_key: String = "") -> Dictionary:
	var path := ""
	if cache_key != "" and not "no_batch_cache" in OS.get_cmdline_user_args():
		path = "user://batch_cache/%s_v%d.scn" % [cache_key, CACHE_VERSION]
		if ResourceLoader.exists(path):
			var cached := _from_cache(holder, path)
			if not cached.is_empty():
				return cached
	var built := _merge(holder)
	if path != "":
		_to_cache(holder, path)
	return built


## The pieces a merge takes: plain meshes straight under the holder.
static func _takes(mi: MeshInstance3D) -> bool:
	if mi == null or mi.get_child_count() > 0 or mi.get_script() != null \
			or not mi.visible or mi.mesh == null or mi.is_in_group(&"unbatched") \
			or mi.skeleton != NodePath("") and mi.skin != null:
		return false
	var mesh := mi.mesh
	for s in mesh.get_surface_count():
		var mat: Material = mi.material_override
		if mat == null:
			mat = mi.get_surface_override_material(s)
		if mat == null:
			mat = mesh.surface_get_material(s)
		var base := mat as BaseMaterial3D
		if base != null and (base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
				or base.blend_mode != BaseMaterial3D.BLEND_MODE_MIX):
			return false
		if mat != null and not (mat is BaseMaterial3D) and not (mat is ShaderMaterial):
			return false
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(s) \
				!= Mesh.PRIMITIVE_TRIANGLES:
			return false
	return true


static func _from_cache(holder: Node3D, path: String) -> Dictionary:
	var scene := load(path) as PackedScene
	if scene == null:
		return {}
	var root := scene.instantiate()
	var taken: Array[Node] = []
	for child in holder.get_children():
		if _takes(child as MeshInstance3D):
			taken.append(child)
	if int(root.get_meta(&"pieces", -1)) != taken.size():
		# not what was cached (something changed that the key missed): build
		root.free()
		return {}
	for node in taken:
		holder.remove_child(node)
		node.free()
	var made := 0
	for batch in root.get_children():
		root.remove_child(batch)
		batch.owner = null
		holder.add_child(batch)
		made += 1
	root.free()
	last_counts = {"pieces": taken.size(), "batches": made, "cached": true}
	return last_counts


static func _to_cache(holder: Node3D, path: String) -> void:
	var root := Node3D.new()
	root.set_meta(&"pieces", int(last_counts.get("pieces", 0)))
	for child in holder.get_children():
		if not String(child.name).begins_with("Batch_"):
			continue
		var copy := child.duplicate()
		root.add_child(copy)
		copy.owner = root
	var packed := PackedScene.new()
	if packed.pack(root) == OK:
		DirAccess.make_dir_recursive_absolute("user://batch_cache")
		ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS)
	root.free()


static func _merge(holder: Node3D) -> Dictionary:
	var groups: Dictionary = {}
	var taken: Array[Node] = []
	for child in holder.get_children():
		var mi := child as MeshInstance3D
		if mi == null or mi.get_child_count() > 0 or mi.get_script() != null \
				or not mi.visible or mi.mesh == null or mi.is_in_group(&"unbatched") \
				or mi.skeleton != NodePath("") and mi.skin != null:
			continue
		var mesh := mi.mesh
		var box := mi.transform * mesh.get_aabb()
		var diagonal := box.size.length()
		var size_class := 0 if diagonal < SMALL else (1 if diagonal < MIDDLE else 2)
		var shadow := mi.cast_shadow
		if diagonal < NO_SHADOW:
			shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var centre := box.get_center()
		var cell: float = CELL[size_class]
		var square := Vector2i(floori(centre.x / cell), floori(centre.z / cell))
		var origin := Vector3((square.x + 0.5) * cell, 0.0, (square.y + 0.5) * cell)
		var plain := true
		var mats: Array = []
		for s in mesh.get_surface_count():
			var mat: Material = mi.material_override
			if mat == null:
				mat = mi.get_surface_override_material(s)
			if mat == null:
				mat = mesh.surface_get_material(s)
			var base := mat as BaseMaterial3D
			if base != null and (base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
					or base.blend_mode != BaseMaterial3D.BLEND_MODE_MIX):
				plain = false
			if mat != null and not (mat is BaseMaterial3D) and not (mat is ShaderMaterial):
				plain = false
			if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(s) \
					!= Mesh.PRIMITIVE_TRIANGLES:
				plain = false
			mats.append(mat)
		if not plain:
			continue
		var into_square := Transform3D(Basis.IDENTITY, -origin) * mi.transform
		for s in mesh.get_surface_count():
			var layout := _layout(mesh, s)
			var mat: Material = mats[s]
			var key := "%d,%d|%d|%d|%d|%d" % [square.x, square.y,
					mat.get_instance_id() if mat != null else 0, size_class, shadow, layout]
			var group: Dictionary = groups.get(key, {})
			if group.is_empty():
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				group = {"st": st, "mat": mat, "size": size_class, "shadow": shadow,
						"origin": origin, "count": 0}
				groups[key] = group
			(group["st"] as SurfaceTool).append_from(mesh, s, into_square)
			group["count"] = int(group["count"]) + 1
		taken.append(mi)

	var made := 0
	for key: String in groups:
		var group: Dictionary = groups[key]
		var st := group["st"] as SurfaceTool
		var mesh := st.commit()
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		mesh.surface_set_material(0, group["mat"])
		var batch := MeshInstance3D.new()
		batch.name = "Batch_%d" % made
		batch.mesh = mesh
		batch.position = group["origin"]
		batch.cast_shadow = group["shadow"]
		var reach := [SMALL_REACH, MIDDLE_REACH, 0.0][int(group["size"])] as float
		batch.set_meta(&"designed_range", reach)
		batch.visibility_range_end = reach
		holder.add_child(batch)
		made += 1
	for node in taken:
		holder.remove_child(node)
		node.free()
	last_counts = {"pieces": taken.size(), "batches": made}
	return last_counts


## Which of the arrays that matter to a merge a surface has: surfaces only
## merge with surfaces laid out the same way.
static func _layout(mesh: Mesh, s: int) -> int:
	var arrays := mesh.surface_get_arrays(s)
	var bits := 0
	for kind: int in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR,
			Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		if arrays[kind] != null:
			bits |= 1 << kind
	return bits


## Every drawn thing under `holder` that has no reach yet gets the reach of its
## size: the kit's buildings, the props that were not batched.
static func range_rest(holder: Node3D) -> void:
	for node in holder.find_children("*", "GeometryInstance3D", true, false):
		var geo := node as GeometryInstance3D
		if geo.has_meta(&"designed_range"):
			continue
		if geo.visibility_range_end > 0.0:
			# Given a reach where it was put up (a sign's lettering): kept.
			geo.set_meta(&"designed_range", geo.visibility_range_end)
			continue
		var box := geo.global_transform * geo.get_aabb() if geo.is_inside_tree() else geo.get_aabb()
		var diagonal := box.size.length()
		var reach := SMALL_REACH if diagonal < SMALL else (MIDDLE_REACH if diagonal < MIDDLE else 0.0)
		geo.set_meta(&"designed_range", reach)
		geo.visibility_range_end = reach
