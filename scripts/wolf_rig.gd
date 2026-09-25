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
const LOOPS: Array[StringName] = [&"WF_Idle", &"WF_Walk", &"WF_Crawl_Run", &"WF_Drag", &"WF_Run",
		&"WF_Crawl_Walk"]

#region Exported tuning
@export_group("Attack")
## How long a swipe takes, and the share of it spent winding up: the claws come
## through at the end of the windup.
@export var swipe_duration: float = 0.85
@export var swipe_windup: float = 0.55
## The pounce: how long, and the share of it spent gathering.
@export var lunge_duration: float = 1.0
@export var lunge_windup: float = 0.5

@export_group("Pace")
## Metres a second each cycle carries it at rate 1: what the clips are sped up
## or slowed against so the feet do not skate.
@export var walk_pace: float = 1.25
@export var run_pace: float = 4.2
@export var drag_pace: float = 0.5
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
var _trail_l: SwordTrail
var _trail_r: SwordTrail
var _glints: Dictionary = {}
var _clock: float = 0.0


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
	for n in ["tail_01", "tail_02", "tail_03", "tail_04"]:
		var b := _skeleton.find_bone(n)
		if b >= 0:
			_tail.append(b)
	_tail_swing.resize(_tail.size())
	for clip in [SWIPE_L, SWIPE_R, POUNCE, &"WF_Punch"]:
		_strike_at[clip] = _fastest(clip)
	_mark_claws()
	_anim.play(IDLE)
	_anim.advance(0.0)


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


func _make_trail(side: String) -> SwordTrail:
	if not _wrists.has(side):
		return null
	var trail := SwordTrail.new()
	trail.tint = Color(0.85, 0.92, 1.0, 0.4)
	trail.sample_count = 12
	trail.fade_time = 0.18
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
	_swipe_timer = maxf(_swipe_timer - delta, 0.0)
	_lunge_timer = maxf(_lunge_timer - delta, 0.0)
	_reel_timer = maxf(_reel_timer - delta, 0.0)
	_stance = stance_target
	if not _dead:
		_choose(planar_speed)
	_anim.advance(delta)
	# The clips are kept on the spot; the body is what moves it.
	if _root_bone >= 0:
		_skeleton.set_bone_pose_position(_root_bone, _skeleton.get_bone_rest(_root_bone).origin)
		if is_legless() and not _dead:
			_rest_on_ground()
	_overlay(delta)
	var swiping := _swipe_timer > 0.0 and _swipe_timer < swipe_duration * (1.0 - swipe_windup)
	if _trail_l != null:
		_trail_l.emitting = (swiping and _swipe_left) or _lunging_through()
	if _trail_r != null:
		_trail_r.emitting = (swiping and not _swipe_left) or _lunging_through()


## With no legs its belly is what it lies on: the body is let down until the
## lowest part left on it touches the ground under it.
func _rest_on_ground() -> void:
	var lowest := INF
	for bone_name: String in _parts:
		for at: BoneAttachment3D in _parts[bone_name]:
			if not at.visible:
				continue
			for m in at.get_children():
				var mesh := m as MeshInstance3D
				if mesh != null:
					lowest = minf(lowest, (mesh.global_transform * mesh.get_aabb()).position.y)
	var body := get_parent() as Node3D
	if is_inf(lowest) or body == null:
		return
	var drop := lowest - body.global_position.y
	var down := _skeleton.global_transform.basis.inverse() * Vector3(0.0, -drop, 0.0)
	_skeleton.set_bone_pose_position(_root_bone, _skeleton.get_bone_rest(_root_bone).origin + down)


func _lunging_through() -> bool:
	return _lunge_timer > 0.0 and _lunge_timer < lunge_duration * (1.0 - lunge_windup)


## The clip for what it is doing now, when no attack or stagger is playing.
func _choose(planar: float) -> void:
	if _swipe_timer > 0.0 or _lunge_timer > 0.0 or _reel_timer > 0.0:
		return
	var clip := IDLE
	var pace := 1.0
	if is_legless():
		clip = DRAG
		pace = clampf(planar / drag_pace, 0.3, 2.0) if planar > 0.1 else 0.3
	elif planar > run_from and _stance > 0.5:
		clip = RUN
		pace = clampf(planar / run_pace, 0.7, 1.6)
	elif planar > 0.25:
		clip = WALK
		pace = clampf(planar / walk_pace, 0.6, 1.8)
	if not _anim.has_animation(clip):
		clip = IDLE
	if _anim.current_animation != String(clip):
		_anim.play(clip, 0.25)
	_anim.speed_scale = pace


## Plays `clip` so that its fastest moment comes `arrive` seconds from now.
func _strike(clip: StringName, arrive: float) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	var peak: float = _strike_at.get(clip, 0.5)
	var rate := 1.0
	var start := peak - arrive * rate
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
	_strike(POUNCE, lunge_duration * lunge_windup)


## Thrown back off a shield, or knocked by a skill: it staggers.
func reel(length: float = Recoil.STAGGER) -> void:
	if _anim == null or _dead:
		return
	_swipe_timer = 0.0
	_lunge_timer = 0.0
	_reel_timer = length
	if _anim.has_animation(STAGGER):
		_anim.play(STAGGER, 0.08)
		_anim.seek(0.0, true)
		_anim.speed_scale = _anim.get_animation(STAGGER).length / maxf(length, 0.2) * 0.8


## Dead: it falls onto its back, and stays there.
func fall() -> void:
	if _dead or _anim == null:
		return
	_dead = true
	_swipe_timer = 0.0
	_lunge_timer = 0.0
	if _anim.has_animation(DEATH):
		_anim.play(DEATH, 0.12)
		_anim.speed_scale = 1.3


func is_lunging() -> bool:
	return _lunge_timer > 0.0


func is_swiping() -> bool:
	return _swipe_timer > 0.0
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
	elif not _dead:
		gape = 0.06 + 0.04 * sin(_clock * 2.3)
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
func claw_parts(pounce: bool) -> Array:
	var out := []
	if _skeleton == null:
		return out
	var frame := _skeleton.global_transform
	for side in ["l", "r"]:
		if has_lost("left arm" if side == "l" else "right arm") or not _claw_tips.has(side):
			continue
		var elbow := frame * _skeleton.get_bone_global_pose(_skeleton.find_bone("lowerarm_" + side)).origin
		var wrist := (_wrists[side] as Node3D).global_position
		var tip := (_claw_tips[side] as Node3D).global_position
		out.append([elbow, wrist, 0.1])
		out.append([wrist, tip, 0.12])
	if pounce and not has_lost("head"):
		var head := frame * _skeleton.get_bone_global_pose(_skeleton.find_bone("head")).origin
		var jaw := frame * (_skeleton.get_bone_global_pose(_jaw) * Vector3(0.0, 0.26, 0.0)) if _jaw >= 0 else head
		out.append([head, jaw, 0.16])
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


## Both legs gone: it can only drag itself.
func is_legless() -> bool:
	return _lost.has("left leg") and _lost.has("right leg")


## True once both arms are gone: nothing left to fight with.
func is_disarmed() -> bool:
	return _lost.has("left arm") and _lost.has("right arm")
#endregion
