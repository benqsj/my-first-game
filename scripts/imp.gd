class_name Imp
extends Fighter

## The imp: a spiked mace in its right fist, claws on its left, and no patience.
##
## It keeps the [Fighter]'s body — band, leash, stamina, the blade watched for
## cuts — and fights its own way, out of clips made on its own rig
## (`assets/monsters/imp/imp_anims.glb`, vepxis-art `tools/imp_build.py`):
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
## "mace"), share of hit_damage, blows the player counts it as].
const STRIKES := {
	SWIPE: [["hand_l"], ["claw"], 0.55, 2],
	MACE: [["hand_r"], ["mace"], 0.8, 2],
	COMBO: [["hand_l", "hand_r"], ["claw", "mace"], 0.6, 3],
	SLAM: [["hand_r"], ["mace"], 1.0, 1],
	POUNCE: [["hand_r", "hand_l"], ["mace"], 1.0, 1],
	FLIP: [["foot_l", "foot_r"], ["feet"], 0.7, 2],
}
const EVADES := [HOP, BACKFLIP, DODGE_L, DODGE_R]
const HITS := [HIT_F, HIT_L, HIT_R, STAGGER]
## How many of a band go in at one man at once.
const PACK := 2
## Where the mace's head is, in the right hand's own frame (measured off the
## mesh), and how thick the spikes make it.
const MACE_TIP := Vector3(-0.15, 0.12, 0.47)
const MACE_RADIUS := 0.14
const CLAW_RADIUS := 0.1
const FOOT_RADIUS := 0.11
const META_PATH := "res://assets/monsters/imp/imp_clip_meta.json"

enum Tactic { CLOSE, CIRCLE, ENGAGE }

@export_group("Imp")
## The ring it circles at, metres from him.
@export var ring: Vector2 = Vector2(3.4, 5.4)
## Seconds it circles before it may go in again.
@export var circle_time: Vector2 = Vector2(0.7, 2.0)
@export var strafe_speed: float = 2.6
## Farthest it leaps in from.
@export var leap_range: float = 6.5
## How far off him a leap comes down: the arm and the mace ahead of it, about
## 1.45 m at its size, so the head of the mace and not the imp lands on him.
@export var land_off: float = 1.5
## How close it steps in under a blow on foot.
@export var strike_off: float = 1.3
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
static var _meta: Dictionary = {}

var _tactic: int = Tactic.CLOSE
var _tactic_left: float = 0.0
var _circle_sign: float = 1.0
## The body's frame when the move began: travel is laid along it.
var _move_fwd: Vector3 = Vector3.FORWARD
var _move_right: Vector3 = Vector3.RIGHT
## Forward travel is stretched by this (a leap sized to the gap).
var _stretch: float = 1.0
var _last_hips: Vector2 = Vector2.ZERO
var _dodge_dir: Vector3 = Vector3.ZERO
var _counter: bool = false
var _hand_r: int = -1
var _hand_l: int = -1
var _fore_l: int = -1
var _tip_l: int = -1
var _foot_l: int = -1
var _foot_r: int = -1
var _calf_l: int = -1
var _calf_r: int = -1
## Blow moments per attack, act seconds, measured once per kind.
static var _moments: Dictionary = {}


func _ready() -> void:
	reacts = {
		Act.REACT_KNOCK: [[&"IP_Fall", 1.2, 1.0], [&"IP_GetUp", 1.5, 1.0]],
		Act.REACT_BURN: [[&"IP_Hit", 1.5, 1.0]],
		Act.REACT_POISON: [[&"IP_Stagger", 1.2, 0.8]],
	}
	super()
	if _meta.is_empty() and FileAccess.file_exists(META_PATH):
		_meta = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	if _skeleton != null:
		_hand_r = _skeleton.find_bone("hand_r")
		_hand_l = _skeleton.find_bone("hand_l")
		_fore_l = _skeleton.find_bone("lowerarm_l")
		_tip_l = _skeleton.find_bone("middle_04_leaf_l")
		_foot_l = _skeleton.find_bone("ball_l")
		_foot_r = _skeleton.find_bone("ball_r")
		_calf_l = _skeleton.find_bone("calf_l")
		_calf_r = _skeleton.find_bone("calf_r")
	_circle_sign = 1.0 if _rng.randf() < 0.5 else -1.0


