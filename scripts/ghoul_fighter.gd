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
## * **Poisoned claws** (the user's pick, 2026-10-07): a blow of its that
##   reaches him, not on his guard, leaves a stack of poison in him
##   ([HeroPoison], `poison_time` s of `poison_dps`, up to three).
## * **The scream and the frenzy.** Cut under `frenzy_at` of its health it
##   stops, throws its head back and screams (`scream_clip`), and from then
##   on is in a frenzy: faster on its feet and in its swings
##   (`frenzy_pace`), hardly a breath between them, no more running off
##   between them, and a blow no longer stops it (no knock-down, no flinch
##   clip); a red glow on it.
## * **Feeding.** A corpse within `feed_range` while it is hurt and he is not
##   close (or it is not roused): it goes to it, crouches over it and eats
##   (`feed_clip`), `feed_heal` of its health a second, the corpse kept from
##   sinking while it does. A blow while it feeds and it comes up off it
##   enraged.

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

@export_group("Poison")
@export var poison_time: float = 6.0
@export var poison_dps: float = 2.5

@export_group("Frenzy")
@export_range(0.0, 1.0) var frenzy_at: float = 0.45
@export var scream_clip: StringName = &"CR_Transform"
@export var scream_part: Vector3 = Vector3(1.15, 0.0, 0.9)
@export var frenzy_pace: float = 1.3
@export var frenzy_glow: Color = Color(1.0, 0.12, 0.05)

@export_group("Feeding")
@export var feed_range: float = 14.0
@export var feed_clip: StringName = &"CR_Harvest"
@export var feed_part: Vector3 = Vector3(0.9, 0.22, 0.72)
@export var feed_heal: float = 0.06
@export var feed_most: float = 8.0
## Feeds while roused only with him further off than this.
@export var feed_while_far: float = 9.0

const LEAP := 96
const SCREAM := 103
const FEED := 104

var frenzied: bool = false
var _corpse: Node3D = null
var _fed_for: float = 0.0
var _glow: StandardMaterial3D
var _glow_light: OmniLight3D

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
	_moves_table[SCREAM] = [scream_clip, scream_part.x, scream_part.y, scream_part.z]
	_moves_table[FEED] = [feed_clip, feed_part.x, feed_part.y, feed_part.z]


func _leaps() -> Array:
	return [LEAP]


func _think(delta: float) -> void:
	_leap_wait = maxf(_leap_wait - delta, 0.0)
	if is_dead:
		super(delta)
		return
	if act == FEED:
		_feeding(delta)
		return
	if act != Act.NONE or mode == Mode.RETURN:
		super(delta)
		return
	# Cut deep enough: the scream, and the frenzy after it.
	if not frenzied and (mode == Mode.CHASE or mode == Mode.FIGHT) and health <= max_health * frenzy_at:
		_corpse = null
		velocity.x = 0.0
		velocity.z = 0.0
		_begin(SCREAM)
		return
	if _go_feed(delta):
		return
	if mode == Mode.GUARD:
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
		_leap_wait = leap_cooldown * (0.5 if frenzied else 1.0)
	if what == SCREAM and not frenzied:
		_send_frenzy()
	if _strikes_table.has(what) and not frenzied and _rng.randf() < dart_chance:
		_dart_left = _rng.randf_range(dart_time.x, dart_time.y)
		_dart_side = 1.0 if _rng.randf() < 0.5 else -1.0
	super(what)



#region Poison
func _blow_reached(who: Node3D, _what: int) -> void:
	if is_dead or who == null:
		return
	if bool(who.get("net_blocking")) or bool(who.get("is_blocking")):
		return
	var poison := HeroPoison.of(who)
	if poison != null:
		poison.apply(poison_time, poison_dps)
#endregion


#region The frenzy
func _send_frenzy() -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_frenzy.rpc()
	else:
		net_frenzy()


## Every peer: in a frenzy from now on.
@rpc("authority", "call_local", "reliable")
func net_frenzy() -> void:
	if frenzied:
		return
	frenzied = true
	speed *= frenzy_pace
	chase_speed *= frenzy_pace
	close_speed *= frenzy_pace
	dart_speed *= frenzy_pace
	attack_cooldown *= 0.35
	stamina_regen *= 2.0
	for what: int in _moves_table:
		if what != SCREAM and what != FEED and what != ROAR:
			var m: Array = (_moves_table[what] as Array).duplicate()
			m[1] = float(m[1]) * frenzy_pace
			_moves_table[what] = m
	_glow_on()


