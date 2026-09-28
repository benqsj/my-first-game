class_name Fighter
extends Monster

## A Bestiary creature that fights back: the imp and the puglin.
##
## It keeps the [Monster]'s body — the retargeted skeleton, the colourways, the
## wander — and adds a fight on top, all of it out of the same animation
## library the knight's own swings come from:
##
## * **A band and a patch of ground.** Each one belongs to a band (a node group)
##   that holds a camp. It patrols near its own spot until a player comes within
##   `sight_range`, then the whole band turns out. It follows no further than
##   `leash_radius` from the camp; past that it walks home and is made whole
##   again, so a fight cannot be won by dragging it across the map.
## * **Stamina.** Blocking, sidestepping and attacking all cost it. Every cut
##   that lands on the guard costs `block_cost`; when there is none left the
##   guard breaks (`Idle_Shield_Break`) and it stands open for
##   `guard_break_time` — which is the way through a creature that blocks.
## * **Defence against a cut being thrown.** The moment a knight within
##   `react_range` starts a swing at it, it may raise its guard (`Sword_Block`)
##   or throw itself aside (`Sword_Dash`), if it has the stamina for it.
## * **Attack.** `Sword_Heavy_Combo`, with a blow landing wherever the hands are
##   moving fastest in the clip — measured off the clip, not typed in.
##
## **The host decides**, exactly as for the wolf. `health`, `stamina`, `is_dead`,
## `mode` and the current action (`act`, with `act_serial` counting them) are
## replicated; every peer plays the action's clip when the serial moves, so a
## block or a swing is the same move in every window. Blows on a player are sent
## to that player's own peer, which is the one that knows whether its shield was
## up.

signal died
signal hurt(remaining: float)
signal guard_broken

## What the body is doing right now. Replicated, and each new one bumps
## `act_serial`, which is what tells the other peers to play it.
enum Act { NONE, ATTACK, BLOCK, DASH, BREAK, DEAD, REEL, REACT_KNOCK, REACT_BURN, REACT_POISON }
## How it takes the heroes' skills: act -> clips from the animation library
## one after another, each [clip, rate, share of it played].
const REACTS := {
	Act.REACT_KNOCK: [[&"Hit_Knockback", 1.3, 0.85], [&"LayToIdle", 1.5, 1.0]],
	Act.REACT_BURN: [[&"Zombie_Scratch", 1.6, 1.0]],
	Act.REACT_POISON: [[&"Zombie_Idle", 1.2, 0.5]],
}
## The table this one reacts by: [constant REACTS], unless a kind with clips of
## its own sets another in its `_ready()` before calling up.
var reacts: Dictionary = REACTS
## What it is about, which only decides the idle it stands in on other peers.
enum Mode { GUARD, CHASE, FIGHT, RETURN }

#region Exported tuning
@export_group("Territory")
## The band it belongs to. Every member of a band turns out when one of them is
## roused. Left empty it fights alone.
@export var band: StringName = &""
## Middle of the ground the band holds. Zero means "where it was put".
@export var camp_centre: Vector3 = Vector3.ZERO
## How near a player has to come before it notices.
@export var sight_range: float = 13.0
## How far from the camp it will follow before giving up and going home.
@export var leash_radius: float = 26.0
## Speed while going after a player. The patrol speed is `speed`.
@export var chase_speed: float = 3.2
## The walk cycle may be run this much faster than authored while chasing. The
## library has no run, so a chase is a hurried shamble.
@export var chase_retime_max: float = 3.0

@export_group("Health")
@export var max_health: float = 90.0
## What one of the knight's cuts takes off.
@export var sword_damage: float = 25.0
## Height of the bars over its head, before `visual_scale`.
@export var bar_height: float = 1.75
## The body as the blade sees it: an upright capsule, before `visual_scale`.
@export var body_radius: float = 0.4
@export var body_height: float = 1.4
## Extra room the blade is given, so a cut that visibly connects counts.
@export var hit_tolerance: float = 0.3

