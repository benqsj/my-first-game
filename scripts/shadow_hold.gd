class_name ShadowHold
extends Node

## Held where it stands by the dark elf's Dark Hands ([ShadowGrasp]): for its
## time a body cannot go anywhere over the ground, though it may turn and
## strike. On the body's own peer (the host for a creature, a hero's own for
## him) each physics tick's step over the ground is taken back whole, after the
## body's own tick, whatever moved it — so it holds every kind of creature and
## the heroes alike, as the chill does ([Afflictions]). Not a fall: only x and z.
##
## Hangs under the body as "ShadowHold"; a new hold only lengthens the old.

var _body: Node3D
var _left: float = 0.0
var _at := Vector3.INF


## Holds `body` for `seconds`.
static func hold(body: Node3D, seconds: float) -> void:
	if body == null or not body.is_inside_tree() or seconds <= 0.0:
		return
	var held := body.get_node_or_null(^"ShadowHold") as ShadowHold
	if held != null:
		held._left = maxf(held._left, seconds)
		return
	held = ShadowHold.new()
	held.name = "ShadowHold"
	held._body = body
	held._left = seconds
	body.add_child(held)


## Whether `body` is held now.
static func is_held(body: Node) -> bool:
	return body != null and body.get_node_or_null(^"ShadowHold") != null


func _ready() -> void:
	# after the body's own tick, so its step is taken before it is undone
	process_physics_priority = 110


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 or _body == null or not is_instance_valid(_body) or _body.get(&"is_dead") == true:
		queue_free()
		return
	if not _body.is_multiplayer_authority():
		_at = Vector3.INF
		return
	var now := _body.global_position
	if not _at.is_finite():
		_at = now
		return
	var moved := now - _at
	moved.y = 0.0
	# a step too long to be a step (a blink, a teleport) is let be
	if moved.length() < 1.5:
		_body.global_position = Vector3(_at.x, now.y, _at.z)
	else:
		_at = now
