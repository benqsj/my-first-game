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
## How far away the knight is noticed: well off, so a pack comes out at him
## before he is among them (it was 11 m, and they were met rather than seen).
@export var sight_range: float = 17.0
## Once chasing, it keeps coming until the knight is this far away.
@export var lose_range: float = 28.0
## Close enough to stand up and swing.
@export var reach: float = 3.2
## How far off its claws land (measured: about 1.65 m round it, at its size);
## swiping from further, it steps in to that.
@export var claw_reach: float = 1.25
## Hurt from further off than it can see — an arrow out of the trees — it
## comes anyway, and keeps coming for this long whatever the distance.
@export var provoked_time: float = 14.0
## The pack: wolves this close to one that is hurt come too.
@export var pack_call: float = 14.0

@export_group("Pack")
## Wolves whose homes are this close (one to the next) are one pack; a pack of
## two or more has a leader — bigger, heavier — and its fall shakes the rest.
@export var pack_span: float = 22.0
@export var leader_scale: float = 1.15
@export var leader_health: float = 1.6
## The leader fallen: the share of the pack that breaks and runs to another
## pack (the rest stay, enraged: all at once, harder, faster, reckless).
@export var desert_chance: float = 0.35
@export var rage_damage: float = 1.3
@export var rage_speed: float = 1.15

@export_group("Movement")
## Tallest step it walks up without being stopped by it. Kept below the body's
## own radius, as the sweep needs room to put it down again.
@export var step_height: float = 0.45
## How far ahead that sweep reaches. Must exceed the body's radius.
@export var step_probe: float = 0.8
@export var prowl_speed: float = 1.1
@export var charge_speed: float = 6.4
## On all fours after somebody it runs faster than upright.
@export var charge_speed_on_fours: float = 8.5
@export var acceleration: float = 22.0
@export var turn_speed: float = 9.0
## How far from where it started it will wander.
@export var prowl_radius: float = 4.0

@export_group("Health")
@export var max_health: float = 160.0
## Taken off per cut. Losing limbs is what kills it; this is the readout.
@export var damage_per_hit: float = 26.0
## How high over its head the bar sits.
@export var bar_height: float = 3.2

@export_group("Combat")
@export var swipe_interval: float = 1.5
## What a swipe that lands takes off, and how far into the swipe the claws
## arrive — the player has that long to roll or raise a shield.
## Two of them are the end of Tariel (160 health, p.def 35), and of anyone.
@export var swipe_damage: float = 110.0
@export var swipe_lands_after: float = 0.58
## How long it stands open after a swipe is parried.
@export var parried_stagger: float = 1.6
## Losing this many limbs puts it down.
@export var limbs_before_death: int = 4
@export var flee_speed: float = 4.5
## How close the blade has to pass a limb to take it off, in metres.
@export var hit_tolerance: float = 1.0
## Physical defence, p.def ([Defence]): twice the imp's.
@export var p_def: float = 40.0
## Magical defence, m.def ([Defence]): a beast, little against spells and fire.
@export var m_def: float = 10.0
## Whole until its health is down to this share: before that the blade only
## wounds it, after it limbs come off.
@export_range(0.0, 1.0) var sever_below: float = 0.5
## Below that, how often a cut takes a limb; the rest only wound it. Limbs are
## not a way to finish a wolf in four quick cuts.
@export_range(0.0, 1.0) var sever_chance: float = 0.35
## Cut this many times inside `combo_window` seconds, it breaks out of the
## combo: a hop back out of it, and straight back in with a leap.
@export var combo_break_cuts: int = 3
@export var combo_window: float = 2.0
## When the cuts landed on it, for the breaking out.
var _cut_times: Array[float] = []

@export_group("Corpse")
## Seconds a body lies where it fell before it is cleared away. Long enough to
## see it land and read the kill, short enough that the ground stays clear.
@export var corpse_linger: float = 3.0
## How long it takes to fade out of sight once the linger is up.
@export var corpse_fade_time: float = 1.2
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
## Leading its pack; enraged by its leader's fall; running off to another pack.
var is_leader: bool = false
var frenzied: bool = false
var _deserting: bool = false
var _desert_to: Vector3 = Vector3.ZERO
var _missile_wait: float = 0.0
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
## A leap at him under way, and whether it found him.
var _leap_at_him: bool = false
var _leap_found: bool = false
## Open after its smash: counting down to it, then for how long.
var _open_in: float = -1.0
var _open_for: float = 0.0
var _open: float = 0.0
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
## Open to a heavier cut ([constant Recoil.RIPOSTE]): stuck a moment after its
## smash has come down, and stumbling after a leap that found nobody.
@export var open_after_slam: float = 0.7
@export var open_after_miss: float = 0.85
## Drawing off to come again at a run, face on ([method withdraw]).
@export var withdraw_speed: float = 3.0
@export var crawl_speed: float = 1.2
## The throw of a dodge, a hop back, a bite and a lunge from the ground.
@export var dodge_speed: float = 6.5
@export var hop_speed: float = 7.0
@export var bite_speed: float = 5.0
@export var ground_lunge_speed: float = 4.2

## On its beat it stops a while where it gets to, and now and then on the way,
## and looks about: seconds.
@export var linger: Vector2 = Vector2(3.0, 8.0)
## Missiles (arrows, bolts, fire) it sees coming at it: how often it gets out of
## one loosed from far off once it is after somebody, and from close in, while
## it comes at him.
@export var missile_dodge_far: float = 0.45
@export var missile_dodge_near: float = 0.3
## After getting out of one missile's way, a while before it can again — so a
## man with a bow (or spells) can bring it down.
@export var missile_dodge_rest: float = 2.0
@export var missile_near: float = 5.0
@export var missile_far: float = 10.0

## The leap at the end of a run: from how far off him it goes (metres), how
## long it gathers for, how long it is in the air, and how long before it may
## leap like that again.
@export var run_leap_range: Vector2 = Vector2(3.0, 6.5)
@export var run_leap_gather: float = 0.2
@export var run_leap_flight: float = 0.65
@export var run_leap_cooldown: float = 4.0
var _leap_wait: float = 0.0

@export_group("Running")
## A run builds: off at `run_start_speed`, and after `run_build` seconds of it
## flat out at `sprint_speed` (on all fours, `sprint_speed_on_fours`).
@export var run_start_speed: float = 4.8
@export var sprint_speed: float = 10.0
@export var sprint_speed_on_fours: float = 12.5
@export var run_build: float = 2.2
## How fast it has to be going before it strikes out of the run.
@export var run_strike_speed: float = 5.0
## How long it has been running, for the build.
var _run_for: float = 0.0
var _charged: bool = false
var _top_speed: float = 10.0
## A running blow's path stretched (or shortened) to meet him: this much, until
## `_ride_warp_until` seconds into it.
var _ride_warp: float = 1.0
var _ride_warp_until: float = -1.0

## Blows struck out of a run ([method try_run_attack]): the clip, the part of
## it played, its blows (clip time), their weight against `swipe_damage`, and
## whether one knocks a man down.
const RUN_STRIKES := {
	&"run_spin": {"clip": WolfRig.RUN_SPIN, "from": 0.12, "to": 1.75, "hits": [0.68, 1.0],
			"damage": 0.75, "heavy": false},
	&"run_axe": {"clip": WolfRig.RUN_AXE, "from": 0.6, "to": 2.45, "hits": [1.62],
			"damage": 1.3, "heavy": true},
}
## A leap under way, carried along its clip's own throw ([method WolfRig.carry]):
## where it left the ground, which way it faces, how far the throw is stretched
## to land on him; empty when not in the air.
var _flight: Dictionary = {}
## Stop this far short of him, so it lands on him rather than through him.
const LAND_SHORT := 0.9
## The clip throws itself a metre and three quarters up — a mutant's leap, not a
## wolf's. A wolf leaps low and long: this much of the height is kept.
const LEAP_HEIGHT := 0.45
## The move under way is a dodge or a hop: another missile may be got out of
## before it is over.
var _dodge_busy: bool = false

## Its fighting mind (host).
var mind: WolfMind