@export_group("Stamina")
@export var max_stamina: float = 100.0
## Won back per second, once `regen_delay` has passed since it last spent any.
## Slow enough that a guard worn down stays down for a while.
@export var stamina_regen: float = 10.0
@export var regen_delay: float = 1.6
## Spent by every cut caught on the guard. Three, at the default, and the guard
## is gone.
@export var block_cost: float = 34.0
## Spent by a cut that gets through: being hurt winds it too.
@export var hit_cost: float = 12.0
@export var dash_cost: float = 22.0
@export var attack_cost: float = 18.0
## Stands open this long when its guard breaks.
@export var guard_break_time: float = 1.8

@export_group("Defence")
## Physical defence, p.def ([Defence]): what its hide takes off a blow.
@export var p_def: float = 20.0
## Magical defence, m.def ([Defence]): fire, poison, the mage's bolts.
@export var m_def: float = 10.0
## Chance it raises its guard against a swing, when it has the stamina.
@export_range(0.0, 1.0) var block_chance: float = 0.5
## Chance it throws itself aside instead.
@export_range(0.0, 1.0) var dash_chance: float = 0.25
## A swing further off than this is not answered.
@export var react_range: float = 3.4
## How long the guard stays up after a swing is seen or caught.
@export var block_hold: float = 0.9
@export var dash_speed: float = 6.5
## Out of reach while diving aside, in seconds from the start of the dash.
@export var dash_iframes: float = 0.35

@export_group("Attack")
## Close enough to start the combo.
@export var reach: float = 1.8
## What each blow of the combo is worth.
@export var hit_damage: float = 8.0
## Rate the combo is played at: faster swings, less time to answer them.
@export var attack_speed: float = 1.0
## Seconds between one combo and the next, picked between the two.
@export var attack_cooldown: Vector2 = Vector2(1.4, 3.0)

@export_group("Clips")
@export var attack_clip: StringName = &"Sword_Heavy_Combo"
@export var block_clip: StringName = &"Sword_Block"
@export var dash_clip: StringName = &"Sword_Dash"
@export var break_clip: StringName = &"Idle_Shield_Break"
## Ends lying on the ground, so it doubles as the fall.
@export var death_clip: StringName = &"Hit_Knockback"
## Stood in while fighting, instead of the shambling idle.
@export var guard_idle_clip: StringName = &"Idle_Shield"

@export_group("Corpse")
## It has a death of its own to play out (the imp's): the clip runs to its end
## and the body is not tipped over by hand.
@export var dies_by_clip: bool = false
@export var corpse_linger: float = 4.0
@export var corpse_sink_time: float = 1.2
@export var corpse_sink_depth: float = 1.6
#endregion

## Replicated state. See the class notes.
var health: float = 0.0
var stamina: float = 0.0
var mode: int = Mode.GUARD
var act: int = Act.NONE
var act_serial: int = 0
var is_dead: bool = false:
	set(value):
		if is_dead == value:
			return
		is_dead = value
		if is_dead:
			_lie_down()

var _health_bar: HealthBar
var _stamina_bar: HealthBar
var _played_serial: int = -1

## Host only from here down.
var _quarry: Node3D
var _act_time: float = 0.0
var _act_length: float = 0.0
var _cooldown: float = 0.0
var _regen_wait: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO
## The moments in the combo a blow lands, 0 to 1, and how many have gone.
var _blows: PackedFloat32Array = PackedFloat32Array()
var _blows_done: int = 0
## Per attacker, by node name: the last swing answered and the last one taken.
var _seen_swing: Dictionary = {}
var _last_cut: Dictionary = {}
var _corpse_age: float = 0.0
var _cleared: bool = false
## The bones the reel from a parry bends, and how far into it this peer is.
var _reel_bones: Dictionary = {}
## The combo's blows as its fists ([WeaponSweep]), host side.
var _sweeps: Array[WeaponSweep] = []
## How long either side of the moment a hand moves fastest its blow is live.
const BLOW_BEFORE := 0.14
const BLOW_AFTER := 0.1
## A forearm and fist, in metres at scale 1.
const FIST_RADIUS := 0.11
## How far off its fists land (measured: about 1.4 m round it at scale 1),
## and how fast it steps in to bring them there.
@export var fist_reach: float = 1.05
@export var close_speed: float = 3.0
var _reel_clock: float = 0.0
var _reel_settled: bool = false


