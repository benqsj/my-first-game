class_name GhoulFighter
extends Brawler

## The ghoul (Polysplit's Biped Creatures, CREATURES_PACK.md): quick and
## low, it does not stand and trade blows (the user's pick, 2026-10-06).
##
## * **The leap.** From `leap_from` to `leap_to` off, now and then
##   (`leap_cooldown`), it crouches and springs at him (`CR_Leap`, UAL 2's
##   NinjaJump start and landing) and comes down on him, body and claws: a
##   blow that knocks him off his feet. The spring is sized to the gap.
## * **Hit and run.** After a swing it mostly (`dart_chance`) scuttles off a
##   few steps sideways and back, facing him (`dart_time`), and comes again,
##   at a run or with a leap.
## * Its swings are quick claws and a bite ([Brawler] attacks).

@export_group("Ghoul")
@export var leap_clip: StringName = &"CR_Leap"
## [rate, from, to] of the leap clip, and the share of the clip it lands at.
@export var leap_part: Vector3 = Vector3(1.25, 0.1, 0.62)
@export var leap_land: float = 0.44
@export var leap_from: float = 3.2
@export var leap_to: float = 8.0
@export var leap_cooldown: float = 3.5
## What lands: its whole body thrown onto him, and its claws.
@export var leap_limbs: String = "pelvis_joint>head_joint:0.32|L_elbow_joint>L_midFinger_joint3:0.14|R_elbow_joint>R_midFinger_joint3:0.14"
## How far short of him it means to come down (it comes down on him: the
## two bodies stop it there).
@export var leap_short: float = 0.5
@export_range(0.0, 1.0) var dart_chance: float = 0.7
@export var dart_time: Vector2 = Vector2(0.6, 1.1)
@export var dart_speed: float = 4.2

const LEAP := 96

var _leap_wait: float = 1.0
var _leap_speed: float = 0.0
var _dart_left: float = 0.0
var _dart_side: float = 1.0


func _ready() -> void:
	super()
	_moves_table[LEAP] = [leap_clip, leap_part.x, leap_part.y, leap_part.z]
	_own_limb(LEAP, leap_limbs)
	var s: Array = _strikes_table[LEAP]
	# One blow that knocks him down, at the landing.
	_strikes_table[LEAP] = [s[0], s[1], 1.3, 1, 0.6, PackedFloat32Array([leap_land])]


func _leaps() -> Array:
	return [LEAP]


func _think(delta: float) -> void:
	_leap_wait = maxf(_leap_wait - delta, 0.0)
	if mode == Mode.GUARD or mode == Mode.RETURN or is_dead or act != Act.NONE:
		super(delta)
		return
	_quarry = _pick_quarry()
	if _quarry == null:
		super(delta)
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
		_leap(gap)
		return
	super(delta)


func _leap(gap: float) -> void:
	_begin(LEAP)
	var until := _blow_moments(LEAP)[0]
	_leap_speed = maxf(gap - leap_short, 0.0) / maxf(until, 0.2)


func _extra_velocity(delta: float) -> Vector3:
	if act == LEAP:
		if _act_time <= _blow_moments(LEAP)[0]:
			return _forward() * _leap_speed
		return Vector3.ZERO
	return super(delta)


func _after(what: int) -> void:
	if what == LEAP:
		_leap_wait = leap_cooldown
	if _strikes_table.has(what) and _rng.randf() < dart_chance:
		_dart_left = _rng.randf_range(dart_time.x, dart_time.y)
		_dart_side = 1.0 if _rng.randf() < 0.5 else -1.0
	super(what)
