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
const SPRAY := Color(0.58, 0.03, 0.03)
const CHUNK := Color(0.46, 0.02, 0.02)
const STAIN := Color(0.32, 0.02, 0.02)
## The tint the grass and the props take.
const TINT := Color(0.34, 0.02, 0.015)

## Radius over which the grass and the props standing in the blood get tinted:
## the ground stains lie under the grass, and a meadow would hide them, so the
## grass itself is what has to read as bloodied.
const SPLATTER_RADIUS := 1.9
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
const DROPS := 14

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

## How it looks (see [method use_style]):
##   `cubes` — a stream of small bright cubes and darker gouts, faceted pools
##             (the first: blocky like the world);
##   `gloss` — round glossy drops, lit, and smooth wet pools that catch the
##             light (after Arkdeva's venom);
##   `trail` — a thin fast streak of drops along the cut and, on the ground,
##             one red stroke the way the blade went, and a few drops;
##   `mist`  — a soft red mist that hangs and thins, and on the ground a clear
##             red pool, splashes and drops (the one the game uses).
static var style: StringName = &"mist"
static var _stroke: ImageTexture


## Changes how blood looks from the next blow on: the sprays and stains laid so
## far are cleared and the assets built again.
static func use_style(which: StringName) -> void:
	style = which
	_stream_mesh = null
	_stream_material = null
	_burst_mesh = null
	_burst_material = null
	_stream_process = null
	_burst_process = null
	_splat = null
	_pool_material = null
	_drop_material = null
	for pair: Array in _sprays:
		for p: Variant in pair:
			if is_instance_valid(p):
				(p as Node).queue_free()
	_sprays.clear()
	for patch in _patches:
		if is_instance_valid(patch):
			patch.queue_free()
	_patches.clear()


