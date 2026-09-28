class_name Puglin
extends ClipFighter

## The puglin: small, round, thick-skinned, and never alone.
##
## Out of clips made on its own rig (`assets/monsters/puglin/puglin.glb`,
## vepxis-art `tools/puglin_build.py`, a short sword in place of the kit's stick)
## and the [ClipFighter]'s moves, travel and blows:
##
## * **A band is one thing.** Roused, the band walks at him slowly, bunched about
##   one point (`_bands`), each in its place round it, faces all turned on him.
##   Bunched, they roll at him together, throw mud, and whichever he stands next
##   to cuts at him.
## * **A big blow breaks it up.** A heavy cut (a hit worth well over the hero's
##   ordinary cut, a critical, or one knocking it off its feet), or one swing that
##   finds two of them: they hop away from him every way at once and come at him
##   from all sides for a while — rolling, throwing, cutting each on its own —
##   then one of them shouts and they bunch up again.
## * **They roll.** Curled into a ball it comes at him fast, turning as a ball
##   turns over the ground, off walls; if he gets out of the way it rolls on past,
##   swings round in an arc and comes again, two or three times. A ball takes a
##   cut on its hide — only magic gets in — and once it uncurls it is dizzy a
##   moment: that is the opening. When the whole band rolls at once and every one
##   of them finds him, he goes down.
## * **One combo, three cuts** with the sword (three slashes run together);
##   the three together floor him.
## * **Mud.** Thrown in an arc; what it hits is muddied — on the screen of the
##   one it hit ([ScreenMud]) — unless it was rolled away from or met on a shield.
## * **Hard to cut** (p.def high), easy to burn (m.def low), and not put off its
##   stroke by an ordinary cut.

const COMBO := 40
const COMBO_2 := 53
const COMBO_3 := 54
const THROW := 41
const CURL := 42
const ROLL := 43
const UNCURL := 44
const DIZZY := 45
const HOP := 46
const THUMP := 47
const SCREAM := 48
const HIT_F := 49
const HIT_L := 50
const HIT_R := 51
const STAGGER := 52

const MOVES := {
	# Three of the sword-and-shield set's slashes run together: across, back
	# down the other way, and a heavy one down into the ground.
	COMBO: [&"PG_Slash1", 1.15, 0.3, 0.62],
	COMBO_2: [&"PG_Slash2", 1.15, 0.27, 0.58],
	COMBO_3: [&"PG_Slash3", 1.1, 0.4, 0.82],
	# Only the throw itself: the arm drawn back (0.55), flung forward (0.70), held.
	# Before 0.55 the clip swings its hand back and forth once for nothing.
	THROW: [&"PG_Throw", 1.35, 0.55, 0.8],
	CURL: [&"PG_Roll", 1.3, 0.06, 0.3],
	UNCURL: [&"PG_Roll", 1.2, 0.62, 0.98],
	DIZZY: [&"PG_Stagger", 0.9, 0.05, 0.85],
	HOP: [&"PG_Hop", 1.4, 0.12, 0.8],
	THUMP: [&"PG_Thump", 1.4, 0.0, 0.9],
	SCREAM: [&"PG_Scream", 1.4, 0.05, 0.75],
	HIT_F: [&"PG_Hit_F", 1.3, 0.0, 0.8],
	HIT_L: [&"PG_Hit_L", 1.3, 0.0, 0.8],
	HIT_R: [&"PG_Hit_R", 1.3, 0.0, 0.8],
	STAGGER: [&"PG_Stagger", 1.2, 0.0, 0.85],
	# Held on the curled frame while it rolls; its length is the roll's.
	ROLL: [&"PG_Roll", 0.0, 0.2, 0.2],
}
const STRIKES := {
	# Each slash's moment is where its point sweeps across in front of it
	# (measured: 1.0–1.3 m out); the three are one combo of three blows.
	COMBO: [["hand_r"], ["weapon"], 0.45, 3, 0.6, [0.49]],
	COMBO_2: [["hand_r"], ["weapon"], 0.45, 3, 0.6, [0.42]],
	COMBO_3: [["hand_r"], ["weapon"], 0.55, 3, 0.6, [0.57]],
}
const HITS := [HIT_F, HIT_L, HIT_R, STAGGER]
const CUTS := [COMBO, COMBO_2, COMBO_3]
const THROW_RELEASE := 0.7

