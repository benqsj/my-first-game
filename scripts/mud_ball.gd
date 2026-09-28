class_name MudBall
extends Node3D

## A lump of mud a puglin throws. Every peer flies its own on the same arc; the
## host's is the one that hits. What it hits is told back to the thrower
## (`mud_landed`).
##
## Made to be seen coming: a fist-sized lump, lumpy and wet-shining with a pale
## rim round it so it stands off the ground behind it, spinning, shedding drops
## as it goes, with a dark spot on the ground under it that says where the arc
## is; a slap and a spray of drops where it lands, and a patch that dries.

const GRAVITY := 12.0
const RADIUS := 0.2
const LIFE := 4.0
const SPLAT_SOUND := "res://unverified/sounds/all/land.wav"
const THROW_SOUND := "res://unverified/sounds/all/jump.wav"

var _vel: Vector3 = Vector3.ZERO
var _thrower: Node3D
var _host: bool = false
var _age: float = 0.0
var _done: bool = false
var _lump: MeshInstance3D
var _shadow: MeshInstance3D
var _drip_in: float = 0.0

static var _material: StandardMaterial3D
static var _lump_mesh: ArrayMesh
static var _drop_mesh: SphereMesh
static var _shadow_mat: StandardMaterial3D


static func fling(world: Node, from: Vector3, vel: Vector3, thrower: Node3D, host: bool) -> MudBall:
	var ball := MudBall.new()
	ball._vel = vel
	ball._thrower = thrower
	ball._host = host
	world.add_child(ball)
	ball.global_position = from
	Sfx.play(world, THROW_SOUND, null, from, 0.62, -8.0)
	return ball


## Wet mud: dark brown, glossy, a pale rim so a lump reads against earth.
static func mud() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = Color(0.3, 0.19, 0.09)
		_material.roughness = 0.35
		_material.clearcoat_enabled = true
		_material.clearcoat = 0.8
		_material.clearcoat_roughness = 0.15
		_material.rim_enabled = true
		_material.rim = 0.7
		_material.rim_tint = 0.35
	return _material


## A lump rather than a ball: a sphere pushed in and out by a few lobes.
static func lump_mesh() -> ArrayMesh:
	if _lump_mesh == null:
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 14
		s.rings = 8
		var arrays := s.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var lobes := [Vector3(1, 0.3, 0.2), Vector3(-0.4, 1, 0.3), Vector3(0.2, -0.5, 1), Vector3(-0.7, -0.6, -0.5)]
		for i in verts.size():
			var v := verts[i]
			var n := v.normalized()
			var k := 1.0
			for l: Vector3 in lobes:
				k += 0.16 * maxf(n.dot(l.normalized()), 0.0) ** 3
			k -= 0.08 * absf(sin(n.x * 7.0) * sin(n.y * 5.0 + 1.0))
			verts[i] = n * k * RADIUS
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = null
		arrays[Mesh.ARRAY_TANGENT] = null
		var st := SurfaceTool.new()
		var raw := ArrayMesh.new()
		raw.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		st.create_from(raw, 0)
		st.generate_normals()
		_lump_mesh = st.commit()
	return _lump_mesh


static func drop_mesh() -> SphereMesh:
	if _drop_mesh == null:
		_drop_mesh = SphereMesh.new()
		_drop_mesh.radius = 1.0
		_drop_mesh.height = 2.0
		_drop_mesh.radial_segments = 6
		_drop_mesh.rings = 3
	return _drop_mesh