## The claw wave ([WolfClaw], [ClawWave]): not always — once in a while, from
## out of reach: seconds between one and the next, and from how near to how
## far off it is thrown.
@export var claw_cooldown: Vector2 = Vector2(9.0, 15.0)
@export var claw_range: Vector2 = Vector2(3.2, 11.0)
## Seconds until it may throw one again (the first a little after it notices).
var _claw_wait: float = 0.0
## Seconds left standing on its beat, looking about.
var _linger: float = 0.0
## Missiles already judged, by instance id.
var _judged: Dictionary = {}
## Out of the missile's line: its body is not there to be struck.
var _slipping: float = 0.0
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

## Its hand-to-hand, beyond the swipe (the grab and headbutt taken out at the
## user's word: it did not read): each move a clip ([WolfRig]), when in
## the clip its blows land (`hits`, clip seconds), what strikes (`parts`: the
## claws, or the head and jaws), how hard (`damage`, of `swipe_damage`), how
## fast it is played, and the stretch of the clip used (`from`, `to`). A heavy
## blow cannot be turned aside on a shield and puts a man down; the wolf keeps
## its feet through the windup of one (`armour`, of the poise a blow takes).
const MELEE := {
	&"punch": {"clip": &"WF_Punch", "hits": [0.33], "parts": "claws", "damage": 0.45,
			"rate": 1.05, "from": 0.0, "to": 0.95, "armour": 1.0},
	&"rake": {"clip": &"WF_Rake", "hits": [1.0], "parts": "claws", "damage": 0.8,
			"rate": 1.5, "from": 0.4, "to": 1.85, "armour": 1.0},
	&"combo3": {"clip": &"WF_Combo3", "hits": [0.95, 1.8, 2.62], "parts": "claws", "damage": 0.55,
			"rate": 1.45, "from": 0.35, "to": 3.25, "armour": 0.5},
	&"slam": {"clip": &"WF_Slam", "hits": [1.5], "parts": "claws", "damage": 1.3,
			"rate": 1.25, "from": 0.35, "to": 2.45, "armour": 0.35, "heavy": true},
	&"combo2": {"clip": &"WF_Combo2", "hits": [2.05, 2.95], "parts": "claws", "damage": 0.7,
			"rate": 1.4, "from": 1.1, "to": 3.6, "armour": 0.6},
}
## How long before a blow lands it stops turning after him: from here on the
## blow goes where it was aimed, and a step aside gets out of it.
const COMMIT := 0.24
## A melee blow's claws are live this long either side of the moment it lands.
const HIT_HALF := 0.13

## Poise: how much punishment it takes before a blow staggers it, open to a
## heavier cut (`Recoil.RIPOSTE`); it comes back once it is let alone.
@export var max_poise: float = 150.0
@export var poise_back: float = 45.0
@export var poise_stagger: float = 1.15
var poise: float = 150.0
var _poise_rest: float = 0.0
## The chain of blows under way (a combo from its mind): which blow of how
## many, so a man caught by all of them goes down, and one who turns the first
## aside on a shield throws it off.
var _chain: int = 0
var _chain_blow: int = 0
var _chain_len: int = 1
## On the act clock: when it stops turning after him (see `COMMIT`), and while
## a heavy move's armour holds.
var _commit_at: float = -1.0
var _armour: float = 1.0
var _strike_until: float = -1.0


func _ready() -> void:
	add_to_group(&"wolf")
	# Stood on the ground where it was put: its hill is not flattened for it.
	if Terrain.current != null:
		global_position.y = Terrain.height_under(global_position.x, global_position.z, 0.4) + 0.2
	_home = global_position
	_rng.randomize()
	_pick_prowl_target()
	# Only the host thinks. `_process` stays on everywhere — that is what
	# animates the body and moves the bar from replicated state.
	set_physics_process(_decides())
	if rig != null:
		rig.severed.connect(_on_severed)
		rig.landed.connect(_body_lands)

	_last_position = global_position
	health = max_health
	if intellect < 0.0:
		intellect = _rng.randf_range(wit_range.x, wit_range.y)
	mind = WolfMind.new(self, intellect)
	_claw_wait = _rng.randf_range(2.5, 5.0)
	if rig != null and rig.claw != null:
		rig.claw.on_release = _claw_released
	if rig != null:
		# Its coat and whether it goes on four legs or two: from its name, so the
		# same on every peer.
		rig.dress(String(name))
		rig.gait = 1.0 if absi(hash(String(name) + "/gait")) % 2 == 0 else 0.0
		if rig.gait > 0.5:
			prowl_speed *= 0.75
			charge_speed = charge_speed_on_fours
		_top_speed = sprint_speed_on_fours if rig.gait > 0.5 else sprint_speed
	# Once every wolf of the level has its home: which of each pack leads.
	_find_leader.call_deferred()
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
	_claw_wait = maxf(_claw_wait - delta, 0.0)
	_leap_wait = maxf(_leap_wait - delta, 0.0)
	_evading = maxf(_evading - delta, 0.0)
	if _slipping > 0.0:
		_slipping -= delta
		if _slipping <= 0.0 and not is_dead:
			collision_layer = 4
	_watch_missiles()
	_burst = maxf(_burst - delta, 0.0)
	_poise_rest = maxf(_poise_rest - delta, 0.0)
	if _poise_rest <= 0.0:
		poise = minf(poise + poise_back * delta, max_poise)
	if _strike_until >= 0.0:
		_strike_until -= delta
		if _strike_until < 0.0:
			_armour = 1.0
	_swipe_timer = maxf(_swipe_timer - delta, 0.0)
	_reeling = maxf(_reeling - delta, 0.0)
	_counter_armour = maxf(_counter_armour - delta, 0.0)
	_provoked = maxf(_provoked - delta, 0.0)
	_missile_wait = maxf(_missile_wait - delta, 0.0)
	if _open_in >= 0.0:
		_open_in -= delta
		if _open_in < 0.0:
			_open = _open_for
	_open = maxf(_open - delta, 0.0)
	if _pounce_in >= 0.0:
		_pounce_in -= delta
		if _pounce_in < 0.0 and not is_dead:
			# Carried through the leap, not stopped by its own feet: the leap
			# itself is the clip's throw ([method _fly]).
			_burst = 0.4
	if _swipe_lands >= 0.0:
		_swipe_lands -= delta
		if _swipe_lands < 0.0:
			_land_swipe()
			_pouncing = false

	_charged = false
	_think(delta)
	_fly(delta)
	_ride(delta)
	if not _charged:
		_run_for = maxf(_run_for - 3.0 * delta, 0.0)
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
		var gone := (_corpse_age - corpse_linger) / maxf(corpse_fade_time, 0.001)
		if gone > 0.0 and rig != null:
			rig.fade(smoothstep(0.0, 1.0, minf(gone, 1.0)))
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
	# Standing about on its beat, it looks about.
	var looking := 1.0 if state == State.PROWL and planar < 0.2 and not is_dead else 0.0
	rig.look_about = lerpf(rig.look_about, looking, 1.0 - exp(-2.0 * delta))
	if is_dead:
		planar = 0.0
	_reel_clock += delta
	var reeling := _reel_clock < Recoil.STAGGER and not is_dead
	if reeling:
		# Thrown back up on its hind legs by the parry.
		stance = 0.0
	# A prowl is a full walk cycle, not a fraction of a sprint: measuring the
	# gait against the charge speed left it barely lifting its feet.
	if _pose_now(delta):
		rig.animate(_pose_delta, planar, planar / maxf(prowl_speed, 0.01), stance)
		_pose_delta = 0.0
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

	# Its leader fallen, off to another pack: it runs there and is one of them.
	if _deserting:
		_desert(delta)
		return
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
			elif try_run_attack(distance):
				# Nearly on him at a run: a blow out of it, or a leap.
				pass
			elif distance < fight_from() and not (_run_attack_ready() and distance > 2.6):
				state = State.FIGHT
				_fighting = quarry
				mind.engage(quarry)
			elif can_claw(distance) and _rng.randf() < delta * (0.35 + 0.4 * intellect):
				# Kept at a distance, it throws the claws' cut at him.
				attack(&"claw_wave")
			elif _busy > 0.0:
				if rig.is_clawing():
					_face(to_player, delta)
					_slow(delta)
				# Thrown aside out of a missile's way: let it carry.
				elif _burst <= 0.0:
					_slow(delta)
			elif rig.is_crippled():
				_move_towards(global_position + to_player, crawl_speed, delta)
			else:
				charge_at(to_player, delta)
		State.FLEE:
			# Nothing left to fight with: get away and stay away.
			if quarry != null:
				_move_towards(global_position - to_player, flee_speed, delta)
		State.DOWN:
			_slow(delta)
		State.FIGHT:
			# Well out of it: after him again, on all fours.
			var keeps := 2.0 if mind != null and mind.tactic == WolfMind.Tactic.SHOOT else 1.6
			if quarry == null or distance > fight_from() * keeps:
				state = State.CHASE
			else:
				_fighting = quarry
				mind.fight(delta, quarry, to_player, distance)
				# A throw it is in the middle of carries it; otherwise a move
				# of its own lets it come to a stop.
				if _busy > 0.0 and _burst <= 0.0 and not rig.is_swiping():
					_slow(delta)
				# No step in under a blow any more: the body goes where the
				# clip's own feet take it ([method _ride]), or nowhere.


