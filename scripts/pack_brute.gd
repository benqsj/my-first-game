class_name PackBrute
extends Brawler

## What the big ones of Polysplit's pack have in common (CREATURES_PACK.md;
## the user's picks, 2026-10-07): the orc, the ogre, the troll and the golem
## ([OrcFighter], [OgreFighter], [TrollFighter], [GolemFighter]) each take
## some of it.
##
## * **Rage** (`rage_at`): cut under that share of its health it stops and
##   roars (`rage_clip`), and from then on is quicker on its feet and in its
##   swings (`rage_pace`), hardly a breath between them, and hits harder
##   (`rage_harder`); a red glow on it. Its kin within `rage_call` come.
## * **The leap** (`leap_clip`): from `leap_from` to `leap_to` off, now and
##   then (`leap_cooldown`), it springs at him and comes down on him — a blow
##   that throws him down — sized to the gap. With `leap_quake` it shakes the
##   ground where it lands too ([method _quake]).
## * **The quake** ([method _quake]): a shock along the ground out from a
##   slam ([QuakeRing]); whoever is on the ground when it passes under him is
##   thrown down. A jump clears it, a roll too; no shield takes it.
## * **A slow blow** (`_windups`): a move whose wind-up is drawn out, so he
##   sees it coming, its weapon glowing hotter as it rises.
## * **Kinds of blow** (`_kinds`, [method ClipFighter._blow_kind]): "guard"
##   a kick through the shield, "crush" a blow no shield holds, "ground",
##   "stomp".
## * **Stance** (`stance`; the user's word, 2026-10-08: Elden Ring's, not a
##   hit-stop): blows do not stop it nor push it about (`bite_hold`,
##   `shove_share`, `flinch_share`), but each fills a hidden stance, a heavy
##   blow far more than a light cut; full, it goes down on a knee
##   (`stance_clip`), open, and the first blow on it then is a critical
##   (`stance_crit`). Left alone `stance_rest` s, it is whole again.
## * **A delayed blow** (`_holds`): now and then a swing held at the top of
##   its wind-up a moment before it comes down (Elden Ring's delayed swings).

@export_group("Rage")
## 0: it does not rage.
@export_range(0.0, 1.0) var rage_at: float = 0.0
@export var rage_clip: StringName = &"CR_Transform"
@export var rage_part: Vector3 = Vector3(1.15, 0.0, 0.85)
@export var rage_pace: float = 1.22
@export var rage_harder: float = 1.25
@export var rage_glow: Color = Color(1.0, 0.16, 0.05)
## Its own kind within this far are roused by the roar.
@export var rage_call: float = 0.0

@export_group("Leap")
## Empty: it does not leap.
@export var leap_clip: StringName = &""
## [rate, from, to] of the leap clip, and the share of the clip it lands at.
@export var leap_part: Vector3 = Vector3(1.15, 0.1, 0.62)
@export var leap_land: float = 0.44
@export var leap_from: float = 4.5
@export var leap_to: float = 10.0
@export var leap_cooldown: float = 7.0
## What lands (as `attack_limbs`).
@export var leap_limbs: String = "pelvis_joint>head_joint:0.34"
## Share of `hit_damage`.
@export var leap_share: float = 1.2
## How far short of him it means to come down.
@export var leap_short: float = 0.25
## A quake where it lands, this wide (0: none), worth this share.
@export var leap_quake: float = 0.0
@export var leap_quake_share: float = 0.7

@export_group("Stance")
## What its hidden stance takes before it breaks (0: it has none). A blow
## fills it by its damage (before defence) times the hero's swing weight
## twice over (a light cut 1, a heavy blow 1.5 and more: 2.25+); a shot 0.5,
## a spell 0.75 of its damage.
@export var stance: float = 0.0
## Seconds with nothing landing before its stance is whole again.
@export var stance_rest: float = 10.0
## What a light cut (a swing lighter than a finisher's, `cut_weight` under
## 1.15) or a shot puts into it, as a share of the above (the ogre 0.2: the
## user's word, 2026-10-12 — light cuts broke it far too easily).
@export var stance_light_share: float = 1.0
## How long it stays down on its knee, open.
@export var stance_down: float = 2.6
## How long the stone a quake throws up stays up under him, dangerous (s):
## a roll must cover its rising, not only the blow before it.
@export var quake_linger: float = 0.2
## The first blow on it while it is down: this many times as hard.
@export var stance_crit: float = 3.0
## Or, if above 0, that first blow takes just this share of its whole health
## whatever struck it (the ogre 0.1: the user's word, 2026-10-12 — a riposte
## worth at most a tenth of it).
@export var stance_crit_share: float = 0.0
## Going down on its knee: the clip, [rate, -, the share of it it kneels at].
## It comes back up the same way, slower.
@export var stance_clip: StringName = &"CR_LayDown"
@export var stance_part: Vector3 = Vector3(1.2, 0.0, 0.38)
## The share of a hero's hit-stop that holds it ([HitFeel]: 1 every bite,
## 0 none — a blade does not stop a big one's swing), and of the shove and the
## bend a blow gives it.
@export_range(0.0, 1.0) var bite_hold: float = 1.0
@export_range(0.0, 1.0) var shove_share: float = 1.0
@export_range(0.0, 1.0) var flinch_share: float = 1.0
## Heard as the critical goes in (empty: the thud only).
@export_file("*.wav", "*.ogg") var crit_sound: String = ""

const RAGE := 110
const LEAP := 111
const STANCE := 119

## Replicated by [method net_rage].
var raging: bool = false
## act -> the kind of blow it lands ([method ClipFighter._blow_kind]).
var _kinds: Dictionary = {}
## act -> [how many times slower its wind-up is played, seconds before its
## blow the wind-up ends] ([method _clip_time]).
var _windups: Dictionary = {}
var _leap_wait: float = 2.0
var _leap_speed: float = 0.0
var _glow: StandardMaterial3D
var _glow_light: OmniLight3D
## Host: how many quakes it has made, and those running out ([method _quake]).
var quakes_made: int = 0
var _quakes: Array[Dictionary] = []
var _in_lin: bool = false
## Every peer: the serial and clock of the move it shows, for the looks of a
## slow blow.
var _shown_serial: int = -1
var _shown_clock: float = 0.0
var _charge: OmniLight3D
var _ember: MeshInstance3D
var _ember_mat: StandardMaterial3D
## act -> [chance, shortest, longest, seconds before the blow it holds at]: a
## delayed swing ([method _hold_of]).
var _holds: Dictionary = {}
## act -> the least time from its start to its blow (s): a quick clip's
## wind-up played slower to it, no glow (the orc's, 2026-10-14).
var _slow_to: Dictionary = {}
## act -> how much quicker than its clip a drawn-out wind-up's swing comes
## down, from the top of it to its blow (the user's word, 2026-10-14: heavy
## up, then fast down).
var _snap: Dictionary = {}

