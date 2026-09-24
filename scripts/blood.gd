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
## Most ground patches alive at once. Past this the oldest is picked up and
## laid down again under the new blow, so a long fight costs the same number of
## draws as a short one instead of growing without end.
const MAX_PATCHES := 144
## Physics layer the ground is on ("world" in the project settings).
const GROUND_MASK := 1

## Shared by every splatter. A new material per hit meant a new draw per patch
## that could never be batched with the others.
static var _stain_material: StandardMaterial3D
static var _overlay_material: StandardMaterial3D
static var _spray_mesh: SphereMesh
static var _spray_material: StandardMaterial3D
static var _patch_mesh: QuadMesh
## Every ground patch laid so far, oldest first, up to `MAX_PATCHES`.
static var _patches: Array[MeshInstance3D] = []


## Builds, ahead of time, what a blow would otherwise build in the middle of a
## fight, and lays the spray emitters out in `world`.
##
## Measured at the orc camp, a blow that drew blood cost the physics step it
## landed in 10 to 25 ms — every blow, not only the first. Nearly all of it was
## the spray: a new [GPUParticles3D] and a new [ParticleProcessMaterial] per
## hit. The emitters are now a small ring kept in the level and restarted (see
## [method _spray]), and they, the splat image (worked out a pixel at a time in
## script) and the shared materials are all made here, while the level loads.
static func prewarm(world: Node = null) -> void:
	splat_texture()
	_spray_assets()
	if world != null and world.is_inside_tree():
		while _live_sprays() < SPRAY_POOL:
			_add_spray(world)


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
##
## Taken from a ring of `SPRAY_POOL` emitters that live in the level and are
## restarted, oldest first. They share one process material that throws along
## the emitter's own -Z, so the emitter is turned to face the blow instead of
## being given a material of its own: the process material moves the droplets'
## start and velocity by the emitter's transform, and gravity stays world-down.
static func _spray(world: Node, point: Vector3, direction: Vector3) -> void:
	var particles := _take_spray(world)
	if particles == null:
		return
	var along := direction.normalized() if direction.length_squared() > 0.001 else Vector3.UP
	var up := Vector3.UP if absf(along.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	particles.global_transform = Transform3D(Basis.looking_at(along, up), point)
	particles.restart()


## Six is more blows than land inside one spray's 0.7 s, so a spray is almost
## never cut short by being reused.
const SPRAY_POOL := 6

static var _spray_process: ParticleProcessMaterial
static var _sprays: Array[GPUParticles3D] = []
static var _next_spray: int = 0


static func _spray_assets() -> void:
	if _spray_mesh == null:
		_spray_mesh = SphereMesh.new()
		_spray_mesh.radius = 0.035
		_spray_mesh.height = 0.07
		_spray_mesh.radial_segments = 6
		_spray_mesh.rings = 3
		_spray_material = StandardMaterial3D.new()
		_spray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spray_material.albedo_color = SPRAY
	if _spray_process == null:
		_spray_process = ParticleProcessMaterial.new()
		_spray_process.direction = Vector3.FORWARD
		_spray_process.spread = 55.0
		_spray_process.initial_velocity_min = 2.0
		_spray_process.initial_velocity_max = 5.5
		_spray_process.gravity = Vector3(0.0, -9.0, 0.0)
		_spray_process.scale_min = 0.5
		_spray_process.scale_max = 1.4


## How many emitters are still in a level. Ones that went with an old level are
## dropped from the ring.
static func _live_sprays() -> int:
	for i in range(_sprays.size() - 1, -1, -1):
		if not is_instance_valid(_sprays[i]):
			_sprays.remove_at(i)
	return _sprays.size()


static func _add_spray(world: Node) -> GPUParticles3D:
	_spray_assets()
	var particles := GPUParticles3D.new()
	particles.name = "BloodSpray"
	particles.amount = 24
	particles.lifetime = 0.7
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false
	particles.draw_pass_1 = _spray_mesh
	particles.material_override = _spray_material
	particles.process_material = _spray_process
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(particles)
	_sprays.append(particles)
	return particles


static func _take_spray(world: Node) -> GPUParticles3D:
	if _live_sprays() < SPRAY_POOL:
		return _add_spray(world)
	var particles := _sprays[_next_spray % _sprays.size()]
	_next_spray += 1
	if particles.get_parent() != world:
		particles.reparent(world, false)
	return particles


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

	if _stain_material == null:
		_stain_material = StandardMaterial3D.new()
		_stain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_stain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_stain_material.albedo_color = Color(STAIN.r, STAIN.g, STAIN.b, 0.9)
		_stain_material.albedo_texture = splat_texture()
		_stain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		# One unit quad for every patch; the size lives in the node's scale.
		_patch_mesh = QuadMesh.new()
		_patch_mesh.size = Vector2.ONE

	var space := _space_of(world)
	for i in PATCH_COUNT:
		var size := rng.randf_range(0.4, 1.5)
		# Squashed a little and spun below, so no two pools share an outline.
		var squash := rng.randf_range(0.7, 1.0)
		var offset := Vector3(rng.randfn(0.0, SPLATTER_RADIUS * 0.4), 0.0,
				rng.randfn(0.0, SPLATTER_RADIUS * 0.4))
		var spin := rng.randf() * TAU

		# Laid on whatever is actually under the spot — a stair, the ramp, a
		# rock — rather than at the height of the flat ground, which put blood
		# spilt on the steps underneath them.
		var at := Vector3(point.x + offset.x, 0.0, point.z + offset.z)
		var normal := Vector3.UP
		var ground := _ground_under(space, at, point.y)
		if ground.is_empty():
			at.y = PATCH_LIFT
		else:
			normal = ground["normal"]
			at = ground["position"] + normal * PATCH_LIFT

		# Lay it flat, spin it so repeated hits do not tile, then tip it onto
		# the slope it landed on.
		var basis := Basis(Quaternion(Vector3.UP, normal)) \
				* Basis(Vector3.UP, spin) * Basis(Vector3.RIGHT, -PI * 0.5) \
				* Basis.from_scale(Vector3(size, size * squash, 1.0))
		var patch := _take_patch(world)
		patch.global_transform = Transform3D(basis, at)


## A ground patch to lay down: a new one while there is room under
## `MAX_PATCHES`, otherwise the oldest one, moved.
static func _take_patch(world: Node) -> MeshInstance3D:
	# Patches go when their level does; drop the ones that went with it.
	while not _patches.is_empty() and not is_instance_valid(_patches[0]):
		_patches.pop_front()
	var patch: MeshInstance3D
	if _patches.size() >= MAX_PATCHES:
		patch = _patches.pop_front()
		if patch.get_parent() != world:
			patch.reparent(world, false)
	else:
		patch = MeshInstance3D.new()
		patch.mesh = _patch_mesh
		patch.material_override = _stain_material
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(patch)
	_patches.append(patch)
	return patch


static func _space_of(world: Node) -> PhysicsDirectSpaceState3D:
	var spatial := world as Node3D
	if spatial == null or spatial.get_world_3d() == null:
		return null
	return spatial.get_world_3d().direct_space_state


## The ground straight below `at`, searched from a little above the height of
## the blow down to well below it. Empty if there is nothing there.
static func _ground_under(space: PhysicsDirectSpaceState3D, at: Vector3, from_height: float) -> Dictionary:
	if space == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
			Vector3(at.x, from_height + 1.0, at.z),
			Vector3(at.x, from_height - 4.0, at.z), GROUND_MASK)
	return space.intersect_ray(query)