#region Missiles
## Arrows, bolts and fire coming at it (host). Each is judged once, the moment
## it is seen on a line that passes through it: from far off — it after somebody
## and him shooting from out of reach — it gets out of the way of most; while
## it runs at him and is nearly on him, of few. Unaware on its beat, of none.
func _watch_missiles() -> void:
	# Enraged it does not look; and a dodge wants its breath back.
	if frenzied or _missile_wait > 0.0:
		return
	if is_dead or state == State.PROWL or not can_leap() \
			or _busy > 0.0 and not winding_up() and not (_dodge_busy and _busy < 0.35):
		return
	var centre := global_position + Vector3.UP * 0.9
	for node in get_tree().get_nodes_in_group(&"missile"):
		var id := node.get_instance_id()
		if _judged.has(id) or not node.has_method("flight"):
			continue
		var flight: Array = node.call("flight")
		if flight.is_empty():
			continue
		var at: Vector3 = flight[0]
		var going: Vector3 = flight[1]
		var shooter: Node3D = null
		if flight.size() > 2 and is_instance_valid(flight[2]):
			shooter = flight[2] as Node3D
		var speed2 := going.length_squared()
		if speed2 < 1.0:
			continue
		var when := (centre - at).dot(going) / speed2
		if when < 0.0 or when > 0.9:
			continue
		var miss := (at + going * when).distance_to(centre)
		if miss > 1.3:
			continue
		_judged[id] = true
		var from := shooter.global_position.distance_to(global_position) if shooter != null \
				else at.distance_to(global_position)
		var far := clampf((from - missile_near) / maxf(missile_far - missile_near, 0.1), 0.0, 1.0)
		var chance := lerpf(missile_dodge_near, missile_dodge_far, far) * lerpf(0.8, 1.15, intellect)
		if _rng.randf() >= chance:
			continue
		# Aside from its line, whichever way is shorter.
		var line := Vector3(going.x, 0.0, going.z).normalized()
		var aside := line.cross(Vector3.UP)
		var off := (centre - at) - going.normalized() * (centre - at).dot(going.normalized())
		if off.dot(aside) < 0.0 or (off.length() < 0.2 and _rng.randf() < 0.5):
			aside = -aside
		attack(&"dodge_right" if aside.dot(global_transform.basis.x) > 0.0 else &"dodge_left", aside)
		# Out of the line before it arrives: the shaft finds nothing there.
		_slipping = 0.35
		_missile_wait = missile_dodge_rest
		collision_layer = 0
		return
	if _judged.size() > 64:
		_judged.clear()
#endregion


#region What the mind can make it do
## How close it has to be before it fights rather than chases: near enough to
## circle and to leap.
func fight_from() -> float:
	return 5.8 if not rig.is_crippled() else 3.8


## Close enough for the claws, after the step in.
func strike_range() -> float:
	return claw_reach + 0.45


## From how far `move` is thrown so that its own steps in bring it chest to
## chest with him as the first blow lands — no further (it would come up
## short and tread air), no nearer (it would tread on the spot against him).
func reach_of(move: StringName) -> float:
	if rig == null:
		return strike_range()
	var clip := &""
	var from := 0.0
	var hit := -1.0
	if MELEE.has(move):
		clip = MELEE[move]["clip"]
		from = MELEE[move]["from"]
		hit = (MELEE[move]["hits"] as Array)[0]
	elif move == &"swipe":
		clip = WolfRig.SWIPE_L
		from = maxf(rig.strike_time(clip) - rig.swipe_duration * rig.swipe_windup, 0.0)
	elif move == &"bite":
		clip = WolfRig.BITE
		from = maxf(rig.strike_time(clip) - 0.4, 0.0)
	else:
		return strike_range()
	var on := -rig.travel_between(clip, from, hit if hit >= 0.0 else rig.strike_time(clip)).z
	return maxf(strike_range(), CONTACT + on)


## From how far a pounce carries it on to him.
func pounce_range() -> float:
	return 5.6


func lunge_range() -> float:
	return 2.6


func is_crippled() -> bool:
	return rig != null and rig.is_crippled()


func is_busy() -> bool:
	return _busy > 0.0 or _reeling > 0.0


## Out of the way of a blow or a missile right now: a mage's bolt shaken off by
## it flies on straight instead of coming round after it ([SpellBolt]).
func is_evading() -> bool:
	return _evading > 0.0 or _slipping > 0.0


## Through the air along the leap its clip makes: the clip's throw off the
## ground, forward and up, stretched to come down on him (motion warping, as a
## souls-like does it). Before the clip leaves the ground the body is left to
## whatever carries it (a run keeps running into the gather); from the moment
## it does, the body is where the throw says, and nothing else steers it.
func _fly(delta: float) -> void:
	if rig == null or is_dead:
		_flight.clear()
		return
	var now := rig.carry()
	if now.is_empty():
		_land()
		return
	var throw: Dictionary = now["carry"]
	var time: float = now["time"]
	if time < float(throw["off"]):
		return
	if time > float(throw["land"]):
		_land(true)
		return
	if _flight.is_empty() or _flight.get("clip") != now["clip"]:
		_take_off(now["clip"], throw)
	var at := WolfRig.carry_at(throw, time)
	var basis: Basis = _flight["basis"]
	var from: Vector3 = _flight["from"]
	var ahead := basis * Vector3(0.0, 0.0, -(at.x - float(_flight["fwd0"])) * float(_flight["warp"]))
	var target := from + ahead + basis * Vector3(0.0, at.y * LEAP_HEIGHT, 0.0)
	# Where the ground has gone while it was in the air, eased in by the landing.
	var fall := Terrain.height(target.x, target.z) - Terrain.height(from.x, from.z)
	var span := maxf(float(throw["land"]) - float(throw["off"]), 0.01)
	target.y += fall * clampf((time - float(throw["off"])) / span, 0.0, 1.0)
	velocity = ((target - global_position) / maxf(delta, 0.001)).limit_length(30.0)
	_burst = maxf(_burst, 0.1)


## In the air on a leap, or gathering for one.
func is_leaping() -> bool:
	return not _flight.is_empty() or (rig != null and rig.is_leaping())