func _ready() -> void:
	super()
	if camp_centre == Vector3.ZERO:
		camp_centre = _home
	if not band.is_empty():
		add_to_group(band)
	health = max_health
	stamina = max_stamina
	_cooldown = _rng.randf_range(0.5, attack_cooldown.y)

	var s := maxf(visual_scale, 0.01)
	_health_bar = _make_bar(Color(0.72, 0.13, 0.13), Color(0.85, 0.55, 0.1), 0.08)
	_stamina_bar = _make_bar(Color(0.86, 0.74, 0.28), Color(0.55, 0.42, 0.16), 0.045)
	_health_bar.position = Vector3.UP * bar_height * s
	_stamina_bar.position = Vector3.UP * (bar_height * s - 0.1)

	if _skeleton != null:
		_reel_bones = Recoil.bones_of(_skeleton)
	if _anim != null:
		_blows = _anim.measure_peaks(attack_clip, PackedStringArray(["hand_r", "hand_l"]))
		if _blows.is_empty():
			_blows = PackedFloat32Array([0.3, 0.55, 0.8])


func _make_bar(full: Color, low: Color, tall: float) -> HealthBar:
	var bar := HealthBar.new()
	bar.healthy = full
	bar.hurt = low
	bar.height = tall
	bar.width = 0.8
	# Kept out of the body's rotation so it never turns edge-on to the camera.
	bar.top_level = true
	add_child(bar)
	return bar


#region Frame
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if is_dead:
		_slow(delta, 3.0)
		move_and_slide()
		if _corpse_age >= corpse_linger + corpse_sink_time and not _cleared:
			_cleared = true
			net_clear.rpc()
		return

	_act_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_regen_wait = maxf(_regen_wait - delta, 0.0)
	if act != Act.BLOCK and act != Act.BREAK and _regen_wait <= 0.0:
		stamina = minf(stamina + stamina_regen * delta, max_stamina)

	_watch_blades()
	if is_dead:
		return
	_run_act(delta)
	_think(delta)

	StepUp.climb(self, delta, step_height, step_probe)
	move_and_slide()


func _process(delta: float) -> void:
	_drive_flinch(delta)
	var s := maxf(visual_scale, 0.01)
	if not is_dead:
		_health_bar.global_position = global_position + Vector3.UP * bar_height * s
		_stamina_bar.global_position = global_position + Vector3.UP * (bar_height * s - 0.1)
		_health_bar.set_fraction(health / maxf(max_health, 0.001))
		_stamina_bar.set_fraction(stamina / maxf(max_stamina, 0.001))
	else:
		# Every peer counts its own corpse time, so the body sinks in every
		# window and not just the host's.
		_corpse_age += delta
		if not dies_by_clip:
			_topple()
		if _corpse_age > corpse_linger and body != null:
			var sunk := clampf((_corpse_age - corpse_linger) / maxf(corpse_sink_time, 0.001), 0.0, 1.0)
			body.position.y = _body_rest_y + FALL_LIFT * visual_scale - sunk * sunk * corpse_sink_depth

	if _anim == null:
		return
	if act_serial != _played_serial:
		_played_serial = act_serial
		_play_act()
	if act == Act.NONE:
		_play_locomotion(delta)
	elif reacts.has(act):
		_play_react(delta)
	elif act == Act.REEL:
		_reel_clock += delta
		if _reel_clock >= Recoil.REBOUND and not _reel_settled:
			# The blow knocked back, it stands reeling in the guard-broken clip.
			_reel_settled = true
			_anim.play(break_clip, 0.15, 1.2, 1.0, true)
	# Dead, the knock back plays only as far as the blow throwing it back; the
	# fall itself is the body going over (`_topple`).
	if not is_dead or dies_by_clip or _corpse_age < FREEZE_AT:
		_anim.advance(delta)
	if _decides() and not is_dead:
		WeaponSweep.run(_sweeps, _act_time, act_serial, get_tree(), delta)
	WeaponSweep.draw(self, _sweeps)
	if act == Act.REEL and not is_dead and _skeleton != null:
		Recoil.pose(_skeleton, self, _reel_bones, _reel_clock)


