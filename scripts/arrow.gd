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
##
## Most of this file is about being *seen*. A centimetre-wide shaft crossing half
## a metre a frame, viewed end-on because that is where the camera is, is a thing
## nobody can react to. What carries the shot is the **air it cuts**: a thin pale
## line down the flight path with a wider, fainter wake either side of it, and a
## roll on the shaft.
##
## Deliberately not light. An earlier pass gave the head a glow and put a flare
## at each end of the flight, and what that read as was an explosion crossing the
## field — the shot stopped looking like an arrow. Nothing here goes past white
## or flares: a slipstream is displaced air, and displaced air does not shine.

signal struck(what: Node3D, where: Vector3, critical: bool)

## How long a spent arrow stays in the world before it goes.
@export var linger: float = 6.0
## And how long it takes to sink out of sight once that is up.
@export var sink_time: float = 1.0
## Longest an arrow may be in the air before it is given up on, in seconds.
@export var lifetime: float = 6.0
## How far past the surface it buries itself.
@export var bite: float = 0.12
## How wide the line down the flight path is, in metres, and how much wider the
## wake either side of it is. An arrow is a centimetre across and crosses half a
## metre between one frame and the next, so on its own it is a thing that is
## never actually on screen where you are looking. The line is what makes a shot
## something an opponent can see coming — and duck.
@export var trail_width: float = 0.05
@export var wake_spread: float = 4.5
## How fast the shaft rolls in flight, in turns a second. Fletching spins an
## arrow, and a spinning arrow reads as a thing in flight rather than a sliding
## decal — at this speed it is the flicker of it that is seen, not the turn.
@export var spin: float = 2.4
## The colours of cut air. Kept **at or under white on every channel**: past one
## they run into the glow pass and the shot reads as something burning rather
## than something flying.
@export var streak_tint: Color = Color(1.0, 0.99, 0.95, 0.6)
@export var wake_tint: Color = Color(0.88, 0.92, 0.98, 0.17)
## A shot that lands hard cuts the same air, only a little warmer.
@export var crit_tint: Color = Color(1.0, 0.85, 0.62, 0.7)

var _velocity: Vector3 = Vector3.ZERO
var _gravity: float = 6.0
var _damage: float = 0.0
var _critical: bool = false
var _shooter: Node3D = null
var _spent: bool = false
## The line down the flight path, and the wider wake either side of it.
var _trail: SwordTrail
var _wake: SwordTrail
var _age: float = 0.0
var _rested: float = 0.0
## How far the shaft has rolled.
var _roll: float = 0.0
## Carries the trail markers, turned back against the roll so the streak stays
## flat while the shaft spins inside it.
var _steady: Node3D


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
	_lay_trail()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _spent:
		_settle(delta)
		return

	_age += delta
	if _age > lifetime:
		for ribbon in [_trail, _wake]:
			if ribbon != null:
				ribbon.queue_free()
		queue_free()
		return

	_velocity.y -= _gravity * delta
	_roll += TAU * spin * delta
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
	for ribbon in [_trail, _wake]:
		if ribbon == null:
			continue
		# Stops feeding the ribbon; it fades itself out from there and then goes.
		ribbon.emitting = false
		ribbon.get_tree().create_timer(ribbon.fade_time + 0.1).timeout.connect(
				ribbon.queue_free)
	_trail = null
	_wake = null
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


## Hangs the cut air off the arrow.
##
## Two ribbons, both the one the sword leaves, given a segment that lies *across*
## the flight rather than along it — so what each sweeps out is a flat band down
## the arrow's path. They write world positions, so they live in the world beside
## the arrow rather than on it, and they outlive the arrow by a fade.
##
## The narrow one is the line the head draws; the wide one is the air pushed
## aside around it, fainter and gone sooner. Two of them rather than one wide
## band because that is the difference between air parting and a searchlight: the
## edge of the wake has to be soft where the line down the middle is not.
func _lay_trail() -> void:
	var into := get_parent()
	if into == null or trail_width <= 0.0:
		return
	# Hung off a node that undoes the roll. The bands have to stay flat sheets
	# down the flight path; carried on a shaft that is spinning they would wind
	# into a corkscrew and pinch to nothing twice a turn.
	_steady = Node3D.new()
	_steady.name = "Steady"
	add_child(_steady)

	var line := crit_tint if _critical else streak_tint
	# Long enough to be a line across the field rather than a smear behind the
	# head: at forty metres a second, twenty samples is most of a second of
	# flight held on screen at once.
	_trail = _ribbon(into, "ArrowTrail", trail_width, line, 20, 0.30, 0.85)
	if wake_spread > 1.0:
		# Even across the band: the wake is air, and air has no bright edge.
		_wake = _ribbon(into, "ArrowWake", trail_width * wake_spread,
				wake_tint, 12, 0.16, 1.0)


## One band of swept air: a pair of markers `width` apart on the steady node, and
## a ribbon stitched between wherever they have been.
func _ribbon(into: Node, ribbon_name: String, width: float, tint: Color,
		samples: int, fade: float, inner: float) -> SwordTrail:
	var left := Marker3D.new()
	left.position = Vector3(-width * 0.5, 0.0, 0.0)
	_steady.add_child(left)
	var right := Marker3D.new()
	right.position = Vector3(width * 0.5, 0.0, 0.0)
	_steady.add_child(right)

	var ribbon := SwordTrail.new()
	ribbon.name = ribbon_name
	ribbon.sample_count = samples
	ribbon.fade_time = fade
	ribbon.inner_edge_alpha = inner
	ribbon.tint = tint
	into.add_child(ribbon)
	ribbon.setup(left, right)
	ribbon.emitting = true
	return ribbon


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
	var aimed := Basis(side, forward, side.cross(forward)).orthonormalized()
	# Rolled about its own shaft: the fletching spins an arrow, and the flicker
	# that comes off it is most of what makes one readable in the air. The shaft
	# runs up local +Y, so the roll is a turn about that.
	global_transform.basis = aimed.rotated(forward, _roll)
	if _steady != null:
		_steady.rotation = Vector3(0.0, -_roll, 0.0)
