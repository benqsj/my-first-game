class_name Wolf
extends CharacterBody3D

## The wolf monster: prowls until it notices the knight, runs him down on all
## fours, then rears onto its hind legs to fight with its claws — how well, and
## how cunningly, is its `intellect` and its [WolfMind]: dodges, hops back out
## of reach, circles, backs off and comes again, combos, a leap from out of
## reach. It never runs away for good. A leg cut off puts it down on its belly,
## and it comes on crawling.
##
## Gait is not a separate decision from the AI — it falls out of what the
## creature is doing. Covering ground means all fours; being within reach means
## standing up, because that is where the claws are useful. The rig only ever
## sees a single 0-to-1 stance value.

signal attacked
signal died
signal hurt(remaining: float)

enum State { PROWL, CHASE, FIGHT, FLEE, DOWN }

#region Exported tuning
@export_group("Senses")
## How far away the knight is noticed. Close: a wolf in the grass is met, not
## seen coming from across the field.
@export var sight_range: float = 11.0
## Once chasing, it keeps coming until the knight is this far away.
@export var lose_range: float = 18.0
## Close enough to stand up and swing.
@export var reach: float = 2.3
## How far off its claws land (measured: about 1.1 m round it); swiping from
## further, it steps in to that.
@export var claw_reach: float = 0.8
## Hurt from further off than it can see — an arrow out of the trees — it
## comes anyway, and keeps coming for this long whatever the distance.
@export var provoked_time: float = 14.0
## The pack: wolves this close to one that is hurt come too.
@export var pack_call: float = 14.0

@export_group("Movement")
## Tallest step it walks up without being stopped by it. Kept below the body's
## own radius, as the sweep needs room to put it down again.
@export var step_height: float = 0.45
## How far ahead that sweep reaches. Must exceed the body's radius.
@export var step_probe: float = 0.6
@export var prowl_speed: float = 2.2
@export var charge_speed: float = 5.6
@export var acceleration: float = 22.0
@export var turn_speed: float = 9.0
## How far from where it started it will wander.
@export var prowl_radius: float = 4.0

@export_group("Health")
@export var max_health: float = 100.0
## Taken off per cut. Losing limbs is what kills it; this is the readout.
@export var damage_per_hit: float = 26.0
## How high over its head the bar sits.
@export var bar_height: float = 2.15

@export_group("Combat")
@export var swipe_interval: float = 1.5
## What a swipe that lands takes off, and how far into the swipe the claws
## arrive — the player has that long to roll or raise a shield.
@export var swipe_damage: float = 38.0
@export var swipe_lands_after: float = 0.58
## How long it stands open after a swipe is parried.
@export var parried_stagger: float = 1.6
## Losing this many limbs puts it down.
@export var limbs_before_death: int = 4
@export var flee_speed: float = 4.5
## How close the blade has to pass a limb to take it off, in metres.
@export var hit_tolerance: float = 1.0

@export_group("Corpse")
## Seconds a body lies where it fell before it is cleared away. Long enough to
## see it land and read the kill, short enough that the ground stays clear.
@export var corpse_linger: float = 3.0
## How long it takes to sink out of sight once the linger is up.
@export var corpse_sink_time: float = 1.0
## How far it sinks, in metres. Deep enough that nothing shows through.
@export var corpse_sink_depth: float = 2.0
#endregion

@onready var rig: WolfRig = $Visuals as WolfRig

var state: State = State.PROWL
## Replicated. A client never decides that a wolf has died — it is told, and the
## setter runs the half of `_die()` that is only about how a corpse looks.
var is_dead: bool = false:
	set(value):
		if is_dead == value:
			return
		is_dead = value
		if is_dead:
			_lie_down()
var health: float = 0.0

