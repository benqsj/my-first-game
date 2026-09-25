class_name Arkdeva
extends Brute

## Arkdeva the poisoner: a rider grown into a four-legged spider, with a pair
## of scythe-limbs over its shoulders.
##
## The model comes with a skeleton and no clips, so it is posed in code, limb
## by limb, the way the bestiary drives it: every limb is turned at its root
## about axes of the creature's own — straight up, and across the limb — from
## the pose it was built in. Walking is the legs swinging in two diagonal
## pairs. Its attacks, and nothing else:
##
## * **Stamp** — the front legs rear up, hold, and come down in front of it.
## * **Scythe** — one upper limb reared, held, and driven down in front into the
##   ground; the next one is the other side.
## * **Chop** — both scythes brought round to point ahead, pulled back over the
##   top, and brought down in front.
## * **Combo** — left scythe, right scythe, both together, and then a wave of
##   stone thorns out of the ground ahead of it, eleven metres long and wider
##   the further it runs: a hit of its own, apart from the scythes'.
## * **Poison** — spat forward, once or twice, at whoever it is fighting. It
##   bursts where it lands and leaves a pool that burns ([Venom] draws it).
##
## Only the combo can knock a player down, and only if all three scythes land.

enum Act { NONE = 0, STAMP = 1, STRIKE_L = 2, STRIKE_R = 3, CHOP = 4, COMBO = 5, SPIT_ONE = 6, SPIT_TWO = 7, PARRIED = 20, DEAD = 99 }

const DIFFUSE := "res://assets/spider/textures/arcdeva_diff.png"
const NORMAL := "res://assets/spider/textures/arcdeva_norm.png"
const EMISSION := "res://assets/spider/textures/arcdeva_emis.png"

## The moves each act is made of, in order: [kind, seconds, side].
const MOVES := {
	Act.STAMP: [[&"stamp", 1.2, &""]],
	Act.STRIKE_L: [[&"strike", 1.0, &"L"]],
	Act.STRIKE_R: [[&"strike", 1.0, &"R"]],
	Act.CHOP: [[&"chop", 1.2, &""]],
	Act.COMBO: [[&"strike", 0.85, &"L"], [&"strike", 0.85, &"R"], [&"strike", 1.25, &"B"], [&"thorns", 1.2, &""]],
	Act.SPIT_ONE: [[&"spit", 0.8, &""]],
	Act.SPIT_TWO: [[&"spit", 0.5, &""], [&"spit", 0.8, &""]],
	## A scythe thrown back off a shield ([Recoil]): it rears, scythes flung
	## up and wide, then sags open.
	Act.PARRIED: [[&"parried", Recoil.STAGGER, &""]],
}
## How far through each kind of move its blow lands.
const LANDS := { &"stamp": 0.7, &"strike": 0.66, &"chop": 0.6, &"thorns": 0.15, &"spit": 0.4,
		&"parried": 2.0 }

@export_group("Attack")
## Close enough for the legs and scythes.
@export var melee_range: float = 3.8
## Where it spits from, and how far.
@export var spit_range: Vector2 = Vector2(5.0, 14.0)
## A raid boss: every blow of its is enough to kill a player outright.
@export var stamp_damage: float = 220.0
@export var strike_damage: float = 220.0
@export var both_damage: float = 220.0
@export var chop_damage: float = 220.0
@export var thorn_damage: float = 220.0
@export var thorn_length: float = 11.0
## How much bigger than the bestiary's the thorns are drawn. Left at zero it
## follows `visual_scale`, so they grow with the creature.
@export var thorn_size: float = 0.0
@export var poison_damage: float = 220.0
@export var pool_damage: float = 30.0
## Around where a scythe comes down, how far its blow reaches.
@export var strike_radius: float = 1.7
@export var spit_flight: float = 0.6

var _skeleton: Skeleton3D
var _tilt: Node3D
var _yaw: Node3D
var _mouth: int = -1
## Skeleton space -> the creature's own (the Tilt node's), as a turn.
var _to_body := Quaternion.IDENTITY
var _to_skeleton := Quaternion.IDENTITY
var _legs: Array[Dictionary] = []
var _arms: Dictionary = {}

var _phase: float = 0.0
var _walk: float = 0.0
var _clock: float = 0.0
var _next_side: StringName = &"L"