@export_group("Combos")
## How often it opens one of its combos made by hand (`_hand_combos`, its
## kind's) instead of a plain attack, he in front: calm, enraged.
@export var hand_combo_chance: Vector2 = Vector2(0.4, 0.55)
## Its combos' moves played this much quicker than their clips (the user's
## word, 2026-10-11: too slow).
@export var hand_pace: float = 1.42
## A combo's move with more to come runs on this long after its last blow
## before the next begins (s).
@export var hand_tail: float = 0.32
## The practice (the test arena's board, 2026-10-10): >= 0, it does nothing
## but this one of its combos, over and over — it comes in to it, opens it, gets
## its breath, and again.
@export var drill_combo: int = -1

## Its combos made by hand (the user's word, 2026-10-10: as the ogre's, for the
## troll, the golem and the orc): [{"name", "moves", "fells", "weight",
## "rage"?}] — always the same moves in the same order, the ones at `fells`
## throwing him down by themselves, the rest staggering; enraged, a `rage`
## tail runs on and its last fells instead; "rage_only" ones only enraged;
## "far" ones its kind opens itself from off. Set by its kind in `_ready`, its
## moves with [method _hand_move]. (The ogre has its own, richer.)
var _hand_combos: Array = []
## A fist's stretch, its radius to fill in (the troll's, the golem's).
const FIST_R := "R_elbow_joint>R_midFinger_joint3:%s"
const FIST_L := "L_elbow_joint>L_midFinger_joint3:%s"
## Host: the combo on (-1 none), its place, its moves as they run, which
## fell, the last it made; counts for the tests.
var _hand_combo: int = -1
var _hand_step: int = 0
var _hand_moves: Array = []
var _hand_fells: Array = []
var _hand_last: int = -1
var hand_combos_made: Array[int] = []
var hand_finishers: int = 0
## Host: the stance it has taken, how long since a blow last landed, and
## whether the critical is still to come in this break.
var stance_taken: float = 0.0
var stance_breaks: int = 0
var crits_taken: int = 0
var _stance_quiet: float = 99.0
var _crit_open: bool = false
var _by_blade: bool = false
## Every peer: the clock of the stance break shown (its clip set by hand).
var _stance_clock: float = 0.0
var _stance_serial: int = -1


@export_group("Pack turns")
## How many of its kind with turns (`pack_turns` > 0) come at one hero at once
## (the user's word, 2026-10-13, Souls' bands): the nearest so many fight;
## the rest keep `turn_wait_gap` off, circling him, facing him, till one of
## them drops back or falls. 0: it never waits its turn.
@export var pack_turns: int = 0
@export var turn_wait_gap: float = 5.5
@export var turn_wait_speed: float = 1.7

## Host: which way it circles while it waits (1 or -1), till it turns about;
## how long it has waited all told (the tests).
var _circle_dir: float = 1.0
var _circle_for: float = 0.0
var turn_waited: float = 0.0

@export_group("Stoop")
## Its swings that pass over a man's head at its size (the user's word
## 2026-10-12: the ogre half again as tall; 2026-10-13 the orc too): bent
## forward from the waist through them, by the least of these degrees that
## brings its weapon onto him (measured at load, [method _fit_stoops]), no
## more than `stoop_most`. 0: never bent.
@export var stoop_most: float = 0.0
@export var stoop_step: float = 4.0
@export var stoop_margin: float = 8.0
## The body each swing is fitted to (the user's word 2026-10-13: playing the
## assassin, the club went over his head and still hurt him): the chest of
## the shortest hero and below, (low, high, m from his middle the weapon must
## come), so it is seen to go into him, not over him; a swing that cannot be
## bent so far is fitted to the sweep's own body as before.
@export var stoop_body: Vector3 = Vector3(0.0, 1.2, 0.22)

## Its bend over swings that would go over his head (`stoop_most`).
var _stoop: LeanModifier
## what -> degrees it bends through that swing.
var _stoops: Dictionary = {}
## While measuring a swing's reach: the bend to measure it with.
var _measure_bend: float = 0.0
## Every peer: the serial and clock of the move it bends through.
var _stoop_serial: int = -1
var _stoop_clock: float = 0.0


func _ready() -> void:
	super()
	if not rage_clip.is_empty():
		_moves_table[RAGE] = [rage_clip, rage_part.x, rage_part.y, rage_part.z]
	if not leap_clip.is_empty():
		_moves_table[LEAP] = [leap_clip, leap_part.x, leap_part.y, leap_part.z]
		_own_limb(LEAP, leap_limbs)
		var s: Array = _strikes_table[LEAP]
		# One blow that throws him down, at the landing.
		_strikes_table[LEAP] = [s[0], s[1], leap_share, 1, 0.6, PackedFloat32Array([leap_land])]
	_leap_wait = _rng.randf_range(1.0, leap_cooldown * 0.5)
	if stance > 0.0:
		_moves_table[STANCE] = [stance_clip, stance_part.x, 0.0, stance_part.z]
	if stoop_most > 0.0 and _skeleton != null:
		_stoop = LeanModifier.new()
		_stoop.bend = 1.0
		_skeleton.add_child(_stoop)


## A move of its own beyond its attacks: [clip, rate, from, to].
func _special(what: int, clip: StringName, part: Vector3) -> void:
	_moves_table[what] = [clip, part.x, part.y, part.z]


## A move of its own that lands blows: its striking ends (as `attack_limbs`),
## its worth (share of `hit_damage`) and how many of its blows fell him.
func _special_strike(what: int, limbs: String, share: float, fells: int = 1) -> void:
	if limbs.is_empty():
		var bones := strike_bones if not strike_bones.is_empty() else PackedStringArray([String(weapon_bone)])
		_strikes_table[what] = [bones, ["weapon"], share, fells]
	else:
		_own_limb(what, limbs)
		var s: Array = _strikes_table[what]
		_strikes_table[what] = [s[0], s[1], share, fells]
	if strike_at_reach:
		_moment_at_reach(what)


func _leaps() -> Array:
	return [LEAP]


