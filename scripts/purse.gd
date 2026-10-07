class_name Purse
extends Node

## A hero's gold (the user's word, 2026-10-07: there was none for a goblin to
## steal).
##
## Hung under each [Player] by [World] as `Purse`, on every peer, beside his
## [Leveling]. **The host decides**: it hands out what the coins on the ground
## are worth when he walks over them ([Coins]) and takes what a goblin's hand
## gets out of it ([GoblinFighter]); it tells everyone the new count
## ([method net_gold]), and the hero's own HUD shows it and the change.

## The count changed: the new total and by how much (+ found, - lost).
signal changed(total: int, by: int)

var gold: int = 0


## The purse of `hero` (null without one).
static func of(hero: Node) -> Purse:
	return hero.get_node_or_null(^"Purse") as Purse if hero != null else null


## Host: `amount` more.
func give(amount: int) -> void:
	if amount > 0:
		_tell(gold + amount, amount)


## Host: up to `amount` out of it; returns what was there to take.
func take(amount: int) -> int:
	var got := mini(maxi(amount, 0), gold)
	if got > 0:
		_tell(gold - got, -got)
	return got


func _tell(total: int, by: int) -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_gold.rpc(total, by)
	else:
		net_gold(total, by)


## From the host: what is in it now.
@rpc("any_peer", "call_local", "reliable")
func net_gold(total: int, by: int) -> void:
	var sender := multiplayer.get_remote_sender_id() if is_inside_tree() else 0
	if sender != 0 and sender != 1:
		return
	gold = maxi(total, 0)
	changed.emit(gold, by)
