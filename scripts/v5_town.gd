class_name V5Town
extends Node3D

## The v5 world's town (stage 2 of the project's world_v5_plan): the walled town
## round the palace's hill at (-150, 0).
##
## Every model is one of `assets/town/town_kit.glb`'s (built in Blender from
## Quaternius' Medieval Village and Fantasy Props MegaKits by
## `vepxis-art/map/v5/town.py`), and where each stands is
## `assets/world/v5/town.json` (`town_layout.py`): the wall — sixteen towers,
## the lengths between them, four gatehouses on the cardinal roads —, some two
## hundred houses in four rings facing their streets, two markets, and the
## palace: eight round towers and their wall on the hilltop, the inner gate,
## the keep, its tower and two wings, a fountain in the court. The gardens on
## the hill's slope get their cypresses, the square a fire to come back to.
##
## Drawing: one [MultiMeshInstance3D] per model and per eighth of the town
## (the palace one more), so two hundred houses are a few dozen draws and a far
## eighth can drop to its meshes' coarser levels on its own. Colliding: the
## kit's boxes for each (one round a house, the wall's lengths, the gatehouses'
## blocks either side of their passages), in one body.

const KIT := "res://assets/town/town_kit.glb"
const KIT_INFO := "res://assets/town/town_kit.json"
const LAYOUT := "res://assets/world/v5/town.json"
const F := "res://assets/forest/"
const ROCKS: PackedStringArray = [F + "Rock_1.obj", F + "Rock_3.obj", F + "Rock_5.obj", F + "Rock_7.obj"]

## How far the town is drawn (m).
@export var reach: float = 1100.0
## Into how many slices round the middle the town's draws are cut.
@export var sectors: int = 8

var layout: Dictionary = {}
var info: Dictionary = {}
var counts: Dictionary = {}
## What hides what behind it ([Occluders]): [Transform3D, size] of the wall's
## lengths, towers and gates and of the houses, a little inside their boxes.
var occluder_boxes: Array = []
var _meshes: Dictionary = {}
var _body: StaticBody3D


func _ready() -> void:
	var started := Time.get_ticks_usec()
	layout = _json(LAYOUT)
	info = _json(KIT_INFO)
	if layout.is_empty() or info.is_empty():
		push_warning("V5Town: no layout or kit info.")
		return
	_load_kit()
	_body = StaticBody3D.new()
	_body.name = "TownBody"
	_body.collision_layer = 1
	_body.collision_mask = 0
	_body.set_meta(&"matter", &"stone")
	add_child(_body)
	_place_pieces()
	_plant_gardens()
	_build_fountain()
	_build_bonfire()
	counts["ms"] = snappedf((Time.get_ticks_usec() - started) / 1000.0, 0.1)
	print("V5Town: %s" % counts)


static func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _load_kit() -> void:
	var scene := load(KIT) as PackedScene
	if scene == null:
		push_warning("V5Town: no %s" % KIT)
		return
	var models := scene.instantiate()
	for node in models.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		_meshes[StringName(String(mi.name))] = mi.mesh
	models.free()


## The ground a model stands on: the lowest under its corners and middle, a hand
## lower, so nothing shows daylight under a wall on the town's gentle roll.
func _ground_under(xf: Transform3D, w: float, d: float) -> float:
	var low := INF
	for c: Vector3 in [Vector3.ZERO, Vector3(-w, 0, -d), Vector3(w, 0, -d), Vector3(w, 0, d), Vector3(-w, 0, d)]:
		var p := xf * c
		low = minf(low, Terrain.height(p.x, p.z))
	return low - 0.06


func _place_pieces() -> void:
	var centre := Vector2(float(layout["centre"][0]), float(layout["centre"][1]))
	var groups: Dictionary = {}          # "model|sector" -> Array[Transform3D]
	var n := 0
	for p: Array in layout["pieces"]:
		var model := String(p[0])
		var data: Dictionary = info.get(model, {})
		if data.is_empty() or not _meshes.has(StringName(model)):
			continue
		var at := Vector2(float(p[1]), float(p[2]))
		var stretch := float(p[4])
		var basis := Basis(Vector3.UP, deg_to_rad(float(p[3]))) * Basis.from_scale(Vector3(stretch, 1.0, 1.0))
		var xf := Transform3D(basis, Vector3(at.x, 0.0, at.y))
		var hw := float(data.get("W", 1.0)) * 0.5
		var hd := float(data.get("D", 1.0)) * 0.5
		xf.origin.y = _ground_under(xf, hw, hd)
		var group := String(p[5])
		var sector := 0
		if group != "palace":
			var a := fposmod((at - centre).angle(), TAU)
			sector = int(a / TAU * sectors) % sectors
		var key := "%s|%s|%d" % [model, group, sector]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(xf)
		_collide(model, data, xf, group)
		n += 1
		counts[group] = int(counts.get(group, 0)) + 1
	for key: String in groups:
		var model := key.get_slice("|", 0)
		var list: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _meshes[StringName(model)]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = key.replace("|", "_")
		mmi.multimesh = mm
		mmi.visibility_range_end = reach if key.get_slice("|", 1) != "props" else 160.0
		mmi.visibility_range_end_margin = 20.0
		if key.get_slice("|", 1) == "props":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	counts["draw_groups"] = groups.size()