var _bar: HealthBar

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _home: Vector3
var _prowl_target: Vector3
var _prowl_timer: float = 0.0
var _swipe_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
## The last swing taken from each attacker, keyed by their node name. A single
## number here would let two players swinging in the same tick collapse into one
## hit — the second one's serial would already look seen.
var _last_hit_serial: Dictionary = {}
## How much each attacker has taken off it in total, keyed the same way. This is
## what it goes after: the one hurting it most, not the one standing nearest.
var _threat: Dictionary = {}
## The line this creature patrols along, as an offset from home.
var _beat: Vector3 = Vector3.ZERO
## Set while shouldering past something it has walked into.
var _unstick: float = 0.0
var _unstick_side: float = 1.0
var _last_position: Vector3 = Vector3.ZERO
var _stuck_for: float = 0.0
## Speed it asked for this frame, before anything got in the way.
var _intent: float = 0.0
## Seconds since it went down, counted only once it is dead.
var _corpse_age: float = 0.0
## Seconds until the swipe under way lands, below zero when none is.
var _swipe_lands: float = -1.0
var _swipe_count: int = 0
## Seconds left reeling from a parried swipe.
var _reeling: float = 0.0
## How far into its reel this peer's copy is, drawn on every peer.
var _reel_clock: float = 99.0
## Seconds left of coming after whoever hurt it (or its pack), whatever the
## distance.
var _provoked: float = 0.0
## Which way it went over when it died: onto its left side or its right.
var _fall_side: float = 1.0
## The pounce under way: seconds until it throws itself forward, and whether
## the claws landing now are a pounce's (a longer reach).
var _pounce_in: float = -1.0
var _pouncing: bool = false
## Share of attacks that are a pounce rather than a swipe (the old fight; the
## mind chooses now).
@export var pounce_chance: float = 0.35

@export_group("Fighting")
## How cunning a fighter it is, 0 to 1 (see [WolfMind]). Below zero it is drawn
## at birth, between `wit_range`.
@export var intellect: float = -1.0
@export var wit_range: Vector2 = Vector2(0.2, 0.9)
## Paces in a fight: stepping in upright, circling, backing off, crawling on
## its belly with a leg gone.
@export var fight_speed: float = 2.4
@export var circle_speed: float = 1.8
@export var back_speed: float = 1.7
@export var crawl_speed: float = 1.2
## The throw of a dodge, a hop back, a bite and a lunge from the ground.
@export var dodge_speed: float = 6.5
@export var hop_speed: float = 7.0
@export var bite_speed: float = 5.0
@export var ground_lunge_speed: float = 4.2

## Its fighting mind (host).
var mind: WolfMind
## Seconds left of a move of its own under way (an attack, a dodge, a hop).
var _busy: float = 0.0
## Seconds left in which a blade goes through the air it has just left.
var _evading: float = 0.0
## Seconds left of a throw it keeps going through (the velocity is left alone).
var _burst: float = 0.0
## Who it is fighting now.
var _fighting: Node3D

## The claws as their blows see them ([WeaponSweep]), host side, on a clock
## that starts with each attack. A swipe's claws come through from the end of
## its windup; a pounce's from when it throws itself forward. Only a paw — or,
## in a pounce, the jaws — that passes through a player strikes him.
var _sweeps: Array[WeaponSweep] = []
var _attack_clock: float = 0.0
const SWIPE_LIVE := Vector2(0.44, 0.74)
const POUNCE_LIVE := Vector2(0.5, 0.86)


func _ready() -> void:
	add_to_group(&"wolf")
	_home = global_position
	_rng.randomize()
	_pick_prowl_target()
	# Only the host thinks. `_process` stays on everywhere — that is what
	# animates the body and moves the bar from replicated state.
	set_physics_process(_decides())
	if rig != null:
		rig.severed.connect(_on_severed)

	_last_position = global_position
	health = max_health
	if intellect < 0.0:
		intellect = _rng.randf_range(wit_range.x, wit_range.y)
	mind = WolfMind.new(self, intellect)
	_bar = HealthBar.new()
	_bar.position = Vector3(0.0, bar_height, 0.0)
	# Kept out of the body's rotation so it never turns edge-on to the camera.
	_bar.top_level = true
	add_child(_bar)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if is_dead:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * 3.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * 3.0 * delta)
		move_and_slide()
		_collapse(delta)
		_clear_away(delta)
		return

	_prowl_timer = maxf(_prowl_timer - delta, 0.0)
	_busy = maxf(_busy - delta, 0.0)
	_evading = maxf(_evading - delta, 0.0)
	_burst = maxf(_burst - delta, 0.0)
	_swipe_timer = maxf(_swipe_timer - delta, 0.0)
	_reeling = maxf(_reeling - delta, 0.0)
	_provoked = maxf(_provoked - delta, 0.0)
	if _pounce_in >= 0.0:
		_pounce_in -= delta
		if _pounce_in < 0.0 and not is_dead:
			var ahead := -global_transform.basis.z
			ahead.y = 0.0
			velocity += ahead.normalized() * 9.0
			# Carried through the leap, not stopped by its own feet.
			_burst = 0.4
	if _swipe_lands >= 0.0:
		_swipe_lands -= delta
		if _swipe_lands < 0.0:
			_land_swipe()
			_pouncing = false

	_think(delta)
	# Up a kerb or a stair rather than into it. A hunter that loses you to six
	# greybox steps is not hunting you.
	StepUp.climb(self, delta, step_height, step_probe)
	move_and_slide()
	_watch_for_snags(delta)
	_take_hits()


