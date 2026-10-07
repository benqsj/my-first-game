class_name CoinBank
extends Node

## The gold on the ground (the user's word, 2026-10-07): what a creature drops
## when it dies, and what a goblin drops of what it stole.
##
## One hangs under the [World] as `CoinBank`, on every peer at the same path.
## **The host decides**: it drops the coins ([method drop]), every peer is told
## and throws its own scatter of them ([Coins]); a hero who walks within
## `PICK_UP` of a scatter gets what it is worth in his [Purse] (the host
## again), and every peer sees the coins fly up into him.

## How near he has to come to take them, and how soon after they are thrown.
const PICK_UP := 1.7
const SETTLE := 0.6
## What a creature drops, for each wolf it is worth ([method Leveling.worth]),
## and a little either way.
const PER_WOLF := 6.0
const SPREAD := 0.35

var _next: int = 0
var _piles: Dictionary = {}


## The bank of whatever world `node` is in (null outside one).
static func of(node: Node) -> CoinBank:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(&"coin_bank") as CoinBank


## What `creature` drops when it dies, its own worth and whatever it carried
## (a goblin's takings: `carried_gold`).
static func worth_of(creature: Node, rng: RandomNumberGenerator = null) -> int:
	var base := Leveling.worth(creature) * PER_WOLF
	var r := rng.randf_range(-SPREAD, SPREAD) if rng != null else randf_range(-SPREAD, SPREAD)
	var own := maxi(int(round(base * (1.0 + r))), 1)
	if "carried_gold" in creature:
		own += int(creature.get("carried_gold"))
	return own


func _ready() -> void:
	add_to_group(&"coin_bank")


## Host: `amount` gold thrown on the ground at `at`.
func drop(at: Vector3, amount: int) -> void:
	if amount <= 0 or not _host():
		return
	_next += 1
	_send(&"net_drop", [at, amount, _next])


@rpc("any_peer", "call_local", "reliable")
func net_drop(at: Vector3, amount: int, id: int) -> void:
	if not _from_host():
		return
	var into := Blood.world_of(self)
	if into == null:
		into = get_parent()
	var pile := Coins.scatter(into, at, amount, id)
	_piles[id] = pile


@rpc("any_peer", "call_local", "reliable")
func net_taken(id: int, hero: NodePath) -> void:
	if not _from_host():
		return
	var pile := _piles.get(id) as Coins
	_piles.erase(id)
	if pile != null and is_instance_valid(pile):
		pile.fly_into(get_node_or_null(hero) as Node3D)


func _physics_process(_delta: float) -> void:
	if not _host() or _piles.is_empty():
		return
	for id: int in _piles.keys():
		var pile := _piles[id] as Coins
		if pile == null or not is_instance_valid(pile):
			_piles.erase(id)
			continue
		if pile.age < SETTLE:
			continue
		for node in get_tree().get_nodes_in_group(&"player"):
			var hero := node as Node3D
			if hero == null or bool(hero.get("is_dead")):
				continue
			var gap := hero.global_position - pile.global_position
			gap.y *= 0.5
			if gap.length() > PICK_UP:
				continue
			var purse := Purse.of(hero)
			if purse == null:
				continue
			purse.give(pile.amount)
			_send(&"net_taken", [id, hero.get_path()])
			break


func _send(method: StringName, args: Array) -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		callv(&"rpc", [method] + args)
	else:
		callv(method, args)


func _host() -> bool:
	var net := get_node_or_null(^"/root/Net")
	return net == null or bool(net.call(&"is_host"))


func _from_host() -> bool:
	var sender := multiplayer.get_remote_sender_id() if is_inside_tree() else 0
	return sender == 0 or sender == 1
