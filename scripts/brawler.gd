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
## Blows in each attack (in `attacks`, then `big_attacks`; missing: 1). An
## attack of several (a punch combo) has its blows where its striking ends
## move fastest, the latest that many of them.
@export var attack_blows: PackedInt32Array = PackedInt32Array()
## Not pushed back by the blows it takes while it is swinging: the swing
## goes on and lands where it was aimed.
@export var steady_in_attack: bool = false
## Guarding behind its shield, it strikes back once his blows have stopped
## coming for this long (s; 0: it waits for the guard to drop by itself).
@export var counter_after: float = 0.0
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
## Cut down, it comes apart where it stands ([BoneShatter]), the pieces
## thrown the way the last blow went: the skeletons.
@export var shatter_on_death: bool = false

@export_group("Coming back together")
## Cut down the first time, one that comes apart (`shatter_on_death`) may
## (`reform_chance`, once) not be dead: its pieces lie `reform_after` s, then
## gather back up into it over `reform_time`, the lowest first, glowing, and it
## stands again with `reform_health` of its health and gives `reform_clip`
## (the user's pick, 2026-10-07: the skeletons and the golem). Struck while it
## lies in pieces, nothing lands.
@export_range(0.0, 1.0) var reform_chance: float = 0.0
@export var reform_after: float = 2.2
@export var reform_time: float = 1.7
@export_range(0.0, 1.0) var reform_health: float = 0.4
@export var reform_clip: StringName = &""
@export var reform_part: Vector3 = Vector3(1.0, 0.0, 1.0)
@export var reform_glow: Color = Color(0.45, 0.85, 1.0)

const ATTACK_BASE := 60
const BIG_BASE := 80
const ROAR := 99
## Lying in pieces, and standing up out of them ([member reform_chance]).
const PIECES := 120
const REFORM := 121

var _weapon: int = -1
## Act -> the gap its blow lands from (`strike_at_reach`), else `strike_off`.
var _strike_from: Dictionary = {}
## Parsed `attack_limbs` / `big_limbs`: act -> [[from bone, to bone, tip, radius], ...].
var _limbs_of: Dictionary = {}
var _moves_table: Dictionary = {}
var _strikes_table: Dictionary = {}
var _roar_in: float = 0.0
## The way the last blow that got through went (every peer sees the cuts).
var _last_blow: Vector3 = Vector3.ZERO
## Whether it has come back together once already (host).
var _reformed: bool = false
## Every peer: its pieces while it lies apart, where each stood in it, and
## how long it has lain.
var _pieces: Array[RigidBody3D] = []
var _piece_home: Array[Transform3D] = []
var _piece_clock: float = 0.0
var _gathering: bool = false
var _apart_shown: bool = false
var _layer_whole: int = -1
var _piece_glow: StandardMaterial3D
## Every peer: lying in pieces, out of the fight (no bars, no name over it).
var out_of_fight: bool = false


func _ready() -> void:
	for i in attacks.size():
		_moves_table[ATTACK_BASE + i] = _move(attacks[i], attack_parts, i)
	for i in big_attacks.size():
		_moves_table[BIG_BASE + i] = _move(big_attacks[i], big_parts, i)
	if not roar_clip.is_empty():
		_moves_table[ROAR] = [roar_clip, 1.0, 0.0, 1.0]
	if not reform_clip.is_empty():
		_moves_table[REFORM] = [reform_clip, reform_part.x, reform_part.y, reform_part.z]
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
func _blows_of(what: int) -> int:
	var i := what - ATTACK_BASE if what < BIG_BASE else attacks.size() + what - BIG_BASE
	return maxi(attack_blows[i], 1) if i >= 0 and i < attack_blows.size() else 1


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
		_moment_at_reach(what)


