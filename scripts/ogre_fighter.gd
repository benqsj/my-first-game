class_name OgreFighter
extends PackBrute

## The ogre (Polysplit's Biped Creatures, CREATURES_PACK.md): a great club,
## slow and heavy (the user's picks, 2026-10-07; its fight made over in
## Elden Ring's way, 2026-10-08: "it does the same combo again and again").
##
## * **Strings, light and heavy.** Its swings are of two kinds: quick light
##   ones (a sweep, a chop, a backhand, a low sweep, a wide one round to the
##   side), that only stagger him, and heavy ones (an overhead smash, a
##   cleave, a leaping slam, a whirl brought down) that throw him down by
##   themselves (Elden Ring's rule, the user's word 2026-10-09: "not every
##   second blow should knock you down"). Each swing may run on into another
##   (`FOLLOW`, weighed; never the same twice running), up to `string_most`
##   of them, each turned a little after him; the close of a long one
##   (`finisher_from`) fells him too, light or not, if all of it found him.
##   Then it stands to get its breath (`recover`) — the opening.
## * **Where he stands chooses.** Off to its side it sweeps round at him; at
##   its back, the backhand; hugging it, a kick that beats a raised shield
##   aside; 4.5-8 m off, a lunge; the opener it began with last time is
##   seldom the next.
## * **Delayed swings** ([PackBrute] `_holds`): a heavy one, now and then,
##   held at the top of its wind-up before it comes down. And the roll-catch
##   (`CATCH`): him rolled out from under a blow, the next comes held a
##   beat, timed for the end of a roll made too early.
## * **Tracking, then committed** (Elden Ring's): each swing and leap turns
##   after him up to a late point before its blow (`commit_lead`), and is
##   locked from there — it is the timing of a roll that beats it, not
##   running from it.
## * **Its gait** (the user's word, 2026-10-09): a heavy walk of long strides
##   about its ground, a lumbering trot (`trot_clip`) coming at him, and a
##   real run (`run_speed`) when he plainly runs from it; each clip played at
##   the pace its feet keep to the ground.
## * **From afar** (the distance ladder): 4.5-8 m the sword dash (`LUNGE`);
##   8-14 m a great leap with the club overhead, brought down on him
##   (`LEAP_SLAM`); 12-22 m it runs at him, springs high and comes down club
##   first (`RUN_SLAM`). Both fell him; they follow him till they leave the
##   ground and are locked a little after.
## * **Aftershock**: a single heavy blow or a slam that strikes the ground is
##   followed a beat later by a second burst of earth ahead of it — the one
##   who comes back in too soon is caught (a jump or a roll clears it).
## * **The ground struck** (`CR_GroundPound`): the club brought down on the
##   ground sends a shock out round it ([PackBrute._quake], `pound_radius`):
##   whoever is on the ground as it passes is thrown down. Jump it, or roll.
## * **The great blow** (`CR_Heavy2`): the club raised slowly overhead, glowing
##   hotter as it goes (`heavy_slow`), and brought down: no shield holds it
##   (a "crush": the guard is beaten down and most of it lands), and it
##   throws him down. Get out from under it.
## * **The fallen trodden.** Him down within `stomp_reach`: the club brought
##   down on him where he lies ("stomp"). Roll out, or get up quick.
## * **Its stance** ([PackBrute]): no blow stops it or pushes it about, but
##   enough of them, heavy ones above all, put it down on a knee, open.
## * **Rage** ([PackBrute]): at half its health — and its strings run longer,
##   with the pound and the great blow in them.

@export_group("Pound")
@export var pound_clip: StringName = &"CR_GroundPound"
@export var pound_part: Vector3 = Vector3(1.0, 0.0, 0.92)
@export var pound_radius: float = 5.5
@export var pound_share: float = 0.85
@export var pound_from: float = 1.5
@export var pound_to: float = 5.0
@export var pound_cooldown: Vector2 = Vector2(9.0, 14.0)

@export_group("Great blow")
@export var heavy_clip: StringName = &"CR_Heavy2"
@export var heavy_part: Vector3 = Vector3(0.95, 0.0, 0.9)
## How many times slower its wind-up is played, and how long before the blow
## it comes back to its own pace.
@export var heavy_slow: float = 2.4
@export var heavy_lead: float = 0.18
@export var heavy_share: float = 1.5
@export var heavy_cooldown: Vector2 = Vector2(8.0, 13.0)

@export_group("Stomp")
@export var stomp_clip: StringName = &"CR_Heavy2"
@export var stomp_part: Vector3 = Vector3(1.3, 0.0, 0.85)
@export var stomp_reach: float = 3.4
@export var stomp_share: float = 0.6
@export var stomp_cooldown: float = 5.0
## The share of the times it treads on him down rather than wait for him.
@export var stomp_chance: float = 0.6

@export_group("Strings")
## The most swings in one string, calm and enraged.
@export var string_most: int = 3
@export var string_most_raging: int = 5
## Its breath got back after a string ends (s), calm and enraged.
@export var recover: Vector2 = Vector2(1.0, 1.9)
@export var recover_raging: Vector2 = Vector2(0.4, 0.9)
## How far it turns after him between two swings of a string (degrees).
@export var string_turn: float = 55.0
@export var lunge_from: float = 4.5
@export var lunge_to: float = 8.0
@export var lunge_cooldown: Vector2 = Vector2(6.0, 10.0)
@export var kick_cooldown: float = 4.0
@export_group("Gait")
## Its trot coming at him (the walk is `walk_clip`, the run `run_clip`); the
## paces it changes from walk to trot and from trot to run (m/s).
@export var trot_clip: StringName = &"CR_OgreTrot"
@export var trot_above: float = 2.9
@export var run_gait_above: float = 4.9
## Its run, when he runs from it: the gap opening this fast (m/s) for this
## long (s) with him this far off.
@export var run_speed: float = 6.0
@export var flee_rate: float = 1.2
@export var flee_time: float = 0.6
@export var flee_from: float = 5.0

