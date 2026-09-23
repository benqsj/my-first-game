class_name Venom
extends Node3D

## Arkdeva's poison, as it is seen: a gob lobbed on an arc, dripping as it goes,
## that bursts where it lands and leaves a pool eating into the ground.
##
## The shapes are modelled (`assets/fx/venom.glb`, from `fx/venom.blend` in the
## art folder): a teardrop gob that flies nose first, a falling drop, and a
## splat — lobes, a few short runs and a scatter of droplets round it — rather
## than the sphere and the flat green disc there were before. The disc was the
## part that looked wrong: a perfect circle of flat unlit green, stamped on the
## ground at one height whatever the ground was doing.
##
## * **In flight** the gob wobbles (the shader moves its skin), glows at its
##   rim, turns to face the way it is going, and sheds drops behind it that
##   fall under gravity.
## * **Landing** throws a burst of droplets up and out.
## * **The pool** lies on the ground as the ground lies: it is laid down along
##   the surface under it, found with a ray, so on a slope it is on the slope.
##   It runs out from the middle to its full size in a third of a second, with
##   a ragged front, bubbles while it lasts, and dries from the edges inwards
##   before it goes. Its wet surface is lit like a liquid, not painted on.
##
## All of it is looks, on every peer. Who is hurt is the host's business, in
## [Arkdeva].

const MODEL := "res://assets/fx/venom.glb"
const GLOB_SHADER := "res://assets/fx/venom.gdshader"
const POOL_SHADER := "res://assets/fx/venom_pool.gdshader"

enum Kind { GOB, POOL, SPLASH }

static var _meshes: Dictionary = {}
static var _gob_material: ShaderMaterial
static var _pool_material: ShaderMaterial
static var _noise: NoiseTexture2D

var _kind: int = Kind.GOB
var _t: float = 0.0
var _end: float = 1.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _flight: float = 0.6
var _arc: float = 0.8
var _size: float = 1.0
var _into: Node
var _body: MeshInstance3D
var _trail: GPUParticles3D


## A gob from `from` to `to`, `flight` seconds in the air, `size` times the
## size it is modelled at.
static func spit(into: Node, from: Vector3, to: Vector3, flight: float = 0.6,
		arc: float = 0.8, size: float = 1.0) -> Venom:
	if into == null:
		return null
	var fx := Venom.new()
	fx.name = "VenomGob"
	fx._kind = Kind.GOB
	fx._from = from
	fx._to = to
	fx._flight = maxf(flight, 0.05)
	fx._arc = arc
	fx._size = size
	fx._end = flight
	fx._into = into
	fx._body = MeshInstance3D.new()
	fx._body.mesh = mesh(&"VenomGlob")
	fx._body.material_override = gob_material()
	fx._body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx._body.scale = Vector3.ONE * 0.26 * size
	fx.add_child(fx._body)
	fx._trail = _drops(0.07 * size, 26, 0.55, false)
	fx._trail.emitting = true
	fx.add_child(fx._trail)
	fx.top_level = true
	into.add_child(fx)
	fx.global_position = from
	return fx


## The pool a gob leaves, `radius` metres across the middle of it, for `life`
## seconds.
static func pool(into: Node, at: Vector3, radius: float = 1.1, life: float = 3.5) -> Venom:
	if into == null:
		return null
	var fx := Venom.new()
	fx.name = "VenomPool"
	fx._kind = Kind.POOL
	fx._end = life
	fx._size = radius
	fx._body = MeshInstance3D.new()
	fx._body.mesh = mesh(&"VenomSplat")
	fx._body.material_override = pool_material()
	fx._body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx._body.set_instance_shader_parameter(&"spread", 0.0)
	fx._body.set_instance_shader_parameter(&"dry", 0.0)
	fx._body.set_instance_shader_parameter(&"seed", randf() * 10.0)
	fx.add_child(fx._body)
	fx.top_level = true
	into.add_child(fx)
	# Lie on whatever is under it.
	var up := Vector3.UP
	var ground := at
	var world: World3D = (into as Node3D).get_world_3d() if into is Node3D else null
	if world != null:
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at + Vector3.DOWN * 2.5, 1)
		var hit := world.direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			ground = hit["position"]
			up = (hit["normal"] as Vector3).normalized()
	var across := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(across, up, across.cross(up)).rotated(up, randf() * TAU)
	fx.global_transform = Transform3D(basis.scaled(Vector3(radius, radius, radius)), ground + up * 0.02)
	return fx


