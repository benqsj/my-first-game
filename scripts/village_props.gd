class_name VillageProps
extends Node3D

## The village's life: market stalls on the cobbled square, a smithy and a
## training yard by the barracks, benches, barrels and baskets at the doors,
## bushes, flowers and stepping stones round the huts, tables in front of the
## town centre, a wagon and flour sacks at the windmill, banners at the gate.
## The models are Quaternius' Fantasy Props, Medieval Village and Stylized
## Nature MegaKits (CC0), cut down in `vepxis-art/village/village_props.blend`
## onto shared texture sheets at 1024 (assets/village/SOURCES.txt).
##
## Cheap to draw: every placed prop is baked, at load, into one mesh per
## material for each 48 m cell, so the whole village is some seventy meshes
## rather than 167 nodes. Only the big things cast a shadow ([SHADOWED]); the
## small are dropped beyond [SMALL_REACH], the rest beyond [MID_REACH].

const SCENE := "res://assets/village/village_props.glb"
## The square's cobbles (x, z, width, depth): round the spawn, between the
## stalls; grass keeps off it ([Meadows]).
const PLAZA := Rect2(45.0, 37.2, 36.0, 12.0)
const COBBLES := "res://assets/village/ground/cobble_%s.jpg"
const CELL := 48.0
## Beyond this the little things (buckets, pots, baskets) are not drawn.
const SMALL_REACH := 70.0
## Kinds too small to be worth a shadow or drawing from far off.
const SMALL := [&"Bucket_Wooden_1", &"Pot_1", &"Vase_2", &"FarmCrate_Apple",
		&"FarmCrate_Carrot", &"FarmCrate_Empty", &"Bag", &"Stool", &"Axe_Bronze",
		&"Pickaxe_Bronze", &"Shield_Wooden", &"Flower_3_Group", &"Flower_4_Group",
		&"Plant_1", &"Plant_7", &"Fern_1", &"RockPath_Round_Small_1",
		&"RockPath_Round_Small_2", &"RockPath_Round_Small_3"]
## The only kinds that cast a shadow: the big ones, whose shadow grounds them.
const SHADOWED := [&"Stall_Empty", &"Stall_Cart_Empty", &"Prop_Wagon", &"Table_Large",
		&"Workbench", &"Bush_Common", &"Bush_Common_Flowers", &"Barrel_Holder"]
## The rest, neither small nor shadowed, are dropped beyond this.
const MID_REACH := 110.0

## Kinds a man bumps into (a box round each, a little inside the model).
const SOLID := [&"Stall_Empty", &"Stall_Cart_Empty", &"Barrel", &"Barrel_Apples",
		&"Crate_Wooden", &"Table_Large", &"Workbench", &"WeaponStand", &"Dummy",
		&"Anvil_Log", &"Barrel_Holder", &"Cauldron", &"Prop_Wagon", &"Bench"]

## The huts' x, south row (doors to +z) and north row (doors to -z).
const HUTS_SOUTH := [39.0, 52.4, 65.8, 79.3]
const HUTS_NORTH := [45.7, 59.1, 72.6, 86.0]
const SOUTH_DOOR_Z := 30.6
const NORTH_DOOR_Z := 52.6