@export_group("From afar")
@export var leap_slam_clip: StringName = &"CR_Heavy4"
@export var leap_slam_part: Vector3 = Vector3(1.0, 0.0, 0.92)
@export var leap_slam_from: float = 8.0
@export var leap_slam_to: float = 14.0
@export var leap_slam_cooldown: Vector2 = Vector2(8.0, 12.0)
@export var leap_slam_share: float = 1.3
@export var run_slam_clip: StringName = &"CR_RunJumpSlam"
@export var run_slam_part: Vector3 = Vector3(1.0, 0.218, 1.0)
@export var run_slam_from: float = 12.0
@export var run_slam_to: float = 22.0
## It springs off its run this far from him.
@export var run_slam_takeoff: float = 9.5
@export var run_slam_cooldown: Vector2 = Vector2(10.0, 16.0)
@export var run_slam_share: float = 1.5

@export_group("Elden Ring")
## How long before a blow it stops turning after him (s): light, heavy.
@export var commit_lead: Vector2 = Vector2(0.28, 0.36)
## The roll-catch's hold, and how often it answers a roll with it.
@export var catch_hold: Vector2 = Vector2(0.42, 0.55)
@export var catch_chance: float = 0.65
## The aftershock: how long after the blow, how far ahead of the club, how
## wide, and its worth (a share of `hit_damage`; it staggers, never fells).
@export var aftershock_after: float = 0.4
@export var aftershock_ahead: float = 1.1
@export var aftershock_radius: float = 2.6
@export var aftershock_share: float = 0.45

@export_group("Strings")
## The closing swing of a string this long or longer (calm, enraged) throws
## him down even if it is a light one — if every blow of the string before
## it found him ([Player.receive_blow]). Shorter strings end on a stagger.
@export var finisher_from: Vector2i = Vector2i(3, 4)

const SOUNDS := "res://sounds/ogre/"
const WHOOSH_HEAVY := SOUNDS + "whoosh_heavy.wav"
const WHOOSH_LIGHT := SOUNDS + "whoosh_light.wav"
const ROAR_SOUND := SOUNDS + "roar.wav"
const ROAR_SHORT_SOUND := SOUNDS + "roar_short.wav"
const GRUNTS := [SOUNDS + "grunt_1.wav", SOUNDS + "grunt_2.wav", SOUNDS + "grunt_3.wav"]
const CLUB_GROUND := [SOUNDS + "club_ground_1.wav", SOUNDS + "club_ground_2.wav", SOUNDS + "club_ground_3.wav",
		SOUNDS + "club_ground_4.wav"]
const STEPS := [SOUNDS + "step_1.wav", SOUNDS + "step_2.wav", SOUNDS + "step_3.wav"]

const POUND := 113
const HEAVY := 114
const STOMP := 115
## Its light swings.
const SWEEP := 130
const CHOP := 131
const BACKHAND := 132
const WIDE := 133
const LOW := 134
## Its heavy ones.
const SMASH := 135
const CLEAVE := 136
const JUMP_SLAM := 137
const WHIRL := 138
## A kick at him hugging it, and a lunge from further off.
const KICK := 139
const LUNGE := 140
## Its leaps from afar, and the roll-catch.
const LEAP_SLAM := 141
const RUN_SLAM := 143
const CATCH := 144
## A leap's flight drawn out: act -> [clip s it leaves the ground, clip s it
## lands, how many times slower the flight is played], and how high the
## body is lifted on top of the clip's own jump (m at its size).
const FLIGHTS := {
	LEAP_SLAM: [0.05, 0.45, 2.2, 1.0],
	RUN_SLAM: [0.87, 1.62, 1.35, 0.55],
}

## what -> [clip, [rate, from, to], heavy, share of `hit_damage`, how often
## it opens with it, how it does from his side (`_side_weight`), whether it
## fells him (1: it does, by itself; 99: not — but the closing blow of a long
## string does, [member finisher_from])].
const SWINGS := {
	SWEEP: [&"CR_Slash1", Vector3(0.85, 0.0, 0.9), false, 0.55, 1.0, &"front", 99],
	CHOP: [&"CR_Slash4", Vector3(0.85, 0.0, 0.9), false, 0.6, 1.0, &"front", 99],
	BACKHAND: [&"CR_RegB", Vector3(0.8, 0.0, 0.92), false, 0.6, 0.35, &"behind", 99],
	WIDE: [&"CR_Slash3", Vector3(0.82, 0.0, 0.92), false, 0.65, 0.6, &"side", 99],
	LOW: [&"CR_LightD", Vector3(0.85, 0.0, 0.9), false, 0.55, 0.7, &"side", 99],
	SMASH: [&"CR_Heavy1", Vector3(1.0, 0.0, 0.92), true, 1.05, 0.9, &"front", 1],
	CLEAVE: [&"CR_Heavy3", Vector3(1.0, 0.0, 0.92), true, 1.0, 0.8, &"front", 1],
	JUMP_SLAM: [&"CR_Heavy4", Vector3(1.0, 0.0, 0.92), true, 1.2, 0.5, &"front", 1],
	WHIRL: [&"CR_HeavyD", Vector3(0.9, 0.0, 0.95), true, 1.35, 0.3, &"front", 1],
	KICK: [&"CR_Kick", Vector3(0.95, 0.0, 0.85), false, 0.35, 0.0, &"front", 99],
	LUNGE: [&"CR_SwordDash", Vector3(0.9, 0.0, 0.9), false, 0.7, 0.0, &"front", 99],
	# The smash, held a beat for the end of his roll: never an opener.
	CATCH: [&"CR_Heavy1", Vector3(1.0, 0.0, 0.92), true, 1.05, 0.0, &"front", 1],
}

