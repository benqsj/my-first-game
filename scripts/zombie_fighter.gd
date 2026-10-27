class_name ZombieFighter
extends Brawler

## The walking dead: Polysplit's two zombies (CREATURES_PACK.md). Their own
## moves since 2026-10-27, the user's picks from the films (project doc
## claude/zombie_plan.md; the clips CR_ZB_* and some of the ghoul's CR_GH_*,
## Mixamo's, in tools/creature_clips.gd):
##
## * **Six gaits, each its own.** Two walks, a creeping walk, a limp and two
##   runs; each zombie takes one at random at its own pace (`gait`, every peer
##   plays what the host picked) and changes it now and then on the way
##   (`gait_change`), a third of the time to a run (`run_share`).
## * **Its blows.** Both hands brought down from above, and the right hand
##   swung (`attacks`); a cut makes it flinch (`CR_GH_Flinch`).
## * **The grab.** Coming at him slowly, at `grab_from` its hands go a cold
##   blue (`TELL`, the tell, every peer: [method _hands]), then it rushes him
##   (`LUNGE`) and takes him by the shoulders where he stands (`HOLD`): its
##   teeth at his neck (`bite_every`) until he works free (E pressed fast:
##   [method Player.net_seized]; he drives his hilt into it and it reels back,
##   `SHOVED`), a friend strikes it, or `hold_most` runs out. Blocked or
##   dodged, it stumbles on past (`MISS`).
## * **Its legs cut.** A blow when it is low (`legs_below`, `legs_chance`,
##   once) takes its legs: it falls on its face and comes on crawling
##   (`legless`, every peer), biting at his feet; low, a blow on it now goes
##   deep (`crawl_wound`).
## * **Not dead the first time, and up three ways.** Cut down, it may
##   (`getup_chance`, once) only fall: on its face, onto its back or
##   stumbling to its side, and gets up again the way it fell (from its belly,
##   its back, its side) with `getup_health` of its health. Struck while it
##   lies, it is dead for good. Its last fall is one of the three as well (by
##   its name, the same on every peer).
## * **Out of the ground.** It lies under the earth (`buried`: not seen, not
##   in anyone's way) until a hero comes within `wake_range`, then breaks out
##   of it: a hand first, the earth thrown up, and it drags itself up out of
##   the ground (`EMERGE`, every peer). Roused, it rouses the dead round it
##   (`call_range`), those still under the earth coming up in waves, the
##   nearest first.
## * **The woman's scream** (`screamer`, the woman). Roused with him still
##   off, she screams (`SCREAM`, the air breaking from her mouth): the dead
##   under the earth within `scream_range` come up in waves, and those already
##   up round her break into a run (`haste_time`).
## * **At a corpse.** Not yet roused, it goes to a corpse near it, kneels
##   and eats (`KNEEL`, `EAT`); he comes within `feast_notice` (or strikes it)
##   and it gets up off it at him.

@export_group("The dead")
@export var buried: bool = true
@export var wake_range: float = 8.0
@export var call_range: float = 14.0
## Coming up in waves: this long a metre off the one that called.
@export var wave_delay: float = 0.11
@export_range(0.0, 1.0) var getup_chance: float = 0.5
@export var getup_after: float = 2.0
@export_range(0.0, 1.0) var getup_health: float = 0.35

@export_group("Gaits")
@export var gaits: PackedStringArray = PackedStringArray(["CR_ZB_Walk1", "CR_ZB_Walk2", "CR_ZB_Creep",
		"CR_ZB_Limp", "CR_ZB_Run1", "CR_ZB_Run2"])
## The first `walk_gaits` of them are walks, the rest runs.
@export var walk_gaits: int = 4
## A walk's pace: its clip's own over the ground, times one of these.
@export var walk_pace: Vector2 = Vector2(1.15, 1.55)
@export var run_pace: Vector2 = Vector2(2.7, 3.2)
@export_range(0.0, 1.0) var run_share: float = 0.33
@export var gait_change: Vector2 = Vector2(5.0, 11.0)

