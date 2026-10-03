class_name Brawler
extends ClipFighter

## A creature or a boss that fights out of clips of its own, on the skeleton it
## came with, set up in its scene rather than in code: the minotaur, the demon,
## the frog, the ogre, the centaur, the dragons.
##
## The clips are made in vepxis-art `tools/mon_build.py` — the creature's own
## where it came with them, Mixamo's carried onto its bones where it did not —
## and nothing about the skeleton is renamed for the game, so everything that
## reads a bone is told which one here:
##
## * **Attacks** are a list of clips, each with how fast it plays and the share
##   of it that is the blow (past a slow wind-up, short of a long settle). One
##   is picked at random each time it swings; `big_attacks` are the ones a boss
##   saves for when the hero is further off (a leap, a charge, a breath).
## * **The blow** is the limb in `strike_bones` (its fastest moment is the blow,
##   measured off the clip), swept from `weapon_bone` out to `weapon_tip` in
##   that bone's frame and `weapon_radius` thick — a blade, a fist, jaws.
## * **Hurt and death** are its own clips; it takes the heroes' knock-downs,
##   burns and poison with the hit clip rather than the library's.

@export_group("Own moves")
## The attack clips, and for each [rate, from, to] (missing: [1, 0, 1]).
@export var attacks: Array[StringName] = []
@export var attack_parts: Array[Vector3] = []
## Attacks for further off: used when the hero is between `reach` and
## `big_reach`, now and then.
@export var big_attacks: Array[StringName] = []
@export var big_parts: Array[Vector3] = []
@export var big_reach: float = 0.0
## Bones whose speed marks a blow, and the one the blow is swept along.
@export var strike_bones: PackedStringArray = PackedStringArray()
@export var weapon_bone: StringName = &""
## What lands each attack, where it is not the weapon: one entry per attack
## (in `attacks`, then `big_attacks`; empty or missing: the weapon), each one
## or more stretches of the skeleton joined by "|", each "from>to" bone to
## bone, with "@x,y,z" a point in `to`'s own frame instead of its head, and
## ":r" its thickness in metres at size 1 (else `claw_radius`). The ends are
## also the bones whose speed marks the blow. A shield bash is the shield, a
## bite the head, a two-handed rake both hands.
@export var attack_limbs: PackedStringArray = PackedStringArray()
@export var big_limbs: PackedStringArray = PackedStringArray()
## The blow is the moment the weapon (or the attack's own limb) is farthest
## out in front of it, not when the hand moves fastest: a wind-up that raises
## the sword fast behind the head is not the cut. The clip's front is +Z of
## the skeleton it comes from (`reach_forward`).
@export var strike_at_reach: bool = false
@export var reach_forward: Vector3 = Vector3.BACK
## How many of its ordinary blows in one attack fell a hero (1: every blow
## that lands knocks him down). Its big attacks always do.
@export var blows_to_fell: int = 1
## Keeps the gap a blow is made from: under `strike_off` less this, it steps
## back before swinging, and backs off through a swing's wind-up, so a cut
## made from too close does not pass behind him.
@export var too_close: float = 0.0
## The clip it takes a hit with, and a shout it gives now and then when roused.
@export var hit_clip: StringName = &""
@export var roar_clip: StringName = &""
@export var roar_every: Vector2 = Vector2(9.0, 16.0)

const ATTACK_BASE := 60
const BIG_BASE := 80
const ROAR := 99

var _weapon: int = -1
## Act -> the gap its blow lands from (`strike_at_reach`), else `strike_off`.
var _strike_from: Dictionary = {}
## Parsed `attack_limbs` / `big_limbs`: act -> [[from bone, to bone, tip, radius], ...].
var _limbs_of: Dictionary = {}
var _moves_table: Dictionary = {}
var _strikes_table: Dictionary = {}
var _roar_in: float = 0.0


func _ready() -> void:
	for i in attacks.size():
		_moves_table[ATTACK_BASE + i] = _move(attacks[i], attack_parts, i)
	for i in big_attacks.size():
		_moves_table[BIG_BASE + i] = _move(big_attacks[i], big_parts, i)
	if not roar_clip.is_empty():
		_moves_table[ROAR] = [roar_clip, 1.0, 0.0, 1.0]
	var bones := strike_bones if not strike_bones.is_empty() else PackedStringArray([String(weapon_bone)])
	for what: int in _moves_table:
		if what != ROAR:
			_strikes_table[what] = [bones, ["weapon"], 1.0, 1 if what >= BIG_BASE else maxi(blows_to_fell, 1)]
	for i in mini(attack_limbs.size(), attacks.size()):
		_own_limb(ATTACK_BASE + i, attack_limbs[i])
	for i in mini(big_limbs.size(), big_attacks.size()):
		_own_limb(BIG_BASE + i, big_limbs[i])
	if not hit_clip.is_empty():
		reacts = {
			Act.REACT_KNOCK: [[hit_clip, 1.0, 1.0]],
			Act.REACT_BURN: [[hit_clip, 1.3, 1.0]],
			Act.REACT_POISON: [[hit_clip, 1.5, 0.6]],
		}
	super()
	if _skeleton != null and not weapon_bone.is_empty():
		_weapon = _skeleton.find_bone(String(weapon_bone))
	if strike_at_reach:
		_moments_at_reach()
	_roar_in = _rng.randf_range(roar_every.x, roar_every.y)


