class_name Villager
extends Node3D

## Someone who lives in the village: walks the street from one spot to the
## next, stops, stands at ease, now and then folds his arms or nods, and turns
## to watch a player who comes close.
##
## Their bodies are [FolkBody]s (the user's word, 2026-10-22): the poly
## heroes' Blink man — THE SQUIRE in the leathers (the prisoner, and the men
## he frees), THE KNIGHT in the plate and kettle hat — and the village's own
## people, men, women and elves made of the hero select's Polysplit parts
## (`ps_look`), all moved by everyday clips, not a fighter's.
##
## Not a physics body: they walk a handful of set spots along the street and
## round the square, which are clear of houses, and stand on whatever is under
## them. Nothing about them is simulated on more than one peer — each peer walks
## its own villagers from the same seed, and nobody fights them.

## The men he frees, in the order freed (the same in the cage and the village).
const FREED: Array[StringName] = [&"squire", &"knight"]


## The look of the `k`th man freed.
static func freed_look(k: int) -> StringName:
	return FREED[posmod(k, FREED.size())]


## Where they may walk, in the world; set by whoever places them.
var spots: Array[Vector3] = []
var variant: int = 0
## &"squire" / &"knight" (Blink's man), or &"ps" with `ps_look`.
var look: StringName = &"squire"
## A [PolysplitLook] look for `look` &"ps".
var ps_look: Dictionary = {}
## Down on his heels and still (the prisoner in his cage).
var crouched: bool = false
var pace: float = 1.2

var _body: FolkBody
var _rng := RandomNumberGenerator.new()
var _target: Vector3
var _wait: float = 0.0
var _walking: bool = false


func _ready() -> void:
	_rng.seed = 7919 * (variant + 1)
	_wait = _rng.randf_range(0.5, 4.0)
	_target = global_position
	pace = _rng.randf_range(1.0, 1.3)
	_body = FolkBody.new()
	_body.name = "Body"
	_body.kind = look
	_body.look = ps_look
	add_child(_body)
	if crouched:
		_body.crouch()
		set_process(false)


func _process(delta: float) -> void:
	var watcher := _nearest_player()
	if _walking:
		var to := _target - global_position
		to.y = 0.0
		if to.length() < 0.3:
			_walking = false
			_wait = _rng.randf_range(3.0, 9.0)
			_body.idle()
		else:
			global_position += to.normalized() * pace * delta
			_turn_to(to, delta, 5.0)
			_body.walk(pace)
	else:
		if watcher != null:
			_turn_to(watcher.global_position - global_position, delta, 2.0)
		_wait -= delta
		if _wait <= 0.0 and not spots.is_empty() and watcher == null:
			_target = spots[_rng.randi() % spots.size()]
			_walking = true
	_stand_on_ground()


## A player close enough to be watched, or null.
func _nearest_player() -> Node3D:
	for node in get_tree().get_nodes_in_group("player"):
		var who := node as Node3D
		if who != null and who.global_position.distance_to(global_position) < 4.0:
			return who
	return null


func _turn_to(direction: Vector3, delta: float, rate: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-rate * delta))


func _stand_on_ground() -> void:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 2.0
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 5.0, 1))
	if not hit.is_empty():
		global_position.y = (hit["position"] as Vector3).y