func _process(delta: float) -> void:
	# The host topples and sinks its body from `_physics_process`, which the
	# other peers never run. They get `is_dead` and nothing else, so they play
	# the same fall and the same sink here, off their own clock.
	if is_dead and not _decides():
		_collapse(delta)
		_corpse_age += delta
		var sunk := (_corpse_age - corpse_linger) / maxf(corpse_sink_time, 0.001)
		if sunk > 0.0 and rig != null:
			rig.position.y = LIE_Y - minf(sunk, 1.0) * minf(sunk, 1.0) * corpse_sink_depth
	# A dead wolf's bar stays hidden: `set_fraction` shows the bar whenever it
	# is below full, and a corpse is always below full.
	if _bar != null and not is_dead:
		_bar.global_position = global_position + Vector3.UP * bar_height
		# Read off `health` every frame rather than written when a hit lands:
		# the hit lands on the host, and what reaches everyone else is the
		# replicated number.
		_bar.set_fraction(health / maxf(max_health, 0.001))
	if rig == null:
		return
	var planar := Vector3(velocity.x, 0.0, velocity.z).length()
	# On all fours to cover ground, upright to fight.
	var stance := 0.0 if state == State.FIGHT and not is_dead and not rig.is_crippled() else 1.0
	# Which way it is going, in its own frame: backing off, circling, coming on.
	rig.move_local = global_transform.basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
	if is_dead:
		planar = 0.0
	_reel_clock += delta
	var reeling := _reel_clock < Recoil.STAGGER and not is_dead
	if reeling:
		# Thrown back up on its hind legs by the parry.
		stance = 0.0
	# A prowl is a full walk cycle, not a fraction of a sprint: measuring the
	# gait against the charge speed left it barely lifting its feet.
	rig.animate(delta, planar, planar / maxf(prowl_speed, 0.01), stance)
	# The stagger, the belly-crawl and the fall are the rig's own clips now.
	if _decides() and not is_dead:
		_attack_clock += delta
		WeaponSweep.run(_sweeps, _attack_clock, _swipe_count, get_tree(), delta)
	WeaponSweep.draw(self, _sweeps)


#region Behaviour
## True when this peer is the one that decides things. Offline that is everyone,
## which is what keeps a solo game a single code path.
func _decides() -> bool:
	var net := get_node_or_null("/root/Net")
	return net == null or bool(net.call("is_host"))


## Who it is after.
##
## **Whoever has hurt it most**, and the nearest one only while nobody has hurt
## it at all. A creature that always goes for the closest body is a creature you
## beat by standing one step further back than your friend, and it makes the
## archer's whole way of fighting free: shoot from the trees, let the knight be
## nearest, never be answered for it.
##
## Cumulative and undecayed on purpose. If the knight has taken a hundred off it
## and the archer fifty, it wants the knight — and it goes on wanting the knight
## until the archer has done more than a hundred. That is the rule as asked for,
## and it is also the one a player can hold in their head: *hurt it more than
## they did, and it is yours.*
func _quarry() -> Node3D:
	var owed: Node3D = null
	var worst := 0.0
	for node in get_tree().get_nodes_in_group("player"):
		var who := node as Node3D
		if who == null or Brute._fallen(who):
			continue
		var done := float(_threat.get(who.name, 0.0))
		if done > worst:
			worst = done
			owed = who
	return owed if owed != null else _nearest_player()


## The closest player there is, or null while there are none. Worked out fresh
## each time: which one is nearest changes as they move, and a wolf that picked
## its quarry once at load would keep chasing a body that has gone home.
func _nearest_player() -> Node3D:
	var best: Node3D = null
	var closest := INF
	for node in get_tree().get_nodes_in_group("player"):
		var who := node as Node3D
		if who == null or Brute._fallen(who):
			continue
		var gap := global_position.distance_squared_to(who.global_position)
		if gap < closest:
			closest = gap
			best = who
	return best


