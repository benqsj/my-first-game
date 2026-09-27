class_name WolfRig
extends Node3D

## The wolf-man's body: `assets/wolf/wolf_beast.glb`, built in Blender
## (vepxis-art/tools/wolf_build.py) as one mesh per bone on a Tariel-style
## skeleton, and moved by Mixamo's clips laid onto that skeleton
## (tools/retarget_mixamo.py): WF_*.
##
## It runs down its quarry on all fours (Running Crawl), rises to fight (the
## mutant set: a breathing idle, a brutal walk, swipes with either paw, a
## pounce), staggers when a swipe is thrown back off a shield, drags itself on
## its belly with both legs gone (Zombie Crawl), and dies falling onto its back.
## Over the clips: the jaws open as it strikes, the tail swings behind it, and a
## red glint gathers on the claws about to come through.
##
## Every part hangs off its bone whole ([BoneAttachment3D]), so a limb the
## knight's blade takes is hidden here and dropped as a piece of its own, and a
## blow is measured against the parts themselves.
##
## [Wolf] drives it: `animate()` once a frame with how fast it is going and
## whether it is fighting, `swipe()` and `lunge()` to attack, `reel()` when a
## swipe is thrown back, `fall()` once it is dead.

signal severed(part: String)

## Limbs that come off, by the bone their subtree starts at.
const SEVERABLE := {
	"head": "head",
	"left arm": "upperarm_l",
	"right arm": "upperarm_r",
	"left leg": "thigh_l",
	"right leg": "thigh_r",
	"tail": "tail_01",
}

const IDLE := &"WF_Idle"
const WALK := &"WF_Walk"
const RUN := &"WF_Crawl_Run"
const DRAG := &"WF_Drag"
const SWIPE_L := &"WF_Swipe_L"
const SWIPE_R := &"WF_Swipe_R"
const POUNCE := &"WF_Pounce"
const STAGGER := &"WF_Stagger"
const DEATH := &"WF_Death"
const BACK := &"WF_Back"
const STRAFE_L := &"WF_Strafe_L"
const STRAFE_R := &"WF_Strafe_R"
const DODGE_L := &"WF_SideL"
const DODGE_R := &"WF_SideR"
const HOP_BACK := &"WF_Hop_Back"
const BITE := &"WF_Bite"
const CRAWL_WALK := &"WF_Crawl_Walk"
const RUN_UPRIGHT := &"WF_Run"
## Its hand-to-hand, beyond the swipes (Mixamo, laid on in wolf_export.py): an
## overhead two-handed smash, a zombie's raking swipe, a two- and a three-blow
## combo, and a quick jab. Driven by [Wolf]'s `MELEE`.
const SLAM := &"WF_Slam"
const RAKE := &"WF_Rake"
const COMBO3 := &"WF_Combo3"
const COMBO2 := &"WF_Combo2"
const PUNCH := &"WF_Punch"
## Out of a run, straight on through him: a spinning rake of both claws
## (Great Sword High Spin Attack From Run), and a leap off the run coming down
## in a two-handed smash (Running Jump With Attack With Axe).
const RUN_SPIN := &"WF_RunSpin"
const RUN_AXE := &"WF_RunAxe"
const GROWL := "res://unverified/sounds/orc/orc-aggressive-sound1.wav"

## The coats a wolf can be born with — the colour of each fur material — and
## how often each comes up.
const COATS := [
	{"name": "black", "weight": 25, "wolf_fur": Color(0.06, 0.058, 0.062), "wolf_fur_mid": Color(0.04, 0.038, 0.042),
		"wolf_fur_dark": Color(0.018, 0.017, 0.02), "wolf_fur_light": Color(0.2, 0.19, 0.19)},
	{"name": "dark grey", "weight": 30, "wolf_fur": Color(0.15, 0.155, 0.165), "wolf_fur_mid": Color(0.1, 0.1, 0.11),
		"wolf_fur_dark": Color(0.045, 0.045, 0.05), "wolf_fur_light": Color(0.4, 0.4, 0.42)},
	{"name": "grey-brown", "weight": 25, "wolf_fur": Color(0.3, 0.265, 0.23), "wolf_fur_mid": Color(0.21, 0.185, 0.16),
		"wolf_fur_dark": Color(0.13, 0.115, 0.105), "wolf_fur_light": Color(0.64, 0.58, 0.5)},
	{"name": "pale grey", "weight": 10, "wolf_fur": Color(0.32, 0.32, 0.33), "wolf_fur_mid": Color(0.23, 0.23, 0.24),
		"wolf_fur_dark": Color(0.12, 0.12, 0.13), "wolf_fur_light": Color(0.6, 0.59, 0.57)},
	{"name": "russet", "weight": 10, "wolf_fur": Color(0.32, 0.2, 0.12), "wolf_fur_mid": Color(0.22, 0.14, 0.09),
		"wolf_fur_dark": Color(0.1, 0.07, 0.05), "wolf_fur_light": Color(0.62, 0.52, 0.4)},
]
const LOOPS: Array[StringName] = [&"WF_Idle", &"WF_Walk", &"WF_Crawl_Run", &"WF_Drag", &"WF_Run",
		&"WF_Crawl_Walk", &"WF_Back", &"WF_Strafe_L", &"WF_Strafe_R"]

#region Exported tuning
@export_group("Attack")
## How long a swipe takes, and the share of it spent winding up: the claws come
## through at the end of the windup.
@export var swipe_duration: float = 0.85
@export var swipe_windup: float = 0.55
## The pounce: how long, and the share of it spent gathering.
## A long gather before it — crouched low, eyes flaring, a growl — so the leap
## can be seen coming.
@export var lunge_duration: float = 1.35
@export var lunge_windup: float = 0.6
## How low it crouches in that gather, metres.
@export var crouch: float = 0.4

@export_group("Pace")
## Metres a second each cycle carries it at rate 1: what the clips are sped up
## or slowed against so the feet do not skate. At the wolf's size in
## `wolf.tscn` (1.65; they were measured at 1.1 and scaled with it).
@export var walk_pace: float = 1.87
@export var run_pace: float = 6.31
@export var drag_pace: float = 0.75
@export var back_pace: float = 1.65
@export var strafe_pace: float = 2.4
@export var crawl_walk_pace: float = 1.12
@export var upright_run_pace: float = 6.6
## Faster than this it drops to all fours.
@export var run_from: float = 2.8
#endregion

