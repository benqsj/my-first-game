class_name GhoulFighter
extends Brawler

## The ghoul (Polysplit's Biped Creatures, CREATURES_PACK.md): quick and
## low, it does not stand and trade blows (the user's pick, 2026-10-06). Its
## own moves since 2026-10-27 (the user's picks from the films, project doc
## claude/ghoul_goblin_plan.md; the clips CR_GH_*, Mixamo's, in
## tools/creature_clips.gd):
##
## * **On all fours, up for the claws.** It comes at a run on all fours
##   (`run_clip`), rears up close and throws a string of two: a jab and the
##   long claw, or a wide swipe and the left claw (`_combos`). Off him after
##   it mostly (`dart_chance`) it scuttles back and aside on all fours, the
##   crawl run backwards, facing him, and comes again.
## * **The pounce, with a tell.** From `leap_from` to `leap_to` off, now and
##   then (`leap_cooldown`), it first drops low a beat (`tell_time`: a
##   shiver, a hiss, its eyes flash) and then springs (`CR_GH_Pounce`, the
##   clip's high jump pressed down to a long low one, `leap_press`): it
##   comes down on him and knocks him off his feet.
## * **On him.** Felled by the pounce, it is on him on the ground biting
##   (`PIN`, his neck, `pin_bite_every`), venom with each bite, until he
##   kicks it off (pressing the key fast: [method Player.net_pinned]), a
##   friend strikes it off him, or `pin_most` runs out. Kicked or struck off
##   it goes over onto its back and gets up again.
## * **Lying as dead.** Some lie among the dead as if dead (`feign_chance`),
##   nothing to lock on to, no bar over them, until a hero comes within
##   `feign_range` (or strikes one): its eyes open, it pushes up off its
##   hands and springs at him from there, no tell, no standing up between.
## * **Venomed claws.** Green drips off its claws; a blow of its that reaches
##   him, not on his guard, throws venom into him ([HeroPoison], a bar).
## * **The scream and the frenzy.** Cut under `frenzy_at` of its health it
##   screams (its own scream): the air breaks from its mouth (no ring), its
##   eyes go red, steam comes off it; from then on it is faster on its feet
##   and in its swings (`frenzy_pace`), hardly a breath between them, no more
##   running off, and a blow no longer stops it; a red glow on it.
## * **Feeding.** A corpse within `feed_range` while it is hurt and he is not
##   close (or it is not roused): it bends over it and eats, health back
##   (`feed_heal`), blood at its mouth. Two at one corpse quarrel over it: a
##   hiss, a claw each, the weaker gives way. Struck from behind while it eats
##   or quarrels, the blow is a critical (`crit_mult`).
## * **Its death.** It goes over onto its back, twitches a while, and lies
##   still; a pool of venom spreads under it.

@export_group("Ghoul")
@export var leap_clip: StringName = &"CR_GH_Pounce"
## [rate, from, to] of the pounce, and the share of its clip it lands at.
@export var leap_part: Vector3 = Vector3(1.35, 0.035, 1.0)
@export var leap_land: float = 0.655
@export var leap_from: float = 3.2
@export var leap_to: float = 8.0
@export var leap_cooldown: float = 3.5
## The clip's jump is high (1.6 m): the body drawn down by this share of its
## rise above standing, so it reads as a long low pounce.
@export var leap_press: float = 0.55
## What lands: its whole body thrown onto him, and its claws.
@export var leap_limbs: String = "pelvis_joint>head_joint:0.32|L_elbow_joint>L_midFinger_joint3:0.14|R_elbow_joint>R_midFinger_joint3:0.14"
## How far short of him it means to come down.
@export var leap_short: float = 0.75
## The tell before it springs: down low this long.
@export var tell_clip: StringName = &"CR_GH_Crouch"
@export var tell_time: float = 0.42
@export_range(0.0, 1.0) var dart_chance: float = 0.7
@export var dart_time: Vector2 = Vector2(0.6, 1.1)
@export var dart_speed: float = 4.2

@export_group("Claw strings")
## Each string: [clip, rate, from, to] twice, the two blows of it.
@export var string_limbs: PackedStringArray = PackedStringArray([
	"R_elbow_joint>R_midFinger_joint3:0.12",
	"L_elbow_joint>L_midFinger_joint3:0.12|R_elbow_joint>R_midFinger_joint3:0.12",
	"L_elbow_joint>L_midFinger_joint3:0.12|R_elbow_joint>R_midFinger_joint3:0.12",
	"L_elbow_joint>L_midFinger_joint3:0.13"])
## How often it bites instead (its old bite, `attacks`).
@export_range(0.0, 1.0) var bite_chance: float = 0.2

@export_group("On him")
@export var pin_clip: StringName = &"CR_GH_Pin"
@export var pin_most: float = 6.0
## Him down: it goes to him, and only if it is at him (`pin_reach` m) while he
## is still down does it get on him; a beat after its pounce lands first
## (`pin_delay` s); and after he has pushed it off, not again for `pin_rest` s.
@export var pin_reach: float = 1.3
@export var pin_delay: float = 0.2
@export var pin_rest: float = 4.0
var _pin_wait: float = 0.0
var _pin_rest_left: float = 0.0
@export var pin_bite_every: float = 0.75
## A bite's share of `hit_damage`.
@export var pin_bite_share: float = 0.35
@export var thrown_clip: StringName = &"CR_GH_Thrown"
@export var up_clip: StringName = &"CR_GH_UpBack"
## Kicked off him: its share of `hit_damage` taken, as a blow.
@export var kicked_share: float = 1.5

@export_group("Lying as dead")
@export_range(0.0, 1.0) var feign_chance: float = 0.3
@export var feign_range: float = 4.6
@export var feign_clip: StringName = &"CR_GH_Feign"
## Up off its belly: [rate, from, to] of the clip.
@export var spring_part: Vector3 = Vector3(3.4, 0.46, 1.0)

@export_group("Venom")
## Venom thrown into him by a claw that lands, and how much more creeps in.
@export var venom_hit: float = 30.0
@export var venom_creep: float = 15.0
@export var venom_bite: float = 8.0
@export var venom_bite_creep: float = 4.0
## Not every ghoul is venomous (the user's word, 2026-10-27): this share of
## them are, picked from its name so every peer agrees (-1 / 0 / 1 in
## `force_venom` to pick, or force it); and a venomous one's claw throws
## venom in only on this share of its blows (its bite always).
@export var venomous_share: float = 0.5
@export var force_venom: int = -1
@export var venom_chance: float = 0.45
var venomous: bool = true