func _take_off(clip: StringName, throw: Dictionary) -> void:
	var ahead := -global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var fwd: PackedFloat32Array = throw["fwd"]
	var fwd0 := WolfRig.carry_at(throw, float(throw["off"])).x
	var across := WolfRig.carry_at(throw, float(throw["land"])).x - fwd0
	var basis := Basis(Vector3.UP, atan2(-ahead.x, -ahead.z)).scaled(global_transform.basis.get_scale())
	var clip_reach := (basis * Vector3(0.0, 0.0, across)).length()
	var warp := 1.0
	var quarry := _quarry()
	if quarry != null:
		var to := quarry.global_position - global_position
		to.y = 0.0
		# A leap forward (a pounce, a leap out of a run) is aimed at him however
		# it was turned; only a hop back keeps to the way it faces.
		if to.length() > 0.1 and (across > 0.0 or to.normalized().dot(ahead) > 0.3):
			ahead = to.normalized()
			rotation.y = atan2(-ahead.x, -ahead.z)
			basis = Basis(Vector3.UP, rotation.y).scaled(global_transform.basis.get_scale())
			warp = clampf((to.length() - LAND_SHORT) / maxf(clip_reach, 0.1), 0.35, 2.6)
	_flight = {"clip": clip, "from": global_position, "basis": basis, "warp": warp, "fwd0": fwd0}
	floor_snap_length = 0.0
	if fwd.is_empty():
		_flight.clear()


func _land(came_down: bool = false) -> void:
	if _flight.is_empty():
		return
	_flight.clear()
	if _leap_at_him and _decides() and not is_dead:
		_leap_at_him = false
		# Only a leap that came down where it was going, not one broken off.
		if came_down and not _leap_found and not is_crippled():
			# Nobody there: it comes down off balance, open a moment.
			_stumble(open_after_miss)
	floor_snap_length = 0.1
	# Down the rest of the way at once: the clip's own landing is steep, and a
	# body left a hand's breadth up would float down on gravity alone.
	# Its feet stop where it lands: no sliding on after it.
	velocity = Vector3(0.0, minf(velocity.y, 0.0 if is_on_floor() else -7.0), 0.0)


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


## At a run, and faster the longer it runs: off at `run_start_speed`, up to
## its sprint after `run_build` seconds.
func charge_at(direction: Vector3, delta: float) -> void:
	if charge_speed <= 0.0:
		# Told not to charge (a test holding it where it is).
		_slow(delta)
		return
	_charged = true
	_run_for += delta
	var speed := lerpf(run_start_speed, _top_speed, smoothstep(0.0, 1.0, _run_for / maxf(run_build, 0.01)))
	_move_towards(global_position + direction, speed, delta)
	# Held up (scenery, a turn): the run starts over.
	var planar := Vector3(velocity.x, 0.0, velocity.z).length()
	if planar < run_start_speed * 0.5:
		_run_for = minf(_run_for, 0.3)


## Whatever move is playing carries the body exactly as far as the clip's own
## feet go ([method WolfRig.ride]) — a stagger stumbles back, a combo steps in,
## a blow thrown standing stays standing. Nothing skates.
func _ride(delta: float) -> void:
	if rig == null or is_dead or not _flight.is_empty():
		return
	var along: Variant = rig.ride()
	if along == null:
		_ride_warp_until = -1.0
		_ride_clip = &""
		return
	var clip := StringName(rig.playing())
	if clip != _ride_clip:
		_ride_clip = clip
		_ride_short = _short_of_him(clip)
	var warp := _ride_short
	if _ride_warp_until > 0.0:
		_ride_warp_until -= delta
		warp = _ride_warp
	var world: Vector3 = global_transform.basis.orthonormalized() * (along as Vector3) * warp
	velocity.x = world.x
	velocity.z = world.z


## Going at a run (building one or flat out).
func is_running() -> bool:
	return _run_for > 0.0 and Vector3(velocity.x, 0.0, velocity.z).length() > rig.run_from


var _ride_clip: StringName = &""
var _ride_short: float = 1.0
## Chest to chest with him: closer than this a move's steps in would only
## shove against him, feet treading on the spot.
const CONTACT := 1.15


## How much of a move's own step towards him it takes, so that it stops
## chest to chest rather than stepping on into him: all of it when there is
## room, less when he is close, none when it is already on him.
func _short_of_him(clip: StringName) -> float:
	var quarry := _quarry()
	if quarry == null or rig == null:
		return 1.0
	var to := quarry.global_position - global_position
	to.y = 0.0
	var gap := to.length()
	if gap < 0.01:
		return 0.0
	var now := rig.playing_position()
	var ahead := global_transform.basis.orthonormalized() * rig.travel_between(clip, now, now + 10.0)
	var towards := ahead.dot(to / gap)
	if towards < 0.2:
		return 1.0
	return clampf((gap - CONTACT) / towards, 0.0, 1.0)


## Fast enough, legs and a paw under it, and the wait since the last one over.
func _run_attack_ready() -> bool:
	if _leap_wait > 0.0 or _busy > 0.0 or not can_leap() or arms_left() == 0 or rig.is_clawing():
		return false
	return Vector3(velocity.x, 0.0, velocity.z).length() >= run_strike_speed


## Out of a run, at `distance` from him: whichever of its running blows fits
## that distance (the spinning rake, the leaping smash, the pounce), if any.
func try_run_attack(distance: float) -> bool:
	if not _run_attack_ready():
		return false
	var fits: Array[StringName] = []
	if distance >= run_leap_range.x and distance <= run_leap_range.y:
		fits.append(&"run_leap")
	for move: StringName in RUN_STRIKES:
		var window := run_window(move)
		if distance >= window.x and distance <= window.y:
			fits.append(move)
			if move == &"run_spin":
				fits.append(move)
	if fits.is_empty():
		return false
	attack(fits[_rng.randi() % fits.size()])
	return true


## How far off it can be for a running blow to land: the clip's travel to its
## first blow, stretched from three quarters to half as much again, plus the
## claws' reach; for the smash, the run up to its leap and the leap stretched.
func run_window(move: StringName) -> Vector2:
	var spec: Dictionary = RUN_STRIKES[move]
	var clip: StringName = spec["clip"]
	var from: float = spec["from"]
	var hit: float = (spec["hits"] as Array)[0]
	if rig == null or not rig.has_clip(clip):
		return Vector2(INF, -INF)
	var throw: Dictionary = rig.throw_of(clip)
	if throw.is_empty():
		var d := rig.travel_between(clip, from, hit).length()
		return Vector2(claw_reach + 0.75 * d, claw_reach + 1.5 * d)
	var planar := Vector3(velocity.x, 0.0, velocity.z).length()
	var run_up := planar * maxf(float(throw["off"]) - from, 0.0) / _run_rate(clip, from)
	var reach := rig.travel_between(clip, float(throw["off"]), float(throw["land"])).length()
	return Vector2(run_up + LAND_SHORT + 0.6 * reach, run_up + LAND_SHORT + 1.8 * reach)


## How fast a running blow's clip is played: its run-in matched to the run
## it comes out of, within reason.
func _run_rate(clip: StringName, from: float) -> float:
	var clip_speed := rig.travel_between(clip, from, from + 0.2).length() / 0.2
	var planar := Vector3(velocity.x, 0.0, velocity.z).length()
	return clampf(planar / maxf(clip_speed, 0.5), 1.0, 1.5)


func _run_strike(move: StringName) -> void:
	var spec: Dictionary = RUN_STRIKES[move]
	var clip: StringName = spec["clip"]
	var from: float = spec["from"]
	var hits: Array = spec["hits"]
	var rate := _run_rate(clip, from)
	var length := (float(spec["to"]) - from) / rate
	_swipe_count += 1
	_break_off()
	_leap_wait = run_leap_cooldown
	_busy = length
	_strike_until = length
	_armour = 0.7
	var heavy := bool(spec["heavy"])
	var throw: Dictionary = rig.throw_of(clip)
	if throw.is_empty():
		# On the ground: its path stretched to bring the first blow onto him.
		var quarry := _quarry()
		var d := rig.travel_between(clip, from, float(hits[0])).length()
		if quarry != null and d > 0.1:
			var gap := Vector3(quarry.global_position.x - global_position.x, 0.0,
					quarry.global_position.z - global_position.z).length()
			_ride_warp = clampf((gap - claw_reach) / d, 0.6, 1.6)
			_ride_warp_until = (float(hits[0]) - from) / rate
	else:
		# The run carries it into the leap; the leap is the clip's throw.
		_burst = (float(throw["off"]) - from) / rate + 0.05
	rig.run_strike(clip, rate, from, length, hits)
	net_run_strike.rpc(move, rate)
	_attack_clock = 0.0
	_sweeps.clear()
	_commit_at = (float(hits[0]) - from) / rate - COMMIT
	var serial := _swipe_count
	var hurt_by: float = float(spec["damage"]) * swipe_damage
	_chain += 1
	var chain := _chain
	for i in hits.size():
		var at := (float(hits[i]) - from) / rate
		# A spin's two rakes are not a combo that puts him down; the smash is.
		var blows := 1 if heavy else 3
		var blow := i
		_sweeps.append(WeaponSweep.blow(_claw_parts.bind(false), 2.0, at - HIT_HALF, at + HIT_HALF, serial,
				func(who: Node3D) -> void:
					if not is_dead and rig != null:
						rig.hitstop(0.09 if heavy else 0.06)
						who.call("receive_blow", hurt_by, self, mini(blow, blows - 1), blows, chain)))
	attacked.emit()