#region Thinking
## Host. Before anything else: the rage, if it is due. Then a leap, if he is
## at the right gap.
func _think(delta: float) -> void:
	_leap_wait = maxf(_leap_wait - delta, 0.0)
	if is_dead or act != Act.NONE or mode == Mode.GUARD or mode == Mode.RETURN:
		super(delta)
		return
	if rage_at > 0.0 and not raging and _moves_table.has(RAGE) and health <= max_health * rage_at:
		velocity.x = 0.0
		velocity.z = 0.0
		_begin(RAGE)
		return
	_quarry = _pick_quarry()
	if _quarry == null:
		super(delta)
		return
	if _await_turn(delta):
		return
	if _own_move(delta):
		return
	super(delta)


## A kind's own choice of move, before the Brawler's (true if it took one).
func _own_move(delta: float) -> bool:
	if drill_combo >= 0 and not _hand_combos.is_empty():
		return _drill(delta)
	if _try_hand_combo(_distance_to(_quarry)):
		return true
	return _try_leap()


## Host, practising one combo: waits out its breath (and him down) facing him,
## then comes in to it and opens it.
func _drill(delta: float) -> bool:
	mode = Mode.FIGHT
	var to := _quarry.global_position - global_position
	to.y = 0.0
	if _quarry_down() or _cooldown > 0.0 or stamina < attack_cost:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		if to.length_squared() > 0.0001:
			_face(to, delta, turn_speed)
		return true
	if _try_hand_combo(_distance_to(_quarry)):
		return true
	_move_towards(_quarry.global_position, chase_speed, delta)
	return true

#region Combos made by hand
## A move of its combos: `clip` played over `part` [rate, from, to], striking
## with `limbs` (as `attack_limbs`; "" its weapon), worth `share` of
## `hit_damage`; its blows where they reach furthest, or at `moments`
## (shares of the clip) for a move of several.
func _hand_move(what: int, clip: StringName, part: Vector3, share: float, limbs: String = "",
		moments: Array = []) -> void:
	_special(what, clip, Vector3(part.x * hand_pace, part.y, part.z))
	_special_strike(what, limbs, share, 99)
	if not moments.is_empty():
		var s: Array = _strikes_table[what]
		var ls: Array = []
		for i in moments.size():
			ls.append((s[1] as Array)[0])
		_strikes_table[what] = [s[0], ls, share, 99, 0.5, PackedFloat32Array(moments)]
		if _anim != null:
			var from := _gap_that_lands(what, _moves_table[what], float(moments[0]))
			if from > 0.0:
				_strike_from[what] = from


## Host: now and then one of its combos, he in front and its first move in
## reach, off its cooldown.
func _try_hand_combo(gap: float) -> bool:
	if _hand_combos.is_empty() or _quarry == null or _quarry_down() or stamina < attack_cost \
			or _cooldown > 0.0:
		return false
	var drill := drill_combo >= 0 and drill_combo < _hand_combos.size()
	if not drill and _rng.randf() >= (hand_combo_chance.y if raging else hand_combo_chance.x):
		return false
	var to := _quarry.global_position - global_position
	to.y = 0.0
	if to.length_squared() > 0.0001 and rad_to_deg(_forward().angle_to(to.normalized())) > 60.0:
		return false
	var options: Array = []
	var total := 0.0
	for i in _hand_combos.size():
		if drill and i != drill_combo:
			continue
		var c: Dictionary = _hand_combos[i]
		# one only enraged; one opened from off (its kind's own, [method _own_move])
		if (bool(c.get("rage_only", false)) and not raging and not drill) or bool(c.get("far", false)):
			continue
		var first := int((c["moves"] as Array)[0])
		var want := float(_strike_from.get(first, strike_off))
		if (gap < want - 0.9 and not drill) or gap > want + 1.4:
			continue
		var w := float(c["weight"]) * (0.2 if i == _hand_last else 1.0)
		options.append([i, w])
		total += w
	if options.is_empty() or total <= 0.0:
		return false
	var roll := _rng.randf() * total
	var pick := int((options[-1] as Array)[0])
	for o: Array in options:
		roll -= float(o[1])
		if roll <= 0.0:
			pick = int(o[0])
			break
	start_hand_combo(pick)
	return true


## Host: combo `which` of `_hand_combos` begun now, turned to him.
func start_hand_combo(which: int) -> void:
	var c: Dictionary = _hand_combos[which]
	_hand_combo = which
	_hand_step = 0
	_hand_last = which
	hand_combos_made.append(which)
	_hand_moves = (c["moves"] as Array).duplicate()
	_hand_fells = (c["fells"] as Array).duplicate()
	if raging and c.has("rage"):
		_hand_moves.append_array(c["rage"])
		_hand_fells = [_hand_moves.size() - 1]
	mode = Mode.FIGHT
	if _quarry != null:
		_face(_quarry.global_position - global_position, 1.0, 50.0)
	# one combo on him: its blows count together
	_chain_serial = 3000000 + act_serial + 1
	_chain_blow = 0
	_hand_begin(int(_hand_moves[0]))


## Its move at `_hand_step`: a felling one is a fresh combo to him, its blows
## his last, so it fells by itself.
func _hand_begin(what: int) -> void:
	if _hand_fells.has(_hand_step) and _strikes_table.has(what):
		hand_finishers += 1
		_chain_serial = 4000000 + act_serial + 1
		_chain_blow = 0
		var keep: Array = _strikes_table[what]
		var close := keep.duplicate()
		close[3] = _blow_moments(what).size()
		_strikes_table[what] = close
		_begin(what)
		_strikes_table[what] = keep
	else:
		_begin(what)


## Host, a move ended: the combo's next, if it runs on (-1 if not).
func _hand_next(what: int) -> int:
	if _hand_combo < 0 or is_dead or not _decides():
		return -1
	if _hand_step >= _hand_moves.size() or what != int(_hand_moves[_hand_step]):
		return -1
	if _hand_step + 1 >= _hand_moves.size() or _quarry == null or _quarry_down() \
			or stamina < attack_cost * 0.25:
		return -1
	_hand_step += 1
	return int(_hand_moves[_hand_step])
#endregion


func _try_leap() -> bool:
	if not _moves_table.has(LEAP) or _leap_wait > 0.0 or _quarry_down() or stamina < attack_cost:
		return false
	var gap := _distance_to(_quarry)
	if gap < leap_from or gap > leap_to:
		return false
	mode = Mode.FIGHT
	_face(_quarry.global_position - global_position, 1.0, 50.0)
	_begin(LEAP)
	var until := _blow_moments(LEAP)[0]
	_leap_speed = maxf(gap - leap_short - 0.4 * visual_scale, 0.0) / maxf(until, 0.2)
	return true


