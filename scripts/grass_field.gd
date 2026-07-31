class_name GrassField
extends Node3D

## Bends grass out of the way as something walks or rolls through it.
##
## Every child whose name starts with `grass_prefix` is treated as a clump. Each
## clump keeps the orientation it was placed with; the bend is a rotation
## layered on top of that, about a horizontal axis through the clump's base, so
## the blades lean away from whatever is pushing them and spring back once it
## has passed.
##
## Everything is driven off distance to a single target, which is cheap enough
## to run over a few hundred clumps every frame without a spatial index.

## Only children whose name starts with this are bent. Rocks and other props
## sitting in the same scatter node are left alone.
@export var grass_prefix: String = "Grass"
## How far from the target a clump starts to feel it, in metres.
@export var reach: float = 1.5
## How far the blades lean at the centre of the push, in radians.
@export var max_bend: float = 1.15
## How fast the blades give way. Higher snaps out of the way sooner.
@export var bend_speed: float = 14.0
## How fast they stand back up once nothing is on them.
@export var recover_speed: float = 4.5

var _clumps: Array[Node3D] = []
var _rest: Array[Basis] = []
## Current lean per clump: direction is which way it leans, length is how far.
var _bend: Array[Vector3] = []
var _target: Node3D


func _ready() -> void:
	for child in get_children():
		var node := child as Node3D
		if node == null or not node.name.begins_with(grass_prefix):
			continue
		_clumps.append(node)
		_rest.append(node.transform.basis)
		_bend.append(Vector3.ZERO)

	_target = get_tree().get_first_node_in_group("player") as Node3D
	if _target == null:
		push_warning("GrassField: no node in the \"player\" group, grass will not react.")
		set_process(false)


func _process(delta: float) -> void:
	if _target == null:
		return

	var origin := _target.global_position
	var reach_squared := reach * reach
	var push_weight := 1.0 - exp(-bend_speed * delta)
	var recover_weight := 1.0 - exp(-recover_speed * delta)

	for i in _clumps.size():
		var clump := _clumps[i]
		var offset := clump.global_position - origin
		offset.y = 0.0

		var wanted := Vector3.ZERO
		var weight := recover_weight
		var distance_squared := offset.length_squared()
		if distance_squared < reach_squared and distance_squared > 0.0001:
			# Closer means further over, and the lean points away from the target.
			var falloff := 1.0 - sqrt(distance_squared) / reach
			wanted = offset.normalized() * (max_bend * falloff)
			weight = push_weight

		var bend: Vector3 = _bend[i].lerp(wanted, weight)
		_bend[i] = bend

		var amount := bend.length()
		if amount < 0.001:
			clump.transform.basis = _rest[i]
			continue
		# Rotating about the horizontal axis square to the lean tips the clump
		# over in that direction, pivoting on its base.
		var axis := Vector3.UP.cross(bend)
		if axis.length_squared() < 0.000001:
			continue
		clump.transform.basis = Basis(axis.normalized(), amount) * _rest[i]