## Host: the blows of the act under way, and the gobs in the air and pools on
## the ground.
var _events: Array = []
var _events_done: int = 0
var _gobs: Array[Dictionary] = []
var _pools: Array[Dictionary] = []


func _ready() -> void:
	super()
	_tilt = body.get_node_or_null("Tilt") as Node3D
	_yaw = body.get_node_or_null("Tilt/Yaw") as Node3D
	_skeleton = body.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton == null or _tilt == null or _yaw == null:
		push_warning("Arkdeva '%s': no skeleton to pose." % name)
		return
	_dress()
	_face_forward()
	_find_limbs()


## The textures ship loose, beside the model, as DDS the importer never linked.
func _dress() -> void:
	var material := StandardMaterial3D.new()
	material.resource_name = "Arkdeva"
	if ResourceLoader.exists(DIFFUSE):
		material.albedo_texture = load(DIFFUSE)
	if ResourceLoader.exists(NORMAL):
		material.normal_enabled = true
		material.normal_texture = load(NORMAL)
	if ResourceLoader.exists(EMISSION):
		material.emission_enabled = true
		material.emission_texture = load(EMISSION)
		# Multiplied, not added: added to white, the whole body glows white.
		material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		material.emission = Color.WHITE
		material.emission_energy_multiplier = 1.5
	material.roughness = 0.8
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh != null:
			for s in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(s, material)


## How big the thorns are drawn: with the creature, unless set by hand.
func _thorn_size() -> float:
	return thorn_size if thorn_size > 0.0 else visual_scale


func _bone_in_body(bone: int) -> Vector3:
	var world := _skeleton.global_transform * _skeleton.get_bone_global_rest(bone).origin
	return _tilt.global_transform.affine_inverse() * world


## Turns the model so its front legs point down -Z, the way the body faces.
func _face_forward() -> void:
	var ahead := Vector3.ZERO
	for id in ["FL", "FR"]:
		var b := _skeleton.find_bone("Leg_%s_00" % id)
		if b >= 0:
			ahead += _bone_in_body(b)
	for id in ["BL", "BR"]:
		var b := _skeleton.find_bone("Leg_%s_00" % id)
		if b >= 0:
			ahead -= _bone_in_body(b)
	ahead.y = 0.0
	if ahead.length_squared() > 1e-6:
		_yaw.rotation.y += PI - atan2(ahead.x, ahead.z)
	_to_body = (_tilt.global_transform.affine_inverse() * _skeleton.global_transform).basis.get_rotation_quaternion()
	_to_skeleton = _to_body.inverse()


func _limb(root_name: String, tip_name: String) -> Dictionary:
	var root := _skeleton.find_bone(root_name)
	var tip := _skeleton.find_bone(tip_name)
	if root < 0 or tip < 0:
		return {}
	var along := _bone_in_body(tip) - _bone_in_body(root)
	along.y = 0.0
	along = along.normalized()
	var parent := _skeleton.get_bone_parent(root)
	return {
		"root": root, "tip": tip, "along": along,
		"lift": Vector3.UP.cross(along).normalized(),
		"rest": _to_body * _skeleton.get_bone_global_rest(root).basis.get_rotation_quaternion(),
		"parent_inv": (_skeleton.get_bone_global_rest(parent).basis.get_rotation_quaternion().inverse()
				if parent >= 0 else Quaternion.IDENTITY),
	}


func _find_limbs() -> void:
	for pair in [["FL", 0.0], ["BR", 0.0], ["FR", PI], ["BL", PI]]:
		var leg := _limb("Leg_%s_00" % pair[0], "Leg_%s_03" % pair[0])
		if leg.is_empty():
			continue
		leg.phase = pair[1]
		leg.front = String(pair[0]).begins_with("F")
		_legs.append(leg)
	for side in ["L", "R"]:
		var arm := _limb("Arm%s_00" % side, "Arm%s_02" % side)
		if arm.is_empty():
			continue
		# Part of the way round from where it points to straight ahead.
		var f := Vector3.FORWARD
		var along: Vector3 = arm.along
		arm.inward = atan2(along.cross(f).y, along.dot(f)) * 0.55
		_arms[StringName(side)] = arm
	_mouth = _skeleton.find_bone("Mouth")