@rpc("authority", "call_remote", "unreliable")
func net_run_strike(move: StringName, rate: float) -> void:
	if rig == null or is_dead or not RUN_STRIKES.has(move):
		return
	var spec: Dictionary = RUN_STRIKES[move]
	rig.run_strike(spec["clip"], rate, spec["from"], (float(spec["to"]) - float(spec["from"])) / rate, spec["hits"])


#region The pack and its leader
## The pack it belongs to: every living wolf whose home is near its own.
func pack() -> Array[Wolf]:
	var out: Array[Wolf] = []
	if not is_inside_tree() or is_dead:
		return out
	var all: Array[Wolf] = []
	for node in get_tree().get_nodes_in_group(&"wolf"):
		var w := node as Wolf
		if w != null and not w.is_dead:
			all.append(w)
	# Everyone reachable home to home within `pack_span`: the same set whichever
	# of them asks.
	out.append(self)
	var i := 0
	while i < out.size():
		for w in all:
			if not out.has(w) and w._home.distance_to(out[i]._home) <= pack_span:
				out.append(w)
		i += 1
	return out


## Which of the pack leads: the same on every peer (by its path), a pack of
## two or more. The leader is bigger and harder to bring down.
func _find_leader() -> void:
	var mates := pack()
	if mates.size() < 2 or is_leader:
		return
	var first: Wolf = null
	for w in mates:
		if w.is_leader:
			return
		if first == null or String(w.get_path()) < String(first.get_path()):
			first = w
	if first == self:
		is_leader = true
		var body := get_node_or_null(^"Visuals") as Node3D
		if body != null:
			body.scale *= leader_scale
		max_health *= leader_health
		health = max_health
		if intellect < 0.8:
			intellect = 0.8
			if mind != null:
				mind.intellect = 0.8


## The leader down: every one of its pack is shaken — a stagger where it stands
## — and then either breaks and runs to another pack, or stays, enraged.
func _leader_fell() -> void:
	for w in pack():
		if w != self:
			w._lose_leader()


func _lose_leader() -> void:
	if is_dead:
		return
	if not is_crippled():
		_stumble(0.9)
	if rig != null and body_has_growl():
		Sfx.play(self, WolfRig.GROWL, null, global_position + Vector3.UP, 0.8, -6.0)
	var other := _other_pack()
	if other.x < INF and _rng.randf() < desert_chance and not is_crippled():
		_deserting = true
		_desert_to = other
		state = State.CHASE
		_provoked = 0.0
		_threat.clear()
		if mind != null:
			mind._release()
			mind._release_shot()
		return
	_enrage()


func body_has_growl() -> bool:
	return ResourceLoader.exists(WolfRig.GROWL)


## Enraged: every one of them at him at once (no turns to wait), no drawing
## off or standing back to throw, blows harder, faster on its feet — and
## reckless: it no longer gets out of an arrow's way.
func _enrage() -> void:
	if frenzied:
		return
	frenzied = true
	swipe_damage *= rage_damage
	fight_speed *= rage_speed
	charge_speed *= rage_speed
	run_start_speed *= rage_speed
	_top_speed *= rage_speed
	if rig != null and rig._eye_mat != null:
		rig._eye_base *= 2.5
	if mind != null:
		mind._release_shot()
		mind._begin(WolfMind.Tactic.CLOSE)


## The home of the nearest other pack (INF if there is none).
func _other_pack() -> Vector3:
	var best := Vector3(INF, INF, INF)
	var best_d := INF
	for node in get_tree().get_nodes_in_group(&"wolf"):
		var w := node as Wolf
		if w == null or w.is_dead or w._home.distance_to(_home) <= pack_span * 1.5:
			continue
		var d := w._home.distance_to(global_position)
		if d < best_d and d < 260.0:
			best_d = d
			best = w._home
	return best


func _desert(delta: float) -> void:
	var to := _desert_to - global_position
	to.y = 0.0
	if to.length() < 4.0:
		# Among the others now: one of that pack.
		_deserting = false
		_home = _desert_to + Vector3(_rng.randf_range(-3.0, 3.0), 0.0, _rng.randf_range(-3.0, 3.0))
		state = State.PROWL
		_pick_prowl_target()
		return
	charge_at(to.normalized(), delta)
#endregion


## Sooner ready to throw the claws' cut again ([method WolfMind] standing off).
func hurry_claw(wait: float) -> void:
	_claw_wait = minf(_claw_wait, wait)


## Knocked off balance: it staggers, open to a heavier cut, for `seconds`.
func _stumble(seconds: float) -> void:
	_reeling = seconds
	_busy = maxf(_busy, seconds)
	_swipe_timer = maxf(_swipe_timer, seconds)
	if rig != null:
		rig.reel(seconds)
	net_stumble.rpc(seconds)


@rpc("authority", "call_remote", "unreliable")
func net_stumble(seconds: float) -> void:
	if rig != null and not is_dead:
		rig.reel(seconds)


## Round him, face on.
func strafe(direction: Vector3, look: Vector3, delta: float) -> void:
	_face(look, delta)
	_steer(direction * circle_speed, delta)


## Drawing off a way, face on, slantwise (`aside`): back and to one side at a
## trot, to come again at a run.
func withdraw(towards: Vector3, aside: Vector3, delta: float) -> void:
	_face(towards, delta)
	_steer((-towards * 0.8 + aside * 0.6).normalized() * withdraw_speed, delta)


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
func attack(move: StringName, aside: Vector3 = Vector3.ZERO, delay: float = 0.0) -> void:
	if is_dead or rig == null:
		return
	if MELEE.has(move):
		if arms_left() == 0 and String(MELEE[move]["parts"]) == "claws":
			return
		_melee(move, delay)
		net_melee.rpc(move, delay)
		return
	if RUN_STRIKES.has(move):
		if arms_left() == 0:
			return
		_run_strike(move)
		return
	var ahead := -global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	_dodge_busy = move == &"dodge_left" or move == &"dodge_right" or move == &"hop"
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
			_leap_at_him = true
			_leap_found = false
			rig.lunge()
			net_lunge.rpc()
			var leap := rig.lunge_duration * rig.lunge_windup
			_arm_claws(Vector2(leap - 0.02, leap + 0.4), true)
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
		&"run_leap":
			_swipe_count += 1
			_break_off()
			_leap_wait = run_leap_cooldown
			_busy = run_leap_gather + run_leap_flight + 0.35
			# Carried on by its run through the gather, and by the leap after.
			_burst = run_leap_gather + run_leap_flight
			# The leap itself is the clip's throw ([method _fly]).
			rig.run_leap(run_leap_gather, run_leap_flight)
			_leap_at_him = true
			_leap_found = false
			net_move.rpc(move)
			_arm_claws(Vector2(run_leap_gather, run_leap_gather + run_leap_flight + 0.15), true)
			attacked.emit()
		&"claw_wave":
			if not can_claw(-1.0):
				return
			var moves := claw_combo()
			var tell := lerpf(0.85, 0.55, intellect)
			_break_off()
			_busy = WolfClaw.duration(moves, tell)
			_claw_wait = _rng.randf_range(claw_cooldown.x, claw_cooldown.y) * lerpf(1.2, 0.8, intellect)
			rig.claw.begin(moves, tell)
			net_claw.rpc(moves, tell)
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
			if aside.length_squared() > 0.01:
				across = aside.normalized()
			velocity = across * dodge_speed
			_burst = 0.3
			_sweeps.clear()