## What a swing may run on into: [what, weight]; -1 is the string's end.
const FOLLOW := {
	SWEEP: [[BACKHAND, 0.45], [CHOP, 0.25], [SMASH, 0.2], [CATCH, 0.12], [-1, 0.2]],
	BACKHAND: [[SMASH, 0.35], [LOW, 0.2], [WHIRL, 0.15], [-1, 0.25]],
	CHOP: [[SWEEP, 0.3], [CLEAVE, 0.3], [CATCH, 0.12], [-1, 0.25]],
	LOW: [[CLEAVE, 0.35], [BACKHAND, 0.2], [-1, 0.25]],
	WIDE: [[SMASH, 0.3], [BACKHAND, 0.25], [CATCH, 0.1], [-1, 0.3]],
	CATCH: [[WIDE, 0.25], [SWEEP, 0.15], [-1, 0.6]],
	LEAP_SLAM: [[WIDE, 0.25], [BACKHAND, 0.15], [-1, 0.6]],
	RUN_SLAM: [[-1, 1.0]],
	SMASH: [[CLEAVE, 0.3], [WIDE, 0.2], [-1, 0.4]],
	CLEAVE: [[WHIRL, 0.2], [SWEEP, 0.2], [-1, 0.5]],
	JUMP_SLAM: [[WIDE, 0.35], [SMASH, 0.2], [-1, 0.35]],
	WHIRL: [[-1, 1.0]],
	KICK: [[SMASH, 0.45], [SWEEP, 0.35], [-1, 0.2]],
	LUNGE: [[BACKHAND, 0.35], [SMASH, 0.3], [CHOP, 0.2], [-1, 0.15]],
	POUND: [[SWEEP, 0.25], [-1, 0.75]],
	HEAVY: [[-1, 1.0]],
}
## Enraged, on top: the pound and the great blow come into its strings.
const FOLLOW_RAGING := {
	SMASH: [[JUMP_SLAM, 0.25]],
	CLEAVE: [[POUND, 0.3]],
	WHIRL: [[POUND, 0.5], [-1, -0.5]],
	POUND: [[HEAVY, 0.4], [JUMP_SLAM, 0.3]],
	HEAVY: [[POUND, 0.4], [-1, -0.4]],
	JUMP_SLAM: [[WHIRL, 0.25]],
}

var _pound_wait: float = 3.0
var _heavy_wait: float = 2.0
var _stomp_wait: float = 0.0
var _lunge_wait: float = 3.0
var _kick_wait: float = 0.0
## Act seconds the club meets the ground in the pound and the stomp.
var _pound_at: float = 0.5
var _stomp_at: float = 0.5
var _pounded: bool = false
## Host: how many swings into this string, the swing it opened with last, and
## the moves it has made (for a test).
var _string_count: int = 0
var _last_opener: int = -1
var _lunge_speed: float = 0.0
var moves_made: Array[int] = []
## Host: this swing closes its string (and fells him), and the blows of the
## string so far by their kind (each kind is a combo of its own to him).
var _closing: bool = false
var _kind_blows: Dictionary = {}
var finishers_made: int = 0
## Host: the leaps' waits and speed, the run-up at him, whether he is running
## from it (and how long the gap has been opening), the gap a tick ago.
var _leap_slam_wait: float = 4.0
var _run_slam_wait: float = 5.0
var _flight_speed: float = 0.0
var _charging: bool = false
var _charge_time: float = 0.0
var running_after: bool = false
var _opening: float = 0.0
var _last_gap: float = -1.0
var _trot_speed: float = 3.8
## Host: he rolled under this swing's blow; the aftershocks to come
## ([at, seconds left, id]); counts for a test.
var _saw_roll: bool = false
var _shocks: Array = []
var _shock_look: Vector2 = Vector2(-1, 0)
var aftershocks_made: int = 0
var catches_made: int = 0
## Every peer: the body lifted through a leap.
var _lifted: bool = false
## Every peer: the move shown and its clock, which of its blows have been
## heard, and the feet (down or not) for the footfalls.
var _heard_serial: int = -1
var _heard_clock: float = 0.0
var _heard: int = 0
var _ankles: PackedInt32Array = PackedInt32Array()
var _foot_down: Array[bool] = [true, true]


func _ready() -> void:
	super()
	_special(POUND, pound_clip, pound_part)
	_special(HEAVY, heavy_clip, heavy_part)
	_special_strike(HEAVY, "", heavy_share, 1)
	_kinds[HEAVY] = &"crush"
	_windups[HEAVY] = [heavy_slow, heavy_lead]
	_special(STOMP, stomp_clip, stomp_part)
	for what: int in SWINGS:
		var sw: Array = SWINGS[what]
		_special(what, sw[0], sw[1])
		# A heavy one fells him by itself, a light one never (but as the close
		# of a long string, [method _begin_move]).
		_special_strike(what, "", float(sw[3]), int(sw[6]))
		if bool(sw[2]):
			_holds[what] = [0.3, 0.3, 0.75, 0.22]
	_holds.erase(CATCH)
	_holds[HEAVY] = [0.35, 0.25, 0.6, 0.2]
	# The roll-catch is always held, a roll's length.
	_holds[CATCH] = [1.0, catch_hold.x, catch_hold.y, 0.3]
	_special(LEAP_SLAM, leap_slam_clip, leap_slam_part)
	_special_strike(LEAP_SLAM, "", leap_slam_share, 1)
	_special(RUN_SLAM, run_slam_clip, run_slam_part)
	_special_strike(RUN_SLAM, "", run_slam_share, 1)
	# Down on him club first out of the run: no shield holds it.
	_kinds[RUN_SLAM] = &"crush"
	_trot_speed = chase_speed
	_leap_slam_wait = _rng.randf_range(3.0, leap_slam_cooldown.x)
	_run_slam_wait = _rng.randf_range(3.0, run_slam_cooldown.x)
	# The kick beats a raised shield aside, as the orc's does.
	_kinds[KICK] = &"guard"
	_pound_at = _club_down(POUND)
	_stomp_at = _club_down(STOMP)
	_pound_wait = _rng.randf_range(2.0, pound_cooldown.x)
	_heavy_wait = _rng.randf_range(1.0, heavy_cooldown.x)
	# Fresh to the fight it walks in first; the lunge comes later.
	_lunge_wait = _rng.randf_range(3.5, lunge_cooldown.x)
	if _skeleton != null:
		for bone in foot_bones:
			_ankles.append(_skeleton.find_bone(bone))
	Sfx.warm([WHOOSH_HEAVY, WHOOSH_LIGHT, ROAR_SOUND, ROAR_SHORT_SOUND] + GRUNTS + CLUB_GROUND + STEPS)


