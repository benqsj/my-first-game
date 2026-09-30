class_name Brawler
extends ClipFighter

## A creature or a boss that fights out of clips of its own, on the skeleton it
## came with, set up in its scene rather than in code: the minotaur, the demon,
## the frog, the ogre, the centaur, the dragons.
##
## The clips are made in vepxis-art `tools/mon_build.py` — the creature's own
## where it came with them, Mixamo's carried onto its bones where it did not —
## and nothing about the skeleton is renamed for the game, so everything that
## reads a bone is told which one here:
##
## * **Attacks** are a list of clips, each with how fast it plays and the share
##   of it that is the blow (past a slow wind-up, short of a long settle). One
##   is picked at random each time it swings; `big_attacks` are the ones a boss
##   saves for when the hero is further off (a leap, a charge, a breath).
## * **The blow** is the limb in `strike_bones` (its fastest moment is the blow,
##   measured off the clip), swept from `weapon_bone` out to `weapon_tip` in
##   that bone's frame and `weapon_radius` thick — a blade, a fist, jaws.
## * **Hurt and death** are its own clips; it takes the heroes' knock-downs,
##   burns and poison with the hit clip rather than the library's.

@export_group("Own moves")
## The attack clips, and for each [rate, from, to] (missing: [1, 0, 1]).
@export var attacks: Array[StringName] = []
@export var attack_parts: Array[Vector3] = []
## Attacks for further off: used when the hero is between `reach` and
## `big_reach`, now and then.
@export var big_attacks: Array[StringName] = []
@export var big_parts: Array[Vector3] = []
@export var big_reach: float = 0.0
## Bones whose speed marks a blow, and the one the blow is swept along.
@export var strike_bones: PackedStringArray = PackedStringArray()
@export var weapon_bone: StringName = &""
## The clip it takes a hit with, and a shout it gives now and then when roused.
@export var hit_clip: StringName = &""
@export var roar_clip: StringName = &""
@export var roar_every: Vector2 = Vector2(9.0, 16.0)

const ATTACK_BASE := 60
const BIG_BASE := 80
const ROAR := 99

var _weapon: int = -1
var _moves_table: Dictionary = {}
var _strikes_table: Dictionary = {}
var _roar_in: float = 0.0


func _ready() -> void:
	for i in attacks.size():
		_moves_table[ATTACK_BASE + i] = _move(attacks[i], attack_parts, i)
	for i in big_attacks.size():
		_moves_table[BIG_BASE + i] = _move(big_attacks[i], big_parts, i)
	if not roar_clip.is_empty():
		_moves_table[ROAR] = [roar_clip, 1.0, 0.0, 1.0]
	var bones := strike_bones if not strike_bones.is_empty() else PackedStringArray([String(weapon_bone)])
	for what: int in _moves_table:
		if what != ROAR:
			_strikes_table[what] = [bones, ["weapon"], 1.0, 1]
	if not hit_clip.is_empty():
		reacts = {
			Act.REACT_KNOCK: [[hit_clip, 1.0, 1.0]],
			Act.REACT_BURN: [[hit_clip, 1.3, 1.0]],
			Act.REACT_POISON: [[hit_clip, 1.5, 0.6]],
		}
	super()
	if _skeleton != null and not weapon_bone.is_empty():
		_weapon = _skeleton.find_bone(String(weapon_bone))
	_roar_in = _rng.randf_range(roar_every.x, roar_every.y)


func _move(clip: StringName, parts: Array[Vector3], i: int) -> Array:
	var p := parts[i] if i < parts.size() else Vector3(1.0, 0.0, 1.0)
	return [clip, p.x, p.y, p.z]


func _moves() -> Dictionary:
	return _moves_table


func _strikes() -> Dictionary:
	return _strikes_table


func _weapon_part() -> Array:
	if _weapon < 0:
		return []
	return [WeaponSweep.bones(_skeleton, _weapon, _weapon, weapon_radius * maxf(visual_scale, 0.01), weapon_tip)]


## Picks one of its attacks — a big one if the hero is further off.
func _begin_attack() -> void:
	if attacks.is_empty():
		super()
		return
	_begin(ATTACK_BASE + _rng.randi() % attacks.size())


func _think(delta: float) -> void:
	if (mode == Mode.CHASE or mode == Mode.FIGHT) and act == Act.NONE and _quarry != null and not is_dead:
		_roar_in -= delta
		var gap := _distance_to(_quarry)
		if not big_attacks.is_empty() and gap > reach and gap < big_reach and _cooldown <= 0.0 \
				and stamina >= attack_cost and _rng.randf() < 0.02:
			_face(_quarry.global_position - global_position, 1.0, 50.0)
			_begin(BIG_BASE + _rng.randi() % big_attacks.size())
			return
		if _roar_in <= 0.0 and _moves_table.has(ROAR):
			_roar_in = _rng.randf_range(roar_every.x, roar_every.y)
			_begin(ROAR)
			return
	super(delta)


func _after(what: int) -> void:
	if what != ROAR:
		_cooldown = _rng.randf_range(attack_cooldown.x, attack_cooldown.y)
	super(what)
