class_name Marsh
extends Node3D

## The ground the map grew by: a strip of marsh south of the old boundary, with
## a mere in it and the misty village standing on its island.
##
## The old level is one flat box, 240 m on a side, and that is still what it
## is — nothing north of the old south wall moves. What is added here is the
## strip beyond it, and it cannot be another box, because a lake is a hole.
## So it is built the way the wood is: from a function and a handful of
## numbers, on every peer, with nothing written into the scene file.
##
## * **Ground.** One grid mesh over the whole strip, flat at the old ground's
##   height everywhere but the mere, and dished down into it. Flat at its edges
##   on purpose: the seam with the old box is a straight line at y = 0 and a
##   player walking across it should not be able to tell where it is.
## * **Collision.** A [HeightMapShape3D] sampled from the same function, so the
##   floor under the water is exactly the floor that is drawn. A heightmap is the
##   cheap way to collide with terrain — the engine knows it is a grid and looks
##   up the one cell under a capsule instead of searching a triangle soup.
## * **Water.** One plane at `water_level`, over the whole mere. The ground
##   outside the mere is above it, so the plane only shows where the ground dips
##   below the surface and the shoreline draws itself. Shallow enough to wade:
##   the bed is `bed_depth` under the old ground, a little over half a metre of
##   it under the water, so a player walks into the mere rather than into a
##   wall at its edge.
## * **Mist.** Soft upright cards standing low over the water and drifting, which is most
##   of what the picture the village was built from is about. Cards rather than
##   volumetric fog: fog is a setting for the whole world and a per-pixel cost
##   everywhere in it, and the mist is wanted in one place.
##
## The village itself is an instanced scene under this node (see
## `scenes/world/mist_village.tscn`); this only makes the ground it stands in.

@export_group("Extent")
## The strip's corners in the level's own frame, (x, z). The north edge meets
## the old ground's south edge.
@export var strip_min: Vector2 = Vector2(-120.0, -250.0)
@export var strip_max: Vector2 = Vector2(120.0, -120.0)
## Side of a ground cell, in metres. The heightmap is sampled on the same grid.
@export var cell: float = 2.0

@export_group("Mere")
## Middle of the mere, (x, z).
@export var mere_centre: Vector2 = Vector2(10.0, -188.0)
## Half its width along x and z. An ellipse, so it can be longer than it is wide.
@export var mere_radii: Vector2 = Vector2(44.0, 38.0)
## How far below the old ground the bed of the mere lies.
@export var bed_depth: float = 1.0
## Over how many metres the shore slopes from the old ground down to the bed.
@export var shore_width: float = 9.0
## Height of the water's surface.
@export var water_level: float = -0.35

@export_group("Look")
## The old ground's material. The strip draws with a copy of it, so the seam
## does not show; the copy is darkened towards the water with vertex colours.
@export var ground_material: Material
@export var mist_cards: int = 26
@export var mist_enabled: bool = true

var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.seed = 551277
	_noise.frequency = 0.05
	_build_ground()
	_build_water()
	if mist_enabled:
		_build_mist()


## Height of the ground at a point in the level's own frame. Zero everywhere but
## the mere, so the strip meets the old ground on a level line.
func height_at(x: float, z: float) -> float:
	var reach := _mere_reach(Vector2(x, z))
	if reach >= 1.0:
		return 0.0
	# How far in from the rim, in metres, measured along the shorter radius so
	# the slope is no steeper at the narrow ends than on the long sides.
	var inset := (1.0 - reach) * minf(mere_radii.x, mere_radii.y)
	var t := smoothstep(0.0, shore_width, inset)
	# A little unevenness on the bed, none at the rim.
	var lumps := _noise.get_noise_2d(x, z) * 0.18 * t
	return -bed_depth * t + lumps


## Whether a point is in the mere — under the water, or on its shore.
func in_mere(at: Vector2) -> bool:
	return _mere_reach(at) < 1.0


## 0 at the middle of the mere, 1 on its rim, more outside it.
func _mere_reach(at: Vector2) -> float:
	var d := (at - mere_centre) / mere_radii
	return d.length()