## Whatever attack it was winding up, dropped.
## A chain of blows begins: `blows` of them, all in one combo.
func begin_chain(blows: int) -> void:
	_chain += 1
	_chain_blow = 0
	_chain_len = maxi(blows, 1)


## How many blows a move throws, for its chain.
static func blows_in(move: StringName) -> int:
	if MELEE.has(move):
		return (MELEE[move]["hits"] as Array).size()
	if move == &"hop" or move.begins_with("dodge") or move == &"claw_wave":
		return 0
	return 1


## A hand-to-hand move ([constant MELEE]): the clip, its blows on the act
## clock, and — if `delay` — a hold at the top of the windup before the first.
func _melee(move: StringName, delay: float) -> void:
	var spec: Dictionary = MELEE[move]
	var rate: float = spec["rate"]
	var from: float = spec["from"]
	var hits: Array = spec["hits"]
	var first: float = (float(hits[0]) - from) / rate
	var length := (float(spec["to"]) - from) / rate + delay
	if move == &"slam":
		# The smash come down: its claws in the ground a moment, open.
		_open_in = first + delay + HIT_HALF
		_open_for = length - _open_in + open_after_slam
		length += open_after_slam
	_swipe_count += 1
	_break_off()
	_busy = length
	_strike_until = length
	_armour = float(spec["armour"])
	# The hold: just short of the first blow.
	var hold_at := float(hits[0]) - HIT_HALF * rate * 1.6 if delay > 0.0 else -1.0
	rig.melee(StringName(spec["clip"]), rate, from, length, hold_at, delay, hits)
	_attack_clock = 0.0
	_sweeps.clear()
	_commit_at = first + delay - COMMIT
	var serial := _swipe_count
	var heavy := bool(spec.get("heavy", false))
	var jaws := String(spec["parts"]) == "jaws"
	var hurt_by: float = float(spec["damage"]) * swipe_damage
	for i in hits.size():
		var at := (float(hits[i]) - from) / rate + delay
		var blow := _chain_blow
		_chain_blow += 1
		var chain := _chain
		var blows := 1 if heavy else maxi(_chain_len, 2)
		_sweeps.append(WeaponSweep.blow(
				(func() -> Array: return rig.claw_parts(false, true)) if jaws else _claw_parts.bind(false),
				2.0, at - HIT_HALF, at + HIT_HALF, serial,
				func(who: Node3D) -> void:
					if not is_dead and rig != null:
						rig.hitstop(0.08 if heavy else 0.05)
						who.call("receive_blow", hurt_by, self, mini(blow, blows - 1), blows, chain)))
	attacked.emit()


## A hand-to-hand move, on the peers that did not decide it.
@rpc("authority", "call_remote", "unreliable")
func net_melee(move: StringName, delay: float) -> void:
	if rig == null or is_dead or not MELEE.has(move):
		return
	var spec: Dictionary = MELEE[move]
	var rate: float = spec["rate"]
	var from: float = spec["from"]
	var hits: Array = spec["hits"]
	var hold_at := float(hits[0]) - HIT_HALF * rate * 1.6 if delay > 0.0 else -1.0
	var length := (float(spec["to"]) - from) / rate + delay + (open_after_slam if move == &"slam" else 0.0)
	rig.melee(StringName(spec["clip"]), rate, from, length, hold_at, delay, hits)


## Still turning after him: until a blow is committed (see `COMMIT`).
func tracking() -> bool:
	# A leap: aimed as it leaves the ground, and not turned in the air or while
	# it gathers itself after landing — got out of, it comes down where it was
	# going, and only turns once it is up again.
	if not _flight.is_empty():
		return false
	var now := rig.carry() if rig != null else {}
	if not now.is_empty() and float(now["time"]) >= float((now["carry"] as Dictionary)["off"]) - 0.12:
		return false
	if rig != null and rig.is_striking():
		return _attack_clock < _commit_at
	if rig != null and rig.is_swiping():
		return _swipe_lands > COMMIT
	return true


func _break_off() -> void:
	if rig != null and rig.claw != null:
		rig.claw.cancel()
	_swipe_lands = -1.0
	_pounce_in = -1.0
	_pouncing = false
	_swipe_timer = 0.0
	_sweeps.clear()
	_strike_until = -1.0
	_armour = 1.0


#region Claw wave
## Whether it may throw a claw wave now, at a quarry `gap` metres off (below
## zero: whatever the distance): both arms and both legs, its clips there, not
## busy, and the wait since the last one over.
func can_claw(gap: float) -> bool:
	if rig == null or rig.claw == null or not rig.claw.has_clips() or is_dead:
		return false
	if is_crippled() or arms_left() < 2 or _reeling > 0.0 or _claw_wait > 0.0 or rig.is_clawing():
		return false
	return gap < 0.0 or (gap >= claw_range.x and gap <= claw_range.y)


## The blows it throws, as many as its wit runs to ([method WolfMind.combo_max]):
## the rake always first — the one with the long tell — then the sweep or the
## slam, and a clever one all three.
func claw_combo() -> Array[StringName]:
	var most := mind.combo_max() if mind != null else 1
	var out: Array[StringName] = [&"rake"]
	if most >= 3:
		out.append_array([&"sweep", &"slam"])
	elif most == 2:
		out.append(&"slam" if _rng.randf() < 0.4 else &"sweep")
	return out


## The wave leaving the paw, on every peer: the host's is the one that hurts.
## At its quarry if he is anywhere ahead of it, else straight ahead.
func _claw_released(_blow: StringName, spec: Dictionary) -> void:
	if is_dead:
		return
	var dir := -global_transform.basis.z
	dir.y = 0.0
	dir = dir.normalized()
	# As big as the wolf that throws it, from as high as its paw.
	var big := _size()
	var ground := bool(spec.get("ground", false))
	var quarry := _quarry() if _decides() else _nearest_player()
	var aim := dir
	if quarry != null:
		var at_him := quarry.global_position - global_position
		at_him.y = 0.0
		if at_him.length_squared() > 0.01 and at_him.normalized().dot(dir) > 0.5:
			dir = at_him.normalized()
	var from := global_position + dir * 0.8 * big + Vector3.UP * float(spec.get("height", 1.0)) * big
	aim = dir
	if quarry != null and (quarry.global_position - global_position).normalized().dot(dir) > 0.5:
		# Up at him on the ledge, down at him below: at his chest, not level.
		aim = (quarry.global_position + Vector3.UP * 1.0 - from).normalized()
	var world := Blood.world_of(self)
	if world == null:
		world = get_parent()
	ClawWave.throw(world, from, dir if ground else aim, deg_to_rad(float(spec.get("roll", 0.0))),
			float(spec.get("size", 1.0)) * big, ground, _decides(), self, float(spec.get("damage", 30.0)))
	if bool(spec.get("ground", false)):
		WindBlast.shake(self, 0.1, 0.3, 16.0)


## A claw wave, on the peers that did not decide it.
@rpc("authority", "call_remote", "reliable")
func net_claw(moves: Array, tell: float) -> void:
	if rig == null or rig.claw == null or is_dead:
		return
	var list: Array[StringName] = []
	for m in moves:
		list.append(StringName(m))
	rig.claw.begin(list, tell)
#endregion


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
		&"run_leap":
			rig.run_leap(run_leap_gather, run_leap_flight)
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
	# One blow of the chain it is throwing (a lone swipe: the first of two, a
	# flinch, never a knockdown). In a chain it is a lighter blow than alone.
	var blow := _chain_blow
	_chain_blow += 1
	var blows := maxi(_chain_len, 2)
	var chain := _chain if _chain_len > 1 else serial
	var hurt_by := swipe_damage * (0.72 if _chain_len > 1 else 1.0)
	_sweeps.append(WeaponSweep.blow(_claw_parts.bind(pounce), 2.5, live.x, live.y, serial,
			func(who: Node3D) -> void:
				if not is_dead and rig != null:
					rig.hitstop(0.05)
					if pounce:
						_leap_found = true
					who.call("receive_blow", hurt_by, self, mini(blow, blows - 1), blows, chain)))


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
	if is_dead or who == null or not _decides() or _deserting:
		return
	_provoked = provoked_time
	if not _threat.has(who.name):
		_threat[who.name] = 0.01
	if state == State.PROWL or state == State.FIGHT and _quarry() != who:
		state = State.CHASE