## Act seconds of a move when its club is lowest, in front.
func _club_down(what: int) -> float:
	var m: Array = _moves_table[what]
	if _anim == null or _weapon < 0:
		return _move_length(what) * 0.5
	var at := _anim.measure_reach(m[0], String(weapon_bone), weapon_tip, reach_forward, float(m[2]), float(m[3]))
	if at < 0.0:
		return _move_length(what) * 0.5
	return (at - float(m[2])) * _anim.clip_length(m[0]) / maxf(float(m[1]), 0.01)


func _leaps() -> Array:
	return [LEAP, LUNGE, LEAP_SLAM, RUN_SLAM]


#region Choosing
func _own_move(delta: float) -> bool:
	_pound_wait = maxf(_pound_wait - delta, 0.0)
	_heavy_wait = maxf(_heavy_wait - delta, 0.0)
	_stomp_wait = maxf(_stomp_wait - delta, 0.0)
	_lunge_wait = maxf(_lunge_wait - delta, 0.0)
	_kick_wait = maxf(_kick_wait - delta, 0.0)
	_leap_slam_wait = maxf(_leap_slam_wait - delta, 0.0)
	_run_slam_wait = maxf(_run_slam_wait - delta, 0.0)
	var gap := _distance_to(_quarry)
	_watch_flight(gap, delta)
	# Running at him to spring off the run.
	if _charging:
		_charge_time += delta
		if _quarry_down() or _charge_time > 4.5 or gap > run_slam_to + 8.0:
			_charging = false
		elif gap <= run_slam_takeoff:
			_charging = false
			if gap >= run_slam_takeoff * 0.55 and stamina >= attack_cost:
				mode = Mode.FIGHT
				_face(_quarry.global_position - global_position, 1.0, 50.0)
				_open(RUN_SLAM)
				return true
		else:
			mode = Mode.CHASE
			_move_towards(_quarry.global_position, _pace(run_speed), delta)
			return true
	# Him down in reach: the club on him where he lies.
	if _quarry_down():
		if gap <= stomp_reach and _stomp_wait <= 0.0:
			if _rng.randf() > stomp_chance:
				_stomp_wait = stomp_cooldown * 0.5
				return false
			_face(_quarry.global_position - global_position, 1.0, 50.0)
			_open(STOMP)
			return true
		if gap > stomp_reach * 0.8:
			_move_towards(_quarry.global_position, chase_speed, delta)
			return true
		return false
	if _from_afar(gap, delta):
		return true
	if _pound_wait <= 0.0 and gap >= pound_from and gap <= pound_to and stamina >= attack_cost:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_open(POUND)
		return true
	var want := float(_strike_from.get(HEAVY, strike_off))
	if _heavy_wait <= 0.0 and _cooldown <= 0.0 and gap <= want + 0.6 and gap >= want - 1.2 \
			and stamina >= attack_cost:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_open(HEAVY)
		return true
	if attacks.is_empty() or _cooldown > 0.0 or stamina < attack_cost:
		return super(delta)
	if _lunge_wait <= 0.0 and gap >= lunge_from and gap <= lunge_to:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_open(LUNGE)
		return true
	var pick := _pick_opener(gap)
	if pick >= 0:
		mode = Mode.FIGHT
		if SWINGS[pick][5] == &"front":
			_face(_quarry.global_position - global_position, 1.0, 50.0)
		_open(pick)
		return true
	return super(delta)


## Host: the leaps from afar, if he is at their gap and they are due.
func _from_afar(gap: float, delta: float) -> bool:
	if stamina < attack_cost or _quarry_down():
		return false
	var run_ok := _run_slam_wait <= 0.0 and gap >= run_slam_from and gap <= run_slam_to
	var leap_ok := _leap_slam_wait <= 0.0 and gap >= leap_slam_from and gap <= leap_slam_to
	if run_ok and (not leap_ok or _rng.randf() < 0.5):
		# Off at a run at him first; it springs at `run_slam_takeoff`.
		_charging = true
		_charge_time = 0.0
		_run_slam_wait = _rng.randf_range(run_slam_cooldown.x, run_slam_cooldown.y)
		mode = Mode.CHASE
		_move_towards(_quarry.global_position, _pace(run_speed), delta)
		return true
	if leap_ok:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_open(LEAP_SLAM)
		return true
	return false


## A pace, quicker enraged.
func _pace(base: float) -> float:
	return base * (rage_pace if raging else 1.0)


## Host: whether he is running from it — the gap opening fast for a while
## with him well off — and its pace after him by that: a trot, or a run.
func _watch_flight(gap: float, delta: float) -> void:
	if _last_gap >= 0.0 and delta > 0.0:
		var opening := (gap - _last_gap) / delta
		if opening > flee_rate and gap > flee_from:
			_opening += delta
		else:
			_opening = maxf(_opening - delta * 0.5, 0.0)
	_last_gap = gap
	if _opening >= flee_time and gap > flee_from:
		running_after = true
	elif running_after and (gap < flee_from - 1.0 or _opening <= 0.0):
		running_after = false
	chase_speed = _pace(run_speed if running_after else _trot_speed)


## The Brawler's own choosing goes through the strings too.
func _begin_attack() -> void:
	if _quarry_down() or _quarry == null:
		return
	if attacks.is_empty():
		super()
		return
	var pick := _pick_opener(_distance_to(_quarry))
	if pick >= 0:
		_open(pick)
	else:
		super()


