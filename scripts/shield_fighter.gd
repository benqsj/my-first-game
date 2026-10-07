class_name ShieldFighter
extends Brawler

## Sword and shield: the skeleton warrior of Polysplit's Biped Creatures
## (CREATURES_PACK.md).
##
## * **The shield raised when he strikes or shoots** (the user's word: it
##   came on always behind a raised shield). Its shield hangs at its side
##   and it comes on as any creature does, until he swings at it (a swing
##   seen, [signal HurtboxComponent.swing_seen]), something he loosed comes
##   at it (an arrow, a bolt, a spear of ice: the `missile` group, judged
##   `missile_watch` seconds out) or a blow gets through to it: then the
##   shield comes up, turned to whoever it was, and stays up `raise_hold`
##   seconds past the last of them. For the first `raise_steady` of those it
##   does not swing itself (it would drop the shield into his blow); behind
##   the raised shield it walks in (`CR_ShieldWalk` and the rest: the walk's
##   legs, the guard's body, tools/creature_clips.gd LAYERED) instead of
##   running. Whatever comes at its front while the shield is up is caught
##   on it (the guard's stamina, as any [Fighter]'s block: spent, the guard
##   breaks and it stands open); from the side or behind (wider than
##   `shield_front`) it gets through, and magic goes through it. Caught, it
##   rocks behind the shield, and once his blows stop coming
##   (`counter_after`) it answers.
## * **The bash and the sword.** Its answer from behind the shield, mostly,
##   and now and then one of its attacks: the shield thrown into him
##   (`bash_clip`), and straight out of it the sword (`follow_clip`), one
##   combo to the hero. Its other attacks are the [Brawler]'s.
## * **Broken into bones** as every skeleton is ([member Brawler.shatter_on_death]).

@export_group("Shield")
@export var shield_pace: float = 1.6
@export var shield_walk_clip: StringName = &"CR_ShieldWalk"
@export var shield_back_clip: StringName = &"CR_ShieldBack"
@export var shield_l_clip: StringName = &"CR_ShieldL"
@export var shield_r_clip: StringName = &"CR_ShieldR"
@export var shield_idle_clip: StringName = &"CR_Block"
## How far round its front the shield covers: a blow from where the dot of
## its facing and the way to the striker is above this is caught.
@export var shield_front: float = 0.2
## How long the shield stays up past the last swing, shot or blow (s).
@export var raise_hold: float = 1.5
## How long after one it stands behind the shield without swinging (s).
@export var raise_steady: float = 0.4
## How far out (s of its flight) a missile coming at it raises the shield.
@export var missile_watch: float = 0.9
## Blows caught one after another, and how long behind the shield since the
## first, before it answers through them, his swings still coming (a hero
## hacking at the shield is bashed off it).
@export var answer_after_caught: int = 2
@export var answer_within: float = 0.6

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
## The sword straight after the bash (off: the bash alone, a hand with no
## sword in it).
@export var bash_follows: bool = true

const BASH := 74
const FOLLOW := 75

## The shield raised (every peer; the host decides it, [method net_guard]).
var guarding: bool = false
var _guard_for: float = 0.0
var _threat_age: float = 99.0
var _guard_from: Node3D = null
var _judged: Dictionary = {}
var _caught_run: int = 0
var _caught_for: float = 0.0

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
## Up: roused, raised against a swing, a shot or a blow ([member guarding]),
## and not in the middle of a move.
func shield_up() -> bool:
	if is_dead or not (mode == Mode.CHASE or mode == Mode.FIGHT):
		return false
	if act == Act.BLOCK:
		return true
	# Raised (still slowing out of a run, as well): it holds.
	return act == Act.NONE and guarding


## Free to raise it: roused, and not in a move of its own, broken or reeling.
func _may_raise() -> bool:
	if is_dead or not _decides() or not (mode == Mode.CHASE or mode == Mode.FIGHT):
		return false
	return act == Act.NONE or act == Act.BLOCK


## Host: the shield up (or kept up) against `who`, turned to them.
func _raise_shield(who: Node3D) -> void:
	if not _may_raise():
		return
	_guard_for = raise_hold
	_threat_age = 0.0
	_guard_from = who
	if who != null:
		_turn_to_threat(who.global_position)
	if not guarding:
		net_guard.rpc(true)


## Turned at once onto what comes from its front half, as a block is; from
## behind it is not spun round (it turns as it can, and may be too late).
func _turn_to_threat(point: Vector3) -> void:
	var to := point - global_position
	to.y = 0.0
	if to.length_squared() > 0.0001 and _forward().dot(to.normalized()) > -0.2:
		_face(to, 1.0, 1000.0)