@export_group("Frenzy")
@export_range(0.0, 1.0) var frenzy_at: float = 0.45
@export var scream_clip: StringName = &"CR_GH_Scream"
@export var scream_part: Vector3 = Vector3(1.0, 0.0, 1.0)
@export var frenzy_pace: float = 1.3
@export var frenzy_glow: Color = Color(1.0, 0.12, 0.05)
## When the scream's breath leaves its mouth (s into the scream).
@export var scream_bursts: PackedFloat32Array = PackedFloat32Array([0.62, 0.9, 1.18])

@export_group("Feeding")
@export var feed_range: float = 14.0
@export var feed_clip: StringName = &"CR_GH_Pin"
@export var feed_part: Vector3 = Vector3(1.0, 0.0, 1.0)
@export var feed_heal: float = 0.06
@export var feed_most: float = 8.0
## Feeds while roused only with him further off than this.
@export var feed_while_far: float = 9.0
## A blow from behind while it eats or quarrels, this many times as deep.
@export var crit_mult: float = 2.5
## Bent over its meal, how close he can come at its back before it knows.
@export var feed_unseen: float = 0.5

@export_group("Death")
@export var twitch_after: float = 2.4
@export var twitch_time: float = 2.4
@export var death_pool: float = 0.85

const LEAP := 96
const SCREAM := 103
const FEED := 104
const TELL := 130
const JAB := 131
const CLAW := 132
const SWIPE := 133
const LEFT := 134
const PIN := 135
const THROWN := 136
const UP := 137
const LIE := 138
const SPRING := 139
const HISS := 140
const QUARREL_A := 141
const QUARREL_B := 142
const STUMBLE := 143
const ALERT := 144
## The two strings: first blow, second.
const STRINGS := [[JAB, CLAW], [SWIPE, LEFT]]
## Where it is open to a critical from behind.
const DISTRACTED := [FEED, HISS, QUARREL_A, QUARREL_B, STUMBLE, ALERT]
const EYE_TELL := Color(0.85, 1.0, 0.35)

var frenzied: bool = false
var _corpse: Node3D = null
var _fed_for: float = 0.0
var _glow: StandardMaterial3D
var _glow_light: OmniLight3D

var _leap_wait: float = 1.0
var _leap_speed: float = 0.0
var _dart_left: float = 0.0
var _dart_side: float = 1.0
var _string_next: int = -1

var _pinned: Node3D = null
var _pin_left: float = 0.0
var _bite_in: float = 0.0
var _pin_want: Node3D = null

var _feign_asked: bool = false
var _feigning: bool = false
var _feign_shift: Vector3 = Vector3.ZERO
var _feign_shifted: bool = false
var _pressed: bool = false
## Every peer: lying as dead now (nothing for a hero to lock on to:
## [method Player._targetable]).
var playing_dead: bool = false

var _rival: GhoulFighter = null
var _shunned: Node3D = null
var _shun_left: float = 0.0
var _quarrel_hit: bool = false

var _sparks: Array[MeshInstance3D] = []
var _eye_left: float = 0.0
var _twitch_at: float = -1.0
var _twitch_base: Dictionary = {}
var _twitch_kick: Dictionary = {}


func _ready() -> void:
	super()
	_moves_table[LEAP] = [leap_clip, leap_part.x, leap_part.y, leap_part.z]
	_own_limb(LEAP, leap_limbs)
	var s: Array = _strikes_table[LEAP]
	# One blow that knocks him down, at the landing.
	_strikes_table[LEAP] = [s[0], s[1], 1.3, 1, 0.6, PackedFloat32Array([leap_land])]
	_moves_table[SCREAM] = [scream_clip, scream_part.x, scream_part.y, scream_part.z]
	_moves_table[FEED] = [feed_clip, feed_part.x, feed_part.y, feed_part.z]
	# its claw strings (shares of each clip: past the wind-up of the first,
	# short of the long settle of the last)
	var clip_len := func(clip: StringName, fallback: float) -> float:
		return _anim.clip_length(clip) if _anim != null and _anim.has_clip(clip) else fallback
	_moves_table[JAB] = [&"CR_GH_Jab", 1.25, 0.05, 0.82]
	_moves_table[CLAW] = [&"CR_GH_Claw", 1.3, 0.14, 0.46]
	_moves_table[SWIPE] = [&"CR_GH_Swipe", 1.3, 0.095, 0.51]
	_moves_table[LEFT] = [&"CR_GH_LeftClaw", 1.35, 0.26, 0.71]
	for i in 4:
		_own_limb(JAB + i, string_limbs[i] if i < string_limbs.size() else "")
		_moment_at_reach(JAB + i)
		# its claws do not fell him (the acts are numbered past BIG_BASE, which
		# would count each as a felling blow): `blows_to_fell` as its bite
		var st: Array = _strikes_table[JAB + i]
		st[3] = maxi(blows_to_fell, 1)
	_moves_table[TELL] = [tell_clip, 1.0, 0.0, tell_time / maxf(clip_len.call(tell_clip, 2.5), 0.1)]
	_moves_table[PIN] = [pin_clip, 1.25, 0.0, 1.0]
	_moves_table[THROWN] = [thrown_clip, 1.4, 0.18, 0.75]
	_moves_table[UP] = [up_clip, 1.4, 0.1, 1.0]
	# lying as dead: the clip's first frame held (played a hair at a time)
	_moves_table[LIE] = [feign_clip, 0.001, 0.0, 0.001]
	_moves_table[SPRING] = [feign_clip, spring_part.x, spring_part.y, spring_part.z]
	_moves_table[HISS] = [&"CR_GH_Hiss", 1.3, 0.0, 1.0]
	_moves_table[QUARREL_A] = [&"CR_GH_Swipe", 1.35, 0.095, 0.51]
	_moves_table[QUARREL_B] = [&"CR_GH_LeftClaw", 1.4, 0.26, 0.71]
	_moves_table[STUMBLE] = [&"CR_GH_Stumble", 1.3, 0.0, 0.8]
	_moves_table[ALERT] = [&"CR_GH_Alert", 1.3, 0.0, 1.0]
	add_to_group(&"ghouls")
	venomous = force_venom == 1 if force_venom >= 0 \
			else float(posmod(hash(String(name) + "/venom"), 1000)) / 1000.0 < venomous_share
	if venomous:
		_claw_drips()
	_make_sparks()


func _leaps() -> Array:
	return [LEAP]


