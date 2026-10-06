class_name PackDress
extends Node

## Puts one of Polysplit's Biped Creatures (CREATURES_PACK.md) in the pack's
## own shader and colours, for a fighting creature whose model is the pack's
## FBX as it is (a [Brawler] scene): every mesh under `model`, its body
## surfaces in `body`'s colours and its objects' (armour, cloth, weapons) in
## `objects`' — names of [PackCreature.MATERIALS]. With no `always` list every
## part is shown.
##
## **A mixed outfit** (the skeletons, on the pack's all-in-one kit; the user's
## word, 2026-10-06): `always` is what it always wears and holds (its bones,
## its arms), and one of each of `heads`, `tops` and `bottoms` is put on
## besides ("" for none; a name given more than once is that much likelier),
## and its objects coloured by one of `colours`. Picked from its own name, so
## every peer dresses the same body the same way and no two of a camp need
## look alike.

@export var model: NodePath = ^"../Model"
@export var body: String = "Body_Skeleton"
@export var objects: String = "Objects"
@export var always: PackedStringArray = PackedStringArray()
@export var heads: PackedStringArray = PackedStringArray()
@export var tops: PackedStringArray = PackedStringArray()
@export var bottoms: PackedStringArray = PackedStringArray()
@export var colours: PackedStringArray = PackedStringArray()

## What it was dressed in (mesh names shown), for a test to read.
var worn: PackedStringArray = PackedStringArray()


func _ready() -> void:
	var root := get_node_or_null(model)
	if root == null:
		return
	if always.is_empty():
		PackCreature.dress(root, body, objects)
		return
	var rng := RandomNumberGenerator.new()
	var who := owner if owner != null else get_parent()
	rng.seed = hash(String(who.name) if who != null else "")
	var paint := objects
	if not colours.is_empty():
		paint = colours[rng.randi() % colours.size()]
	PackCreature.dress(root, body, paint)
	var on := {}
	for n in always:
		on[n] = true
	for slot: PackedStringArray in [heads, tops, bottoms]:
		if slot.is_empty():
			continue
		var pick := slot[rng.randi() % slot.size()]
		if pick != "":
			on[pick] = true
	worn = PackedStringArray()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		mi.visible = on.has(String(mi.name))
		if mi.visible:
			worn.append(String(mi.name))
