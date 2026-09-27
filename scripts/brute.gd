class_name Brute
extends CharacterBody3D

## What the big ones share: the orc warrior and Arkdeva.
##
## Much of it is [Fighter]'s — a band and a patch of ground it holds, a leash
## back to it, health, the knight's blade watched for cuts, the arrow's
## `take_hit()`, a corpse that sinks — without the parts that make a Fighter a
## Fighter (the stamina, the block and the sidestep). Neither of these is
## animated by [SkeletonAnim], which is why this is not a [Monster]: the orc is
## retargeted in skeleton space ([RigRetarget]) and Arkdeva is posed limb by
## limb in code.
##
## A subclass says what it does with `_choose_attack()`, `_run_act()` and
## `_animate()`. **The host decides**, as everywhere: `health`, `is_dead`,
## `mode`, `act` and `act_serial` are replicated, and every peer starts the
## act's animation when the serial moves. Effects go out as RPCs.

signal died
signal hurt(remaining: float)

enum Mode { GUARD, CHASE, FIGHT, RETURN }
## Every subclass keeps these two numbers for "nothing" and "dead".
const ACT_NONE := 0
const ACT_DEAD := 99
## Reeling from a parried blow ([Recoil]), open to a riposte.
const ACT_REEL := 98

@export_group("Movement")
@export var speed: float = 1.3
@export var chase_speed: float = 3.4
@export var acceleration: float = 6.0
@export var turn_speed: float = 4.0
@export var roam_radius: float = 5.0
@export var rest_time: float = 3.0
@export var step_height: float = 0.45
@export var step_probe: float = 0.8

@export_group("Territory")
@export var band: StringName = &""
@export var camp_centre: Vector3 = Vector3.ZERO
@export var sight_range: float = 16.0
@export var leash_radius: float = 30.0

@export_group("Health")
@export var max_health: float = 260.0
## What a cut takes off when no hero is behind it (a hero's is his p.atk).
@export var sword_damage: float = 25.0
## Physical and magical defence, p.def and m.def ([Defence]).
@export var p_def: float = 0.0
@export var m_def: float = 0.0
## The body as the blade sees it: an upright capsule, in metres.
@export var body_radius: float = 0.55
@export var body_height: float = 2.4
@export var hit_tolerance: float = 0.3
@export var bar_height: float = 2.8
@export var bar_width: float = 1.2
## Left alone this long — nobody chased, nothing struck — it mends to full
## health over `regen_fill` seconds. 0 leaves it to heal only when it gets home.
@export var regen_after: float = 0.0
@export var regen_fill: float = 1.5

@export_group("Appearance")
## Size the model is drawn at. The collider is sized in the scene to match.
@export var visual_scale: float = 1.0

@export_group("Corpse")
@export var corpse_linger: float = 5.0
@export var corpse_sink_time: float = 1.6
@export var corpse_sink_depth: float = 2.6

var health: float = 0.0
var mode: int = Mode.GUARD
var act: int = ACT_NONE
var act_serial: int = 0
var is_dead: bool = false:
	set(value):
		if is_dead == value:
			return
		is_dead = value
		if is_dead:
			_lie_down()

@onready var body: Node3D = $Visuals

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _rng := RandomNumberGenerator.new()
var _health_bar: HealthBar
var _played_serial: int = -1
## Seconds since the act on screen started, on every peer.
var _shown_time: float = 0.0

## Host only.
var _home: Vector3
var _target: Vector3
var _beat := Vector3.ZERO
var _wait: float = 0.0
var _quarry: Node3D
var _act_time: float = 0.0
var _act_length: float = 0.0
var _cooldown: float = 0.0
var _seen_swing: Dictionary = {}
var _last_cut: Dictionary = {}
var _corpse_age: float = 0.0
var _cleared: bool = false
var _body_rest_y: float = 0.0
## Waves of thorns in the ground, host side: each catches a player once as its
## front runs under them.
var _waves: Array[Dictionary] = []
## Seconds since it last fought or was struck, for `regen_after`.
var _calm: float = 0.0
## A skill's shove (the Piercing Arrow), host side: added to the move each
## frame and dying away.
var _shove := Vector3.ZERO
## When each kind of skill last made it react, so one cannot be kept reeling.
var _reacted: Dictionary = {}
## How long before the same kind of skill makes it react again.
@export var react_again: float = 6.0
## How much of a skill's shove it takes (a big body moves less).
@export var shove_taken: float = 0.6
## The blows under way, as the weapon or limb that throws each ([WeaponSweep]):
## host side, run once a frame after the pose is set.
var _sweeps: Array[WeaponSweep] = []


