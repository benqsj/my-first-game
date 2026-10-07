class_name ClipFighter
extends Fighter

## A [Fighter] that fights out of clips made on its own rig — the imp's, the
## puglin's — rather than the shared library's.
##
## What the kinds have in common lives here; each says what its moves are and
## how it chooses them:
##
## * **Moves are clips.** `_moves()` maps an act to [clip, rate, from, to]: which
##   clip, how fast, and the share of it played (past a slow wind-up, short of a
##   long settle). Every peer plays the act's clip when the serial moves.
## * **The body goes where the clip goes.** How far each clip carries the hips
##   was measured in Blender (a `*_clip_meta.json` beside the model); the clips
##   are exported in place and the body is driven along that path, scaled to its
##   size, by `move_and_slide` — into walls and bodies like any walk.
##   `_stretch` lengthens or shortens the forward part of it (a leap sized to the
##   gap).
## * **Blows are limbs.** `_strikes()` maps an attack to [bones whose speed marks
##   a blow, the limb that lands each ("weapon", "claw", "feet"), share of
##   `hit_damage`, how many blows the player counts it as]. Each blow is live
##   around the moment its bones move fastest in the clip, measured once.
## * **Walking** picks forward, sideways, backwards or a run by how the body is
##   moving against the way it faces, each retimed to its own stride *at the
##   size the creature is drawn*.

@export_group("Own clips")
@export_file("*.json") var clip_meta: String = ""
@export var run_clip: StringName = &""
## A slower walk it keeps once roused, if it has one.
@export var roused_walk_clip: StringName = &""
@export var strafe_l_clip: StringName = &""
@export var strafe_r_clip: StringName = &""
@export var back_clip: StringName = &""
## Its back clip for going back faster, if it has one (the ghoul's run back).
@export var back_run_clip: StringName = &""
## Above this pace it runs, where its walk cannot be read off the clip; where
## it can, it runs once the walk would play faster than `walk_rate_max`
## (and walks again under `walk_rate_max` less a tenth), so neither clip is
## ever played far off its own pace.
@export var run_above: float = 3.2
@export var walk_rate_max: float = 1.55
## The slowest a cycle clip is played (a big creature ambling).
@export var gait_floor: float = 0.3
## How much further a run carries than twice its feet's widest gap (the
## flight between steps, which the feet do not show): the run's legs retimed
## to it. 1 for a run measured right.
@export var run_stride_gain: float = 1.0
## The weapon in its right fist, from the fist to this point in the hand's own
## frame (measured off the mesh), this thick.
@export var weapon_tip: Vector3 = Vector3(0.0, 0.0, 0.4)
@export var weapon_radius: float = 0.1
## How long before and after its moment a blow is live (s), and the slowest
## the limb may be moving and still count — smaller arms swing slower.
@export var blow_window: Vector2 = Vector2(0.14, 0.1)
@export var blow_min_speed: float = 2.0
## How close it steps in under a blow on foot (the clip's own travel aside).
@export var strike_off: float = 1.3
@export var claw_radius: float = 0.1
@export var foot_radius: float = 0.11

static var _metas: Dictionary = {}
static var _moment_cache: Dictionary = {}

## The body's frame when the move began: travel is laid along it.
var _move_fwd: Vector3 = Vector3.FORWARD
var _move_right: Vector3 = Vector3.RIGHT
## Forward travel is stretched by this.
var _stretch: float = 1.0
var _last_hips: Vector2 = Vector2.ZERO
var _meta: Dictionary = {}
## Attacks run one into the next as one combo: which blow of it the next act's
## first blow is, and the serial they all share (-1: each act its own).
var _chain_blow: int = 0
var _chain_serial: int = -1
var _hand_r: int = -1
var _hand_l: int = -1
var _fore_l: int = -1
var _tip_l: int = -1
var _foot_l: int = -1
var _foot_r: int = -1
var _calf_l: int = -1
var _calf_r: int = -1