func _collide(model: String, data: Dictionary, xf: Transform3D, group: String) -> void:
	var boxes: Array = data.get("boxes", [])
	if boxes.is_empty():
		if group != "props":
			return
		# a prop: a box round its mesh, a little in
		var mesh := _meshes.get(StringName(model)) as Mesh
		if mesh == null:
			return
		var aabb := mesh.get_aabb()
		boxes = [{"c": [aabb.get_center().x, aabb.get_center().z], "y": aabb.get_center().y,
				"size": [aabb.size.x * 0.85, aabb.size.y, aabb.size.z * 0.85], "yaw": 0.0}]
	for b: Dictionary in boxes:
		var size: Array = b["size"]
		var c: Array = b["c"]
		var shape := CollisionShape3D.new()
		var slab := BoxShape3D.new()
		# the stretch is in xf's basis: the box is sized in the model's own metres and
		# scaled with it, so its size is set from the unscaled frame below
		var sx := xf.basis.get_scale().x
		slab.size = Vector3(float(size[0]) * sx, float(size[1]), float(size[2]))
		shape.shape = slab
		var local := Transform3D(Basis(Vector3.UP, deg_to_rad(float(b.get("yaw", 0.0)))),
				Vector3(float(c[0]), float(b["y"]), float(c[1])))
		var world := xf * local
		shape.transform = Transform3D(world.basis.orthonormalized(), world.origin)
		_body.add_child(shape)
		if group != "props" and slab.size.y >= 2.5 and minf(slab.size.x, slab.size.z) >= 1.5:
			occluder_boxes.append([shape.transform, slab.size * Vector3(0.9, 0.85, 0.9)])