func _extra_velocity(delta: float) -> Vector3:
	if act == LEAP:
		if _act_time <= _blow_moments(LEAP)[0]:
			return _forward() * _leap_speed
		return Vector3.ZERO
	if act == RAGE:
		return Vector3.ZERO
	return super(delta)


func _after(what: int) -> void:
	if what == STANCE:
		_crit_open = false
		stance_taken = 0.0
		_stance_quiet = 99.0
	if what == LEAP:
		_leap_wait = leap_cooldown * (0.6 if raging else 1.0)
	if what == RAGE and not raging:
		_send_rage()
	var next := _hand_next(what)
	if next < 0 and _hand_combo >= 0:
		_hand_combo = -1
	super(what)
	if next >= 0:
		# on into the next, turned a little after him
		_chain_blow += _blow_moments(what).size()
		if _quarry != null:
			var to := _quarry.global_position - global_position
			rotation.y = rotate_toward(rotation.y, atan2(-to.x, -to.z), deg_to_rad(55.0))
		_hand_begin(next)


func _run_act(delta: float) -> void:
	var was := act
	var t0 := _act_time - delta
	super(delta)
	if is_dead or not _decides():
		return
	# Down on him out of the leap: the ground shakes where it lands.
	if was == LEAP and act == LEAP and leap_quake > 0.0:
		var land := _blow_moments(LEAP)[0]
		if t0 < land and _act_time >= land:
			_quake(global_position + _forward() * 0.6 * visual_scale, leap_quake, hit_damage * leap_quake_share)
#endregion


#region Blows
func _blow_kind(what: int) -> StringName:
	return _kinds.get(what, &"")


func _blow_worth(_what: int) -> float:
	return rage_harder if raging else 1.0
#endregion


#region The quake
## Host: a shock out along the ground from `at`, `radius` wide, worth `worth`
## to whoever is on the ground as it passes under him.
func _quake(at: Vector3, radius: float, worth: float, ring: bool = true, pace: float = -1.0) -> void:
	quakes_made += 1
	_quakes.append({"at": at, "t": 0.0, "r": radius, "worth": worth * _blow_worth(0),
			"id": act_serial * 1000 + 90 + _quakes.size(), "caught": {},
			"pace": pace if pace > 0.0 else QuakeRing.SPEED})
	if not ring:
		return
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_quake.rpc(at, radius)
	else:
		net_quake(at, radius)


@rpc("authority", "call_local", "reliable")
func net_quake(at: Vector3, radius: float) -> void:
	QuakeRing.spawn(Blood.world_of(self), at, radius)


func _physics_process(delta: float) -> void:
	super(delta)
	if stance > 0.0 and _decides():
		_stance_quiet += delta
		if _stance_quiet > stance_rest:
			stance_taken = 0.0
	if _quakes.is_empty() or not _decides():
		return
	for i in range(_quakes.size() - 1, -1, -1):
		var q := _quakes[i]
		q.t = float(q.t) + delta
		var front := float(q.t) * float(q.get("pace", QuakeRing.SPEED))
		var caught: Dictionary = q.caught
		for node in get_tree().get_nodes_in_group(&"player"):
			var who := node as Node3D
			if who == null or caught.has(who) or not who.has_method(&"receive_blow") or bool(who.get("is_dead")):
				continue
			var rel := who.global_position - (q.at as Vector3)
			if absf(rel.y) > 2.5:
				continue
			var d := Vector2(rel.x, rel.z).length()
			if d > float(q.r) + 0.4 or d > front:
				continue
			# The stone stays up under him a while (`quake_linger`): a roll
			# that was for the blow itself, over by then, does not clear it
			# (the user's word, 2026-10-12: dodging the club, the stone never
			# found him); one timed for the stone does, or a jump over it.
			var since := float(q.t) - d / maxf(float(q.get("pace", QuakeRing.SPEED)), 0.1)
			if since > quake_linger:
				continue
			if who.has_method(&"untouchable_now") and bool(who.call(&"untouchable_now", self)):
				continue
			if who is CharacterBody3D and not (who as CharacterBody3D).is_on_floor():
				continue
			caught[who] = true
			# The ground jumping under him puts him down — if he is on it.
			who.call(&"receive_blow", float(q.worth) * lerpf(1.0, 0.6, d / maxf(float(q.r), 0.1)), self, 0, 1,
					int(q.id), false, &"ground")
		if front > float(q.r) + 1.0 + quake_linger * float(q.get("pace", QuakeRing.SPEED)):
			_quakes.remove_at(i)
#endregion


#region A slow blow, a delayed one
## Act seconds of the move at its own pace up to `lead` s before its first
## blow (where a slow wind-up ends, or a delayed swing is held).
func _windup_end(what: int, lead: float = -1.0) -> float:
	if _in_lin:
		return 0.0
	_in_lin = true
	var ms := super._blow_moments(what)
	_in_lin = false
	if lead < 0.0:
		lead = float((_windups[what] as Array)[1]) if _windups.has(what) else 0.15
	return maxf(ms[0] - lead, 0.0) if not ms.is_empty() else 0.0


## Through a swing held at the top its clip creeps on at this share of its
## pace (the user's word, 2026-10-10: dead still there read as a freeze).
const HOLD_CREEP := 0.07


## How long this swing is held at the top of its wind-up (0: not this time).
## Picked from the swing's serial, so every peer holds it alike.
func _hold_of(what: int) -> float:
	if what != act or not _holds.has(what):
		return 0.0
	var h: Array = _holds[what]
	var r := fposmod(sin(float(act_serial) * 12.9898 + float(what) * 78.233) * 43758.5453, 1.0)
	if r >= float(h[0]):
		return 0.0
	return lerpf(float(h[1]), float(h[2]), fposmod(r * 9.137, 1.0))


## [where the wind-up ends at its own pace, how much slower it is played up to
## there, how long it is held there] for a move, or [] if it is played plain.
func _shape(what: int) -> Array:
	if _in_lin:
		return []
	var slow := float((_windups[what] as Array)[0]) if _windups.has(what) else 1.0
	var hold := _hold_of(what)
	var lead := float((_holds[what] as Array)[3]) if hold > 0.0 else -1.0
	if slow == 1.0 and _slow_to.has(what):
		# drawn out to at least so long before its blow, so he sees it come
		if lead < 0.0:
			lead = 0.1
		var k := _windup_end(what, lead)
		var least := float(_slow_to[what])
		if k > 0.02 and k + lead < least:
			slow = minf((least - lead) / k, 4.0)
	if slow == 1.0 and hold <= 0.0:
		return []
	var k := _windup_end(what, lead)
	if _snap.has(what) and slow > 1.0:
		_in_lin = true
		var base := super._blow_moments(what)
		_in_lin = false
		if not base.is_empty() and base[0] > k:
			return [k, slow, hold, base[0], maxf(float(_snap[what]), 1.0)]
	return [k, slow, hold]


