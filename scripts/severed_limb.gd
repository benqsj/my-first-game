class_name SeveredLimb
extends Node3D

## A limb that has been cut off. It keeps the pose it was in, falls, tumbles a
## little and settles on the ground — enough to see it come away and land,
## without a rigid body per piece.

@export var spin: Vector3 = Vector3.ZERO
@export var lifetime: float = 25.0

var _velocity: Vector3 = Vector3.ZERO
var _resting: bool = false
var _age: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


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

	if global_position.y <= 0.05:
		global_position.y = 0.05
		_resting = true
		Blood.splatter(get_parent(), global_position, Vector3.UP)