var _anim: AnimationPlayer
var _skeleton: Skeleton3D
## bone name -> the attachments hanging off it.
var _parts: Dictionary = {}
var _lost: Dictionary = {}
var _rng := RandomNumberGenerator.new()
## Where the last limb came off, so the blow can bleed from the right place.
var last_cut_point: Vector3 = Vector3.ZERO

var _swipe_timer: float = 0.0
var _lunge_timer: float = 0.0
var _reel_timer: float = 0.0
## A dodge, a hop back, a bite or a lunge from the ground under way.
var _move_timer: float = 0.0
## How it is moving over the ground, in its own frame (-Z ahead, +X to its
## right), set by [Wolf] each frame: what picks walking, backing and circling.
var move_local := Vector3.ZERO
## 1: it goes about on all fours; 0: on its hind legs. Set by [Wolf].
var gait: float = 1.0
## Looking about, 0 to 1, while it stands on its beat (set by [Wolf]).
var look_about: float = 0.0
## How far the belly-crawl has let the body down, smoothed.
var _ground_drop: float = 0.0
var _neck: int = -1
var _head: int = -1
var _eye_mat: StandardMaterial3D
var _eye_base: float = 1.0
var _look_phase: float = 0.0
var _growled: bool = false
var _swipe_left: bool = true
var _dead: bool = false
var _stance: float = 1.0
var _one_shot: StringName = &""
## The moment in each attack clip its claws move fastest, seconds from its start.
var _strike_at: Dictionary = {}

var _root_bone: int = -1
var _jaw: int = -1
var _tail: Array[int] = []
var _tail_swing: PackedFloat32Array = PackedFloat32Array()
var _claw_tips: Dictionary = {}
var _wrists: Dictionary = {}
var _trail_l: BladeArc
var _trail_r: BladeArc
var _glints: Dictionary = {}
var _clock: float = 0.0
## The claw wave: its clips and its tell ([WolfClaw]).
var claw: WolfClaw
## A leap at the end of a run under way: seconds left, how long it all takes
## and how much of that is the gather.
var _leap_timer: float = 0.0
var _leap_len: float = 0.0
var _leap_gather: float = 0.0
## A hand-to-hand move under way ([method melee]): seconds left, the rate it is
## played at, and a hold at the top of its windup — the delayed blow, a
## souls-like's way of making the timing a thing to read, not to learn by rote.
var _melee_timer: float = 0.0
var _melee_rate: float = 1.0
var _hold_at: float = -1.0
var _hold_left: float = 0.0
## A blow landing, in either direction: the clip all but stops for this long,
## so the hit is felt.
var _hitstop: float = 0.0
## The clip times a melee move's blows land at: the trails show round them.
var _melee_hits: Array = []


func _ready() -> void:
	_rng.randomize()
	_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _skeleton == null or _anim == null:
		push_warning("WolfRig: no skeleton or no clips.")
		return
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in LOOPS:
		if _anim.has_animation(clip):
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for node in _skeleton.find_children("*", "BoneAttachment3D", true, false):
		var at := node as BoneAttachment3D
		var list: Array = _parts.get(String(at.bone_name), [])
		list.append(at)
		_parts[String(at.bone_name)] = list
	_root_bone = _skeleton.find_bone("root")
	_jaw = _skeleton.find_bone("jaw")
	_neck = _skeleton.find_bone("neck_01")
	_head = _skeleton.find_bone("head")
	for n in ["tail_01", "tail_02", "tail_03", "tail_04"]:
		var b := _skeleton.find_bone(n)
		if b >= 0:
			_tail.append(b)
	_tail_swing.resize(_tail.size())
	for clip in [SWIPE_L, SWIPE_R, POUNCE, &"WF_Punch", BITE]:
		_strike_at[clip] = _fastest(clip)
	for clip in CARRIED:
		_carry_out(clip)
	for clip in _anim.get_animation_list():
		if not LOOPS.has(StringName(clip)):
			_travel_out(StringName(clip))
	_mark_claws()
	claw = WolfClaw.new(self, _anim, _skeleton)
	react = HitReact.on_bones(_skeleton, BENDS, BEND_SHARES)
	_anim.play(IDLE)
	_anim.advance(0.0)
	_look_phase = _rng.randf() * TAU


## Its coat, the same on every peer: from its name. Each fur material is
## swapped for the coat's colour (one set of copies per coat, shared by every
## wolf wearing it), and the eyes get a copy of their own to flare.
static var _coat_sets: Dictionary = {}


func dress(key: String) -> void:
	if _skeleton == null:
		return
	var total := 0
	for c: Dictionary in COATS:
		total += int(c.weight)
	var pick := RandomNumberGenerator.new()
	pick.seed = hash(key + "/coat")
	var roll := pick.randi() % total
	var coat: Dictionary = COATS[0]
	for c: Dictionary in COATS:
		roll -= int(c.weight)
		if roll < 0:
			coat = c
			break
	var copies: Dictionary = _coat_sets.get(coat.name, {})
	_coat_sets[coat.name] = copies
	for node in _skeleton.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(i) as StandardMaterial3D
			if mat == null:
				continue
			var key_name := mat.resource_name
			if coat.has(key_name):
				if not copies.has(key_name):
					var tinted := mat.duplicate() as StandardMaterial3D
					tinted.albedo_color = coat[key_name] as Color
					copies[key_name] = tinted
				mesh.set_surface_override_material(i, copies[key_name])
			elif key_name == "wolf_eye":
				if _eye_mat == null:
					_eye_mat = mat.duplicate() as StandardMaterial3D
					_eye_mat.emission_enabled = true
					_eye_base = maxf(_eye_mat.emission_energy_multiplier, 1.0)
				mesh.set_surface_override_material(i, _eye_mat)
	coat_name = String(coat.name)


var coat_name: String = ""


## Clips that throw the whole body somewhere — the pounce's leap, up off the
## ground and a metre and a half on — with that throw in the hips. Left in, the
## hips fly while the body stays put, or the body is shoved along the ground
## while the hips fly: a wolf that slides at you rather than leaps. So the
## throw is taken out of the pose ([method _carry_out]) and handed to [Wolf],
## which carries the body along it ([method carry]), stretched to land on
## whoever it is leaping at — the pose and the flight the same moment.
const CARRIED: Array[StringName] = [POUNCE, RUN_AXE]
## Clip -> its throw: {"t": clip times, "fwd": metres on, "up": metres up off
## the ground, "off": when it leaves the ground, "land": when it is down again},
## in the wolf body's own frame. The clips are shared by every wolf, so they
## are worked on once.
static var _carries: Dictionary = {}