func _think(delta: float) -> void:
	_leap_wait = maxf(_leap_wait - delta, 0.0)
	_shun_left = maxf(_shun_left - delta, 0.0)
	if is_dead:
		super(delta)
		return
	if not _feign_asked:
		_feign_asked = true
		if mode == Mode.GUARD and _rng.randf() < feign_chance:
			_feigning = true
			_begin(LIE)
			return
	if act == LIE:
		_lying(delta)
		return
	if act == PIN:
		_pinning(delta)
		return
	# (no longer on him the moment its pounce fells him, the user's word
	# 2026-10-27: it has to get to him while he is still down, [method _go_pin])
	_pin_wait = maxf(_pin_wait - delta, 0.0)
	_pin_rest_left = maxf(_pin_rest_left - delta, 0.0)
	# its pounce has felled him: off the rest of its landing, to him
	if act == LEAP and _quarry is Player and (_quarry as Player).state == Player.State.DOWNED \
			and _act_time > _blow_moments(LEAP)[0] + 0.1:
		_leap_wait = leap_cooldown * (0.5 if frenzied else 1.0)
		_pin_want = null
		_pin_wait = pin_delay
		_start(Act.NONE)
	if act == FEED:
		_feeding(delta)
		return
	if act in [TELL, SPRING, THROWN, UP, HISS, QUARREL_A, QUARREL_B, STUMBLE, ALERT]:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * 4.0 * delta) if act == TELL else velocity.x
		velocity.z = move_toward(velocity.z, 0.0, acceleration * 4.0 * delta) if act == TELL else velocity.z
		if (act == QUARREL_A or act == QUARREL_B) and not _quarrel_hit and _act_time >= _quarrel_moment():
			_quarrel_hit = true
			_claw_rival()
		return
	if act != Act.NONE or mode == Mode.RETURN:
		super(delta)
		return
	# Cut deep enough: the scream, and the frenzy after it.
	if not frenzied and (mode == Mode.CHASE or mode == Mode.FIGHT) and health <= max_health * frenzy_at:
		_corpse = null
		velocity.x = 0.0
		velocity.z = 0.0
		_begin(SCREAM)
		return
	if _go_feed(delta):
		return
	if mode == Mode.GUARD:
		super(delta)
		return
	_quarry = _pick_quarry()
	if _quarry == null:
		super(delta)
		return
	if _go_pin(delta):
		return
	var to := _quarry.global_position - global_position
	to.y = 0.0
	var gap := to.length()
	if _dart_left > 0.0:
		# Off to the side and back a little, facing him.
		_dart_left -= delta
		mode = Mode.FIGHT
		_face(to, delta, turn_speed * 2.0)
		var side := to.normalized().cross(Vector3.UP) * _dart_side
		var way := (side * 0.8 - to.normalized() * 0.6).normalized() * dart_speed
		velocity.x = move_toward(velocity.x, way.x, acceleration * 4.0 * delta)
		velocity.z = move_toward(velocity.z, way.z, acceleration * 4.0 * delta)
		return
	if _leap_wait <= 0.0 and gap >= leap_from and gap <= leap_to and not _quarry_down() \
			and stamina >= attack_cost:
		mode = Mode.FIGHT
		_face(to, 1.0, 50.0)
		velocity.x = 0.0
		velocity.z = 0.0
		_begin(TELL)
		return
	super(delta)


## A string of two claws, or now and then its bite.
func _begin_attack() -> void:
	if _quarry_down() or _quarry == null:
		_cooldown = maxf(_cooldown, 0.15)
		return
	var gap := _distance_to(_quarry)
	if gap > strike_off + 0.5:
		_move_towards(_quarry.global_position, chase_speed, get_physics_process_delta_time())
		return
	if not attacks.is_empty() and _rng.randf() < bite_chance:
		super()
		return
	var string: Array = STRINGS[_rng.randi() % STRINGS.size()]
	_face(_quarry.global_position - global_position, 1.0, 50.0)
	_string_next = string[1]
	_begin(string[0])


func _leap(gap: float) -> void:
	_begin(LEAP)
	var until := _blow_moments(LEAP)[0]
	# the clip carries it forward too: only the rest of the way is added
	var travel := _hips(leap_clip, _clip_time(LEAP, until)).x - _hips(leap_clip, _clip_time(LEAP, 0.0)).x
	_leap_speed = maxf(gap - leap_short - travel, 0.0) / maxf(until, 0.2)


func _extra_velocity(delta: float) -> Vector3:
	if act == LEAP:
		if _act_time <= _blow_moments(LEAP)[0]:
			return _forward() * _leap_speed
		return Vector3.ZERO
	if act in [PIN, LIE, SPRING, THROWN, UP, TELL, HISS, QUARREL_A, QUARREL_B, STUMBLE, ALERT]:
		return Vector3.ZERO
	return super(delta)


func _after(what: int) -> void:
	match what:
		TELL:
			var q := _pick_quarry()
			if q != null and not _quarry_down():
				_quarry = q
				var to := q.global_position - global_position
				to.y = 0.0
				_face(to, 1.0, 50.0)
				_leap(to.length())
				return
			_start(Act.NONE)
			return
		LIE:
			_begin(LIE)
			return
		SPRING:
			_feigning = false
			var q := _pick_quarry()
			if q != null:
				_quarry = q
				var to := q.global_position - global_position
				to.y = 0.0
				_face(to, 1.0, 50.0)
				_leap(to.length())
				return
			_start(Act.NONE)
			return
		PIN:
			if _pinned != null:
				_begin(PIN)
				return
		THROWN:
			_begin(UP)
			return
		HISS:
			if _rival != null and is_instance_valid(_rival) and not _rival.is_dead:
				_face(_rival.global_position - global_position, 1.0, 50.0)
				_quarrel_hit = false
				_begin(QUARREL_A)
				return
		QUARREL_A, QUARREL_B, STUMBLE, ALERT:
			_end_quarrel(what)
			return
	if what == LEAP:
		_leap_wait = leap_cooldown * (0.5 if frenzied else 1.0)
		_pin_want = null
		_pin_wait = pin_delay
	if what == SCREAM and not frenzied:
		_send_frenzy()
	# the second blow of the string, if he is still there for it
	if (what == JAB or what == SWIPE) and _string_next >= 0 and _quarry != null and not _quarry_down() \
			and _distance_to(_quarry) <= strike_off + 0.9:
		var next := _string_next
		_string_next = -1
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_begin(next)
		return
	_string_next = -1
	if _strikes_table.has(what) and what != JAB and what != SWIPE and not frenzied and _rng.randf() < dart_chance:
		_dart_left = _rng.randf_range(dart_time.x, dart_time.y)
		_dart_side = 1.0 if _rng.randf() < 0.5 else -1.0
	super(what)


