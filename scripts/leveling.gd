class_name Leveling
extends Node

## A hero's level and experience. Every hero starts at level 1; what they kill
## gives experience, and enough of it is a level: more health, harder blows,
## better armour — each hero along his own line (`GROWTH`).
##
## Hung under each [Player] by [World] as `Leveling`, on every peer, so it has
## the same path everywhere. **The host decides**: it hears the creatures die,
## hands out the experience ([method gain]) and tells everyone the new level
## and experience ([method net_progress]); each peer then grows its copy of the
## hero the same way.
##
## | to reach | experience | wolves |
## |---|---|---|
## | level 2 | 40 | 4 |
## | level 3 | 70 more | 7 |
## | level 4 | 100 more | 10 |
## | 5 … 10 | 140, 180, 230, 280, 340, 400 more | |

## Wolves are the yardstick: 10 each.
const XP_FOR := {&"wolf": 10, &"imp": 6, &"puglin": 8, &"orc": 30, &"arkdeva": 120}
## What a creature with no line of its own is worth.
const XP_OTHER := 5
## Experience from each level to the next: `TO_NEXT[0]` takes level 1 to 2.
const TO_NEXT: Array[int] = [40, 70, 100, 140, 180, 230, 280, 340, 400]
const MAX_LEVEL := 10
## Heroes this far from a creature when it dies share in it — each gets it
## whole. Alone, that is simply the one who killed it.
const SHARE_RANGE := 35.0
## No crit chance grows past this.
const CRIT_CAP := 0.4

## What each level adds, by hero (the profile's file name). Roughly 8 % of
## where each starts, along what the hero is: Tariel's health and armour most
## and his blade least; the Mage's spells and m.def; Avtandil's arrows; the
## Assassin's critical hits.
const GROWTH := {
	&"tariel": {"hp": 15.0, "p_atk": 1.0, "p_def": 3.0, "m_def": 2.0, "stamina": 3.0},
	&"avtandil": {"hp": 9.0, "p_atk": 2.4, "p_def": 1.2, "m_def": 1.2, "crit": 0.01, "stamina": 2.0},
	&"rogue": {"hp": 8.0, "p_atk": 1.5, "p_def": 1.5, "m_def": 1.2, "crit": 0.015, "stamina": 3.0},
	&"mage": {"hp": 7.0, "m_atk": 3.5, "p_def": 0.8, "m_def": 3.0, "crit": 0.005, "stamina": 3.0},
}

signal gained(amount: int)
signal leveled_up(level: int)

var level: int = 1
## Experience towards the next level (not in all).
var xp: int = 0

var _player: Player
## The profile is shared by every body of the same hero; the one that grows is
## this body's own copy.
var _own_profile: bool = false
## Which hero this is (the profile's file name), kept from before it was copied.
var _hero: StringName = &""


func _ready() -> void:
	_player = get_parent() as Player


## What `creature` is worth, by what it is.
static func worth(creature: Node) -> int:
	return int(XP_FOR.get(kind_of(creature), XP_OTHER))


static func kind_of(creature: Node) -> StringName:
	if creature is Wolf:
		return &"wolf"
	var scene := creature.scene_file_path.get_file().get_basename()
	if scene.begins_with("orc"):
		return &"orc"
	if scene != "":
		return StringName(scene)
	return &""


## Experience still wanted for the next level; 0 at the top.
func needed() -> int:
	return TO_NEXT[level - 1] if level < MAX_LEVEL else 0


## The host gives experience. Everyone is told the outcome.
func gain(amount: int) -> void:
	if amount <= 0 or level >= MAX_LEVEL:
		return
	var new_level := level
	var new_xp := xp + amount
	while new_level < MAX_LEVEL and new_xp >= TO_NEXT[new_level - 1]:
		new_xp -= TO_NEXT[new_level - 1]
		new_level += 1
	if new_level >= MAX_LEVEL:
		new_xp = 0
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_progress.rpc(new_level, new_xp, amount)
	else:
		net_progress(new_level, new_xp, amount)


## From the host: where this hero now stands. Each level gained grows him here.
@rpc("any_peer", "call_local", "reliable")
func net_progress(new_level: int, new_xp: int, amount: int) -> void:
	var sender := multiplayer.get_remote_sender_id() if is_inside_tree() else 0
	if sender != 0 and sender != 1:
		return
	var rose := level < new_level
	while level < new_level:
		level += 1
		_grow()
		leveled_up.emit(level)
	# Seen by everyone: the column of light onto him ([LevelBeam]).
	if rose and _player != null:
		LevelBeam.on(_player)
	xp = new_xp
	gained.emit(amount)


## One level's worth, onto this body and its own copy of the profile (which is
## what every blow and shot reads).
func _grow() -> void:
	if _player == null or _player.profile == null:
		return
	if not _own_profile:
		_hero = StringName(_player.profile.resource_path.get_file().get_basename())
		_player.profile = _player.profile.duplicate() as CharacterProfile
		_own_profile = true
	var p := _player.profile
	var g: Dictionary = GROWTH.get(_hero, {})
	var hp := float(g.get("hp", 0.0))
	p.max_health += hp
	_player.max_health += hp
	# A level is a fresh start: whole again.
	_player.health = _player.max_health
	p.damage += float(g.get("p_atk", 0.0))
	if "m_atk" in p:
		p.set("m_atk", float(p.get("m_atk")) + float(g.get("m_atk", 0.0)))
	p.p_def += float(g.get("p_def", 0.0))
	_player.p_def += float(g.get("p_def", 0.0))
	if "m_def" in p:
		p.set("m_def", float(p.get("m_def")) + float(g.get("m_def", 0.0)))
	if "m_def" in _player:
		_player.set("m_def", float(_player.get("m_def")) + float(g.get("m_def", 0.0)))
	p.crit_chance = minf(p.crit_chance + float(g.get("crit", 0.0)), CRIT_CAP)
	var st := float(g.get("stamina", 0.0))
	p.max_stamina += st
	_player.max_stamina += st
	_player.stamina = _player.max_stamina


## The host: `creature` has died; every hero near it gets what it was worth.
static func share(creature: Node3D, heroes: Array[Player]) -> void:
	var amount := worth(creature)
	for hero in heroes:
		if hero == null or hero.is_dead:
			continue
		if hero.global_position.distance_to(creature.global_position) > SHARE_RANGE:
			continue
		var book := hero.get_node_or_null(^"Leveling") as Leveling
		if book != null:
			book.gain(amount)