## A limb turned from the pose it was built in: about straight up, about the
## line across it, and — for the chop — about the creature's own side to side.
func _turn(limb: Dictionary, swing: float, lift: float, pitch: float = 0.0) -> void:
	var q := Quaternion(Vector3.UP, swing) * Quaternion(limb.lift as Vector3, lift)
	if pitch != 0.0:
		# Side to side across it, turned so that more pitch is over the top and
		# down in front (-Z) rather than behind.
		q = Quaternion(Vector3.LEFT, pitch) * q
	var in_body: Quaternion = q * (limb.rest as Quaternion)
	var in_skeleton := _to_skeleton * in_body
	_skeleton.set_bone_pose_rotation(limb.root, ((limb.parent_inv as Quaternion) * in_skeleton).normalized())


## Where a limb's tip is now, in the world.
func _tip(limb: Dictionary) -> Vector3:
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(limb.tip).origin


func mouth() -> Vector3:
	if _mouth < 0:
		return global_position + Vector3.UP * 2.6
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(_mouth).origin


#region Deciding
func _stand_off() -> float:
	return melee_range * 0.75


func _choose_attack(gap: float) -> void:
	if gap <= melee_range:
		var roll := _rng.randf()
		if roll < 0.22:
			_begin(Act.STAMP)
		elif roll < 0.5:
			_begin(Act.STRIKE_L if _next_side == &"L" else Act.STRIKE_R)
			_next_side = &"R" if _next_side == &"L" else &"L"
		elif roll < 0.72:
			_begin(Act.CHOP)
		else:
			_begin(Act.COMBO)
	elif gap >= spit_range.x and gap <= spit_range.y:
		_begin(Act.SPIT_ONE if _rng.randf() < 0.5 else Act.SPIT_TWO)


func _begin(what: int) -> void:
	var at := 0.0
	_events.clear()
	_events_done = 0
	for move: Array in MOVES[what]:
		_events.append([at + float(move[1]) * float(LANDS[move[0]]), move[0], move[2], _events.size()])
		at += float(move[1])
	_start(what, at)


## Arkdeva takes only the knock as a blow: it rears as if parried.
func _react(kind: StringName) -> void:
	if kind == &"knock" and act != Act.DEAD:
		_reel()


func _reel() -> void:
	_begin(Act.PARRIED)


func _reel_act() -> bool:
	return act == Act.PARRIED


func _after_act_rest() -> float:
	return _rng.randf_range(1.2, 2.6)


func _run_act(delta: float) -> bool:
	_slow(delta, 3.0)
	while _events_done < _events.size() and _act_time >= float(_events[_events_done][0]):
		var e: Array = _events[_events_done]
		_events_done += 1
		_land(e[1], e[2], e[3])
	return _act_time < _act_length


func _physics_process(delta: float) -> void:
	_run_poison(delta)
	super(delta)


## One move's blow, on the host.
func _land(kind: StringName, side: StringName, index: int) -> void:
	var ground := global_position.y + 0.03
	var in_combo := act == Act.COMBO
	var reach := visual_scale
	match kind:
		&"stamp":
			var at := global_position + _forward() * 2.0 * reach
			at.y = ground
			net_ground.rpc(at, 0.7 * reach)
			for who in _players_ahead(3.4 * reach, 0.3):
				_floor(who, stamp_damage)
		&"strike":
			var sides: Array = [&"L", &"R"] if side == &"B" else [side]
			var struck := {}
			for sd in sides:
				var at := _scythe_point(sd)
				net_ground.rpc(at, (0.8 if side == &"B" else 0.6) * reach)
				for who in _players_near(at, strike_radius):
					if struck.has(who):
						continue
					struck[who] = true
					var damage := both_damage if side == &"B" else strike_damage
					if in_combo:
						# Left, right, both: all three have to land to floor him.
						_hit(who, damage, index, 3)
					else:
						_hit(who, damage)
		&"chop":
			var mid := global_position + _forward() * 2.2 * reach
			mid.y = ground
			var struck := {}
			for sd in [&"L", &"R"]:
				var at := _scythe_point(sd)
				net_ground.rpc(at, 0.75 * reach)
				for who in _players_near(at, strike_radius):
					struck[who] = true
			for who in _players_near(mid, strike_radius):
				struck[who] = true
			for who in struck:
				_floor(who, chop_damage)
		&"thorns":
			var from := global_position + _forward() * 1.2 * reach
			from.y = ground
			_launch_wave(from, _forward(), thorn_length, _thorn_size(), thorn_damage)
			net_thorns.rpc(from, _forward())
		&"spit":
			_spit()


