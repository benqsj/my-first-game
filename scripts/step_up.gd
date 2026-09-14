class_name StepUp
extends Object

## Walking up a step.
##
## `CharacterBody3D` has no stair stepping of its own in 4.7 — a body walking
## into a 20 cm kerb stops dead against it — so anything on legs has to do it by
## hand. This was the knight's alone until the creatures needed it too: a wolf
## that cannot follow you up six stairs is a wolf you beat by standing on a
## step, which is not a fight.
##
## The move is the classic one: lift, push forward, drop. Each of the three is a
## `test_move()`, and any of them failing abandons the whole thing and leaves
## the obstacle a plain wall.

## Extra distance used when probing for an obstacle ahead of the body.
const SKIN := 0.05
## How many forward samples the sweep takes before giving up.
const SAMPLES := 4


## Puts `body` on top of whatever low ledge it has walked into, and reports
## whether it did.
##
## `height` is the tallest step that can be taken; `probe` is how far ahead the
## sweep reaches, and must exceed the body's own radius or the downward probe
## lands on the ledge's edge instead of its top face.
##
## Call it *before* `move_and_slide()`: it works from the velocity the body is
## about to move with, which afterwards has already been flattened against the
## step it failed to climb.
static func climb(body: CharacterBody3D, delta: float, height: float,
		probe: float) -> bool:
	if height <= 0.0 or not body.is_on_floor():
		return false

	var horizontal := Vector3(body.velocity.x, 0.0, body.velocity.z)
	if horizontal.length_squared() < 0.0001:
		return false
	var direction := horizontal.normalized()
	var from := body.global_transform
	var floor_cos := cos(body.floor_max_angle)

	# 1. Is a wall-like surface actually in the way this frame?
	var blocker := KinematicCollision3D.new()
	var reach := horizontal.length() * delta + SKIN
	if not body.test_move(from, direction * reach, blocker):
		return false
	if blocker.get_normal().dot(body.up_direction) > floor_cos:
		return false  # A walkable slope: move_and_slide() already handles it.

	# 2. Is there room to lift the body?
	var lift := body.up_direction * height
	if body.test_move(from, lift):
		return false
	var raised := from.translated(lift)

	# 3. Push outwards until the body has cleared the ledge, otherwise the
	#    downward probe catches the step's edge and reports an unwalkable
	#    normal. Land on the first sample that gives a real floor.
	var drop := KinematicCollision3D.new()
	for i in SAMPLES:
		var ahead := direction * (probe * float(i + 1) / SAMPLES)
		if body.test_move(raised, ahead):
			return false  # A real wall, not a ledge.

		var landing := raised.translated(ahead)
		if not body.test_move(landing, -lift, drop):
			continue  # Still hanging over the void: probe further out.
		if drop.get_normal().dot(body.up_direction) < floor_cos:
			continue  # Caught the edge: probe further out.

		if height - drop.get_travel().length() <= 0.001:
			return false  # The surface is level with our feet, nothing to climb.

		body.global_transform = landing.translated(drop.get_travel())
		body.velocity.y = 0.0
		return true
	return false