func is_reeling() -> bool:
	return _reeling > 0.0


func _prowl(delta: float) -> void:
	if _linger > 0.0:
		_linger -= delta
		_slow(delta)
		return
	var to_target := _prowl_target - global_position
	to_target.y = 0.0
	if to_target.length() < 1.0 or _prowl_timer <= 0.0:
		# Got there: it stands a while and looks about before it moves on.
		_linger = _rng.randf_range(linger.x, linger.y)
		_pick_prowl_target()
		return
	# And now and then it stops on the way.
	if _rng.randf() < delta * 0.08:
		_linger = _rng.randf_range(linger.x * 0.5, linger.y * 0.6)
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
		var edge := _within_reach(knight.cutting_edge_for(self))
		if edge.is_empty():
			continue

		if _wound(knight, edge, serial):
			if is_dead:
				return
			continue
		# Thrown the way the blade was going: the limb, and the blood after it.
		var blow := knight.rig.swing_direction((edge[1] - edge[0]).normalized() + Vector3.UP * 0.4)
		var part := rig.sever_along_edge(edge[0], edge[1], hit_tolerance, blow)
		if part == "":
			continue
		_last_hit_serial[knight.name] = serial

		_by_blade = true
		# The host decided *which* limb; everyone else is told, so the piece that
		# comes off is the same piece in every window. Re-running the geometry
		# there would disagree — their copy of the blade is in a slightly
		# different place, a frame of interpolation behind.
		net_sever.rpc(part, rig.last_cut_point, blow)
		# `net_sever` has already spilled the blood, on every peer.
		var worth := _blade_damage(knight)
		take_hit(float(worth[0]), rig.last_cut_point, blow, bool(worth[1]), false, knight)
		knight.rig.bloody()
		knight.net_blade_landed.rpc(ImpactFx.matter_of(self))
		knight.blade_hit(self, rig.last_cut_point)
		if is_dead:
			return


## Down on its belly, it lies under a cut swung at a standing man's height: the
## blade went over it and nothing was ever struck. So a wolf that is down is
## met where it lies — the edge is let down to the height of its back (a man
## cuts down at what is at his feet) before it is asked what it reached. How
## near it is along the ground is still the blade's own.
func _within_reach(edge: PackedVector3Array) -> PackedVector3Array:
	if edge.is_empty() or rig == null or not rig.is_crippled():
		return edge
	var back := global_position.y + DOWN_BACK * _size() / 1.65
	var drop := minf(edge[0].y, edge[1].y) - back
	if drop <= 0.0:
		return edge
	return PackedVector3Array([edge[0] + Vector3.DOWN * drop, edge[1] + Vector3.DOWN * drop])

## The height of its back, down on its belly (at the size in `wolf.tscn`).
const DOWN_BACK := 0.45


## Where a hero's cut is aimed at it ([StrikeAim]): its chest standing, its back
## when it is down on its belly.
func strike_point() -> Vector3:
	var k := _size() / 1.65
	return global_position + Vector3.UP * (DOWN_BACK * 0.8 if rig != null and rig.is_crippled() else 1.15) * k


## While it is above half its health (`sever_below`) the blade does not take a
## limb off: it wounds it — blood, the damage, a shove. True when that is what
## this cut was (whether or not it reached); false once limbs may come off.
func _wound(knight: Player, edge: Array, serial: int) -> bool:
	if health <= max_health * sever_below and _rng.randf() < sever_chance:
		return false
	if not rig._blade_reaches(edge[0], edge[1], hit_tolerance):
		return true
	_last_hit_serial[knight.name] = serial
	var chest := 0.35 if rig.is_crippled() else 1.1
	var at := Geometry3D.get_closest_point_to_segment(global_position + Vector3.UP * chest * _size() / 1.65, edge[0], edge[1])
	# Thrown the way the blade was going: cut from its right, it goes left.
	var cut: Vector3 = knight.rig.swing_direction((edge[1] - edge[0]).normalized() + Vector3.UP * 0.4)
	var worth := _blade_damage(knight)
	_by_blade = true
	take_hit(float(worth[0]), at, cut, bool(worth[1]), true, knight)
	knight.rig.bloody()
	knight.net_blade_landed.rpc(ImpactFx.matter_of(self))
	knight.blade_hit(self, at)
	return true


## What a hero's cut is worth to it, before its p.def: that hero's own p.atk,
## now and then a critical. [worth, critical].
func _blade_damage(knight: Player) -> Array:
	if knight != null and knight.profile != null:
		return knight.cut_worth()
	return [damage_per_hit, false]


## How long a flinch that breaks off a move holds it (seconds): long enough
## that the cut after is in before it can start another.
const FLINCH := 0.42
## How hard a blow throws its body over (radians a second, see [HitReact]): a
## cut, a critical; through armour, this share of it.
const FLINCH_CUT := 6.5
const FLINCH_CRIT := 9.0
const FLINCH_ARMOURED := 0.35
## How long, once it has had enough and turned on him, it will strike through
## his cuts (seconds): the counter takes that long to come in.
const COUNTER_ARMOUR := 1.6
var _counter_armour: float = 0.0
## The hit coming through `take_hit` now is a blade's cut (set just before).
var _by_blade: bool = false


## A blow has landed: its body thrown over the way the blow was going, and —
## unless what it is in the middle of has armour — whatever it was doing broken
## off (a cut only). That is the trade: in the middle of a cut of his, its ordinary blows
## never land; the heavy ones (the slam, the combos: see `armour` in [constant
## MELEE]), a leap, a claw wave, and the counter it throws when it has had
## enough, come through his cuts and hit him anyway. True if it broke off.
func _flinch(blow: Vector3, from: Node, critical: bool, blade: bool) -> bool:
	if rig == null or is_dead:
		return false
	var away := Vector3.ZERO
	if from is Node3D:
		away = global_position - (from as Node3D).global_position
	# Only a cut breaks it off: an arrow or a bolt only jolts it, or a volley
	# would hold it where it stands, unable to get out of the next.
	var broke := blade and _breaks_off()
	var strength := FLINCH_CRIT if critical else FLINCH_CUT
	if not broke:
		strength *= FLINCH_ARMOURED
	if broke:
		# What it was doing is over: it is taken up with the blow, and no longer.
		_break_off()
		_busy = FLINCH
		_swipe_timer = maxf(_swipe_timer, FLINCH)
	net_flinch.rpc(blow, away, strength, broke)
	return broke


## Whether a blow landing now breaks off what it is doing.
func _breaks_off() -> bool:
	if _armour < 1.0 or _counter_armour > 0.0:
		return false
	# In the air, or gathered to leave it: the leap goes where it was going.
	if not _flight.is_empty() or _pounce_in >= 0.0 or _pouncing:
		return false
	if rig.is_clawing() or rig.is_crippled() or _reeling > 0.0:
		return false
	return true


## The flinch, on every peer: the body thrown over, and if it broke off what it
## was doing, the jolt of a hit taken instead.
@rpc("authority", "call_local", "unreliable")
func net_flinch(along: Vector3, away: Vector3, strength: float, broke: bool) -> void:
	if rig == null or is_dead:
		return
	rig.flinch(along, strength, away)
	if broke:
		rig.interrupt(along, FLINCH)


## Its size against a man, for what is drawn at its wounds.
func _size() -> float:
	var body := get_node_or_null(^"Visuals") as Node3D
	return clampf(body.scale.x, 0.6, 2.5) if body != null else 1.0