## Off him backwards on all fours: the crawl run played back to front (every
## peer: read off how it moves, the way it faces).
func _play_locomotion(delta: float) -> void:
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	if planar.dot(_forward()) < -1.5 and _anim != null and _anim.has_clip(run_clip):
		var rate := gait_rate(run_clip, planar.length())
		_anim.play(run_clip, 0.2, rate)
		_anim.rewind(rate)
		return
	super(delta)


#region Venom
func _blow_reached(who: Node3D, what: int) -> void:
	if is_dead or who == null:
		return
	if what == LEAP:
		_pin_want = who
	if bool(who.get("net_blocking")) or bool(who.get("is_blocking")):
		return
	if not venomous or _rng.randf() >= venom_chance:
		return
	var poison := HeroPoison.of(who)
	if poison != null:
		poison.apply_venom(venom_hit, venom_creep)


## Every peer: green drips off both hands' claws, and a faint green light.
func _claw_drips() -> void:
	if _skeleton == null:
		return
	for bone: String in ["L_midFinger_joint3", "R_midFinger_joint3"]:
		if _skeleton.find_bone(bone) < 0:
			continue
		var at := BoneAttachment3D.new()
		at.bone_name = bone
		_skeleton.add_child(at)
		var p := _particles(Color(0.45, 1.0, 0.2, 0.95), 14, 0.7, 0.045, Vector3(0, -9.8, 0))
		var pm := p.process_material as ParticleProcessMaterial
		pm.direction = Vector3.DOWN
		pm.spread = 25.0
		pm.initial_velocity_min = 0.2
		pm.initial_velocity_max = 0.6
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.05
		p.emitting = true
		at.add_child(p)
		var l := OmniLight3D.new()
		l.light_color = Color(0.4, 1.0, 0.2)
		l.light_energy = 0.4
		l.omni_range = 0.7
		l.shadow_enabled = false
		at.add_child(l)
#endregion


#region On him
## Host: him down (not yet getting up): to him, and on him if it gets there
## before he starts up.
func _go_pin(delta: float) -> bool:
	var hero := _quarry as Player
	if hero == null or hero.state != Player.State.DOWNED or hero.is_dead or _pin_rest_left > 0.0:
		return false
	# up on his feet first: he got away
	if bool(hero.get(&"_getting_up")):
		return false
	for node in get_tree().get_nodes_in_group(&"ghouls"):
		var other := node as GhoulFighter
		if other != null and other != self and other._pinned == hero:
			return false
	mode = Mode.FIGHT
	var to := hero.global_position - global_position
	to.y = 0.0
	if to.length() > pin_reach:
		_move_towards(hero.global_position, chase_speed, delta)
		return true
	_face(to, delta, turn_speed * 2.0)
	velocity.x = 0.0
	velocity.z = 0.0
	if _pin_wait > 0.0:
		return true
	return _try_pin(hero)


## Host: on him where he lies, if he lies there and no other ghoul has him.
func _try_pin(who: Node3D) -> bool:
	_pin_want = null
	if not (who is Player) or not is_instance_valid(who) or bool(who.get("is_dead")):
		return false
	if (who as Player).state != Player.State.DOWNED:
		return false
	for node in get_tree().get_nodes_in_group(&"ghouls"):
		var other := node as GhoulFighter
		if other != null and other != self and other._pinned == who:
			return false
	_pinned = who
	_pin_left = pin_most
	_bite_in = pin_bite_every * 0.6
	add_collision_exception_with(who as PhysicsBody3D)
	_begin(PIN)
	_send_pin(who, true)
	return true


func _send_pin(who: Node3D, on: bool) -> void:
	if who == null or not is_instance_valid(who):
		return
	var method := &"net_pinned" if on else &"net_unpinned"
	if not who.has_method(method):
		return
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		if on:
			who.rpc_id(who.get_multiplayer_authority(), method, get_path())
		else:
			who.rpc_id(who.get_multiplayer_authority(), method)
	else:
		if on:
			who.call(method, get_path())
		else:
			who.call(method)


## Host, each tick on him: its head kept over his chest, a bite now and then.
func _pinning(delta: float) -> void:
	var who := _pinned
	if who == null or not is_instance_valid(who) or bool(who.get("is_dead")):
		_let_go(false)
		return
	_pin_left -= delta
	if _pin_left <= 0.0:
		_let_go(true)
		return
	var chest := _bone_of(who, &"spine_03", who.global_position + Vector3.UP * 0.3)
	var head := _head_point()
	var d := chest - head
	d.y = 0.0
	var v := d / maxf(delta, 0.001) * 0.35
	v = v.limit_length(4.0)
	velocity.x = v.x
	velocity.z = v.z
	_bite_in -= delta
	if _bite_in > 0.0:
		return
	_bite_in = pin_bite_every
	var dmg := hit_damage * pin_bite_share * (frenzy_pace if frenzied else 1.0)
	if who.has_method(&"net_pin_bite"):
		if multiplayer.has_multiplayer_peer():
			who.rpc_id(who.get_multiplayer_authority(), &"net_pin_bite", dmg)
		else:
			who.call(&"net_pin_bite", dmg)
	var poison := HeroPoison.of(who) if venomous else null
	if poison != null:
		poison.apply_venom(venom_bite, venom_bite_creep)
	var neck := _bone_of(who, &"neck_01", chest + Vector3.UP * 0.2)
	if multiplayer.has_multiplayer_peer():
		net_bite.rpc(neck)
	else:
		net_bite(neck)


## Every peer: a bite on him, blood at his throat.
@rpc("authority", "call_local", "unreliable")
func net_bite(at: Vector3) -> void:
	# his blood thrown up as it tears at him (the user's word, 2026-10-27)
	var world := Blood.world_of(self)
	Blood.spill(world, at, Vector3(0.0, 0.6, 0.0) - _forward() * 0.6, null, 1.3)
	Blood.splatter(world, at, Vector3(0.0, 1.0, 0.0) - _forward() * 0.4)
	SkillFx.particles(world, at, {
		"amount": 22, "life": 0.8, "one_shot": true, "explosiveness": 0.9, "speed": Vector2(1.2, 3.4),
		"dir": Vector3.UP - _forward() * 0.6, "spread": 45.0, "gravity": Vector3(0, -9.0, 0), "damping": 0.5,
		"size": Vector2(0.035, 0.075), "add": false,
		"colors": [Color(0.5, 0.0, 0.0, 1.0), Color(0.36, 0.0, 0.0, 1.0), Color(0.25, 0.0, 0.0, 0.0)]})