func _ready() -> void:
	add_to_group(&"enemy")
	_rng.randomize()
	_home = global_position
	if camp_centre == Vector3.ZERO:
		camp_centre = _home
	if not band.is_empty():
		add_to_group(band)
	health = max_health
	_cooldown = _rng.randf_range(0.5, 2.0)
	if body != null:
		body.scale = Vector3.ONE * visual_scale
		_body_rest_y = body.position.y
	_health_bar = HealthBar.new()
	_health_bar.width = bar_width
	_health_bar.height = 0.09
	_health_bar.top_level = true
	add_child(_health_bar)
	_pick_target()
	set_physics_process(_decides())


func _decides() -> bool:
	var net := get_node_or_null("/root/Net")
	return net == null or bool(net.call("is_host"))


#region What a subclass fills in
## Close enough and cooled down: start something, or do nothing.
func _choose_attack(_gap: float) -> void:
	pass


## Moves the act on (host). Return true while it is still running.
func _run_act(_delta: float) -> bool:
	return _act_time < _act_length


## Poses the body for this frame, on every peer.
func _animate(_delta: float) -> void:
	pass


## Called on every peer when a new act starts.
func _show_act() -> void:
	pass


## How much of an arrow gets through. The orc's raised arm says less.
func _arrow_factor(_from: Node3D) -> float:
	return 1.0


## Closest a fight wants to be: inside this it stops and turns to face.
func _stand_off() -> float:
	return 2.2


## Starts the reel. A kind whose acts are a list of moves (Arkdeva) starts its
## own; the rest stand in `ACT_REEL`.
func _reel() -> void:
	_start(ACT_REEL, Recoil.STAGGER)
#endregion


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
	_mend(delta)
	_run_waves(delta)
	_watch_blades()
	if is_dead:
		return
	if act != ACT_NONE and not _run_act(delta):
		_cooldown = maxf(_cooldown, _after_act_rest())
		_start(ACT_NONE, 0.0)
	_think(delta)
	StepUp.climb(self, delta, step_height, step_probe)
	var own := velocity
	if _shove.length_squared() > 0.0001:
		velocity += _shove
		_shove *= exp(-4.0 * delta)
	move_and_slide()
	if _shove.length_squared() > 0.0001:
		velocity = Vector3(own.x, velocity.y, own.z)


## Left alone long enough, it mends.
func _mend(delta: float) -> void:
	if regen_after <= 0.0 or health >= max_health or mode == Mode.CHASE or mode == Mode.FIGHT \
			or act != ACT_NONE:
		_calm = 0.0
		return
	_calm += delta
	if _calm >= regen_after:
		health = minf(health + max_health * delta / maxf(regen_fill, 0.01), max_health)


func _after_act_rest() -> float:
	return _rng.randf_range(1.0, 2.4)


func _process(delta: float) -> void:
	if not is_dead:
		_health_bar.global_position = global_position + Vector3.UP * bar_height
		_health_bar.set_fraction(health / maxf(max_health, 0.001))
	else:
		_corpse_age += delta
		if _corpse_age > corpse_linger and body != null:
			var sunk := clampf((_corpse_age - corpse_linger) / maxf(corpse_sink_time, 0.001), 0.0, 1.0)
			body.position.y = _body_rest_y - sunk * sunk * corpse_sink_depth
	if act_serial != _played_serial:
		_played_serial = act_serial
		_shown_time = 0.0
		_show_act()
	else:
		_shown_time += delta
	_animate(delta)
	# A blow lands only where the weapon has actually been: checked against the
	# pose just set, from where it was a frame ago.
	if _decides() and not is_dead:
		WeaponSweep.run(_sweeps, _act_time, act_serial, get_tree(), delta)
	WeaponSweep.draw(self, _sweeps)
#endregion