enum Band { GATHER, SCATTER, REGROUP }
enum Roll { RUSH, TURN }

@export_group("Puglin")
## How far off him the bunch stops, and how fast it walks.
@export var stand_off: float = 3.0
@export var bunch_speed: float = 1.3
## How far each stands from the middle of the bunch.
@export var bunch_radius: float = 0.95
## Rolling: top speed, how fast it gets there, how fast it swings round.
@export var roll_speed: float = 13.0
@export var roll_turn: float = 5.5
## How hard a ball steers after him while it comes (rad/s); none in the last
## `roll_commit` metres, so a late sidestep still gets out of its way.
@export var roll_home: float = 1.8
@export var roll_commit: float = 2.2
## Metres it rolls on past him before it swings round.
@export var roll_overshoot: float = 2.5
## Share of `hit_damage` a ball hits for.
@export var roll_share: float = 0.6
## Seconds between rolls, the band's and its own.
@export var roll_every: Vector2 = Vector2(7.0, 11.0)
## Mud: range, damage, and seconds between one puglin's throws.
@export var throw_range: Vector2 = Vector2(4.5, 13.0)
@export var mud_damage: float = 8.0
@export var throw_every: Vector2 = Vector2(4.0, 7.0)
## A cut this much bigger than the hero's ordinary one breaks the bunch.
@export var big_blow: float = 1.35
## Seconds it stays broken up.
@export var scatter_time: Vector2 = Vector2(6.5, 9.0)
## How long it is dizzy after uncurling.
@export var dizzy_time: float = 1.0
## Share of its health one blow must take to stagger it.
@export var stagger_share: float = 0.2

## Band -> {state, until, centre, next_roll, next_throw, hit_at}: what a band is doing.
static var _bands: Dictionary = {}
## Volley serial -> balls of it that have found him.
static var _volley_hits: Dictionary = {}
static var _volley_serial: int = 1000

var _ball_r: float = 0.36
var _tuck_at: float = 0.0
var _roll_dir: Vector3 = Vector3.FORWARD
var _roll_pace: float = 0.0
var _roll_phase: int = Roll.RUSH
var _roll_clock: float = 0.0
var _passes_left: int = 0
var _pass_hit: bool = false
var _volley: int = 0
var _volley_size: int = 1
var _next_throw: float = 0.0
var _next_roll: float = 0.0
var _slot_angle: float = 0.0
## One clock for the whole band (every member's times are read against it):
## the physics frames gone by, in seconds.
var _clock: float:
	get:
		return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)
## The rolling look, every peer: how far over the ball has turned.
var _spin: float = 0.0
var _body_basis: Basis = Basis.IDENTITY
var _throw_at: float = 0.5
var _mask_standing: int = 7
var _mask_rolling: int = 3
var _passing: Array[Node] = []
## The lump of mud in its fist while it winds up to throw (every peer).
var _held: MeshInstance3D
var _throw_clock: float = -1.0


func _ready() -> void:
	reacts = {
		Act.REACT_KNOCK: [[&"PG_Fall", 1.2, 1.0], [&"PG_GetUp", 1.5, 1.0]],
		Act.REACT_BURN: [[&"PG_Hit_F", 1.2, 1.0], [&"PG_Stagger", 1.2, 0.6]],
		Act.REACT_POISON: [[&"PG_Stagger", 1.0, 0.8]],
	}
	super()
	_mask_standing = collision_mask
	# Rolling it meets only the world (layer 1): its own kind are not knocked
	# off their line, and one he rolls out of the way of goes on through him —
	# finding him is measured, not bumped into.
	_mask_rolling = collision_mask & 1
	_ball_r = 0.3 * maxf(visual_scale, 0.01)
	if body != null:
		_body_basis = body.transform.basis
	_slot_angle = _rng.randf() * TAU
	_next_throw = _rng.randf_range(1.0, throw_every.y)
	_next_roll = _rng.randf_range(roll_every.x * 0.5, roll_every.y)
	if _anim != null:
		_tuck_at = _curled_moment()
		# Where the hand goes forward fastest (measured: 0.70 of the clip).
		var m: Array = MOVES[THROW]
		_throw_at = (THROW_RELEASE - float(m[2])) * _anim.clip_length(&"PG_Throw") / float(m[1])