## Takes the hips' travel out of `clip` — forward, and up above where they
## stand — and keeps it as the clip's throw.
func _carry_out(clip: StringName) -> void:
	if _carries.has(clip) or not _anim.has_animation(clip):
		return
	var anim := _anim.get_animation(clip)
	var pelvis := _skeleton.find_bone("pelvis")
	var body := get_parent() as Node3D
	if pelvis < 0 or body == null:
		return
	var track := -1
	var root_track := -1
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var path := String(anim.track_get_path(i))
		if path.ends_with(":pelvis"):
			track = i
		elif path.ends_with(":root"):
			root_track = i
	if track < 0 or anim.track_get_key_count(track) < 2:
		return
	# The throw on is in the root (which [method animate] keeps pinned where it
	# rests, so the clip already stands still); the throw up is in the hips,
	# above where they stand, and is taken out of them here. Both in the body's
	# own frame: through the rig and the skeleton under it, and for the hips
	# their parent at rest.
	var parent := _skeleton.get_bone_parent(pelvis)
	var skel_to_body := body.global_transform.affine_inverse() * _skeleton.global_transform
	var to_body := skel_to_body
	if parent >= 0:
		to_body = to_body * _skeleton.get_bone_global_rest(parent)
	var from_body := to_body.affine_inverse()
	var start: Vector3 = to_body * (anim.track_get_key_value(track, 0) as Vector3)
	var root_start := Vector3.ZERO
	var axis := Vector3.FORWARD
	if root_track >= 0:
		root_start = skel_to_body * anim.position_track_interpolate(root_track, 0.0)
		var root_end := skel_to_body * anim.position_track_interpolate(root_track, anim.length)
		var drift := root_end - root_start
		drift.y = 0.0
		if drift.length() > 0.2:
			axis = drift.normalized()
	var times := PackedFloat32Array()
	var fwd := PackedFloat32Array()
	var up := PackedFloat32Array()
	for k in anim.track_get_key_count(track):
		var time := anim.track_get_key_time(track, k)
		var at: Vector3 = to_body * (anim.track_get_key_value(track, k) as Vector3)
		var rise := maxf(at.y - start.y, 0.0)
		var on := 0.0
		if root_track >= 0:
			on = (skel_to_body * anim.position_track_interpolate(root_track, time) - root_start).dot(axis)
		times.append(time)
		fwd.append(on)
		up.append(rise)
		anim.track_set_key_value(track, k, from_body * (at - Vector3.UP * rise))
	var off := -1.0
	var land := -1.0
	var top := 0
	for k in up.size():
		if up[k] > up[top]:
			top = k
	for k in up.size():
		if off < 0.0 and up[k] > 0.03:
			off = times[k]
		if k > top and land < 0.0 and up[k] < 0.03:
			land = times[k]
	if off < 0.0 or land < 0.0:
		return
	_carries[clip] = {"t": times, "fwd": fwd, "up": up, "off": off, "land": land}


## The throw of the clip playing now, if it is one of [constant CARRIED] and
## still in the air or about to leave the ground: {"clip", "time", "carry"},
## or empty.
func carry() -> Dictionary:
	if _anim == null or _dead or not _anim.is_playing():
		return {}
	var clip := StringName(_anim.current_animation)
	if not _carries.has(clip):
		return {}
	return {"clip": clip, "time": _anim.current_animation_position, "carry": _carries[clip]}


## The throw of `clip` if it is one of [constant CARRIED], else empty.
func throw_of(clip: StringName) -> Dictionary:
	return _carries.get(clip, {})


func has_clip(clip: StringName) -> bool:
	return _anim != null and _anim.has_animation(clip)


## Where along its throw a clip is at `time`: (metres on, metres up).
static func carry_at(throw: Dictionary, time: float) -> Vector2:
	var t: PackedFloat32Array = throw["t"]
	var fwd: PackedFloat32Array = throw["fwd"]
	var up: PackedFloat32Array = throw["up"]
	if time <= t[0]:
		return Vector2(fwd[0], up[0])
	for k in range(1, t.size()):
		if time <= t[k]:
			var w := (time - t[k - 1]) / maxf(t[k] - t[k - 1], 0.0001)
			return Vector2(lerpf(fwd[k - 1], fwd[k], w), lerpf(up[k - 1], up[k], w))
	return Vector2(fwd[fwd.size() - 1], up[up.size() - 1])


## Clip -> where its root goes, in the wolf body's own frame, from where it
## started: {"t": times, "p": positions}; empty for a clip that stays put.
## The root is pinned while it plays ([method animate]), so this is the travel
## [Wolf] carries the body along instead ([method ride]).
static var _travels: Dictionary = {}


func _travel_out(clip: StringName) -> void:
	if _travels.has(clip) or not _anim.has_animation(clip):
		return
	var anim := _anim.get_animation(clip)
	var body := get_parent() as Node3D
	var root_track := -1
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_POSITION_3D and String(anim.track_get_path(i)).ends_with(":root"):
			root_track = i
	if root_track < 0 or body == null:
		_travels[clip] = {}
		return
	var basis := (body.global_transform.affine_inverse() * _skeleton.global_transform).basis
	var start := anim.position_track_interpolate(root_track, 0.0)
	var times := PackedFloat32Array()
	var points := PackedVector3Array()
	var most := 0.0
	var steps := maxi(int(anim.length * 30.0), 1)
	for i in steps + 1:
		var t := anim.length * i / steps
		var at := basis * (anim.position_track_interpolate(root_track, t) - start)
		at.y = 0.0
		times.append(t)
		points.append(at)
		most = maxf(most, at.length())
	_travels[clip] = {"t": times, "p": points} if most > 0.12 else {}


static func _travel_at(travel: Dictionary, time: float) -> Vector3:
	var t: PackedFloat32Array = travel["t"]
	var p: PackedVector3Array = travel["p"]
	if time <= t[0]:
		return p[0]
	for k in range(1, t.size()):
		if time <= t[k]:
			return p[k - 1].lerp(p[k], (time - t[k - 1]) / maxf(t[k] - t[k - 1], 0.0001))
	return p[p.size() - 1]