static func _lit(colour: Color, alpha: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.12
	m.metallic_specular = 1.0
	m.metallic = 0.15
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


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
	# A skeleton or a golem has none to let (the user, 2026-10-06): what it
	# is made of is knocked off it instead, bone chips or stone grit.
	if on != null and not bleeds(on):
		_chips(world, point, on, strength)
		return
	_spray(world, point, along, strength)
	_stain_ground(world, point, along, strength)
	_stain_nearby(world, point, along)
	if on != null:
		wound(on, point, along)


## Whether `creature` has blood to let: not a skeleton or a golem (bone or
## stone, [method ImpactFx.matter_of]). Nothing struck bleeds as flesh does.
static func bleeds(creature: Node) -> bool:
	return creature == null or ImpactFx.matter_of(creature) == &"flesh"


## Blood where `struck` (whatever was hit, if known) has any, with no wound
## laid on it: an arrow going in, a gust through it. Its chips where it has
## none.
static func spill(world: Node, point: Vector3, direction: Vector3, struck: Node = null,
		strength: float = 1.0) -> void:
	if world == null or not world.is_inside_tree():
		return
	if struck != null and not bleeds(struck):
		_chips(world, point, struck, strength)
		return
	splatter(world, point, direction, null, strength)


static func _chips(world: Node, point: Vector3, struck: Node, strength: float) -> void:
	var matter := ImpactFx.matter_of(struck)
	HitFx.spawn(world, matter if matter in [&"bone", &"stone", &"wood"] else &"stone", point,
			HitFx.facing_out(struck, point), clampf(strength, 0.6, 2.0))


## How long this blow's blood stays, between `LINGER_MIN` and `LINGER_MAX`.
static func _linger() -> float:
	if style == &"mist":
		return randf_range(14.0, 18.0)
	if style == &"trail":
		return randf_range(18.0, 24.0)
	return randf_range(LINGER_MIN, LINGER_MAX)


#region The spray
## Six is more blows than land inside one spray's life, so a spray is almost
## never cut short by being reused.
const SPRAY_POOL := 6

static var _stream_process: ParticleProcessMaterial
static var _stream_mesh: PrimitiveMesh
static var _stream_material: StandardMaterial3D
static var _burst_process: ParticleProcessMaterial
static var _burst_mesh: PrimitiveMesh
static var _burst_material: StandardMaterial3D
## Each entry: [the stream of drops, the gush].
static var _sprays: Array = []
static var _next_spray: int = 0


## What comes out of the wound as the blade goes through, all of it thrown the
## way the blade was going, in blocks like the world it falls in: a stream of
## small bright cubes, tumbling as they fly and fall, and a dozen bigger,
## darker gouts that burst out of the cut and shrink away as they come down.
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
		p.amount_ratio = clampf(0.6 + 0.3 * strength, 0.35, 1.0)
		p.restart()


static func _spray_assets() -> void:
	if _stream_mesh == null and style != &"cubes":
		match style:
			&"gloss":
				var drop := SphereMesh.new()
				drop.radius = 0.022
				drop.height = 0.044
				drop.radial_segments = 8
				drop.rings = 4
				_stream_mesh = drop
				_stream_material = _lit(SPRAY)
				var gout := SphereMesh.new()
				gout.radius = 0.045
				gout.height = 0.09
				gout.radial_segments = 8
				gout.rings = 4
				_burst_mesh = gout
				_burst_material = _lit(CHUNK)
			&"trail":
				# Streaks, drawn out along the way they fly.
				var streak := BoxMesh.new()
				streak.size = Vector3(0.012, 0.11, 0.012)
				_stream_mesh = streak
				_stream_material = StandardMaterial3D.new()
				_stream_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_stream_material.albedo_color = Color(0.62, 0.02, 0.03)
				var bead := SphereMesh.new()
				bead.radius = 0.02
				bead.height = 0.04
				bead.radial_segments = 6
				bead.rings = 3
				_burst_mesh = bead
				_burst_material = _stream_material
			&"mist":
				var puff := QuadMesh.new()
				puff.size = Vector2(0.22, 0.22)
				_stream_mesh = puff
				_stream_material = StandardMaterial3D.new()
				_stream_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_stream_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				_stream_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
				_stream_material.albedo_texture = _soft_dot()
				_stream_material.vertex_color_use_as_albedo = true
				_stream_material.albedo_color = Color(0.55, 0.03, 0.03, 0.8)
				var fleck := SphereMesh.new()
				fleck.radius = 0.016
				fleck.height = 0.032
				fleck.radial_segments = 6
				fleck.rings = 3
				_burst_mesh = fleck
				_burst_material = _lit(SPRAY)
	if _stream_mesh == null:
		# Blocks, like the world they fall in: a small cube each, flat red.
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE * 0.036
		_stream_mesh = cube
		_stream_material = StandardMaterial3D.new()
		_stream_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_stream_material.albedo_color = SPRAY
	if _burst_mesh == null:
		# A gout: a bigger block, darker, tumbling out of the cut.
		var block := BoxMesh.new()
		block.size = Vector3.ONE * 0.075
		_burst_mesh = block
		_burst_material = StandardMaterial3D.new()
		_burst_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_burst_material.albedo_color = CHUNK
	if _burst_process == null:
		_burst_process = ParticleProcessMaterial.new()
		_burst_process.direction = Vector3.FORWARD
		_burst_process.spread = 26.0
		_burst_process.flatness = 0.4
		_burst_process.initial_velocity_min = 1.4
		_burst_process.initial_velocity_max = 4.6
		_burst_process.damping_min = 1.5
		_burst_process.damping_max = 3.0
		_burst_process.gravity = Vector3(0.0, -7.0, 0.0)
		_burst_process.scale_min = 0.6
		_burst_process.scale_max = 1.5
		_burst_process.angle_min = -180.0
		_burst_process.angle_max = 180.0
		_burst_process.angular_velocity_min = -360.0
		_burst_process.angular_velocity_max = 360.0
		_burst_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		_burst_process.emission_sphere_radius = 0.06
		# Out of the cut small, full a moment later, shrinking away as it falls.
		var swell := Curve.new()
		swell.add_point(Vector2(0.0, 0.4))
		swell.add_point(Vector2(0.15, 1.0))
		swell.add_point(Vector2(0.75, 0.9))
		swell.add_point(Vector2(1.0, 0.0))
		var swell_tex := CurveTexture.new()
		swell_tex.curve = swell
		_burst_process.scale_curve = swell_tex
	if _stream_process == null:
		_stream_process = ParticleProcessMaterial.new()
		_stream_process.direction = Vector3.FORWARD
		_stream_process.spread = THROW_SPREAD
		_stream_process.flatness = 0.55
		_stream_process.initial_velocity_min = THROW_SPEED.x
		_stream_process.initial_velocity_max = THROW_SPEED.y
		_stream_process.gravity = Vector3(0.0, -GRAVITY, 0.0)
		_stream_process.angle_min = -180.0
		_stream_process.angle_max = 180.0
		_stream_process.angular_velocity_min = -540.0
		_stream_process.angular_velocity_max = 540.0
		_stream_process.scale_min = 0.55
		_stream_process.scale_max = 1.6
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
		if style == &"trail":
			# Each streak drawn out along its own flight.
			_stream_process.particle_flag_align_y = true
			_stream_process.angle_min = 0.0
			_stream_process.angle_max = 0.0
			_stream_process.angular_velocity_min = 0.0
			_stream_process.angular_velocity_max = 0.0
			_stream_process.spread = THROW_SPREAD * 0.6
		elif style == &"mist":
			# A soft cloud thrown a little way and hanging, growing as it thins.
			_stream_process.spread = 40.0
			_stream_process.initial_velocity_min = 0.6
			_stream_process.initial_velocity_max = 2.2
			_stream_process.gravity = Vector3(0.0, -0.6, 0.0)
			_stream_process.damping_min = 1.5
			_stream_process.damping_max = 3.0
			var grow := Curve.new()
			grow.add_point(Vector2(0.0, 0.4))
			grow.add_point(Vector2(1.0, 1.8))
			var grow_tex := CurveTexture.new()
			grow_tex.curve = grow
			_stream_process.scale_curve = grow_tex
			var thin := Gradient.new()
			thin.set_color(0, Color(1, 1, 1, 0.85))
			thin.set_color(1, Color(1, 1, 1, 0.0))
			var thin_tex := GradientTexture1D.new()
			thin_tex.gradient = thin
			_stream_process.color_ramp = thin_tex


## How many emitter pairs are still in a level. Ones that went with an old
## level are dropped from the ring.
static func _live_sprays() -> int:
	for i in range(_sprays.size() - 1, -1, -1):
		var pair: Array = _sprays[i]
		for p: Variant in pair:
			if not is_instance_valid(p):
				_sprays.remove_at(i)
				break
	return _sprays.size()


static func _add_spray(world: Node) -> Array:
	_spray_assets()
	var stream := GPUParticles3D.new()
	stream.name = "BloodSpray"
	stream.amount = int({&"cubes": 36, &"gloss": 30, &"trail": 22, &"mist": 18}.get(style, 36))
	stream.lifetime = 1.1 if style == &"mist" else 0.62
	stream.one_shot = true
	stream.explosiveness = 0.82
	stream.emitting = false
	stream.draw_pass_1 = _stream_mesh
	stream.material_override = _stream_material
	stream.process_material = _stream_process
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stream.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	world.add_child(stream)
	var gush := GPUParticles3D.new()
	gush.name = "BloodGush"
	gush.amount = int({&"cubes": 12, &"gloss": 10, &"trail": 5, &"mist": 8}.get(style, 12))
	gush.lifetime = 0.5
	gush.one_shot = true
	gush.explosiveness = 0.9
	gush.emitting = false
	gush.draw_pass_1 = _burst_mesh
	gush.material_override = _burst_material
	gush.process_material = _burst_process
	gush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gush.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	world.add_child(gush)
	var pair := [stream, gush]
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
## A pool: a faceted blob — a few straight-sided lobes, cut like the rest of
## the world — darker in the middle, with square drops thrown round it. White:
## the material gives the colour. The drops on the ground are the same image,
## stretched the way they were going.
static var _splat: ImageTexture
## A cut on a hide: a long thin gash, darkest along its middle, bleeding down.
static var _wound: ImageTexture


static func splat_texture() -> ImageTexture:
	if _splat != null:
		return _splat
	if style == &"gloss" or style == &"trail":
		_splat = _smooth_splat()
		return _splat
	if style == &"mist":
		_splat = _soft_dot()
		return _splat
	const SIZE := 128
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	# A few straight-sided lobes: a faceted blob, cut like the rest of the world.
	var lobes := PackedFloat32Array()
	for i in 9:
		lobes.append(rng.randf_range(0.58, 0.92))
	# Square drops thrown round it.
	var spots: Array[Vector3] = []
	for i in 8:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.72, 0.95)
		spots.append(Vector3(cos(a) * r, sin(a) * r, rng.randf_range(0.03, 0.065)))
	for y in SIZE:
		for x in SIZE:
			var u := (x + 0.5) / float(SIZE) * 2.0 - 1.0
			var v := (y + 0.5) / float(SIZE) * 2.0 - 1.0
			var radius := sqrt(u * u + v * v)
			var around := (atan2(v, u) + PI) / TAU * lobes.size()
			var first := int(floor(around)) % lobes.size()
			var edge := lerpf(lobes[first], lobes[(first + 1) % lobes.size()], around - floor(around))
			var inside := clampf((edge - radius) / 0.02, 0.0, 1.0)
			for sp in spots:
				var d := maxf(absf(u - sp.x), absf(v - sp.y))
				inside = maxf(inside, clampf((sp.z - d) / 0.008, 0.0, 1.0))
			# A darker core where it lies deepest.
			var shade := 1.0 - 0.25 * clampf((edge * 0.55 - radius) / 0.1, 0.0, 1.0)
			image.set_pixel(x, y, Color(shade, shade, shade, inside))
	image.generate_mipmaps()
	_splat = ImageTexture.create_from_image(image)
	return _splat


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


