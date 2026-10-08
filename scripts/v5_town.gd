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
		var group := String(p[5])
		# the nature's slot carries a uniform scale; the wall's a stretch along its length
		var scale := Vector3.ONE * stretch if group == "nature" else Vector3(stretch, 1.0, 1.0)
		var basis := Basis(Vector3.UP, deg_to_rad(float(p[3]))) * Basis.from_scale(scale)
		var xf := Transform3D(basis, Vector3(at.x, 0.0, at.y))
		var hw := float(data.get("W", 1.0)) * 0.5
		var hd := float(data.get("D", 1.0)) * 0.5
		if group == "nature":
			xf.origin.y = Terrain.height_under(at.x, at.y, 0.6) - 0.05
		else:
			xf.origin.y = _ground_under(xf, hw, hd)
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
		var grp := key.get_slice("|", 1)
		var tree := model.begins_with("Tree")
		mmi.visibility_range_end = reach
		if grp == "props":
			mmi.visibility_range_end = 160.0
		elif grp == "nature":
			mmi.visibility_range_end = 500.0 if tree else 110.0
		mmi.visibility_range_end_margin = 20.0
		if grp == "props" or (grp == "nature" and not tree):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	counts["draw_groups"] = groups.size()


func _collide(model: String, data: Dictionary, xf: Transform3D, group: String) -> void:
	if group == "nature":
		if model.begins_with("Tree"):
			var trunk := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			var s := xf.basis.get_scale().x
			cyl.radius = 0.32 * s
			cyl.height = 4.0
			trunk.shape = cyl
			trunk.position = xf.origin + Vector3(0, 2.0, 0)
			_body.add_child(trunk)
		return
	if group == "houses" or group == "palace":
		_house_extras(data, xf)
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


## A box in a house's own frame (centre, size, tilt about its x axis in radians).
func _box_in(xf: Transform3D, centre: Vector3, size: Vector3, tilt_x: float = 0.0, tilt_z: float = 0.0) -> void:
	var shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = size
	shape.shape = slab
	var local := Transform3D(Basis.from_euler(Vector3(tilt_x, 0.0, tilt_z)), centre)
	var world := xf * local
	shape.transform = Transform3D(world.basis.orthonormalized(), world.origin)
	_body.add_child(shape)


## What a house has besides its walls: the balcony's floor and rail, the outside
## stair up to it (a ramp under the steps), and the roof's two slopes, so a body
## stands on the stair and the balcony rather than walking through them, and
## does not stand on air over the walls' top inside the roof.
func _house_extras(data: Dictionary, xf: Transform3D) -> void:
	for b: Dictionary in data.get("balconies", []):
		var x := float(b["x"])
		var y := float(b["y"])
		var depth := float(b["depth"])
		var side := float(b["side"])
		_box_in(xf, Vector3(x, y - 0.1, 0.0), Vector3(2.0, 0.2, depth))
		# the rail along the outer edge, and across the ends (not the stair's)
		_box_in(xf, Vector3(x + side * 0.95, y + 0.55, 0.0), Vector3(0.12, 1.1, depth))
		var stair_end: Variant = b.get("stair_end")
		for e: float in [-depth * 0.5, depth * 0.5]:
			if stair_end != null and is_equal_approx(e, float(stair_end)):
				continue
			_box_in(xf, Vector3(x, y + 0.55, e), Vector3(2.0, 1.1, 0.12))
	var ramp: Dictionary = data.get("stair_ramp", {})
	if not ramp.is_empty():
		var z0 := float(ramp["z_foot"])
		var z1 := float(ramp["z_top"])
		var top := float(ramp["y_top"])
		var run := absf(z1 - z0)
		var length := sqrt(run * run + top * top)
		var angle := atan2(top, run)
		# the slab's top face is the slope from the foot (y 0) to the balcony (y top);
		# rising towards +z (z_top > z_foot) is a negative turn about x
		var mid := Vector3(float(ramp["x"]), top * 0.5, (z0 + z1) * 0.5)
		var thick := 0.3
		var down := Vector3(0.0, cos(angle), -sin(angle) * signf(z1 - z0)) * (thick * 0.5)
		_box_in(xf, mid - down, Vector3(float(ramp["width"]), thick, length), -angle * signf(z1 - z0))
	var roof: Dictionary = data.get("roof", {})
	if not roof.is_empty():
		var top := float(roof["top"])
		var rise := float(roof["rise"])
		var half := float(roof["half"])
		var depth := float(roof["depth"])
		var slope := sqrt(half * half + rise * rise)
		var angle := atan2(rise, half)
		for side: float in [-1.0, 1.0]:
			var centre := Vector3(side * half * 0.5, top + rise * 0.5 - 0.15, 0.0)
			_box_in(xf, centre, Vector3(slope, 0.3, depth), 0.0, side * -angle)