func _moves() -> Dictionary:
	return MOVES


func _strikes() -> Dictionary:
	return STRIKES


func _fade_in(what: int) -> float:
	return 0.06 if what == ROLL else (0.08 if HITS.has(what) else 0.12)


## The frame of the roll where it is most curled up: the hips at their lowest.
func _curled_moment() -> float:
	var m: Dictionary = _meta.get("PG_Roll", {})
	var path: Array = m.get("hips", [])
	var best := 0
	var low := INF
	for i in range(int(path.size() * 0.1), int(path.size() * 0.55)):
		var z := float((path[i] as Array)[2])
		if z < low:
			low = z
			best = i
	return float(best) / float(m.get("fps", 30.0))


#region Band
func _band() -> Dictionary:
	if band.is_empty():
		return {}
	if not _bands.has(band):
		_bands[band] = {"state": Band.GATHER, "until": 0.0, "centre": global_position,
				"next_roll": _clock + _rng.randf_range(roll_every.x * 0.5, roll_every.y),
				"next_throw": 0.0, "hit_at": -10.0, "hit_by": null}
	return _bands[band]


## The living members of its band, in a fixed order.
func _mates() -> Array[Puglin]:
	var out: Array[Puglin] = []
	if band.is_empty():
		out.append(self)
		return out
	for node in get_tree().get_nodes_in_group(band):
		var p := node as Puglin
		if p != null and not p.is_dead and p.is_physics_processing():
			out.append(p)
	out.sort_custom(func(a: Puglin, b: Puglin) -> bool: return String(a.name) < String(b.name))
	return out


## Breaks the bunch up: every one of it hops off from him, each its own way.
func _scatter(from_pos: Vector3) -> void:
	var b := _band()
	if b.is_empty() or int(b["state"]) == Band.SCATTER:
		return
	b["state"] = Band.SCATTER
	b["until"] = _clock + _rng.randf_range(scatter_time.x, scatter_time.y)
	var mates := _mates()
	for i in mates.size():
		var p := mates[i]
		p._slot_angle = TAU * float(i) / float(maxi(mates.size(), 1)) + _rng.randf_range(-0.4, 0.4)
		if p.act == Act.NONE or p.act == DIZZY or p.act == THUMP:
			var away := p.global_position - from_pos
			away.y = 0.0
			if away.length_squared() < 0.01:
				away = Vector3.FORWARD.rotated(Vector3.UP, p._slot_angle)
			p._face(-away, 1.0, 1000.0)
			p._begin(HOP)
			p._next_roll = _clock + _rng.randf_range(1.0, 3.0)


func _band_think(delta: float) -> void:
	var b := _band()
	if b.is_empty():
		return
	var mates := _mates()
	if mates.is_empty() or mates[0] != self:
		return
	# The first of the band keeps the band's time.
	match int(b["state"]):
		Band.SCATTER:
			if _clock >= float(b["until"]):
				b["state"] = Band.REGROUP
				b["until"] = _clock + 6.0
				var mid := Vector3.ZERO
				for p in mates:
					mid += p.global_position
				b["centre"] = mid / float(mates.size())
				if act == Act.NONE:
					_begin(SCREAM)
		Band.REGROUP:
			var together := true
			for i in mates.size():
				if mates[i].global_position.distance_to(_slot(b, i, mates.size(), mates[i])) > 1.2:
					together = false
			if together or _clock >= float(b["until"]):
				b["state"] = Band.GATHER
				b["next_roll"] = _clock + _rng.randf_range(roll_every.x * 0.4, roll_every.x)
		Band.GATHER:
			if _quarry != null:
				var c: Vector3 = b["centre"]
				var to_him := _quarry.global_position - c
				to_him.y = 0.0
				var gap := to_him.length()
				if gap > stand_off:
					c += to_him.normalized() * minf(bunch_speed * delta, gap - stand_off)
				c.y = global_position.y
				b["centre"] = c
				# All of them at once, in their balls.
				if _clock >= float(b["next_roll"]) and gap > 2.0 and gap < 11.0:
					var idle := true
					for p in mates:
						idle = idle and (p.act == Act.NONE)
					if idle:
						b["next_roll"] = _clock + _rng.randf_range(roll_every.x, roll_every.y)
						_volley_serial += 1
						for p in mates:
							p._curl_up(p._quarry if p._quarry != null else _quarry, _volley_serial, mates.size(),
									_rng.randi_range(2, 3))