## Host: off him. `away`: of itself (it scuttles off).
func _let_go(away: bool) -> void:
	var who := _pinned
	_pinned = null
	if who != null and is_instance_valid(who):
		remove_collision_exception_with(who as PhysicsBody3D)
		_send_pin(who, false)
	_start(Act.NONE)
	if away and not is_dead:
		_dart_left = dart_time.y
		_dart_side = 1.0 if _rng.randf() < 0.5 else -1.0


## Host: kicked off him (he pressed it off, [method Player.net_pinned]):
## thrown onto its back away from him, and up again.
@rpc("any_peer", "call_local", "reliable")
func net_kicked(hero: NodePath) -> void:
	if not _decides() or is_dead:
		return
	var who := get_node_or_null(hero) as Node3D
	if who == null or who != _pinned:
		return
	_pinned = null
	remove_collision_exception_with(who as PhysicsBody3D)
	# pushed off him: back off him, not thrown over (the user's word,
	# 2026-10-27); hurt, and not on him again for a while
	var to := who.global_position - global_position
	to.y = 0.0
	if to.length_squared() > 0.0001:
		_face(to, 1.0, 50.0)
	health = maxf(health - hit_damage * kicked_share, 1.0)
	net_bleed.rpc(_head_point(), -to.normalized() + Vector3.UP * 0.5)
	_pin_rest_left = pin_rest
	_start(Act.NONE)
	_dart_left = dart_time.y
	_dart_side = 1.0 if _rng.randf() < 0.5 else -1.0


## Host: struck or kicked off whoever it was on, over onto its back.
func _thrown_off(from: Node3D, damage: float) -> void:
	var to := from.global_position - global_position
	to.y = 0.0
	if to.length_squared() > 0.0001:
		_face(to, 1.0, 50.0)
	if damage > 0.0:
		health = maxf(health - damage, 1.0)
		net_bleed.rpc(_head_point(), -to.normalized() + Vector3.UP * 0.5)
	_begin(THROWN)


func _head_point() -> Vector3:
	if _skeleton != null:
		var i := _skeleton.find_bone("head_joint")
		if i >= 0:
			return _skeleton.global_transform * _skeleton.get_bone_global_pose(i).origin
	return global_position + Vector3.UP * 1.0


static func _bone_of(who: Node3D, bone: StringName, fallback: Vector3) -> Vector3:
	var rig := who.get(&"rig") as Node
	if rig != null and rig.has_method(&"bone_position"):
		return rig.call(&"bone_position", bone)
	return fallback
#endregion


#region Lying as dead
## Host, lying there: up and at a hero who comes close.
func _lying(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	var q := _pick_quarry()
	if q == null or _distance_to(q) > feign_range:
		return
	_quarry = q
	_rouse(q)
	_face(q.global_position - global_position, 1.0, 50.0)
	_begin(SPRING)


## Every peer, while it lies or springs up: its body put back over where it
## is (the clip lies 1.2 m ahead of its root, as Mixamo gave it); its bars
## kept away and nothing to lock on to.
func _feign_look() -> void:
	var lying := act == LIE or act == SPRING
	if _health_bar != null:
		_health_bar.visible = act != LIE and not is_dead
	if _stamina_bar != null:
		_stamina_bar.visible = act != LIE and not is_dead
	playing_dead = act == LIE
	if body == null:
		return
	if lying and not _feign_shifted and _skeleton != null:
		var i := _skeleton.find_bone("pelvis_joint")
		if i < 0:
			return
		var pel := _skeleton.global_transform * _skeleton.get_bone_global_pose(i).origin
		var off := pel - global_position
		off.y = 0.0
		if off.length() < 0.4:
			return  # the lying pose not on it yet
		_feign_shift = global_basis.inverse() * off
		_feign_shift.y = 0.0
		body.position -= _feign_shift
		_feign_shifted = true
	elif not lying and _feign_shifted:
		body.position += _feign_shift
		_feign_shifted = false
#endregion


#region The pounce, seen
## Every peer: the tell (a hiss, the eyes flash); the scream's breath and its
## eyes going red.
func _play_act() -> void:
	super()
	match act:
		TELL:
			_hiss()
			_set_eyes(EYE_TELL, 2.5)
			_eye_left = tell_time + 0.05
		SPRING:
			_set_eyes(EYE_TELL, 3.0)
			_eye_left = 0.35
		SCREAM:
			_scream_fx()


## Every peer: the pounce pressed down, the tell's shiver.
func _pounce_look(delta: float) -> void:
	if body == null or _skeleton == null:
		return
	var s := maxf(visual_scale, 0.01)
	if act == LEAP:
		var i := _skeleton.find_bone("pelvis_joint")
		if i >= 0:
			var pel := (_skeleton.global_transform * _skeleton.get_bone_global_pose(i).origin).y \
					- body.global_position.y
			body.position.y = _body_rest_y - leap_press * maxf(pel - 0.93 * s, 0.0)
			_pressed = true
	elif _pressed and not is_dead:
		body.position.y = _body_rest_y
		_pressed = false
	if act == TELL and not is_dead:
		var j := Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)) * 0.022 * s
		body.position.x = j.x - (_feign_shift.x if _feign_shifted else 0.0)
		body.position.z = j.z - (_feign_shift.z if _feign_shifted else 0.0)
	if _eye_left > 0.0:
		_eye_left -= delta
		if _eye_left <= 0.0 and not frenzied:
			_set_eyes(Color.BLACK, 0.0)
			if not _feign_shifted:
				body.position.x = 0.0
				body.position.z = 0.0


## A hiss: a breath of grey spittle out of its mouth.
func _hiss() -> void:
	var p := _particles(Color(0.85, 0.9, 0.8, 0.55), 14, 0.5, 0.09, Vector3(0, -0.5, 0))
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 22.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.0
	p.one_shot = true
	p.explosiveness = 0.3
	var into := Blood.world_of(self)
	if into == null:
		return
	into.add_child(p)
	p.global_position = _head_point() + _forward() * 0.2
	p.global_rotation.y = global_rotation.y
	p.emitting = true
	p.finished.connect(p.queue_free)
#endregion