func _think(delta: float) -> void:
	# Asked for again every think rather than cached at `_ready()`: who it is
	# after changes as they hurt it, and with none spawned yet a cache would hold
	# null for the rest of the game.
	var quarry := _quarry()
	var to_player := Vector3.ZERO
	var distance := INF
	if quarry != null:
		to_player = quarry.global_position - global_position
		to_player.y = 0.0
		distance = to_player.length()

	# It never runs for good: a wolf with no arms left bites, and one with a leg
	# gone crawls at him. (FLEE and DOWN are no longer entered.)
	if state == State.FLEE or state == State.DOWN:
		state = State.CHASE

	match state:
		State.PROWL:
			if distance < sight_range:
				state = State.CHASE
			else:
				_prowl(delta)
		State.CHASE:
			if distance > lose_range and (_provoked <= 0.0 or distance > 90.0):
				state = State.PROWL
				_pick_prowl_target()
			elif distance < fight_from():
				state = State.FIGHT
				_fighting = quarry
				mind.engage(quarry)
			else:
				_move_towards(global_position + to_player,
						crawl_speed if rig.is_crippled() else charge_speed, delta)
		State.FLEE:
			# Nothing left to fight with: get away and stay away.
			if quarry != null:
				_move_towards(global_position - to_player, flee_speed, delta)
		State.DOWN:
			_slow(delta)
		State.FIGHT:
			# Well out of it: after him again, on all fours.
			if quarry == null or distance > fight_from() * 1.6:
				state = State.CHASE
			else:
				_fighting = quarry
				mind.fight(delta, quarry, to_player, distance)
				# A throw it is in the middle of carries it; otherwise a move
				# of its own lets it come to a stop.
				if _busy > 0.0 and _burst <= 0.0 and not rig.is_swiping():
					_slow(delta)
				# Into the swipe it steps up, so the claws come through where
				# he stands rather than short of him.
				if rig.is_swiping() and distance > claw_reach:
					var step := to_player.normalized() * minf((distance - claw_reach) * 4.0, charge_speed)
					velocity.x = step.x
					velocity.z = step.z


#region What the mind can make it do
## How close it has to be before it fights rather than chases: near enough to
## circle and to leap.
func fight_from() -> float:
	return 4.5 if not rig.is_crippled() else 3.0


## Close enough for the claws, after the step in.
func strike_range() -> float:
	return claw_reach + 0.45


## From how far a pounce carries it on to him.
func pounce_range() -> float:
	return 4.4


func lunge_range() -> float:
	return 1.9


func is_crippled() -> bool:
	return rig != null and rig.is_crippled()


func is_busy() -> bool:
	return _busy > 0.0 or _reeling > 0.0


## Early in its own windup, still able to break it off.
func winding_up() -> bool:
	return (rig.is_swiping() and _swipe_lands > swipe_lands_after * 0.4) or _pounce_in > 0.2


## It can throw itself about: legs under it and not reeling.
func can_leap() -> bool:
	return not is_crippled() and _reeling <= 0.0


func arms_left() -> int:
	var n := 2
	for arm in ["left arm", "right arm"]:
		if rig.has_lost(arm):
			n -= 1
	return n


## Who it is fighting, for its pack.
func fighting() -> Node3D:
	return _fighting if state == State.FIGHT else null


func face(direction: Vector3, delta: float) -> void:
	_face(direction, delta)


func hold(delta: float) -> void:
	_slow(delta)


## Upright, at him.
func run_at(direction: Vector3, delta: float) -> void:
	_move_towards(global_position + direction, fight_speed, delta)


## Round him, face on.
func strafe(direction: Vector3, look: Vector3, delta: float) -> void:
	_face(look, delta)
	_steer(direction * circle_speed, delta)


## Backing away from him, face on.
func back_off(towards: Vector3, delta: float) -> void:
	_face(towards, delta)
	_steer(-towards * back_speed, delta)


## On its belly, at him.
func crawl_at(direction: Vector3, delta: float) -> void:
	_move_towards(global_position + direction, crawl_speed, delta)


func _steer(wanted: Vector3, delta: float) -> void:
	_intent = wanted.length()
	velocity.x = move_toward(velocity.x, wanted.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, wanted.z, acceleration * delta)