## The clip for the action that has just started, on every peer.
func _play_act() -> void:
	match act:
		Act.ATTACK:
			_anim.play(attack_clip, 0.12, attack_speed, 1.0, true)
		Act.BLOCK:
			_anim.play(block_clip, 0.08, 1.2, 1.0, true)
		Act.DASH:
			_anim.play(dash_clip, 0.06, 1.4, 1.0, true)
		Act.BREAK:
			_anim.play(break_clip, 0.08, 1.0, 1.0, true)
		Act.DEAD:
			_anim.play(death_clip, 0.08, 1.0, 1.0, true)
		Act.REEL:
			# The combo that threw the blow, run back the way it came.
			_reel_clock = 0.0
			_reel_settled = false
			_anim.rewind(2.4)
		Act.REACT_KNOCK, Act.REACT_BURN, Act.REACT_POISON:
			_react_clock = 0.0
			_react_seg = -1


## Idle or walking, retimed to the ground like the [Monster]'s — in a fighting
## crouch once it has been roused, shambling while it is only on patrol.
func _play_locomotion(_delta: float) -> void:
	var planar := Vector3(velocity.x, 0.0, velocity.z).length()
	var roused := mode == Mode.CHASE or mode == Mode.FIGHT
	if planar > 0.12:
		var wanted := planar * _cycle / _stride
		var top := chase_retime_max if roused else retime_range.y
		_anim.play(walk_clip, 0.2, clampf(wanted, retime_range.x, top))
	elif roused and _anim.has_clip(guard_idle_clip):
		_anim.play(guard_idle_clip, 0.25, 1.0)
	elif _anim.current_clip() != idle_clip or _anim.clip_progress() >= 1.0:
		_anim.play(idle_clip, 0.3, 1.0)
#endregion


#region Thinking
func _think(delta: float) -> void:
	_quarry = _pick_quarry()
	match mode:
		Mode.GUARD:
			if _quarry != null and _distance_to(_quarry) < sight_range:
				_rouse(_quarry)
			elif act == Act.NONE:
				_wander(delta)
		Mode.CHASE, Mode.FIGHT:
			if _quarry == null:
				_go_home()
			elif act == Act.NONE:
				var gap := _distance_to(_quarry)
				if gap > reach:
					mode = Mode.CHASE
					_move_towards(_quarry.global_position, chase_speed, delta)
				else:
					mode = Mode.FIGHT
					_face(_quarry.global_position - global_position, delta, turn_speed)
					_slow(delta, 2.0)
					if _cooldown <= 0.0 and stamina >= attack_cost:
						_begin_attack()
			elif act == Act.ATTACK or act == Act.BLOCK:
				# Keeps turning into the fight, slower during a swing so the
				# combo cannot be spun round to follow a knight circling it.
				var rate := turn_speed * (0.35 if act == Act.ATTACK else 1.0)
				_face(_quarry.global_position - global_position, delta, rate)
		Mode.RETURN:
			var home := _home - global_position
			home.y = 0.0
			if home.length() < 1.2:
				mode = Mode.GUARD
				health = max_health
				stamina = max_stamina
				_wait = 1.0
			else:
				_move_towards(_home, speed * 1.6, delta)


## The nearest player still inside the band's ground, or the one already being
## fought while they stay there.
func _pick_quarry() -> Node3D:
	var reach2 := leash_radius * leash_radius
	if _quarry != null and is_instance_valid(_quarry) and _quarry.is_inside_tree() \
			and _quarry.global_position.distance_squared_to(camp_centre) < reach2 \
			and not Brute._fallen(_quarry):
		return _quarry
	if mode == Mode.RETURN:
		return null
	var best: Node3D = null
	var closest := INF
	for node in get_tree().get_nodes_in_group("player"):
		var who := node as Node3D
		if who == null or who.global_position.distance_squared_to(camp_centre) >= reach2 \
				or Brute._fallen(who):
			continue
		var gap := global_position.distance_squared_to(who.global_position)
		if gap < closest:
			closest = gap
			best = who
	return best


