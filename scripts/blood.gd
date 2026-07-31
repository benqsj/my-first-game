class_name Blood
extends Node

## Blood: the spray at the moment of the cut, what it leaves on the ground, and
## what stays on the blade.
##
## Everything here is built in code from plain meshes and unshaded materials.
## There is no texture to author and nothing to keep in sync with an art pass,
## which suits a greybox: the shapes are crude but the read — a burst, a stain
## spreading over whatever happens to be underfoot, a blade that darkens as it
## works — is the part that matters.

const SPRAY := Color(0.55, 0.03, 0.03)
const STAIN := Color(0.28, 0.02, 0.02)

## Radius over which the ground and anything standing on it gets marked.
const SPLATTER_RADIUS := 2.6
## Ground patches laid down per hit.
const PATCH_COUNT := 9
## Height above the ground the patches sit, to keep them out of the floor.
const PATCH_LIFT := 0.02


## The node new effects should be parented to.
##
## `current_scene` is the obvious answer but it is null whenever the scene was
## built by hand rather than loaded as the main scene — which is exactly what
## the test harness does — so fall back to the top of the tree.
static func world_of(node: Node) -> Node:
	var tree := node.get_tree()
	if tree == null:
		return null
	if tree.current_scene != null:
		return tree.current_scene
	var top := node
	while top.get_parent() != null and top.get_parent() != tree.root:
		top = top.get_parent()
	return top


## Sprays from `point`, roughly along `direction`, and marks the surroundings.
static func splatter(world: Node, point: Vector3, direction: Vector3) -> void:
	if world == null or not world.is_inside_tree():
		return
	_spray(world, point, direction)
	_stain_ground(world, point)
	_stain_nearby(world, point)


## A short-lived burst of droplets thrown out along the blow.
static func _spray(world: Node, point: Vector3, direction: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 24
	particles.lifetime = 0.7
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true

	var shape := SphereMesh.new()
	shape.radius = 0.035
	shape.height = 0.07
	shape.radial_segments = 6
	shape.rings = 3
	particles.draw_pass_1 = shape

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = SPRAY
	particles.material_override = material

	var behaviour := ParticleProcessMaterial.new()
	behaviour.direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.UP
	behaviour.spread = 55.0
	behaviour.initial_velocity_min = 2.0
	behaviour.initial_velocity_max = 5.5
	behaviour.gravity = Vector3(0.0, -9.0, 0.0)
	behaviour.scale_min = 0.5
	behaviour.scale_max = 1.4
	particles.process_material = behaviour

	world.add_child(particles)
	particles.global_position = point
	_free_after(particles, 1.6)


## A soft, ragged blob used for every ground splat.
##
## Built once as an image rather than shipped as a texture: the alpha is a
## radial falloff whose edge wanders in and out around the circle, which is what
## stops a pool reading as the quad it is actually drawn on.
static var _splat: ImageTexture

static func splat_texture() -> ImageTexture:
	if _splat != null:
		return _splat

	const SIZE := 128
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210

	# Radius of the blob at evenly spaced angles, interpolated between.
	var lobes := PackedFloat32Array()
	for i in 20:
		lobes.append(rng.randf_range(0.55, 0.95))

	for y in SIZE:
		for x in SIZE:
			var u := (x + 0.5) / float(SIZE) * 2.0 - 1.0
			var v := (y + 0.5) / float(SIZE) * 2.0 - 1.0
			var radius := sqrt(u * u + v * v)
			var around := (atan2(v, u) + PI) / TAU * lobes.size()
			var first := int(floor(around)) % lobes.size()
			var edge := lerpf(lobes[first], lobes[(first + 1) % lobes.size()], around - floor(around))
			var alpha := clampf((edge - radius) / 0.2, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha * alpha))

	_splat = ImageTexture.create_from_image(image)
	return _splat


## Flat patches scattered on the ground under the blow.
static func _stain_ground(world: Node, point: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(point * 100.0))

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(STAIN.r, STAIN.g, STAIN.b, 0.9)
	material.albedo_texture = splat_texture()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	for i in PATCH_COUNT:
		var patch := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var size := rng.randf_range(0.4, 1.5)
		# Squashed a little and spun below, so no two pools share an outline.
		quad.size = Vector2(size, size * rng.randf_range(0.7, 1.0))
		patch.mesh = quad
		patch.material_override = material
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(patch)

		var offset := Vector3(rng.randfn(0.0, SPLATTER_RADIUS * 0.4), 0.0,
				rng.randfn(0.0, SPLATTER_RADIUS * 0.4))
		patch.global_position = Vector3(point.x + offset.x, PATCH_LIFT, point.z + offset.z)
		# Lay it flat, then spin it so repeated hits do not tile.
		patch.rotation = Vector3(-PI * 0.5, rng.randf() * TAU, 0.0)


## Tints whatever is standing in the splatter — grass, stones, props.
##
## An overlay material is used rather than replacing the surface: the object
## keeps its own texture and simply reads as wet, and nothing has to be put back
## afterwards.
static func _stain_nearby(world: Node, point: Vector3) -> void:
	var overlay := StandardMaterial3D.new()
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Color(STAIN.r, STAIN.g, STAIN.b, 0.5)
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var scatter := world.get_node_or_null("Level/Scatter")
	if scatter == null:
		return
	for child in scatter.get_children():
		var node := child as Node3D
		if node == null or node.global_position.distance_to(point) > SPLATTER_RADIUS:
			continue
		for m in node.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_overlay = overlay


## Darkens a blade as it is used. `amount` climbs from 0 to 1 over several cuts.
static func stain_blade(blade: Node, amount: float) -> void:
	if blade == null:
		return
	var overlay := StandardMaterial3D.new()
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Color(STAIN.r, STAIN.g, STAIN.b, clampf(amount, 0.0, 1.0) * 0.7)
	overlay.roughness = 0.35
	for m in blade.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_overlay = overlay


static func _free_after(node: Node, seconds: float) -> void:
	var timer := node.get_tree().create_timer(seconds)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free())