#region Eyes
## Its eyes lit (`energy` 0: as they are): the eye strips of its own shader
## ([code]eye_emit[/code], [code]eye_tint[/code]) and two glowing points where
## they are, so the glow reads from afar.
func _set_eyes(colour: Color, energy: float) -> void:
	if body != null:
		for node in body.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			var mat := mi.get_active_material(0) as ShaderMaterial
			if mat == null or mat.shader != PackCreature.SHADER:
				continue
			mi.set_instance_shader_parameter(&"eye_emit", Vector3(colour.r, colour.g, colour.b) * energy)
			mi.set_instance_shader_parameter(&"eye_tint",
					Vector3(colour.r, colour.g, colour.b) if energy > 0.0 else Vector3(-1, -1, -1))
	for m in _sparks:
		if not is_instance_valid(m):
			continue
		var spark := m.material_override as StandardMaterial3D
		spark.albedo_color = Color(colour.r, colour.g, colour.b, clampf(energy / 3.0, 0.0, 1.0))
		m.visible = energy > 0.01


## The eyes' middles, in the head bone's frame: the body mesh's vertices the
## mask's eye strips cover (creature_rgb.gdshader), from the skin's bind of
## the head, split left and right. Measured once per mesh.
static var _eye_cache: Dictionary = {}


func _make_sparks() -> void:
	if body == null or _skeleton == null:
		return
	var head := _skeleton.find_bone("head_joint")
	if head < 0:
		return
	var points: Array = []
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.skin == null:
			continue
		var key := mi.mesh.get_rid().get_id()
		if not _eye_cache.has(key):
			_eye_cache[key] = _eye_points(mi)
		points.append_array(_eye_cache[key])
	for p: Vector3 in points:
		var at := BoneAttachment3D.new()
		at.bone_name = "head_joint"
		_skeleton.add_child(at)
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.11, 0.11)
		m.mesh = q
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_texture = SkillFx.dot()
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		at.add_child(m)
		m.position = p
		_sparks.append(m)


static func _eye_points(mi: MeshInstance3D) -> Array:
	var bind := -1
	for b in mi.skin.get_bind_count():
		if String(mi.skin.get_bind_name(b)) == "head_joint":
			bind = b
			break
	if bind < 0:
		return []
	var to_head := mi.skin.get_bind_pose(bind)
	var sums := [Vector3.ZERO, Vector3.ZERO]
	var counts := [0, 0]
	for si in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(si)
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		if uvs.size() != verts.size():
			continue
		for i in verts.size():
			var u := Vector2(uvs[i].x, 1.0 - uvs[i].y)
			if absf(u.x - 0.75) >= 0.245 or (absf(u.y - 0.4325) >= 0.0125 and absf(u.y - 0.325) >= 0.0125):
				continue
			var out := norms[i] * 0.03 if norms.size() == verts.size() else Vector3.ZERO
			var side := 0 if verts[i].x > 0.0 else 1
			sums[side] += verts[i] + out
			counts[side] += 1
	var points: Array = []
	for k in 2:
		if int(counts[k]) > 0:
			points.append(to_head * ((sums[k] as Vector3) / float(counts[k])))
	return points
#endregion


#region The frenzy
func _send_frenzy() -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_frenzy.rpc()
	else:
		net_frenzy()


## Every peer: in a frenzy from now on.
@rpc("authority", "call_local", "reliable")
func net_frenzy() -> void:
	if frenzied:
		return
	frenzied = true
	speed *= frenzy_pace
	chase_speed *= frenzy_pace
	close_speed *= frenzy_pace
	dart_speed *= frenzy_pace
	attack_cooldown *= 0.35
	stamina_regen *= 2.0
	for what: int in _moves_table:
		if not what in [SCREAM, FEED, ROAR, LIE, PIN, HISS]:
			var m: Array = (_moves_table[what] as Array).duplicate()
			m[1] = float(m[1]) * frenzy_pace
			_moves_table[what] = m
	_set_eyes(Color(1.0, 0.06, 0.02), 3.0)
	_glow_on()


## Every peer, as it screams: its eyes go red, the air breaks from its mouth
## in waves, steam comes off it.
func _scream_fx() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(0.55).timeout.connect(_scream_eyes)
	for t in scream_bursts:
		tree.create_timer(t).timeout.connect(_air_burst)


func _scream_eyes() -> void:
	if is_dead:
		return
	_set_eyes(Color(1.0, 0.06, 0.02), 3.0)
	_steam()


## A ball of bent air out of its mouth, swelling and gone (no ring).
func _air_burst() -> void:
	if is_dead:
		return
	var into := Blood.world_of(self)
	if into == null:
		return
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 32
	s.rings = 16
	mi.mesh = s
	var m := ShaderMaterial.new()
	m.shader = load(SCREAM_AIR)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	into.add_child(mi)
	var fw := _forward()
	var at := _head_point() + fw * 0.3 + Vector3.UP * 0.05
	mi.global_position = at
	var tw := mi.create_tween()
	tw.tween_method(func(u: float) -> void:
		mi.scale = Vector3.ONE * lerpf(0.3, 4.2, 1.0 - pow(1.0 - u, 2.5))
		mi.global_position = at + fw * u * 1.2
		m.set_shader_parameter(&"life", u), 0.0, 1.0, 0.53)
	tw.tween_callback(mi.queue_free)

const SCREAM_AIR := "res://assets/fx/scream_air.gdshader"


## Steam rising off its back and head from now on.
func _steam() -> void:
	if _skeleton == null:
		return
	for bone: String in ["chest_joint", "L_shoulder_joint", "R_shoulder_joint", "head_joint"]:
		if _skeleton.find_bone(bone) < 0:
			continue
		var at := BoneAttachment3D.new()
		at.bone_name = bone
		_skeleton.add_child(at)
		var p := _particles(Color(0.75, 0.72, 0.72, 0.2), 14, 1.3, 0.28, Vector3(0, 1.2, 0))
		var pm := p.process_material as ParticleProcessMaterial
		pm.direction = Vector3.UP
		pm.spread = 20.0
		pm.initial_velocity_min = 0.2
		pm.initial_velocity_max = 0.5
		pm.scale_min = 0.5
		pm.scale_max = 1.6
		var grow := Curve.new()
		grow.add_point(Vector2(0, 0.4))
		grow.add_point(Vector2(1, 1.6))
		var ct := CurveTexture.new()
		ct.curve = grow
		pm.scale_curve = ct
		p.emitting = true
		at.add_child(p)