#region Ground
func _build_ground() -> void:
	var size := strip_max - strip_min
	var nx := int(ceil(size.x / cell)) + 1
	var nz := int(ceil(size.y / cell)) + 1

	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var x := strip_min.x + ix * cell
			var z := strip_min.y + iz * cell
			heights[iz * nx + ix] = height_at(x, z)

	# Drawn.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in nz:
		for ix in nx:
			var x := strip_min.x + ix * cell
			var z := strip_min.y + iz * cell
			var h := heights[iz * nx + ix]
			# Wet ground darkens towards the water, and the bed is mud.
			var wet := clampf(-h / maxf(bed_depth, 0.01), 0.0, 1.0)
			st.set_color(Color(1.0, 1.0, 1.0).lerp(Color(0.42, 0.4, 0.33), wet))
			# Same repeat as the old box, and the same phase at the seam: the box
			# runs its texture from x = -120, z = -120.
			st.set_uv(Vector2((x + 120.0) / 240.0, (z + 120.0) / 240.0))
			st.add_vertex(Vector3(x, h, z))
	for iz in nz - 1:
		for ix in nx - 1:
			var a := iz * nx + ix
			var b := a + 1
			var c := a + nx
			var d := c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	st.generate_tangents()

	var mesh := MeshInstance3D.new()
	mesh.name = "Ground"
	mesh.mesh = st.commit()
	if ground_material != null:
		var own := ground_material.duplicate() as BaseMaterial3D
		if own != null:
			own.vertex_color_use_as_albedo = true
			mesh.material_override = own
		else:
			mesh.material_override = ground_material
	add_child(mesh)

	# Collided. A heightmap is a grid one unit apart, so the shape is scaled up
	# by a cell — uniformly, which is what every physics engine supports — and
	# the heights are handed over in cells to match.
	var shape := HeightMapShape3D.new()
	shape.map_width = nx
	shape.map_depth = nz
	var scaled := PackedFloat32Array()
	scaled.resize(heights.size())
	for i in heights.size():
		scaled[i] = heights[i] / cell
	shape.map_data = scaled

	var body := StaticBody3D.new()
	body.name = "GroundBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var node := CollisionShape3D.new()
	node.shape = shape
	node.scale = Vector3.ONE * cell
	# A heightmap is centred on its node, and the grid may overrun `strip_max` by
	# part of a cell, so it is centred on what the grid covers.
	node.position.x = strip_min.x + (nx - 1) * cell * 0.5
	node.position.z = strip_min.y + (nz - 1) * cell * 0.5
	body.add_child(node)
	add_child(body)
#endregion


#region Water
func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = mere_radii * 2.0 + Vector2.ONE * 4.0
	plane.subdivide_width = 0
	plane.subdivide_depth = 0

	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.position = Vector3(mere_centre.x, water_level, mere_centre.y)
	water.material_override = load("res://assets/world/water.tres")
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
#endregion


#region Mist
func _build_mist() -> void:
	# Upright, and turned to face the camera by the shader: a card lying flat on
	# the water is a line from anywhere a player's eye can be.
	var quad := QuadMesh.new()
	quad.size = Vector2(26.0, 9.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = 77120
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = quad
	multi.instance_count = mist_cards
	for i in mist_cards:
		# Mostly over the water and its shore, a few layers deep.
		var angle := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 1.25
		var at := mere_centre + Vector2(cos(angle), sin(angle)) * mere_radii * r
		var size := rng.randf_range(0.7, 1.4)
		var y := water_level + 9.0 * 0.5 * size * 0.6 + rng.randf_range(-0.6, 1.8)
		var basis := Basis.IDENTITY.scaled(Vector3(size, size, size))
		multi.set_instance_transform(i, Transform3D(basis, Vector3(at.x, y, at.y)))
		multi.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))

	var node := MultiMeshInstance3D.new()
	node.name = "Mist"
	node.multimesh = multi
	node.material_override = load("res://assets/world/mist.tres")
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
#endregion