@export_group("The grab")
@export var grab_from: float = 4.4
@export var grab_near: float = 1.9
@export var grab_cooldown: Vector2 = Vector2(6.0, 11.0)
@export var tell_time: float = 0.55
@export var lunge_time: float = 0.5
## Where it stands to him while it holds him (its root off his).
@export var hold_gap: float = 0.62
@export var hold_most: float = 6.0
@export var bite_every: float = 0.75
## A bite's share of `hit_damage`.
@export var bite_share: float = 0.35
## Shoved off by his hilt: its share of `hit_damage` taken.
@export var shoved_share: float = 0.6
@export var hands_colour: Color = Color(0.35, 0.6, 1.0)

@export_group("Legs cut")
@export_range(0.0, 1.0) var legs_below: float = 0.5
@export_range(0.0, 1.0) var legs_chance: float = 0.35
@export var crawl_clip: StringName = &"CR_ZB_Crawl"
@export var crawl_speed: float = 0.6
## A blow on it crawling goes this many times as deep.
@export var crawl_wound: float = 2.5

@export_group("The scream")
@export var screamer: bool = false
@export var scream_range: float = 24.0
@export var scream_off: float = 4.5
@export var haste_time: float = 8.0
@export var scream_bursts: PackedFloat32Array = PackedFloat32Array([1.25, 1.5, 1.75])

@export_group("At a corpse")
@export var feed_range: float = 12.0
@export var feast_notice: float = 5.5

const DOWN := 92
const LIE := 93
const GETUP := 94
const DOWN_B := 150
const LIE_B := 151
const GETUP_B := 152
const DOWN_C := 153
const LIE_C := 154
const GETUP_C := 155
const TELL := 156
const LUNGE := 157
const HOLD := 158
const SHOVED := 159
const MISS := 160
const LEGS := 161
const CRAWL_BITE := 162
const SCREAM := 163
const KNEEL := 164
const EAT := 165
const RISE_EAT := 166
const EMERGE := 167
## The three falls: [fall, lie, get up], and their clips.
const FALLS := [[DOWN, LIE, GETUP], [DOWN_B, LIE_B, GETUP_B], [DOWN_C, LIE_C, GETUP_C]]
const FALL_CLIPS := [[&"CR_ZB_FallFwd", &"CR_ZB_UpStomach"], [&"CR_GH_Thrown", &"CR_GH_UpBack"],
		[&"CR_ZB_StumbleFall", &"CR_ZB_UpSide"]]
## Acts in which a blow does not throw it about.
const STEADY := [DOWN, LIE, GETUP, DOWN_B, LIE_B, GETUP_B, DOWN_C, LIE_C, GETUP_C, LUNGE, HOLD, LEGS,
		SCREAM, EMERGE, KNEEL, EAT, RISE_EAT]
const HOLD_CLIP := &"CR_ZB_NeckBite"
const SCREAM_AIR := "res://assets/fx/scream_air.gdshader"

## Replicated: still under the ground.
var under: bool = false
## Replicated: the gait it goes in (an index into `gaits`).
var gait: int = -1
## Replicated: its legs cut, crawling.
var legless: bool = false

var _shown_under: bool = false
var _shown_gait: int = -2
var _shown_legless: bool = false
var _got_up: bool = false
var _layer: int = 0
var _gait_left: float = 0.0
var _haste_left: float = 0.0
var _grab_wait: float = 0.0
var _lunge_speed: float = 0.0
var _seized: Node3D = null
var _hold_left: float = 0.0
var _bite_in: float = 0.0
var _legs_tried: bool = false
var _screamed: bool = false
var _scream_due: bool = false
var _wake_in: float = -1.0
var _wake_by: Node3D = null
var _corpse: Node3D = null
var _eat_for: float = 0.0
var _hands_glow: float = 0.0
var _hand_parts: Array = []
var _sink_shown: bool = false