## One move of a fight: an attack (`swipe`, `pounce`, `bite`, `ground_lunge`)
## or a way out of one (`hop`, `dodge_left`, `dodge_right`).
func attack(move: StringName) -> void:
	if is_dead or rig == null:
		return
	var ahead := -global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	match move:
		&"swipe":
			if arms_left() == 0:
				return
			_swipe_count += 1
			_busy = rig.swipe_duration
			_swipe_timer = rig.swipe_duration
			_swipe_lands = swipe_lands_after
			rig.swipe()
			_arm_claws(SWIPE_LIVE, false)
			net_swipe.rpc()
			attacked.emit()
		&"pounce":
			_swipe_count += 1
			_busy = rig.lunge_duration
			_swipe_timer = rig.lunge_duration
			_swipe_lands = rig.lunge_duration * (rig.lunge_windup + 0.12)
			_pounce_in = rig.lunge_duration * rig.lunge_windup
			_pouncing = true
			rig.lunge()
			net_lunge.rpc()
			_arm_claws(POUNCE_LIVE, true)
			attacked.emit()
		&"bite":
			_swipe_count += 1
			_busy = 0.9
			rig.bite(0.4)
			net_move.rpc(move)
			_arm_jaws(Vector2(0.25, 0.6))
			# Thrown at him as it bites.
			velocity += ahead * bite_speed
			_burst = 0.35
			attacked.emit()
		&"ground_lunge":
			_swipe_count += 1
			_busy = 0.8
			rig.ground_lunge()
			net_move.rpc(move)
			_arm_claws(Vector2(0.05, 0.55), true)
			velocity += ahead * ground_lunge_speed
			_burst = 0.4
			attacked.emit()
		&"hop":
			_break_off()
			_busy = 0.6
			_evading = 0.35
			rig.hop_back()
			net_move.rpc(move)
			velocity = -ahead * hop_speed + Vector3.UP * 2.0
			_burst = 0.35
			_sweeps.clear()
		&"dodge_left", &"dodge_right":
			var side := -1.0 if move == &"dodge_left" else 1.0
			_break_off()
			_busy = 0.55
			_evading = 0.35
			rig.dodge(side)
			net_move.rpc(move)
			var across := ahead.cross(Vector3.UP) * side
			velocity = across * dodge_speed
			_burst = 0.3
			_sweeps.clear()


## Whatever attack it was winding up, dropped.
func _break_off() -> void:
	_swipe_lands = -1.0
	_pounce_in = -1.0
	_pouncing = false
	_swipe_timer = 0.0
	_sweeps.clear()


## A move of its own, on the peers that did not decide it.
@rpc("authority", "call_remote", "unreliable")
func net_move(move: StringName) -> void:
	if rig == null or is_dead:
		return
	match move:
		&"bite":
			rig.bite(0.4)
		&"ground_lunge":
			rig.ground_lunge()
		&"hop":
			rig.hop_back()
		&"dodge_left":
			rig.dodge(-1.0)
		&"dodge_right":
			rig.dodge(1.0)


## A bite: only the jaws strike.
func _arm_jaws(live: Vector2) -> void:
	_attack_clock = 0.0
	_sweeps.clear()
	var serial := _swipe_count
	_sweeps.append(WeaponSweep.blow(func() -> Array: return rig.claw_parts(false, true), 2.0,
			live.x, live.y, serial,
			func(who: Node3D) -> void:
				if not is_dead:
					who.call("receive_blow", swipe_damage, self, 0, 2, serial)))
#endregion


## The moment the claws arrive. They strike through their sweep (`_arm_claws`),
## not here.
func _land_swipe() -> void:
	pass


## Arms the attack just begun: its claws are live for `live` seconds of it, and
## land on whoever they pass through. Sent as one blow of two, so a swipe is a
## flinch, never a knockdown, and can be parried.
func _arm_claws(live: Vector2, pounce: bool) -> void:
	_attack_clock = 0.0
	_sweeps.clear()
	var serial := _swipe_count
	_sweeps.append(WeaponSweep.blow(_claw_parts.bind(pounce), 2.5, live.x, live.y, serial,
			func(who: Node3D) -> void:
				if not is_dead and rig != null:
					who.call("receive_blow", swipe_damage, self, 0, 2, serial)))


## Both forearms and paws out to the claws, as posed this frame — an arm it has
## lost strikes nobody — and in a pounce its head ([method WolfRig.claw_parts]).
func _claw_parts(pounce: bool) -> Array:
	return rig.claw_parts(pounce) if rig != null else []


## A swipe met on a shield at the last moment: it is knocked back on its haunches
## and cannot swipe again for a while.
func parried(by: Node3D) -> void:
	if is_dead or not _decides():
		return
	_swipe_lands = -1.0
	_sweeps.clear()
	_reeling = parried_stagger
	_busy = 0.0
	net_reel.rpc()
	_swipe_timer = maxf(_swipe_timer, parried_stagger)
	if by != null:
		var away := global_position - by.global_position
		away.y = 0.0
		if away.length_squared() > 0.0001:
			velocity += away.normalized() * 5.0