## Where a scythe meets the ground: its tip as posed now, or failing that a
## little ahead and to its side.
func _scythe_point(side: StringName) -> Vector3:
	var reach := visual_scale
	var at := global_position + _forward() * 2.2 * reach \
			+ global_transform.basis.x * (-0.9 if side == &"L" else 0.9) * reach
	if _arms.has(side):
		at = _tip(_arms[side])
		# Never behind it, whatever the pose says.
		var rel := at - global_position
		var least := 0.8 * reach
		if rel.dot(_forward()) < least:
			at += _forward() * (least - rel.dot(_forward()))
	at.y = global_position.y + 0.03
	return at


func _spit() -> void:
	var from := mouth()
	var aim := global_position + _forward() * 8.0 * visual_scale
	if _quarry != null and is_instance_valid(_quarry):
		aim = _quarry.global_position
		var body3 := _quarry as CharacterBody3D
		if body3 != null:
			aim += Vector3(body3.velocity.x, 0.0, body3.velocity.z) * spit_flight * 0.7
	aim += Vector3(_rng.randf_range(-0.6, 0.6), 0.0, _rng.randf_range(-0.4, 0.4))
	aim.y = global_position.y + 0.03 if absf(aim.y - global_position.y) < 2.0 else aim.y
	net_spit.rpc(from, aim)
	_gobs.append({"at": aim, "t": spit_flight})


## Gobs landing, and pools that burn whoever steps in — once each.
func _run_poison(delta: float) -> void:
	for i in range(_gobs.size() - 1, -1, -1):
		var gob := _gobs[i]
		gob.t = float(gob.t) - delta
		if gob.t > 0.0:
			continue
		for who in _players_near(gob.at, 1.4 * visual_scale):
			_hit(who, poison_damage, 0, 2, act_serial * 1000 + 500 + i)
		_pools.append({"at": gob.at, "t": 3.5, "caught": {}, "id": act_serial * 1000 + 600 + _pools.size()})
		_gobs.remove_at(i)
	for i in range(_pools.size() - 1, -1, -1):
		var pool := _pools[i]
		pool.t = float(pool.t) - delta
		if pool.t <= 0.0:
			_pools.remove_at(i)
			continue
		var caught: Dictionary = pool.caught
		for who in _players_near(pool.at, 1.1 * visual_scale):
			if not caught.has(who):
				caught[who] = true
				_hit(who, pool_damage, 0, 2, pool.id)
#endregion


#region Looks
@rpc("authority", "call_local", "unreliable")
func net_ground(at: Vector3, size: float) -> void:
	GroundFx.eruption(Blood.world_of(self), at, size)


@rpc("authority", "call_local", "reliable")
func net_thorns(from: Vector3, direction: Vector3) -> void:
	var world := Blood.world_of(self)
	GroundFx.wave(world, from, direction, thorn_length, true, _thorn_size())
	GroundFx.eruption(world, from, 0.8 * visual_scale)


@rpc("authority", "call_local", "reliable")
func net_spit(from: Vector3, to: Vector3) -> void:
	Venom.spit(Blood.world_of(self), from, to, spit_flight, 0.8 * visual_scale, visual_scale)


## Where it is in its act, on this peer: the move, and how far through it.
func _move_now() -> Array:
	if not MOVES.has(act):
		return []
	var t := _shown_time
	for move: Array in MOVES[act]:
		var length := float(move[1])
		if t < length:
			return [move[0], clampf(t / length, 0.0, 1.0), move[2]]
		t -= length
	return []


static func _ss(x: float, a: float, b: float) -> float:
	return smoothstep(a, b, x)


