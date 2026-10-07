class_name GolemFighter
extends PackBrute

## The golem (Polysplit's Biped Creatures, CREATURES_PACK.md): stone, slow,
## and not to be put off (the user's picks, 2026-10-07).
##
## * **It does not reel.** A blow does not push it back or bend it over, nor
##   stop what it is doing. Only a heavy one (`poise_heavy` and more) or a
##   string of them close together (`poise`, worn away again at
##   `poise_mend` a second) staggers it: it reels (its hit clip), and is open.
## * **Stone out of the ground.** It strikes the ground (`CR_GroundPound`) and
##   a run of stone spikes comes up from it towards him, row after row
##   ([GroundFx] wave, slower than Arkdeva's): whoever it comes up under is
##   thrown down. No shield takes it; get out of its line.
## * **It comes back together.** Cut down the first time it falls to pieces
##   of stone and, after a while, the pieces gather back into it and it stands
##   again ([Brawler] `reform_chance`).

@export_group("Steady")
## Damage (before its defence) that staggers it by itself.
@export var poise_heavy: float = 45.0
## Damage taken close together that staggers it, and how fast that wears off
## (a second, after `poise_rest` s with nothing landing).
@export var poise: float = 90.0
@export var poise_mend: float = 30.0
@export var poise_rest: float = 0.8

@export_group("Spikes")
@export var spikes_clip: StringName = &"CR_GroundPound"
@export var spikes_part: Vector3 = Vector3(0.9, 0.0, 0.92)
@export var spikes_from: float = 3.5
@export var spikes_to: float = 13.0
@export var spikes_length: float = 14.0
@export var spikes_pace: float = 11.0
@export var spikes_size: float = 1.1
@export var spikes_share: float = 0.9
@export var spikes_cooldown: Vector2 = Vector2(6.0, 9.0)

const SPIKES := 118

var _poise_taken: float = 0.0
var _since_hit: float = 99.0
var _spikes_wait: float = 2.0
var _spiked: bool = false
var _spikes_at: float = 0.5
## Host: spike runs going out ([method _run_spikes]).
var _runs: Array[Dictionary] = []


func _ready() -> void:
	super()
	_special(SPIKES, spikes_clip, spikes_part)
	if _anim != null:
		var m: Array = _moves_table[SPIKES]
		var at := _anim.measure_reach(m[0], "R_wrist_joint", Vector3(0.12, 0, 0), reach_forward, float(m[2]), float(m[3]))
		if at < 0.0:
			at = lerpf(float(m[2]), float(m[3]), 0.5)
		_spikes_at = (at - float(m[2])) * _anim.clip_length(m[0]) / maxf(float(m[1]), 0.01)
	_spikes_wait = _rng.randf_range(2.0, spikes_cooldown.x)


func _shatter_matter() -> StringName:
	return &"stone"


#region Steady
func _receive(damage: float, at: Vector3, blow: Vector3, from: Node3D, magic: bool = false) -> bool:
	var was := velocity
	var bled := super(damage, at, blow, from, magic)
	if not bled or is_dead or act == PIECES:
		return bled
	# Not pushed about by it.
	velocity.x = was.x
	velocity.z = was.z
	_since_hit = 0.0
	_poise_taken += damage
	if damage >= poise_heavy or _poise_taken >= poise:
		_stagger()
	return bled


## Staggered at last: it reels, open.
func _stagger() -> void:
	_poise_taken = 0.0
	if act == PIECES or act == REFORM:
		return
	_sweeps.clear()
	_start(Act.REACT_KNOCK)


## A skill that would throw it about counts as a heavy blow, no more.
func react(kind: StringName, from: Node3D = null, push: Vector3 = Vector3.ZERO) -> void:
	if kind == &"knock" or kind == &"stun":
		if is_dead or not _decides():
			return
		if from != null and is_instance_valid(from):
			_rouse(from)
		_since_hit = 0.0
		_poise_taken += poise_heavy * 0.6
		if _poise_taken >= poise:
			_stagger()
		return
	super(kind, from, push)