func _ready() -> void:
	super()
	add_to_group(&"the_dead")
	_layer = collision_layer
	var clip_len := func(clip: StringName, fallback: float) -> float:
		return _anim.clip_length(clip) if _anim != null and _anim.has_clip(clip) else fallback
	for i in 3:
		var f: Array = FALLS[i]
		var c: Array = FALL_CLIPS[i]
		_moves_table[f[0]] = [c[0], 1.0, 0.0, 1.0]
		# Held on the fall's last frame for `getup_after`.
		var length: float = clip_len.call(c[0], 3.0)
		_moves_table[f[1]] = [c[0], 0.02 * length / maxf(getup_after, 0.1), 0.98, 1.0]
		_moves_table[f[2]] = [c[1], 1.25, 0.0, 1.0]
	var walk_len: float = clip_len.call(&"CR_ZB_Walk1", 4.0)
	var run_len: float = clip_len.call(&"CR_ZB_Run1", 0.8)
	_moves_table[TELL] = [&"CR_ZB_Walk1", 1.3, 0.0, minf(tell_time * 1.3 / walk_len, 1.0)]
	_moves_table[LUNGE] = [&"CR_ZB_Run1", 1.6, 0.0, minf(lunge_time * 1.6 / run_len, 1.0)]
	var bite_len: float = clip_len.call(HOLD_CLIP, 4.2)
	_moves_table[HOLD] = [HOLD_CLIP, 0.9, 1.7 / bite_len, 2.85 / bite_len]
	_moves_table[SHOVED] = [&"CR_GH_Stumble", 1.2, 0.0, 1.0]
	_moves_table[MISS] = [&"CR_GH_Flinch", 1.2, 0.2, 0.75]
	_moves_table[LEGS] = [&"CR_ZB_FallFwd", 1.1, 0.08, 1.0]
	_moves_table[CRAWL_BITE] = [&"CR_GH_Pin", 1.3, 0.0, 1.0]
	_own_limb(CRAWL_BITE, "head_joint>head_joint@0.1,0.12,0:0.3")
	_moment_at_reach(CRAWL_BITE)
	# (numbered past BIG_BASE, which would count it a felling blow)
	var bite_st: Array = _strikes_table[CRAWL_BITE]
	bite_st[3] = maxi(blows_to_fell, 1)
	_moves_table[SCREAM] = [&"CR_GH_Scream", 1.0, 0.0, 1.0]
	var kneel_len: float = clip_len.call(&"CR_ZB_KneelBite", 6.93)
	_moves_table[KNEEL] = [&"CR_ZB_KneelBite", 1.0, 0.0, 1.9 / kneel_len]
	_moves_table[EAT] = [&"CR_GH_Pin", 1.0, 0.0, 1.0]
	_moves_table[RISE_EAT] = [&"CR_ZB_KneelBite", 1.25, 4.7 / kneel_len, 1.0]
	var up_len: float = clip_len.call(&"CR_ZB_UpStomach", 6.0)
	_moves_table[EMERGE] = [&"CR_ZB_UpStomach", 1.15, 2.2 / up_len, 1.0]
	# its blows of its own, as many as fell him as its old scratch
	for i in attacks.size():
		if _strikes_table.has(ATTACK_BASE + i):
			var st: Array = _strikes_table[ATTACK_BASE + i]
			st[3] = maxi(blows_to_fell, 1)
	# a cut makes it flinch
	reacts[Act.REACT_KNOCK] = [[&"CR_GH_Flinch", 1.3, 0.5]]
	# its last fall: one of the three, by its name (the same on every peer)
	death_clip = FALL_CLIPS[absi(String(name).hash()) % 3][0]
	under = buried
	_show_under()
	_hands()
	if _decides():
		_grab_wait = _rng.randf_range(1.0, grab_cooldown.y)
		_pick_gait(false)


#region Under the ground, and up out of it
func _show_under() -> void:
	_shown_under = under
	# Under the ground there is nothing to lock on to.
	if under:
		remove_from_group(&"enemy")
	elif not is_in_group(&"enemy"):
		add_to_group(&"enemy")
	if body != null:
		body.visible = not under
	collision_layer = 0 if under else _layer
	if _health_bar != null:
		_health_bar.visible = not under
	if _stamina_bar != null:
		_stamina_bar.visible = not under


## Host: out of the ground, after `who`.
func _climb_out(who: Node3D) -> void:
	_wake_in = -1.0
	under = false
	_show_under()
	_begin(EMERGE)
	if who != null:
		_rouse(who)


## Host: up out of the ground in `delay` s (the wave a scream or a call sends).
func _wake_after(delay: float, who: Node3D) -> void:
	if not under or (_wake_in >= 0.0 and _wake_in <= delay):
		return
	_wake_in = delay
	_wake_by = who