## [kind, x, z, yaw in degrees (the model's front is +z), height] — the
## square, the smithy, the town centre's tables, the windmill and the gate.
## Every model's front faces +z at yaw 0.
const PLACED := [
	# The market, north side of the square, stalls facing the street.
	[&"Stall_Empty", 50.5, 50.2, 180.0],
	[&"FarmCrate_Apple", 48.9, 49.0, 170.0],
	[&"FarmCrate_Carrot", 52.1, 49.1, 190.0],
	[&"Barrel_Apples", 49.2, 51.6, 0.0],
	[&"Stall_Cart_Empty", 66.2, 50.4, 180.0],
	[&"Bag", 64.0, 49.4, 20.0],
	[&"Bag", 64.6, 48.9, -40.0],
	[&"FarmCrate_Empty", 68.6, 49.2, 175.0],
	[&"FarmCrate_Empty", 68.6, 49.2, 175.0, 0.25],
	[&"Stall_Empty", 77.4, 50.2, 185.0],
	[&"Vase_2", 75.9, 49.1, 0.0],
	[&"Pot_1", 78.9, 49.0, 30.0],
	[&"Barrel", 79.0, 51.6, 10.0],
	# South side of the square.
	[&"Stall_Empty", 58.8, 35.8, 0.0],
	[&"FarmCrate_Carrot", 57.2, 37.0, -10.0],
	[&"Barrel_Apples", 60.6, 36.9, 0.0],
	[&"Bag", 56.6, 35.0, 60.0],
	[&"Crate_Wooden", 61.0, 34.6, 15.0],
	[&"Table_Large", 72.4, 35.6, 0.0],
	[&"Stool", 71.4, 34.6, 0.0],
	[&"Stool", 73.4, 34.5, 20.0],
	[&"Bucket_Wooden_1", 74.5, 36.6, 0.0],
	# The smithy and the training yard in front of the barracks.
	[&"Anvil_Log", 93.2, 34.2, -20.0],
	[&"WeaponStand", 97.4, 33.4, 0.0],
	[&"Workbench", 101.0, 33.2, -10.0],
	[&"Cauldron", 99.3, 35.8, 0.0],
	[&"Barrel", 88.6, 33.2, 0.0],
	[&"Pickaxe_Bronze", 102.6, 34.1, 80.0],
	[&"Dummy", 86.0, 36.6, 20.0],
	[&"Dummy", 83.4, 37.2, -15.0],
	# Tables in front of the town centre.
	[&"Table_Large", 93.4, 51.4, 90.0],
	[&"Stool", 92.3, 50.4, 0.0],
	[&"Stool", 92.3, 52.4, 40.0],
	[&"Stool", 94.5, 50.4, 10.0],
	[&"Stool", 94.5, 52.4, -30.0],
	[&"Barrel_Holder", 97.2, 55.4, 180.0],
	[&"Barrel", 95.6, 56.2, 0.0],
	# The windmill: a wagon and the flour.
	[&"Prop_Wagon", 95.8, 66.0, 35.0],
	[&"Bag", 99.0, 67.6, 0.0],
	[&"Bag", 99.8, 67.0, 70.0],
	[&"Bag", 99.4, 68.6, -50.0],
	[&"Crate_Wooden", 97.8, 69.4, 10.0],
	# By the gate: a wagon come in on the track, crates off it.
	[&"Prop_Wagon", 38.0, 50.6, 100.0],
	[&"Crate_Wooden", 40.8, 52.4, 5.0],
	[&"FarmCrate_Empty", 36.2, 52.6, 30.0],
	# Banners on the gate towers, over the way in.
	[&"Banner_1", 30.0, 27.6, -90.0, 4.2],
	[&"Banner_2", 30.0, 56.4, 90.0, 4.2],
]

## Green round each hut (dx off the door, dz out from the wall, yaw): bushes at
## the corners, flowers by the door, stepping stones out to the street.
const GREEN := [
	[&"Bush_Common", -5.6, -1.6, 0.0], [&"Bush_Common_Flowers", 5.4, -1.2, 60.0],
	[&"Flower_3_Group", -1.2, 0.1, 0.0], [&"Flower_4_Group", 1.2, 0.2, 90.0],
	[&"RockPath_Round_Small_1", 0.0, 1.0, 0.0], [&"RockPath_Round_Small_2", 0.3, 2.4, 40.0],
	[&"RockPath_Round_Small_3", -0.2, 3.8, 80.0], [&"RockPath_Round_Small_1", 0.2, 5.2, 130.0],
	[&"Plant_7", -4.4, 0.4, 20.0], [&"Fern_1", 4.6, -0.6, 0.0],
]
## Green elsewhere: along the town centre's front, the gate, the fence corners.
const GREENERY := [
	[&"Bush_Common_Flowers", 97.0, 39.5, 0.0], [&"Flower_4_Group", 97.4, 42.0, 30.0],
	[&"Flower_3_Group", 97.2, 47.6, 0.0], [&"Bush_Common", 97.0, 50.0, 80.0],
	[&"Bush_Common", 33.6, 33.8, 0.0], [&"Flower_3_Group", 33.8, 36.0, 40.0],
	[&"Bush_Common_Flowers", 33.4, 55.2, 10.0], [&"Flower_4_Group", 33.6, 53.0, 0.0],
	[&"Fern_1", 22.5, 9.0, 0.0], [&"Bush_Common", 113.0, 9.0, 30.0],
	[&"Fern_1", 113.0, 75.0, 60.0], [&"Bush_Common", 22.8, 75.4, 0.0],
	[&"Plant_1", 88.0, 62.5, 0.0], [&"Plant_1", 52.0, 64.5, 50.0],
	[&"Bush_Common_Flowers", 45.0, 19.0, 0.0], [&"Plant_1", 70.0, 20.0, 0.0],
]

