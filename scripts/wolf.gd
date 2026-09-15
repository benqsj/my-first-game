class_name Wolf
extends CharacterBody3D

## The wolf monster: prowls until it notices the knight, runs him down on all
## fours, then rears onto its hind legs to fight with its claws.
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
## How far away the knight is noticed.
@export var sight_range: float = 20.0
## Once chasing, it keeps coming until the knight is this far away.
@export var lose_range: float = 28.0
## Close enough to stand up and swing.
@export var reach: float = 2.3

@export_group("Movement")
## Tallest step it walks up without being stopped by it. Kept below the body's
## own radius, as the sweep needs room to put it down again.
@export var step_height: float = 0.45
## How far ahead that sweep reaches. Must exceed the body's radius.
@export var step_probe: float = 0.6
@export var prowl_speed: float = 1.9
@export var charge_speed: float = 7.2
@export var acceleration: float = 22.0
@export var turn_speed: float = 9.0
## How far from where it started it will wander.
@export var prowl_radius: float = 9.0

@export_group("Health")
@export var max_health: float = 100.0
## Taken off per cut. Losing limbs is what kills it; this is the readout.
@export var damage_per_hit: float = 26.0
## How high over its head the bar sits.
@export var bar_height: float = 2.15

@export_group("Combat")
@export var swipe_interval: float = 1.1
## Losing this many limbs puts it down.
@export var limbs_before_death: int = 4
@export var flee_speed: float = 5.6
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


func _ready() -> void:
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
	_swipe_timer = maxf(_swipe_timer - delta, 0.0)

	_think(delta)
	# Up a kerb or a stair rather than into it. A hunter that loses you to six
	# greybox steps is not hunting you.
	StepUp.climb(self, delta, step_height, step_probe)
	move_and_slide()
	_watch_for_snags(delta)
	_take_hits()


func _process(delta: float) -> void:
	if _bar != null:
		_bar.global_position = global_position + Vector3.UP * bar_height
		# Read off `health` every frame rather than written when a hit lands:
		# the hit lands on the host, and what reaches everyone else is the
		# replicated number.
		_bar.set_fraction(health / maxf(max_health, 0.001))
	if rig == null:
		return
	var planar := Vector3(velocity.x, 0.0, velocity.z).length()
	# On all fours to cover ground, upright to fight.
	var stance := 0.0 if state == State.FIGHT else 1.0
	# A prowl is a full walk cycle, not a fraction of a sprint: measuring the
	# gait against the charge speed left it barely lifting its feet.
	rig.animate(delta, planar, planar / maxf(prowl_speed, 0.01), stance)


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
		if who == null:
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
		if who == null:
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

	if state == State.FLEE or state == State.DOWN:
		pass
	elif rig.is_disarmed():
		state = State.FLEE

	match state:
		State.PROWL:
			if distance < sight_range:
				state = State.CHASE
			else:
				_prowl(delta)
		State.CHASE:
			if distance > lose_range:
				state = State.PROWL
				_pick_prowl_target()
			elif distance < reach:
				state = State.FIGHT
			else:
				_move_towards(global_position + to_player, charge_speed, delta)
		State.FLEE:
			# Nothing left to fight with: get away and stay away.
			if quarry != null:
				_move_towards(global_position - to_player, flee_speed, delta)
		State.DOWN:
			_slow(delta)
		State.FIGHT:
			# Give a little ground back before chasing again, so it does not
			# flicker between standing and running on the edge of reach.
			if distance > reach * 1.6:
				state = State.CHASE
			else:
				_face(to_player, delta)
				_slow(delta)
				if _swipe_timer <= 0.0:
					_swipe_timer = swipe_interval
					rig.swipe()
					attacked.emit()


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
	if is_dead:
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

	health = maxf(health - damage, 0.0)
	# Who is owed for it. Kept here rather than at the call sites: this is the
	# one door every kind of damage comes through, and a tally that has to be
	# remembered separately by each weapon is a tally that will be wrong the
	# first time a weapon is added.
	if from != null:
		_threat[from.name] = float(_threat.get(from.name, 0.0)) + damage
	hurt.emit(health)

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
	if state == State.PROWL:
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
	# An empty bar over a corpse is just clutter: there is nothing left to
	# read off it, and the body is about to topple out from under it anyway.
	if _bar != null:
		_bar.hide()
	# A corpse should not go on blocking the way like a wall. Clearing its
	# layer hides it from everything else while it keeps its own mask, so it
	# still rests on the ground instead of falling through the world.
	collision_layer = 0
	died.emit()


## Takes the body out of every window at once.
##
## `queue_free()` does not replicate — it is a local decision about a local
## node — so the peer that decided has to say so out loud.
@rpc("authority", "call_local", "reliable")
func net_clear() -> void:
	queue_free()


## Topples the body over once it is dead.
func _collapse(delta: float) -> void:
	if rig == null:
		return
	var fallen := rig.rotation.x
	rig.rotation.x = lerpf(fallen, -PI * 0.5, 1.0 - exp(-6.0 * delta))
	rig.position.y = lerpf(rig.position.y, 0.35, 1.0 - exp(-6.0 * delta))


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
		rig.position.y = 0.35 - sunk * sunk * corpse_sink_depth
#endregion