## Every peer, breaking out: a hand first out of the earth, the earth thrown
## up, and it drags itself up out of it (its body raised out of the floor).
func _emerge_look() -> void:
	if body == null:
		return
	if act != EMERGE or is_dead or under:
		if _sink_shown:
			_sink_shown = false
			body.position.y = _body_rest_y
		return
	_sink_shown = true
	var t := _act_time
	var s := maxf(visual_scale, 0.01)
	var sink := 0.0
	if t < 0.35:
		sink = lerpf(-1.7, -1.1, t / 0.35)
	elif t < 0.6:
		sink = -1.1
	else:
		sink = lerpf(-1.1, 0.0, smoothstep(0.0, 1.0, (t - 0.6) / 1.0))
	body.position.y = _body_rest_y + sink * s


func _earth(size: float) -> void:
	var into := Blood.world_of(self)
	if into == null or is_dead:
		return
	GroundFx.eruption(into, global_position, size, false)
	var dust := _particles(Color(0.42, 0.36, 0.28, 0.7), int(36 * size), 1.5, 0.5 * size, Vector3(0, -0.5, 0))
	var pm := dust.process_material as ParticleProcessMaterial
	pm.direction = Vector3.UP
	pm.spread = 55.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 2.0 * size
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.35
	dust.one_shot = true
	dust.explosiveness = 0.85
	into.add_child(dust)
	dust.global_position = global_position + Vector3.UP * 0.1
	dust.emitting = true
	dust.finished.connect(dust.queue_free)
#endregion


#region Gaits
## Host: a gait at random, its pace with it; the woman's scream sends the
## ones round her into a run (`haste`).
func _pick_gait(haste: bool) -> void:
	var runs := gaits.size() - walk_gaits
	var run := haste or (runs > 0 and _rng.randf() < run_share)
	if run and runs > 0:
		gait = walk_gaits + _rng.randi() % runs
	else:
		gait = _rng.randi() % maxi(walk_gaits, 1)
	_gait_left = _rng.randf_range(gait_change.x, gait_change.y)
	_apply_gait()
	if run:
		chase_speed = _rng.randf_range(run_pace.x, run_pace.y)
	else:
		var ground := 0.6
		if _anim != null and _anim.has_clip(walk_clip):
			ground = maxf(_anim.measure_ground_speed(walk_clip) * maxf(visual_scale, 0.01), 0.25)
		chase_speed = ground * _rng.randf_range(walk_pace.x, walk_pace.y)
	speed = minf(chase_speed, 0.9)
	close_speed = maxf(chase_speed, 1.2)
	if legless:
		chase_speed = crawl_speed
		speed = crawl_speed
		close_speed = crawl_speed


## Every peer: the gait's clips (or the crawl).
func _apply_gait() -> void:
	_shown_gait = gait
	_shown_legless = legless
	if legless:
		walk_clip = crawl_clip
		run_clip = crawl_clip
		return
	if gait < 0 or gait >= gaits.size():
		return
	walk_clip = StringName(gaits[gait])
	run_clip = walk_clip
	roused_walk_clip = &""


## Crawling: the crawl at its pace, or all but still.
func _play_locomotion(delta: float) -> void:
	if not legless or _anim == null:
		super(delta)
		return
	var pace := Vector3(velocity.x, 0.0, velocity.z).length()
	var rate := gait_rate(crawl_clip, pace) if pace > 0.08 else 0.15
	_anim.play(crawl_clip, 0.25, rate)
#endregion


func _process(delta: float) -> void:
	super(delta)
	if _shown_under != under:
		_show_under()
	if _shown_gait != gait or _shown_legless != legless:
		_apply_gait()
	_emerge_look()
	_glow_hands(delta)


func _think(delta: float) -> void:
	_grab_wait = maxf(_grab_wait - delta, 0.0)
	if under:
		if not _decides():
			return
		if _wake_in >= 0.0:
			_wake_in -= delta
			if _wake_in <= 0.0:
				_climb_out(_wake_by if _wake_by != null and is_instance_valid(_wake_by) else _pick_quarry())
			return
		var near := _pick_quarry()
		if near != null and _distance_to(near) < wake_range:
			# Set to wait for his blow (the arena's rule, its sight put away):
			# it climbs out and stands there until he strikes it.
			_climb_out(near if sight_range > 0.0 else null)
		return
	if is_dead:
		super(delta)
		return
	if act == HOLD:
		_holding(delta)
		return
	if act == KNEEL or act == EAT:
		_eating(delta)
		return
	if act in STEADY or act in [TELL, SHOVED, MISS, CRAWL_BITE]:
		return
	if act != Act.NONE:
		super(delta)
		return
	# now and then another gait (the scream's run holds its time)
	_haste_left = maxf(_haste_left - delta, 0.0)
	_gait_left -= delta
	if _gait_left <= 0.0 and _haste_left <= 0.0 and not legless:
		_pick_gait(false)
	if _scream_due:
		_scream_due = false
		var q := _pick_quarry()
		if q != null and _distance_to(q) > scream_off:
			_face(q.global_position - global_position, 1.0, 50.0)
			velocity.x = 0.0
			velocity.z = 0.0
			_screamed = true
			_begin(SCREAM)
			return
	if mode == Mode.GUARD and not legless and _go_eat(delta):
		return
	if (mode == Mode.CHASE or mode == Mode.FIGHT) and not legless and _try_tell():
		return
	super(delta)