## How far the root of `clip` goes on, in the body's frame, from clip time
## `from` to `to`.
func travel_between(clip: StringName, from: float, to: float) -> Vector3:
	var travel: Dictionary = _travels.get(clip, {})
	if travel.is_empty():
		return Vector3.ZERO
	return _travel_at(travel, to) - _travel_at(travel, from)


## When `clip`'s claws come through, clip time.
func strike_time(clip: StringName) -> float:
	return _strike_at.get(clip, 0.5)


## The clip playing, and how far into it.
func playing() -> String:
	return _anim.current_animation if _anim != null else ""


func playing_position() -> float:
	return _anim.current_animation_position if _anim != null and _anim.is_playing() else 0.0


## Playing a move rather than going about on its feet: an attack, a stagger, a
## dodge, a claw wave.
func is_acting() -> bool:
	return (claw != null and claw.active()) or _swipe_timer > 0.0 or _lunge_timer > 0.0 \
			or _reel_timer > 0.0 or _move_timer > 0.0 or _melee_timer > 0.0


## How the body has to move to go with what is playing, in its own frame, m/s:
## a move's own travel (a combo's steps in, a stagger's stumble back, a dodge),
## nothing at all for a move that stays put — so no move ever skates. Null
## while it is going about on its feet (the paces see to that) or in a leap's
## throw ([method carry]).
func ride() -> Variant:
	if _anim == null or _dead or not is_acting():
		return null
	var clip := StringName(_anim.current_animation)
	if _carries.has(clip):
		return null
	var slow := 0.06 if _hitstop > 0.0 else 1.0
	var rate := _anim.speed_scale * slow
	if LOOPS.has(clip):
		# A cycle played as a move (the ground lunge's crawl): its own pace.
		var pace := drag_pace if clip == DRAG else walk_pace
		return Vector3(0.0, 0.0, -pace * rate)
	var travel: Dictionary = _travels.get(clip, {})
	if travel.is_empty():
		return Vector3.ZERO
	var now := _anim.current_animation_position
	var step := 1.0 / 30.0
	return (_travel_at(travel, now + step) - _travel_at(travel, now)) / step * rate


## When a clip's claws move fastest — the moment a swipe arrives.
func _fastest(clip: StringName) -> float:
	if not _anim.has_animation(clip):
		return 0.5
	var anim := _anim.get_animation(clip)
	var hands := [_skeleton.find_bone("hand_l"), _skeleton.find_bone("hand_r")]
	var best := 0.0
	var when := anim.length * 0.5
	var last := []
	_anim.play(clip)
	var steps := 60
	for i in steps + 1:
		var t := anim.length * i / steps
		_anim.seek(t, true)
		var now := []
		for h in hands:
			now.append(_skeleton.get_bone_global_pose(h).origin if h >= 0 else Vector3.ZERO)
		if not last.is_empty():
			for k in now.size():
				var v: float = (now[k] as Vector3).distance_to(last[k])
				if v > best:
					best = v
					when = t
		last = now
	_anim.stop()
	return when


## Marks on each paw: the wrist, and the points of the claws.
func _mark_claws() -> void:
	for side in ["l", "r"]:
		var list: Array = _parts.get("hand_" + side, [])
		if list.is_empty():
			continue
		var holder := list[0] as Node3D
		var hand := _skeleton.find_bone("hand_" + side)
		var rest := _skeleton.get_bone_global_rest(hand)
		# The claws run on out along the bone, about 0.28 m past the wrist.
		var wrist := Marker3D.new()
		wrist.name = "Wrist"
		holder.add_child(wrist)
		var tip := Marker3D.new()
		tip.name = "ClawTip"
		tip.position = Vector3(0.0, 0.28, 0.0) / maxf(rest.basis.get_scale().y, 0.001)
		holder.add_child(tip)
		_wrists[side] = wrist
		_claw_tips[side] = tip
	_trail_l = _make_trail("l")
	_trail_r = _make_trail("r")


## The claws' cut through the air: three hot lines side by side, the marks of
## the claws, ash-white in a dull red halo, over hardly any sheet.
func _make_trail(side: String) -> BladeArc:
	if not _wrists.has(side):
		return null
	var trail := BladeArc.new()
	trail.name = "ClawArc_" + side
	trail.strands = 3
	trail.strand_gap = 0.14
	trail.sheet = 0.16
	trail.life = 0.26
	trail.taper = 0.35
	trail.tip_overshoot = 0.12
	trail.intensity = 1.7
	trail.core_color = Color(1.0, 0.94, 0.9)
	trail.glow_color = Color(0.85, 0.22, 0.16)
	trail.distortion = 0.008
	add_child(trail)
	trail.setup(_wrists[side], _claw_tips[side])
	return trail


#region Driving it
## Once a frame from [Wolf]: how fast it is going over the ground, that against
## its prowl (unused: the clips are timed to the ground itself), and 1 to run on
## all fours or 0 to stand and fight.
func animate(delta: float, planar_speed: float, _speed_ratio: float, stance_target: float) -> void:
	if _anim == null:
		return
	_clock += delta
	var raw := delta
	# A blow landing: the whole body all but stops a moment.
	if _hitstop > 0.0:
		_hitstop -= delta
		delta *= 0.06
	_melee_timer = maxf(_melee_timer - delta, 0.0)
	if _hold_left > 0.0 and _melee_timer > 0.0 and _anim.current_animation_position >= _hold_at:
		_hold_left -= delta
		_anim.speed_scale = 0.03 if _hold_left > 0.0 else _melee_rate
	_swipe_timer = maxf(_swipe_timer - delta, 0.0)
	_lunge_timer = maxf(_lunge_timer - delta, 0.0)
	_reel_timer = maxf(_reel_timer - delta, 0.0)
	_move_timer = maxf(_move_timer - delta, 0.0)
	_stance = stance_target
	if not _dead:
		_choose(planar_speed)
	if claw != null:
		claw.drive(delta)
	_anim.advance(delta)
	# The clips are kept on the spot; the body is what moves it.
	if _root_bone >= 0:
		_skeleton.set_bone_pose_position(_root_bone, _skeleton.get_bone_rest(_root_bone).origin)
		if is_crippled() and not _dead:
			_rest_on_ground(delta)
	_overlay(delta)
	if claw != null:
		claw.overlay(delta)
	# Thrown over by a blow, on top of everything else: on the real clock, so
	# the jolt goes through the body even while the hitstop holds the clip.
	if react != null and not _dead:
		react.drive(raw)
	if _leap_timer > 0.0:
		_leap_timer = maxf(_leap_timer - delta, 0.0)
		# The claws flash up as it gathers, and stay lit through the leap.
		var since := _leap_len - _leap_timer
		_glint(clampf(since / maxf(_leap_gather, 0.01), 0.0, 1.0) if since < _leap_len - 0.3 else 0.0, 2.0)
	var swiping := _swipe_timer > 0.0 and _swipe_timer < swipe_duration * (1.0 - swipe_windup)
	if _trail_l != null:
		_trail_l.emitting = (swiping and _swipe_left) or _lunging_through() or (claw != null and claw.slashing("l")) or _leaping_through() or _slashing()
	if _trail_r != null:
		_trail_r.emitting = (swiping and not _swipe_left) or _lunging_through() or (claw != null and claw.slashing("r")) or _leaping_through() or _slashing()