func _clip_time(what: int, t: float) -> float:
	if what == STANCE and _moves_table.has(STANCE):
		return _stance_clip_time(t)
	var sh := _shape(what)
	if not sh.is_empty():
		var k := float(sh[0])
		var slow := float(sh[1])
		var hold := float(sh[2])
		# held, but not dead still: the wind-up stops a little short of the
		# top and creeps on up to it through the hold (its blow, and all
		# after it, where they were)
		var creep := minf(hold * HOLD_CREEP, k * 0.5)
		if t < k * slow:
			t = t / slow * (k - creep) / maxf(k, 0.0001)
		elif t < k * slow + hold:
			t = k - creep + creep * (t - k * slow) / maxf(hold, 0.0001)
		elif sh.size() > 4:
			# down from the top quicker, to its blow; its own pace after
			var b := float(sh[3])
			var snap := float(sh[4])
			var t2 := t - k * slow - hold
			t = k + t2 * snap if t2 < (b - k) / snap else b + t2 - (b - k) / snap
		else:
			t = t - k * (slow - 1.0) - hold
	return super(what, t)


func _move_length(what: int) -> float:
	if what == STANCE and _moves_table.has(STANCE):
		return _stance_spans().x + _stance_spans().y + _stance_spans().z
	var length := super(what)
	var sh := _shape(what)
	if not sh.is_empty():
		length += float(sh[0]) * (float(sh[1]) - 1.0) + float(sh[2])
		if sh.size() > 4:
			length -= (float(sh[3]) - float(sh[0])) * (1.0 - 1.0 / float(sh[4]))
	# a hand-made combo's move with more to come: on soon after its last blow
	if what == act and _hand_combo >= 0 and _hand_step < _hand_moves.size() - 1 \
			and _strikes_table.has(what):
		var ms := _blow_moments(what)
		if not ms.is_empty():
			length = minf(length, ms[ms.size() - 1] + hand_tail)
	return length


func _blow_moments(what: int) -> PackedFloat32Array:
	var ms := super(what)
	var sh := _shape(what)
	if sh.is_empty():
		return ms
	var k := float(sh[0])
	var slow := float(sh[1])
	var hold := float(sh[2])
	var out := PackedFloat32Array()
	var b := float(sh[3]) if sh.size() > 4 else INF
	var snap := float(sh[4]) if sh.size() > 4 else 1.0
	for m in ms:
		if m <= k:
			out.append(m * slow)
		elif m <= b:
			out.append(k * slow + hold + (m - k) / snap)
		else:
			out.append(k * slow + hold + (b - k) / snap + (m - b))
	return out


## Every peer: the weapon glowing hotter through a slow blow's wind-up.
func _show_windup(delta: float) -> void:
	if act_serial != _shown_serial:
		_shown_serial = act_serial
		_shown_clock = 0.0
	else:
		_shown_clock += delta
	var winding := _windups.has(act) and not is_dead
	if not winding:
		if _charge != null:
			_charge.light_energy = move_toward(_charge.light_energy, 0.0, 12.0 * delta)
			_ember.visible = false
		return
	var w: Array = _windups[act]
	var until := _windup_end(act) * float(w[0])
	var share := clampf(_shown_clock / maxf(until, 0.05), 0.0, 1.0)
	var tip := _weapon_tip_at()
	if _charge == null:
		_charge = OmniLight3D.new()
		_charge.light_color = Color(1.0, 0.45, 0.12)
		_charge.omni_range = 2.6 * visual_scale
		_charge.shadow_enabled = false
		_charge.top_level = true
		add_child(_charge)
	_charge.global_position = tip
	_charge.light_energy = 0.4 + 3.2 * share * share if share < 1.0 else move_toward(_charge.light_energy, 0.0, 10.0 * delta)
	# A coal at the weapon's end, swelling and brightening as it rises.
	if _ember == null:
		_ember = MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 1.0
		ball.height = 2.0
		ball.radial_segments = 12
		ball.rings = 6
		_ember.mesh = ball
		_ember_mat = SkillFx.glow(Color(1.0, 0.5, 0.15), 3.0)
		_ember.material_override = _ember_mat
		_ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ember.top_level = true
		add_child(_ember)
	_ember.visible = share < 1.0
	_ember.global_position = tip
	var flick := 0.85 + 0.15 * sin(Time.get_ticks_msec() / 1000.0 * 30.0)
	_ember.scale = Vector3.ONE * (0.08 + 0.22 * share) * visual_scale * flick
	_ember_mat.albedo_color.a = 0.35 + 0.6 * share
	if share < 1.0 and randf() < delta * 22.0 * (0.3 + share):
		SkillFx.burst(Blood.world_of(self), tip, Color(1.0, 0.55, 0.15), 3, Vector2(0.5, 1.5), Vector3.UP, 70.0,
				Vector2(0.02, 0.04), Vector3(0, 1.5, 0), 0.4)


## Where its weapon's end is now, for a hero asking whether its blow passes
## under his jump ([method Player._low_blow]).
func weapon_tip_now() -> Vector3:
	return _weapon_tip_at()


## Where its weapon's end is now (its right fist where it has none).
func _weapon_tip_at() -> Vector3:
	if _skeleton != null and _weapon >= 0:
		return _skeleton.global_transform * (_skeleton.get_bone_global_pose(_weapon) * weapon_tip)
	return global_position + Vector3.UP * 1.5 * visual_scale


func _process(delta: float) -> void:
	super(delta)
	_show_stance(delta)
	_stoop_into(delta)
	if not _windups.is_empty():
		_show_windup(delta)
	if _glow != null:
		var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
		_glow.albedo_color.a = 0.0 if is_dead else 0.1 + 0.12 * beat
		if _glow_light != null:
			_glow_light.light_energy = 0.0 if is_dead else 0.5 + 0.6 * beat
#endregion


#region Rage
func _send_rage() -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_rage.rpc()
	else:
		net_rage()
	if rage_call > 0.0 and _quarry != null:
		for node in get_tree().get_nodes_in_group(&"enemy"):
			var f := node as Fighter
			if f == null or f == self or f.is_dead or f.scene_file_path != scene_file_path:
				continue
			if f.global_position.distance_to(global_position) <= rage_call:
				f._rouse(_quarry)