## A string of its own: one of its blows, or crawling, its bite at his feet.
func _begin_attack() -> void:
	if not legless:
		super()
		return
	if _quarry == null or _quarry_down():
		_cooldown = maxf(_cooldown, 0.15)
		return
	if _distance_to(_quarry) > 1.5:
		_move_towards(_quarry.global_position, crawl_speed, get_physics_process_delta_time())
		return
	_face(_quarry.global_position - global_position, 1.0, 50.0)
	_begin(CRAWL_BITE)


func _extra_velocity(delta: float) -> Vector3:
	match act:
		TELL:
			return _forward() * 0.45
		LUNGE:
			return _forward() * _lunge_speed
		HOLD, KNEEL, EAT, SCREAM, EMERGE, MISS:
			return Vector3.ZERO
	return super(delta)


func _after(what: int) -> void:
	for f: Array in FALLS:
		if what == f[0]:
			_begin(f[1])
			return
		if what == f[1]:
			_begin(f[2])
			return
		if what == f[2]:
			health = maxf(health, max_health * getup_health)
			_start(Act.NONE)
			return
	match what:
		TELL:
			_lunge()
			return
		LUNGE:
			_land_lunge()
			return
		HOLD:
			if _seized != null:
				_begin(HOLD)
				return
		KNEEL, EAT:
			_begin(EAT)
			return
		RISE_EAT:
			_corpse = null
			_start(Act.NONE)
			return
		SCREAM:
			_screamed = true
			_call_the_dead(scream_range, true)
	super(what)


#region The grab
## Host: within `grab_from` of him, standing, nobody else holding him: its
## hands go blue (the tell), and then the rush.
func _try_tell() -> bool:
	if _grab_wait > 0.0 or _quarry == null or not (_quarry is Player) or _quarry_down():
		return false
	var gap := _distance_to(_quarry)
	if gap > grab_from or gap < grab_near:
		return false
	if _held_by_other(_quarry):
		return false
	_face(_quarry.global_position - global_position, 1.0, 50.0)
	_begin(TELL)
	return true


func _held_by_other(who: Node3D) -> bool:
	for node in get_tree().get_nodes_in_group(&"the_dead"):
		var other := node as ZombieFighter
		if other != null and other != self and other._seized == who:
			return true
	return false


## Host: the rush, timed to end at his shoulders.
func _lunge() -> void:
	var q := _pick_quarry()
	if q == null or _quarry_down():
		_grab_wait = grab_cooldown.x
		_start(Act.NONE)
		return
	_quarry = q
	var to := q.global_position - global_position
	to.y = 0.0
	_face(to, 1.0, 50.0)
	_begin(LUNGE)
	_lunge_speed = maxf(to.length() - hold_gap, 0.0) / maxf(_act_length, 0.2)


## Host: at the end of the rush: his shoulders in its hands, or it stumbles
## on past (he blocked it facing it, or rolled out of it).
func _land_lunge() -> void:
	_grab_wait = _rng.randf_range(grab_cooldown.x, grab_cooldown.y)
	var q := _quarry
	if q == null or not is_instance_valid(q) or not (q is Player) or bool(q.get("is_dead")):
		_begin(MISS)
		return
	var hero := q as Player
	var to := q.global_position - global_position
	to.y = 0.0
	var dodged := hero.untouchable_now(self) or int(hero.get(&"net_state")) in [Player.State.DASHING, Player.State.DODGING]
	var guarded := hero.guarding() and (-to.normalized()).dot(-hero.global_basis.z) > 0.3
	if to.length() > hold_gap + 0.9 or dodged or guarded or _held_by_other(q) or _quarry_down():
		_begin(MISS)
		return
	_seized = q
	_hold_left = hold_most
	_bite_in = bite_every * 0.7
	add_collision_exception_with(q as PhysicsBody3D)
	_begin(HOLD)
	_send_seize(q, true)