## A string begun with `what`.
func _open(what: int) -> void:
	_string_count = 0
	_pounded = false
	# One combo on him for the whole string: its blows count together, so a
	# heavy one after a light one fells him ([Player.receive_blow]).
	_chain_serial = 1000000 + act_serial + 1
	_chain_blow = 0
	_kind_blows.clear()
	_closing = false
	if SWINGS.has(what) and what != KICK and what != LUNGE:
		_last_opener = what
	if what == KICK:
		_kick_wait = kick_cooldown
	_begin_move(what)


## The next move of a string (after `prev`, -1 for its first).
func _begin_move(what: int, prev: int = -1) -> void:
	if prev >= 0 and _strikes_table.has(prev):
		var n := _blow_moments(prev).size()
		_chain_blow += n
		var kind := _blow_kind(prev)
		_kind_blows[kind] = int(_kind_blows.get(kind, 0)) + n
	_string_count += 1
	_pounded = false
	moves_made.append(what)
	if moves_made.size() > 200:
		moves_made = moves_made.slice(-100)
	_saw_roll = false
	_closing = _closes(what)
	if what == CATCH:
		catches_made += 1
	if _closing and _finishes() and _strikes_table.has(what) and int((_strikes_table[what] as Array)[3]) > 1:
		# The close of a long string: its last blow fells him, if every blow
		# of its kind in the string found him (they count as one combo).
		finishers_made += 1
		var keep: Array = _strikes_table[what]
		var close := keep.duplicate()
		close[3] = int(_kind_blows.get(_blow_kind(what), 0)) + _blow_moments(what).size()
		_strikes_table[what] = close
		_begin(what)
		_strikes_table[what] = keep
	else:
		_begin(what)
	if FLIGHTS.has(what) and _quarry != null:
		var span := _flight_span(what)
		_flight_speed = _close_speed_for(what, span.y, span.x)
	if what == LUNGE and _quarry != null:
		var until := _blow_moments(LUNGE)[0]
		var m: Array = _moves_table[LUNGE]
		var own := _hips(m[0], _clip_time(LUNGE, until)).x - _hips(m[0], _clip_time(LUNGE, 0.0)).x
		var short := float(_strike_from.get(LUNGE, strike_off))
		_lunge_speed = maxf(_distance_to(_quarry) - short - own, 0.0) / maxf(until, 0.2)


## Where he stands against the way it faces: "front", "side" or "behind".
func _where_he_is() -> StringName:
	var to := _quarry.global_position - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return &"front"
	var angle := rad_to_deg(_forward().angle_to(to.normalized()))
	if angle > 120.0:
		return &"behind"
	if angle > 55.0:
		return &"side"
	return &"front"


## How far off a swing can be begun: from a little inside where it lands to
## as far as it can step in before its blow.
func _fits(what: int, gap: float, slack: float = 0.0) -> bool:
	var want := float(_strike_from.get(what, strike_off))
	var ms := _blow_moments(what)
	var step := clampf(close_speed * ((ms[0] if not ms.is_empty() else 0.5) - 0.15), 0.3, 2.2)
	return gap >= want - 0.8 - slack and gap <= want + step + slack


func _side_weight(where: StringName, suits: StringName) -> float:
	if where == suits:
		return 3.0 if where != &"front" else 1.0
	if where == &"behind":
		return 0.08
	if where == &"side":
		return 0.35 if suits == &"front" else 0.8
	return 0.5 if suits == &"side" else 0.25


## Its first swing, by how far off he is and where: none if none will do.
func _pick_opener(gap: float) -> int:
	var where := _where_he_is()
	var nearest := 0.4 * maxf(visual_scale, 0.01) + 0.55
	if gap < nearest + 0.35 and _kick_wait <= 0.0 and where != &"behind":
		return KICK
	var options: Array = []
	for what: int in SWINGS:
		var sw: Array = SWINGS[what]
		var base := float(sw[4])
		if base <= 0.0 or not _fits(what, gap):
			continue
		var w := base * _side_weight(where, sw[5])
		if what == _last_opener:
			w *= 0.25
		options.append([what, w])
	return _weighed(options)


func _weighed(options: Array) -> int:
	var total := 0.0
	for o: Array in options:
		total += maxf(float(o[1]), 0.0)
	if total <= 0.0:
		return -1
	var roll := _rng.randf() * total
	for o: Array in options:
		roll -= maxf(float(o[1]), 0.0)
		if roll <= 0.0:
			return int(o[0])
	return int((options[-1] as Array)[0])


## Whether `what`, begun now as the `_string_count`th of its string, is its
## last: at the most a string runs, or by the same odds the string would end
## after it ([method _follow]) — weighed now, as it begins, so its blow knows
## it closes (a long string's close fells him; a lone heavy blow's is
## followed by its aftershock).
func _weighed_ahead(what: int) -> bool:
	return SWINGS.has(what) and what != KICK and what != LUNGE


## Whether the string closing on `what` now is long enough to fell him.
func _finishes() -> bool:
	return _string_count >= (finisher_from.y if raging else finisher_from.x)



func _closes(what: int) -> bool:
	if not _weighed_ahead(what):
		return false
	var most := string_most_raging if raging else string_most
	if _string_count >= most:
		return true
	var weights := _follow(what)
	var total := 0.0
	for k: int in weights:
		total += maxf(float(weights[k]), 0.0)
	return total > 0.0 and _rng.randf() < maxf(float(weights.get(-1, 0.0)), 0.0) / total


## What may come after `what` in a string, weighed: next -> weight (-1 the end).
func _follow(what: int) -> Dictionary:
	var weights := {}
	for f: Array in FOLLOW.get(what, []):
		weights[int(f[0])] = float(weights.get(int(f[0]), 0.0)) + float(f[1])
	if raging:
		for f: Array in FOLLOW_RAGING.get(what, []):
			weights[int(f[0])] = float(weights.get(int(f[0]), 0.0)) + float(f[1])
		# Enraged, it seldom stops.
		weights[-1] = float(weights.get(-1, 0.0)) * 0.35
	return weights