## Down on its belly, the body is let down until the lowest joint left on it is
## just off the ground. Measured from the bones as posed this frame (the parts
## hanging off them follow a frame later, and measuring those set it bobbing),
## and eased, so it settles rather than twitches.
func _rest_on_ground(delta: float) -> void:
	var body := get_parent() as Node3D
	if body == null:
		return
	var lowest := INF
	var frame := _skeleton.global_transform
	for bone_name: String in _parts:
		var shown := false
		for at: BoneAttachment3D in _parts[bone_name]:
			shown = shown or at.visible
		if not shown:
			continue
		var b := _skeleton.find_bone(bone_name)
		lowest = minf(lowest, (frame * _skeleton.get_bone_global_pose(b).origin).y)
	if is_inf(lowest):
		return
	# Joints sit inside the flesh: about a hand's depth of it below them.
	var want := lowest - 0.1 - body.global_position.y
	_ground_drop = lerpf(_ground_drop, want, 1.0 - exp(-8.0 * delta))
	var down := _skeleton.global_transform.basis.inverse() * Vector3(0.0, -_ground_drop, 0.0)
	_skeleton.set_bone_pose_position(_root_bone, _skeleton.get_bone_rest(_root_bone).origin + down)


func _lunging_through() -> bool:
	return _lunge_timer > 0.0 and _lunge_timer < lunge_duration * (1.0 - lunge_windup)


## The clip for what it is doing now, when no attack or stagger is playing.
func _choose(planar: float) -> void:
	if claw != null and claw.active():
		return
	if _swipe_timer > 0.0 or _lunge_timer > 0.0 or _reel_timer > 0.0 or _move_timer > 0.0 \
			or _melee_timer > 0.0:
		return
	var clip := IDLE
	var pace := 1.0
	var side := move_local.x
	var ahead := -move_local.z
	if is_crippled():
		clip = DRAG
		pace = clampf(planar / drag_pace, 0.3, 2.2) if planar > 0.1 else 0.3
	elif planar > 0.25 and absf(side) > absf(ahead) * 1.2 and _stance < 0.5:
		# Circling him, face on.
		clip = STRAFE_R if side > 0.0 else STRAFE_L
		pace = clampf(absf(side) / strafe_pace, 0.6, 1.8)
	elif planar > 0.25 and ahead < -0.3 and _stance < 0.5:
		# Backing off, face on.
		clip = BACK
		pace = clampf(-ahead / back_pace, 0.6, 1.8)
	elif _stance > 0.5 and gait > 0.5:
		# About the world on all fours: a slow crawl on its beat, the run after him,
		# and standing it holds the crawl's pose, low on its four feet.
		if planar > run_from:
			clip = RUN
			pace = clampf(planar / run_pace, 0.4, 2.2)
		else:
			clip = CRAWL_WALK
			pace = clampf(planar / crawl_walk_pace, 0.3, 2.5) if planar > 0.2 else 0.0
	elif planar > run_from and (ahead > 0.3 or _stance > 0.5):
		# Running, fighting or not: a fight's walk sped up past its stride would
		# skate. On all fours if that is how it goes.
		clip = RUN if gait > 0.5 else RUN_UPRIGHT
		pace = clampf(planar / (run_pace if gait > 0.5 else upright_run_pace), 0.4, 2.2 if gait > 0.5 else 1.8)
	elif planar > 0.25:
		clip = WALK
		pace = clampf(planar / walk_pace, 0.3, 1.5)
	if not _anim.has_animation(clip):
		clip = IDLE
	if _anim.current_animation != String(clip):
		_anim.play(clip, 0.25)
	_anim.speed_scale = pace


## Plays `clip` so that its fastest moment comes `arrive` seconds from now.
## `whole`: from the clip's own start, sped up to fit — for a leap, whose
## crouch before it leaves the ground is the tell and must not be skipped.
func _strike(clip: StringName, arrive: float, whole: bool = false) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	var peak: float = _strike_at.get(clip, 0.5)
	var rate := 1.0
	var start := peak - arrive * rate
	if whole:
		start = -1.0
	if start < 0.0:
		# The clip's own windup is shorter than asked for: slowed to fit.
		rate = peak / maxf(arrive, 0.05)
		start = 0.0
	_anim.play(clip, 0.1)
	_anim.seek(start, true)
	_anim.speed_scale = rate


## Starts a claw swipe, alternating paws so it never rakes with the same one twice.
func swipe() -> void:
	_swipe_left = not _swipe_left
	if _swipe_left and has_lost("left arm"):
		_swipe_left = false
	elif not _swipe_left and has_lost("right arm"):
		_swipe_left = true
	_swipe_timer = swipe_duration
	_strike(SWIPE_L if _swipe_left else SWIPE_R, swipe_duration * swipe_windup)


## A pounce: down on its haunches, then thrown forward, both claws raking.
func lunge() -> void:
	_lunge_timer = lunge_duration
	_strike(POUNCE, lunge_duration * lunge_windup, true)
	# The tell, heard as well as seen.
	var body := get_parent() as Node3D
	if body != null and ResourceLoader.exists(GROWL):
		Sfx.play(body, GROWL, null, body.global_position + Vector3.UP, 1.45, -8.0)