func _ready() -> void:
	super()
	if not clip_meta.is_empty():
		if not _metas.has(clip_meta) and FileAccess.file_exists(clip_meta):
			_metas[clip_meta] = JSON.parse_string(FileAccess.get_file_as_string(clip_meta))
		_meta = _metas.get(clip_meta, {})
	if _skeleton != null:
		_hand_r = _skeleton.find_bone("hand_r")
		_hand_l = _skeleton.find_bone("hand_l")
		_fore_l = _skeleton.find_bone("lowerarm_l")
		_tip_l = _skeleton.find_bone("middle_04_leaf_l")
		_foot_l = _skeleton.find_bone("ball_l")
		_foot_r = _skeleton.find_bone("ball_r")
		_calf_l = _skeleton.find_bone("calf_l")
		_calf_r = _skeleton.find_bone("calf_r")


#region What a kind says
func _moves() -> Dictionary:
	return {}


func _strikes() -> Dictionary:
	return {}


## What follows a move of its own once it has run its length.
func _after(_what: int) -> void:
	_start(Act.NONE)


## Speed on top of the clip's own travel, this frame of the move: by default a
## step in under an attack's next blow, so it lands where he stands.
func _extra_velocity(_delta: float) -> Vector3:
	if _strikes().has(act) and not _leaps().has(act):
		return _close_gap()
	return Vector3.ZERO


## Attacks that carry it to him by their own travel (a leap), not stepped in.
func _leaps() -> Array:
	return []


## How long before and after each of a move's blow moments its weapon can
## land (seconds): `blow_window` unless a creature says otherwise for a move.
func _blow_window_for(_what: int) -> Vector2:
	return blow_window


## How near (body to body) it steps in under a move's next blow.
func _strike_off_for(_what: int) -> float:
	return strike_off


## How fast it turns to follow him before an attack's first blow.
func _track_rate(_what: int) -> float:
	return turn_speed * 0.5
#endregion


#region Clips
func _clip_of(what: int) -> StringName:
	return (_moves()[what] as Array)[0]


## Seconds the move lasts on the act clock.
func _move_length(what: int) -> float:
	var m: Array = _moves()[what]
	if _anim == null:
		return 0.6
	return _anim.clip_length(m[0]) * (float(m[3]) - float(m[2])) / float(m[1])


## Where the clip is, in its own seconds, this far into the move.
func _clip_time(what: int, t: float) -> float:
	var m: Array = _moves()[what]
	return _anim.clip_length(m[0]) * float(m[2]) + t * float(m[1])


## The moments of an attack's blows, in act seconds.
func _blow_moments(what: int) -> PackedFloat32Array:
	# Kinds can share a clip file and act numbers (the Biped Creatures' one
	# library): the move and its strike are part of the key.
	var key := "%s|%d|%s|%s" % [clip_meta, what, _moves().get(what, []), _strikes().get(what, [])]
	if _moment_cache.has(key):
		return _moment_cache[key]
	var out := PackedFloat32Array()
	if _anim != null:
		var m: Array = _moves()[what]
		var s: Array = _strikes()[what]
		var clip: StringName = m[0]
		var length := _anim.clip_length(clip)
		var threshold := float(s[4]) if s.size() > 4 else 0.6
		# Moments given by hand (shares of the clip) where the measure runs two
		# swings into one.
		var peaks: PackedFloat32Array = PackedFloat32Array(s[5]) if s.size() > 5 \
				else _anim.measure_peaks(clip, PackedStringArray(s[0]), threshold, 0.12)
		for p in peaks:
			if p < float(m[2]) or p > float(m[3]):
				continue
			out.append((p - float(m[2])) * length / float(m[1]))
		var wanted: int = (s[1] as Array).size()
		if out.size() > wanted:
			# Keep the latest ones: the fastest early motion is the wind-up.
			out = out.slice(out.size() - wanted)
		if out.is_empty():
			out.append(_move_length(what) * 0.45)
		_moment_cache[key] = out
	return out


## Where the hips have got to, forward and to its left, metres on this body.
func _hips(clip: StringName, t: float) -> Vector2:
	var m: Dictionary = _meta.get(String(clip), {})
	var path: Array = m.get("hips", [])
	if path.is_empty():
		return Vector2.ZERO
	var f := clampf(t * float(m.get("fps", 30.0)), 0.0, float(path.size() - 1))
	var i := int(f)
	var j := mini(i + 1, path.size() - 1)
	var a: Array = path[i]
	var b: Array = path[j]
	var w := f - float(i)
	return Vector2(lerpf(float(a[0]), float(b[0]), w), lerpf(float(a[1]), float(b[1]), w)) \
			* maxf(visual_scale, 0.01)