## Turns it and the rest of its band on `who`.
func _rouse(who: Node3D) -> void:
	if who == null or is_dead:
		return
	_quarry = who
	if mode == Mode.GUARD or mode == Mode.RETURN:
		mode = Mode.CHASE
	if band.is_empty():
		return
	for node in get_tree().get_nodes_in_group(band):
		var mate := node as Fighter
		if mate != null and mate != self and not mate.is_dead and mate.mode == Mode.GUARD:
			mate._quarry = who
			mate.mode = Mode.CHASE


func _go_home() -> void:
	_quarry = null
	mode = Mode.RETURN
	if act == Act.BLOCK:
		_start(Act.NONE)


## The patrol: the [Monster]'s out-and-back beat around its own spot.
func _wander(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		_slow(delta, 1.0)
		return
	var to_target := _target - global_position
	to_target.y = 0.0
	if to_target.length() < 1.0:
		_wait = rest_time + _rng.randf_range(-rest_spread, rest_spread) * 0.5
		_pick_target()
	else:
		_move_towards(_target, speed, delta)


func _move_towards(point: Vector3, pace: float, delta: float) -> void:
	var direction := point - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	direction = direction.normalized()
	_face(direction, delta, turn_speed)
	# Walk where it is looking, not where it is aiming, or a turn reads as a skid.
	var facing := -global_transform.basis.z
	facing.y = 0.0
	var alignment := clampf(facing.normalized().dot(direction), 0.0, 1.0)
	velocity.x = move_toward(velocity.x, direction.x * pace * alignment, acceleration * 2.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * pace * alignment, acceleration * 2.0 * delta)


func _face(direction: Vector3, delta: float, rate: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-rate * delta))


func _slow(delta: float, strength: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * strength * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * strength * delta)


func _distance_to(who: Node3D) -> float:
	var gap := who.global_position - global_position
	gap.y = 0.0
	return gap.length()


func _forward() -> Vector3:
	var ahead := -global_transform.basis.z
	ahead.y = 0.0
	return ahead.normalized()
#endregion


#region Actions
## Starts an action here and, through the serial, everywhere else.
func _start(what: Act) -> void:
	act = what
	act_serial += 1
	_sweeps.clear()
	_act_time = 0.0
	var length := 0.0
	if _anim != null:
		match what:
			Act.ATTACK:
				length = _anim.clip_length(attack_clip) / maxf(attack_speed, 0.05)
			Act.BLOCK:
				length = block_hold
			Act.DASH:
				length = _anim.clip_length(dash_clip) / 1.4 * 0.6
			Act.BREAK:
				length = guard_break_time
	if what == Act.REEL:
		length = Recoil.STAGGER
	if reacts.has(what):
		length = _react_length(what)
	_act_length = length


func _begin_attack() -> void:
	stamina -= attack_cost
	_regen_wait = regen_delay
	_blows_done = 0
	_start(Act.ATTACK)
	if _skeleton == null:
		return
	for i in _blows.size():
		var moment := _blows[i] * _act_length
		var blow := i
		_sweeps.append(WeaponSweep.blow(_fists, 2.5, moment - BLOW_BEFORE, moment + BLOW_AFTER,
				act_serial, func(who: Node3D) -> void:
					who.call("receive_blow", hit_damage, self, blow, _blows.size(), act_serial)))


## Up to each blow of the combo it steps in, so its fists land where they are
## aimed: true while it is stepping.
func _close_in() -> bool:
	if _quarry == null or _blows_done >= _blows.size():
		return false
	var gap := _distance_to(_quarry)
	var want := fist_reach * visual_scale
	if gap <= want:
		return false
	var left := _blows[_blows_done] * _act_length - _act_time
	var pace := minf((gap - want) / maxf(left, 0.15), close_speed)
	var ahead := _forward() * pace
	velocity.x = ahead.x
	velocity.z = ahead.z
	return true


