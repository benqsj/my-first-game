class_name LootDrop
extends Node

## What a creature drops besides its gold (the user's word, 2026-10-07): now
## and then, not always, a thing for the bag: clothes or arms the hero has not
## got yet (GEAR_SETS.md §5.7). Which creature drops what is not decided yet,
## so for now any thing from any creature.
##
## One hangs under the [World] as `LootDrop`, on every peer at the same path.
## **The host decides** whether a hero near the kill gets something
## ([method chance_of], each hero rolled on his own). **What** it is, his own
## peer decides: it is drawn from his own bag ([method Inventory.roll_loot]),
## and only he sees it on the ground ([LootItem]): loot of his own, as each
## hero's bag is.

## How near the kill a hero has to be to get a roll (as for experience).
const RANGE := 35.0
## A creature worth this many wolves or more ([method Leveling.worth]) is a
## boss: it always drops something.
const BOSS_WORTH := 8.0

var _rng := RandomNumberGenerator.new()


## The drop of whatever world `node` is in (null outside one).
static func of(node: Node) -> LootDrop:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(&"loot_drop") as LootDrop


## How likely `creature` is to drop something for a hero: an imp about one in
## five, a wolf one in four, an orc nearly one in two, a boss always.
static func chance_of(creature: Node) -> float:
	var worth := Leveling.worth(creature)
	if worth >= BOSS_WORTH:
		return 1.0
	return clampf(0.15 + 0.1 * worth, 0.0, 1.0)


func _ready() -> void:
	add_to_group(&"loot_drop")
	_rng.randomize()


## Host: `creature` has died among `heroes`.
func drop(creature: Node3D, heroes: Array[Player]) -> void:
	if not _host():
		return
	var chance := chance_of(creature)
	for hero in heroes:
		if hero == null or hero.is_dead:
			continue
		if hero.global_position.distance_to(creature.global_position) > RANGE:
			continue
		if _rng.randf() >= chance:
			continue
		var draw := _rng.randi()
		var peer := hero.get_multiplayer_authority()
		if is_inside_tree() and multiplayer.has_multiplayer_peer() and peer != multiplayer.get_unique_id():
			net_loot.rpc_id(peer, creature.global_position, hero.get_path(), draw)
		else:
			net_loot(creature.global_position, hero.get_path(), draw)


## On the hero's own peer: something from his own bag where the creature fell.
@rpc("any_peer", "call_local", "reliable")
func net_loot(at: Vector3, hero_path: NodePath, draw: int) -> void:
	if not _from_host():
		return
	var hero := get_node_or_null(hero_path) as Player
	if hero == null or not hero.is_multiplayer_authority():
		return
	var bag := hero.get_node_or_null(^"Inventory") as Inventory
	if bag == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = draw
	var item := bag.roll_loot(rng)
	if item.is_empty():
		return
	var into := Blood.world_of(self)
	if into == null:
		into = get_parent()
	# a little to one side of the body, so it is not lost under it
	var a := rng.randf() * TAU
	LootItem.lay(into, at + Vector3(cos(a), 0.0, sin(a)) * 0.7, item, hero, bag.picture_of(item))


func _host() -> bool:
	var net := get_node_or_null(^"/root/Net")
	return net == null or bool(net.call(&"is_host"))


func _from_host() -> bool:
	var sender := multiplayer.get_remote_sender_id() if is_inside_tree() else 0
	return sender == 0 or sender == 1