#region Gardens, fountain, fire
## A soft round spot, white at the middle fading to nothing at the edge: what
## the fire's and the smoke's particles are drawn with (a plain quad read as a
## square).
func _soft_dot() -> Texture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.45, Color(1, 1, 1, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	return tex


func _particles(nm: String, at: Vector3, tex: Texture2D, amount: int, life: float, radius: float,
		speed: Vector2, size: Vector2, c0: Color, c1: Color, glow: bool, spread_out: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = nm
	p.amount = amount
	p.lifetime = life
	p.position = at
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 14.0
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = Vector3(0.0, 0.4, 0.0)
	p.damping_min = spread_out
	p.damping_max = spread_out * 2.0
	p.scale_amount_min = size.x
	p.scale_amount_max = size.y
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 0.7))
	shrink.add_point(Vector2(0.3, 1.0))
	shrink.add_point(Vector2(1.0, 0.25 if glow else 1.6))
	p.scale_amount_curve = shrink
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.albedo_texture = tex
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	quad.material = m
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fade := Gradient.new()
	fade.set_color(0, c0)
	fade.set_color(1, c1)
	p.color_ramp = fade
	return p


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
	# The rim alone stops a body (a ring of short boxes); inside it the basin's
	# floor is the ground, so one who steps over wades in the water rather than
	# standing on top of it. The column in the middle is solid.
	for i in 18:
		var a := TAU * i / 18.0
		var seg := CollisionShape3D.new()
		var slab := BoxShape3D.new()
		slab.size = Vector3(1.32, 0.75, 0.42)
		seg.shape = slab
		seg.transform = Transform3D(Basis(Vector3.UP, -a + PI * 0.5), at + Vector3(cos(a) * 3.4, 0.38, sin(a) * 3.4))
		_body.add_child(seg)
	var column := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.85
	cyl.height = 2.8
	column.shape = cyl
	column.position = at + Vector3(0, 1.4, 0)
	_body.add_child(column)


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
	light.light_color = Color(1.0, 0.6, 0.28)
	light.light_energy = 2.8
	light.omni_range = 12.0
	light.position = at + Vector3(0.0, 1.3, 0.0)
	add_child(light)
	var flicker := FireFlicker.new()
	flicker.light = light
	add_child(flicker)
	var soft := _soft_dot()
	# the fire: a hot core low in the logs, tongues of orange above it, sparks and smoke
	add_child(_particles("FireCore", at + Vector3(0, 0.35, 0), soft, 36, 0.55, 0.3, Vector2(0.5, 1.1),
			Vector2(0.55, 0.85), Color(1.0, 0.92, 0.6, 1.0), Color(1.0, 0.55, 0.15, 0.0), true, 0.25))
	add_child(_particles("FireTongues", at + Vector3(0, 0.55, 0), soft, 30, 0.9, 0.45, Vector2(0.9, 1.7),
			Vector2(0.45, 0.8), Color(1.0, 0.6, 0.2, 0.9), Color(0.7, 0.12, 0.03, 0.0), true, 0.35))
	add_child(_particles("Sparks", at + Vector3(0, 0.8, 0), soft, 14, 1.8, 0.35, Vector2(1.6, 3.0),
			Vector2(0.04, 0.08), Color(1.0, 0.8, 0.4, 1.0), Color(1.0, 0.4, 0.1, 0.0), true, 0.4))
	add_child(_particles("Smoke", at + Vector3(0, 1.6, 0), soft, 16, 4.0, 0.3, Vector2(0.5, 0.9),
			Vector2(0.9, 2.2), Color(0.25, 0.24, 0.23, 0.35), Color(0.45, 0.45, 0.45, 0.0), false, 0.15))
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.2
	shape.height = 0.8
	cs.shape = shape
	cs.position = at + Vector3(0, 0.4, 0)
	_body.add_child(cs)
#endregion


## The bonfire's light breathing with the flames.
class FireFlicker extends Node:
	var light: OmniLight3D
	var _t := 0.0

	func _process(delta: float) -> void:
		if light == null:
			return
		_t += delta
		light.light_energy = 2.6 + sin(_t * 9.0) * 0.25 + sin(_t * 23.0 + 1.3) * 0.18 + sin(_t * 3.1) * 0.2