func _physics_process(delta: float) -> void:
	if _decides():
		_keep_guard(delta)
	super(delta)


@rpc("authority", "call_local", "reliable")
func net_guard(on: bool) -> void:
	guarding = on


## Host: the shield's clock, and the missiles coming at it.
func _keep_guard(delta: float) -> void:
	_threat_age += delta
	_guard_for = maxf(_guard_for - delta, 0.0)
	if _caught_run > 0:
		_caught_for += delta
	_watch_missiles()
	var want := _guard_for > 0.0 and not is_dead and (mode == Mode.CHASE or mode == Mode.FIGHT)
	if want != guarding:
		net_guard.rpc(want)
	if not want:
		_guard_from = null
		_caught_run = 0
		_caught_for = 0.0


## Arrows, bolts and spears loosed by a hero, on a line through it and soon
## there: each raises the shield once, turned to whoever loosed it.
func _watch_missiles() -> void:
	if not (mode == Mode.CHASE or mode == Mode.FIGHT) or is_dead:
		return
	var centre := global_position + Vector3.UP * body_height * 0.55 * visual_scale
	for node in get_tree().get_nodes_in_group(&"missile"):
		var id := node.get_instance_id()
		if _judged.has(id) or not node.has_method("flight"):
			continue
		if bool(node.get("against_heroes")):
			continue
		var flight: Array = node.call("flight")
		if flight.is_empty():
			continue
		var at: Vector3 = flight[0]
		var going: Vector3 = flight[1]
		var speed2 := going.length_squared()
		if speed2 < 1.0:
			continue
		var when := (centre - at).dot(going) / speed2
		if when < 0.0 or when > missile_watch:
			continue
		if (at + going * when).distance_to(centre) > 1.4 * visual_scale:
			continue
		_judged[id] = true
		var shooter: Node3D = null
		if flight.size() > 2 and is_instance_valid(flight[2]):
			shooter = flight[2] as Node3D
		if shooter == null or not shooter.is_in_group(&"player"):
			# Turned to where it comes from, whoever loosed it.
			_raise_shield(null)
			_turn_to_threat(at)
		else:
			_raise_shield(shooter)
	if _judged.size() > 64:
		_judged.clear()


## A hero's swing begun at it: the shield up, whether or not it will reach.
func _answer_swing(knight: Node3D) -> void:
	super(knight)
	if knight == null or _moves_table.has(act):
		return
	var to_me := global_position - knight.global_position
	to_me.y = 0.0
	if to_me.length() > react_range:
		return
	_raise_shield(knight)


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
		_caught_run += 1
	var bled := super(damage, at, blow, from, magic)
	# A blow that got through: the shield up for the next.
	if bled and not is_dead and from != null:
		_raise_shield(from)
	return bled


#endregion


#region Thinking
func _think(delta: float) -> void:
	if mode == Mode.GUARD or mode == Mode.RETURN or is_dead:
		super(delta)
		return
	# Behind the shield, his blows over (or caught one after another): the
	# bash and the sword, mostly.
	var through := answer_after_caught > 0 and _caught_run >= answer_after_caught \
			and _caught_for >= answer_within and _act_time >= 0.1
	if counter_after > 0.0 and act == Act.BLOCK and _quarry != null \
			and (_act_time >= counter_after or through) and stamina >= attack_cost \
			and _distance_to(_quarry) <= reach + 0.4 and not _quarry_down():
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_caught_run = 0
		_caught_for = 0.0
		if _rng.randf() < counter_bash_chance:
			_begin_bash()
		else:
			_begin_attack()
		return
	_quarry = _pick_quarry()
	if _quarry != null and act == Act.NONE and guarding:
		var gap := _distance_to(_quarry)
		var toward := _guard_from if is_instance_valid(_guard_from) else _quarry
		if gap > reach:
			# Walking in behind the shield, not running.
			mode = Mode.CHASE
			_move_towards(_quarry.global_position, shield_pace, delta)
			_face(toward.global_position - global_position, delta, turn_speed * 2.0)
			return
		if _threat_age < raise_steady:
			# His blow on its way: behind the shield, not swinging into it.
			mode = Mode.FIGHT
			_face(toward.global_position - global_position, delta, turn_speed * 2.0)
			_slow(delta, 4.0)
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
	if what == BASH and not is_dead and bash_follows:
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
	_anim.play(clip, 0.2, gait_rate(clip, pace))
#endregion