## Thrown back off a shield, or knocked by a skill: it staggers.
func reel(length: float = Recoil.STAGGER) -> void:
	if _anim == null or _dead:
		return
	_swipe_timer = 0.0
	_lunge_timer = 0.0
	_reel_timer = length
	_leap_timer = 0.0
	_melee_timer = 0.0
	_hold_left = 0.0
	if claw != null:
		claw.cancel()
	if _anim.has_animation(STAGGER):
		_anim.play(STAGGER, 0.08)
		_anim.seek(0.0, true)
		_anim.speed_scale = _anim.get_animation(STAGGER).length / maxf(length, 0.2) * 0.8


## A move of its own, not an attack's timing: plays `clip` from `from` at
## `rate`, and nothing else is chosen over it for `length` seconds.
func _move(clip: StringName, length: float, rate: float = 1.0, from: float = 0.0) -> void:
	if _anim == null or _dead or not _anim.has_animation(clip):
		return
	_swipe_timer = 0.0
	_lunge_timer = 0.0
	_move_timer = length
	_leap_timer = 0.0
	_melee_timer = 0.0
	_hold_left = 0.0
	if claw != null:
		claw.cancel()
	_anim.play(clip, 0.08)
	_anim.seek(from, true)
	_anim.speed_scale = rate


## At the end of a run, straight on at him off all fours, claws out: it gathers
## for `gather` seconds (a snarl, the claws flashing) and is in the air for
## `flight`; the claws come through as it lands.
func run_leap(gather: float, flight: float) -> void:
	if _anim == null or _dead:
		return
	_swipe_timer = 0.0
	_lunge_timer = 0.0
	_leap_gather = gather
	_leap_len = gather + flight + 0.35
	_strike(POUNCE, gather + flight * 0.8, true)
	_move_timer = _leap_len
	_leap_timer = _leap_len
	var body := get_parent() as Node3D
	if body != null and ResourceLoader.exists(GROWL):
		Sfx.play(body, GROWL, null, body.global_position + Vector3.UP, 1.7, -8.0)


## Out of a run, a blow: `clip` from `from` at `rate`, for `length` seconds;
## its blows at `hits` (clip time) flare and trail like a melee's.
func run_strike(clip: StringName, rate: float, from: float, length: float, hits: Array) -> void:
	melee(clip, rate, from, length, -1.0, 0.0, hits)
	var body := get_parent() as Node3D
	if body != null and ResourceLoader.exists(GROWL):
		Sfx.play(body, GROWL, null, body.global_position + Vector3.UP, 1.55, -7.0)


## A run's leap under way, from the gather to the landing.
func is_leaping() -> bool:
	return _leap_timer > 0.0


func _leaping_through() -> bool:
	return _leap_timer > 0.0 and _leap_len - _leap_timer > _leap_gather


## Thrown aside, out of a blow's way: -1 to its left, 1 to its right.
func dodge(side: float) -> void:
	_move(DODGE_R if side > 0.0 else DODGE_L, 0.55, 1.5)


## A hop back out of reach.
func hop_back() -> void:
	var clip_len := _anim.get_animation(HOP_BACK).length if _anim != null and _anim.has_animation(HOP_BACK) else 1.0
	# The clip crouches first; the spring is a little way in.
	_move(HOP_BACK, 0.6, 1.9, clip_len * 0.12)


## A lunge with its jaws: the bite comes `arrive` seconds from now.
func bite(arrive: float = 0.4) -> void:
	_strike(BITE, arrive)
	_move_timer = 0.9
	_lunge_timer = 0.0
	_swipe_timer = 0.0


## Down on its belly, it throws itself forward: the crawl sped up, the jaws wide.
func ground_lunge() -> void:
	_move(DRAG, 0.7, 2.6)


## Dead: it falls onto its back, and stays there.
func fall() -> void:
	if _dead or _anim == null:
		return
	_dead = true
	_leap_timer = 0.0
	_melee_timer = 0.0
	_hold_left = 0.0
	if claw != null:
		claw.cancel()
	_swipe_timer = 0.0
	_lunge_timer = 0.0
	if _anim.has_animation(DEATH):
		_anim.play(DEATH, 0.12)
		_anim.speed_scale = 1.3


func is_lunging() -> bool:
	return _lunge_timer > 0.0


## Rearing up to throw a claw wave, or throwing it.
func is_clawing() -> bool:
	return claw != null and claw.active()


func is_swiping() -> bool:
	return _swipe_timer > 0.0


## A hand-to-hand move: `clip` from `from` at `rate`, for `length` seconds, and
## if `hold_for` is more than nothing, held still at `hold_at` (clip time) that
## long before the blow comes on.
func melee(clip: StringName, rate: float, from: float, length: float,
		hold_at: float = -1.0, hold_for: float = 0.0, hits: Array = []) -> void:
	if _anim == null or _dead or not _anim.has_animation(clip):
		return
	_swipe_timer = 0.0
	_lunge_timer = 0.0
	_leap_timer = 0.0
	_move_timer = 0.0
	if claw != null:
		claw.cancel()
	_melee_timer = length
	_melee_rate = rate
	_melee_hits = hits
	_hold_at = hold_at
	_hold_left = hold_for if hold_at >= 0.0 else 0.0
	_anim.play(clip, 0.1)
	_anim.seek(from, true)
	_anim.speed_scale = rate
	var body := get_parent() as Node3D
	if body != null and ResourceLoader.exists(GROWL) and (clip == SLAM or clip == COMBO3):
		Sfx.play(body, GROWL, null, body.global_position + Vector3.UP, 1.3, -9.0)


func is_striking() -> bool:
	return _melee_timer > 0.0


## A melee blow coming through now: its claws trail.
func _slashing() -> bool:
	if _melee_timer <= 0.0 or _hold_left > 0.0 and _anim.current_animation_position >= _hold_at:
		return false
	var now := _anim.current_animation_position
	for h: float in _melee_hits:
		if now > h - 0.2 and now < h + 0.12:
			return true
	return false


## Holding its windup still, the blow not yet come.
func is_holding() -> bool:
	return _melee_timer > 0.0 and _hold_left > 0.0 and _anim.current_animation_position >= _hold_at


## A blow has landed (its or on it): a beat of stillness.
func hitstop(seconds: float) -> void:
	_hitstop = maxf(_hitstop, seconds)


## The spine from the hips up, and the share of a flinch each joint takes.
const BENDS := ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head"]
const BEND_SHARES := [0.2, 0.42, 0.42, 0.3, 0.26, 0.2]
## Hit reactions, if the clips are there (Mixamo's, retargeted in Blender):
## knocked back from the front, and thrown over to its left (by a blow from its
## right) and to its right. Without them the start of the stagger stands in.
const HIT_FRONT := &"WF_Hit_F"
const HIT_LEFT := &"WF_Hit_L"
const HIT_RIGHT := &"WF_Hit_R"
## Bent by blows: see [HitReact].
var react: HitReact