## What stands at each hut's door (dx off the door, dz out from the wall, yaw).
const AT_DOOR := [
	[[&"Bench", 3.0, 0.0, 0.0], [&"Barrel", -3.1, 0.1, 0.0], [&"Bucket_Wooden_1", -2.3, 0.6, 0.0]],
	[[&"Crate_Wooden", -3.2, 0.1, 10.0], [&"FarmCrate_Empty", -3.0, 0.1, 0.0, 0.93], [&"Pot_1", 2.6, 0.4, 0.0]],
	[[&"Bench", -3.0, 0.0, 0.0], [&"Vase_2", 2.7, 0.3, 0.0], [&"Barrel", 3.4, -0.2, 0.0]],
	[[&"Barrel", 3.0, 0.0, 0.0], [&"Barrel", 3.7, 0.6, 0.0], [&"Bag", -2.8, 0.3, 30.0]],
]


## Off for a measure of what the props cost (perf probes).
static var enabled := true


static func dress(parent: Node3D) -> VillageProps:
	if not enabled:
		return null
	var props := VillageProps.new()
	props.name = "Props"
	parent.add_child(props)
	props.build()
	props.lay_plaza()
	return props


## Whether a point (x, z) is on the square's cobbles.
static func in_plaza(at: Vector2, margin: float = 0.0) -> bool:
	return PLAZA.grow(margin).has_point(at)


func lay_plaza() -> void:
	var sheet := PlaneMesh.new()
	sheet.size = PLAZA.size
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/village_plaza.gdshader")
	mat.set_shader_parameter(&"albedo_tex", load(COBBLES % "diff"))
	mat.set_shader_parameter(&"normal_tex", load(COBBLES % "nor"))
	mat.set_shader_parameter(&"rough_tex", load(COBBLES % "rough"))
	mat.set_shader_parameter(&"half_size", PLAZA.size * 0.5)
	mat.set_shader_parameter(&"tint", Color(0.74, 0.7, 0.64))
	sheet.material = mat
	var node := MeshInstance3D.new()
	node.name = "Plaza"
	node.mesh = sheet
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mid := PLAZA.get_center()
	node.position = Vector3(mid.x, Terrain.height(mid.x, mid.y) + 0.05, mid.y)
	add_child(node)


## Every placement as [kind, Transform3D].
static func placements() -> Array:
	var out: Array = []
	for p: Array in PLACED:
		out.append([p[0], _at(p[1], p[2], p[3], p[4] if p.size() > 4 else 0.0)])
	for p: Array in GREENERY:
		out.append([p[0], _at(p[1], p[2], p[3], 0.0)])
	for x: float in HUTS_SOUTH:
		for d: Array in GREEN:
			out.append([d[0], _at(x + d[1], SOUTH_DOOR_Z + d[2], d[3], 0.0)])
	for x: float in HUTS_NORTH:
		for d: Array in GREEN:
			out.append([d[0], _at(x - d[1], NORTH_DOOR_Z - d[2], d[3] + 180.0, 0.0)])
	for i in HUTS_SOUTH.size():
		for d: Array in AT_DOOR[i]:
			out.append([d[0], _at(HUTS_SOUTH[i] + d[1], SOUTH_DOOR_Z + d[2], d[3], d[4] if d.size() > 4 else 0.0)])
	for i in HUTS_NORTH.size():
		# The north row mirrored: doors face -z.
		for d: Array in AT_DOOR[(i + 2) % AT_DOOR.size()]:
			out.append([d[0], _at(HUTS_NORTH[i] - d[1], NORTH_DOOR_Z - d[2], d[3] + 180.0, d[4] if d.size() > 4 else 0.0)])
	return out