func _exit_tree() -> void:
	_release()


#region Clips
func _clip_of(what: int) -> StringName:
	return (MOVES[what] as Array)[0]


## Seconds the move lasts on the act clock.
func _move_length(what: int) -> float:
	var m: Array = MOVES[what]
	if _anim == null:
		return 0.6
	return _anim.clip_length(m[0]) * (float(m[3]) - float(m[2])) / float(m[1])


## Where the clip is, in its own seconds, this far into the move.
func _clip_time(what: int, t: float) -> float:
	var m: Array = MOVES[what]
	return _anim.clip_length(m[0]) * float(m[2]) + t * float(m[1])


## The moments of an attack's blows, in act seconds.
func _blow_moments(what: int) -> PackedFloat32Array:
	if _moments.has(what):
		return _moments[what]
	var out := PackedFloat32Array()
	if _anim != null:
		var m: Array = MOVES[what]
		var s: Array = STRIKES[what]
		var clip: StringName = m[0]
		var length := _anim.clip_length(clip)
		var peaks := _anim.measure_peaks(clip, PackedStringArray(s[0]), 0.6, 0.12)
		for p in peaks:
			if p < float(m[2]) or p > float(m[3]):
				continue
			out.append((p - float(m[2])) * length / float(m[1]))
		var wanted: int = (s[1] as Array).size()
		if out.size() > wanted:
			# Keep the latest ones: the fastest early motion is the wind-up.
			out = out.slice(out.size() - wanted)
		if out.is_empty():
			out.append(_move_length(what) * 0.45)
	_moments[what] = out
	return out


## Where the hips have got to, forward and to its left, metres on this body.
func _hips(clip: StringName, t: float) -> Vector2:
	var m: Dictionary = _meta.get(String(clip), {})
	var path: Array = m.get("hips", [])
	if path.is_empty():
		return Vector2.ZERO
	var f := clampf(t * float(m.get("fps", 30.0)), 0.0, float(path.size() - 1))
	var i := int(f)
	var j := mini(i + 1, path.size() - 1)
	var a: Array = path[i]
	var b: Array = path[j]
	var w := f - float(i)
	return Vector2(lerpf(float(a[0]), float(b[0]), w), lerpf(float(a[1]), float(b[1]), w)) \
			* maxf(visual_scale, 0.01)
#endregion


#region Acting
func _begin(what: int) -> void:
	_start(what)
	_act_length = _move_length(what)
	_move_fwd = _forward()
	_move_right = _move_fwd.cross(Vector3.UP)
	_stretch = 1.0
	_last_hips = _hips(_clip_of(what), _clip_time(what, 0.0))
	if STRIKES.has(what):
		stamina -= attack_cost
		_regen_wait = regen_delay
		_arm(what)


## Lays the attack's blows along its limbs, live around each moment.
func _arm(what: int) -> void:
	if _skeleton == null:
		return
	var s: Array = STRIKES[what]
	var limbs: Array = s[1]
	var moments := _blow_moments(what)
	var worth := hit_damage * float(s[2])
	var count: int = s[3]
	for i in moments.size():
		var limb: String = limbs[mini(i, limbs.size() - 1)]
		var stretches := _mace_part if limb == "mace" else (_claw_part if limb == "claw" else _feet_part)
		var blow := i
		var serial := act_serial
		_sweeps.append(WeaponSweep.blow(stretches, 2.0, moments[i] - BLOW_BEFORE, moments[i] + BLOW_AFTER,
				act_serial, func(who: Node3D) -> void:
					who.call("receive_blow", worth, self, blow, count, serial)))


func _mace_part() -> Array:
	if _hand_r < 0:
		return []
	var s := maxf(visual_scale, 0.01)
	return [WeaponSweep.bones(_skeleton, _hand_r, _hand_r, MACE_RADIUS * s, MACE_TIP)]


func _claw_part() -> Array:
	if _fore_l < 0 or _hand_l < 0:
		return []
	var s := maxf(visual_scale, 0.01)
	var out := [WeaponSweep.bones(_skeleton, _fore_l, _hand_l, CLAW_RADIUS * s)]
	if _tip_l >= 0:
		out.append(WeaponSweep.bones(_skeleton, _hand_l, _tip_l, CLAW_RADIUS * s))
	return out