## A blow going `along` has landed: the body thrown over with it.
func flinch(along: Vector3, strength: float, away: Vector3 = Vector3.ZERO) -> void:
	if react != null and not _dead:
		react.strike(along, strength, away)


## What it was doing broken off by a blow going `along`: the jolt of a hit taken,
## for `length` seconds — the clip for the side it came from, if there is one.
func interrupt(along: Vector3, length: float) -> void:
	if _anim == null or _dead:
		return
	var body := get_parent() as Node3D
	var clip := StringName()
	if body != null:
		# Which side it is thrown to, in its own terms: a cut going to its left
		# came from its right.
		var local := body.global_basis.inverse() * along
		if absf(local.x) > absf(local.z) * 0.6:
			clip = HIT_LEFT if local.x < 0.0 else HIT_RIGHT
		else:
			clip = HIT_FRONT
	if clip != StringName() and _anim.has_animation(clip):
		var clip_len := _anim.get_animation(clip).length
		_move(clip, length, clip_len / maxf(length * 1.6, 0.1))
	else:
		_move(STAGGER, length, 1.35)
#endregion


#region Over the clips
## The jaws, the tail, and the glint on the claws, laid over whatever is playing.
func _overlay(delta: float) -> void:
	var gape := 0.0
	var glint_side := 0.0
	var glint := 0.0
	if _swipe_timer > 0.0:
		var a := 1.0 - _swipe_timer / maxf(swipe_duration, 0.001)
		gape = 0.45 * sin(a * PI)
		if a < swipe_windup:
			glint = a / swipe_windup
			glint_side = -1.0 if _swipe_left else 1.0
	elif _lunge_timer > 0.0:
		var a := 1.0 - _lunge_timer / maxf(lunge_duration, 0.001)
		gape = 0.6 * sin(minf(a * 1.3, 1.0) * PI)
		if a < lunge_windup:
			glint = a / lunge_windup
			glint_side = 2.0
	elif _melee_timer > 0.0 and not _melee_hits.is_empty():
		# A hand-to-hand blow coming: the claws flare over the last half second
		# before it lands (held, they stay lit), and the jaws open with it — so
		# every blow is seen coming, not only the big ones.
		var now := _anim.current_animation_position
		for h: float in _melee_hits:
			var ahead := (h - now) / maxf(_melee_rate, 0.01)
			if is_holding():
				ahead = 0.1
			if ahead > -0.08 and ahead < 0.55:
				glint = maxf(glint, 1.0 - maxf(ahead, 0.0) / 0.55)
		glint_side = 2.0
		gape = 0.5 * glint
	elif _move_timer > 0.0 and (_anim.current_animation == String(BITE) or _anim.current_animation == String(DRAG)):
		gape = 0.65 * sin(clampf(1.0 - _move_timer / 0.8, 0.0, 1.0) * PI)
	elif not _dead:
		gape = 0.06 + 0.04 * sin(_clock * 2.3)
	_tell(delta)
	_look(delta)
	if _jaw >= 0 and not has_lost("head"):
		var rest := _skeleton.get_bone_pose_rotation(_jaw)
		_skeleton.set_bone_pose_rotation(_jaw, rest * Quaternion(Vector3.RIGHT, gape))
	# The tail swings behind it, each link lagging the one before.
	var sway := sin(_clock * (7.0 if _stance > 0.5 else 2.2)) * (0.35 if _stance > 0.5 else 0.2)
	for i in _tail.size():
		var want := sway * (0.5 + 0.5 * i)
		_tail_swing[i] = lerpf(_tail_swing[i], want, 1.0 - exp(-(8.0 - i) * delta))
		var bone := _tail[i]
		var rot := _skeleton.get_bone_pose_rotation(bone)
		_skeleton.set_bone_pose_rotation(bone, rot * Quaternion(Vector3.FORWARD, _tail_swing[i]))
	_glint(glint, glint_side)


## Before a pounce: down low on its haunches, trembling, eyes flaring.
func _tell(_delta: float) -> void:
	var gather := 0.0
	if _lunge_timer > 0.0:
		var a := 1.0 - _lunge_timer / maxf(lunge_duration, 0.001)
		if a < lunge_windup:
			# Down fast, held, and up into the spring at the very end.
			gather = smoothstep(0.0, 0.35, a / lunge_windup) * (1.0 - smoothstep(0.85, 1.0, a / lunge_windup))
	if _eye_mat != null:
		_eye_mat.emission_energy_multiplier = _eye_base * (1.0 + 3.0 * gather)
	if gather <= 0.001 or _root_bone < 0:
		return
	var shiver := Vector3(sin(_clock * 71.0), 0.0, cos(_clock * 53.0)) * 0.012 * gather
	var down := _skeleton.global_transform.basis.inverse() * (Vector3.DOWN * crouch * gather + shiver)
	_skeleton.set_bone_pose_position(_root_bone, _skeleton.get_bone_pose_position(_root_bone) + down)


## Standing on its beat it looks about: the head turned slowly one way and the
## other, now and then down to the ground as if at a scent.
func _look(delta: float) -> void:
	if look_about <= 0.01 or _dead or _neck < 0 or _head < 0 or has_lost("head"):
		return
	_look_phase += delta
	var yaw := sin(_look_phase * 0.55) * 0.75 + sin(_look_phase * 1.3) * 0.15
	var sniff := maxf(0.0, sin(_look_phase * 0.23 + 1.0) - 0.6) * 1.6
	var w := look_about
	for bone in [_neck, _head]:
		var rot := _skeleton.get_bone_pose_rotation(bone)
		_skeleton.set_bone_pose_rotation(bone, rot * Quaternion(Vector3.UP, yaw * 0.5 * w)
				* Quaternion(Vector3.RIGHT, sniff * 0.35 * w))