## A wet pool: a smooth round blob with a wavering edge, a few round drops
## beside it, deeper in the middle.
static func _smooth_splat() -> ImageTexture:
	const SIZE := 128
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	var waves: Array[Vector3] = []
	for i in 4:
		waves.append(Vector3(rng.randi_range(3, 9), rng.randf_range(0.03, 0.07), rng.randf() * TAU))
	var spots: Array[Vector3] = []
	for i in 6:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.78, 0.93)
		spots.append(Vector3(cos(a) * r, sin(a) * r, rng.randf_range(0.03, 0.06)))
	for y in SIZE:
		for x in SIZE:
			var u := (x + 0.5) / float(SIZE) * 2.0 - 1.0
			var v := (y + 0.5) / float(SIZE) * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			var a := atan2(v, u)
			var edge := 0.66
			for w in waves:
				edge += w.y * sin(w.x * a + w.z)
			var inside := clampf((edge - r) / 0.025, 0.0, 1.0)
			for sp in spots:
				inside = maxf(inside, clampf((sp.z - Vector2(u - sp.x, v - sp.y).length()) / 0.01, 0.0, 1.0))
			var shade := 1.0 - 0.3 * clampf((edge * 0.6 - r) / 0.15, 0.0, 1.0)
			image.set_pixel(x, y, Color(shade, shade, shade, inside))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## A soft round dot, clear at its edge.