## Tints whatever is standing in the splatter — grass, stones, props.
##
## Two ways round, because the scatter holds two kinds of thing. The grass is
## drawn out of multimeshes and has no per-clump material to hang an overlay on,
## so the field is asked to darken the instances itself; a tint on the clump's
## own texture is what bloodied grass looks like anyway. Everything else in the
## scatter is still a node, and gets an overlay material — the object keeps its
## own texture and simply reads as wet, and nothing has to be put back after.
static func _stain_nearby(world: Node, point: Vector3) -> void:
	var scatter := world.get_node_or_null("Level/Scatter")
	if scatter == null:
		return

	var field := scatter as GrassField
	if field != null:
		field.stain(point, SPLATTER_RADIUS, STAIN, 0.65)

	if _overlay_material == null:
		_overlay_material = StandardMaterial3D.new()
		_overlay_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_overlay_material.albedo_color = Color(STAIN.r, STAIN.g, STAIN.b, 0.5)
		_overlay_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var overlay := _overlay_material
	for child in scatter.get_children():
		var node := child as Node3D
		# The field's own chunks are not props standing in the blood; they *are*
		# the grass, and they have already been tinted.
		if node == null or node is MultiMeshInstance3D:
			continue
		if node.global_position.distance_to(point) > SPLATTER_RADIUS:
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