## One move's blows put where they reach furthest (see `strike_at_reach`).
func _moment_at_reach(what: int) -> void:
	if _anim == null:
		return
	var m: Array = _moves_table[what]
	var s: Array = _strikes_table[what]
	var bone := String(weapon_bone)
	var tip := weapon_tip
	if _limbs_of.has(what):
		var last: Array = (_limbs_of[what] as Array)[-1]
		bone = String(last[1])
		tip = last[2]
	var n := _blows_of(what)
	if n > 1:
		# A combo: its blows where the striking ends move fastest.
		var peaks := PackedFloat32Array()
		for p in _anim.measure_peaks(m[0], PackedStringArray(s[0]), 0.3, 0.08):
			if p >= float(m[2]) and p <= float(m[3]):
				peaks.append(p)
		if peaks.size() > n:
			peaks = peaks.slice(peaks.size() - n)
		if not peaks.is_empty():
			var limbs: Array = []
			for k in peaks.size():
				limbs.append((s[1] as Array)[0])
			_strikes_table[what] = [s[0], limbs, 1.0 / float(peaks.size()) * 1.6, maxi(int(s[3]), peaks.size()), 0.5, peaks]
			var first := _gap_that_lands(what, m, peaks[0])
			if first > 0.0:
				_strike_from[what] = first
		return
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
	# The limb grows with the creature; the hero does not.
	var touch := radius * s + WeaponSweep.BODY_RADIUS + WeaponSweep.GRAZE - 0.05
	# A sample counts only moving as fast as a blow must (`blow_min_speed`,
	# at the stretch's far end, in act seconds), as the sweep will count it.
	var step_act := (share_before + share_after) * length / 14.0 / rate
	var fwd := reach_forward.normalized()
	var runs: Array = []
	var run_start := -1.0
	var last := -1.0
	var d := 0.5
	while d <= strike_off + 1.2:
		var low := fwd * d / s + Vector3.UP * WeaponSweep.BODY_LOW / s
		var high := fwd * d / s + Vector3.UP * WeaponSweep.BODY_HIGH / s
		var hit := false
		for fi in frames.size():
			var frame: Array = frames[fi]
			var prev: Array = frames[maxi(fi - 1, 0)]
			for pi in frame.size():
				var part: Array = frame[pi]
				if fi > 0 and blow_min_speed > 0.0 and pi < prev.size():
					var moved := (part[1] as Vector3).distance_to((prev[pi] as Array)[1]) * s
					if moved / maxf(step_act, 0.0001) < blow_min_speed:
						continue
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


## Raised out of the ground (a mage's summons): it climbs out first
## (`clip`, e.g. UAL 2's Zombie_Spawn), then goes for `quarry`.
const RISE := 98


func rise(clip: StringName, quarry: Node3D = null) -> void:
	_moves_table[RISE] = [clip, 1.3, 0.0, 1.0]
	_begin(RISE)
	if quarry != null:
		_rouse(quarry)


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
	# Knocked flat, he cannot be hit (Player.net_blow): it waits over him for
	# him to get up rather than swing through the air above him.
	if _quarry_down():
		_cooldown = maxf(_cooldown, 0.15)
		return
	if attacks.is_empty():
		super()
		return
	# One of the attacks that lands from where it stands: a slam made from the
	# edge of its reach while still walking in falls short. (No closer than
	# the two bodies let it come: a bite is thrown from there and steps in.)
	var gap := _distance_to(_quarry) if _quarry != null else 0.0
	var nearest := 0.4 * maxf(visual_scale, 0.01) + 0.55
	var fits: Array[int] = []
	var closest_want := INF
	for i in attacks.size():
		var want := maxf(float(_strike_from.get(ATTACK_BASE + i, strike_off)), nearest)
		closest_want = minf(closest_want, want)
		# Nor from well inside it: a thrust from too close goes past him.
		if gap <= want + 0.4 and gap >= want - 0.6:
			fits.append(ATTACK_BASE + i)
	if fits.is_empty():
		var delta := get_physics_process_delta_time()
		if gap < closest_want:
			# Too close for any of them: a step back first, facing him.
			var away := global_position - _quarry.global_position
			away.y = 0.0
			_face(-away, delta, turn_speed)
			var back := away.normalized() * speed
			velocity.x = move_toward(velocity.x, back.x, acceleration * 3.0 * delta)
			velocity.z = move_toward(velocity.z, back.z, acceleration * 3.0 * delta)
		else:
			_move_towards(_quarry.global_position, chase_speed, delta)
		return
	_begin(fits[_rng.randi() % fits.size()])


func _quarry_down() -> bool:
	return _quarry != null and _quarry is Player and (_quarry as Player).state == Player.State.DOWNED


