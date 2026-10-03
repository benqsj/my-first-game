class_name PackDress
extends Node

## Puts one of Polysplit's Biped Creatures (CREATURES_PACK.md) in the pack's
## own shader and colours, for a fighting creature whose model is the pack's
## FBX as it is (a [Brawler] scene): every mesh under `model`, its body
## surfaces in `body`'s colours and its objects' (armour, cloth, weapons) in
## `objects`' — names of [PackCreature.MATERIALS]. The pack hides nothing it
## should not show, so every part is shown.

@export var model: NodePath = ^"../Model"
@export var body: String = "Body_Skeleton"
@export var objects: String = "Objects"


func _ready() -> void:
	var root := get_node_or_null(model)
	if root == null:
		return
	PackCreature.dress(root, body, objects)