func _glow_on() -> void:
	if body == null:
		return
	_glow = StandardMaterial3D.new()
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.albedo_color = Color(frenzy_glow, 0.22)
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = _glow
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = frenzy_glow
	_glow_light.light_energy = 0.9
	_glow_light.omni_range = 2.2
	_glow_light.shadow_enabled = false
	add_child(_glow_light)
	_glow_light.position = Vector3.UP * 1.4 * visual_scale


## In its frenzy a blow no longer throws it about, nor do fire and poison
## make it flinch (they still burn and eat at it).
func react(kind: StringName, from: Node3D = null, push: Vector3 = Vector3.ZERO) -> void:
	if frenzied and (kind == &"knock" or kind == &"burn" or kind == &"poison"):
		if from != null and is_instance_valid(from) and _decides():
			_rouse(from)
		return
	if act in [PIN, LIE, SPRING, THROWN, UP]:
		return
	super(kind, from, push)


func _process(delta: float) -> void:
	super(delta)
	_feign_look()
	_pounce_look(delta)
	_twitching(delta)
	if _glow != null:
		var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 7.0)
		_glow.albedo_color.a = 0.14 + 0.14 * beat
		if _glow_light != null:
			_glow_light.light_energy = 0.6 + 0.6 * beat
		if is_dead:
			_glow.albedo_color.a = 0.0
			_glow_light.light_energy = 0.0
	if act == FEED and not is_dead:
		_feed_blood -= delta
		if _feed_blood <= 0.0:
			_feed_blood = 0.7
			Blood.spill(Blood.world_of(self), _head_point(), Vector3.UP * 0.6 + _forward() * 0.3, null, 0.35)

var _feed_blood: float = 0.5
#endregion


#region Death
## Every peer: down on its back; then it twitches a while and lies still, a
## pool of venom spreading under it.
func _lie_down() -> void:
	super()
	_set_eyes(Color.BLACK, 0.0)
	var held: Array[Node] = _skeleton.get_children() if _skeleton != null else []
	for at in held:
		for p in at.get_children():
			if p is GPUParticles3D:
				(p as GPUParticles3D).emitting = false
			elif p is OmniLight3D:
				(p as OmniLight3D).visible = false
	_twitch_at = 0.0


func _twitching(delta: float) -> void:
	if _twitch_at < 0.0 or _skeleton == null:
		return
	var was := _twitch_at
	_twitch_at += delta
	if was < twitch_after and _twitch_at >= twitch_after:
		var at := global_position
		var i := _skeleton.find_bone("pelvis_joint")
		if i >= 0:
			at = _skeleton.global_transform * _skeleton.get_bone_global_pose(i).origin
		at.y = global_position.y + 0.02
		if venomous:
			Venom.pool(Blood.world_of(self), at, death_pool, corpse_linger)
	if _twitch_at < twitch_after or _twitch_at > twitch_after + twitch_time:
		return
	var fade := pow(1.0 - (_twitch_at - twitch_after) / twitch_time, 1.6)
	for b: String in ["L_elbow_joint", "R_elbow_joint", "L_wrist_joint", "R_wrist_joint", "L_knee_joint",
			"R_knee_joint", "head_joint", "L_ankle_joint", "R_ankle_joint", "chest_joint"]:
		var idx := _skeleton.find_bone(b)
		if idx < 0:
			continue
		if _rng.randf() < 0.18 * fade + 0.01:
			_twitch_kick[idx] = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1),
					_rng.randf_range(-1, 1)) * 0.5 * fade
		if not _twitch_base.has(idx):
			_twitch_base[idx] = _skeleton.get_bone_pose_rotation(idx)
		var v: Vector3 = _twitch_kick.get(idx, Vector3.ZERO)
		_twitch_kick[idx] = v * 0.7
		var base: Quaternion = _twitch_base[idx]
		_skeleton.set_bone_pose_rotation(idx, base * Quaternion.from_euler(v))
#endregion


#region Feeding
## Off to a corpse when it is hurt and nothing presses it; true while it goes.
## A corpse another ghoul is eating: it quarrels with it for it.
func _go_feed(delta: float) -> bool:
	# Left alone it feeds whenever it finds one; roused, only when it is hurt.
	if mode != Mode.GUARD and (health >= max_health * 0.98 or frenzied):
		return false
	if _disturbed():
		_corpse = null
		return false
	if _corpse == null or not is_instance_valid(_corpse) or not _edible(_corpse):
		_corpse = _nearest_corpse()
		_fed_for = 0.0
	if _corpse == null:
		return false
	var to := _corpse.global_position - global_position
	to.y = 0.0
	if to.length() > 0.95 * maxf(visual_scale, 0.5):
		var eater := _eater_of(_corpse)
		if eater != null and to.length() < 2.4:
			# another is at it: a hiss at it, and a quarrel
			_rival = eater
			_face(eater.global_position - global_position, 1.0, 50.0)
			velocity.x = 0.0
			velocity.z = 0.0
			_begin(HISS)
			eater._quarrel_with(self)
			return true
		_move_towards(_corpse.global_position, chase_speed * 0.8 if mode != Mode.GUARD else speed * 1.6, delta)
		_hold_corpse(4.0)
		return true
	_face(to, 1.0, 30.0)
	velocity.x = 0.0
	velocity.z = 0.0
	_begin(FEED)
	_hold_corpse(feed_most - _fed_for + 2.0)
	return true


## The ghoul eating `corpse` now, if one is.
func _eater_of(corpse: Node3D) -> GhoulFighter:
	for node in get_tree().get_nodes_in_group(&"ghouls"):
		var g := node as GhoulFighter
		if g != null and g != self and not g.is_dead and g.act == FEED and g._corpse == corpse:
			return g
	return null


## Host: up off its meal at the one that came hissing for it: it rears up
## and waits for the claw.
func _quarrel_with(other: GhoulFighter) -> void:
	_rival = other
	_answer_due = false
	_face(other.global_position - global_position, 1.0, 50.0)
	_begin(ALERT)


## The moment the quarrel's claw lands (act seconds).
func _quarrel_moment() -> float:
	return 0.63 if act == QUARREL_A else 0.43


## Host: its claw on its rival: the rival reels, bleeds, and answers.
func _claw_rival() -> void:
	var r := _rival
	if r == null or not is_instance_valid(r) or r.is_dead:
		return
	r.health = maxf(r.health - hit_damage * 0.4, 1.0)
	r.net_bleed.rpc(r._head_point(), (r.global_position - global_position).normalized() + Vector3.UP * 0.4)
	r._rival = self
	r._quarrel_hit = false
	r._answer_due = act == QUARREL_A
	r._begin(STUMBLE)

