class_name Blood
extends Node

## Blood: the spray at the moment of the cut, what it leaves on the ground, the
## wound it leaves on the body, and what stays on the blade.
##
## Everything here is built in code: the images are worked out a pixel at a time
## while the level loads (see [method prewarm]), the meshes are plain quads and
## capsules. The read is what matters — a spray thrown along the swing, drops
## that come down where the spray was going and splash there, a small pool
## under the wound, a cut left on the hide — and all of it wet, lit by the same
## light as everything else rather than painted on in flat red.

## Fresh blood, lit: dark and glossy, not the flat red of a cartoon.
const SPRAY := Color(0.36, 0.015, 0.015)
const STAIN := Color(0.24, 0.012, 0.01)
## The tint the grass and the props take.
const TINT := Color(0.28, 0.02, 0.02)

## Radius over which the grass and the props standing in the blood get tinted.
const SPLATTER_RADIUS := 1.4
## Height above the ground the stains sit, to keep them out of the floor.
const PATCH_LIFT := 0.015
## Most ground stains alive at once. Past this the oldest is picked up and laid
## down again under the new blow, so a long fight costs the same number of
## draws as a short one instead of growing without end.
const MAX_PATCHES := 160
## Physics layer the ground is on ("world" in the project settings).
const GROUND_MASK := 1
## How long what a blow leaves lies there before it fades (between these two,
## so a fight's blood does not all go at once), and how long the fade takes.
const LINGER_MIN := 30.0
const LINGER_MAX := 40.0
const FADE_TIME := 4.0

## The spray: how fast the drops leave the wound (m/s), and how far they fan out
## either side of the blow (degrees). What the ground stains are worked out from
## too, so the drops come down where the spray was seen to go.
const THROW_SPEED := Vector2(2.2, 6.2)
const THROW_SPREAD := 17.0
const GRAVITY := 9.8
## Drops that come down per blow (at `strength` 1).
const DROPS := 10

## The render layer a creature's meshes are put on so that a wound (a [Decal])
## marks the creature and nothing round it — not the grass it stands in.
const WOUND_LAYER := 1 << 18
## Most wounds on one creature at once; the oldest goes when there are more.
const MAX_WOUNDS := 7

static var _pool_material: StandardMaterial3D
static var _drop_material: StandardMaterial3D
static var _overlay_material: StandardMaterial3D
static var _patch_mesh: QuadMesh
## Every ground stain laid so far, oldest first, up to `MAX_PATCHES`.
static var _patches: Array[MeshInstance3D] = []


## Builds, ahead of time, what a blow would otherwise build in the middle of a
## fight, and lays the spray emitters out in `world`.
##
## Measured at the orc camp, a blow that drew blood cost the physics step it
## landed in 10 to 25 ms when each spray was a new [GPUParticles3D] with a new
## process material. The emitters are a small ring kept in the level and
## restarted (see [method _spray]); they, the images (worked out a pixel at a
## time in script) and the shared materials are all made here, while the level
## loads.
static func prewarm(world: Node = null) -> void:
	splat_texture()
	drop_texture()
	wound_texture()
	_spray_assets()
	_stain_assets()
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


## Sprays from `point` along `direction` — the way the blow was going — and
## marks the ground where it comes down. `on`: the creature it came out of,
## which takes a wound there. `strength`: 1 for a cut, more for a critical or a
## limb off, less for a scratch.
static func splatter(world: Node, point: Vector3, direction: Vector3, on: Node3D = null,
		strength: float = 1.0) -> void:
	if world == null or not world.is_inside_tree():
		return
	var along := direction.normalized() if direction.length_squared() > 0.0001 else Vector3.UP
	_spray(world, point, along, strength)
	_stain_ground(world, point, along, strength)
	_stain_nearby(world, point, along)
	if on != null:
		wound(on, point, along)


## How long this blow's blood stays, between `LINGER_MIN` and `LINGER_MAX`.
static func _linger() -> float:
	return randf_range(LINGER_MIN, LINGER_MAX)