## Every peer: enraged from now on.
@rpc("authority", "call_local", "reliable")
func net_rage() -> void:
	if raging:
		return
	raging = true
	speed *= rage_pace
	chase_speed *= rage_pace
	close_speed *= rage_pace
	attack_cooldown *= 0.4
	stamina_regen *= 1.6
	for what: int in _moves_table:
		if what != RAGE and what != ROAR and what != PIECES and what != REFORM:
			var m: Array = (_moves_table[what] as Array).duplicate()
			m[1] = float(m[1]) * rage_pace
			_moves_table[what] = m
	_glow_on()


## Host: home and whole again — calm again too, so the next fight begins at
## its beginning (the user's word, 2026-10-12: a retry must be the whole fight).
func _made_whole() -> void:
	stance_taken = 0.0
	if not raging:
		return
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_calm.rpc()
	else:
		net_calm()


## Every peer: its rage undone ([method net_rage] backwards).
@rpc("authority", "call_local", "reliable")
func net_calm() -> void:
	if not raging:
		return
	raging = false
	speed /= rage_pace
	chase_speed /= rage_pace
	close_speed /= rage_pace
	attack_cooldown /= 0.4
	stamina_regen /= 1.6
	for what: int in _moves_table:
		if what != RAGE and what != ROAR and what != PIECES and what != REFORM:
			var m: Array = (_moves_table[what] as Array).duplicate()
			m[1] = float(m[1]) / rage_pace
			_moves_table[what] = m
	_glow_off()


func _glow_off() -> void:
	if body != null:
		for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			if mi.material_overlay == _glow:
				mi.material_overlay = null
	if _glow_light != null:
		_glow_light.queue_free()
		_glow_light = null
	_glow = null


func _glow_on() -> void:
	if body == null:
		return
	_glow = StandardMaterial3D.new()
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.albedo_color = Color(rage_glow, 0.2)
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = _glow
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = rage_glow
	_glow_light.light_energy = 0.9
	_glow_light.omni_range = 2.4 * visual_scale
	_glow_light.shadow_enabled = false
	add_child(_glow_light)
	_glow_light.position = Vector3.UP * 1.3 * visual_scale
	# No rings at its feet (the user's word, 2026-10-08): red embers and hot
	# breath going up off it, and the roar shakes the view.
	var into := Blood.world_of(self)
	SkillFx.particles(into, global_position + Vector3.UP * 1.1 * visual_scale, {
		"amount": 46, "life": 1.3, "one_shot": true, "explosiveness": 0.85,
		"speed": Vector2(0.6, 2.2), "dir": Vector3.UP, "spread": 55.0, "gravity": Vector3(0, 1.2, 0),
		"damping": 1.2, "size": Vector2(0.03, 0.07), "box": Vector3(0.45, 0.8, 0.45) * visual_scale,
		"colors": [Color(1.0, 0.8, 0.5, 1.0), rage_glow, Color(rage_glow.r, rage_glow.g, rage_glow.b, 0.0)],
	})
	SkillFx.particles(into, global_position + Vector3.UP * 1.75 * visual_scale, {
		"amount": 14, "life": 1.6, "one_shot": true, "explosiveness": 0.7, "add": false,
		"speed": Vector2(0.4, 1.1), "dir": Vector3.UP, "spread": 35.0, "gravity": Vector3(0, 0.6, 0),
		"damping": 0.8, "size": Vector2(0.35, 0.7), "sphere": 0.25 * visual_scale, "grow": 0.3,
		"colors": [Color(0.55, 0.5, 0.48, 0.0), Color(0.5, 0.45, 0.42, 0.28), Color(0.45, 0.42, 0.4, 0.0)],
	})
	for node in get_tree().get_nodes_in_group(&"player"):
		var hero := node as Player
		if hero != null and hero.is_multiplayer_authority() and hero.global_position.distance_to(global_position) < 14.0:
			var cam := hero.get_viewport().get_camera_3d()
			if cam != null:
				ImpactFx.knock(cam, Vector3.DOWN, 0.06, 0.12, 0.6)


## Enraged, a blow no longer throws it about; one with a stance is not thrown
## about at all, the knock goes to its stance.
func react(kind: StringName, from: Node3D = null, push: Vector3 = Vector3.ZERO) -> void:
	if stance > 0.0 and kind == &"knock" and act != STANCE:
		if is_dead or not _decides():
			return
		if from != null and is_instance_valid(from):
			_rouse(from)
		_add_stance(stance * 0.3)
		return
	if raging and kind == &"knock":
		if from != null and is_instance_valid(from) and _decides():
			_rouse(from)
		return
	super(kind, from, push)
#endregion


#region Stance
## [going down, down, getting up] in act seconds.
func _stance_spans() -> Vector3:
	var len_down := 0.6
	if _anim != null:
		len_down = _anim.clip_length(stance_clip) * stance_part.z / maxf(stance_part.x, 0.01)
	return Vector3(len_down, stance_down, len_down * 1.4)


## The clip's own time through the break: down to the knee, held there (a
## breath of sway), and back up the same way, slower.
func _stance_clip_time(t: float) -> float:
	var sp := _stance_spans()
	var knee := _anim.clip_length(stance_clip) * stance_part.z if _anim != null else 0.0
	if t < sp.x:
		return t * stance_part.x
	if t < sp.x + sp.y:
		return knee - 0.06 * (0.5 + 0.5 * sin((t - sp.x) * 2.6))
	return maxf(knee - (t - sp.x - sp.y) * stance_part.x / 1.4, 0.0)


func receive_hit(hit: HitInfo) -> bool:
	_by_blade = hit.by_blade
	var bled := super(hit)
	_by_blade = false
	return bled


## How much of a blow's damage goes to its stance: a hero's swing by its
## weight (twice: the damage has it once already), a shot or a spell less.
func _stance_weight(from: Node3D, magic: bool) -> float:
	if not _by_blade or from == null:
		return 0.75 if magic else 0.5 * stance_light_share
	var w := 1.0
	var rig: Variant = from.get(&"rig")
	if rig is Object:
		var cw: Variant = (rig as Object).get(&"cut_weight")
		if cw is float:
			w = float(cw)
	return w * w * (stance_light_share if w < 1.15 else 1.0)