## Where member `i` of `n` stands in the bunch: round the middle, the ring
## turned to face him.
func _slot(b: Dictionary, i: int, n: int, who: Puglin) -> Vector3:
	var c: Vector3 = b["centre"]
	if n <= 1:
		return c
	var facing := 0.0
	if who._quarry != null:
		var to_him := who._quarry.global_position - c
		facing = atan2(to_him.x, to_him.z)
	var ang := facing + TAU * float(i) / float(n) + PI / float(n)
	return c + Vector3(sin(ang), 0.0, cos(ang)) * bunch_radius
#endregion


#region Thinking
func _think(delta: float) -> void:
	# The band keeps its time whatever this one is doing.
	_band_think(delta)
	if mode == Mode.GUARD or mode == Mode.RETURN:
		super(delta)
		if mode == Mode.CHASE:
			var b := _band()
			if not b.is_empty() and int(b["state"]) == Band.GATHER:
				b["centre"] = global_position
		return
	_quarry = _pick_quarry()
	if _quarry == null:
		_go_home()
		return
	mode = Mode.FIGHT
	if act != Act.NONE:
		return
	var b := _band()
	var state := Band.SCATTER if b.is_empty() else int(b["state"])
	var gap := _distance_to(_quarry)
	# Close enough to cut at: it cuts, bunched or not.
	if gap < reach and _cooldown <= 0.0 and stamina >= attack_cost:
		_face(_quarry.global_position - global_position, 1.0, 1000.0)
		_volley_serial += 1
		_chain_serial = _volley_serial * 10
		_chain_blow = 0
		_begin(COMBO)
		return
	# Mud, from the bunch or from anywhere, one throw of the band at a time.
	if gap > throw_range.x and gap < throw_range.y and _clock >= _next_throw and state != Band.REGROUP \
			and (b.is_empty() or _clock >= float(b["next_throw"])):
		_next_throw = _clock + _rng.randf_range(throw_every.x, throw_every.y)
		if not b.is_empty():
			b["next_throw"] = _clock + 1.6
		_face(_quarry.global_position - global_position, 1.0, 1000.0)
		_begin(THROW)
		return
	match state:
		Band.GATHER, Band.REGROUP:
			var mates := _mates()
			var i := mates.find(self)
			var spot := _slot(b, maxi(i, 0), mates.size(), self)
			var pace := bunch_speed * 1.4 if state == Band.GATHER else speed * 1.3
			_walk_to(spot, pace, delta)
		Band.SCATTER:
			# Its own way round him, slowly, and its own ball.
			if _clock >= _next_roll and gap > 3.0 and gap < 12.0:
				_next_roll = _clock + _rng.randf_range(roll_every.x * 0.6, roll_every.x)
				_volley_serial += 1
				_curl_up(_quarry, _volley_serial, 1, _rng.randi_range(2, 3))
				return
			var spot := _quarry.global_position + Vector3(sin(_slot_angle), 0.0, cos(_slot_angle)) * (stand_off + 1.5)
			_slot_angle += delta * 0.25
			_walk_to(spot, speed, delta)


## Walks to `spot`, face on to him the whole way (sideways or backwards if it
## has to), and stands there facing him.
func _walk_to(spot: Vector3, pace: float, delta: float) -> void:
	var to_spot := spot - global_position
	to_spot.y = 0.0
	_face(_quarry.global_position - global_position, delta, turn_speed)
	var want := Vector3.ZERO
	if to_spot.length() > 0.25:
		want = to_spot.normalized() * minf(pace, to_spot.length() * 2.0)
	velocity.x = move_toward(velocity.x, want.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, want.z, acceleration * delta)
#endregion


#region Rolling
func _curl_up(who: Node3D, volley: int, size: int, passes: int) -> void:
	if who == null or is_dead:
		return
	_quarry = who
	_volley = volley
	_volley_size = size
	_passes_left = passes - 1
	_face(who.global_position - global_position, 1.0, 1000.0)
	_begin(CURL)


