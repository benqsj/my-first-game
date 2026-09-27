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
## Down, it falls over onto its length rather than standing on its end: the
## turn that lays it flat, and how far through it is.
var _toppling: bool = false
var _lie_from: Basis
var _lie_to: Basis
var _lie_t: float = 0.0


## Throws the piece clear of the body. Called right after it is added to the
## tree, so the limb is already moving on the frame it comes off. `blow`: the
## way the blade was going, when it is known — the piece goes with the blade,
## a little out from the body, and turns end over end about the line the blade
## cut across rather than spinning every way at once.
func launch(away: Vector3, blow: Vector3 = Vector3.ZERO) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var sideways := away.normalized() if away.length_squared() > 0.001 else Vector3.FORWARD
	var swing := Vector3(blow.x, 0.0, blow.z)
	if swing.length_squared() > 0.01:
		swing = swing.normalized()
		_velocity = swing * rng.randf_range(2.6, 4.2) + sideways * rng.randf_range(0.6, 1.4) \
				+ Vector3(0.0, rng.randf_range(1.6, 2.8), 0.0)
		var over := Vector3.UP.cross(swing).normalized()
		spin = over * rng.randf_range(7.0, 11.0) + Vector3(rng.randfn(0.0, 1.5), rng.randfn(0.0, 1.5), rng.randfn(0.0, 1.5))
	else:
		_velocity = sideways * rng.randf_range(2.0, 4.0) \
				+ Vector3(rng.randfn(0.0, 0.8), rng.randf_range(1.8, 3.2), rng.randfn(0.0, 0.8))
		spin = Vector3(rng.randfn(0.0, 6.0), rng.randfn(0.0, 6.0), rng.randfn(0.0, 6.0))


func _process(delta: float) -> void:
	_age += delta
	if _age > lifetime:
		queue_free()
		return
	# Its last second it fades out, the way the body it came off does.
	if _age > lifetime - 1.0:
		var gone := clampf(_age - (lifetime - 1.0), 0.0, 1.0)
		for node in find_children("*", "GeometryInstance3D", true, false):
			(node as GeometryInstance3D).transparency = gone
	if _resting:
		return
	if _toppling:
		_topple(delta)
		return

	_velocity.y -= _gravity * delta
	global_position += _velocity * delta
	if spin.length_squared() > 0.0001:
		global_rotate(spin.normalized(), spin.length() * delta)
		# Slowed by the air a little: it tumbles, it is not a propeller.
		spin *= exp(-0.4 * delta)

	var ground := _ground_under()
	var low := _lowest()
	if low <= ground + 0.02 and _velocity.y < 0.0:
		global_position.y += ground + 0.02 - low
		Blood.splatter(get_parent(), Vector3(global_position.x, ground, global_position.z), Vector3.UP)
		_begin_topple()
	elif global_position.y < ground - 30.0:
		# Fell through a hole in the world: nothing to show.
		queue_free()


## Its length, as it lies now: between the two points of it furthest apart.
func _length_axis() -> Vector3:
	if _points.is_empty():
		return Vector3.UP
	var a := _points[0]
	var b := a
	for p in _points:
		if p.distance_squared_to(a) > b.distance_squared_to(a):
			b = p
	var c := b
	for p in _points:
		if p.distance_squared_to(b) > c.distance_squared_to(b):
			c = p
	var axis := global_transform.basis * (c - b)
	return axis.normalized() if axis.length() > 0.01 else Vector3.UP


func _begin_topple() -> void:
	var axis := _length_axis()
	var flat := Vector3(axis.x, 0.0, axis.z)
	if flat.length() < 0.05:
		var turn := randf() * TAU
		flat = Vector3(cos(turn), 0.0, sin(turn))
	flat = flat.normalized()
	_lie_from = global_transform.basis
	var tilt := Quaternion(axis, flat) if absf(axis.dot(flat)) < 0.9999 else Quaternion.IDENTITY
	_lie_to = Basis(tilt) * _lie_from
	_lie_t = 0.0
	_toppling = true


func _topple(delta: float) -> void:
	_lie_t = minf(_lie_t + delta / 0.3, 1.0)
	var e := _lie_t * _lie_t
	var q := Quaternion(_lie_from.orthonormalized()).slerp(Quaternion(_lie_to.orthonormalized()), e)
	var grow := _lie_from.get_scale()
	global_transform.basis = Basis(q).scaled(grow)
	# Kept with its lowest point on the ground as it goes over.
	global_position.y += _ground_under() + 0.02 - _lowest()
	if _lie_t >= 1.0:
		_toppling = false
		_resting = true


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


## Points on the piece's surface, in its own frame, taken once: what its lowest
## point is measured from. (The box round a turned mesh reaches lower than the
## mesh does, and stopping on that left pieces hanging a hand over the ground.)
var _points: PackedVector3Array = PackedVector3Array()


## The lowest point of the piece as it hangs now.
func _lowest() -> float:
	if _points.is_empty():
		var mine := global_transform.affine_inverse()
		for node in find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if mesh.mesh == null:
				continue
			var into := mine * mesh.global_transform
			var faces := mesh.mesh.get_faces()
			var step := maxi(1, faces.size() / 400)
			for i in range(0, faces.size(), step):
				_points.append(into * faces[i])
		if _points.is_empty():
			return global_position.y
	var low := INF
	var frame := global_transform
	for p in _points:
		low = minf(low, (frame * p).y)
	return low