func _receive(damage: float, at: Vector3, blow: Vector3, from: Node3D, magic: bool = false) -> bool:
	var crit := false
	if act == STANCE and _crit_open and from != null and from.is_in_group(&"player"):
		damage *= stance_crit
		if stance_crit_share > 0.0:
			# laid on before its defence, so what it loses is the share itself
			damage = max_health * stance_crit_share * (Defence.SCALE + maxf(m_def if magic else p_def, 0.0)) / Defence.SCALE
		crit = true
	var was := velocity
	var bled := super(damage, at, blow, from, magic)
	if not bled or is_dead or act == PIECES:
		return bled
	if shove_share < 1.0:
		velocity.x = lerpf(was.x, velocity.x, shove_share)
		velocity.z = lerpf(was.z, velocity.z, shove_share)
	if crit:
		_crit_open = false
		crits_taken += 1
		_send_crit(at)
		# Struck down where it knelt: it gets up from there now.
		var sp := _stance_spans()
		_act_time = maxf(_act_time, sp.x + sp.y - 0.35)
	elif stance > 0.0 and act != STANCE:
		_add_stance(damage * _stance_weight(from, magic))
	return bled


## Down on its knee and open to a hero's critical (every peer: its own flag
## on the host, the kneel itself elsewhere).
func crit_open() -> bool:
	return not is_dead and act == STANCE and (_crit_open or not _decides())


## Where a hero stands to deal it the critical: in front of it, this far
## (m), and the height the blade goes in at.
func crit_spot() -> Vector3:
	return global_position + _forward() * 1.25 * visual_scale / 1.6


## Host: stance taken; full, it breaks.
func _add_stance(amount: float) -> void:
	if stance <= 0.0 or is_dead or act == STANCE or act == PIECES or act == REFORM:
		return
	_stance_quiet = 0.0
	stance_taken += amount
	if stance_taken >= stance:
		_break_stance()


func _break_stance() -> void:
	stance_taken = 0.0
	stance_breaks += 1
	_crit_open = true
	_sweeps.clear()
	velocity.x = 0.0
	velocity.z = 0.0
	_begin(STANCE)
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_stance_broken.rpc()
	else:
		net_stance_broken()


## A parry counts towards its stance too.
func parried(by: Node3D) -> void:
	_add_stance(stance * 0.35)
	if act != STANCE:
		super(by)


## Every peer: it buckles — a heavy grunt of the ground taking its knee, dust
## kicked up off it (no ring), the view knocked for him close by.
@rpc("authority", "call_local", "reliable")
func net_stance_broken() -> void:
	var into := Blood.world_of(self)
	var knee := global_position + _forward() * 0.5 * visual_scale
	ImpactFx.thud(self, knee + Vector3.UP * 0.3, true)
	SkillFx.particles(into, knee + Vector3.UP * 0.15, {
		"amount": 22, "life": 0.9, "one_shot": true, "explosiveness": 0.9, "add": false,
		"speed": Vector2(0.8, 2.4), "dir": Vector3.UP, "spread": 70.0, "gravity": Vector3(0, -1.5, 0),
		"damping": 2.5, "size": Vector2(0.25, 0.55), "sphere": 0.4 * visual_scale, "grow": 0.25,
		"colors": [Color(0.62, 0.55, 0.45, 0.0), Color(0.6, 0.53, 0.44, 0.5), Color(0.58, 0.52, 0.44, 0.0)],
	})
	# Lit for a beat, white-gold: open now.
	HitFeel.flash(self, 0.5)
	WindBlast.shake(self, 0.08, 0.3, 14.0)


func _send_crit(at: Vector3) -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_crit.rpc(at)
	else:
		net_crit(at)


## Every peer: the critical on it down — a deep blow, blood and a burst of
## light where it went in, the view knocked hard.
@rpc("authority", "call_local", "reliable")
func net_crit(at: Vector3) -> void:
	var into := Blood.world_of(self)
	ImpactFx.thud(self, at, true)
	ImpactFx.strike(self, at, &"flesh", 2.2)
	if not crit_sound.is_empty():
		Sfx.play(self, crit_sound, null, at, 1.0, 1.0)
	SkillFx.burst(into, at, Color(1.0, 0.85, 0.55), 26, Vector2(2.0, 6.5), Vector3.UP, 120.0,
			Vector2(0.03, 0.07), Vector3(0, -7, 0), 0.45)
	HitFeel.flash(self, 0.8)
	for node in get_tree().get_nodes_in_group(&"player"):
		var hero := node as Player
		if hero != null and hero.is_multiplayer_authority() and hero.global_position.distance_to(global_position) < 10.0:
			var cam := hero.get_viewport().get_camera_3d()
			if cam != null:
				ImpactFx.knock(cam, (global_position - hero.global_position).normalized(), 0.09, 0.1, 0.4)


## Every peer: the break's clip kept where its clock is (down, held, back up:
## not a clip played straight through).
func _show_stance(delta: float) -> void:
	if act != STANCE or _anim == null or not _moves_table.has(STANCE):
		_stance_serial = -1
		return
	if act_serial != _stance_serial:
		_stance_serial = act_serial
		_stance_clock = 0.0
	else:
		_stance_clock += delta
	if _decides():
		return
	if _anim.current_clip() == stance_clip:
		_anim.seek(_stance_clip_time(_stance_clock))


## A blow bends it over only so far.
func _flinch_body(blow: Vector3) -> void:
	if flinch_share >= 1.0:
		super(blow)
		return
	_last_blow = blow
	if is_dead or body == null:
		return
	if _hit_react == null:
		_hit_react = HitReact.on_body(body)
	_hit_react.strike(blow, FLINCH_THROW * flinch_share)
#endregion


#region Bent over its swings
## Each swing that finds no gap it lands from (its weapon over a man's head
## at this size): the least bend forward from the waist that brings it onto
## him. Its kind calls it once all its moves are in.
func _fit_stoops() -> void:
	if _anim == null or _stoop == null:
		return
	for what: int in _strikes_table:
		if _stoop_skip(what):
			continue
		var s: Array = _strikes_table[what]
		if s.size() < 6 or (s[5] as PackedFloat32Array).is_empty():
			continue
		var moments: PackedFloat32Array = s[5]
		_fit_body = stoop_body
		# a swing that already comes into his chest, as it is, is left as it is
		if _gap_that_lands(what, _moves_table[what], moments[0]) > 0.0:
			_fit_body = Vector3.ZERO
			continue
		if not _fit_stoop(what, moments) and not _strike_from.has(what):
			_fit_body = Vector3.ZERO
			_fit_stoop(what, moments)
		_fit_body = Vector3.ZERO
	_measure_bend = 0.0


## A move never bent: a kick or a butt (a limb, not the weapon) only if it
## would miss outright.
func _stoop_skip(what: int) -> bool:
	if what == LEAP:
		# it comes down on him body and all
		return true
	return _limbs_of.has(what) and _strike_from.has(what)