## What a blow takes off its poise; at nothing it staggers — upright, open, the
## next cut into it deeper — and the poise comes back whole. Through the windup
## of a heavy move it has armour: the blow takes less, and it strikes through.
func _take_poise(damage: float) -> void:
	_poise_rest = 1.6
	poise -= damage * _armour
	if poise > 0.0 or is_dead or rig == null or rig.is_crippled():
		return
	poise = max_poise
	_break_off()
	_busy = 0.0
	_reeling = poise_stagger
	_swipe_timer = maxf(_swipe_timer, poise_stagger)
	net_reel.rpc()


## A hero's cut has landed. Too many too fast and it will not stand there and
## take them: it hops back out of the combo and comes straight back in with a
## leap.
func _count_cut() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_cut_times.append(now)
	while not _cut_times.is_empty() and now - _cut_times[0] > combo_window:
		_cut_times.remove_at(0)
	if _cut_times.size() < combo_break_cuts or not can_leap() or state != State.FIGHT or rig.is_clawing():
		return
	_cut_times.clear()
	_reeling = 0.0
	# Mostly it will not give ground: it trades, straight back at him through
	# his combo, a jab and a rake. Now and then it gets out and comes back
	# through the air.
	if mind != null and arms_left() == 2 and _rng.randf() < 0.65:
		_armour = 0.3
		_strike_until = 1.2
		# The counter goes through whatever he is still swinging: not broken off
		# by his next cut (see `_flinch`).
		_counter_armour = COUNTER_ARMOUR
		mind.counter()
		return
	attack(&"hop")
	if mind != null:
		mind.come_back_leaping()


## The limb, everywhere. The host has already taken it off its own copy, so this
## only detaches on the peers that have not — and spills the blood on all of
## them, which is the half that has to be seen.
@rpc("authority", "call_local", "reliable")
func net_sever(part: String, at: Vector3, blow: Vector3) -> void:
	if rig != null and not _decides():
		rig.detach(part, blow)
	var thrown := blow
	if thrown.length_squared() < 0.0001:
		thrown = Vector3.UP
	Blood.splatter(Blood.world_of(self), at, thrown.normalized(), self, 1.8)


## Far off and at peace, on its beat with nobody within `pose_far` metres, a
## wolf is posed one frame in three (with the time of all three): a wood of
## wolves nobody is near is not worth a full frame each. Asked afresh every
## twenty frames.
@export var pose_far: float = 30.0
var _pose_skip: int = 0
var _pose_delta: float = 0.0
var _pose_check: int = 0
var _pose_far: bool = false


func _pose_now(delta: float) -> bool:
	_pose_check -= 1
	if _pose_check <= 0:
		_pose_check = 20
		var near := _nearest_player()
		_pose_far = state == State.PROWL and not is_dead and (near == null
				or near.global_position.distance_to(global_position) > pose_far)
	_pose_delta += delta
	if _pose_far:
		_pose_skip = (_pose_skip + 1) % 3
		if _pose_skip != 0:
			return false
	return true


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
		spill: bool = true, from: Node = null, magic: bool = false) -> void:
	# Only the host decides what a hit is worth. `health` and `is_dead` are
	# replicated from here, so a client that scored one says nothing and waits to
	# be told — which is what keeps one wolf from dying twice.
	if is_dead or not _decides():
		return
	if critical:
		CombatText.mark_critical(self)

	damage = Defence.against(damage, p_def, m_def, magic)
	if _reeling > 0.0 or _open > 0.0:
		damage *= Recoil.RIPOSTE
	# Marked by the hunter, everything bites deeper.
	damage *= Afflictions.factor(self, from)
	health = maxf(health - damage, 0.0)
	if rig != null:
		# A beat of stillness only for the big ones: a string of light cuts
		# should not stutter it.
		rig.hitstop(0.09 if critical else 0.03)
	# Before its mind hears of it: a counter it decides on now must not be the
	# thing this blow breaks off.
	var broke := _flinch(blow, from, critical, _by_blade)
	_by_blade = false
	_take_poise(damage)
	# Who is owed for it. Kept here rather than at the call sites: this is the
	# one door every kind of damage comes through, and a tally that has to be
	# remembered separately by each weapon is a tally that will be wrong the
	# first time a weapon is added.
	if from != null:
		_threat[from.name] = float(_threat.get(from.name, 0.0)) + damage
	hurt.emit(health)
	if mind != null and not is_dead:
		mind.hurt()
		if from is Player:
			_count_cut()

	var thrown := blow
	if thrown.length_squared() < 0.0001:
		thrown = Vector3.UP
	# Blood for a hit that severed nothing — an arrow, most often. A hit that did
	# sever asks for `spill = false`, because `net_sever` has already bled on
	# every peer and doing it twice on the host is a darker stain there than
	# anywhere else.
	if spill:
		Blood.splatter(Blood.world_of(self), at, thrown.normalized(), self, 1.5 if critical else 1.0)
	# Moved by it, the way the blow was going — much less through a move with
	# armour, which it keeps its feet through.
	var shove := thrown
	shove.y = 0.0
	if shove.length_squared() > 0.0001:
		velocity += shove.normalized() * (6.0 if critical else 4.0) * (1.0 if broke else 0.35)

	# Cut while it runs off: it turns and fights after all.
	_deserting = false
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
	if is_leader and _decides():
		_leader_fell()
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
	damage = Defence.taken(damage, m_def) * Afflictions.factor(self, from)
	health = maxf(health - damage, 0.0)
	if from != null and is_instance_valid(from):
		_threat[from.name] = float(_threat.get(from.name, 0.0)) + damage
		provoke(from)
	hurt.emit(health)
	if health <= 0.0:
		_die()


var _reacted: Dictionary = {}


## A hero's skill landed on it (host): thrown by the Piercing Arrow it reels
## back on its haunches as from a parry; fire and poison make it flinch; the
## mark is only laid on.
func react(kind: StringName, from: Node3D = null, push: Vector3 = Vector3.ZERO) -> void:
	if is_dead or not _decides():
		return
	if push.length_squared() > 0.0001:
		velocity += Vector3(push.x, 0.0, push.z) * 1.3
	if from != null and is_instance_valid(from):
		provoke(from)
	# The hunter's mark is only laid on it: no stagger, nothing that stops it
	# (a reel at a run had it skating along in the stagger).
	if kind == &"mark":
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(_reacted.get(kind, -1000.0)) + 4.0:
		return
	_reacted[kind] = now
	_swipe_lands = -1.0
	_reeling = parried_stagger if kind == &"knock" or kind == &"stun" else parried_stagger * 0.4
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


## Once it is dead: it falls onto its back (the rig's death clip), and lies there.
func _collapse(_delta: float) -> void:
	if rig != null:
		rig.fall(_fall_side)


## Its body strikes the ground as it goes down: dust thrown up where it hits,
## and the sound of a weight landing. Everywhere: the rig plays the fall on
## every peer.
func _body_lands(at: Vector3, weight: float) -> void:
	var ground := at
	ground.y = global_position.y
	DustRing.burst(Blood.world_of(self), ground, 0.9 * weight * _size() / 1.65)
	Sfx.play(self, THUD_SOUND, null, ground, randf_range(0.8, 0.95), -8.0 + 6.0 * weight)

const THUD_SOUND := "res://unverified/sounds/all/dropped-person-sound1.wav"


## Takes the body out of the world once it has lain there long enough. Corpses
## that never leave pile up into clutter, and each one keeps a rig posing every
## frame. It fades out where it lies rather than blinking out — or being let
## down through the ground, which read as the ground swallowing it.
func _clear_away(delta: float) -> void:
	_corpse_age += delta
	if _corpse_age < corpse_linger:
		return

	var gone := (_corpse_age - corpse_linger) / maxf(corpse_fade_time, 0.001)
	if gone >= 1.0:
		# Everywhere, not only here. This runs in `_physics_process`, which only
		# the host has, so freeing it locally would leave a wolf lying in every
		# other window for the rest of the game — kept alive by nothing, posing a
		# rig every frame, and never coming back.
		net_clear.rpc()
		return
	if rig != null:
		rig.fade(smoothstep(0.0, 1.0, gone))
#endregion