#region The spray
## Six is more blows than land inside one spray's life, so a spray is almost
## never cut short by being reused.
const SPRAY_POOL := 6

static var _stream_process: ParticleProcessMaterial
static var _mist_process: ParticleProcessMaterial
static var _stream_mesh: CapsuleMesh
static var _stream_material: StandardMaterial3D
static var _mist_mesh: QuadMesh
static var _mist_material: StandardMaterial3D
## Each entry a pair: [the stream of drops, the mist].
static var _sprays: Array = []
static var _next_spray: int = 0


## A short spray thrown out along the blow: a stream of drops, each stretched
## along the way it flies so the arc reads as liquid rather than beads, falling
## as they go; and a puff of fine mist at the wound that hangs a moment.
##
## Taken from a ring of `SPRAY_POOL` emitter pairs that live in the level and
## are restarted, oldest first. They share process materials that throw along
## the emitter's own -Z, so the emitter is turned to face the blow instead of
## being given a material of its own.
static func _spray(world: Node, point: Vector3, along: Vector3, strength: float) -> void:
	var pair := _take_spray(world)
	if pair.is_empty():
		return
	# A little lift: blood thrown level by a blade still arcs up off the wound.
	var aim := (along + Vector3.UP * 0.22).normalized()
	var up := Vector3.UP if absf(aim.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var basis := Basis.looking_at(aim, up)
	for p: GPUParticles3D in pair:
		p.global_transform = Transform3D(basis, point)
		p.amount_ratio = clampf(0.55 + 0.35 * strength, 0.3, 1.0)
		p.restart()


static func _spray_assets() -> void:
	if _stream_mesh == null:
		# One drop: a thin capsule, turned by the particle system to lie along
		# the way it is flying.
		_stream_mesh = CapsuleMesh.new()
		_stream_mesh.radius = 0.02
		_stream_mesh.height = 0.17
		_stream_mesh.radial_segments = 5
		_stream_mesh.rings = 1
		_stream_material = StandardMaterial3D.new()
		_stream_material.albedo_color = SPRAY
		_stream_material.roughness = 0.12
		_stream_material.metallic_specular = 0.7
		# A touch of its own glow, so the spray still reads against the dark of
		# the wood and in shadow.
		_stream_material.emission_enabled = true
		_stream_material.emission = Color(0.22, 0.0, 0.0)
		_stream_material.emission_energy_multiplier = 0.6
	if _mist_mesh == null:
		_mist_mesh = QuadMesh.new()
		_mist_mesh.size = Vector2(0.24, 0.24)
		_mist_material = StandardMaterial3D.new()
		_mist_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mist_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mist_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_mist_material.vertex_color_use_as_albedo = true
		_mist_material.albedo_texture = splat_texture()
		_mist_material.albedo_color = Color(0.42, 0.02, 0.02)
		_mist_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if _stream_process == null:
		_stream_process = ParticleProcessMaterial.new()
		_stream_process.direction = Vector3.FORWARD
		_stream_process.spread = THROW_SPREAD
		_stream_process.flatness = 0.55
		_stream_process.initial_velocity_min = THROW_SPEED.x
		_stream_process.initial_velocity_max = THROW_SPEED.y
		_stream_process.gravity = Vector3(0.0, -GRAVITY, 0.0)
		_stream_process.particle_flag_align_y = true
		_stream_process.scale_min = 0.5
		_stream_process.scale_max = 1.9
		# Out of a wound, not a point: the first drops leave from along the cut.
		_stream_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		_stream_process.emission_sphere_radius = 0.05
		# Whole for most of the flight, gone as it reaches the ground.
		var shrink := Curve.new()
		shrink.add_point(Vector2(0.0, 1.0))
		shrink.add_point(Vector2(0.75, 0.9))
		shrink.add_point(Vector2(1.0, 0.0))
		var shrink_tex := CurveTexture.new()
		shrink_tex.curve = shrink
		_stream_process.scale_curve = shrink_tex
	if _mist_process == null:
		_mist_process = ParticleProcessMaterial.new()
		_mist_process.direction = Vector3.FORWARD
		_mist_process.spread = 35.0
		_mist_process.initial_velocity_min = 0.6
		_mist_process.initial_velocity_max = 2.2
		_mist_process.damping_min = 4.0
		_mist_process.damping_max = 7.0
		_mist_process.gravity = Vector3(0.0, -1.2, 0.0)
		_mist_process.scale_min = 0.8
		_mist_process.scale_max = 1.8
		_mist_process.angle_min = -180.0
		_mist_process.angle_max = 180.0
		var grow := Curve.new()
		grow.add_point(Vector2(0.0, 0.5))
		grow.add_point(Vector2(1.0, 2.2))
		var grow_tex := CurveTexture.new()
		grow_tex.curve = grow
		_mist_process.scale_curve = grow_tex
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 0.75))
		fade.set_color(1, Color(1, 1, 1, 0.0))
		var fade_tex := GradientTexture1D.new()
		fade_tex.gradient = fade
		_mist_process.color_ramp = fade_tex