func _animate(delta: float) -> void:
	if _skeleton == null or _legs.is_empty():
		return
	_clock += delta
	var planar := Vector3(velocity.x, 0.0, velocity.z).length()
	var walking := 1.0 if planar > 0.2 and act == ACT_NONE and not is_dead else 0.0
	_walk += (walking - _walk) * (1.0 - exp(-5.0 * delta))
	# A longer leg covers more ground in a step, so the cycle is tied to the
	# creature's own size as well as to its pace.
	_phase = fmod(_phase + delta * 6.0 / maxf(visual_scale, 0.2) * _walk
			* clampf(planar / (1.6 * visual_scale), 0.6, 1.8), TAU)

	var rear := 0.0
	var recoil := 0.0
	var lift := {&"L": 0.0, &"R": 0.0}
	var turn := {&"L": 0.0, &"R": 0.0}
	var pitch := {&"L": 0.0, &"R": 0.0}
	var fall := 0.0
	if is_dead:
		fall = clampf(_shown_time / 0.7, 0.0, 1.0)
	var m := _move_now()
	if not m.is_empty():
		var kind: StringName = m[0]
		var p: float = m[1]
		match kind:
			&"stamp":
				if p < 0.45: rear = _ss(p, 0.0, 0.45) * 1.5
				elif p < 0.6: rear = 1.5
				elif p < 0.72: rear = lerpf(1.5, -0.35, (p - 0.6) / 0.12)
				else: rear = lerpf(-0.35, 0.0, _ss(p, 0.72, 1.0))
			&"strike":
				var up := _ss(p, 0.0, 0.4) if p < 0.4 else (1.0 if p < 0.55 else (1.0 - (p - 0.55) / 0.13 if p < 0.68 else 0.0))
				var down := 0.0 if p < 0.55 else ((p - 0.55) / 0.13 if p < 0.68 else (1.0 if p < 0.8 else 1.0 - _ss(p, 0.8, 1.0)))
				var sides: Array = [&"L", &"R"] if m[2] == &"B" else [m[2]]
				for sd in sides:
					lift[sd] = -0.95 * up + 1.6 * down
					turn[sd] = down
				recoil = -0.35 * up + 0.4 * down
			&"chop":
				var v := 0.0
				if p < 0.4: v = -0.9 * _ss(p, 0.0, 0.4)
				elif p < 0.5: v = -0.9
				elif p < 0.62: v = lerpf(-0.9, 2.3, (p - 0.5) / 0.12)
				elif p < 0.78: v = 2.3
				else: v = lerpf(2.3, 0.0, _ss(p, 0.78, 1.0))
				var ahead := _ss(p, 0.0, 0.3) if p < 0.78 else 1.0 - _ss(p, 0.78, 1.0)
				for sd in [&"L", &"R"]:
					pitch[sd] = v
					turn[sd] = ahead * 1.45
					lift[sd] = -0.35 * _ss(p, 0.0, 0.4) * (1.0 if p < 0.5 else 0.0)
				recoil = -0.4 * maxf(0.0, -v) / 0.9 + 0.35 * maxf(0.0, v) / 2.3
			&"thorns":
				recoil = sin(minf(p / 0.5, 1.0) * PI) * 0.35
			&"parried":
				var t := p * Recoil.STAGGER
				var jolt := Recoil.back(t)
				var give := Recoil.fold(t)
				# Up on its hind legs with both scythes flung high and wide, then
				# down low with them hanging.
				rear = 1.3 * jolt - 0.45 * give
				for sd in [&"L", &"R"]:
					lift[sd] = -1.6 * jolt + 0.55 * give
					turn[sd] = -0.6 * jolt
				recoil = -0.9 * jolt + 0.35 * give
			&"spit":
				recoil = -_ss(p, 0.0, 0.35) * 0.25 if p < 0.35 else sin(minf((p - 0.35) / 0.4, 1.0) * PI) * 0.3

	for leg in _legs:
		var s := sin(_phase + float(leg.phase))
		var up := -maxf(0.0, cos(_phase + float(leg.phase))) * 0.35 * _walk
		up += sin(_clock * 1.7 + float(leg.phase)) * 0.03
		if leg.front:
			up -= rear
		up -= 0.55 * fall
		_turn(leg, 0.28 * s * _walk, up)
	for side: StringName in _arms:
		var arm: Dictionary = _arms[side]
		var idle := sin(_clock * 1.3 + (0.0 if side == &"L" else 1.5)) * 0.06 * (1.0 - fall)
		_turn(arm, float(arm.inward) * float(turn[side]), float(lift[side]) + idle + 0.9 * fall, float(pitch[side]))

	# Forward is -Z here, so leaning into a blow is a negative turn about X.
	_tilt.rotation.x = rear * 0.12 - recoil * 0.25 - 0.12 * fall
	_tilt.position.y = (absf(sin(_phase * 2.0)) * 0.04 * _walk + rear * 0.12 - 1.0 * fall) * visual_scale
#endregion