static func _soft_dot() -> ImageTexture:
	const SIZE := 64
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var u := (x + 0.5) / float(SIZE) * 2.0 - 1.0
			var v := (y + 0.5) / float(SIZE) * 2.0 - 1.0
			var a := clampf(1.0 - sqrt(u * u + v * v), 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, a * a))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## A stroke of red laid the way the blade went: a long streak, thick at its
## start and thinning to a torn tail, dry-brushed along its edges.
static func stroke_texture() -> ImageTexture:
	if _stroke != null:
		return _stroke
	const W := 256
	const H := 64
	var image := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 404
	noise.frequency = 0.09
	for y in H:
		for x in W:
			var u := (x + 0.5) / float(W)
			var v := (y + 0.5) / float(H) * 2.0 - 1.0
			var width := 0.8 * pow(1.0 - u, 0.6) * smoothstep(0.0, 0.08, u) + 0.04
			var bristle := 0.25 * noise.get_noise_2d(x * 0.4, y * 3.0)
			var inside := clampf((width + bristle * width - absf(v)) / 0.06, 0.0, 1.0)
			# Streaks where the brush ran dry, more of them towards the tail.
			if noise.get_noise_2d(x * 0.15, y * 6.0) < -0.35 + 0.5 * (1.0 - u):
				inside *= 0.25
			var shade := 1.0 - 0.25 * clampf(1.0 - absf(v) / maxf(width, 0.01), 0.0, 1.0)
			image.set_pixel(x, y, Color(shade, shade, shade, inside))
	image.generate_mipmaps()
	_stroke = ImageTexture.create_from_image(image)
	return _stroke