func _glow_on() -> void:
	if body == null:
		return
	_glow = StandardMaterial3D.new()
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.albedo_color = Color(frenzy_glow, 0.22)
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = _glow
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = frenzy_glow
	_glow_light.light_energy = 0.9
	_glow_light.omni_range = 2.2
	_glow_light.shadow_enabled = false
	add_child(_glow_light)
	_glow_light.position = Vector3.UP * 1.4 * visual_scale
	var into := Blood.world_of(self)
	SkillFx.ring(into, global_position + Vector3.UP * 1.3 * visual_scale, Vector3.UP, frenzy_glow, 0.3, 3.4,
			0.45, 0.03, 2.5)


## In its frenzy a blow no longer throws it about, nor do fire and poison
## make it flinch (they still burn and eat at it).
func react(kind: StringName, from: Node3D = null, push: Vector3 = Vector3.ZERO) -> void:
	if frenzied and (kind == &"knock" or kind == &"burn" or kind == &"poison"):
		if from != null and is_instance_valid(from) and _decides():
			_rouse(from)
		return
	super(kind, from, push)


func _process(delta: float) -> void:
	super(delta)
	if _glow != null:
		var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 7.0)
		_glow.albedo_color.a = 0.14 + 0.14 * beat
		if _glow_light != null:
			_glow_light.light_energy = 0.6 + 0.6 * beat
		if is_dead:
			_glow.albedo_color.a = 0.0
			_glow_light.light_energy = 0.0
#endregion


#region Feeding
## Off to a corpse when it is hurt and nothing presses it; true while it goes.
func _go_feed(delta: float) -> bool:
	# Left alone it feeds whenever it finds one; roused, only when it is hurt.
	if mode != Mode.GUARD and (health >= max_health * 0.98 or frenzied):
		return false
	if _disturbed():
		_corpse = null
		return false
	if _corpse == null or not is_instance_valid(_corpse) or not _edible(_corpse):
		_corpse = _nearest_corpse()
		_fed_for = 0.0
	if _corpse == null:
		return false
	var to := _corpse.global_position - global_position
	to.y = 0.0
	if to.length() > 0.95 * maxf(visual_scale, 0.5):
		_move_towards(_corpse.global_position, chase_speed * 0.8 if mode != Mode.GUARD else speed * 1.6, delta)
		_hold_corpse(4.0)
		return true
	_face(to, 1.0, 30.0)
	velocity.x = 0.0
	velocity.z = 0.0
	_begin(FEED)
	_hold_corpse(feed_most - _fed_for + 2.0)
	return true


## Bent over it, eating: whole again bit by bit, until it is full, the meal
## is done or he comes close.
func _feeding(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * 6.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * 6.0 * delta)
	_fed_for += delta
	health = minf(health + max_health * feed_heal * delta, max_health)
	var done := _corpse == null or not is_instance_valid(_corpse) or _fed_for >= feed_most \
			or (mode != Mode.GUARD and health >= max_health)
	if done and _corpse != null and is_instance_valid(_corpse) and _fed_for >= feed_most:
		# Picked clean.
		_corpse.set_meta(&"eaten", true)
	if done or _disturbed():
		_start(Act.NONE)
		_corpse = null


## He has come too close to keep at it (and roused it, if it was not).
func _disturbed() -> bool:
	var q := _pick_quarry()
	if q == null:
		return false
	var near := feed_while_far if act != FEED else feed_while_far * 0.55
	if mode == Mode.GUARD:
		near = minf(sight_range * 0.6, near)
	if _distance_to(q) >= near:
		return false
	_rouse(q)
	return true


func _nearest_corpse() -> Node3D:
	var best: Node3D = null
	var near := feed_range
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var f := node as Node3D
		if f == null or f == self or not _edible(f):
			continue
		var d := f.global_position.distance_to(global_position)
		if d < near:
			near = d
			best = f
	return best


## A body lying whole, not yet sinking away: not a skeleton's bones, not a
## golem's stone.
func _edible(f: Node3D) -> bool:
	if not bool(f.get("is_dead")) or f.has_meta(&"eaten"):
		return false
	if bool(f.get("shatter_on_death")) or not Blood.bleeds(f):
		return false
	var age := float(f.get("_corpse_age"))
	var linger := float(f.get("corpse_linger"))
	return age < linger - 0.3


## Keeps the corpse from sinking for `seconds` more, on every peer.
func _hold_corpse(seconds: float) -> void:
	if _corpse == null or not _decides():
		return
	var age := float(_corpse.get("_corpse_age"))
	if float(_corpse.get("corpse_linger")) - age >= seconds:
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


func _receive(damage: float, at: Vector3, blow: Vector3, from: Node3D, magic: bool = false) -> bool:
	var feeding := act == FEED
	var bled := super(damage, at, blow, from, magic)
	if feeding and not is_dead and _decides():
		# Disturbed at its meal: up off it, at him.
		_corpse = null
		_start(Act.NONE)
		_leap_wait = 0.0
		if from != null:
			_rouse(from)
			_face(from.global_position - global_position, 1.0, 50.0)
	return bled
#endregion