## Both forearms and fists, out to the fingertips, as they are this frame.
func _fists() -> Array:
	var out := []
	var r := FIST_RADIUS * visual_scale
	for side in ["l", "r"]:
		var elbow := _skeleton.find_bone("lowerarm_" + side)
		var wrist := _skeleton.find_bone("hand_" + side)
		var tip := _skeleton.find_bone("middle_04_leaf_" + side)
		if elbow < 0 or wrist < 0:
			continue
		out.append(WeaponSweep.bones(_skeleton, elbow, wrist, r))
		if tip >= 0:
			out.append(WeaponSweep.bones(_skeleton, wrist, tip, r))
	return out


## Moves an action on: lands the combo's blows, carries the dash, and hands
## back to thinking once the action has run its length.
func _run_act(delta: float) -> void:
	match act:
		Act.NONE, Act.DEAD:
			return
		Act.ATTACK:
			if not _close_in():
				_slow(delta, 2.0)
			var through := _act_time / maxf(_act_length, 0.001)
			while _blows_done < _blows.size() and through >= _blows[_blows_done]:
				_blows_done += 1
		Act.BLOCK, Act.BREAK, Act.REEL, Act.REACT_KNOCK, Act.REACT_BURN, Act.REACT_POISON:
			_slow(delta, 3.0)
		Act.DASH:
			var push := clampf(1.0 - _act_time / 0.4, 0.0, 1.0)
			velocity.x = _dash_dir.x * dash_speed * push
			velocity.z = _dash_dir.z * dash_speed * push
	if _act_time >= _act_length:
		_cooldown = maxf(_cooldown, 0.3) if act != Act.ATTACK \
				else _rng.randf_range(attack_cooldown.x, attack_cooldown.y)
		_start(Act.NONE)


## A knight within reach has just started a swing at it: guard, sidestep, or
## take it. Never in the middle of its own swing — a creature that can cancel
## its combo into a block cannot be punished for attacking.
func _answer_swing(knight: Node3D) -> void:
	if act == Act.ATTACK or act == Act.BREAK or act == Act.DASH or act == Act.REEL:
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
	if act == Act.BLOCK:
		_act_time = 0.0
		return
	var roll := _rng.randf()
	if roll < block_chance and stamina >= block_cost * 0.5:
		_face(-to_me, 1.0, 1000.0)
		_start(Act.BLOCK)
	elif roll < block_chance + dash_chance and stamina >= dash_cost:
		stamina -= dash_cost
		_regen_wait = regen_delay
		var side := to_me.normalized().cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0)
		_dash_dir = (to_me.normalized() * 0.6 + side * 0.8).normalized()
		_face(-to_me, 1.0, 1000.0)
		_start(Act.DASH)
#endregion


#region Taking hits
## A player met one of its blows on the shield at the last moment. Host only:
## the rest of the combo is not thrown, and it reels open ([Recoil]).
func parried(_by: Node3D) -> void:
	if is_dead or not _decides():
		return
	_start(Act.REEL)


func is_reeling() -> bool:
	return act == Act.REEL


## Watches every knight's blade. A new swing is a chance to defend; a blade
## that passes through the body is a cut, taken once per swing per attacker.
func _watch_blades() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		var knight := node as Player
		if knight == null or knight.rig == null:
			continue
		var serial: int = knight.rig.attack_serial
		if not _seen_swing.has(knight.name):
			_seen_swing[knight.name] = serial
			_last_cut[knight.name] = serial
			continue
		if serial != _seen_swing[knight.name]:
			_seen_swing[knight.name] = serial
			_answer_swing(knight)
		if serial == _last_cut.get(knight.name, -1):
			continue
		var edge := knight.rig.get_cutting_edge()
		if edge.is_empty():
			continue
		var s := maxf(visual_scale, 0.01)
		var low := global_position + Vector3.UP * body_radius * s
		var high := global_position + Vector3.UP * maxf(body_height - body_radius, body_radius) * s
		var near := Geometry3D.get_closest_points_between_segments(edge[0], edge[1], low, high)
		if near[0].distance_to(near[1]) > body_radius * s + hit_tolerance:
			continue
		_last_cut[knight.name] = serial
		# Thrown the way the blade was going: cut from its right, it goes left.
		var blow := knight.rig.swing_direction((edge[1] - edge[0]).normalized() + Vector3.UP * 0.3)
		var worth := knight.cut_worth()
		if bool(worth[1]):
			CombatText.mark_critical(self)
		if _receive(float(worth[0]), near[1], blow, knight):
			knight.rig.bloody()
			knight.net_blade_landed.rpc()
			knight.blade_hit(self, near[1])
		if is_dead:
			return