## Sets it after `who`: it comes, and keeps coming for `provoked_time` however
## far off they are. A wolf of the pack that was not hurt itself owes `who` a
## token of threat, so that is who it goes for.
func provoke(who: Node3D) -> void:
	if is_dead or who == null or not _decides():
		return
	_provoked = provoked_time
	if not _threat.has(who.name):
		_threat[who.name] = 0.01
	if state == State.PROWL or state == State.FIGHT and _quarry() != who:
		state = State.CHASE


func is_reeling() -> bool:
	return _reeling > 0.0


func _prowl(delta: float) -> void:
	var to_target := _prowl_target - global_position
	to_target.y = 0.0
	if to_target.length() < 1.0 or _prowl_timer <= 0.0:
		_pick_prowl_target()
		return
	_move_towards(_prowl_target, prowl_speed, delta)


## Walks a beat: out to one end, turn, back to the other. Picking a fresh
## random spot every time never reads as patrolling — it reads as drifting.
func _pick_prowl_target() -> void:
	if _beat == Vector3.ZERO:
		var angle := _rng.randf() * TAU
		_beat = Vector3(cos(angle), 0.0, sin(angle)) * prowl_radius
		_prowl_target = _home + _beat
	else:
		_prowl_target = _home + _beat if _prowl_target.distance_to(_home + _beat) > 0.1 else _home - _beat
	_prowl_timer = _rng.randf_range(8.0, 14.0)


func _move_towards(point: Vector3, speed: float, delta: float) -> void:
	var direction := point - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	direction = direction.normalized()
	# Walked into scenery: strike out sideways for a moment rather than keep
	# pressing into it. There is no navigation mesh here, so without this a
	# creature can wedge itself against a rock and stay there.
	if _unstick > 0.0:
		direction = (direction + direction.cross(Vector3.UP) * _unstick_side * 1.4).normalized()
	_face(direction, delta)
	# Only travel the way it is actually looking. Turning and moving at once is
	# what made it crab sideways and backwards out of a turn.
	var facing := -global_transform.basis.z
	facing.y = 0.0
	var alignment := clampf(facing.normalized().dot(direction), 0.0, 1.0)
	var wanted := direction * speed * alignment
	_intent = wanted.length()
	velocity.x = move_toward(velocity.x, wanted.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, wanted.z, acceleration * delta)


## Notices when it is asking to move but going nowhere.
func _watch_for_snags(delta: float) -> void:
	_unstick = maxf(_unstick - delta, 0.0)

	var travelled := (global_position - _last_position)
	travelled.y = 0.0
	_last_position = global_position

	if _intent > 0.5 and travelled.length() < _intent * delta * 0.35:
		_stuck_for += delta
		if _stuck_for > 0.35 and _unstick <= 0.0:
			_unstick = 0.9
			_unstick_side = 1.0 if _rng.randf() < 0.5 else -1.0
			_stuck_for = 0.0
	else:
		_stuck_for = 0.0


func _slow(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * 2.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * 2.0 * delta)


func _face(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var target := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target, 1.0 - exp(-turn_speed * delta))
#endregion


#region Damage
## Watches the knight's blade and takes off whatever it passes through. The
## blade is read as a line segment rather than a collision body: the point of
## the swing is *where* it lands on the creature, and a segment gives that
## directly without wrapping every limb in its own collider.
func _take_hits() -> void:
	if is_dead or _evading > 0.0:
		return
	# Every player, not the one that happened to be first in the group at load.
	# Two people swinging at the same wolf in the same tick both land — which is
	# also why the serial is remembered per attacker.
	for node in get_tree().get_nodes_in_group("player"):
		var knight := node as Player
		if knight == null or knight.rig == null:
			continue

		var serial: int = knight.rig.attack_serial
		if serial == _last_hit_serial.get(knight.name, -1):
			continue
		var edge := knight.rig.get_cutting_edge()
		if edge.is_empty():
			continue

		var part := rig.sever_along_edge(edge[0], edge[1], hit_tolerance)
		if part == "":
			continue
		_last_hit_serial[knight.name] = serial

		# Bleed from where the limb actually came away, thrown along the blow.
		var blow := (edge[1] - edge[0]).normalized() + Vector3.UP * 0.4
		# The host decided *which* limb; everyone else is told, so the piece that
		# comes off is the same piece in every window. Re-running the geometry
		# there would disagree — their copy of the blade is in a slightly
		# different place, a frame of interpolation behind.
		net_sever.rpc(part, rig.last_cut_point, blow)
		# `net_sever` has already spilled the blood, on every peer.
		take_hit(damage_per_hit, rig.last_cut_point, blow, false, false, knight)
		knight.rig.bloody()
		knight.net_blade_landed.rpc()
		knight.blade_hit(self, rig.last_cut_point)
		if is_dead:
			return


