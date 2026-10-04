class_name Imp
extends ClipFighter

## The imp: a spiked mace in its right fist, claws on its left, and no patience.
##
## It keeps the [Fighter]'s body — band, leash, stamina, the blade watched for
## cuts — and fights its own way, out of clips made on its own rig
## (`assets/monsters/imp/imp_anims.glb`, vepxis-art `tools/imp_build.py`; the
## moves, the travel and the blows are [ClipFighter]'s):
##
## * **It circles.** Roused, it does not walk into the sword. It runs to a ring
##   round the one it hunts and strafes there, face on, working round towards his
##   back, keeping clear of the rest of its band.
## * **Two go in at a time** ([constant PACK]); the others circle, and now and then
##   one stops to flex and jeer.
## * **It hits and springs away.** From the ring it leaps in with the mace
##   overhead ([constant POUNCE]) or flips in feet first ([constant FLIP]); close
##   in it rakes with the claws, swings the mace, runs the two together, or brings
##   the mace down two-handed ([constant SLAM], which floors). Then it hops or
##   flips back out and circles again.
## * **It does not block, it gets out of the way** — a sidestep either side or a
##   backflip, the first moments of which nothing touches — and a knight who cut
##   at nothing is punished at once.
## * **Its body moves as its clips do.** How far each clip carries the hips was
##   measured in Blender (`imp_clip_meta.json`) and the body is driven along that
##   path, scaled to its size, into whatever it collides with; a leap is stretched
##   or shortened so it comes down where he stands; a cut throws it the way the
##   blade went, by the hit clip for that side.

## Its moves, as acts after the Fighter's own.
const SWIPE := 20
const MACE := 21
const COMBO := 22
const SLAM := 23
const POUNCE := 24
const FLIP := 25
const HOP := 26
const BACKFLIP := 27
const DODGE_L := 28
const DODGE_R := 29
const TAUNT := 30
const HIT_F := 31
const HIT_L := 32
const HIT_R := 33
const STAGGER := 34

## act -> [clip, rate, from, to]: which clip, how fast, and the share of it
## played (past a slow wind-up, short of a long settle).
const MOVES := {
	SWIPE: [&"IP_Swipe_L", 1.55, 0.22, 0.78],
	MACE: [&"IP_Swipe_R", 1.5, 0.22, 0.8],
	COMBO: [&"IP_Combo2", 1.35, 0.08, 0.86],
	SLAM: [&"IP_Overhead", 1.3, 0.1, 0.8],
	POUNCE: [&"IP_Pounce", 1.25, 0.1, 0.88],
	FLIP: [&"IP_FlipKick", 1.2, 0.0, 0.9],
	HOP: [&"IP_HopBack", 1.5, 0.12, 0.8],
	BACKFLIP: [&"IP_Backflip", 1.35, 0.1, 0.85],
	DODGE_L: [&"IP_Dodge_L", 1.3, 0.0, 0.85],
	DODGE_R: [&"IP_Dodge_R", 1.3, 0.0, 0.85],
	TAUNT: [&"IP_Flex", 1.3, 0.12, 0.5],
	HIT_F: [&"IP_Hit_F", 1.3, 0.0, 0.8],
	HIT_L: [&"IP_Hit_L", 1.3, 0.0, 0.8],
	HIT_R: [&"IP_Hit_R", 1.3, 0.0, 0.8],
	STAGGER: [&"IP_Stagger", 1.2, 0.0, 0.85],
}
## Attack -> [bones whose speed marks a blow, which limb lands it ("claw" /
## "weapon"), share of hit_damage, blows the player counts it as].
const STRIKES := {
	SWIPE: [["hand_l"], ["claw"], 0.55, 2],
	MACE: [["hand_r"], ["weapon"], 0.8, 2],
	COMBO: [["hand_l", "hand_r"], ["claw", "weapon"], 0.6, 3],
	SLAM: [["hand_r"], ["weapon"], 1.0, 1],
	POUNCE: [["hand_r", "hand_l"], ["weapon"], 1.0, 1],
	FLIP: [["foot_l", "foot_r"], ["feet"], 0.7, 2],
}
const EVADES := [HOP, BACKFLIP, DODGE_L, DODGE_R]
const HITS := [HIT_F, HIT_L, HIT_R, STAGGER]
## How many of a band go in at one man at once.
const PACK := 2

enum Tactic { CLOSE, CIRCLE, ENGAGE }

