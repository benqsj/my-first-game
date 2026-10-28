class_name PlayerLooks
extends RefCounted

## What he wears and owns: shield, face, hair, garb, owned things.
## Taken out of player.gd (2026-10-28) so the hero is in parts; every
## function takes the hero as `me` and works on it as it did before. [Player]
## keeps a one-line function of the same name for each one called from
## outside this file (other scripts, the rig, signals, the hero himself).

#region Vitals
## Puts on a shield ([enum Inventory.Shields]); every peer sees it through
## `net_shield`.
static func set_shield(me: Player, kind: int) -> void:
	me.shield_kind = kind
	if me.rig != null and me.rig.has_method(&"set_shield"):
		me.rig.call(&"set_shield", kind)


## Wears one of the rig's `faces`; every peer sees it through `net_face`.
static func set_face(me: Player, index: int) -> void:
	me.face = index
	if me.rig != null and me.rig.has_method(&"set_face"):
		me.rig.call(&"set_face", index)


## Wears the look made on the hero select ([PolysplitLook]); every peer sees
## it through `net_look`.
static func set_look(me: Player, made: Dictionary) -> void:
	if me.rig != null and me.rig.has_method(&"set_look"):
		me.rig.call(&"set_look", made)
		me.look = me.rig.call(&"get_look")
	else:
		me.look = made.duplicate(true)


## Dyes the rig's clothes (its `TINTS`); every peer sees it through `net_tint`.
static func set_tint(me: Player, index: int) -> void:
	me.tint = index
	if me.rig != null and me.rig.has_method(&"set_tint"):
		me.rig.call(&"set_tint", index)


## Wears one of the rig's `hairs`; every peer sees it through `net_hair`.
static func set_hair(me: Player, index: int) -> void:
	me.hair = index
	if me.rig != null and me.rig.has_method(&"set_hair"):
		me.rig.call(&"set_hair", index)


## Puts on one of his outfits (an index into the rig's `garbs`); every peer
## sees it through `net_garb`.
static func set_garb(me: Player, index: int) -> void:
	me.garb = index
	if me.rig != null and me.rig.has_method(&"set_garb"):
		me.rig.call(&"set_garb", index)


## What he has on now kept for the next level ([method Game.worn]).
static func remember_worn(me: Player) -> void:
	var game := me.get_node_or_null(^"/root/Game")
	if game == null or not game.has_method(&"set_worn") or not me.is_multiplayer_authority():
		return
	game.call(&"set_worn", game.call(&"character"), me.look, me.garb)


## The hero's id ("tariel"), his profile's file name.
static func hero_id(me: Player) -> StringName:
	return StringName(me.profile.resource_path.get_file().get_basename()) if me.profile != null else &""


static func _read_owned(me: Player) -> void:
	if me._owned_read:
		return
	me._owned_read = true
	var game := me.get_node_or_null(^"/root/Game") if not Inventory.under_test() else null
	if game != null and game.has_method(&"owned"):
		for key: Variant in game.call(&"owned", PlayerLooks.hero_id(me)):
			me._owned[String(key)] = true


## Whether he carries the thing of `key`.
static func owns(me: Player, key: String) -> bool:
	PlayerLooks._read_owned(me)
	return me._owned.has(key)


## He has the thing of `key` now; false if he had it already.
static func gain(me: Player, key: String) -> bool:
	PlayerLooks._read_owned(me)
	if key == "" or me._owned.has(key):
		return false
	me._owned[key] = true
	var game := me.get_node_or_null(^"/root/Game") if not Inventory.under_test() else null
	if game != null and game.has_method(&"set_owned") and PlayerLooks.hero_id(me) != &"":
		game.call(&"set_owned", PlayerLooks.hero_id(me), me._owned.keys())
	return true


## Everything he carries forgotten (a new start; the tests).
static func forget_owned(me: Player) -> void:
	me._owned_read = true
	me._owned.clear()
	var game := me.get_node_or_null(^"/root/Game") if not Inventory.under_test() else null
	if game != null and game.has_method(&"set_owned") and PlayerLooks.hero_id(me) != &"":
		game.call(&"set_owned", PlayerLooks.hero_id(me), [])