#region On the ground
static func _stain_assets() -> void:
	if _pool_material == null and style != &"cubes":
		if style == &"gloss":
			_pool_material = _lit(Color(0.36, 0.015, 0.015, 0.97), true)
			_pool_material.metallic = 0.0
			_pool_material.roughness = 0.22
			_pool_material.albedo_texture = splat_texture()
			_pool_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			_drop_material = _pool_material
		else:
			_pool_material = StandardMaterial3D.new()
			_pool_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_pool_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_pool_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			if style == &"trail":
				_pool_material.albedo_color = Color(0.5, 0.02, 0.03, 0.95)
				_pool_material.albedo_texture = stroke_texture()
				_drop_material = _pool_material.duplicate() as StandardMaterial3D
				_drop_material.albedo_texture = splat_texture()
			else:
				# Deep red with a clear edge, so it reads on grass and stone alike;
				# the drops round it keep the mist's soft edge.
				_pool_material.albedo_color = Color(0.52, 0.02, 0.03, 0.95)
				_pool_material.albedo_texture = _smooth_splat()
				_drop_material = _pool_material.duplicate() as StandardMaterial3D
				_drop_material.albedo_color = Color(0.6, 0.03, 0.04, 0.95)
				_drop_material.albedo_texture = _soft_dot()
		_patch_mesh = QuadMesh.new()
		_patch_mesh.size = Vector2.ONE
	if _pool_material != null:
		return
	# Flat red, like the spray: faceted pools that read at a glance.
	_pool_material = StandardMaterial3D.new()
	_pool_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pool_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pool_material.albedo_color = Color(STAIN.r, STAIN.g, STAIN.b, 0.95)
	_pool_material.albedo_texture = splat_texture()
	_pool_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_pool_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_drop_material = _pool_material.duplicate() as StandardMaterial3D
	_drop_material.albedo_texture = splat_texture()
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
	if style == &"trail" or style == &"mist":
		_stain_light(world, space, point, aim, strength)
		return
	var side := aim.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	var lift := aim.cross(side).normalized()

	# The pool under the wound: what runs down off it, after a moment.
	var pool_size := randf_range(0.45, 0.8) * clampf(0.7 + 0.3 * strength, 0.6, 1.4)
	var under := point + Vector3(randfn(0.0, 0.06), 0.0, randfn(0.0, 0.06))
	_lay(world, space, _pool_material, under, point.y, Vector3.ZERO, pool_size, pool_size * randf_range(0.75, 1.0),
			randf_range(0.35, 0.6))

	var drops := int(round(DROPS * clampf(strength, 0.4, 2.0)))
	var landed := Vector3.ZERO
	var fell := 0.0
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
		var size := randf_range(0.1, 0.22) * (1.0 + 0.18 * speed)
		# The faster it was going along the ground, the longer the drop smears.
		var stretch := size * (1.6 + 0.35 * speed)
		_lay(world, space, _drop_material, land, ground_y + 0.5, flat, stretch, size, t)
		landed += land
		fell = maxf(fell, t)
	# Where most of it came down, a wider splash of it.
	if drops > 0:
		var middle := landed / float(drops)
		var flat_aim := Vector3(aim.x, 0.0, aim.z)
		var wide := randf_range(0.45, 0.75) * clampf(0.8 + 0.2 * strength, 0.7, 1.4)
		_lay(world, space, _pool_material, middle, point.y, flat_aim, wide * 1.4, wide, fell * 0.8)