@export_group("Imp")
## The ring it circles at, metres from him.
@export var ring: Vector2 = Vector2(3.4, 5.4)
## Seconds it circles before it may go in again.
@export var circle_time: Vector2 = Vector2(0.5, 1.3)
@export var strafe_speed: float = 2.1
## Farthest it leaps in from.
@export var leap_range: float = 6.5
## How far off him a leap comes down: the arm and the mace ahead of it, about
## 1.45 m at its size, so the head of the mace and not the imp lands on him.
## (1.35: at 1.5 the mace came down 0.2 m short of a hero standing still.)
@export var land_off: float = 1.35
## The flip kick's feet reach less than the pounce's mace: it comes down nearer
## (at 1.5 m its feet passed 0.4 m short of him).
@export var flip_land_off: float = 1.05
## Chance it gets out of the way of a cut aimed at it.
@export_range(0.0, 1.0) var evade_chance: float = 0.5
## How long a sidestep or a flip is untouchable.
@export var evade_iframes: float = 0.5
## How far a sidestep carries it, metres at its size.
@export var dodge_distance: float = 2.6
## Share of a hit clip's travel it is thrown by (lighter creatures more).
@export var knock_scale: float = 1.0
## Fraction of its health one blow must take to stagger it rather than flinch it.
@export var stagger_share: float = 0.22

## Who holds a turn at whom: quarry's instance id -> the imps going in at him.
static var _turns: Dictionary = {}

var _tactic: int = Tactic.CLOSE
var _tactic_left: float = 0.0
var _circle_sign: float = 1.0
var _dodge_dir: Vector3 = Vector3.ZERO
var _counter: bool = false


func _ready() -> void:
	reacts = {
		Act.REACT_KNOCK: [[&"IP_Fall", 1.2, 1.0], [&"IP_GetUp", 1.5, 1.0]],
		Act.REACT_BURN: [[&"IP_Hit", 1.5, 1.0]],
		Act.REACT_POISON: [[&"IP_Stagger", 1.2, 0.8]],
	}
	super()
	_circle_sign = 1.0 if _rng.randf() < 0.5 else -1.0


func _exit_tree() -> void:
	_release()


func _moves() -> Dictionary:
	return MOVES


func _strikes() -> Dictionary:
	return STRIKES


#region Acting
func _fade_in(what: int) -> float:
	return 0.08 if HITS.has(what) or EVADES.has(what) else 0.12


func _carry(delta: float) -> Vector3:
	var v := super(delta)
	return v * knock_scale if HITS.has(act) else v


func _leaps() -> Array:
	return [POUNCE, FLIP]


## A leap comes down later than its clip's blow moment when it is stretched
## to the gap (the mace met him 0.1-0.5 s after it, past the window); the
## combo's claw comes in early and its mace late (`_shots_tmp/imp_blow_probe.gd`,
## 2026-10-04: the pounce, the flip and the combo all missed a hero standing
## still).
func _blow_window_for(what: int) -> Vector2:
	if what == POUNCE:
		return Vector2(blow_window.x, 0.55)
	if what == FLIP:
		return Vector2(blow_window.x, 0.34)
	if what == COMBO:
		return Vector2(0.26, 0.32)
	return blow_window


## The combo's second blow (the mace) fell 0.4 m short: it steps in closer.
func _strike_off_for(what: int) -> float:
	return 0.9 if what == COMBO else strike_off


func _track_rate(what: int) -> float:
	return turn_speed * (0.9 if what == POUNCE or what == FLIP else 0.5)


func _extra_velocity(delta: float) -> Vector3:
	var v := super(delta)
	if act == DODGE_L or act == DODGE_R or act == BACKFLIP:
		# In place in the clip: carried by hand, fast off the mark and easing out.
		var span := minf(_act_length, 0.55)
		var k := clampf(_act_time / span, 0.0, 1.0)
		var reach_out := dodge_distance * (1.0 if act != BACKFLIP else 1.1)
		v += _dodge_dir * reach_out * 2.0 * (1.0 - k) / span
	return v


## What follows a move: out of reach after a blow, a counter after a clean
## evade, and back to circling.
func _after(what: int) -> void:
	_start(Act.NONE)
	if STRIKES.has(what):
		_cooldown = _rng.randf_range(attack_cooldown.x, attack_cooldown.y)
		# Out again before he can answer: a hop back or a flip, or, one time in
		# four, it only backs off round the ring.
		if _quarry != null and not is_dead and _distance_to(_quarry) < reach * 1.5:
			var roll := _rng.randf()
			if roll < 0.5:
				_evade(HOP, 0.5)
				return
			elif roll < 0.75:
				_evade(BACKFLIP, 0.5)
				return
		_release()
		_set_tactic(Tactic.CIRCLE)
	elif EVADES.has(what):
		if _counter and _quarry != null and _distance_to(_quarry) < leap_range and stamina >= attack_cost:
			_counter = false
			_strike_from(_distance_to(_quarry))
			return
		_counter = false
		_release()
		_set_tactic(Tactic.CIRCLE)
	else:
		_set_tactic(Tactic.CIRCLE)
