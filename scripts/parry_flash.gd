class_name ParryFlash
extends Node3D

## Steel on steel: the flash where a parried blow met the shield.
##
## Three things, all gone within half a second:
##
## * **A star** of light, facing the camera, that swells and is gone — the
##   moment of contact.
## * **Sparks** thrown back the way the blow came, falling as they cool from
##   white to orange: this is what says *metal*, where dust would say earth and
##   blood would say flesh.
## * **A lamp** that flares with the star, so the shield and the arm behind it
##   are lit by it for a frame or two.
##
## Unlike the dust and the arrow's wake, this is allowed to glow: a sword
## struck off a shield does throw sparks, and a parry has to read in the corner
## of the eye in the middle of a fight.

const LIFE := 0.45

var _star: MeshInstance3D
var _star_mat: StandardMaterial3D
var _lamp: OmniLight3D
var _age: float = 0.0

static var _star_tex: ImageTexture = null
static var _spark_tex: ImageTexture = null


## Throws one at `where`, the sparks going out along `outward` (towards whoever
## struck the blow). `size` scales it all — the star, the lamp, how many
## sparks and how far they fly: 1 a parry, less a blow caught on a guard
## (`Player`'s block, by how hard it was).
static func burst(into: Node, where: Vector3, outward: Vector3, size: float = 1.0) -> ParryFlash:
	if into == null:
		return null
	var flash := ParryFlash.new()
	flash.size = clampf(size, 0.1, 2.0)
	into.add_child(flash)
	flash.global_position = where
	flash._build(outward)
	return flash


## How big this one is (see [method burst]).
var size: float = 1.0


func _build(outward: Vector3) -> void:
	top_level = true
	_star = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	_star.mesh = quad
	_star_mat = StandardMaterial3D.new()
	_star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_star_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_star_mat.no_depth_test = true
	_star_mat.albedo_texture = _star_texture()
	_star_mat.albedo_color = Color(1.0, 0.93, 0.75, 1.0)
	_star.material_override = _star_mat
	_star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_star.scale = Vector3.ONE * 0.3
	add_child(_star)

	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.85, 0.55)
	_lamp.light_energy = 5.0 * size
	_lamp.omni_range = 4.0 * sqrt(size)
	add_child(_lamp)

	var sparks := GPUParticles3D.new()
	sparks.amount = maxi(int(28.0 * size), 6)
	sparks.lifetime = 0.42
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.local_coords = false
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	var out := outward
	out.y = 0.0
	out = out.normalized() if out.length_squared() > 0.0001 else Vector3.FORWARD
	# The sparks go back at whoever struck, and up: a fan, not a sphere.
	process.direction = (out + Vector3.UP * 0.55).normalized()
	process.spread = 55.0
	process.initial_velocity_min = 3.5 * sqrt(size)
	process.initial_velocity_max = 8.0 * sqrt(size)
	process.gravity = Vector3(0.0, -14.0, 0.0)
	process.damping_min = 2.0
	process.damping_max = 4.0
	process.scale_min = 0.5
	process.scale_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 0.92, 1.0))
	ramp.set_color(1, Color(1.0, 0.35, 0.05, 0.0))
	ramp.add_point(0.35, Color(1.0, 0.8, 0.35, 1.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	process.color_ramp = ramp_tex
	sparks.process_material = process
	var streak := QuadMesh.new()
	streak.size = Vector2(0.025, 0.14)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_mat.vertex_color_use_as_albedo = true
	spark_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	spark_mat.albedo_texture = _spark_texture()
	streak.material = spark_mat
	sparks.draw_pass_1 = streak
	# Each quad's long side turned along the way it flies, so a spark is a streak.
	process.particle_flag_align_y = true
	add_child(sparks)
	sparks.emitting = true


func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / LIFE, 0.0, 1.0)
	if _age > LIFE + 0.1:
		queue_free()
		return
	if _star != null:
		# Up at once, then out.
		var grow := 1.0 - pow(1.0 - clampf(_age / 0.08, 0.0, 1.0), 3.0)
		_star.scale = Vector3.ONE * lerpf(0.3, 1.5, grow) * (1.0 - 0.4 * t) * size
		_star.rotation.z = t * 0.6
		_star_mat.albedo_color.a = pow(1.0 - clampf(_age / 0.22, 0.0, 1.0), 1.5)
	if _lamp != null:
		_lamp.light_energy = 5.0 * size * pow(1.0 - clampf(_age / 0.25, 0.0, 1.0), 2.0)


## A four-pointed star with a hot core, drawn once.
static func _star_texture() -> ImageTexture:
	if _star_tex != null:
		return _star_tex
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var dx := (x - c) / c
			var dy := (y - c) / c
			var r := sqrt(dx * dx + dy * dy)
			var core := clampf(1.0 - r / 0.35, 0.0, 1.0)
			var rays := maxf(clampf(1.0 - absf(dx) / 0.07, 0.0, 1.0) * clampf(1.0 - absf(dy), 0.0, 1.0),
					clampf(1.0 - absf(dy) / 0.07, 0.0, 1.0) * clampf(1.0 - absf(dx), 0.0, 1.0))
			var a := clampf(core * core + rays * rays * 0.9, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_star_tex = ImageTexture.create_from_image(img)
	return _star_tex


static func _spark_texture() -> ImageTexture:
	if _spark_tex != null:
		return _spark_tex
	var w := 8
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var across := 1.0 - absf((x - (w - 1) * 0.5) / ((w - 1) * 0.5))
			var along := 1.0 - absf((y - (h - 1) * 0.5) / ((h - 1) * 0.5))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(across * across * along, 0.0, 1.0)))
	_spark_tex = ImageTexture.create_from_image(img)
	return _spark_tex