## The light styles' ground: a stroke the way the blade went and a few drops
## (`trail`), or a pool, splashes and drops (`mist`).
static func _stain_light(world: Node, space: PhysicsDirectSpaceState3D, point: Vector3, aim: Vector3,
		strength: float) -> void:
	var flat := Vector3(aim.x, 0.0, aim.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3(randf() - 0.5, 0.0, randf() - 0.5)
	flat = flat.normalized()
	if style == &"trail":
		var length := randf_range(1.1, 1.7) * clampf(0.8 + 0.2 * strength, 0.7, 1.5)
		var start := point + flat * 0.2
		_lay(world, space, _pool_material, start + flat * length * 0.5, point.y, flat, length,
				randf_range(0.16, 0.24), 0.25)
		for i in 3 + int(strength):
			var at := point + flat * randf_range(0.6, 2.2) + flat.cross(Vector3.UP) * randfn(0.0, 0.18)
			var size := randf_range(0.06, 0.13)
			_lay(world, space, _drop_material, at, point.y, flat, size * 1.4, size, randf_range(0.3, 0.55))
		return
	# A pool under the wound, splashes the way the mist was thrown, and a
	# spatter of drops round them.
	var pool := randf_range(0.55, 0.85) * clampf(0.8 + 0.2 * strength, 0.7, 1.4)
	_lay(world, space, _pool_material, point + Vector3(randfn(0.0, 0.08), 0.0, randfn(0.0, 0.08)), point.y,
			Vector3.ZERO, pool, pool * randf_range(0.75, 1.0), randf_range(0.2, 0.4))
	for i in 2 + int(strength):
		var at := point + flat * randf_range(0.5, 1.4) + Vector3(randfn(0.0, 0.2), 0.0, randfn(0.0, 0.2))
		var size := randf_range(0.3, 0.5)
		_lay(world, space, _pool_material, at, point.y, flat, size * 1.3, size, randf_range(0.3, 0.6))
	for i in 5 + int(strength * 2.0):
		var at := point + flat * randf_range(0.2, 2.0) + Vector3(randfn(0.0, 0.35), 0.0, randfn(0.0, 0.35))
		var size := randf_range(0.1, 0.2)
		_lay(world, space, _drop_material, at, point.y, flat, size * 1.2, size, randf_range(0.3, 0.7))


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
	var hit := {}
	if space != null:
		var query := PhysicsRayQueryParameters3D.create(
				Vector3(at.x, from_height + 1.0, at.z),
				Vector3(at.x, from_height - 4.0, at.z), GROUND_MASK)
		hit = space.intersect_ray(query)
	# Missed (the rolling land is not always a body the ray can find): the
	# land's own height there. Without this a stain on a hillside was laid at
	# the height of the old flat floor — under the hill, out of sight.
	if hit.is_empty() and Terrain.current != null:
		var y := Terrain.current.height_at(at.x, at.z)
		var step := 0.3
		var n := Vector3(Terrain.current.height_at(at.x - step, at.z) - Terrain.current.height_at(at.x + step, at.z),
				2.0 * step,
				Terrain.current.height_at(at.x, at.z - step) - Terrain.current.height_at(at.x, at.z + step)).normalized()
		hit = {"position": Vector3(at.x, y, at.z), "normal": n}
	return hit


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
		field.stain(centre, SPLATTER_RADIUS, TINT, 0.8)
	var wet: Array[MeshInstance3D] = []

	if _overlay_material == null:
		_overlay_material = StandardMaterial3D.new()
		_overlay_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_overlay_material.albedo_color = Color(STAIN.r, STAIN.g, STAIN.b, 0.6)
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