func _ready() -> void:
	top_level = true
	_lump = MeshInstance3D.new()
	_lump.mesh = lump_mesh()
	_lump.material_override = mud()
	add_child(_lump)
	if _shadow_mat == null:
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.albedo_color = Color(0.05, 0.03, 0.02, 0.55)
		_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS * 1.3
	disc.bottom_radius = RADIUS * 1.3
	disc.height = 0.005
	disc.radial_segments = 14
	_shadow.mesh = disc
	_shadow.material_override = _shadow_mat
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	add_child(_shadow)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	var from := global_position
	_vel.y -= GRAVITY * delta
	var to := from + _vel * delta
	_lump.rotate_object_local(Vector3(1, 0.3, 0).normalized(), 9.0 * delta)
	# Squashed along the way it flies, a little.
	_lump.scale = Vector3(0.9, 0.9, 1.15)
	if _host and _thrower != null and is_instance_valid(_thrower):
		for node in get_tree().get_nodes_in_group("player"):
			var who := node as Node3D
			if who == null:
				continue
			var low := who.global_position + Vector3.UP * 0.3
			var high := who.global_position + Vector3.UP * 1.7
			if WeaponSweep.touches(from, to, RADIUS + 0.35, low, high):
				_thrower.call(&"mud_landed", who)
				_splash(to, false)
				return
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	if not hit.is_empty():
		_splash(hit["position"], true, hit["normal"])
		return
	global_position = to
	# The spot under it.
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(to, to + Vector3.DOWN * 30.0, 1))
	if down.is_empty():
		_shadow.visible = false
	else:
		var ground: Vector3 = down["position"]
		var high := to.y - ground.y
		_shadow.visible = true
		_shadow.global_position = ground + Vector3.UP * 0.03
		var grow := 1.0 + high * 0.15
		_shadow.scale = Vector3(grow, 1.0, grow)
		_shadow.transparency = clampf(high / 8.0, 0.0, 0.85)
	# Drops flung off it.
	_drip_in -= delta
	if _drip_in <= 0.0:
		_drip_in = 0.035
		MudDrop.spawn(get_parent(), to, _vel * 0.2 + Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)),
				randf_range(0.03, 0.06))
	if _age > LIFE:
		queue_free()


func _splash(at: Vector3, ground: bool, normal: Vector3 = Vector3.UP) -> void:
	_done = true
	var world := get_parent()
	DustRing.burst(world, at, 0.45)
	for i in 14:
		var out := Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized() * randf_range(1.5, 4.0)
		MudDrop.spawn(world, at + Vector3.UP * 0.1, out + normal * randf_range(1.5, 4.0), randf_range(0.03, 0.08))
	Sfx.play(world, SPLAT_SOUND, null, at, randf_range(0.5, 0.6), -4.0)
	if ground and normal.y > 0.6:
		var patch := MudPatch.new()
		world.add_child(patch)
		patch.global_position = at + normal * 0.02
	queue_free()


## A drop of mud off a lump or out of its splash, falling, gone when it lands.
class MudDrop extends MeshInstance3D:
	var _v := Vector3.ZERO
	var _t := 0.0

	static func spawn(world: Node, at: Vector3, vel: Vector3, size: float) -> void:
		var d := MudDrop.new()
		d._v = vel
		d.mesh = MudBall.drop_mesh()
		d.material_override = MudBall.mud()
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d.scale = Vector3.ONE * size
		world.add_child(d)
		d.global_position = at

	func _process(delta: float) -> void:
		_t += delta
		_v.y -= MudBall.GRAVITY * delta
		global_position += _v * delta
		if _t > 0.9 or global_position.y < -50.0:
			queue_free()


## The brown patch a lump leaves on the ground, drying away.
class MudPatch extends MeshInstance3D:
	var _age := 0.0
	var _mat: StandardMaterial3D

	func _ready() -> void:
		var disc := CylinderMesh.new()
		disc.top_radius = 0.45
		disc.bottom_radius = 0.45
		disc.height = 0.01
		disc.radial_segments = 14
		mesh = disc
		_mat = MudBall.mud().duplicate() as StandardMaterial3D
		_mat.rim_enabled = false
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material_override = _mat
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rotate_y(randf() * TAU)
		scale = Vector3(randf_range(0.7, 1.3), 1.0, randf_range(0.7, 1.3))

	func _process(delta: float) -> void:
		_age += delta
		if _age > 6.0:
			_mat.albedo_color.a = clampf(1.0 - (_age - 6.0) / 3.0, 0.0, 1.0)
			if _age > 9.0:
				queue_free()