## The least bend that lands `what` on the body being fitted to (false: none).
func _fit_stoop(what: int, moments: PackedFloat32Array) -> bool:
	# the least bend that lands the most of its blows from about one gap
	# (a string of blows from one place), then a little deeper, if that
	# lands as many, so the weapon meets him across the chest rather than
	# grazing the top of his head
	var best_bend := -1.0
	var best_score := 0
	var best_from := -1.0
	var bend := stoop_step
	while bend <= stoop_most + 0.01:
		var got := _stoop_score(what, moments, bend)
		if int(got[0]) > best_score:
			best_score = int(got[0])
			best_bend = bend
			best_from = float(got[1])
		bend += stoop_step
	if best_bend < 0.0:
		return false
	var deeper := minf(best_bend + stoop_margin, stoop_most)
	var got := _stoop_score(what, moments, deeper)
	if int(got[0]) >= best_score:
		best_bend = deeper
		best_from = float(got[1])
	_stoops[what] = best_bend
	_strike_from[what] = best_from
	return true


## [how many of the blows land bent `bend` from about the gap the first lands
## from, that gap] (0 if the first does not land).
func _stoop_score(what: int, moments: PackedFloat32Array, bend: float) -> Array:
	_measure_bend = bend
	var first := _gap_that_lands(what, _moves_table[what], moments[0])
	var n := 0
	if first > 0.0:
		n = 1
		for k in range(1, moments.size()):
			var g := _gap_that_lands(what, _moves_table[what], moments[k])
			if g > 0.0 and absf(g - first) <= 0.7 * visual_scale / 1.6:
				n += 1
	_measure_bend = 0.0
	return [n, first]


## The blow's frames with its bend from the waist put in, as the stoop's
## modifier will bend it.
func _posed_frames(what: int, m: Array, frames: Array, from: float, to: float, steps: int) -> Array:
	var bend := _measure_bend if _measure_bend > 0.0 else float(_stoops.get(what, 0.0))
	if bend <= 0.0 or _stoop == null:
		return frames
	var waist := _anim.sample_stretches(m[0], [[_stoop.bones[0], _stoop.bones[0], null]], from, to, steps)
	var turn := Basis(Vector3.UP.cross(reach_forward.normalized()).normalized(), deg_to_rad(bend))
	var out: Array = []
	for i in frames.size():
		var w: Vector3 = (waist[i][0] as Array)[0] if i < waist.size() and not (waist[i] as Array).is_empty() else Vector3.ZERO
		var frame: Array = []
		for part: Array in frames[i]:
			frame.append([w + turn * ((part[0] as Vector3) - w), w + turn * ((part[1] as Vector3) - w)])
		out.append(frame)
	return out


## Its weapon and limbs where they strike, its stoop put in: the bend is laid
## on by a modifier after the poses are read, so the sweep bends them itself.
func _weapon_part() -> Array:
	return _stooped(super())


func _own_part(what: int) -> Array:
	return _stooped(super(what))


func _stooped(parts: Array) -> Array:
	if _stoop == null or _stoop.amount <= 0.01 or _skeleton == null:
		return parts
	var waist := _skeleton.find_bone(_stoop.bones[0])
	if waist < 0:
		return parts
	var w := _skeleton.global_transform * _skeleton.get_bone_global_pose(waist).origin
	var f := _forward()
	var turn := Basis(Vector3.UP.cross(f).normalized(), deg_to_rad(_stoop.amount))
	var out: Array = []
	for part: Array in parts:
		var bent := part.duplicate()
		bent[0] = w + turn * ((part[0] as Vector3) - w)
		bent[1] = w + turn * ((part[1] as Vector3) - w)
		out.append(bent)
	return out


## Every peer: through a swing that would pass over his head at its size,
## bent forward from the waist — into it by its first blow, out after its last.
func _stoop_into(delta: float) -> void:
	if _stoop == null:
		return
	if act_serial != _stoop_serial:
		_stoop_serial = act_serial
		_stoop_clock = 0.0
	else:
		_stoop_clock += delta
	var want := 0.0
	var rate := 90.0
	if not is_dead and _stoops.has(act):
		var ms := _blow_moments(act)
		if not ms.is_empty() and _stoop_clock < ms[ms.size() - 1] + 0.3:
			want = float(_stoops[act])
			rate = want / maxf(ms[0] - 0.08, 0.12)
	_stoop.amount = move_toward(_stoop.amount, want, delta * rate)
	_stoop.facing = _forward()
#endregion


#region Pack turns
## Host: not its turn (see `pack_turns`): it keeps off him, circling and
## facing him (true while it waits).
func _await_turn(delta: float) -> bool:
	# enraged it waits for no one
	if pack_turns <= 0 or raging or _quarry == null or drill_combo >= 0 or _my_turn():
		return false
	mode = Mode.FIGHT
	var to := _quarry.global_position - global_position
	to.y = 0.0
	var gap := to.length()
	if gap < 0.01:
		return false
	var dir := to / gap
	if act == Act.NONE and _while_waiting(delta):
		return true
	_circle_for -= delta
	if _circle_for <= 0.0:
		_circle_for = _rng.randf_range(1.8, 3.6)
		_circle_dir = -_circle_dir if _rng.randf() < 0.5 else _circle_dir
	var want := dir.cross(Vector3.UP) * _circle_dir * 0.7
	var keep := turn_wait_gap
	var pace := turn_wait_speed
	if gap < keep - 0.8:
		want -= dir
	elif gap > keep + 1.2:
		want += dir * 1.5
		if gap > keep + 4.0:
			pace = chase_speed
	want = want.normalized() * pace
	velocity.x = move_toward(velocity.x, want.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, want.z, acceleration * delta)
	_face(to, delta, turn_speed)
	turn_waited += delta
	return true


## Its kind's own doing while it waits its turn (true if it took a move).
func _while_waiting(_delta: float) -> bool:
	return false


## Whether fewer than `pack_turns` of its kind are before it on him: those
## nearer him, and those in the middle of a blow on him.
func _my_turn() -> bool:
	var mine := _distance_to(_quarry)
	var before := 0
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var o := node as PackBrute
		if o == null or o == self or o.is_dead or o.pack_turns <= 0 or o._quarry != _quarry:
			continue
		if o.mode != Mode.FIGHT and o.mode != Mode.CHASE:
			continue
		var theirs := o._distance_to(_quarry)
		var striking := o.act != Act.NONE and theirs < o.reach + 2.0
		if striking or theirs < mine - 0.4 or (absf(theirs - mine) <= 0.4 and o.get_instance_id() < get_instance_id()):
			before += 1
			if before >= pack_turns:
				return false
	return true
#endregion
