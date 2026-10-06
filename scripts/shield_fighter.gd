class_name ShieldFighter
extends Brawler

## Sword and shield: the skeleton warrior of Polysplit's Biped Creatures
## (CREATURES_PACK.md).
##
## * **Behind the shield.** Roused and within `shield_under` of him, it stops
##   running and walks in behind its raised shield (`CR_ShieldWalk` and the
##   rest: the walk's legs, the guard's body, tools/creature_clips.gd
##   LAYERED), and stands behind it between its blows. Whatever comes at its
##   front while the shield is up is caught on it (the guard's stamina, as
##   any [Fighter]'s block: spent, the guard breaks and it stands open); from
##   the side or behind (wider than `shield_front`) it gets through. Caught,
##   it rocks behind the shield, and once his blows stop coming
##   (`counter_after`) it answers.
## * **The bash and the sword.** Its answer from behind the shield, mostly,
##   and now and then one of its attacks: the shield thrown into him
##   (`bash_clip`), and straight out of it the sword (`follow_clip`), one
##   combo to the hero. Its other attacks are the [Brawler]'s.
## * **Broken into bones** as every skeleton is ([member Brawler.shatter_on_death]).

@export_group("Shield")
@export var shield_under: float = 7.5
@export var shield_pace: float = 1.6
@export var shield_walk_clip: StringName = &"CR_ShieldWalk"
@export var shield_back_clip: StringName = &"CR_ShieldBack"
@export var shield_l_clip: StringName = &"CR_ShieldL"
@export var shield_r_clip: StringName = &"CR_ShieldR"
@export var shield_idle_clip: StringName = &"CR_Block"
## How far round its front the shield covers: a blow from where the dot of
## its facing and the way to the striker is above this is caught.
@export var shield_front: float = 0.2

@export_group("Bash")
@export var bash_clip: StringName = &"CR_ShieldBash"
## [rate, from, to] of the bash, and of the sword after it.
@export var bash_part: Vector3 = Vector3(1.2, 0.0, 0.55)
@export var follow_clip: StringName = &"CR_Slash1"
@export var follow_part: Vector3 = Vector3(1.3, 0.12, 0.85)
@export var bash_limb: String = "L_wrist_joint>L_equip_joint@0,0.1,0:0.32"
## Share of `hit_damage` the bash is worth.
@export var bash_share: float = 0.6
## How often an attack is the bash and sword, and how often its answer from
## behind the shield is.
@export_range(0.0, 1.0) var bash_chance: float = 0.3
@export_range(0.0, 1.0) var counter_bash_chance: float = 0.8

const BASH := 74
const FOLLOW := 75

func _ready() -> void:
	super()
	_moves_table[BASH] = [bash_clip, bash_part.x, bash_part.y, bash_part.z]
	_moves_table[FOLLOW] = [follow_clip, follow_part.x, follow_part.y, follow_part.z]
	_own_limb(BASH, bash_limb)
	var count := maxi(blows_to_fell, 1)
	_strikes_table[FOLLOW] = [PackedStringArray([String(weapon_bone)]), ["weapon"], 1.0, count]
	if _anim != null:
		var bash_tip := Vector3(0.0, 0.1, 0.0)
		var stretch: Array = (_limbs_of.get(BASH, [[]]) as Array)[-1]
		if stretch.size() > 2:
			bash_tip = stretch[2]
		var at := _anim.measure_reach(bash_clip, "L_equip_joint", bash_tip, reach_forward, bash_part.y, bash_part.z)
		if at >= 0.0:
			var s: Array = _strikes_table[BASH]
			_strikes_table[BASH] = [s[0], s[1], bash_share, count, 0.6, PackedFloat32Array([at])]
			var from := _gap_that_lands(BASH, _moves_table[BASH] as Array, at)
			if from > 0.0:
				_strike_from[BASH] = from
		at = _anim.measure_reach(follow_clip, String(weapon_bone), weapon_tip, reach_forward, follow_part.y, follow_part.z)
		if at >= 0.0:
			_strikes_table[FOLLOW] = [PackedStringArray([String(weapon_bone)]), ["weapon"], 1.0, count, 0.6,
					PackedFloat32Array([at])]