## What the string runs on into after `what`, or -1: weighed, never the same
## swing twice running, only one that lands from where he is now.
func _next_in_string(what: int) -> int:
	if _quarry == null or _quarry_down() or not FOLLOW.has(what):
		return -1
	if _string_count >= (string_most_raging if raging else string_most):
		return -1
	if stamina < attack_cost * 0.5:
		return -1
	var gap := _distance_to(_quarry)
	# He rolled out from under it: the roll-catch, held for the end of the
	# next roll he makes too early.
	if _saw_roll and what != CATCH and _fits(CATCH, gap, 1.5) and _rng.randf() < catch_chance:
		return CATCH
	if _closing:
		return -1
	var weights := _follow(what)
	# A swing's end was weighed as it began ([method _closes]).
	var past := _weighed_ahead(what)
	var options: Array = []
	for next: int in weights:
		var w := float(weights[next])
		if next == -1:
			if not past:
				options.append([-1, w])
			continue
		if next == what:
			continue
		match next:
			POUND:
				if gap > pound_to:
					continue
			HEAVY:
				var want := float(_strike_from.get(HEAVY, strike_off))
				if gap > want + 1.0 or gap < want - 1.6:
					continue
			_:
				if not _fits(next, gap, 1.0):
					continue
		options.append([next, w])
	return _weighed(options)
#endregion


#region Acting
func _extra_velocity(delta: float) -> Vector3:
	if act == LUNGE:
		if _act_time <= _blow_moments(LUNGE)[0]:
			return _forward() * _lunge_speed
		return Vector3.ZERO
	if FLIGHTS.has(act):
		var span := _flight_span(act)
		if _act_time >= span.x and _act_time <= span.y:
			return _forward() * _flight_speed
		return Vector3.ZERO
	return super(delta)


## Act seconds of the move's last moment of turning after him: a little
## before its first blow (`commit_lead`), a leap a third into its flight.
func _commit_at(what: int) -> float:
	if FLIGHTS.has(what):
		var span := _flight_span(what)
		return lerpf(span.x, span.y, 0.3)
	var ms := _blow_moments(what)
	if ms.is_empty():
		return 0.0
	var heavy := _is_heavy(what)
	return ms[0] - (commit_lead.y if heavy else commit_lead.x)


func _track_rate(what: int) -> float:
	if FLIGHTS.has(what) or what == LUNGE:
		return turn_speed * 1.3
	if what == CATCH:
		return turn_speed * 1.2
	return turn_speed * (0.85 if _is_heavy(what) else 0.7)


## Turning after him till the move commits ([method _commit_at]), and then
## locked: the dash and the leaps sized to where he is now, as they turn.
func _track_before_blow(delta: float) -> void:
	if _quarry == null or _act_time >= _commit_at(act):
		return
	_face(_quarry.global_position - global_position, delta, _track_rate(act))
	_reframe()
	if act == LUNGE:
		_lunge_speed = _close_speed_for(LUNGE, _blow_moments(LUNGE)[0], 0.0)
	elif FLIGHTS.has(act):
		var span := _flight_span(act)
		_flight_speed = _close_speed_for(act, span.y, span.x)


## The speed on top of the clip's own travel that brings the move's blow on
## him from where he is now, laid over the act seconds from `from` (or now,
## if later) to `until`.
func _close_speed_for(what: int, until: float, from: float) -> float:
	var ms := _blow_moments(what)
	var blow := ms[0] if not ms.is_empty() else until
	var m: Array = _moves_table[what]
	var own := _hips(m[0], _clip_time(what, blow)).x - _hips(m[0], _clip_time(what, _act_time)).x
	var short := float(_strike_from.get(what, strike_off))
	var left := maxf(until - maxf(from, _act_time), 0.15)
	return maxf(_distance_to(_quarry) - short - own, 0.0) / left


## A leap's flight in act seconds: [leaves the ground, lands], drawn out.
func _flight_span(what: int) -> Vector2:
	var f: Array = FLIGHTS[what]
	var m: Array = _moves_table[what]
	var c0 := _anim.clip_length(m[0]) * float(m[2]) if _anim != null else 0.0
	var a0 := (float(f[0]) - c0) / float(m[1])
	var a1 := (float(f[1]) - c0) / float(m[1])
	return Vector2(a0, a0 + (a1 - a0) * float(f[2]))


## [act s the flight begins, its length at the clip's pace, how much slower].
func _flight_warp(what: int) -> Vector3:
	var f: Array = FLIGHTS[what]
	var m: Array = _moves_table[what]
	var c0 := _anim.clip_length(m[0]) * float(m[2]) if _anim != null else 0.0
	var a0 := (float(f[0]) - c0) / float(m[1])
	return Vector3(a0, (float(f[1]) - float(f[0])) / float(m[1]), float(f[2]))


func _clip_time(what: int, t: float) -> float:
	if FLIGHTS.has(what) and _anim != null:
		var w := _flight_warp(what)
		if t > w.x:
			if t < w.x + w.y * w.z:
				t = w.x + (t - w.x) / w.z
			else:
				t -= w.y * (w.z - 1.0)
	return super(what, t)


func _move_length(what: int) -> float:
	var length := super(what)
	if FLIGHTS.has(what) and _anim != null:
		var w := _flight_warp(what)
		length += w.y * (w.z - 1.0)
	return length


func _blow_moments(what: int) -> PackedFloat32Array:
	var ms := super(what)
	if not FLIGHTS.has(what) or _anim == null:
		return ms
	var w := _flight_warp(what)
	var out := PackedFloat32Array()
	for m in ms:
		if m <= w.x:
			out.append(m)
		elif m <= w.x + w.y:
			out.append(w.x + (m - w.x) * w.z)
		else:
			out.append(m + w.y * (w.z - 1.0))
	return out