## The limb, everywhere. The host has already taken it off its own copy, so this
## only detaches on the peers that have not — and spills the blood on all of
## them, which is the half that has to be seen.
@rpc("authority", "call_local", "reliable")
func net_sever(part: String, at: Vector3, blow: Vector3) -> void:
	if rig != null and not _decides():
		rig.detach(part)
	var thrown := blow
	if thrown.length_squared() < 0.0001:
		thrown = Vector3.UP
	Blood.splatter(Blood.world_of(self), at, thrown.normalized())


## What a peer that arrived late needs in order to see this wolf as it is: the
## parts it has already lost. Health and death arrive through the synchronizer.
func net_census() -> Array:
	return rig.lost_list() if rig != null else []


## The other half of `net_census()`, on the peer that arrived late.
func net_restore(parts: Array) -> void:
	if rig == null:
		return
	for part in parts:
		rig.hide_part(String(part))


## Takes a blow from anything at all — a blade that has already decided what it
## cut off, or an arrow that simply arrived.
##
## The sword path above works by *severing*: it reads the blade as a line and
## takes off whatever it passed through, and the creature dies of losing enough
## of itself. An arrow has nothing to sever, so this is the other way in, and it
## is health that ends it. Both share what a hit means — blood, a shove, a bar
## that goes down — because a hit should not read differently for the weapon
## that landed it.
func take_hit(damage: float, at: Vector3, blow: Vector3, critical: bool = false,
		spill: bool = true, from: Node = null) -> void:
	# Only the host decides what a hit is worth. `health` and `is_dead` are
	# replicated from here, so a client that scored one says nothing and waits to
	# be told — which is what keeps one wolf from dying twice.
	if is_dead or not _decides():
		return

	if _reeling > 0.0:
		damage *= Recoil.RIPOSTE
	# Marked by the hunter, everything bites deeper.
	damage *= Afflictions.factor(self, from)
	health = maxf(health - damage, 0.0)
	# Who is owed for it. Kept here rather than at the call sites: this is the
	# one door every kind of damage comes through, and a tally that has to be
	# remembered separately by each weapon is a tally that will be wrong the
	# first time a weapon is added.
	if from != null:
		_threat[from.name] = float(_threat.get(from.name, 0.0)) + damage
	hurt.emit(health)
	if mind != null and not is_dead:
		mind.hurt()

	var thrown := blow
	if thrown.length_squared() < 0.0001:
		thrown = Vector3.UP
	# Blood for a hit that severed nothing — an arrow, most often. A hit that did
	# sever asks for `spill = false`, because `net_sever` has already bled on
	# every peer and doing it twice on the host is a darker stain there than
	# anywhere else.
	if spill:
		Blood.splatter(Blood.world_of(self), at, thrown.normalized())
	# A critical goes in hard enough to move it.
	var shove := thrown
	shove.y = 0.0
	if shove.length_squared() > 0.0001:
		velocity += shove.normalized() * (6.0 if critical else 4.0)

	# Being shot at is a good enough reason to come and find out who did it —
	# and if somebody else has just taken the lead, to go after them instead.
	# From however far off the shot came, and the pack with it.
	if from is Node3D:
		provoke(from as Node3D)
		for node in get_tree().get_nodes_in_group("wolf"):
			var mate := node as Wolf
			if mate != null and mate != self and not mate.is_dead \
					and mate.global_position.distance_to(global_position) < pack_call:
				mate.provoke(from as Node3D)
	elif state == State.PROWL:
		state = State.CHASE

	if health <= 0.0:
		_die()


func _on_severed(part: String) -> void:
	# Taking the head is fatal on its own; otherwise it is losing enough of
	# itself that puts it down. The host's answer is the only one that counts —
	# everyone else hears about it through `is_dead`.
	if not _decides():
		return
	if part == "head" or rig.lost_parts() >= limbs_before_death:
		_die()


func _die() -> void:
	if is_dead:
		return
	state = State.DOWN
	health = 0.0
	# The setter does the rest, here and on every other peer once `is_dead` has
	# been replicated — so there is one description of what a corpse is.
	is_dead = true


