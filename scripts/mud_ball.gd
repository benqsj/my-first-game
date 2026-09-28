class_name MudBall
extends Node3D

## A lump of mud a puglin throws. Every peer flies its own on the same arc; the
## host's is the one that hits. What it hits is told back to the thrower
## (`mud_landed`); what it lands on gets a splash and a brown patch that dries.

const GRAVITY := 12.0
const RADIUS := 0.13
const LIFE := 4.0

var _vel: Vector3 = Vector3.ZERO
var _thrower: Node3D
var _host: bool = false
var _age: float = 0.0
var _done: bool = false
var _lump: MeshInstance3D

static var _material: StandardMaterial3D


static func fling(world: Node, from: Vector3, vel: Vector3, thrower: Node3D, host: bool) -> MudBall:
	var ball := MudBall.new()
	ball._vel = vel
	ball._thrower = thrower
	ball._host = host
	world.add_child(ball)
	ball.global_position = from
	return ball


static func mud() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = Color(0.2, 0.13, 0.07)
		_material.roughness = 0.95
		_material.metallic_specular = 0.2
	return _material


func _ready() -> void:
	_lump = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 1.7
	sphere.radial_segments = 10
	sphere.rings = 6
	_lump.mesh = sphere
	_lump.material_override = mud()
	_lump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lump)
	top_level = true


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	var from := global_position
	_vel.y -= GRAVITY * delta
	var to := from + _vel * delta
	_lump.rotate_object_local(Vector3(1, 0.3, 0).normalized(), 9.0 * delta)
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
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := space.intersect_ray(ray)
	if not hit.is_empty():
		_splash(hit["position"], true, hit["normal"])
		return
	global_position = to
	if _age > LIFE:
		queue_free()


func _splash(at: Vector3, ground: bool, normal: Vector3 = Vector3.UP) -> void:
	_done = true
	var world := get_parent()
	DustRing.burst(world, at, 0.3)
	if ground and normal.y > 0.6:
		var patch := MudPatch.new()
		world.add_child(patch)
		patch.global_position = at + normal * 0.02
	queue_free()


## The brown patch a lump leaves on the ground, drying away.
class MudPatch extends MeshInstance3D:
	var _age := 0.0
	var _mat: StandardMaterial3D

	func _ready() -> void:
		var disc := CylinderMesh.new()
		disc.top_radius = 0.35
		disc.bottom_radius = 0.35
		disc.height = 0.01
		disc.radial_segments = 12
		mesh = disc
		_mat = MudBall.mud().duplicate() as StandardMaterial3D
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
