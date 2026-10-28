class_name WallSteer
extends RefCounted

## Going round what stands in the way (the user's word, 2026-10-28: the
## creatures stuck in the walls; they should go round and come at him so).
## There is no navigation mesh: a creature walks straight at where it is
## going. Each one has one of these: before it steps, it feels ahead (a ray
## at its middle and one at each shoulder, against the world only) and, the
## way blocked, turns a little more aside each try until it finds a way that
## is open, keeping to the one side it chose until the way ahead is clear
## again. Asking to move but going nowhere a while, it takes the other side.

## How far ahead it feels, at most; the height it feels at (over a step).
const FEEL := 2.4
const HEIGHT := 0.75
## How far aside it turns, try by try (degrees).
const TURNS := [30.0, 55.0, 80.0, 105.0, 135.0]
## Feeling again only so often (seconds).
const EVERY := 0.1
## After the way is clear, it keeps its side this long (so not to swing).
const KEEP := 0.5
## Going nowhere this long while it asks to move: the other side.
const SNAGGED := 0.7

var _side := 0.0
var _keep := 0.0
var _next := 0.0
var _way := Vector3.ZERO
var _aim := Vector3.ZERO
var _snag := 0.0
var _flip := 0.0


## The way `body` should go to head `direction` (flat, unit), `far` metres
## from where it is going, at `pace`.
func way(body: CharacterBody3D, direction: Vector3, far: float, pace: float, delta: float) -> Vector3:
	_keep = maxf(_keep - delta, 0.0)
	_next -= delta
	_flip = maxf(_flip - delta, 0.0)
	# going nowhere while it asks to go: the other side for a while
	var real := body.get_real_velocity()
	real.y = 0.0
	if pace > 0.5 and real.length() < pace * 0.2:
		_snag += delta
	else:
		_snag = maxf(_snag - delta * 2.0, 0.0)
	if _snag >= SNAGGED:
		_snag = 0.0
		_side = -_side if _side != 0.0 else (1.0 if randf() < 0.5 else -1.0)
		_keep = 1.0
		_flip = 1.0
		_next = 0.0
	if far < 1.2:
		return direction
	if _next > 0.0 and _aim.dot(direction) > 0.97 and _way != Vector3.ZERO:
		return _way
	_next = EVERY
	_aim = direction
	var reach := minf(FEEL, far)
	if _flip <= 0.0 and _open(body, direction, reach):
		if _keep <= 0.0:
			_side = 0.0
		_way = direction
		return direction
	var sides: Array = [1.0, -1.0]
	if _side != 0.0:
		sides = [_side]
	elif randf() < 0.5:
		sides = [-1.0, 1.0]
	for turn: float in TURNS:
		for s: float in sides:
			var d := direction.rotated(Vector3.UP, deg_to_rad(turn) * s)
			if _open(body, d, FEEL * 0.8):
				_side = s
				_keep = KEEP
				_way = d
				return d
	# shut in all round ahead: back along its side
	if _side == 0.0:
		_side = sides[0]
	_way = direction.rotated(Vector3.UP, deg_to_rad(150.0) * _side)
	return _way


## Whether the world leaves `body` room `reach` metres along `d`.
func _open(body: CharacterBody3D, d: Vector3, reach: float) -> bool:
	var space := body.get_world_3d().direct_space_state
	var side := d.cross(Vector3.UP).normalized()
	var r := 0.4
	var given: Variant = body.get(&"body_radius")
	if given is float:
		r = float(given) * maxf(float(body.get(&"visual_scale")) if body.get(&"visual_scale") is float else 1.0, 0.5)
	r = clampf(r, 0.25, 1.6)
	var base := body.global_position + Vector3.UP * HEIGHT
	for off: float in [0.0, -0.85, 0.85]:
		var from := base + side * r * off
		var q := PhysicsRayQueryParameters3D.create(from, from + d * (reach + r), 1, [body.get_rid()])
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and (hit["normal"] as Vector3).y < 0.6:
			return false
	return true
