class_name SeveredLimb
extends Node3D

## A limb that has been cut off. It keeps the pose it was in, falls, tumbles a
## little and settles on the ground — enough to see it come away and land,
## without a rigid body per piece.
##
## The ground is the world's, found by a ray straight down (not a height of
## zero: the land rolls, and the bay lies below it), and the piece stops when
## the lowest of its meshes reaches it — not its pivot, which is the joint it
## was cut at, often half a limb above the part that touches down.

@export var spin: Vector3 = Vector3.ZERO
@export var lifetime: float = 25.0

var _velocity: Vector3 = Vector3.ZERO
var _resting: bool = false
var _age: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
## Where the ground under it is, found again as it moves.
var _ground_y: float = -INF
var _probe_at := Vector3(INF, INF, INF)


## Throws the piece clear of the body. Called right after it is added to the
## tree, so the limb is already moving on the frame it comes off.
func launch(away: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var sideways := away.normalized() if away.length_squared() > 0.001 else Vector3.FORWARD
	_velocity = sideways * rng.randf_range(2.0, 4.0) \
			+ Vector3(rng.randfn(0.0, 0.8), rng.randf_range(1.8, 3.2), rng.randfn(0.0, 0.8))
	spin = Vector3(rng.randfn(0.0, 6.0), rng.randfn(0.0, 6.0), rng.randfn(0.0, 6.0))


func _process(delta: float) -> void:
	_age += delta
	if _age > lifetime:
		queue_free()
		return
	if _resting:
		return

	_velocity.y -= _gravity * delta
	global_position += _velocity * delta
	rotation += spin * delta

	var ground := _ground_under()
	var low := _lowest()
	if low <= ground + 0.02 and _velocity.y < 0.0:
		global_position.y += ground + 0.02 - low
		_resting = true
		Blood.splatter(get_parent(), Vector3(global_position.x, ground, global_position.z), Vector3.UP)
	elif global_position.y < ground - 30.0:
		# Fell through a hole in the world: nothing to show.
		queue_free()


## The height of the ground straight below, looked up again once it has moved
## a little way over it.
func _ground_under() -> float:
	var here := global_position
	if Vector2(here.x - _probe_at.x, here.z - _probe_at.z).length() < 0.25 and _ground_y > -INF:
		return _ground_y
	_probe_at = here
	var world := get_world_3d()
	if world == null:
		return 0.0
	# From just above it: from higher up the ray could find a step or a roof
	# over it, and set it on top.
	var ray := PhysicsRayQueryParameters3D.create(here + Vector3.UP * 0.6, here + Vector3.DOWN * 60.0, 1)
	var hit := world.direct_space_state.intersect_ray(ray)
	_ground_y = (hit.position as Vector3).y if not hit.is_empty() else 0.0
	return _ground_y


## The lowest point of the piece as it hangs now.
func _lowest() -> float:
	var low := INF
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh != null:
			low = minf(low, (mesh.global_transform * mesh.get_aabb()).position.y)
	return low if low < INF else global_position.y