## The door every kind of damage comes through, the arrow's included — the same
## signature as `Wolf.take_hit()`, which is what `arrow.gd` calls.
func take_hit(damage: float, at: Vector3, blow: Vector3, critical: bool = false,
		_spill: bool = true, from: Node = null, magic: bool = false) -> void:
	if is_dead or not _decides():
		return
	# The archer may have left while the arrow was in the air. A critical is
	# already in `damage`: the shooter made it one.
	var shooter := from as Node3D if is_instance_valid(from) else null
	if critical:
		CombatText.mark_critical(self)
	_receive(damage, at, blow, shooter, magic)


## Fire and poison (host, from [Afflictions]): health off with no blood and
## no shove, and no guard against it.
func take_dot(damage: float, from: Node3D = null) -> void:
	if is_dead or not _decides():
		return
	if from != null and is_instance_valid(from):
		_rouse(from)
	health = maxf(health - Defence.taken(damage, m_def) * Afflictions.factor(self, from), 0.0)
	hurt.emit(health)
	if health <= 0.0:
		_die()


## When each kind of skill last made it react.
var _reacted: Dictionary = {}
var _react_clock: float = 0.0
var _react_seg: int = -1


## A hero's skill landed on it (host). Thrown back and down by the Piercing
## Arrow; flailing in fire; retching on poison; the mark is only laid on.
## The same kind does not set it off again for 5 s.
func react(kind: StringName, from: Node3D = null, push: Vector3 = Vector3.ZERO) -> void:
	if is_dead or not _decides():
		return
	if from != null and is_instance_valid(from):
		_rouse(from)
	if push.length_squared() > 0.0001:
		velocity += Vector3(push.x, 0.0, push.z)
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(_reacted.get(kind, -1000.0)) + 5.0:
		return
	_reacted[kind] = now
	match kind:
		&"knock":
			_start(Act.REACT_KNOCK)
		&"burn":
			if act == Act.NONE or act == Act.BLOCK:
				_start(Act.REACT_BURN)
		&"poison":
			if act == Act.NONE or act == Act.BLOCK:
				_start(Act.REACT_POISON)


func _react_length(what: Act) -> float:
	var total := 0.0
	for seg: Array in reacts[what]:
		total += _anim.clip_length(seg[0]) * float(seg[2]) / float(seg[1])
	return total


func _play_react(delta: float) -> void:
	_react_clock += delta
	var segs: Array = reacts[act]
	var t := _react_clock
	var i := 0
	while i < segs.size() - 1:
		var seg: Array = segs[i]
		var span := _anim.clip_length(seg[0]) * float(seg[2]) / float(seg[1])
		if t < span:
			break
		t -= span
		i += 1
	if i != _react_seg:
		_react_seg = i
		var seg: Array = segs[i]
		_anim.play(seg[0], 0.1 if i == 0 else 0.25, float(seg[1]), 1.0, true)


## True while dashing aside: a spell that was hunting it lets go.
func is_evading() -> bool:
	return act == Act.DASH