func _after(what: int) -> void:
	match what:
		CURL:
			_start_roll()
		UNCURL:
			_begin(DIZZY)
			_act_length = dizzy_time
		COMBO, COMBO_2:
			# On into the next slash of the three, still the one combo.
			_chain_blow += 1
			_begin(COMBO_2 if what == COMBO else COMBO_3)
			stamina = maxf(stamina + attack_cost, 0.0)
		COMBO_3, THROW:
			_chain_serial = -1
			_chain_blow = 0
			_start(Act.NONE)
			_cooldown = _rng.randf_range(attack_cooldown.x, attack_cooldown.y)
		SCREAM:
			_start(Act.NONE)
		_:
			_start(Act.NONE)


func _start_roll() -> void:
	_start(ROLL)
	_act_length = 12.0
	_roll_phase = Roll.RUSH
	_roll_clock = 0.0
	_pass_hit = false
	_roll_pace = 6.0
	_roll_dir = _aim_at_him()
	# Balls pass through one another (a volley's balls knocking each other off
	# their line was most of their misses) and through him if he rolls clear.
	collision_mask = _mask_rolling
	# And he does not stand on it or get carried by it either way: the pair
	# is let pass (his body pushed itself off a ball and rode along with it).
	for node in get_tree().get_nodes_in_group("player"):
		if node is PhysicsBody3D:
			add_collision_exception_with(node)
			_passing.append(node)


## Where to roll to find him: where he will be, not quite where he is.
func _aim_at_him() -> Vector3:
	if _quarry == null:
		return _forward()
	var lead := _quarry.global_position
	var v: Variant = _quarry.get(&"velocity")
	if v is Vector3:
		var gap := _distance_to(_quarry)
		lead += Vector3((v as Vector3).x, 0.0, (v as Vector3).z) * clampf(gap / roll_speed, 0.0, 0.6)
	var d := lead - global_position
	d.y = 0.0
	return d.normalized() if d.length_squared() > 0.0001 else _forward()


func _run_act(delta: float) -> void:
	if act == ROLL:
		_roll(delta)
		return
	if act == DIZZY and _act_time >= _act_length:
		_start(Act.NONE)
		return
	if act == THROW and _act_time >= _throw_at and _act_time - get_physics_process_delta_time() < _throw_at:
		_let_fly()
	super(delta)


func _roll(delta: float) -> void:
	_roll_clock += delta
	# Off a wall: turned back off it, slower.
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var n := hit.get_normal()
		if absf(n.y) < 0.5 and not (hit.get_collider() is Player) and _roll_dir.dot(n) < -0.2:
			n.y = 0.0
			_roll_dir = _roll_dir.bounce(n.normalized()).normalized()
			_roll_pace *= 0.7
			net_thud.rpc(global_position + Vector3.UP * _ball_r)
			break
	var him := _quarry
	match _roll_phase:
		Roll.RUSH:
			_roll_pace = move_toward(_roll_pace, roll_speed, 32.0 * delta)
			if him != null and not _pass_hit:
				# Steers after him while he is ahead of it and not yet close.
				var lead := _aim_at_him()
				var off := him.global_position - global_position
				off.y = 0.0
				if off.length() > roll_commit and _roll_dir.dot(off.normalized()) > 0.3:
					var ang := _roll_dir.signed_angle_to(lead, Vector3.UP)
					_roll_dir = _roll_dir.rotated(Vector3.UP, clampf(ang, -roll_home * delta, roll_home * delta)).normalized()
				var to_him := him.global_position - global_position
				to_him.y = 0.0
				var dy := absf(him.global_position.y - global_position.y)
				if to_him.length() < _ball_r + 0.7 and dy < 1.6:
					# Rolled out of its way: it goes on through, and comes again.
					if not _evading(him):
						_crash_into(him)
				elif to_him.length() > roll_overshoot and _roll_dir.dot(to_him.normalized()) < -0.2:
					_roll_phase = Roll.TURN
					_roll_clock = 0.0
			if _roll_clock > 2.6:
				_roll_phase = Roll.TURN
				_roll_clock = 0.0
		Roll.TURN:
			_roll_pace = move_toward(_roll_pace, roll_speed * 0.75, 20.0 * delta)
			var want := _aim_at_him()
			var ang := _roll_dir.signed_angle_to(want, Vector3.UP)
			_roll_dir = _roll_dir.rotated(Vector3.UP, clampf(ang, -roll_turn * delta, roll_turn * delta)).normalized()
			if absf(ang) < 0.25 or _roll_clock > 2.2:
				if _passes_left > 0 and him != null and _roll_clock <= 2.2:
					_passes_left -= 1
					_roll_phase = Roll.RUSH
					_roll_clock = 0.0
					_pass_hit = false
				else:
					_end_roll()
					return
	velocity.x = _roll_dir.x * _roll_pace
	velocity.z = _roll_dir.z * _roll_pace
	rotation.y = atan2(-_roll_dir.x, -_roll_dir.z)