func _run_act(delta: float) -> void:
	var was := act
	var serial := act_serial
	var t0 := _act_time - delta
	super(delta)
	if is_dead or not _decides():
		return
	if was == act and serial == act_serial and _strikes_table.has(act):
		_watch_blows(t0)
	if act == POUND and not _pounded and _act_time >= _pound_at:
		_pounded = true
		_quake(_weapon_tip_at() * Vector3(1, 0, 1) + Vector3.UP * global_position.y, pound_radius,
				hit_damage * pound_share)
	elif act == STOMP and not _pounded and _act_time >= _stomp_at:
		_pounded = true
		_stomp_down()


## Host, through a swing: did he roll from under its blow (for the
## roll-catch), and did a lone heavy blow or a slam meet the ground (an
## aftershock to follow).
func _watch_blows(t0: float) -> void:
	var ms := _blow_moments(act)
	if ms.is_empty():
		return
	if _quarry is Player:
		var st := (_quarry as Player).state
		if st == Player.State.DODGING or st == Player.State.DASHING:
			for m in ms:
				if absf(_act_time - m) < 0.3:
					_saw_roll = true
	var last := ms[ms.size() - 1]
	if t0 < last and _act_time >= last and _shakes_after(act):
		_shock_look = Vector2(act_serial, _act_time + 0.35)
	# From its blow on, the first moment the club is down by the ground.
	if int(_shock_look.x) == act_serial and _act_time <= _shock_look.y:
		var tip := _weapon_tip_at()
		if tip.y - global_position.y < 0.9 * visual_scale:
			_shock_look = Vector2(-1, 0)
			var ahead := _forward() * aftershock_ahead * visual_scale / 1.6
			_shocks.append([Vector3(tip.x, global_position.y, tip.z) + ahead, aftershock_after, act_serial * 1000 + 77])


## Whether the ground answers this move's blow a beat later: the slams and
## the great blow always, a heavy swing when it closes its string alone or
## last (combos stay as they were).
func _shakes_after(what: int) -> bool:
	if FLIGHTS.has(what) or what == HEAVY or what == JUMP_SLAM:
		return true
	return SWINGS.has(what) and bool(SWINGS[what][2]) and _closing


func _physics_process(delta: float) -> void:
	super(delta)
	if _shocks.is_empty() or is_dead or not _decides():
		return
	for i in range(_shocks.size() - 1, -1, -1):
		var sh: Array = _shocks[i]
		sh[1] = float(sh[1]) - delta
		if float(sh[1]) > 0.0:
			continue
		_shocks.remove_at(i)
		_aftershock(sh[0], int(sh[2]))


## Host: the second burst of earth: whoever is on the ground near it is
## caught (a stagger; off the ground, or rolling, it misses him).
func _aftershock(at: Vector3, id: int) -> void:
	aftershocks_made += 1
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_aftershock.rpc(at)
	else:
		net_aftershock(at)
	for node in get_tree().get_nodes_in_group(&"player"):
		var who := node as Node3D
		if who == null or not who.has_method(&"receive_blow") or bool(who.get("is_dead")):
			continue
		var rel := who.global_position - at
		if absf(rel.y) > 2.0 or Vector2(rel.x, rel.z).length() > aftershock_radius * visual_scale / 1.6:
			continue
		who.call(&"receive_blow", hit_damage * aftershock_share * _blow_worth(0), self, 0, 2, id, false, &"ground")


## Every peer: the ground bursting up again ahead of where the club fell —
## earth and stones thrown up unevenly, a deep crack of it, the view shaken
## (no ring).
@rpc("authority", "call_local", "reliable")
func net_aftershock(at: Vector3) -> void:
	var into := Blood.world_of(self)
	var fwd := _forward()
	GroundFx.eruption(into, at + Vector3.UP * 0.05, 0.9, false)
	GroundFx.eruption(into, at + fwd * 0.9 + fwd.cross(Vector3.UP) * 0.4 + Vector3.UP * 0.05, 0.55, false)
	ImpactFx.thud(self, at + Vector3.UP * 0.2, true)
	_sound_at(CLUB_GROUND, at, 0.72, 1.0)
	WindBlast.shake(self, 0.1, 0.35, 14.0)


## Host: the club down where he lies: a blow at him if it comes down by him.
func _stomp_down() -> void:
	var at := _weapon_tip_at()
	var world := Blood.world_of(self)
	DustRing.burst(world, Vector3(at.x, global_position.y + 0.05, at.z), 0.6 * visual_scale)
	ImpactFx.thud(self, at, true)
	if _quarry == null or not _quarry.has_method(&"receive_blow"):
		return
	var flat := Vector2(at.x - _quarry.global_position.x, at.z - _quarry.global_position.z).length()
	if flat <= 1.5:
		_quarry.call(&"receive_blow", hit_damage * stomp_share * _blow_worth(STOMP), self, 0, 1,
				act_serial, false, &"stomp")


func _after(what: int) -> void:
	match what:
		POUND:
			_pound_wait = _rng.randf_range(pound_cooldown.x, pound_cooldown.y) * (0.6 if raging else 1.0)
		HEAVY:
			_heavy_wait = _rng.randf_range(heavy_cooldown.x, heavy_cooldown.y) * (0.6 if raging else 1.0)
		STOMP:
			_stomp_wait = stomp_cooldown
		LUNGE:
			_lunge_wait = _rng.randf_range(lunge_cooldown.x, lunge_cooldown.y)
		LEAP_SLAM:
			_leap_slam_wait = _rng.randf_range(leap_slam_cooldown.x, leap_slam_cooldown.y) * (0.7 if raging else 1.0)
	var stringed := SWINGS.has(what) or what == POUND or what == HEAVY or FLIGHTS.has(what)
	var next := -1
	if stringed and not is_dead and _decides():
		next = _next_in_string(what)
	super(what)
	if next >= 0:
		# On into the next, turned a little after him.
		if _quarry != null:
			var to := _quarry.global_position - global_position
			rotation.y = rotate_toward(rotation.y, atan2(-to.x, -to.z), deg_to_rad(string_turn))
		_begin_move(next, what)
		return
	if stringed:
		var r := recover_raging if raging else recover
		_cooldown = _rng.randf_range(r.x, r.y)
	_string_count = 0
	_chain_serial = -1
	_chain_blow = 0
	_closing = false
