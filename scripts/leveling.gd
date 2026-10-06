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
## **Experience is a share of the level, 0 to 100 %.** A wolf is worth a whole
## level shared among `level + 2` of them — a third at level 1, a quarter at
## 2, a fifth at 3 — so each level asks one wolf more than the last, and a wolf
## is worth less and less:
##
## | level | wolves to the next | a wolf gives |
## |---|---|---|
## | 1 | 3 | 33.3 % |
## | 2 | 4 | 25 % |
## | 3 | 5 | 20 % |
## | 4 | 6 | 16.7 % |
## | … 9 | 11 | 9.1 % |
##
## Other creatures are worth so many wolves (`WEIGHT`): an imp 0.6, a puglin
## 0.8, an orc 3, Arkdeva 12. What is left over from a level carries into the
## next, counted in wolves.

## Every creature's level, shown over its head ([CombatText]): what it is,
## against where the heroes start.
const LEVEL_OF := {&"imp": 1, &"puglin": 2, &"wolf": 3, &"orc": 6, &"skeleton_lord": 8, &"arkdeva": 10}
const LEVEL_OTHER := 1

## What each creature is worth, in wolves.
const WEIGHT := {&"wolf": 1.0, &"imp": 0.6, &"puglin": 0.8, &"orc": 3.0, &"skeleton_lord": 8.0, &"arkdeva": 12.0}
## What a creature with no line of its own is worth, in wolves.
const WEIGHT_OTHER := 0.5
const MAX_LEVEL := 10
## A share this close to the whole is the whole (three thirds are 100 %).
const EPSILON := 0.01
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
	&"warrior": {"hp": 16.0, "p_atk": 2.2, "p_def": 2.6, "m_def": 1.4, "crit": 0.006, "stamina": 3.0},
}

signal gained(percent: float)
signal leveled_up(level: int)

var level: int = 1
## Towards the next level, in per cent.
var xp: float = 0.0

var _player: Player
## The profile is shared by every body of the same hero; the one that grows is
## this body's own copy.
var _own_profile: bool = false
## Which hero this is (the profile's file name), kept from before it was copied.
var _hero: StringName = &""


func _ready() -> void:
	_player = get_parent() as Player
	# The level's sound is made in code; made off to one side now, it is ready
	# long before the first level instead of stalling it ([LevelBeam]).
	if LevelBeam._sound_made == null:
		WorkerThreadPool.add_task(LevelBeam.warm)


## What `creature` is worth, in wolves.
static func worth(creature: Node) -> float:
	return float(WEIGHT.get(kind_of(creature), WEIGHT_OTHER))


## A creature's level.
static func level_of(creature: Node) -> int:
	return int(LEVEL_OF.get(kind_of(creature), LEVEL_OTHER))


## How many wolves `at_level` asks for the next one.
static func wolves_for(at_level: int) -> int:
	return at_level + 2


## What a wolf is worth at `at_level`, in per cent of the level.
static func wolf_share(at_level: int) -> float:
	return 100.0 / float(wolves_for(at_level))


static func kind_of(creature: Node) -> StringName:
	if creature is Wolf:
		return &"wolf"
	var scene := creature.scene_file_path.get_file().get_basename()
	if scene.begins_with("orc"):
		return &"orc"
	if scene != "":
		return StringName(scene)
	return &""


## Whether there is a next level at all.
func at_top() -> bool:
	return level >= MAX_LEVEL


## The host gives experience, `wolves` worth of it. Everyone is told the outcome.
func gain(wolves: float) -> void:
	if wolves <= 0.0 or at_top():
		return
	var new_level := level
	var new_xp := xp
	var left := wolves
	var first := wolves * wolf_share(level)
	while left > 0.0 and new_level < MAX_LEVEL:
		var share := wolf_share(new_level)
		var room := 100.0 - new_xp
		if left * share >= room - EPSILON:
			left -= room / share
			new_level += 1
			new_xp = 0.0
		else:
			new_xp += left * share
			left = 0.0
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_progress.rpc(new_level, new_xp, first)
	else:
		net_progress(new_level, new_xp, first)


## From the host: where this hero now stands. Each level gained grows him here.
@rpc("any_peer", "call_local", "reliable")
func net_progress(new_level: int, new_xp: float, percent: float) -> void:
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
	gained.emit(percent)


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