## Found him: he takes it — down, if the whole band's balls found him — and the
## ball bounces back off him and swings round for another pass.
func _crash_into(him: Node3D) -> void:
	_pass_hit = true
	var landed := int(_volley_hits.get(_volley, 0)) + 1
	_volley_hits[_volley] = landed
	var worth := hit_damage * roll_share
	# A combo of one floors him; two only flinches him.
	var whole := _volley_size > 1 and landed >= _volley_size
	if him.has_method(&"receive_blow"):
		him.call(&"receive_blow", worth, self, 0, 1 if whole else 2, _volley * 10 + landed)
	net_thud.rpc(global_position + Vector3.UP * _ball_r)
	_roll_dir = (-_roll_dir).rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))
	_roll_pace *= 0.45
	_roll_phase = Roll.TURN
	_roll_clock = 0.0


## Whatever ends a roll — its own end, a spell knocking it out, death — puts
## it back among its kind.
func _start(what: Act) -> void:
	if what != ROLL:
		collision_mask = _mask_standing
		for node in _passing:
			if is_instance_valid(node):
				remove_collision_exception_with(node)
		_passing.clear()
	super(what)


static func _evading(who: Node3D) -> bool:
	var st: Variant = who.get(&"state")
	if st != null and (int(st) == Player.State.DASHING or int(st) == Player.State.DODGING):
		return true
	return bool(who.get(&"is_invulnerable"))


func _end_roll() -> void:
	collision_mask = _mask_standing
	_face(_roll_dir, 1.0, 1000.0)
	_begin(UNCURL)


@rpc("authority", "call_local", "unreliable")
func net_thud(at: Vector3) -> void:
	DustRing.burst(Blood.world_of(self), at, 0.4)
#endregion


#region Mud
func _let_fly() -> void:
	if _quarry == null or _skeleton == null:
		return
	var from := global_position + Vector3.UP * 1.0 * maxf(visual_scale, 0.01) + _forward() * 0.3
	if _hand_r >= 0:
		from = _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand_r).origin
	var target := _quarry.global_position + Vector3.UP * 1.3
	var v: Variant = _quarry.get(&"velocity")
	var flight := clampf(global_position.distance_to(target) / 14.0, 0.35, 1.0)
	if v is Vector3:
		target += Vector3((v as Vector3).x, 0.0, (v as Vector3).z) * flight * 0.7
	# The arc that gets there in `flight` seconds.
	var g := MudBall.GRAVITY
	var vel := (target - from) / flight + Vector3.UP * 0.5 * g * flight
	net_throw.rpc(from, vel)


@rpc("authority", "call_local", "reliable")
func net_throw(from: Vector3, vel: Vector3) -> void:
	MudBall.fling(Blood.world_of(self), from, vel, self, _decides())


## A mud ball of its found someone (host).
func mud_landed(who: Node3D) -> void:
	if who == null or not who.has_method(&"receive_blow"):
		return
	# Rolled away from, or met on a shield: no mud in his eyes.
	var clean := _evading(who)
	if bool(who.get(&"is_blocking")):
		var toward := global_position - who.global_position
		toward.y = 0.0
		var facing := -who.global_transform.basis.z
		facing.y = 0.0
		if facing.normalized().dot(toward.normalized()) > 0.2:
			clean = true
	who.call(&"receive_blow", mud_damage, self, 0, 2, act_serial * 7 + 3)
	if not clean:
		net_mudded.rpc_id(who.get_multiplayer_authority(), who.get_path(), 1.0)


## On the peer whose hero it is: mud over his eyes.
@rpc("authority", "call_local", "reliable")
func net_mudded(who: NodePath, amount: float) -> void:
	var hero := get_node_or_null(who)
	if hero != null and hero.is_multiplayer_authority():
		ScreenMud.splat(get_tree(), amount)