#region Thinking
func _think(delta: float) -> void:
	_quarry = _pick_quarry()
	match mode:
		Mode.GUARD:
			if _quarry != null and _distance_to(_quarry) < sight_range:
				_rouse(_quarry)
			elif act == ACT_NONE:
				_wander(delta)
		Mode.CHASE, Mode.FIGHT:
			if _quarry == null:
				_quarry = null
				mode = Mode.RETURN
			elif act == ACT_NONE:
				var gap := _distance_to(_quarry)
				if _cooldown <= 0.0:
					_choose_attack(gap)
				if act != ACT_NONE:
					return
				if gap > _stand_off():
					mode = Mode.CHASE
					_move_towards(_quarry.global_position, chase_speed, delta)
				else:
					mode = Mode.FIGHT
					_face(_quarry.global_position - global_position, delta, turn_speed)
					_slow(delta, 2.0)
			elif not is_reeling():
				_face(_quarry.global_position - global_position, delta, turn_speed * _turn_while_acting())
		Mode.RETURN:
			var home := _home - global_position
			home.y = 0.0
			if home.length() < 1.5:
				mode = Mode.GUARD
				health = max_health
				_wait = 1.0
			else:
				_move_towards(_home, speed * 1.6, delta)


## How freely it turns to follow its quarry mid-act, as a share of `turn_speed`.
func _turn_while_acting() -> float:
	return 0.3


## Whether a point is on the ground it holds: whoever leaves it is let go.
## A ring of `leash_radius` round its camp, unless a kind says otherwise.
func _holds(point: Vector3) -> bool:
	return point.distance_squared_to(camp_centre) < leash_radius * leash_radius


func _pick_quarry() -> Node3D:
	if _quarry != null and is_instance_valid(_quarry) and _quarry.is_inside_tree() \
			and _holds(_quarry.global_position) and not _fallen(_quarry):
		return _quarry
	if mode == Mode.RETURN:
		return null
	var best: Node3D = null
	var closest := INF
	for node in get_tree().get_nodes_in_group("player"):
		var who := node as Node3D
		if who == null or not _holds(who.global_position) or _fallen(who):
			continue
		var gap := global_position.distance_squared_to(who.global_position)
		if gap < closest:
			closest = gap
			best = who
	return best


## A player who has fallen and is waiting to be put back: left alone.
static func _fallen(who: Node3D) -> bool:
	return who != null and who.get("net_dead") == true


func _rouse(who: Node3D) -> void:
	if who == null or is_dead:
		return
	_quarry = who
	if mode == Mode.GUARD or mode == Mode.RETURN:
		mode = Mode.CHASE
		if not roar_sound.is_empty() and Time.get_ticks_msec() / 1000.0 >= _roar_again_at:
			_roar_again_at = Time.get_ticks_msec() / 1000.0 + 8.0
			net_roar.rpc()
	if band.is_empty():
		return
	for node in get_tree().get_nodes_in_group(band):
		var mate := node as Brute
		if mate != null and mate != self and not mate.is_dead and mate.mode == Mode.GUARD:
			mate._quarry = who
			mate.mode = Mode.CHASE