func _send_seize(who: Node3D, on: bool) -> void:
	if who == null or not is_instance_valid(who):
		return
	var method := &"net_seized" if on else &"net_unseized"
	if not who.has_method(method):
		return
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		if on:
			who.rpc_id(who.get_multiplayer_authority(), method, get_path())
		else:
			who.rpc_id(who.get_multiplayer_authority(), method)
	elif on:
		who.call(method, get_path())
	else:
		who.call(method)


## Host, each tick holding him: its feet kept `hold_gap` before his, a bite
## at his neck now and then; let go if he is not there in its hands.
func _holding(delta: float) -> void:
	var who := _seized
	if who == null or not is_instance_valid(who) or bool(who.get("is_dead")) \
			or (who is Player and (who as Player).state == Player.State.DOWNED):
		_let_go(null)
		return
	_hold_left -= delta
	var to := global_position - who.global_position
	to.y = 0.0
	if _hold_left <= 0.0 or to.length() > hold_gap + 1.0:
		_let_go(null)
		return
	var want := who.global_position + to.normalized() * hold_gap
	var d := want - global_position
	d.y = 0.0
	var v := (d / maxf(delta, 0.001) * 0.3).limit_length(3.0)
	velocity.x = v.x
	velocity.z = v.z
	_face(-to, delta, turn_speed * 2.0)
	_bite_in -= delta
	if _bite_in > 0.0:
		return
	_bite_in = bite_every
	var dmg := hit_damage * bite_share
	if who.has_method(&"net_seize_bite"):
		if multiplayer.has_multiplayer_peer():
			who.rpc_id(who.get_multiplayer_authority(), &"net_seize_bite", dmg)
		else:
			who.call(&"net_seize_bite", dmg)
	var neck := GhoulFighter._bone_of(who, &"neck_01", who.global_position + Vector3.UP * 1.55)
	net_bite.rpc(neck)


## Every peer: a bite at his neck, blood out of it.
@rpc("authority", "call_local", "unreliable")
func net_bite(at: Vector3) -> void:
	Blood.spill(Blood.world_of(self), at, Vector3(0.0, 0.4, 0.0) - _forward() * 0.5, null, 0.45)


## Host: its hands off him. `by`: struck off (it reels back from `by`).
func _let_go(by: Node3D) -> void:
	var who := _seized
	_seized = null
	if who != null and is_instance_valid(who):
		remove_collision_exception_with(who as PhysicsBody3D)
		_send_seize(who, false)
	if by != null and not is_dead:
		_face(by.global_position - global_position, 1.0, 50.0)
		_begin(SHOVED)
		return
	_start(Act.NONE)


## Host: his hilt in it (he worked free: [method Player._shove_free]): it
## reels back off him, hurt.
@rpc("any_peer", "call_local", "reliable")
func net_shoved(hero: NodePath) -> void:
	if not _decides() or is_dead:
		return
	var who := get_node_or_null(hero) as Node3D
	if who == null or who != _seized:
		return
	_seized = null
	remove_collision_exception_with(who as PhysicsBody3D)
	health = maxf(health - hit_damage * shoved_share, 1.0)
	var away := global_position - who.global_position
	away.y = 0.0
	net_bleed.rpc(_head_point(), away.normalized() + Vector3.UP * 0.4)
	_face(-away, 1.0, 50.0)
	_begin(SHOVED)