static func _at(x: float, z: float, yaw_deg: float, up: float) -> Transform3D:
	var y := Terrain.height(x, z) + up
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), Vector3(x, y, z))


func build() -> void:
	var started := Time.get_ticks_usec()
	var count := 0
	var scene := load(SCENE) as PackedScene
	if scene == null:
		return
	var models := scene.instantiate()
	var meshes := {}
	for node in models.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		meshes[StringName(mi.name)] = mi.mesh
	models.free()
	var tuned := {}
	# (cell, material, size class) -> SurfaceTool
	var tools := {}
	var body := StaticBody3D.new()
	body.name = "PropsBody"
	body.collision_layer = 1
	add_child(body)
	for p: Array in placements():
		var kind: StringName = p[0]
		var xf: Transform3D = p[1]
		var mesh := meshes.get(kind) as Mesh
		if mesh == null:
			push_warning("VillageProps: no model %s" % kind)
			continue
		count += 1
		var size := 0 if SMALL.has(kind) else (2 if SHADOWED.has(kind) else 1)
		var cell := Vector2i(floori(xf.origin.x / CELL), floori(xf.origin.z / CELL))
		for s in mesh.get_surface_count():
			var mat := _tuned(mesh.surface_get_material(s), tuned)
			var key := [cell, mat, size]
			var st := tools.get(key) as SurfaceTool
			if st == null:
				st = SurfaceTool.new()
				tools[key] = st
			st.append_from(mesh, s, xf)
		if SOLID.has(kind):
			var box := mesh.get_aabb()
			var shape := CollisionShape3D.new()
			var slab := BoxShape3D.new()
			slab.size = Vector3(box.size.x * 0.85, box.size.y, box.size.z * 0.85)
			shape.shape = slab
			shape.transform = xf * Transform3D(Basis.IDENTITY, box.get_center())
			body.add_child(shape)
	var tris := 0
	for key: Array in tools:
		var st: SurfaceTool = tools[key]
		var merged := st.commit()
		var corners := merged.surface_get_array_index_len(0)
		tris += floori((corners if corners > 0 else merged.surface_get_array_len(0)) / 3.0)
		merged.surface_set_material(0, key[1])
		var node := MeshInstance3D.new()
		node.mesh = merged
		# 0 small, 1 middling, 2 big and shadowed.
		if key[2] < 2:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.visibility_range_end = SMALL_REACH if key[2] == 0 else MID_REACH
			node.visibility_range_end_margin = 8.0
		add_child(node)
	print("VillageProps: %d props in %d meshes, %d triangles, in %.0f ms" % [count,
			tools.size(), tris, (Time.get_ticks_usec() - started) / 1000.0])


## The kits' materials made to sit with the village's own colours: the bushes'
## leaves a softer green, the path stones and the flowers' leaves toned down.
## Vertex colour is kept only where a kit meant it (the banners' and stalls'
## cloth, the *_Vertex sheets): the importer turns it on for a material if any
## mesh using it has colours, which painted the others black.
static func _tuned(mat: Material, done: Dictionary) -> Material:
	if done.has(mat):
		return done[mat]
	var out := mat
	var std := mat as StandardMaterial3D
	if std != null:
		std = std.duplicate() as StandardMaterial3D
		var named := std.resource_name
		if not named.contains("Vertex") and named != "MI_Banner":
			std.vertex_color_use_as_albedo = false
		match named:
			"Leaves_NormalTree":
				std.albedo_color = Color(0.62, 0.76, 0.5)
			"Leaves":
				std.albedo_color = Color(0.78, 0.86, 0.7)
			"PathRocks":
				std.albedo_color = Color(0.6, 0.6, 0.56)
		out = std
	done[mat] = out
	return out
