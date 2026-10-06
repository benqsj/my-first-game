class_name ZombieFighter
extends Brawler

## The walking dead: Polysplit's two zombies (CREATURES_PACK.md), on their own
## clips (the user's pick, 2026-10-06).
##
## * **Out of the ground.** It lies under the earth (`buried`: not seen, not
##   in anyone's way) until a hero comes within `wake_range`, then climbs out
##   of it (`rise_clip`) and comes for him. Where it is set to wait for the
##   hero's blow (the arena's rule, its sight put away) it climbs out all the
##   same and stands there until he strikes it.
## * **The horde.** Roused, it rouses every other of the dead within
##   `call_range` that is still waiting, its band or not.
## * **Not dead the first time.** Cut down, it may (`getup_chance`, once) only
##   fall: it lies `getup_after` seconds and gets up again with `getup_health`
##   of its health. Struck while it lies, it is dead for good.
## * It shambles, slow, and swings and bites (its [Brawler] attacks).

@export_group("The dead")
@export var buried: bool = true
@export var wake_range: float = 8.0
@export var rise_clip: StringName = &"CR_Rise"
@export var call_range: float = 14.0
@export_range(0.0, 1.0) var getup_chance: float = 0.5
@export var getup_after: float = 2.0
@export_range(0.0, 1.0) var getup_health: float = 0.35
@export var down_clip: StringName = &"CR_Death2"
@export var getup_clip: StringName = &"CR_GetUp"

const DOWN := 92
const LIE := 93
const GETUP := 94

## Replicated: still under the ground.
var under: bool = false
var _shown_under: bool = false
var _got_up: bool = false
var _layer: int = 0


func _ready() -> void:
	super()
	add_to_group(&"the_dead")
	_layer = collision_layer
	_moves_table[DOWN] = [down_clip, 1.0, 0.0, 1.0]
	_moves_table[GETUP] = [getup_clip, 1.1, 0.0, 1.0]
	if _anim != null and _anim.has_clip(down_clip):
		# Held on the clip's last frame for `getup_after`.
		var length := _anim.clip_length(down_clip)
		_moves_table[LIE] = [down_clip, 0.02 * length / maxf(getup_after, 0.1), 0.98, 1.0]
	else:
		_moves_table[LIE] = [down_clip, 0.01, 0.99, 1.0]
	under = buried
	_show_under()


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


func _process(delta: float) -> void:
	super(delta)
	if _shown_under != under:
		_show_under()


func _think(delta: float) -> void:
	if under:
		if not _decides():
			return
		var near := _pick_quarry()
		if near != null and _distance_to(near) < wake_range:
			# Set to wait for his blow (the arena's rule, its sight put away):
			# it climbs out and stands there until he strikes it.
			_climb_out(near if sight_range > 0.0 else null)
		return
	if act == DOWN or act == LIE or act == GETUP:
		return
	super(delta)


func _climb_out(who: Node3D) -> void:
	under = false
	_show_under()
	net_dirt.rpc(global_position)
	rise(rise_clip, who)


@rpc("authority", "call_local", "unreliable")
func net_dirt(at: Vector3) -> void:
	var into := Blood.world_of(self)
	GroundFx.eruption(into, at, 0.7)
	DustRing.burst(into, at + Vector3.UP * 0.05, 0.9)


func _rouse(who: Node3D) -> void:
	var was := mode
	super(who)
	if under and who != null and not is_dead and _decides():
		_climb_out(who)
	if was != Mode.GUARD or who == null or not _decides():
		return
	# The horde: the dead round it that are still waiting come too.
	for node in get_tree().get_nodes_in_group(&"the_dead"):
		var other := node as ZombieFighter
		if other == null or other == self or other.is_dead or other.mode != Mode.GUARD:
			continue
		if other.global_position.distance_to(global_position) <= call_range:
			other._rouse(who)


func _receive(damage: float, at: Vector3, blow: Vector3, from: Node3D, magic: bool = false) -> bool:
	if under:
		return false
	return super(damage, at, blow, from, magic)


## Cut down, the first time it may only fall, and get up again.
func _die() -> void:
	if is_dead or _got_up or not _decides() or _rng.randf() >= getup_chance:
		super()
		return
	_got_up = true
	health = 1.0
	velocity = Vector3.ZERO
	_sweeps.clear()
	_begin(DOWN)


func _after(what: int) -> void:
	match what:
		DOWN:
			_begin(LIE)
			return
		LIE:
			_begin(GETUP)
			return
		GETUP:
			health = maxf(health, max_health * getup_health)
			_start(Act.NONE)
			return
	super(what)


func _run_act(delta: float) -> void:
	super(delta)
	if act == DOWN or act == LIE or act == GETUP:
		velocity.x = 0.0
		velocity.z = 0.0


## Lying, it is not reeling or guarding: it takes what comes.
func _answer_swing(knight: Node3D) -> void:
	if act == DOWN or act == LIE or act == GETUP or under:
		return
	super(knight)