#endregion


#region Taking hits
## Balls shrug off steel; big blows break the bunch; only a big one staggers it.
func _receive(damage: float, at: Vector3, blow: Vector3, from: Node3D, magic: bool = false) -> bool:
	if (act == ROLL or act == CURL) and not magic:
		net_clash.rpc(at)
		return false
	var before := health
	var big := false
	if from != null and not magic:
		var profile: Variant = from.get(&"profile")
		var ordinary := 26.0
		if profile is CharacterProfile:
			ordinary = float((profile as CharacterProfile).damage)
		big = damage >= ordinary * big_blow
	var landed := super(damage, at, blow, from, magic)
	if not landed or is_dead:
		return landed
	var b := _band()
	if not b.is_empty() and from != null:
		# One swing through two of them breaks them up as a big blow does.
		if _clock - float(b["hit_at"]) < 0.35 and b["hit_by"] != self:
			big = true
		b["hit_at"] = _clock
		b["hit_by"] = self
	if big and from != null:
		_scatter(from.global_position)
	if act == HOP:
		return landed
	var took := before - health
	var busy := CUTS.has(act) or act == THROW
	if took >= max_health * stagger_share:
		_hit_clip(STAGGER, blow)
	elif not busy and act != SCREAM:
		var ahead := _forward()
		var right := ahead.cross(Vector3.UP)
		var thrown := Vector3(blow.x, 0.0, blow.z)
		var what := HIT_F
		if thrown.length_squared() > 0.0001:
			thrown = thrown.normalized()
			if thrown.dot(right) > 0.5:
				what = HIT_R
			elif thrown.dot(right) < -0.5:
				what = HIT_L
		_hit_clip(what, blow)
	return landed


func _hit_clip(what: int, blow: Vector3) -> void:
	var thrown := Vector3(blow.x, 0.0, blow.z)
	if (what == HIT_F or what == STAGGER) and thrown.length_squared() > 0.0001:
		_face(-thrown, 1.0, 1000.0)
	_begin(what)


func react(kind: StringName, from: Node3D = null, push: Vector3 = Vector3.ZERO) -> void:
	super(kind, from, push)
	if kind == &"knock" and from != null:
		_scatter(from.global_position)
#endregion


#region The ball, drawn
func _play_act() -> void:
	super()
	_throw_clock = 0.0 if act == THROW else -1.0


func _process(delta: float) -> void:
	super(delta)
	_hold_mud(delta)
	if body == null or is_dead:
		return
	if act == ROLL:
		if _anim != null and _anim.current_clip() == &"PG_Roll":
			_anim.set_speed(0.0)
			_anim.seek(_tuck_at)
		var pace := Vector2(velocity.x, velocity.z).length()
		_spin = fmod(_spin + pace / maxf(_ball_r, 0.05) * delta, TAU)
		_lay_ball()
	elif _spin != 0.0:
		_spin = 0.0
		body.transform = Transform3D(_body_basis, Vector3(0.0, _body_rest_y, 0.0))


## Scooped up at the start of a throw and held in the fist, wet and shining,
## until it lets fly: the throw is seen coming.
func _hold_mud(delta: float) -> void:
	var holding := act == THROW and _throw_clock >= 0.0 and _throw_clock < _throw_at and not is_dead
	if holding:
		_throw_clock += delta
	if not holding or _skeleton == null or _hand_r < 0:
		if _held != null:
			_held.visible = false
		return
	if _held == null:
		_held = MeshInstance3D.new()
		_held.mesh = MudBall.lump_mesh()
		_held.material_override = MudBall.mud()
		_held.top_level = true
		add_child(_held)
	_held.visible = true
	var grow := clampf(_throw_clock / 0.35, 0.2, 1.0)
	_held.scale = Vector3.ONE * grow
	var hand := _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand_r)
	_held.global_position = hand * Vector3(0.0, 0.05, 0.08)


## Turns the curled body over about the middle of the ball, the way it rolls.
func _lay_ball() -> void:
	var pivot := Vector3(0.0, _ball_r, 0.0)
	var turn := Basis(Vector3.RIGHT, -_spin)
	var rest := Vector3(0.0, _body_rest_y, 0.0)
	body.transform = Transform3D(turn * _body_basis, pivot + turn * (rest - pivot))
#endregion