## The tell: a red glint gathering on the claws about to come through.
func _glint(amount: float, side: float) -> void:
	for key: String in ["l", "r"]:
		if not _claw_tips.has(key):
			continue
		var g := _glints.get(key) as MeshInstance3D
		if g == null:
			g = MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2.ONE
			g.mesh = quad
			var glow := StandardMaterial3D.new()
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			glow.no_depth_test = false
			glow.albedo_texture = SpellBolt._disc_texture(false)
			glow.albedo_color = Color(1.0, 0.25, 0.1, 0.0)
			g.material_override = glow
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.top_level = true
			(_claw_tips[key] as Node3D).add_child(g)
			_glints[key] = g
		var mine: bool = side > 1.5 or (key == "l") == (side < 0.0)
		var k := clampf(amount, 0.0, 1.0) if mine and side != 0.0 else 0.0
		g.global_position = (_claw_tips[key] as Node3D).global_position
		(g.material_override as StandardMaterial3D).albedo_color.a = 0.9 * k * k
		g.scale = Vector3.ONE * lerpf(0.15, 0.55, k)
		g.visible = k > 0.01
#endregion


#region Blows
## What its blows are made of this frame, for a [WeaponSweep]: each arm it still
## has from the elbow to the paw and the paw out to its claws, and in a pounce
## its head and jaws.
func claw_parts(pounce: bool, jaws_only: bool = false) -> Array:
	var out := []
	if _skeleton == null:
		return out
	var frame := _skeleton.global_transform
	for side in ["l", "r"]:
		if jaws_only or has_lost("left arm" if side == "l" else "right arm") or not _claw_tips.has(side):
			continue
		var elbow := frame * _skeleton.get_bone_global_pose(_skeleton.find_bone("lowerarm_" + side)).origin
		var wrist := (_wrists[side] as Node3D).global_position
		var tip := (_claw_tips[side] as Node3D).global_position
		out.append([elbow, wrist, 0.1])
		out.append([wrist, tip, 0.12])
	if (pounce or jaws_only) and not has_lost("head"):
		var head := frame * _skeleton.get_bone_global_pose(_skeleton.find_bone("head")).origin
		var jaw := frame * (_skeleton.get_bone_global_pose(_jaw) * Vector3(0.0, 0.26, 0.0)) if _jaw >= 0 else head
		out.append([head, jaw, 0.16])
		if jaws_only:
			# A bite snaps down at a man a head shorter than it (at its size the
			# jaws pass over his shoulders otherwise): the reach of the lunge
			# runs from the jaws down to his chest.
			out.append([jaw, jaw + Vector3.DOWN * 0.45 * absf(global_transform.basis.get_scale().y) / 1.1, 0.2])
	return out
#endregion


#region Limbs
## Every attachment of a limb: those off its bone and every bone below it.
func _limb(part: String) -> Array[BoneAttachment3D]:
	var out: Array[BoneAttachment3D] = []
	if _skeleton == null or not SEVERABLE.has(part):
		return out
	var top := _skeleton.find_bone(SEVERABLE[part])
	for bone_name: String in _parts:
		var b := _skeleton.find_bone(bone_name)
		var walk := b
		while walk >= 0 and walk != top:
			walk = _skeleton.get_bone_parent(walk)
		if walk == top:
			for at in _parts[bone_name]:
				out.append(at)
	return out


## Takes a limb off if the blade passed within `tolerance` of the creature.
##
## Which limb goes is picked at random from what is left rather than by what the
## edge was nearest: a fight where the same cut always lands the same way stops
## being interesting after the second one.
func sever_along_edge(from: Vector3, to: Vector3, tolerance: float) -> String:
	if not _blade_reaches(from, to, tolerance):
		return ""
	var remaining: Array[String] = []
	for part: String in SEVERABLE:
		if not _lost.has(part):
			remaining.append(part)
	if remaining.is_empty():
		return ""
	return detach(remaining[_rng.randi() % remaining.size()])


## True when the blade passed close enough to any part still on it.
func _blade_reaches(from: Vector3, to: Vector3, tolerance: float) -> bool:
	for bone_name: String in _parts:
		for at: BoneAttachment3D in _parts[bone_name]:
			if not at.visible:
				continue
			for m in at.find_children("*", "MeshInstance3D", true, false):
				var mesh := m as MeshInstance3D
				var centre := mesh.global_transform * mesh.get_aabb().get_center()
				if Geometry3D.get_closest_point_to_segment(centre, from, to).distance_to(centre) <= tolerance:
					return true
	return false


## Takes a named part off, wherever it is told to. Deciding which is the host's
## job, doing it everyone's (see [Wolf]).
func detach(part: String) -> String:
	if part == "" or _lost.has(part) or not SEVERABLE.has(part):
		return ""
	_lost[part] = true
	var limb := _limb(part)
	if limb.is_empty():
		severed.emit(part)
		return part
	var top := _skeleton.find_bone(SEVERABLE[part])
	var where := _skeleton.global_transform * _skeleton.get_bone_global_pose(top)
	where = Transform3D(where.basis.orthonormalized(), where.origin)
	var world := Blood.world_of(self)
	if world == null:
		world = get_parent()
	var piece := SeveredLimb.new()
	piece.name = "SeveredLimb"
	world.add_child(piece)
	piece.global_transform = where
	for at in limb:
		for m in at.get_children():
			var mesh := m as MeshInstance3D
			if mesh == null:
				continue
			var copy := mesh.duplicate() as MeshInstance3D
			piece.add_child(copy)
			copy.global_transform = mesh.global_transform
		at.visible = false
	var away := where.origin - global_position
	away.y = 0.0
	piece.launch(away)
	last_cut_point = where.origin
	severed.emit(part)
	return part


func lost_parts() -> int:
	return _lost.size()


## Every part that has come off, by name.
func lost_list() -> Array:
	return _lost.keys()


## Takes a part off without the show: no falling limb, no signal. For a peer that
## joined after the cut and only needs the wolf to *look* like it did.
func hide_part(part: String) -> void:
	if part == "" or _lost.has(part) or not SEVERABLE.has(part):
		return
	_lost[part] = true
	for at in _limb(part):
		at.visible = false


func has_lost(part: String) -> bool:
	return _lost.has(part)


## A leg gone: it is down, dragging itself on its belly.
func is_crippled() -> bool:
	return _lost.has("left leg") or _lost.has("right leg")


func is_moving_itself() -> bool:
	return _move_timer > 0.0


## Both legs gone.
func is_legless() -> bool:
	return _lost.has("left leg") and _lost.has("right leg")


## True once both arms are gone: nothing left to fight with.
func is_disarmed() -> bool:
	return _lost.has("left arm") and _lost.has("right arm")
#endregion
