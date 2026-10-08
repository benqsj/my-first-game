class_name Occluders
extends RefCounted

## What hides what: the ground and the solid buildings, given to the renderer
## as occluders, so that what stands behind a hill or a wall is not drawn.
##
## Godot's occlusion culling rasterises the occluders into a small depth
## picture on the CPU each frame and skips every instance whose box is wholly
## behind it. Nothing in the level was an occluder: the ground of the lands is
## a flat grid lifted in its shader (the CPU never sees its shape) and the
## city and the villages are boxes put up at load. So both are made here, at
## load, from what the level already knows:
##
## * **The ground.** A grid every [constant GROUND_STEP] metres over the lands
##   and the core. Each corner is put at the lowest ground within a step of it,
##   and [constant SINK] lower again, so the occluder is everywhere *under* the
##   drawn ground: across a valley narrower than a step it lies below the
##   valley's floor, never across its top, and nothing standing on the ground
##   is ever hidden by the ground it stands on.
## * **The buildings.** The big solid boxes of the lands' places (walls,
##   towers, houses: [member LandsPlaces.occluder_boxes]) as they are, and each
##   kit building ([Building]) as a box inside its own outline, so its eaves
##   and porch never hide what is beside it.
##
## Needs `rendering/occlusion_culling/use_occlusion_culling`, which is on.

## The ground occluder's grid, metres.
const GROUND_STEP := 8.0
## How far under the lowest ground near it each corner of the grid is put.
const SINK := 3.0
## The share of a kit building's outline its box takes, across and up.
const BUILDING_SHRINK := Vector3(0.6, 0.75, 0.6)

static var last_counts: Dictionary = {}


static func build(world: Node3D) -> Dictionary:
	last_counts = {}
	if not bool(ProjectSettings.get_setting("rendering/occlusion_culling/use_occlusion_culling", false)):
		return last_counts
	var started := Time.get_ticks_usec()
	var holder := Node3D.new()
	holder.name = "Occluders"
	world.add_child(holder)
	var ground := _ground(holder)
	var boxes := _boxes(world, holder)
	last_counts = {"ground_triangles": ground, "boxes": boxes}
	print("Occluders: %s, in %.1f ms" % [last_counts, (Time.get_ticks_usec() - started) / 1000.0])
	return last_counts


## The ground as one grid. Returns its triangle count.
static func _ground(holder: Node3D) -> int:
	var x0 := -120.0
	var z0 := -455.0
	var x1 := 120.0
	var z1 := 180.0
	var lands := Lands.current
	if lands != null and is_instance_valid(lands) and lands.nx > 0:
		x0 = lands.x0
		z0 = lands.z0
		x1 = lands.x0 + lands.nx
		z1 = lands.z0 + lands.nz
	# Heights on a grid at half the step, then each corner of the occluder the
	# lowest of them within a step of it.
	var half := GROUND_STEP * 0.5
	var hx := int(ceilf((x1 - x0) / half)) + 1
	var hz := int(ceilf((z1 - z0) / half)) + 1
	var h := PackedFloat32Array()
	h.resize(hx * hz)
	for j in hz:
		for i in hx:
			h[j * hx + i] = Terrain.height(x0 + i * half, z0 + j * half)
	var gx := int(ceilf((x1 - x0) / GROUND_STEP)) + 1
	var gz := int(ceilf((z1 - z0) / GROUND_STEP)) + 1
	var verts := PackedVector3Array()
	verts.resize(gx * gz)
	for j in gz:
		for i in gx:
			var ci := i * 2
			var cj := j * 2
			var low := INF
			for dj in range(-2, 3):
				for di in range(-2, 3):
					var a := clampi(ci + di, 0, hx - 1)
					var b := clampi(cj + dj, 0, hz - 1)
					low = minf(low, h[b * hx + a])
			verts[j * gx + i] = Vector3(x0 + i * GROUND_STEP, low - SINK, z0 + j * GROUND_STEP)
	var idx := PackedInt32Array()
	for j in gz - 1:
		for i in gx - 1:
			var a := j * gx + i
			var b := a + 1
			var c := a + gx
			var d := c + 1
			idx.append_array([a, c, b, b, c, d])
	var occ := ArrayOccluder3D.new()
	occ.set_arrays(verts, idx)
	var inst := OccluderInstance3D.new()
	inst.name = "Ground"
	inst.occluder = occ
	holder.add_child(inst)
	return idx.size() / 3


## The buildings' boxes, all in one occluder. Returns how many.
static func _boxes(world: Node3D, holder: Node3D) -> int:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var count := 0
	var places := world.get_node_or_null("LandsPlaces") as LandsPlaces
	if places != null:
		for entry: Array in places.occluder_boxes:
			_add_box(verts, idx, places.global_transform * (entry[0] as Transform3D), entry[1] as Vector3)
			count += 1
	# the v5 town's walls and houses ([V5Town])
	var town := world.get_node_or_null("V5Town")
	if town != null:
		for entry: Array in town.get("occluder_boxes"):
			_add_box(verts, idx, entry[0] as Transform3D, entry[1] as Vector3)
			count += 1
	for node in world.find_children("*", "Building", true, false):
		var building := node as Node3D
		var outline := AABB()
		var first := true
		for child in building.find_children("*", "MeshInstance3D", true, false):
			var mi := child as MeshInstance3D
			var box := mi.global_transform * mi.get_aabb()
			outline = box if first else outline.merge(box)
			first = false
		if first or outline.size.y < 2.0:
			continue
		var size := outline.size * BUILDING_SHRINK
		var centre := outline.get_center()
		centre.y = outline.position.y + size.y * 0.5
		_add_box(verts, idx, Transform3D(Basis.IDENTITY, centre), size)
		count += 1
	if count == 0:
		return 0
	var occ := ArrayOccluder3D.new()
	occ.set_arrays(verts, idx)
	var inst := OccluderInstance3D.new()
	inst.name = "Buildings"
	inst.occluder = occ
	holder.add_child(inst)
	return count


static func _add_box(verts: PackedVector3Array, idx: PackedInt32Array, at: Transform3D, size: Vector3) -> void:
	var base := verts.size()
	var e := size * 0.5
	for k in 8:
		var corner := Vector3(e.x if k & 1 else -e.x, e.y if k & 2 else -e.y, e.z if k & 4 else -e.z)
		verts.append(at * corner)
	# Twelve triangles, the six faces of the box.
	for face: Array in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		idx.append_array([base + int(face[0]), base + int(face[1]), base + int(face[2]),
				base + int(face[0]), base + int(face[2]), base + int(face[3])])