#endregion


#region Thinking
func _think(delta: float) -> void:
	if mode == Mode.GUARD or mode == Mode.RETURN:
		super(delta)
		return
	_quarry = _pick_quarry()
	if _quarry == null:
		_release()
		_go_home()
		return
	if act != Act.NONE:
		return
	var gap := _distance_to(_quarry)
	_tactic_left -= delta
	match _tactic:
		Tactic.CLOSE:
			mode = Mode.CHASE
			if gap <= ring.y:
				_set_tactic(Tactic.CIRCLE)
			else:
				_move_towards(_quarry.global_position, chase_speed, delta)
		Tactic.CIRCLE:
			mode = Mode.FIGHT
			if gap > ring.y + 2.5:
				_set_tactic(Tactic.CLOSE)
				return
			_circle(gap, delta)
			if _tactic_left <= 0.0 and _cooldown <= 0.0 and stamina >= attack_cost:
				if _take_turn():
					if gap <= leap_range and gap >= ring.x - 0.4 and _rng.randf() < 0.55:
						_strike_from(gap)
					else:
						_set_tactic(Tactic.ENGAGE)
				elif _rng.randf() < 0.25:
					_begin(TAUNT)
				else:
					_tactic_left = _rng.randf_range(circle_time.x, circle_time.y) * 0.6
		Tactic.ENGAGE:
			mode = Mode.FIGHT
			if gap <= reach:
				_strike_from(gap)
			else:
				_move_towards(_quarry.global_position, chase_speed, delta)
				if gap > ring.y + 3.0:
					_release()
					_set_tactic(Tactic.CLOSE)


func _set_tactic(what: int) -> void:
	_tactic = what
	_tactic_left = _rng.randf_range(circle_time.x, circle_time.y)
	if what == Tactic.CIRCLE and _rng.randf() < 0.3:
		_circle_sign = -_circle_sign


## Picks the blow for the gap it is at: a leap or a flip from the ring, a
## claw, the mace, the pair of them or the slam close in.
func _strike_from(gap: float) -> void:
	if gap > reach * 1.25:
		var what := POUNCE if _rng.randf() < 0.7 else FLIP
		_face(_quarry.global_position - global_position, 1.0, 1000.0)
		_begin(what)
		# The leap is stretched or cut so it comes down on him.
		var land := _blow_moments(what)[0]
		var travelled := _hips(_clip_of(what), _clip_time(what, land)).x
		var want := gap - (land_off if what == POUNCE else flip_land_off)
		_stretch = clampf(want / maxf(travelled, 0.2), 0.3, 2.2)
		return
	var roll := _rng.randf()
	var what := SWIPE
	if roll < 0.3:
		what = SWIPE
	elif roll < 0.55:
		what = MACE
	elif roll < 0.85:
		what = COMBO
	else:
		what = SLAM
	_face(_quarry.global_position - global_position, 1.0, 1000.0)
	_begin(what)


## Strafes round him, face on, towards his back, holding the middle of the ring
## and keeping off its own band.
func _circle(gap: float, delta: float) -> void:
	var to_him := _quarry.global_position - global_position
	to_him.y = 0.0
	var inward := to_him.normalized()
	_face(inward, delta, turn_speed * 1.5)
	# Which way round is towards his back.
	var his_ahead := -_quarry.global_transform.basis.z
	his_ahead.y = 0.0
	var round_dir := inward.cross(Vector3.UP) * _circle_sign
	var behind := (-inward).dot(his_ahead.normalized())
	if behind < 0.6:
		var toward_back := round_dir.dot(-his_ahead.normalized())
		if toward_back < -0.1 and _rng.randf() < delta * 1.5:
			_circle_sign = -_circle_sign
			round_dir = -round_dir
	var middle := (ring.x + ring.y) * 0.5
	# Inside the ring it backs out quickly; outside it drifts in.
	var radial := inward * clampf((gap - middle) * 1.8, -3.5, 1.5)
	var apart := Vector3.ZERO
	for node in get_tree().get_nodes_in_group(band) if not band.is_empty() else []:
		var mate := node as Node3D
		if mate == null or mate == self:
			continue
		var off := global_position - mate.global_position
		off.y = 0.0
		var d := off.length()
		if d > 0.01 and d < 3.0:
			apart += off / d * (3.0 - d)
	# no faster round him than its strafe can step (backing out of the ring
	# fast had its legs at x2.2, 2026-10-04); inside the ring, out of reach of
	# his sword a little quicker
	var top := strafe_speed * (1.6 if gap < ring.x else 1.1)
	var want := (round_dir * strafe_speed + radial + apart * 1.2).limit_length(top)
	velocity.x = move_toward(velocity.x, want.x, acceleration * 2.0 * delta)
	velocity.z = move_toward(velocity.z, want.z, acceleration * 2.0 * delta)