## An attack landed by limbs of its own (`attack_limbs`): its strike is
## those stretches, and the blow is marked by the speed of their far ends.
func _own_limb(what: int, spec: String) -> void:
	if spec.strip_edges().is_empty():
		return
	var stretches: Array = []
	var ends := PackedStringArray()
	for part in spec.split("|", false):
		var radius := claw_radius
		var body := part
		if body.contains(":"):
			radius = float(body.get_slice(":", 1))
			body = body.get_slice(":", 0)
		var tip := Vector3.ZERO
		var has_tip := false
		if body.contains("@"):
			var v := body.get_slice("@", 1).split(",")
			tip = Vector3(float(v[0]), float(v[1]), float(v[2]))
			has_tip = true
			body = body.get_slice("@", 0)
		var a := body.get_slice(">", 0).strip_edges()
		var b := body.get_slice(">", 1).strip_edges() if body.contains(">") else a
		stretches.append([a, b, tip, radius, has_tip])
		ends.append(b)
	_limbs_of[what] = stretches
	_strikes_table[what] = [ends, ["own:%d" % what], 1.0, 1 if what >= BIG_BASE else maxi(blows_to_fell, 1)]


func _limb(which: String) -> Callable:
	if which.begins_with("own:"):
		return _own_part.bind(int(which.substr(4)))
	return super(which)


func _own_part(what: int) -> Array:
	var out := []
	if _skeleton == null:
		return out
	var s := maxf(visual_scale, 0.01)
	for st: Array in _limbs_of.get(what, []):
		var a := _skeleton.find_bone(String(st[0]))
		var b := _skeleton.find_bone(String(st[1]))
		if a < 0 or b < 0:
			continue
		if bool(st[4]):
			out.append(WeaponSweep.bones(_skeleton, a, b, float(st[3]) * s, st[2]))
		else:
			out.append(WeaponSweep.bones(_skeleton, a, b, float(st[3]) * s))
	return out


## Each blow put where its striking end is farthest out in front (see
## `strike_at_reach`), within the part of the clip the move plays.
func _moments_at_reach() -> void:
	if _anim == null:
		return
	for what: int in _strikes_table:
		var m: Array = _moves_table[what]
		var s: Array = _strikes_table[what]
		var bone := String(weapon_bone)
		var tip := weapon_tip
		if _limbs_of.has(what):
			var last: Array = (_limbs_of[what] as Array)[-1]
			bone = String(last[1])
			tip = last[2]
		var at := _anim.measure_reach(m[0], bone, tip, reach_forward, float(m[2]), float(m[3]))
		if at >= 0.0:
			_strikes_table[what] = [s[0], s[1], s[2], s[3], 0.6, PackedFloat32Array([at])]
			var from := _gap_that_lands(what, m, at)
			if from > 0.0:
				_strike_from[what] = from


## The gap from him a blow lands from: its stretches followed through the
## moments it is live, against a hero standing straight ahead at each gap
## from 0.5 m out; the middle of the widest run of gaps where it meets him.
## A bite from close in, a sword cut from its length off. -1 if none.
func _gap_that_lands(what: int, m: Array, at: float) -> float:
	var length := _anim.clip_length(m[0])
	if length <= 0.0:
		return -1.0
	var rate := float(m[1])
	var stretches: Array = []
	var radius := weapon_radius
	if _limbs_of.has(what):
		for st: Array in _limbs_of[what]:
			stretches.append([st[0], st[1], st[2] if bool(st[4]) else null])
			radius = float(st[3])
	else:
		stretches.append([weapon_bone, weapon_bone, weapon_tip])
	var share_before := blow_window.x * rate / length
	var share_after := blow_window.y * rate / length
	var frames := _anim.sample_stretches(m[0], stretches, at - share_before, at + share_after, 14)
	var s := maxf(visual_scale, 0.01)
	var touch := (radius + WeaponSweep.BODY_RADIUS + WeaponSweep.GRAZE) * s - 0.05
	var fwd := reach_forward.normalized()
	var runs: Array = []
	var run_start := -1.0
	var last := -1.0
	var d := 0.5
	while d <= strike_off + 1.2:
		var low := fwd * d / s + Vector3.UP * WeaponSweep.BODY_LOW / s
		var high := fwd * d / s + Vector3.UP * WeaponSweep.BODY_HIGH / s
		var hit := false
		for frame: Array in frames:
			for part: Array in frame:
				var pts := Geometry3D.get_closest_points_between_segments(part[0], part[1], low, high)
				if pts[0].distance_to(pts[1]) * s <= touch:
					hit = true
					break
			if hit:
				break
		if hit:
			if run_start < 0.0:
				run_start = d
			last = d
		elif run_start >= 0.0:
			runs.append([run_start, last])
			run_start = -1.0
		d += 0.05
	if run_start >= 0.0:
		runs.append([run_start, last])
	var best: Array = []
	for r: Array in runs:
		if best.is_empty() or float(r[1]) - float(r[0]) > float(best[1]) - float(best[0]):
			best = r
	if best.is_empty():
		return -1.0
	# The middle: a step either way still lands.
	return lerpf(float(best[0]), float(best[1]), 0.5)