func _wander(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		_slow(delta, 1.0)
		return
	var to_target := _target - global_position
	to_target.y = 0.0
	if to_target.length() < 1.0:
		_wait = rest_time + _rng.randf_range(-1.0, 1.5)
		_pick_target()
	else:
		_move_towards(_target, speed, delta)


func _pick_target() -> void:
	if _beat == Vector3.ZERO:
		var angle := _rng.randf() * TAU
		_beat = Vector3(cos(angle), 0.0, sin(angle)) * roam_radius
		_target = _home + _beat
	else:
		var drift := Vector3(_rng.randf_range(-1.2, 1.2), 0.0, _rng.randf_range(-1.2, 1.2))
		_target = (_home + _beat + drift) if _target.distance_to(_home + _beat) > roam_radius * 0.5 \
				else (_home - _beat + drift)


func _move_towards(point: Vector3, pace: float, delta: float) -> void:
	var direction := point - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	direction = direction.normalized()
	_face(direction, delta, turn_speed)
	var alignment := clampf(_forward().dot(direction), 0.0, 1.0)
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


## Starts an act here and, through the serial, on every peer.
func _start(what: int, length: float) -> void:
	act = what
	act_serial += 1
	_sweeps.clear()
	_act_time = 0.0
	_act_length = length
#endregion


#region Dealing blows
## Every player a blow can reach: within `radius` of `at` on the ground, or of
## the creature in a cone `ahead` when `cone` is above -1.
func _players_near(at: Vector3, radius: float) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("player"):
		var who := node as Node3D
		if who == null or not who.has_method("receive_blow") or _fallen(who):
			continue
		var gap := who.global_position - at
		if absf(gap.y) > 2.5:
			continue
		gap.y = 0.0
		if gap.length() <= radius:
			found.append(who)
	return found


func _players_ahead(span: float, cone: float) -> Array[Node3D]:
	var found: Array[Node3D] = []
	var ahead := _forward()
	for who in _players_near(global_position, span):
		var to_them := who.global_position - global_position
		to_them.y = 0.0
		if to_them.length() < 0.8 or ahead.dot(to_them.normalized()) >= cone:
			found.append(who)
	return found


## Arms one blow of the act just started: `stretches` is the weapon or limb as
## [WeaponSweep] wants it, live from `start` to `end` seconds into the act, and
## `effect` what it does to whoever it passes through.
func _sweep(stretches: Callable, slowest: float, start: float, end: float, effect: Callable) -> WeaponSweep:
	var sweep := WeaponSweep.blow(stretches, slowest, start, end, act_serial, effect)
	_sweeps.append(sweep)
	return sweep


## One blow on one player. `blow` of `blows`: a combo that lands every blow is
## the only thing that knocks a player down, so a lone hit is sent as the
## first of two.
func _hit(who: Node3D, damage: float, blow: int = 0, blows: int = 2, combo: int = -1,
		magic: bool = false) -> void:
	who.call("receive_blow", damage, self, blow, blows, act_serial if combo < 0 else combo, magic)


## A special blow — a slam, a spin, a stamp, the ground erupting — floors
## whoever it lands on clean (a blocked or rolled one still does not): it is
## sent as a combo of one.
func _floor(who: Node3D, damage: float, combo: int = -1) -> void:
	_hit(who, damage, 0, 1, combo)


## Starts the damage of a wave laid out as [method GroundFx.wave] draws it.
func _launch_wave(from: Vector3, direction: Vector3, length: float, size: float, damage: float) -> void:
	var ahead := Vector3(direction.x, 0.0, direction.z).normalized()
	_waves.append({
		"from": from, "dir": ahead, "length": length, "size": size, "damage": damage,
		"t": 0.0, "id": act_serial * 1000 + 70 + _waves.size(), "caught": {},
	})


func _run_waves(delta: float) -> void:
	for i in range(_waves.size() - 1, -1, -1):
		var wave := _waves[i]
		wave.t = float(wave.t) + delta
		var front := GroundFx.wave_front(wave.t)
		var ahead: Vector3 = wave.dir
		var side := Vector3(-ahead.z, 0.0, ahead.x)
		var caught: Dictionary = wave.caught
		for node in get_tree().get_nodes_in_group("player"):
			var who := node as Node3D
			if who == null or caught.has(who) or not who.has_method("receive_blow"):
				continue
			var rel := who.global_position - (wave.from as Vector3)
			if absf(rel.y) > 1.6:
				continue
			var d := rel.dot(ahead)
			if d < 0.4 or d > minf(front, float(wave.length)):
				continue
			if absf(rel.dot(side)) > GroundFx.wave_width(d, wave.size) * 0.5 + 0.4:
				continue
			caught[who] = true
			# The ground coming up under him puts him down.
			_floor(who, wave.damage, wave.id)
		if front > float(wave.length) + 1.0:
			_waves.remove_at(i)
#endregion


#region Taking hits
## A player met one of its blows on the shield at the last moment. Host only:
## whatever it was doing stops — the rest of a combo is not thrown — and it
## reels, its weapon knocked back, open for `Recoil.STAGGER` seconds.
func parried(_by: Node3D) -> void:
	if is_dead or not _decides():
		return
	_calm = 0.0
	_reel()


## True while it reels from a parry.
func is_reeling() -> bool:
	return act == ACT_REEL or _reel_act()


## A kind with its own reel act says so.
func _reel_act() -> bool:
	return false


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
			if knight.global_position.distance_to(global_position) < 6.0:
				_rouse(knight)
		if serial == _last_cut.get(knight.name, -1):
			continue
		var edge := knight.rig.get_cutting_edge()
		if edge.is_empty():
			continue
		var low := global_position + Vector3.UP * body_radius
		var high := global_position + Vector3.UP * maxf(body_height - body_radius, body_radius)
		var near := Geometry3D.get_closest_points_between_segments(edge[0], edge[1], low, high)
		if near[0].distance_to(near[1]) > body_radius + hit_tolerance:
			continue
		_last_cut[knight.name] = serial
		var blow := (edge[1] - edge[0]).normalized() + Vector3.UP * 0.3
		var worth := knight.cut_worth()
		if bool(worth[1]):
			CombatText.mark_critical(self)
		if _receive(float(worth[0]), near[1], blow, knight):
			knight.rig.bloody()
			knight.net_blade_landed.rpc()
			knight.blade_hit(self, near[1])
		if is_dead:
			return


## What `arrow.gd` calls, with the wolf's signature.
func take_hit(damage: float, at: Vector3, blow: Vector3, critical: bool = false,
		_spill: bool = true, from: Node = null, magic: bool = false) -> void:
	if is_dead or not _decides():
		return
	var shooter := from as Node3D if is_instance_valid(from) else null
	var factor := _arrow_factor(shooter)
	if factor < 1.0:
		net_clash.rpc(at)
	# A critical is already in `damage`: the shooter made it one.
	if critical:
		CombatText.mark_critical(self)
	_receive(damage * factor, at, blow, shooter, factor >= 1.0, magic)


func _receive(damage: float, at: Vector3, blow: Vector3, from: Node3D, bleed: bool = true,
		magic: bool = false) -> bool:
	if is_dead or not _decides():
		return false
	if from != null:
		_rouse(from)
	_calm = 0.0
	# Reeling from a parry, it is wide open: the riposte bites deeper.
	if is_reeling():
		damage *= Recoil.RIPOSTE
	# Marked by the hunter, everything bites deeper.
	damage *= Afflictions.factor(self, from)
	health = maxf(health - Defence.against(damage, p_def, m_def, magic), 0.0)
	hurt.emit(health)
	if bleed:
		var thrown := blow if blow.length_squared() > 0.0001 else Vector3.UP
		net_bleed.rpc(at, thrown.normalized())
	if health <= 0.0:
		_die()
	return true


## Fire and poison (host, from [Afflictions]): health off with no blood, no
## shove, through its m.def.
func take_dot(damage: float, from: Node3D = null) -> void:
	if is_dead or not _decides():
		return
	if from != null and is_instance_valid(from):
		_rouse(from)
	_calm = 0.0
	health = maxf(health - Defence.taken(damage, m_def) * Afflictions.factor(self, from), 0.0)
	hurt.emit(health)
	if health <= 0.0:
		_die()


## A hero's skill landed on it (host): `kind` is &"mark", &"knock", &"burn" or
## &"poison"; `push` is a shove. A kind says how it shows it ([method _react]);
## the same kind does not set it off again for `react_again` seconds.
func react(kind: StringName, from: Node3D = null, push: Vector3 = Vector3.ZERO) -> void:
	if is_dead or not _decides():
		return
	if from != null and is_instance_valid(from):
		_rouse(from)
	if push.length_squared() > 0.0001:
		_shove += Vector3(push.x, 0.0, push.z) * shove_taken
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(_reacted.get(kind, -1000.0)) + react_again:
		return
	_reacted[kind] = now
	_react(kind)


## How it shows a skill. The plain one: thrown back, it reels.
func _react(kind: StringName) -> void:
	if kind == &"knock":
		_reel()


@rpc("authority", "call_local", "unreliable")
func net_bleed(at: Vector3, blow: Vector3) -> void:
	Blood.splatter(Blood.world_of(self), at, blow)


@rpc("authority", "call_local", "unreliable")
func net_clash(at: Vector3) -> void:
	DustRing.burst(Blood.world_of(self), at, 0.35)


func _die() -> void:
	if is_dead:
		return
	health = 0.0
	velocity = Vector3.ZERO
	_start(ACT_DEAD, 0.0)
	is_dead = true


func _lie_down() -> void:
	if _health_bar != null:
		_health_bar.hide()
	collision_layer = 0
	Sfx.play(self, LOOT_SOUND, null, global_position + Vector3.UP * 0.3, 1.0, -18.0)
	died.emit()

## Something falling from it as it goes down: every creature drops a little,
## heard where it lies.
const LOOT_SOUND := "res://unverified/sounds/all/loot_1.wav"


## Its war cry as it comes for someone, if it has one (the orcs).
var roar_sound: String = ""
var _roar_again_at: float = 0.0


@rpc("authority", "call_local", "unreliable")
func net_roar() -> void:
	Sfx.play(self, roar_sound, self, Vector3.UP * 1.6, randf_range(0.94, 1.04), -16.0)


@rpc("authority", "call_local", "reliable")
func net_clear() -> void:
	queue_free()
#endregion
