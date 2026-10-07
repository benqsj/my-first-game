class_name OgreFighter
extends PackBrute

## The ogre (Polysplit's Biped Creatures, CREATURES_PACK.md): a great club,
## slow and heavy (the user's picks, 2026-10-07).
##
## * **The ground struck** (`CR_GroundPound`): the club brought down on the
##   ground sends a shock out round it ([PackBrute._quake], `pound_radius`):
##   whoever is on the ground as it passes is thrown down. Jump it, or roll.
## * **The great blow** (`CR_Heavy2`): the club raised slowly overhead, glowing
##   hotter as it goes (`heavy_slow`), and brought down: no shield holds it
##   (a "crush": the guard is beaten down and most of it lands), and it
##   throws him down. Get out from under it.
## * **The fallen trodden.** Him down within `stomp_reach`: the club brought
##   down on him where he lies ("stomp"). Roll out, or get up quick.
## * **Rage** ([PackBrute]): at half its health.

@export_group("Pound")
@export var pound_clip: StringName = &"CR_GroundPound"
@export var pound_part: Vector3 = Vector3(1.0, 0.0, 0.92)
@export var pound_radius: float = 5.5
@export var pound_share: float = 0.85
@export var pound_from: float = 1.5
@export var pound_to: float = 5.0
@export var pound_cooldown: Vector2 = Vector2(7.0, 11.0)

@export_group("Great blow")
@export var heavy_clip: StringName = &"CR_Heavy2"
@export var heavy_part: Vector3 = Vector3(0.95, 0.0, 0.9)
## How many times slower its wind-up is played, and how long before the blow
## it comes back to its own pace.
@export var heavy_slow: float = 2.4
@export var heavy_lead: float = 0.18
@export var heavy_share: float = 1.5
@export var heavy_cooldown: Vector2 = Vector2(5.0, 9.0)

@export_group("Stomp")
@export var stomp_clip: StringName = &"CR_Heavy2"
@export var stomp_part: Vector3 = Vector3(1.3, 0.0, 0.85)
@export var stomp_reach: float = 3.4
@export var stomp_share: float = 0.6
@export var stomp_cooldown: float = 2.4

const POUND := 113
const HEAVY := 114
const STOMP := 115

var _pound_wait: float = 3.0
var _heavy_wait: float = 2.0
var _stomp_wait: float = 0.0
## Act seconds the club meets the ground in the pound and the stomp.
var _pound_at: float = 0.5
var _stomp_at: float = 0.5
var _pounded: bool = false


func _ready() -> void:
	super()
	_special(POUND, pound_clip, pound_part)
	_special(HEAVY, heavy_clip, heavy_part)
	_special_strike(HEAVY, "", heavy_share, 1)
	_kinds[HEAVY] = &"crush"
	_windups[HEAVY] = [heavy_slow, heavy_lead]
	_special(STOMP, stomp_clip, stomp_part)
	_pound_at = _club_down(POUND)
	_stomp_at = _club_down(STOMP)
	_pound_wait = _rng.randf_range(2.0, pound_cooldown.x)
	_heavy_wait = _rng.randf_range(1.0, heavy_cooldown.x)


## Act seconds of a move when its club is lowest, in front.
func _club_down(what: int) -> float:
	var m: Array = _moves_table[what]
	if _anim == null or _weapon < 0:
		return _move_length(what) * 0.5
	var at := _anim.measure_reach(m[0], String(weapon_bone), weapon_tip, reach_forward, float(m[2]), float(m[3]))
	if at < 0.0:
		return _move_length(what) * 0.5
	return (at - float(m[2])) * _anim.clip_length(m[0]) / maxf(float(m[1]), 0.01)


func _own_move(delta: float) -> bool:
	_pound_wait = maxf(_pound_wait - delta, 0.0)
	_heavy_wait = maxf(_heavy_wait - delta, 0.0)
	_stomp_wait = maxf(_stomp_wait - delta, 0.0)
	var gap := _distance_to(_quarry)
	# Him down in reach: the club on him where he lies.
	if _quarry_down():
		if gap <= stomp_reach and _stomp_wait <= 0.0:
			_face(_quarry.global_position - global_position, 1.0, 50.0)
			_pounded = false
			_begin(STOMP)
			return true
		if gap > stomp_reach * 0.8:
			_move_towards(_quarry.global_position, chase_speed, delta)
			return true
		return false
	if _pound_wait <= 0.0 and gap >= pound_from and gap <= pound_to and stamina >= attack_cost:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_pounded = false
		_begin(POUND)
		return true
	var want := float(_strike_from.get(HEAVY, strike_off))
	if _heavy_wait <= 0.0 and _cooldown <= 0.0 and gap <= want + 0.6 and gap >= want - 1.2 \
			and stamina >= attack_cost:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_begin(HEAVY)
		return true
	return super(delta)


func _run_act(delta: float) -> void:
	super(delta)
	if is_dead or not _decides():
		return
	if act == POUND and not _pounded and _act_time >= _pound_at:
		_pounded = true
		_quake(_weapon_tip_at() * Vector3(1, 0, 1) + Vector3.UP * global_position.y, pound_radius,
				hit_damage * pound_share)
	elif act == STOMP and not _pounded and _act_time >= _stomp_at:
		_pounded = true
		_stomp_down()


## Host: the club down where he lies: a blow at him if it comes down by him.
func _stomp_down() -> void:
	var at := _weapon_tip_at()
	var world := Blood.world_of(self)
	DustRing.burst(world, Vector3(at.x, global_position.y + 0.05, at.z), 0.6 * visual_scale)
	ImpactFx.thud(self, at, true)
	if _quarry == null or not _quarry.has_method(&"receive_blow"):
		return
	var flat := Vector2(at.x - _quarry.global_position.x, at.z - _quarry.global_position.z).length()
	if flat <= 1.5:
		_quarry.call(&"receive_blow", hit_damage * stomp_share * _blow_worth(STOMP), self, 0, 1,
				act_serial, false, &"stomp")


## Him down: it no longer waits over him (the [Brawler]'s way), it treads.
func _begin_attack() -> void:
	if _quarry_down():
		return
	super()


func _after(what: int) -> void:
	match what:
		POUND:
			_pound_wait = _rng.randf_range(pound_cooldown.x, pound_cooldown.y) * (0.6 if raging else 1.0)
		HEAVY:
			_heavy_wait = _rng.randf_range(heavy_cooldown.x, heavy_cooldown.y) * (0.6 if raging else 1.0)
		STOMP:
			_stomp_wait = stomp_cooldown
	super(what)