## Returns true when the hit drew blood, false when it was caught or dodged.
func _receive(damage: float, at: Vector3, blow: Vector3, from: Node3D, magic: bool = false) -> bool:
	if is_dead or not _decides():
		return false
	if from != null:
		_rouse(from)
	# Out of the way: the dash's first moments are a clean miss.
	if act == Act.DASH and _act_time < dash_iframes:
		return false
	# Caught on the guard, if the guard faces the blow.
	if act == Act.BLOCK and from != null:
		var to_them := from.global_position - global_position
		to_them.y = 0.0
		if _forward().dot(to_them.normalized()) > 0.0:
			stamina -= block_cost
			_regen_wait = regen_delay
			net_clash.rpc(at)
			if stamina <= 0.0:
				stamina = 0.0
				_start(Act.BREAK)
				guard_broken.emit()
			else:
				_act_time = 0.0
			return false

	if act == Act.REEL or act == Act.REACT_KNOCK:
		# Reeling from a parry, or thrown down, it is wide open: the riposte
		# bites deeper.
		damage *= Recoil.RIPOSTE
	damage = Defence.against(damage, p_def, m_def, magic)
	# Marked by the hunter, everything bites deeper.
	damage *= Afflictions.factor(self, from)
	health = maxf(health - damage, 0.0)
	stamina = maxf(stamina - hit_cost, 0.0)
	_regen_wait = regen_delay
	hurt.emit(health)
	var thrown := blow if blow.length_squared() > 0.0001 else Vector3.UP
	net_bleed.rpc(at, thrown.normalized())
	var shove := thrown
	shove.y = 0.0
	if shove.length_squared() > 0.0001:
		velocity += shove.normalized() * 2.5
	if health <= 0.0:
		_die()
	return true


@rpc("authority", "call_local", "unreliable")
func net_bleed(at: Vector3, blow: Vector3) -> void:
	Blood.splatter(Blood.world_of(self), at, blow, self)
	_flinch_body(blow)


## Tipped over by blows ([HitReact]): made at the first one, so the pose it
## springs back to is the one the body really has.
var _hit_react: HitReact
## How hard a cut throws it over (radians a second).
const FLINCH_THROW := 4.2


func _flinch_body(blow: Vector3) -> void:
	if is_dead or body == null:
		return
	if _hit_react == null:
		_hit_react = HitReact.on_body(body)
	_hit_react.strike(blow, FLINCH_THROW)


func _drive_flinch(delta: float) -> void:
	if _hit_react == null:
		return
	if is_dead:
		_hit_react.settle()
		_hit_react = null
		return
	_hit_react.drive(delta)


## A cut caught on the guard: a puff where blade met guard, and no blood.
@rpc("authority", "call_local", "unreliable")
func net_clash(at: Vector3) -> void:
	DustRing.burst(Blood.world_of(self), at, 0.35)


func _die() -> void:
	if is_dead:
		return
	health = 0.0
	velocity = Vector3.ZERO
	_start(Act.DEAD)
	is_dead = true


## What being dead looks like, on every peer — run from the `is_dead` setter.
func _lie_down() -> void:
	if _health_bar != null:
		_health_bar.hide()
	if _stamina_bar != null:
		_stamina_bar.hide()
	# Out of the way of the living, but still resting on the ground.
	collision_layer = 0
	Sfx.play(self, LOOT_SOUND, null, global_position + Vector3.UP * 0.3, 1.0, -18.0)
	died.emit()

## Something falling from it as it goes down: every creature drops a little,
## heard where it lies.
const LOOT_SOUND := "res://unverified/sounds/all/loot_1.wav"


## How a body falls once it is dead: the knock back plays for `FREEZE_AT`
## seconds, then it goes over backwards onto the ground in `FALL_TIME`, hits,
## rocks back a little and lies still, `FALL_LIFT` up so it lies on the ground
## rather than in it.
const FREEZE_AT := 0.06
const FALL_TIME := 0.6
const FALL_LIFT := 0.12
var _stood: Basis = Basis.IDENTITY
var _stood_taken: bool = false


func _topple() -> void:
	if body == null:
		return
	if not _stood_taken:
		_stood_taken = true
		_stood = body.transform.basis
	var t := clampf(_corpse_age / FALL_TIME, 0.0, 1.0)
	var over := pow(t / 0.7, 2.0) * 1.05 if t < 0.7 else lerpf(1.05, 1.0, (t - 0.7) / 0.3)
	# About the body's own left-right axis, head going back (+Z is behind it).
	body.transform.basis = Basis(Vector3.RIGHT, PI * 0.5 * over) * _stood
	if _corpse_age <= corpse_linger:
		body.position.y = _body_rest_y + FALL_LIFT * visual_scale * minf(t * 1.5, 1.0)


## `queue_free()` does not replicate, so the host says it out loud.
@rpc("authority", "call_local", "reliable")
func net_clear() -> void:
	queue_free()
#endregion