var _answer_due: bool = false


## Host, a quarrel's move done: the claw answered, or the weaker gives way.
func _end_quarrel(what: int) -> void:
	var r := _rival
	if r == null or not is_instance_valid(r) or r.is_dead:
		_rival = null
		_start(Act.NONE)
		return
	if what == STUMBLE and _answer_due:
		# reeled from its claw: the claw back
		_answer_due = false
		_face(r.global_position - global_position, 1.0, 50.0)
		_quarrel_hit = false
		_begin(QUARREL_B)
		return
	if what == STUMBLE or what == ALERT:
		# up off the corpse, waiting for the claw that is coming
		_start(Act.NONE)
		return
	if what == QUARREL_B or what == QUARREL_A:
		if what == QUARREL_B:
			# both have clawed: the weaker gives way, the other eats
			var loser: GhoulFighter = self if health < r.health else r
			var winner: GhoulFighter = r if loser == self else self
			loser._shunned = loser._corpse if loser._corpse != null else winner._corpse
			loser._shun_left = 10.0
			loser._corpse = null
			loser._rival = null
			winner._rival = null
			if loser == self:
				_dart_left = dart_time.y * 1.5
				_dart_side = 1.0 if _rng.randf() < 0.5 else -1.0
		_start(Act.NONE)


## He has come too close to keep at it (and roused it, if it was not).
func _disturbed() -> bool:
	var q := _pick_quarry()
	if q == null:
		return false
	var meal := _at_meal()
	var near := feed_while_far if not meal else feed_while_far * 0.55
	if mode == Mode.GUARD:
		near = minf(sight_range * 0.6, near)
	# bent over its meal it does not see behind it: he can come up at its
	# back for the critical
	if meal:
		var to := q.global_position - global_position
		to.y = 0.0
		if to.length_squared() > 0.0001 and _forward().dot(to.normalized()) < -0.2:
			near = feed_unseen
	if _distance_to(q) >= near:
		return false
	_rouse(q)
	return true


## At its meal: eating, or over the corpse between mouthfuls.
func _at_meal() -> bool:
	if act == FEED:
		return true
	return act == Act.NONE and _corpse != null and is_instance_valid(_corpse) \
			and _corpse.global_position.distance_to(global_position) < 1.4


func _nearest_corpse() -> Node3D:
	var best: Node3D = null
	var near := feed_range
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var f := node as Node3D
		if f == null or f == self or not _edible(f):
			continue
		if f == _shunned and _shun_left > 0.0:
			continue
		var d := f.global_position.distance_to(global_position)
		if d < near:
			near = d
			best = f
	return best


## A body lying whole, not yet sinking away: not a skeleton's bones, not a
## golem's stone.
func _edible(f: Node3D) -> bool:
	if not bool(f.get("is_dead")) or f.has_meta(&"eaten"):
		return false
	if bool(f.get("shatter_on_death")) or not Blood.bleeds(f):
		return false
	var age := float(f.get("_corpse_age"))
	var linger := float(f.get("corpse_linger"))
	return age < linger - 0.3


## Keeps the corpse from sinking for `seconds` more, on every peer.
func _hold_corpse(seconds: float) -> void:
	if _corpse == null or not _decides():
		return
	var age := float(_corpse.get("_corpse_age"))
	if float(_corpse.get("corpse_linger")) - age >= seconds:
		return
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_hold_corpse.rpc(_corpse.get_path(), seconds)
	else:
		net_hold_corpse(_corpse.get_path(), seconds)


@rpc("authority", "call_local", "reliable")
func net_hold_corpse(path: NodePath, seconds: float) -> void:
	var c := get_node_or_null(path)
	if c != null and "corpse_linger" in c:
		c.set("corpse_linger", float(c.get("_corpse_age")) + seconds)


## Bent over it, eating: whole again bit by bit, until it is full, the meal
## is done or he comes close.
func _feeding(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * 6.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * 6.0 * delta)
	_fed_for += delta
	health = minf(health + max_health * feed_heal * delta, max_health)
	var done := _corpse == null or not is_instance_valid(_corpse) or _fed_for >= feed_most \
			or (mode != Mode.GUARD and health >= max_health)
	if done and _corpse != null and is_instance_valid(_corpse) and _fed_for >= feed_most:
		# Picked clean.
		_corpse.set_meta(&"eaten", true)
	if done or _disturbed():
		_start(Act.NONE)
		_corpse = null
#endregion


## Struck: off him if it was on another; up if it lay as dead; a critical
## from behind while it eats or quarrels; up off its meal at him.
func _receive(damage: float, at: Vector3, blow: Vector3, from: Node3D, magic: bool = false) -> bool:
	var was := act
	if was == LIE:
		_feigning = false
	if from != null and (was in DISTRACTED or _at_meal()):
		var to := from.global_position - global_position
		to.y = 0.0
		if to.length_squared() > 0.0001 and _forward().dot(to.normalized()) < -0.2:
			damage *= crit_mult
			if _decides():
				net_crit.rpc(at, blow)
	var bled := super(damage, at, blow, from, magic)
	if is_dead or not _decides():
		return bled
	match was:
		FEED:
			# Disturbed at its meal: up off it, at him.
			_corpse = null
			_start(Act.NONE)
			_leap_wait = 0.0
			if from != null:
				_rouse(from)
				_face(from.global_position - global_position, 1.0, 50.0)
		LIE:
			if from != null:
				_quarry = from
				_face(from.global_position - global_position, 1.0, 50.0)
			_begin(SPRING)
		PIN:
			# a friend's blow knocks it off the one it is on
			if from != null and from != _pinned:
				var who := _pinned
				_pinned = null
				if who != null and is_instance_valid(who):
					remove_collision_exception_with(who as PhysicsBody3D)
					_send_pin(who, false)
				_thrown_off(from, 0.0)
	return bled


## Every peer: a critical on it from behind: a deep spray of blood.
@rpc("authority", "call_local", "unreliable")
func net_crit(at: Vector3, blow: Vector3) -> void:
	var into := Blood.world_of(self)
	Blood.spill(into, at, blow if blow.length_squared() > 0.0001 else Vector3.UP, null, 2.0)
	ImpactFx.strike(self, at, &"flesh")


#region Bits
func _particles(colour: Color, amount: int, life: float, size: float, gravity: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.gravity = gravity
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = fade
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = SkillFx.dot()
	m.albedo_color = colour
	q.material = m
	p.draw_pass_1 = q
	return p
#endregion