func _think(delta: float) -> void:
	if act == PIECES or act == REFORM:
		return
	if (mode == Mode.CHASE or mode == Mode.FIGHT) and act == Act.NONE and _quarry != null and not is_dead:
		_roar_in -= delta
		var gap := _distance_to(_quarry)
		if not big_attacks.is_empty() and gap > reach and gap < big_reach and _cooldown <= 0.0 \
				and stamina >= attack_cost and _rng.randf() < 0.02 and not _quarry_down():
			_face(_quarry.global_position - global_position, 1.0, 50.0)
			_begin(BIG_BASE + _rng.randi() % big_attacks.size())
			return
		if _roar_in <= 0.0 and _moves_table.has(ROAR):
			_roar_in = _rng.randf_range(roar_every.x, roar_every.y)
			_begin(ROAR)
			return
		if _step_back(delta):
			return
	# Behind the shield, once his blows stop coming: straight back at him.
	if counter_after > 0.0 and act == Act.BLOCK and _quarry != null and not is_dead \
			and _act_time >= counter_after and stamina >= attack_cost \
			and _distance_to(_quarry) <= reach + 0.4:
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_begin_attack()
		return
	super(delta)


func _receive(damage: float, at: Vector3, blow: Vector3, from: Node3D, magic: bool = false) -> bool:
	if act == PIECES:
		return false
	var was := velocity
	var bled := super(damage, at, blow, from, magic)
	if steady_in_attack and not is_dead and _strikes_table.has(act):
		velocity.x = was.x
		velocity.z = was.z
	return bled


## Its own moves are swings too: none is dropped halfway to guard or to step
## aside from his (Fighter only knows its own ATTACK act as one).
func _answer_swing(knight: Node3D) -> void:
	if _moves_table.has(act) or act == PIECES:
		return
	super(knight)


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
	if act == PIECES:
		velocity.x = 0.0
		velocity.z = 0.0
		if _act_time >= reform_after + reform_time:
			health = maxf(health, max_health * reform_health)
			if _moves_table.has(REFORM):
				_begin(REFORM)
			else:
				_start(Act.NONE)
		return
	super(delta)
	if _anim == null or not _moves_table.has(act) or act == ROAR:
		return
	var clip: StringName = (_moves_table[act] as Array)[0]
	if _anim.current_clip() != clip:
		return
	var want := _clip_time(act, _act_time)
	if absf(_anim.clip_position() - want) > 0.015 and want < _anim.clip_length(clip):
		_anim.seek(want)


func _after(what: int) -> void:
	if what != ROAR:
		_cooldown = _rng.randf_range(attack_cooldown.x, attack_cooldown.y)
	super(what)


func _flinch_body(blow: Vector3) -> void:
	_last_blow = blow
	super(blow)


## Dead, on every peer: a skeleton breaks into its bones.
func _lie_down() -> void:
	super()
	_drop_pieces()
	if not shatter_on_death or body == null or _skeleton == null:
		return
	_burst_apart(corpse_linger)


## Breaks it into its pieces where it stands (every peer), thrown the way the
## last blow went; they lie `linger` s.
func _burst_apart(linger: float) -> Array[RigidBody3D]:
	var push := _last_blow
	push.y = 0.0
	push = push.normalized() * 2.2 if push.length_squared() > 0.0001 else -_forward() * 1.2
	var world := Blood.world_of(self)
	var out := BoneShatter.burst(world, body, _skeleton, push, linger, corpse_sink_time)
	ImpactFx.strike(self, global_position + Vector3.UP * 1.0 * visual_scale, _shatter_matter(), 1.4)
	DustRing.burst(world, global_position + Vector3.UP * 0.05, 0.8 * visual_scale)
	return out


## What it sounds like coming apart.
func _shatter_matter() -> StringName:
	return &"bone"


#region Coming back together
## Cut down: the first time it may only come apart (host).
func _die() -> void:
	if is_dead or _reformed or not shatter_on_death or reform_chance <= 0.0 or not _decides() \
			or act == PIECES or _rng.randf() >= reform_chance:
		super()
		return
	_reformed = true
	health = 1.0
	velocity = Vector3.ZERO
	_sweeps.clear()
	_start(PIECES as Act)
	_act_length = reform_after + reform_time


func _play_act() -> void:
	if act == PIECES:
		_come_apart()
		return
	if act == REFORM:
		# Out of the held pose it stood up in.
		_anim.set_speed(1.0)
	super()


## Every peer: in pieces on the ground, the pose it fell in held for them to
## come back to.
func _come_apart() -> void:
	if body == null or _skeleton == null or not body.visible:
		return
	_drop_pieces()
	_pieces = _burst_apart(reform_after + reform_time + 30.0)
	_piece_home.clear()
	for rb in _pieces:
		_piece_home.append(rb.global_transform)
	_piece_clock = 0.0
	_gathering = false
	if _anim != null:
		_anim.set_speed(0.0)