func _take_turn() -> bool:
	if _quarry == null:
		return false
	var key := _quarry.get_instance_id()
	var holders: Array = (_turns.get(key, []) as Array).filter(func(o: Variant) -> bool:
		return is_instance_valid(o) and not (o as Imp).is_dead and (o as Imp)._quarry != null \
				and (o as Imp)._quarry.get_instance_id() == key)
	if holders.has(self):
		_turns[key] = holders
		return true
	if holders.size() >= PACK:
		_turns[key] = holders
		return false
	holders.append(self)
	_turns[key] = holders
	return true


func _release() -> void:
	for key in _turns:
		(_turns[key] as Array).erase(self)
#endregion


#region Defence
## A cut coming: it gets out of the way — sideways, or flipping back when he is
## right on it — and, if the cut met nothing, goes straight back in.
func _answer_swing(knight: Node3D) -> void:
	if is_dead or STRIKES.has(act) or EVADES.has(act) or act == Act.REEL or HITS.has(act):
		return
	var to_me := global_position - knight.global_position
	to_me.y = 0.0
	if to_me.length() > react_range:
		return
	var knight_ahead := -knight.global_transform.basis.z
	knight_ahead.y = 0.0
	if knight_ahead.normalized().dot(to_me.normalized()) < 0.2:
		return
	_rouse(knight)
	_quarry = knight
	if _rng.randf() >= evade_chance or stamina < dash_cost:
		return
	_face(-to_me, 1.0, 1000.0)
	if to_me.length() < 2.0 and _rng.randf() < 0.5:
		_evade(BACKFLIP if _rng.randf() < 0.5 else HOP)
	else:
		_evade(DODGE_L if _rng.randf() < 0.5 else DODGE_R)
	_counter = _rng.randf() < 0.7


func _evade(what: int, cost: float = 1.0) -> void:
	stamina = maxf(stamina - dash_cost * cost, 0.0)
	_regen_wait = regen_delay
	_begin(what)
	var ahead := _forward()
	var right := ahead.cross(Vector3.UP)
	match what:
		DODGE_L:
			_dodge_dir = (-right * 0.9 - ahead * 0.35).normalized()
		DODGE_R:
			_dodge_dir = (right * 0.9 - ahead * 0.35).normalized()
		BACKFLIP:
			_dodge_dir = -ahead
		_:
			_dodge_dir = Vector3.ZERO


func is_evading() -> bool:
	return EVADES.has(act) and _act_time < evade_iframes + 0.15


func _receive(damage: float, at: Vector3, blow: Vector3, from: Node3D, magic: bool = false) -> bool:
	if EVADES.has(act) and _act_time < evade_iframes:
		return false
	var hurt_before := health
	var landed := super(damage, at, blow, from, magic)
	if not landed or is_dead:
		return landed
	# Light: a cut stops what it was doing and throws it the way the blade went,
	# unless it is already in the air coming down on him.
	var airborne := (act == POUNCE or act == FLIP) and _act_time > _move_length(act) * 0.2 \
			and _act_time < _blow_moments(act)[0] + 0.1
	if airborne:
		return landed
	var thrown := blow
	thrown.y = 0.0
	var ahead := _forward()
	var right := ahead.cross(Vector3.UP)
	var what := HIT_F
	if hurt_before - health >= max_health * stagger_share:
		what = STAGGER
	elif thrown.length_squared() > 0.0001:
		thrown = thrown.normalized()
		if thrown.dot(right) > 0.5:
			what = HIT_R
		elif thrown.dot(right) < -0.5:
			what = HIT_L
	_counter = false
	_release()
	# Thrown straight back: turned to face the blow, so the clip carries it away.
	if (what == HIT_F or what == STAGGER) and thrown.length_squared() > 0.0001:
		_face(-thrown, 1.0, 1000.0)
	_begin(what)
	return landed
#endregion