## Every peer: its hands, cold blue: up through the tell, full in the rush,
## low while it holds him, out after.
func _hands() -> void:
	if _skeleton == null:
		return
	for bone: String in ["L_midFinger_joint3", "R_midFinger_joint3"]:
		if _skeleton.find_bone(bone) < 0:
			continue
		var at := BoneAttachment3D.new()
		at.bone_name = bone
		_skeleton.add_child(at)
		var l := OmniLight3D.new()
		l.light_color = hands_colour
		l.light_energy = 0.0
		l.omni_range = 1.1
		l.shadow_enabled = false
		l.visible = false
		at.add_child(l)
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.4, 0.4)
		q.mesh = qm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = SkillFx.dot()
		m.albedo_color = Color(hands_colour, 0.0)
		q.material_override = m
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.visible = false
		at.add_child(q)
		var w := _particles(Color(0.45, 0.7, 1.0, 0.8), 22, 0.7, 0.07, Vector3(0, 0.6, 0))
		var pm := w.process_material as ParticleProcessMaterial
		pm.direction = Vector3.UP
		pm.spread = 35.0
		pm.initial_velocity_min = 0.1
		pm.initial_velocity_max = 0.35
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.08
		(w.draw_pass_1.surface_get_material(0) as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		w.emitting = false
		at.add_child(w)
		_hand_parts.append([l, q, m, w])


func _glow_hands(delta: float) -> void:
	if _hand_parts.is_empty():
		return
	var want := 0.0
	if not is_dead and not under:
		match act:
			TELL:
				want = clampf(_act_time / maxf(tell_time * 0.8, 0.05), 0.0, 1.0)
			LUNGE:
				want = 1.0
			HOLD:
				want = 0.35
	_hands_glow = move_toward(_hands_glow, want, delta * (4.0 if want > _hands_glow else 2.0))
	var beat := 0.85 + 0.15 * sin(Time.get_ticks_msec() / 1000.0 * 27.0)
	var g := _hands_glow
	for p: Array in _hand_parts:
		var l := p[0] as OmniLight3D
		var q := p[1] as MeshInstance3D
		var m := p[2] as StandardMaterial3D
		var w := p[3] as GPUParticles3D
		l.visible = g > 0.01
		q.visible = g > 0.01
		l.light_energy = 2.2 * g * beat
		m.albedo_color = Color(hands_colour, 0.85 * g * beat)
		w.emitting = g > 0.15
#endregion


#region The scream
## Host: roused, the woman screams once (with him still off).
func _rouse(who: Node3D) -> void:
	var was := mode
	super(who)
	if under and who != null and not is_dead and _decides() and _wake_in < 0.0:
		_climb_out(who)
	if who == null or not _decides():
		return
	if screamer and not _screamed and not under:
		_scream_due = true
	if was != Mode.GUARD:
		return
	# The horde: the dead round it that are still waiting come too, those
	# under the earth in waves, the nearest first.
	_call_the_dead(call_range, false)


## Host: the dead within `within` roused; those under the earth up in waves,
## and (the scream) those already up round it into a run.
func _call_the_dead(within: float, haste: bool) -> void:
	var who := _quarry if _quarry != null else _pick_quarry()
	if who == null:
		return
	for node in get_tree().get_nodes_in_group(&"the_dead"):
		var other := node as ZombieFighter
		if other == null or other == self or other.is_dead:
			continue
		var d := other.global_position.distance_to(global_position)
		if d > within:
			continue
		if other.under:
			other._wake_after(d * wave_delay + _rng.randf_range(0.0, 0.25), who)
			continue
		if other.mode == Mode.GUARD:
			other._rouse(who)
		if haste and not other.legless:
			other._haste_left = haste_time
			other._pick_gait(true)


## Every peer: the scream's breath, out of its mouth in waves (no ring).
func _scream_fx() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for t in scream_bursts:
		tree.create_timer(t).timeout.connect(_air_burst)


func _air_burst() -> void:
	if is_dead or not is_inside_tree():
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
#endregion


#region At a corpse
## Host, not roused: to a corpse near it, down on its knees over it.
func _go_eat(delta: float) -> bool:
	if _corpse == null or not is_instance_valid(_corpse) or not _edible(_corpse):
		_corpse = _nearest_corpse()
		_eat_for = 0.0
	if _corpse == null:
		return false
	# kept from sinking while it goes to it and eats
	_hold_corpse(20.0)
	var to := _corpse.global_position - global_position
	to.y = 0.0
	if to.length() > 0.9 * maxf(visual_scale, 0.5):
		_move_towards(_corpse.global_position, maxf(speed, 0.6), delta)
		return true
	_face(to, 1.0, 30.0)
	velocity.x = 0.0
	velocity.z = 0.0
	_begin(KNEEL)
	return true


## Host, at its meal: up off it at him when he comes near.
func _eating(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * 6.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * 6.0 * delta)
	_eat_for += delta
	var q := _pick_quarry()
	if mode != Mode.GUARD or (q != null and _distance_to(q) < feast_notice):
		_rise_from_meal(q)


func _rise_from_meal(q: Node3D) -> void:
	if q != null:
		_quarry = q
		_face(q.global_position - global_position, 1.0, 50.0)
		if mode == Mode.GUARD:
			_rouse(q)
	_begin(RISE_EAT)


func _nearest_corpse() -> Node3D:
	var best: Node3D = null
	var near := feed_range
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var f := node as Node3D
		if f == null or f == self or f is ZombieFighter or not _edible(f):
			continue
		var d := f.global_position.distance_to(global_position)
		if d < near:
			near = d
			best = f
	return best


## A body lying whole, not yet sinking away.
func _edible(f: Node3D) -> bool:
	if not bool(f.get("is_dead")) or f.has_meta(&"eaten"):
		return false
	if bool(f.get("shatter_on_death")) or not Blood.bleeds(f):
		return false
	return float(f.get("_corpse_age")) < float(f.get("corpse_linger")) - 0.3


## Keeps the corpse from sinking while it eats, on every peer.
func _hold_corpse(seconds: float) -> void:
	if _corpse == null or not _decides():
		return
	# (sent again only once half of it has gone)
	if float(_corpse.get("corpse_linger")) - float(_corpse.get("_corpse_age")) >= seconds * 0.5:
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
#endregion


## Every peer: the scream's breath, the earth breaking as it comes up, its
## lying death if its legs are gone.
func _play_act() -> void:
	super()
	match act:
		SCREAM:
			_scream_fx()
		EMERGE:
			_earth(0.45)
			var tree := get_tree()
			if tree != null:
				tree.create_timer(0.6).timeout.connect(_earth.bind(1.0))
		Act.DEAD:
			if legless and _anim != null and _anim.has_clip(&"CR_ZB_FallFwd"):
				_anim.play(&"CR_ZB_FallFwd", 0.2, 1.0, 1.0, true)
				_anim.seek(_anim.clip_length(&"CR_ZB_FallFwd") * 0.93)


func _receive(damage: float, at: Vector3, blow: Vector3, from: Node3D, magic: bool = false) -> bool:
	if under:
		return false
	if legless:
		damage *= crawl_wound
	var was := act
	var bled := super(damage, at, blow, from, magic)
	if is_dead or not _decides():
		return bled
	match was:
		HOLD:
			# a friend's blow knocks it off the one it holds
			if from != null and from != _seized:
				_let_go(from)
		KNEEL, EAT:
			_rise_from_meal(from)
	# low enough, a blow takes its legs (once)
	if bled and not legless and not _legs_tried and health <= max_health * legs_below \
			and act != HOLD and not (act in STEADY):
		_legs_tried = true
		if _rng.randf() < legs_chance:
			legless = true
			_apply_gait()
			_pick_gait(false)
			_begin(LEGS)
	return bled


## Cut down, the first time it may only fall, and get up again the way it
## fell.
func _die() -> void:
	if _seized != null:
		_let_go(null)
	if is_dead or _got_up or legless or not _decides() or _rng.randf() >= getup_chance:
		super()
		return
	_got_up = true
	health = 1.0
	velocity = Vector3.ZERO
	_sweeps.clear()
	_begin(FALLS[_rng.randi() % FALLS.size()][0])


func _run_act(delta: float) -> void:
	super(delta)
	for f: Array in FALLS:
		if act == f[1]:
			velocity.x = 0.0
			velocity.z = 0.0


## Its own moves are not dropped for his swings; lying, under the earth,
## it takes what comes.
func _answer_swing(knight: Node3D) -> void:
	if under or act in STEADY:
		return
	super(knight)


## Knocked by a skill: not while it holds him, lies, or comes up.
func react(kind: StringName, from: Node3D = null, push: Vector3 = Vector3.ZERO) -> void:
	if act in STEADY or legless or under:
		if from != null and is_instance_valid(from) and _decides() and not under:
			_rouse(from)
		return
	super(kind, from, push)


func _head_point() -> Vector3:
	if _skeleton != null:
		var i := _skeleton.find_bone("head_joint")
		if i >= 0:
			return _skeleton.global_transform * _skeleton.get_bone_global_pose(i).origin
	return global_position + Vector3.UP * 1.5


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