## Every peer: lying apart it is not there to be fought (nothing to lock on
## to, nothing in the way); its pieces gather back once they have lain.
func _process(delta: float) -> void:
	super(delta)
	var apart := act == PIECES and not is_dead
	out_of_fight = apart
	if apart:
		# (the bars show themselves again whenever they are set)
		if _health_bar != null:
			_health_bar.visible = false
		if _stamina_bar != null:
			_stamina_bar.visible = false
	if apart != _apart_shown:
		_apart_shown = apart
		if apart:
			_layer_whole = collision_layer
			collision_layer = 0
			remove_from_group(&"enemy")
		else:
			if _layer_whole >= 0:
				collision_layer = _layer_whole
			if not is_dead and not is_in_group(&"enemy"):
				add_to_group(&"enemy")
			_whole_again()
	if not apart:
		return
	_piece_clock += delta
	if not _gathering and _piece_clock >= reform_after:
		_gather()


## Every peer: each piece lifts off the ground and flies back to where it stood
## in it, the lowest first, the head last, glowing as it comes.
func _gather() -> void:
	_gathering = true
	if _pieces.is_empty():
		return
	var low := INF
	var high := -INF
	for home in _piece_home:
		low = minf(low, home.origin.y)
		high = maxf(high, home.origin.y)
	_piece_glow = StandardMaterial3D.new()
	_piece_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_piece_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_piece_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_piece_glow.albedo_color = Color(reform_glow, 0.0)
	var glow_tw := create_tween()
	glow_tw.tween_property(_piece_glow, "albedo_color:a", 0.55, reform_time * 0.4)
	glow_tw.tween_property(_piece_glow, "albedo_color:a", 0.0, reform_time * 0.6)
	var world := Blood.world_of(self)
	SkillFx.light(world, global_position + Vector3.UP * 0.8 * visual_scale, reform_glow, 2.5, 5.0 * visual_scale,
			reform_time + 0.3)
	for i in _pieces.size():
		var rb := _pieces[i]
		if not is_instance_valid(rb):
			continue
		rb.freeze = true
		rb.collision_mask = 0
		for mi in rb.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = _piece_glow
		var home := _piece_home[i]
		var up := (home.origin.y - low) / maxf(high - low, 0.01)
		var delay := up * reform_time * 0.45 + randf_range(0.0, 0.08)
		var fly := maxf(reform_time - delay, 0.2)
		var from := rb.global_transform
		var lift := randf_range(0.4, 0.9) * visual_scale
		var tw := rb.create_tween()
		tw.tween_interval(delay)
		tw.tween_method(func(t: float) -> void:
			if not is_instance_valid(rb):
				return
			var e := t * t * (3.0 - 2.0 * t)
			var at := from.origin.lerp(home.origin, e) + Vector3.UP * sin(PI * t) * lift
			rb.global_transform = Transform3D(from.basis.slerp(home.basis, e), at), 0.0, 1.0, fly)
	SkillFx.burst(world, global_position + Vector3.UP * 0.2, reform_glow, 24, Vector2(0.4, 1.4), Vector3.UP, 60.0,
			Vector2(0.02, 0.05), Vector3(0, 1.0, 0), reform_time)


## Every peer: whole again where the pieces met.
func _whole_again() -> void:
	var had := not _pieces.is_empty()
	_drop_pieces()
	if body != null and not is_dead:
		body.visible = true
	if _anim != null and not is_dead:
		_anim.set_speed(1.0)
	if had and not is_dead:
		var world := Blood.world_of(self)
		var mid := global_position + Vector3.UP * 0.9 * visual_scale
		SkillFx.flash(world, mid, reform_glow, 0.55 * visual_scale, 0.22, 1.6)
		SkillFx.ring(world, global_position + Vector3.UP * 0.1, Vector3.UP, reform_glow, 0.3, 1.9 * visual_scale,
				0.4, 0.025, 1.4)
		ImpactFx.strike(self, mid, _shatter_matter(), 1.0)


func _drop_pieces() -> void:
	for rb in _pieces:
		if is_instance_valid(rb):
			rb.queue_free()
	_pieces.clear()
	_piece_home.clear()
#endregion