#region The shield
## Up: roused, on its feet, not running and not in the middle of a move.
func shield_up() -> bool:
	if is_dead or not (mode == Mode.CHASE or mode == Mode.FIGHT):
		return false
	if act == Act.BLOCK:
		return true
	if act != Act.NONE:
		return false
	return Vector3(velocity.x, 0.0, velocity.z).length() <= run_above


func _covers(from: Node3D) -> bool:
	if from == null:
		return false
	var to_them := from.global_position - global_position
	to_them.y = 0.0
	return _forward().dot(to_them.normalized()) > shield_front


func _receive(damage: float, at: Vector3, blow: Vector3, from: Node3D, magic: bool = false) -> bool:
	if not is_dead and _decides() and not magic and shield_up() and _covers(from):
		# Behind the raised shield: caught, rocking it back; the Fighter's own
		# block takes it from here (stamina, the clash, the break).
		_start(Act.BLOCK)
	var bled := super(damage, at, blow, from, magic)
	return bled


#endregion


#region Thinking
func _think(delta: float) -> void:
	if mode == Mode.GUARD or mode == Mode.RETURN or is_dead:
		super(delta)
		return
	# Behind the shield, his blows over: the bash and the sword, mostly.
	if counter_after > 0.0 and act == Act.BLOCK and _quarry != null \
			and _act_time >= counter_after and stamina >= attack_cost \
			and _distance_to(_quarry) <= reach + 0.4 and not _quarry_down():
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		if _rng.randf() < counter_bash_chance:
			_begin_bash()
		else:
			_begin_attack()
		return
	_quarry = _pick_quarry()
	if _quarry != null and act == Act.NONE:
		var gap := _distance_to(_quarry)
		if gap > reach and gap < shield_under:
			# Walking in behind the shield, not running.
			mode = Mode.CHASE
			_move_towards(_quarry.global_position, shield_pace, delta)
			_face(_quarry.global_position - global_position, delta, turn_speed)
			return
	super(delta)


func _begin_attack() -> void:
	if not _quarry_down() and _quarry != null and _rng.randf() < bash_chance:
		var gap := _distance_to(_quarry)
		var want := float(_strike_from.get(BASH, strike_off))
		if gap <= want + 0.5:
			_begin_bash()
			return
	super()


func _begin_bash() -> void:
	_chain_serial = -1
	_chain_blow = 0
	_begin(BASH)
	_chain_serial = act_serial


func _after(what: int) -> void:
	if what == BASH and not is_dead:
		# Straight out of the bash, the sword: one combo to him.
		var serial := _chain_serial
		_chain_blow = 1
		_begin(FOLLOW)
		# (its blow laid on the bash's serial, as the second of the combo)
		_chain_serial = serial
		return
	_chain_serial = -1
	_chain_blow = 0
	super(what)


func _begin(what: int) -> void:
	if what == FOLLOW:
		# The follow-up spends no more stamina than the bash did.
		var keep := stamina
		super(what)
		stamina = keep
		return
	super(what)


func _fade_in(what: int) -> float:
	return 0.2 if what == FOLLOW else super(what)
#endregion


#region Walking
func _play_locomotion(delta: float) -> void:
	if not shield_up():
		super(delta)
		return
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var pace := planar.length()
	if pace < 0.15:
		_anim.play(shield_idle_clip, 0.25, 1.0)
		return
	var ahead := _forward()
	var right := ahead.cross(Vector3.UP)
	var fwd := planar.dot(ahead)
	var side := planar.dot(right)
	var clip := shield_walk_clip
	if absf(side) > absf(fwd) * 1.1:
		clip = shield_r_clip if side > 0.0 else shield_l_clip
	elif fwd < 0.0:
		clip = shield_back_clip
	if not _anim.has_clip(clip):
		super(delta)
		return
	var stride := maxf(_anim.measure_stride(clip), 0.1) * maxf(visual_scale, 0.01)
	_anim.play(clip, 0.2, clampf(pace * _anim.clip_length(clip) / stride, retime_range.x, chase_retime_max))
#endregion
