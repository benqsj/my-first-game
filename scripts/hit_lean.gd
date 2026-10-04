class_name HitLean
extends SkeletonModifier3D
## A blow that got through, seen in his back (TARIEL_POLISH.md 9): the spine
## thrown over the way the blow was going — struck from his left, he bends to
## his right — and sprung back upright ([HitReact], laid over whatever clip
## plays). On the mannequin, after the clips and the strike aim, so the figure
## following it bends with it.

## The back from the hips up, and each joint's share of the whole bend (the
## mannequin's head is "Head"; a skeleton that has neither skips it).
const CHAIN: Array = [&"spine_01", &"spine_02", &"spine_03", &"neck_01", &"Head", &"head"]
const SHARES: Array = [0.3, 0.25, 0.2, 0.15, 0.1, 0.1]

var _react: HitReact


## A blow going `along` (world space; from whoever struck to him), at
## `strength` (radians a second: 3 a light blow, 6 a heavy one).
func strike(along: Vector3, strength: float) -> void:
	if _react == null:
		_react = HitReact.on_bones(get_skeleton(), CHAIN, SHARES)
	_react.strike(along, strength)


## How far over he is thrown now (a rotation vector, world space), for a test.
func lean() -> Vector3:
	return _react._angle if _react != null else Vector3.ZERO


func _process_modification() -> void:
	if _react == null or not _react.is_on():
		return
	var dt := get_process_delta_time()
	if dt <= 0.0:
		dt = get_physics_process_delta_time()
	_react.drive(dt)