## How many emitter pairs are still in a level. Ones that went with an old
## level are dropped from the ring.
static func _live_sprays() -> int:
	for i in range(_sprays.size() - 1, -1, -1):
		var pair: Array = _sprays[i]
		if not is_instance_valid(pair[0]) or not is_instance_valid(pair[1]):
			_sprays.remove_at(i)
	return _sprays.size()


static func _add_spray(world: Node) -> Array:
	_spray_assets()
	var stream := GPUParticles3D.new()
	stream.name = "BloodSpray"
	stream.amount = 46
	stream.lifetime = 0.62
	stream.one_shot = true
	stream.explosiveness = 0.82
	stream.emitting = false
	stream.draw_pass_1 = _stream_mesh
	stream.material_override = _stream_material
	stream.process_material = _stream_process
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stream.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	world.add_child(stream)
	var mist := GPUParticles3D.new()
	mist.name = "BloodMist"
	mist.amount = 9
	mist.lifetime = 0.42
	mist.one_shot = true
	mist.explosiveness = 0.95
	mist.emitting = false
	mist.draw_pass_1 = _mist_mesh
	mist.material_override = _mist_material
	mist.process_material = _mist_process
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mist)
	var pair := [stream, mist]
	_sprays.append(pair)
	return pair


static func _take_spray(world: Node) -> Array:
	if _live_sprays() < SPRAY_POOL:
		return _add_spray(world)
	var pair: Array = _sprays[_next_spray % _sprays.size()]
	_next_spray += 1
	for p: GPUParticles3D in pair:
		if p.get_parent() != world:
			p.reparent(world, false)
	return pair
#endregion


#region Images
## A pool: a soft blob whose edge wanders (noise, not a handful of lobes — those
## read as the corners of a polygon), a little darker and thicker at the rim
## where it has started to dry, and a few loose drops round it. White: the
## material gives the colour; the image gives the shape and the rim.
static var _splat: ImageTexture
## One drop that hit the ground moving: a round head, a tail thrown on ahead of
## it in the way it was going (+x in the image), and a spatter of fine drops.
static var _drop: ImageTexture
## A cut on a hide: a long thin gash, darkest along its middle, bleeding down.
static var _wound: ImageTexture


static func splat_texture() -> ImageTexture:
	if _splat != null:
		return _splat
	const SIZE := 128
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 90210
	noise.frequency = 0.045
	noise.fractal_octaves = 4
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var spots: Array[Vector3] = []
	for i in 7:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.7, 0.92)
		spots.append(Vector3(cos(a) * r, sin(a) * r, rng.randf_range(0.025, 0.07)))
	for y in SIZE:
		for x in SIZE:
			var u := (x + 0.5) / float(SIZE) * 2.0 - 1.0
			var v := (y + 0.5) / float(SIZE) * 2.0 - 1.0
			var radius := sqrt(u * u + v * v)
			var edge := 0.6 + 0.16 * noise.get_noise_2d(x, y) + 0.05 * noise.get_noise_2d(x * 3.1, y * 3.1)
			var inside := clampf((edge - radius) / 0.035, 0.0, 1.0)
			# The rim: a band just inside the edge, drier and so darker.
			var rim := clampf(1.0 - (edge - radius) / 0.1, 0.0, 1.0) * inside
			for s in spots:
				var d := Vector2(u - s.x, v - s.y).length()
				inside = maxf(inside, clampf((s.z - d) / 0.012, 0.0, 1.0))
			var shade := 1.0 - 0.35 * rim
			image.set_pixel(x, y, Color(shade, shade, shade, inside))
	image.generate_mipmaps()
	_splat = ImageTexture.create_from_image(image)
	return _splat