#endregion


#region Looks and sounds
## Every peer: the swing heard coming, the club meeting the ground, its roar,
## and the weight of its feet.
func _process(delta: float) -> void:
	super(delta)
	if is_dead:
		return
	if act_serial != _heard_serial:
		_heard_serial = act_serial
		_heard_clock = 0.0
		_heard = 0
		_on_new_act()
	else:
		_heard_clock += delta
	_lift_in_flight()
	if _strikes_table.has(act):
		var ms := _blow_moments(act)
		while _heard < ms.size() * 2:
			var i := _heard / 2
			var whoosh := _heard % 2 == 0
			var when := ms[i] - (0.16 if whoosh else 0.0)
			if _heard_clock < when:
				break
			_heard += 1
			if whoosh:
				Sfx.play(self, WHOOSH_HEAVY if _is_heavy(act) else WHOOSH_LIGHT, null, _weapon_tip_at(),
						0.95 if _is_heavy(act) else 1.05, -4.0 if _is_heavy(act) else -9.0)
			elif _is_heavy(act):
				_club_lands()
	elif act == Act.NONE:
		_footfalls()


## Every peer: through a leap's flight the body is carried higher than the
## clip's own jump, an arc over the act clock; back on the ground after.
func _lift_in_flight() -> void:
	if body == null:
		return
	if FLIGHTS.has(act) and not is_dead and _anim != null:
		var span := _flight_span(act)
		var u := clampf((_heard_clock - span.x) / maxf(span.y - span.x, 0.05), 0.0, 1.0)
		body.position.y = _body_rest_y + float((FLIGHTS[act] as Array)[3]) * visual_scale / 1.6 * sin(PI * u)
		_lifted = true
	elif _lifted:
		_lifted = false
		if not is_dead:
			body.position.y = _body_rest_y


## Its walk, its trot, its run, by its pace (every peer sees the pace), each
## played at the rate its feet keep to the ground; anything else (sideways,
## back, standing) as any of the pack.
func _play_locomotion(delta: float) -> void:
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var pace := planar.length()
	if pace < 0.15 or trot_clip.is_empty() or planar.dot(_forward()) < pace * 0.6:
		super(delta)
		return
	var now := _anim.current_clip()
	var clip := walk_clip
	var to_trot := trot_above - (0.25 if now == trot_clip or now == run_clip else 0.0)
	var to_run := run_gait_above - (0.3 if now == run_clip else 0.0)
	if pace > to_run and not run_clip.is_empty():
		clip = run_clip
	elif pace > to_trot:
		clip = trot_clip
	_anim.play(clip, 0.25, gait_rate(clip, pace))


func _is_heavy(what: int) -> bool:
	return what == HEAVY or what == STOMP or (SWINGS.has(what) and bool(SWINGS[what][2]))


func _on_new_act() -> void:
	if act == RAGE:
		Sfx.play(self, ROAR_SOUND, self, Vector3.ZERO, 0.95, 2.0)
	elif act == STANCE:
		Sfx.play_any(self, GRUNTS, self, 0.8, -2.0)
	elif act == POUND or act == HEAVY:
		Sfx.play(self, ROAR_SHORT_SOUND, self, Vector3.ZERO, 1.1, -6.0)
	elif _is_heavy(act) and randf() < 0.45:
		Sfx.play_any(self, GRUNTS, self, 1.0, -7.0)


## A heavy blow come down: if the club is down by the ground, the ground
## takes it — the crack of it, earth and grit thrown up, the view shaken.
func _club_lands() -> void:
	var tip := _weapon_tip_at()
	if tip.y - global_position.y > 0.9 * visual_scale:
		return
	var at := Vector3(tip.x, global_position.y + 0.05, tip.z)
	_sound_at(CLUB_GROUND, at, 1.0, -2.0)
	var into := Blood.world_of(self)
	GroundFx.eruption(into, at, 0.55, false)
	WindBlast.shake(self, 0.07, 0.28, 12.0)


## Walking or running, each foot as it comes down: a deep step and a little
## dust off it, the view nudged when he is near.
func _footfalls() -> void:
	if _skeleton == null or _ankles.size() < 2:
		return
	var pace := Vector2(velocity.x, velocity.z).length()
	for k in 2:
		if _ankles[k] < 0:
			continue
		var foot := _skeleton.global_transform * _skeleton.get_bone_global_pose(_ankles[k]).origin
		var low := foot.y - global_position.y < 0.16 * visual_scale
		if low and not _foot_down[k] and pace > 0.6:
			var into := Blood.world_of(self)
			_sound_at(STEPS, foot, 0.92 if pace > run_gait_above else 1.0,
					-9.0 if pace < 3.0 else (-5.0 if pace < run_gait_above else -2.0))
			SkillFx.particles(into, Vector3(foot.x, global_position.y + 0.08, foot.z), {
				"amount": 5, "life": 0.8, "one_shot": true, "explosiveness": 0.9, "add": false,
				"speed": Vector2(0.3, 0.9), "dir": Vector3.UP, "spread": 80.0, "gravity": Vector3(0, -0.4, 0),
				"damping": 2.0, "size": Vector2(0.18, 0.35), "grow": 0.3, "sphere": 0.15,
				"colors": [Color(0.6, 0.55, 0.47, 0.0), Color(0.58, 0.53, 0.46, 0.3), Color(0.55, 0.5, 0.45, 0.0)],
			})
			if pace > 2.5:
				WindBlast.shake(self, 0.035 if pace > run_gait_above else 0.02, 0.15, 7.0)
		_foot_down[k] = low


func _sound_at(paths: Array, at: Vector3, pitch: float, volume_db: float) -> void:
	Sfx.play(self, String(paths[randi() % paths.size()]), null, at, pitch, volume_db)
#endregion
