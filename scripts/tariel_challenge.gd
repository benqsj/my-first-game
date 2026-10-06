class_name TarielChallenge
extends RefCounted

## Tariel's fourth skill, the Challenge (the user's word, 2026-10-06): he
## raises his sword and strikes it on his shield, and every creature within
## `REACH` turns on him and comes for him alone for `TIME` (Lineage 2's
## Aggression), while his p.def stands `GUARD` times higher. Only creatures
## answer it: in PvP no hero is made to go for him.
##
## Where a creature picks whom to go for (Fighter / Brute `_pick_quarry`,
## Wolf `_quarry`) it asks [method dared] first. The p.def is read where his
## blows are taken ([method Player.net_blow], [method guard]).

const REACH := 9.0
const TIME := 6.0
const GUARD := 1.4
## The move: the sword raised over the shield and brought down on it (Mixamo's
## "Sword And Shield Casting", SS_Spell_Casting), its stretch, its pace, and
## when the blow on the shield rings out.
const CLIP := &"SS_Spell_Casting"
const PART := Vector2(0.0, 1.0)
const RATE := 1.2
const RING_AT := 0.5
## How long he is held by it.
const HOLD := 0.75
const DUST := Color(0.2, 0.17, 0.13)


## The owner's: spends and sends it. True if it went.
static func cast(hero: Player) -> bool:
	if hero == null or hero.rig == null or not hero.is_on_floor():
		return false
	if not hero._spend(float(Player.SKILLS[&"challenge"]["stamina"])):
		return false
	if hero.is_blocking:
		hero.is_blocking = false
		hero.block_changed.emit(false)
	hero.velocity = Vector3.ZERO
	hero._commit(HOLD)
	hero.net_challenge.rpc()
	return true


## Every peer: the move, the ring and the dust; on the host the creatures dared.
static func show(hero: Player) -> void:
	hero.set_meta(&"challenge_until", _now() + TIME)
	if hero.rig != null and hero.rig.has_method(&"play_part"):
		hero.rig.call(&"play_part", CLIP, RATE, PART.x, PART.y, 0.08)
	hero.get_tree().create_timer(RING_AT, false).timeout.connect(_ring.bind(hero))


static func _ring(hero: Player) -> void:
	if hero == null or not is_instance_valid(hero) or not hero.is_inside_tree() or hero.is_dead:
		return
	var into := Blood.world_of(hero)
	if into != null:
		var at := hero.global_position
		# the dust beaten up off the ground round him by the blow
		SkillFx.particles(into, at + Vector3.UP * 0.15, {
			"amount": 40, "life": 1.0, "one_shot": true, "explosiveness": 0.95,
			"speed": Vector2(1.5, 4.0), "spread": 80.0, "dir": Vector3.UP, "damping": 3.5,
			"gravity": Vector3(0, -0.4, 0), "size": Vector2(0.35, 0.8), "box": Vector3(0.6, 0.05, 0.6),
			"add": false, "grow": 0.5,
			"colors": [Color(DUST, 0.0), Color(DUST, 0.55), Color(DUST, 0.0)],
		})
	if hero.is_multiplayer_authority():
		WindBlast.shake(hero, 0.08, 0.3)
	if hero._decides_here():
		dare(hero)


## Host: every creature within reach turns on him.
static func dare(hero: Player) -> void:
	var until := _now() + TIME
	var seen := {}
	for group: StringName in [&"enemy", &"wolf"]:
		for node in hero.get_tree().get_nodes_in_group(group):
			var creature := node as Node3D
			if creature == null or seen.has(creature) or creature.get(&"is_dead") == true:
				continue
			seen[creature] = true
			if creature.global_position.distance_to(hero.global_position) > REACH:
				continue
			creature.set_meta(&"dared_by", hero.get_path())
			creature.set_meta(&"dared_until", until)
			if creature.has_method(&"_rouse"):
				creature.call(&"_rouse", hero)


## Who has dared `creature` and still holds it, or null.
static func dared(creature: Node) -> Node3D:
	if creature == null or not creature.has_meta(&"dared_until"):
		return null
	if _now() >= float(creature.get_meta(&"dared_until")):
		return null
	var hero := creature.get_node_or_null(creature.get_meta(&"dared_by") as NodePath) as Node3D
	if hero == null or not hero.is_inside_tree() or hero.get(&"is_dead") == true or Brute.unseen(hero):
		return null
	return hero


## What his p.def is worth now: `GUARD` times while the challenge holds.
static func guard(hero: Node) -> float:
	if hero != null and _now() < float(hero.get_meta(&"challenge_until", 0.0)):
		return GUARD
	return 1.0


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