static func drop_texture() -> ImageTexture:
	if _drop != null:
		return _drop
	const W := 128
	const H := 64
	var image := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 777
	noise.frequency = 0.08
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	var fine: Array[Vector3] = []
	for i in 9:
		# Thrown on ahead of the drop, mostly: the fine spatter.
		fine.append(Vector3(rng.randf_range(-0.2, 0.95), rng.randfn(0.0, 0.25),
				rng.randf_range(0.02, 0.05)))
	for y in H:
		for x in W:
			# u across the length (-1 .. 1, the head at -0.45), v across (-1 .. 1).
			var u := (x + 0.5) / float(W) * 2.0 - 1.0
			var v := ((y + 0.5) / float(H) * 2.0 - 1.0) * 0.5
			var wobble := 0.03 * noise.get_noise_2d(x, y)
			var head := 0.2 + wobble - Vector2(u + 0.45, v).length()
			# The tail: narrowing from the head out to a point near +0.8.
			var along := clampf((u + 0.45) / 1.25, 0.0, 1.0)
			var tail := (0.12 * (1.0 - along) + wobble) - absf(v) if u > -0.45 and u < 0.8 else -1.0
			var inside := clampf(maxf(head, tail) / 0.02, 0.0, 1.0)
			for s in fine:
				var d := Vector2(u - s.x, v - s.y * 0.5).length()
				inside = maxf(inside, clampf((s.z - d) / 0.01, 0.0, 1.0))
			image.set_pixel(x, y, Color(1, 1, 1, inside))
	image.generate_mipmaps()
	_drop = ImageTexture.create_from_image(image)
	return _drop


static func wound_texture() -> ImageTexture:
	if _wound != null:
		return _wound
	const W := 128
	const H := 64
	var image := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 1312
	noise.frequency = 0.07
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	var runs: Array[Vector2] = []
	for i in 4:
		runs.append(Vector2(rng.randf_range(-0.55, 0.55), rng.randf_range(0.25, 0.8)))
	for y in H:
		for x in W:
			var u := (x + 0.5) / float(W) * 2.0 - 1.0
			var v := (y + 0.5) / float(H) * 2.0 - 1.0
			# The gash: widest in the middle, to points at the ends.
			var width := 0.22 * (1.0 - u * u) + 0.05 * noise.get_noise_2d(x, y)
			var dist := absf(v - 0.08 * sin(u * 2.3))
			var gash := clampf((width - dist) / 0.1, 0.0, 1.0)
			var core := clampf((width * 0.35 - dist) / 0.08, 0.0, 1.0)
			# Runs of blood down from it (+v is down the hide).
			var run := 0.0
			for r in runs:
				if v > 0.0 and v < r.y:
					var w := 0.05 * (1.0 - v / r.y)
					run = maxf(run, clampf((w - absf(u - r.x)) / 0.02, 0.0, 1.0))
			var alpha := maxf(gash, run * 0.9)
			var shade := 1.0 - 0.55 * core
			image.set_pixel(x, y, Color(shade, shade, shade, alpha))
	image.generate_mipmaps()
	_wound = ImageTexture.create_from_image(image)
	return _wound
#endregion


