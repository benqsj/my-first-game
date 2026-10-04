class_name SkidDust
extends GPUParticles3D
## Dirt kicked up from under a boot driven back along the ground: a blow
## caught on his shield shoves him, his feet skid, and a low puff goes up off
## each heel, thrown the way he is sliding (TARIEL_POLISH.md, the block).
##
## Soft dull puffs, not sparks: earth does not shine.
## It frees itself.

## Dirt colour.
const TINT := Color(0.6, 0.53, 0.44)

static var _material: ParticleProcessMaterial = null
static var _draw: QuadMesh = null
static var _puff: ImageTexture = null


## Kicks one up at `where` (on the ground under a foot), thrown along `along`
## (the way he slides) and up a little. `strength` 0..1, how hard the shove:
## a plain blow a thin wisp, a heavy one a thick cloud (how many puffs, how
## solid, how big, how far).
static func kick(into: Node, where: Vector3, along: Vector3, strength: float = 1.0) -> SkidDust:
	var k := clampf(strength, 0.0, 1.0)
	if into == null:
		return null
	var dust := SkidDust.new()
	dust._build(along, k)
	into.add_child(dust)
	dust.global_position = where + Vector3.UP * 0.05
	dust.emitting = true
	dust.get_tree().create_timer(dust.lifetime + 0.3).timeout.connect(dust.queue_free)
	return dust


## How solid the puffs are, from the lightest shove to the heaviest.
const SOLID := Vector2(0.04, 0.3)


func _build(along: Vector3, k: float) -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	one_shot = true
	explosiveness = 0.8
	lifetime = lerpf(0.45, 0.85, k)
	amount = maxi(int(lerpf(1.0, 8.0, k * k)), 1)
	visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 4, 6))
	var process := _process_material().duplicate() as ParticleProcessMaterial
	var flat := Vector3(along.x, 0.0, along.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
	process.direction = (flat + Vector3.UP * 0.45).normalized()
	process.initial_velocity_min = lerpf(0.3, 1.2, k)
	process.initial_velocity_max = lerpf(0.8, 2.8, k)
	process.scale_min = lerpf(0.12, 0.38, k)
	process.scale_max = lerpf(0.22, 0.6, k)
	var solid := lerpf(SOLID.x, SOLID.y, k * k)
	var fade := Gradient.new()
	fade.set_color(0, Color(TINT, solid))
	fade.set_color(1, Color(TINT, 0.0))
	fade.add_point(0.25, Color(TINT, solid * 0.85))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	process.color_ramp = fade_tex
	process_material = process
	draw_pass_1 = _quad()


static func _process_material() -> ParticleProcessMaterial:
	if _material != null:
		return _material
	_material = ParticleProcessMaterial.new()
	_material.spread = 32.0
	_material.gravity = Vector3(0.0, -0.6, 0.0)
	_material.damping_min = 2.5
	_material.damping_max = 4.0
	_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_material.emission_sphere_radius = 0.08
	_material.angle_min = -180.0
	_material.angle_max = 180.0
	# each puff grows as it rises, then thins out
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(0.4, 0.85))
	grow.add_point(Vector2(1.0, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	_material.scale_curve = grow_tex
	return _material


static func _quad() -> QuadMesh:
	if _draw != null:
		return _draw
	_draw = QuadMesh.new()
	_draw.size = Vector2(0.6, 0.6)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.vertex_color_use_as_albedo = true
	look.albedo_texture = _blob()
	look.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_draw.material = look
	return _draw


## A soft round puff, solid in the middle and gone by the rim, a little lumpy.
static func _blob() -> ImageTexture:
	if _puff != null:
		return _puff
	const SIDE := 64
	var image := Image.create(SIDE, SIDE, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.09
	var middle := (SIDE - 1) * 0.5
	for y in SIDE:
		for x in SIDE:
			var out := Vector2(x - middle, y - middle).length() / middle
			var a := (1.0 - smoothstep(0.25, 1.0, out)) * (0.75 + 0.25 * noise.get_noise_2d(x, y))
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(a, 0.0, 1.0)))
	_puff = ImageTexture.create_from_image(image)
	return _puff