#region Gardens, fountain, fire
func _plant_gardens() -> void:
	var by_kind: Dictionary = {}
	for t: Array in layout.get("trees", []):
		var kind := String(t[0])
		if not by_kind.has(kind):
			by_kind[kind] = []
		(by_kind[kind] as Array).append(t)
	var n := 0
	for kind: String in by_kind:
		var mesh := load(F + kind + ".obj") as Mesh
		if mesh == null:
			continue
		var list: Array = by_kind[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			var t: Array = list[i]
			var x := float(t[1])
			var z := float(t[2])
			var s := float(t[3])
			var basis := Basis(Vector3.UP, deg_to_rad(float(t[4]))).scaled(Vector3.ONE * s)
			mm.set_instance_transform(i, Transform3D(basis, Vector3(x, Terrain.height_under(x, z, 0.5) - 0.1, z)))
			if kind.begins_with("Tree"):
				var cs := CollisionShape3D.new()
				var shape := CylinderShape3D.new()
				shape.radius = 0.25 * s
				shape.height = 3.0
				cs.shape = shape
				cs.position = Vector3(x, Terrain.height(x, z) + 1.5, z)
				_body.add_child(cs)
			n += 1
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Garden_" + kind
		mmi.multimesh = mm
		mmi.visibility_range_end = 400.0
		add_child(mmi)
	counts["garden"] = n


## The stone the town is built of, off the wall's own mesh (the kit's uneven brick).
func _stone() -> Material:
	var wall := _meshes.get(&"CityWall8") as Mesh
	if wall != null:
		for s in wall.get_surface_count():
			var m := wall.surface_get_material(s)
			if m != null and m.resource_name.contains("UnevenBrick"):
				return m
	var plain := StandardMaterial3D.new()
	plain.albedo_color = Color(0.55, 0.52, 0.47)
	return plain


func _build_fountain() -> void:
	var f: Array = layout.get("fountain", [])
	if f.size() < 2:
		return
	var at := Vector3(float(f[0]), 0.0, float(f[1]))
	at.y = Terrain.height_under(at.x, at.z, 3.5)
	var stone := _stone()
	var rim := CylinderMesh.new()
	rim.top_radius = 3.4
	rim.bottom_radius = 3.6
	rim.height = 0.75
	rim.radial_segments = 24
	var basin := MeshInstance3D.new()
	basin.name = "FountainRim"
	basin.mesh = rim
	basin.material_override = stone
	basin.position = at + Vector3(0, 0.3, 0)
	add_child(basin)
	var water := CylinderMesh.new()
	water.top_radius = 3.1
	water.bottom_radius = 3.1
	water.height = 0.05
	water.radial_segments = 24
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.18, 0.36, 0.42, 0.82)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.08
	wm.metallic_specular = 0.7
	var surface := MeshInstance3D.new()
	surface.name = "FountainWater"
	surface.mesh = water
	surface.material_override = wm
	surface.position = at + Vector3(0, 0.66, 0)
	add_child(surface)
	for part: Array in [[0.7, 0.9, 1.6], [0.45, 0.55, 2.7], [1.3, 1.3, 0.12]]:
		var col := CylinderMesh.new()
		col.top_radius = part[0]
		col.bottom_radius = part[1]
		col.height = part[2]
		col.radial_segments = 16
		var mi := MeshInstance3D.new()
		mi.mesh = col
		mi.material_override = stone
		mi.position = at + Vector3(0, part[2] * 0.5 if part[2] > 1.0 else 2.2, 0)
		add_child(mi)
	# the jet: a little spray falling back into the bowl
	var spray := CPUParticles3D.new()
	spray.name = "Jet"
	spray.amount = 60
	spray.lifetime = 1.1
	spray.position = at + Vector3(0, 2.8, 0)
	spray.direction = Vector3.UP
	spray.spread = 18.0
	spray.initial_velocity_min = 2.0
	spray.initial_velocity_max = 2.6
	spray.gravity = Vector3(0, -6.0, 0)
	spray.scale_amount_min = 0.5
	spray.scale_amount_max = 0.9
	var drop := QuadMesh.new()
	drop.size = Vector2(0.12, 0.2)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.albedo_color = Color(0.85, 0.93, 1.0, 0.55)
	drop.material = dm
	spray.mesh = drop
	add_child(spray)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 3.6
	shape.height = 1.0
	cs.shape = shape
	cs.position = at + Vector3(0, 0.5, 0)
	_body.add_child(cs)


func _build_bonfire() -> void:
	var b: Array = layout.get("bonfire", [])
	if b.size() < 2:
		return
	var at := Vector3(float(b[0]), 0.0, float(b[1]))
	at.y = Terrain.height_under(at.x, at.z, 1.5)
	var fire := load(F + "Campfire_Star.obj") as Mesh
	if fire != null:
		var mi := MeshInstance3D.new()
		mi.name = "Bonfire"
		mi.mesh = fire
		mi.scale = Vector3.ONE * 1.6
		mi.position = at
		add_child(mi)
	for i in 10:
		var a := TAU * i / 10.0
		var rock := load(ROCKS[i % ROCKS.size()]) as Mesh
		if rock == null:
			continue
		var r := MeshInstance3D.new()
		r.mesh = rock
		r.scale = Vector3.ONE * 0.38
		r.rotation.y = a * 1.7
		r.position = at + Vector3(cos(a) * 1.5, -0.08, sin(a) * 1.5)
		add_child(r)
	var light := OmniLight3D.new()
	light.name = "BonfireLight"
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = 2.6
	light.omni_range = 11.0
	light.position = at + Vector3(0.0, 1.2, 0.0)
	add_child(light)
	var flames := CPUParticles3D.new()
	flames.name = "Flames"
	flames.amount = 26
	flames.lifetime = 0.9
	flames.position = at + Vector3(0.0, 0.35, 0.0)
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.45
	flames.direction = Vector3.UP
	flames.spread = 12.0
	flames.initial_velocity_min = 0.9
	flames.initial_velocity_max = 1.8
	flames.gravity = Vector3(0.0, 0.6, 0.0)
	flames.scale_amount_min = 0.3
	flames.scale_amount_max = 0.6
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.85)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.billboard_keep_scale = true
	fm.albedo_color = Color(1.0, 0.55, 0.2)
	fm.vertex_color_use_as_albedo = true
	quad.material = fm
	flames.mesh = quad
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.8, 0.4, 1.0))
	fade.set_color(1, Color(0.8, 0.2, 0.05, 0.0))
	flames.color_ramp = fade
	add_child(flames)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.2
	shape.height = 0.8
	cs.shape = shape
	cs.position = at + Vector3(0, 0.4, 0)
	_body.add_child(cs)
#endregion