#region On the ground
static func _stain_assets() -> void:
	if _pool_material != null:
		return
	# Lit and glossy: fresh blood is wet, and catches the light.
	_pool_material = StandardMaterial3D.new()
	_pool_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pool_material.albedo_color = Color(STAIN.r, STAIN.g, STAIN.b, 0.94)
	_pool_material.albedo_texture = splat_texture()
	_pool_material.roughness = 0.14
	_pool_material.metallic_specular = 0.75
	_pool_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_pool_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_drop_material = _pool_material.duplicate() as StandardMaterial3D
	_drop_material.albedo_texture = drop_texture()
	# One unit quad for every stain; the size lives in the node's scale.
	_patch_mesh = QuadMesh.new()
	_patch_mesh.size = Vector2.ONE


## What comes down on the ground: a small pool straight under the wound, and a
## line of drops where the spray was going — each one worked out as a drop
## thrown the way the spray throws them and followed down to the ground, laid
## there stretched along the way it was moving when it hit, and laid only when
## it would have got there.
static func _stain_ground(world: Node, point: Vector3, along: Vector3, strength: float) -> void:
	_stain_assets()
	var space := _space_of(world)
	var aim := (along + Vector3.UP * 0.22).normalized()
	var side := aim.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	var lift := aim.cross(side).normalized()

	# The pool under the wound: what runs down off it, after a moment.
	var pool_size := randf_range(0.3, 0.55) * clampf(0.7 + 0.3 * strength, 0.6, 1.4)
	var under := point + Vector3(randfn(0.0, 0.06), 0.0, randfn(0.0, 0.06))
	_lay(world, space, _pool_material, under, point.y, Vector3.ZERO, pool_size, pool_size * randf_range(0.75, 1.0),
			randf_range(0.35, 0.6))

	var drops := int(round(DROPS * clampf(strength, 0.4, 2.0)))
	for i in drops:
		# One drop out of the same fan as the spray.
		var turn := deg_to_rad(randf_range(-THROW_SPREAD, THROW_SPREAD))
		var tip := deg_to_rad(randf_range(-THROW_SPREAD, THROW_SPREAD) * 0.45)
		var dir := (aim + side * tan(turn) + lift * tan(tip)).normalized()
		var v := dir * randf_range(THROW_SPEED.x, THROW_SPEED.y)
		var start := point + Vector3(randfn(0.0, 0.04), randfn(0.0, 0.03), randfn(0.0, 0.04))
		var ground_y := _ground_height(space, start + Vector3(v.x, 0.0, v.z) * 0.4, point.y)
		# The time it takes to fall from `start` to the ground, thrown up at v.y.
		var drop := start.y - ground_y
		var t := (v.y + sqrt(maxf(v.y * v.y + 2.0 * GRAVITY * drop, 0.0))) / GRAVITY
		var land := start + Vector3(v.x, 0.0, v.z) * t
		var flat := Vector3(v.x, 0.0, v.z)
		var speed := flat.length()
		var size := randf_range(0.07, 0.16) * (1.0 + 0.18 * speed)
		# The faster it was going along the ground, the longer the drop smears.
		var stretch := size * (1.6 + 0.35 * speed)
		_lay(world, space, _drop_material, land, ground_y + 0.5, flat, stretch, size, t)


## Lays one stain at `at` (moved onto whatever is there to lie on), `length`
## along `heading` (any way if it is zero) by `width` across, and shows it `wait`
## seconds from now with a quick splash.
static func _lay(world: Node, space: PhysicsDirectSpaceState3D, material: Material, at: Vector3,
		from_height: float, heading: Vector3, length: float, width: float, wait: float) -> void:
	var spot := Vector3(at.x, 0.0, at.z)
	var normal := Vector3.UP
	var ground := _ground_under(space, spot, from_height)
	if ground.is_empty():
		spot.y = PATCH_LIFT
	else:
		normal = ground["normal"]
		spot = ground["position"] + normal * PATCH_LIFT
	var spin := randf() * TAU
	if heading.length_squared() > 0.0001:
		# The image's +x is the way the drop was going.
		spin = atan2(-heading.z, heading.x)
	# Laid flat, turned, then tipped onto the slope it landed on.
	var basis := Basis(Quaternion(Vector3.UP, normal)) \
			* Basis(Vector3.UP, spin) * Basis(Vector3.RIGHT, -PI * 0.5)
	var patch := _take_patch(world, material)
	patch.global_transform = Transform3D(basis, spot)
	var full := Vector3(length, width, 1.0)
	patch.scale = full * 0.01
	patch.visible = false
	_show_later(patch, full, wait)