## What being dead *looks* like, as opposed to what decides it. Runs from the
## `is_dead` setter, which means it runs on the host when it kills the thing and
## on everyone else when they are told.
func _lie_down() -> void:
	state = State.DOWN
	# The side it goes over on, the same in every window: from its name.
	_fall_side = 1.0 if hash(name) % 2 == 0 else -1.0
	_corpse_age = 0.0
	# An empty bar over a corpse is just clutter: there is nothing left to
	# read off it, and the body is about to topple out from under it anyway.
	if _bar != null:
		_bar.hide()
	# A corpse should not go on blocking the way like a wall. Clearing its
	# layer hides it from everything else while it keeps its own mask, so it
	# still rests on the ground instead of falling through the world.
	collision_layer = 0
	Sfx.play(self, LOOT_SOUND, null, global_position + Vector3.UP * 0.3, 1.0, -18.0)
	died.emit()

## Something falling from it as it goes down: every creature drops a little,
## heard where it lies.
const LOOT_SOUND := "res://unverified/sounds/all/loot_1.wav"


## Takes the body out of every window at once.
##
## `queue_free()` does not replicate — it is a local decision about a local
## node — so the peer that decided has to say so out loud.
## Fire and poison (host, from [Afflictions]): health off, no blood, no shove.
func take_dot(damage: float, from: Node3D = null) -> void:
	if is_dead or not _decides():
		return
	damage *= Afflictions.factor(self, from)
	health = maxf(health - damage, 0.0)
	if from != null and is_instance_valid(from):
		_threat[from.name] = float(_threat.get(from.name, 0.0)) + damage
		provoke(from)
	hurt.emit(health)
	if health <= 0.0:
		_die()


var _reacted: Dictionary = {}


## A hero's skill landed on it (host): thrown by the Piercing Arrow it reels
## back on its haunches as from a parry; fire, poison and the mark make it
## flinch.
func react(kind: StringName, from: Node3D = null, push: Vector3 = Vector3.ZERO) -> void:
	if is_dead or not _decides():
		return
	if push.length_squared() > 0.0001:
		velocity += Vector3(push.x, 0.0, push.z) * 1.3
	if from != null and is_instance_valid(from):
		provoke(from)
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(_reacted.get(kind, -1000.0)) + 4.0:
		return
	_reacted[kind] = now
	_swipe_lands = -1.0
	_reeling = parried_stagger if kind == &"knock" else parried_stagger * 0.4
	_swipe_timer = maxf(_swipe_timer, _reeling)
	net_reel.rpc()


## The reel from a parried swipe, on every peer.
@rpc("authority", "call_local", "reliable")
func net_reel() -> void:
	_reel_clock = 0.0
	if rig != null and not is_dead:
		rig.reel()


## A pounce, on the peers that did not decide it.
@rpc("authority", "call_remote", "unreliable")
func net_lunge() -> void:
	if rig != null and not is_dead:
		rig.lunge()


## A swipe, on the peers that did not decide it (the host has already thrown it).
@rpc("authority", "call_remote", "unreliable")
func net_swipe() -> void:
	if rig != null and not is_dead:
		rig.swipe()


@rpc("authority", "call_local", "reliable")
func net_clear() -> void:
	queue_free()


## Where the body lies once it has fallen: its death clip lays it on the ground.
const LIE_Y := 0.0


## Once it is dead: it falls onto its back (the rig's death clip), and lies there.
func _collapse(_delta: float) -> void:
	if rig != null:
		rig.fall()


## Takes the body out of the world once it has lain there long enough. Corpses
## that never leave pile up into clutter, and each one keeps a rig posing every
## frame. It sinks into the ground rather than blinking out, so the removal is
## something that happens in the world instead of to it. The sink is written
## after _collapse so it wins over the settling the collapse is still doing.
func _clear_away(delta: float) -> void:
	_corpse_age += delta
	if _corpse_age < corpse_linger:
		return

	var sunk := (_corpse_age - corpse_linger) / maxf(corpse_sink_time, 0.001)
	if sunk >= 1.0:
		# Everywhere, not only here. This runs in `_physics_process`, which only
		# the host has, so freeing it locally would leave a wolf lying in every
		# other window for the rest of the game — kept alive by nothing, posing a
		# rig every frame, and never coming back.
		net_clear.rpc()
		return
	if rig != null:
		# Eased in: it lingers a moment longer at the surface, then goes.
		rig.position.y = LIE_Y - sunk * sunk * corpse_sink_depth
#endregion