## Under `too_close`: backs off while the next blow is still to come.
func _close_gap() -> Vector3:
	var keep := strike_off
	strike_off = float(_strike_from.get(act, strike_off))
	var v := _gap_for_blow()
	strike_off = keep
	return v


func _gap_for_blow() -> Vector3:
	var v := super._close_gap()
	if too_close <= 0.0 or _quarry == null or v != Vector3.ZERO:
		return v
	var gap := _distance_to(_quarry)
	var want := strike_off - too_close
	if gap >= want:
		return v
	var next := -1.0
	for moment in _blow_moments(act):
		if moment > _act_time + 0.05:
			next = moment
			break
	if next < 0.0:
		return v
	return -_forward() * minf((strike_off - gap) / maxf(next - _act_time, 0.15), close_speed * 0.6)


func _move(clip: StringName, parts: Array[Vector3], i: int) -> Array:
	var p := parts[i] if i < parts.size() else Vector3(1.0, 0.0, 1.0)
	return [clip, p.x, p.y, p.z]


func _moves() -> Dictionary:
	return _moves_table


func _strikes() -> Dictionary:
	return _strikes_table


func _weapon_part() -> Array:
	if _weapon < 0:
		return []
	return [WeaponSweep.bones(_skeleton, _weapon, _weapon, weapon_radius * maxf(visual_scale, 0.01), weapon_tip)]


## Picks one of its attacks — a big one if the hero is further off.
func _begin_attack() -> void:
	if attacks.is_empty():
		super()
		return
	_begin(ATTACK_BASE + _rng.randi() % attacks.size())


func _think(delta: float) -> void:
	if (mode == Mode.CHASE or mode == Mode.FIGHT) and act == Act.NONE and _quarry != null and not is_dead:
		_roar_in -= delta
		var gap := _distance_to(_quarry)
		if not big_attacks.is_empty() and gap > reach and gap < big_reach and _cooldown <= 0.0 \
				and stamina >= attack_cost and _rng.randf() < 0.02:
			_face(_quarry.global_position - global_position, 1.0, 50.0)
			_begin(BIG_BASE + _rng.randi() % big_attacks.size())
			return
		if _roar_in <= 0.0 and _moves_table.has(ROAR):
			_roar_in = _rng.randf_range(roar_every.x, roar_every.y)
			_begin(ROAR)
			return
		if _step_back(delta):
			return
	super(delta)


## Standing too close to swing: a step or two back first.
func _step_back(delta: float) -> bool:
	if too_close <= 0.0 or _quarry == null or act != Act.NONE or mode != Mode.FIGHT:
		return false
	var away := global_position - _quarry.global_position
	away.y = 0.0
	if away.length() >= strike_off - too_close:
		return false
	_face(-away, delta, turn_speed)
	var back := away.normalized() * speed
	velocity.x = move_toward(velocity.x, back.x, acceleration * 3.0 * delta)
	velocity.z = move_toward(velocity.z, back.z, acceleration * 3.0 * delta)
	return true


## The clip kept where the move's clock says it is: the blow is live on that
## clock, and a clip drawn a beat ahead or behind it (the clip steps with the
## drawn frames, the clock with the physics) swings where the blow is not.
func _run_act(delta: float) -> void:
	super(delta)
	if _anim == null or not _moves_table.has(act) or act == ROAR:
		return
	var clip: StringName = (_moves_table[act] as Array)[0]
	if _anim.current_clip() != clip:
		return
	var want := _clip_time(act, _act_time)
	if absf(_anim.clip_position() - want) > 0.03 and want < _anim.clip_length(clip):
		_anim.seek(want)


func _after(what: int) -> void:
	if what != ROAR:
		_cooldown = _rng.randf_range(attack_cooldown.x, attack_cooldown.y)
	super(what)