func _feet_part() -> Array:
	var out := []
	var s := maxf(visual_scale, 0.01)
	if _calf_l >= 0 and _foot_l >= 0:
		out.append(WeaponSweep.bones(_skeleton, _calf_l, _foot_l, FOOT_RADIUS * s))
	if _calf_r >= 0 and _foot_r >= 0:
		out.append(WeaponSweep.bones(_skeleton, _calf_r, _foot_r, FOOT_RADIUS * s))
	return out


func _play_act() -> void:
	if not MOVES.has(act):
		super()
		return
	var m: Array = MOVES[act]
	_anim.play(m[0], 0.08 if HITS.has(act) or EVADES.has(act) else 0.12, float(m[1]), 1.0, true)
	_anim.seek(_anim.clip_length(m[0]) * float(m[2]))


func _run_act(delta: float) -> void:
	if not MOVES.has(act):
		super(delta)
		return
	var clip := _clip_of(act)
	var t := _clip_time(act, _act_time)
	var hips := _hips(clip, t)
	var step := hips - _last_hips
	_last_hips = hips
	var carry := _move_fwd * step.x * _stretch - _move_right * step.y
	if HITS.has(act):
		carry *= knock_scale
	var v := carry / maxf(delta, 0.0001)
	if act == DODGE_L or act == DODGE_R or act == BACKFLIP:
		# In place in the clip: carried by hand, fast off the mark and easing out.
		var span := minf(_act_length, 0.55)
		var k := clampf(_act_time / span, 0.0, 1.0)
		var reach_out := dodge_distance * (1.0 if act != BACKFLIP else 1.1)
		v += _dodge_dir * reach_out * 2.0 * (1.0 - k) / span
	if STRIKES.has(act):
		_track_before_blow(delta)
		v += _close_gap()
	velocity.x = v.x
	velocity.z = v.z
	if _act_time >= _act_length:
		_after(act)


## Turns to follow him until the first blow is on its way, then commits.
func _track_before_blow(delta: float) -> void:
	if _quarry == null:
		return
	var first := _blow_moments(act)[0]
	if _act_time < first - 0.2:
		var rate := turn_speed * (0.9 if act == POUNCE or act == FLIP else 0.5)
		_face(_quarry.global_position - global_position, delta, rate)
		_move_fwd = _forward()
		_move_right = _move_fwd.cross(Vector3.UP)


## A step in under the clip's own travel, so the blow lands where he stands.
func _close_gap() -> Vector3:
	if _quarry == null or act == POUNCE or act == FLIP:
		return Vector3.ZERO
	var moments := _blow_moments(act)
	var next := -1.0
	for m in moments:
		if m > _act_time:
			next = m
			break
	if next < 0.0:
		return Vector3.ZERO
	var gap := _distance_to(_quarry)
	var want := strike_off
	if gap <= want:
		return Vector3.ZERO
	return _forward() * minf((gap - want) / maxf(next - _act_time, 0.15), close_speed)


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
		var want := gap - land_off
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
	var want := (round_dir * strafe_speed + radial + apart * 1.2).limit_length(chase_speed)
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


#region Moving about
func _play_locomotion(_delta: float) -> void:
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var pace := planar.length()
	var roused := mode == Mode.CHASE or mode == Mode.FIGHT
	if pace < 0.15:
		if _anim.current_clip() != idle_clip or _anim.clip_progress() >= 1.0:
			_anim.play(idle_clip, 0.25, 1.0)
		return
	var ahead := _forward()
	var right := ahead.cross(Vector3.UP)
	var fwd := planar.dot(ahead)
	var side := planar.dot(right)
	var clip := walk_clip
	if absf(side) > absf(fwd) * 1.1:
		clip = &"IP_Strafe_R" if side > 0.0 else &"IP_Strafe_L"
	elif fwd < 0.0:
		clip = &"IP_Back"
	elif pace > 3.2:
		clip = &"IP_Run"
	elif roused:
		clip = &"IP_Sneak"
	var stride := maxf(_anim.measure_stride(clip), 0.2) * maxf(visual_scale, 0.01)
	var rate := pace * _anim.clip_length(clip) / stride
	_anim.play(clip, 0.2, clampf(rate, retime_range.x, chase_retime_max))
#endregion