## Droplets thrown up and out where a gob lands.
static func splash(into: Node, at: Vector3, size: float = 1.0) -> Venom:
	if into == null:
		return null
	var fx := Venom.new()
	fx.name = "VenomSplash"
	fx._kind = Kind.SPLASH
	fx._end = 1.2
	var burst := _drops(0.09 * size, 22, 0.8, true)
	var process := burst.process_material as ParticleProcessMaterial
	process.direction = Vector3.UP
	process.spread = 65.0
	process.initial_velocity_min = 2.0 * sqrt(size)
	process.initial_velocity_max = 5.0 * sqrt(size)
	burst.emitting = true
	fx.add_child(burst)
	fx.top_level = true
	into.add_child(fx)
	fx.global_position = at + Vector3.UP * 0.1
	return fx


func _process(delta: float) -> void:
	_t += delta
	match _kind:
		Kind.GOB:
			var p := clampf(_t / _flight, 0.0, 1.0)
			var at := _position_at(p)
			var ahead := _position_at(minf(p + 0.05, 1.0)) - at
			global_position = at
			if ahead.length_squared() > 0.0001:
				_body.global_basis = Basis.looking_at(ahead.normalized(), Vector3.UP) \
						.scaled(Vector3.ONE * 0.26 * _size)
			if p >= 1.0:
				Venom.pool(_into, _to, 1.1 * _size, 3.5)
				Venom.splash(_into, _to, _size)
				queue_free()
				return
		Kind.POOL:
			var spread := 1.0 - pow(1.0 - clampf(_t / 0.35, 0.0, 1.0), 3.0)
			_body.set_instance_shader_parameter(&"spread", spread)
			_body.set_instance_shader_parameter(&"dry", clampf((_t - (_end - 1.3)) / 1.3, 0.0, 1.0))
	if _t >= _end:
		queue_free()


func _position_at(p: float) -> Vector3:
	var at := _from.lerp(_to, p)
	at.y += _arc * 4.0 * p * (1.0 - p)
	return at


#region Shapes and surfaces
static func mesh(which: StringName) -> Mesh:
	if _meshes.is_empty():
		if ResourceLoader.exists(MODEL):
			var scene := (load(MODEL) as PackedScene).instantiate()
			for node in scene.find_children("*", "MeshInstance3D", true, false):
				var m := node as MeshInstance3D
				_meshes[StringName(m.name)] = m.mesh
			scene.free()
		# Fallbacks, so a missing model is a plainer poison rather than none.
		if not _meshes.has(&"VenomGlob"):
			var ball := SphereMesh.new()
			ball.radius = 0.5
			ball.height = 1.0
			_meshes[&"VenomGlob"] = ball
			_meshes[&"VenomDrop"] = ball
		if not _meshes.has(&"VenomSplat"):
			var disc := CylinderMesh.new()
			disc.top_radius = 1.0
			disc.bottom_radius = 1.0
			disc.height = 0.02
			_meshes[&"VenomSplat"] = disc
	return _meshes.get(which, _meshes[&"VenomGlob"])


static func noise() -> NoiseTexture2D:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.02
		n.fractal_octaves = 3
		_noise = NoiseTexture2D.new()
		_noise.width = 128
		_noise.height = 128
		_noise.seamless = true
		_noise.noise = n
	return _noise


static func gob_material() -> ShaderMaterial:
	if _gob_material == null:
		_gob_material = ShaderMaterial.new()
		_gob_material.shader = load(GLOB_SHADER)
		_gob_material.set_shader_parameter(&"noise_tex", noise())
	return _gob_material


static func pool_material() -> ShaderMaterial:
	if _pool_material == null:
		_pool_material = ShaderMaterial.new()
		_pool_material.shader = load(POOL_SHADER)
		_pool_material.set_shader_parameter(&"noise_tex", noise())
	return _pool_material


## Drops of venom that fall: `amount` of them over `life` seconds each.
static func _drops(size: float, amount: int, life: float, burst: bool) -> GPUParticles3D:
	var drops := GPUParticles3D.new()
	drops.amount = amount
	drops.lifetime = life
	drops.one_shot = burst
	drops.explosiveness = 0.95 if burst else 0.0
	drops.local_coords = false
	drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drops.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	var process := ParticleProcessMaterial.new()
	process.gravity = Vector3(0.0, -14.0, 0.0)
	process.direction = Vector3.DOWN
	process.spread = 25.0
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.9
	process.scale_min = 0.6
	process.scale_max = 1.3
	# Drops shrink away rather than blink out.
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.7, 0.8))
	shrink.add_point(Vector2(1.0, 0.0))
	var curve := CurveTexture.new()
	curve.curve = shrink
	process.scale_curve = curve
	drops.process_material = process
	drops.draw_pass_1 = mesh(&"VenomDrop")
	drops.material_override = gob_material()
	# The drop mesh is a metre tall; the particles' own scale sets its size.
	process.scale_min *= size
	process.scale_max *= size
	return drops
#endregion