#endregion


#region Acting
func _begin(what: int) -> void:
	_start(what)
	_act_length = _move_length(what)
	_move_fwd = _forward()
	_move_right = _move_fwd.cross(Vector3.UP)
	_stretch = 1.0
	_last_hips = _hips(_clip_of(what), _clip_time(what, 0.0))
	if _strikes().has(what):
		stamina = maxf(stamina - attack_cost, 0.0)
		_regen_wait = regen_delay
		_arm(what)


## Turns the frame travel is laid along to the way it faces now.
func _reframe() -> void:
	_move_fwd = _forward()
	_move_right = _move_fwd.cross(Vector3.UP)


## Lays the attack's blows along its limbs, live around each moment.
func _arm(what: int) -> void:
	if _skeleton == null:
		return
	var s: Array = _strikes()[what]
	var limbs: Array = s[1]
	var moments := _blow_moments(what)
	var worth := hit_damage * float(s[2])
	var count: int = s[3]
	for i in moments.size():
		var limb: String = limbs[mini(i, limbs.size() - 1)]
		var blow := _chain_blow + i
		var serial := _chain_serial if _chain_serial >= 0 else act_serial
		var window := _blow_window_for(what)
		_sweeps.append(WeaponSweep.blow(_limb(limb), blow_min_speed, moments[i] - window.x,
				moments[i] + window.y,
				act_serial, func(who: Node3D) -> void:
					var how := _blow_kind(what)
					if how.is_empty():
						who.call("receive_blow", worth * _blow_worth(what), self, blow, count, serial)
					else:
						who.call("receive_blow", worth * _blow_worth(what), self, blow, count, serial, false, how)
					_blow_reached(who, what)))


## What kind of blow move `what` lands ([method Player._blow_kind]): "" for
## an ordinary one, "guard" a kick through the shield, "crush" a blow no
## shield holds, "ground" a shock along the ground, "stomp" one at him lying.
func _blow_kind(_what: int) -> StringName:
	return &""


## A share on top of the move's own worth, as it lands (a creature enraged).
func _blow_worth(_what: int) -> float:
	return 1.0


## Host: one of its blows (of act `what`) has reached `who` (he may yet have
## blocked it on his own peer): for what a creature does to him besides the
## blow — a ghoul's poison, a goblin's hand in his purse.
func _blow_reached(_who: Node3D, _what: int) -> void:
	pass


func _limb(which: String) -> Callable:
	match which:
		"claw":
			return _claw_part
		"feet":
			return _feet_part
	return _weapon_part


func _weapon_part() -> Array:
	if _hand_r < 0:
		return []
	return [WeaponSweep.bones(_skeleton, _hand_r, _hand_r, weapon_radius * maxf(visual_scale, 0.01), weapon_tip)]


func _claw_part() -> Array:
	if _fore_l < 0 or _hand_l < 0:
		return []
	var s := maxf(visual_scale, 0.01)
	var out := [WeaponSweep.bones(_skeleton, _fore_l, _hand_l, claw_radius * s)]
	if _tip_l >= 0:
		out.append(WeaponSweep.bones(_skeleton, _hand_l, _tip_l, claw_radius * s))
	return out


func _feet_part() -> Array:
	var out := []
	var s := maxf(visual_scale, 0.01)
	if _calf_l >= 0 and _foot_l >= 0:
		out.append(WeaponSweep.bones(_skeleton, _calf_l, _foot_l, foot_radius * s))
	if _calf_r >= 0 and _foot_r >= 0:
		out.append(WeaponSweep.bones(_skeleton, _calf_r, _foot_r, foot_radius * s))
	return out


func _play_act() -> void:
	var moves := _moves()
	if not moves.has(act):
		super()
		return
	var m: Array = moves[act]
	_anim.play(m[0], _fade_in(act), float(m[1]), 1.0, true)
	_anim.seek(_anim.clip_length(m[0]) * float(m[2]))


## How quickly a move takes over from what was playing.
func _fade_in(_what: int) -> float:
	return 0.12


