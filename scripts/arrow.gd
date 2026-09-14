class_name Arrow
extends Node3D

## An arrow in flight.
##
## It is not a physics body. An arrow crosses more ground in one tick than it is
## long — at 46 m/s that is three quarters of a metre — so a collider would fly
## through a wolf as often as it hit one. Instead each tick draws a line from
## where it was to where it is going and asks what that line crossed, which
## cannot be tunnelled through however fast the arrow goes.
##
## What it hits it tells. Anything with a `take_hit()` takes the damage; anything
## else just stops it. Sticking in what it hit rather than vanishing is most of
## what makes a shot feel landed.

signal struck(what: Node3D, where: Vector3, critical: bool)

## How long a spent arrow stays in the world before it goes.
@export var linger: float = 6.0
## And how long it takes to sink out of sight once that is up.
@export var sink_time: float = 1.0
## Longest an arrow may be in the air before it is given up on, in seconds.
@export var lifetime: float = 6.0
## How far past the surface it buries itself.
@export var bite: float = 0.12

var _velocity: Vector3 = Vector3.ZERO
var _gravity: float = 6.0
var _damage: float = 0.0
var _critical: bool = false
var _shooter: Node3D = null
var _spent: bool = false
var _age: float = 0.0
var _rested: float = 0.0


func _ready() -> void:
	set_physics_process(false)


## Sends it on its way. Everything about the shot is decided by whoever loosed
## it — how hard it was drawn is their business, not the arrow's.
func launch(velocity: Vector3, damage: float, critical: bool, gravity: float,
		shooter: Node3D) -> void:
	_velocity = velocity
	_damage = damage
	_critical = critical
	_gravity = gravity
	_shooter = shooter
	_point_along(velocity)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _spent:
		_settle(delta)
		return

	_age += delta
	if _age > lifetime:
		queue_free()
		return

	_velocity.y -= _gravity * delta
	var step := _velocity * delta
	var hit := _sweep(global_position, global_position + step)
	if hit.is_empty():
		global_position += step
		# An arrow turns to follow its own arc, which is what makes the drop
		# read as a drop rather than a slide.
		_point_along(_velocity)
		return

	global_position = (hit["position"] as Vector3) + _velocity.normalized() * bite
	_strike(hit["collider"] as Node3D, hit["position"] as Vector3)


## What the arrow crossed between one tick and the next, if anything.
func _sweep(from: Vector3, to: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if _shooter is CollisionObject3D:
		exclude.append((_shooter as CollisionObject3D).get_rid())
	# World and enemies: the same things the player's own capsule collides with.
	var query := PhysicsRayQueryParameters3D.create(from, to, 5, exclude)
	return space.intersect_ray(query)


func _strike(what: Node3D, where: Vector3) -> void:
	_spent = true
	_velocity = Vector3.ZERO
	struck.emit(what, where, _critical)

	if what != null and what.has_method("take_hit"):
		var blow := -global_transform.basis.y
		what.call("take_hit", _damage, where, blow, _critical)
		# Arrows that land in something ride it rather than hanging in the air
		# where it used to be. Deferred, because moving a node between parents
		# in the middle of a physics step is asking the tree to change under the
		# solver that is walking it.
		reparent.call_deferred(what, true)


## Sits in whatever it landed in, then sinks away. Arrows that never leave carve
## the ground up into a pincushion and cost a draw call each.
func _settle(delta: float) -> void:
	_rested += delta
	if _rested < linger:
		return
	if _rested - linger >= sink_time:
		queue_free()
		return
	global_position += Vector3.DOWN * delta * 0.35


## Points the shaft along the way it is going. The model is built running up its
## own +Y, so that axis is the one aimed.
func _point_along(heading: Vector3) -> void:
	if heading.length_squared() < 0.0001:
		return
	var forward := heading.normalized()
	var side := forward.cross(Vector3.UP)
	if side.length_squared() < 1e-6:
		side = forward.cross(Vector3.RIGHT)
	side = side.normalized()
	global_transform.basis = Basis(side, forward, side.cross(forward)).orthonormalized()