## Holds a stain back until its blood gets there, splashes it out, lets it lie a
## while, then fades it and frees it. A stain picked up and laid again under a
## newer blow starts over.
static func _show_later(patch: MeshInstance3D, full: Vector3, wait: float) -> void:
	# get_meta with a null default still errors when the key is missing
	var old: Variant = patch.get_meta(&"fade") if patch.has_meta(&"fade") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	patch.transparency = 0.0
	var tween := patch.create_tween()
	tween.tween_interval(maxf(wait, 0.0))
	tween.tween_callback(func() -> void: patch.visible = true)
	tween.tween_property(patch, "scale", full, 0.09).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_interval(_linger())
	tween.tween_property(patch, "transparency", 1.0, FADE_TIME)
	tween.tween_callback(func() -> void:
		_patches.erase(patch)
		patch.queue_free())
	patch.set_meta(&"fade", tween)


## A stain to lay down: a new one while there is room under `MAX_PATCHES`,
## otherwise the oldest one, moved.
static func _take_patch(world: Node, material: Material) -> MeshInstance3D:
	# Stains go when their level does; drop the ones that went with it.
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
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(patch)
	patch.material_override = material
	_patches.append(patch)
	return patch


static func _space_of(world: Node) -> PhysicsDirectSpaceState3D:
	var spatial := world as Node3D
	if spatial == null or spatial.get_world_3d() == null:
		return null
	return spatial.get_world_3d().direct_space_state


## The ground straight below `at`, searched from a little above `from_height`
## down to well below it. Empty if there is nothing there.
static func _ground_under(space: PhysicsDirectSpaceState3D, at: Vector3, from_height: float) -> Dictionary:
	if space == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
			Vector3(at.x, from_height + 1.0, at.z),
			Vector3(at.x, from_height - 4.0, at.z), GROUND_MASK)
	return space.intersect_ray(query)


## The height of the ground under `at`, or of the level's floor (0) if there is
## nothing found.
static func _ground_height(space: PhysicsDirectSpaceState3D, at: Vector3, from_height: float) -> float:
	var hit := _ground_under(space, at, from_height)
	if hit.is_empty():
		return 0.0
	return (hit["position"] as Vector3).y


## Tints whatever is standing where the blood came down — grass, stones, props.
##
## Two ways round, because the scatter holds two kinds of thing. The grass is
## drawn out of multimeshes and has no per-clump material to hang an overlay on,
## so the field is asked to darken the instances itself. Everything else in the
## scatter is still a node, and gets an overlay material — the object keeps its
## own texture and simply reads as wet, and nothing has to be put back after.
static func _stain_nearby(world: Node, point: Vector3, along: Vector3) -> void:
	var scatter := world.get_node_or_null("Level/Scatter")
	if scatter == null:
		return
	# Where most of it comes down: a little way on along the blow.
	var flat := Vector3(along.x, 0.0, along.z)
	var centre := point + (flat.normalized() * 0.8 if flat.length_squared() > 0.0001 else Vector3.ZERO)

	var field := scatter as GrassField
	if field != null:
		field.stain(centre, SPLATTER_RADIUS, TINT, 0.45)
	var wet: Array[MeshInstance3D] = []

	if _overlay_material == null:
		_overlay_material = StandardMaterial3D.new()
		_overlay_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_overlay_material.albedo_color = Color(STAIN.r, STAIN.g, STAIN.b, 0.45)
		_overlay_material.roughness = 0.2
	var overlay := _overlay_material
	for child in scatter.get_children():
		var node := child as Node3D
		# The field's own chunks are not props standing in the blood; they *are*
		# the grass, and they have already been tinted.
		if node == null or node is MultiMeshInstance3D:
			continue
		if node.global_position.distance_to(centre) > SPLATTER_RADIUS:
			continue
		for m in node.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_overlay = overlay
			wet.append(m as MeshInstance3D)
	# The grass and the props dry off when the ground does.
	world.get_tree().create_timer(_linger() + FADE_TIME, false).timeout.connect(func() -> void:
		if field != null and is_instance_valid(field):
			field.unstain(centre, SPLATTER_RADIUS)
		for m in wet:
			if is_instance_valid(m) and m.material_overlay == overlay:
				m.material_overlay = null)