func _run_act(delta: float) -> void:
	if not _moves().has(act):
		super(delta)
		return
	var v := _carry(delta) + _extra_velocity(delta)
	velocity.x = v.x
	velocity.z = v.z
	if _act_time >= _act_length:
		_after(act)


## The speed the clip's own travel asks for this frame. Before an attack's
## first blow it keeps turning to him.
func _carry(delta: float) -> Vector3:
	if _strikes().has(act):
		_track_before_blow(delta)
	var hips := _hips(_clip_of(act), _clip_time(act, _act_time))
	var step := hips - _last_hips
	_last_hips = hips
	return (_move_fwd * step.x * _stretch - _move_right * step.y) / maxf(delta, 0.0001)
#endregion


#region Moving about
func _play_locomotion(_delta: float) -> void:
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var pace := planar.length()
	var roused := mode == Mode.CHASE or mode == Mode.FIGHT
	if pace < 0.15:
		if _anim.current_clip() != idle_clip or _anim.clip_progress() >= 1.0:
			_anim.play(idle_clip, 0.25, 1.0)
		return
	var ahead := _forward()
	var right := ahead.cross(Vector3.UP)
	var fwd := planar.dot(ahead)
	var side := planar.dot(right)
	var clip := walk_clip
	var reverse := false
	if absf(side) > absf(fwd) * 1.1 and not strafe_r_clip.is_empty():
		clip = strafe_r_clip if side > 0.0 else strafe_l_clip
	elif fwd < 0.0:
		if not back_clip.is_empty():
			clip = back_clip
			if not back_run_clip.is_empty() and _would_run(back_clip, back_run_clip, pace):
				clip = back_run_clip
		else:
			# No clip of its own to go back with: its walk, played backwards.
			reverse = true
	elif not run_clip.is_empty() and _would_run(walk_clip, run_clip, pace):
		clip = run_clip
	elif roused and not roused_walk_clip.is_empty():
		clip = roused_walk_clip
	var rate := gait_rate(clip, pace)
	_anim.play(clip, 0.2, rate)
	if reverse:
		_anim.rewind(rate)


## Whether at `pace` it goes at its run rather than its walk.
func _would_run(walk: StringName, run: StringName, pace: float) -> bool:
	var ground := _anim.measure_ground_speed(walk) * maxf(visual_scale, 0.01)
	if ground <= 0.05:
		return pace > run_above
	var limit := walk_rate_max
	if _anim.current_clip() == run:
		limit -= 0.1
	return pace / ground > limit


## The rate a cycle clip plays at for the feet to keep to the ground at `pace`
## (m/s): by how fast the clip's planted foot goes by under it
## ([method SkeletonAnim.measure_ground_speed]), else by the width of its
## stride; kept between `gait_floor` and `chase_retime_max`.
func gait_rate(clip: StringName, pace: float) -> float:
	var ground := _anim.measure_ground_speed(clip) * maxf(visual_scale, 0.01)
	var rate := 1.0
	if ground > 0.05:
		rate = pace / ground
	else:
		var stride := maxf(_anim.measure_stride(clip), 0.1) * maxf(visual_scale, 0.01)
		if clip == run_clip:
			# a run's feet leave the ground: it covers more than its widest step
			stride *= run_stride_gain
		rate = pace * _anim.clip_length(clip) / stride
	return clampf(rate, gait_floor, chase_retime_max)
#endregion


#region Stepping in
func _track_before_blow(delta: float) -> void:
	if _quarry == null:
		return
	var first := _blow_moments(act)[0]
	if _act_time < first - 0.2:
		_face(_quarry.global_position - global_position, delta, _track_rate(act))
		_reframe()


func _close_gap() -> Vector3:
	if _quarry == null:
		return Vector3.ZERO
	var next := -1.0
	for m in _blow_moments(act):
		if m > _act_time:
			next = m
			break
	if next < 0.0:
		return Vector3.ZERO
	var gap := _distance_to(_quarry)
	var off := _strike_off_for(act)
	if gap <= off:
		return Vector3.ZERO
	return _forward() * minf((gap - off) / maxf(next - _act_time, 0.15), close_speed)
#endregion