## The blow seen on it is a shudder, not a bend.
func _flinch_body(blow: Vector3) -> void:
	_last_blow = blow
	if is_dead or body == null:
		return
	if _hit_react == null:
		_hit_react = HitReact.on_body(body)
	_hit_react.strike(blow, FLINCH_THROW * 0.18)


## A parry does not set it reeling either; it only counts.
func parried(_by: Node3D) -> void:
	if is_dead or not _decides():
		return
	_poise_taken += poise * 0.5
	if _poise_taken >= poise:
		_stagger()
#endregion


#region Spikes
func _own_move(delta: float) -> bool:
	_spikes_wait = maxf(_spikes_wait - delta, 0.0)
	var gap := _distance_to(_quarry)
	if _spikes_wait <= 0.0 and gap >= spikes_from and gap <= spikes_to and not _quarry_down() \
			and stamina >= attack_cost:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_spiked = false
		_begin(SPIKES)
		return true
	return super(delta)


func _run_act(delta: float) -> void:
	super(delta)
	if is_dead or not _decides():
		return
	if act == SPIKES:
		if _quarry != null and _act_time < _spikes_at:
			_face(_quarry.global_position - global_position, delta, turn_speed)
		if not _spiked and _act_time >= _spikes_at:
			_spiked = true
			var from := global_position + _forward() * 1.0 * visual_scale
			var way := _forward()
			if _quarry != null:
				way = _quarry.global_position - from
				way.y = 0.0
				way = way.normalized() if way.length_squared() > 0.01 else _forward()
			_spike_run(from, way)


func _after(what: int) -> void:
	if what == SPIKES:
		_spikes_wait = _rng.randf_range(spikes_cooldown.x, spikes_cooldown.y)
	super(what)


## Host: a run of spikes from `from` along `way`, seen everywhere.
func _spike_run(from: Vector3, way: Vector3) -> void:
	_runs.append({"from": from, "dir": way, "t": 0.0, "caught": {}, "id": act_serial * 1000 + 95})
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_spikes.rpc(from, way)
	else:
		net_spikes(from, way)


@rpc("authority", "call_local", "reliable")
func net_spikes(from: Vector3, way: Vector3) -> void:
	var world := Blood.world_of(self)
	GroundFx.wave(world, from, way, spikes_length, false, spikes_size, spikes_pace)
	GroundFx.eruption(world, from, 0.8)
	ImpactFx.thud(self, from, true)


func _physics_process(delta: float) -> void:
	super(delta)
	_since_hit += delta
	if _since_hit > poise_rest:
		_poise_taken = maxf(_poise_taken - poise_mend * delta, 0.0)
	if _runs.is_empty() or not _decides():
		return
	for i in range(_runs.size() - 1, -1, -1):
		var run := _runs[i]
		run.t = float(run.t) + delta
		var front := float(run.t) * spikes_pace
		var ahead: Vector3 = run.dir
		var side := Vector3(-ahead.z, 0.0, ahead.x)
		var caught: Dictionary = run.caught
		for node in get_tree().get_nodes_in_group(&"player"):
			var who := node as Node3D
			if who == null or caught.has(who) or not who.has_method(&"receive_blow") or bool(who.get("is_dead")):
				continue
			var rel := who.global_position - (run.from as Vector3)
			if absf(rel.y) > 2.0:
				continue
			var d := rel.dot(ahead)
			# Under him as that row comes up (a moment after the front passes).
			if d < 0.4 or d > minf(front - 0.3, spikes_length):
				continue
			if absf(rel.dot(side)) > GroundFx.wave_width(d, spikes_size) * 0.5 + 0.35:
				continue
			caught[who] = true
			who.call(&"receive_blow", hit_damage * spikes_share * _blow_worth(SPIKES), self, 0, 1, int(run.id),
					false, &"spike")
		if front > spikes_length + 1.0:
			_runs.remove_at(i)
#endregion