#endregion


#region On the body
## Leaves a cut on `creature` at `point`, laid along `along` (the way the blade
## was going): a [Decal] that marks only the creature's own meshes (they are put
## on `WOUND_LAYER` the first time), carried by the part of the body nearest the
## point so it moves with it. At most `MAX_WOUNDS` on one creature.
static func wound(creature: Node3D, point: Vector3, along: Vector3) -> void:
	if creature == null or not creature.is_inside_tree():
		return
	if not creature.has_meta(&"wound_layer"):
		creature.set_meta(&"wound_layer", true)
		for m in creature.find_children("*", "GeometryInstance3D", true, false):
			var g := m as GeometryInstance3D
			if not (g is GPUParticles3D) and not (g is Label3D):
				g.layers |= WOUND_LAYER
	var carrier := _nearest_part(creature, point)
	var wounds: Array = creature.get_meta(&"wounds") if creature.has_meta(&"wounds") else []
	while wounds.size() >= MAX_WOUNDS:
		var old: Variant = wounds.pop_front()
		if is_instance_valid(old):
			(old as Node).queue_free()

	var decal := Decal.new()
	decal.name = "Wound"
	decal.texture_albedo = wound_texture()
	decal.modulate = Color(0.3, 0.012, 0.01)
	decal.albedo_mix = 0.85
	# Only on the side of the body the cut is on, not through to the far side.
	decal.normal_fade = 0.35
	decal.cull_mask = WOUND_LAYER
	decal.upper_fade = 0.15
	decal.lower_fade = 0.15
	var size := 0.55 * _size_of(creature)
	decal.size = Vector3(size, size * 0.4, size * 0.3)
	carrier.add_child(decal)

	# Its -Y is the way it projects: into the body, from the side the cut is on.
	var out := point - (creature.global_position + Vector3.UP * (point.y - creature.global_position.y))
	if out.length_squared() < 0.0001:
		out = -along
	out = out.normalized()
	var length := along - out * along.dot(out)
	if length.length_squared() < 0.0001:
		length = out.cross(Vector3.UP)
	length = length.normalized()
	var across := length.cross(out).normalized()
	# The image's runs of blood go down its +v (the decal's +Z): keep that down.
	if across.y > 0.0:
		length = -length
		across = -across
	decal.global_transform = Transform3D(Basis(length, out, across).orthonormalized(),
			point + out * size * 0.06)
	wounds.append(decal)
	creature.set_meta(&"wounds", wounds)


## The bone-carried part of `creature` nearest `point`, or the creature itself.
static func _nearest_part(creature: Node3D, point: Vector3) -> Node3D:
	var best: Node3D = creature
	var closest := INF
	for node in creature.find_children("*", "BoneAttachment3D", true, false):
		var at := node as Node3D
		var gap := at.global_position.distance_squared_to(point)
		if gap < closest:
			closest = gap
			best = at
	return best


## Roughly how big a creature is against a man, for the size of its wounds.
static func _size_of(creature: Node3D) -> float:
	var s: Variant = creature.get(&"visual_scale")
	if s is float:
		return clampf(s as float, 0.6, 2.5)
	var body := creature.get_node_or_null(^"Visuals") as Node3D
	if body != null:
		return clampf(body.scale.x, 0.6, 2.5)
	return 1.0
#endregion


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
