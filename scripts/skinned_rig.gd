class_name SkinnedRig
extends CharacterRig

## Tariel as a real skinned character: one Skeleton3D, and the Mixamo sword and
## shield library played on it through an AnimationPlayer.
##
## It stands in for [CharacterRig] everywhere the controller talks to a rig —
## same calls, same answers — so `player.gd` does not know which of the two it
## was handed. The procedural rig is untouched and still drives Avtandil;
## putting Tariel back on it is one line in `tariel.tres`.
##
## The model and every clip come from `assets/tariel_rigged/tariel_rigged.glb`,
## exported from `~/Desktop/vepxis-art/tariel/tariel.blend` (see NOTES.md
## there): the old joint hierarchy turned into a 36-bone skeleton with UE
## mannequin names, every armour plate bound rigidly to one bone so nothing
## stretches, and the Mixamo clips retargeted onto it in Blender.
##
## What the library does not cover — climbing, the slide, sheathing — falls back
## to the nearest pose it does have. Those are marked below.

## Ground speed each in-place cycle was authored at, measured in Blender off the
## planted foot (m/s). The play rate is the body's speed over this, so the feet
## keep up with the ground instead of skating.
const GROUND_SPEED := {
	&"SS_Walk": 1.42, &"SS_Run": 3.2,
	&"SS_Backward_Walk": 1.12, &"SS_Backward_Run": 3.22,
	&"SS_Left_Strafe_Walk": 1.08, &"SS_Right_Strafe_Walk": 1.21,
	&"SS_Left_Run_Strafe": 2.56, &"SS_Right_Run_Strafe": 2.45,
}
const LOOPING: Array[StringName] = [
	&"SS_Idle", &"SS_Walk", &"SS_Run", &"SS_Backward_Walk", &"SS_Backward_Run",
	&"SS_Left_Strafe_Walk", &"SS_Right_Strafe_Walk", &"SS_Left_Run_Strafe",
	&"SS_Right_Run_Strafe", &"SS_Block_Idle", &"SS_Crouch_Block_Idle",
	&"SS_Left_Crouch_Idle_Loop", &"SS_Sword_Play_Idle", &"SS_Look_Around_Idle",
]
## The cuts a flurry cycles through, in order.
const FLURRY: Array[StringName] = [&"SS_High_Attack", &"SS_Cross_Slash", &"SS_Downward_Slash"]
## Where each swing's blade is actually travelling, as a fraction of the clip —
## measured in Blender as the span the tip moves faster than 55% of its peak.
const CUT_WINDOW := {
	&"SS_High_Attack": Vector2(0.41, 0.487), &"SS_Cross_Slash": Vector2(0.44, 0.52),
	&"SS_Downward_Slash": Vector2(0.378, 0.467), &"SS_Low_Attack": Vector2(0.404, 0.462),
	&"SS_Power_Slash": Vector2(0.548, 0.575), &"SS_Jump_Attack": Vector2(0.471, 0.543),
	&"SS_Crouch_Slash": Vector2(0.366, 0.488),
}
const CLIP_ROLL := &"Roll_Quick_To_Run"
## How far into the roll clip the body is back on its feet (pelvis lowest at 0.64).
const ROLL_SHARE := 0.8
const CLIP_AIR := &"SS_Running_Jump"
const CLIP_DOWN := &"SS_Falling_Back_Death"
## The landing half of the jump attack: the blade goes into the ground at 56–76%
## of it (tip down to 0.14 m, measured in Blender) and he stands back up after.
const CLIP_PLUNGE := &"SS_Jump_Attack"
const PLUNGE_FROM := 0.5

## Blade, measured from the fist along the blade (m).
const BLADE_BASE := 0.18
const BLADE_TIP := 1.03

@export_group("Skinned")
## Under this speed the body stands; over `run_threshold` it runs.
@export var idle_threshold: float = 0.25
@export var run_threshold: float = 2.4
## Clamp on how far a cycle is sped up or slowed down to match the ground. Past
## the top of it the feet slide a little rather than blur.
@export var min_play_rate: float = 0.6
@export var max_play_rate: float = 2.1
@export var loco_blend: float = 0.2
@export var action_blend: float = 0.1
## Widens the measured cutting window a little each side, as a fraction of the clip.
@export var cut_margin: float = 0.03
## Swings play at this rate. Mixamo's are unhurried; the game is not.
@export var swing_rate: float = 1.35

enum Role { NONE, SWING, ROLL, HIT, DOWN, GET_UP, PLUNGE, CLIMB, FREE }

var _anim: AnimationPlayer
var _skel: Skeleton3D
var _body: Node3D
var _sword_mesh: MeshInstance3D
var _role: Role = Role.NONE
var _act_clip: StringName = &""
var _action_left: float = 0.0
var _action_len: float = 0.0
var _action_rate: float = 1.0
var _base_clip: StringName = &""
var _flurry_slot: int = -1
var _airborne_now: bool = false
var _blocking_now: bool = false
var _plunge_left: float = 0.0
var _swing_commit: float = 0.0


func _ready() -> void:
	_attack_rng.randomize()
	_anim = find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	_skel = find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	if _anim == null or _skel == null:
		push_error("SkinnedRig: the model has no AnimationPlayer or Skeleton3D.")
		return
	_body = get_parent() as Node3D
	for n in LOOPING:
		if _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	# The clips carry their travel on the `root` bone. The controller moves the
	# body itself, so that travel is taken out of the pose rather than played.
	var holder := _anim.get_node(_anim.root_node)
	_anim.root_motion_track = NodePath(String(holder.get_path_to(_skel)) + ":root")
	_setup_blade()
	_sword_mesh = find_child("tariel_sword", true, false) as MeshInstance3D
	_set_base(&"SS_Idle", 0.0, 1.0)


## Markers for the blade's base and tip on the weapon socket, so the swing trail
## and `get_cutting_edge()` have a segment to read. The blade's direction in the
## socket is read off the rest pose (it points forward, +Z, in the T-pose) rather
## than assumed, so it does not matter which axis the exporter left the bone on.
func _setup_blade() -> void:
	var bone := _skel.find_bone("weapon_r")
	if bone < 0:
		return
	var mount := BoneAttachment3D.new()
	mount.name = "WeaponMount"
	_skel.add_child(mount)
	mount.bone_name = "weapon_r"
	var along := (_skel.get_bone_global_rest(bone).basis.inverse() * Vector3(0, 0, 1)).normalized()
	_blade_base = Marker3D.new()
	_blade_base.name = "blade_base"
	_blade_base.position = along * BLADE_BASE
	mount.add_child(_blade_base)
	_blade_tip = Marker3D.new()
	_blade_tip.name = "blade_tip"
	_blade_tip.position = along * BLADE_TIP
	mount.add_child(_blade_tip)
	_sword_mount = mount
	_trail = SwordTrail.new()
	_trail.name = "SwordTrail"
	add_child(_trail)
	_trail.setup(_blade_base, _blade_tip)


func animate(delta: float, planar_speed: float, _speed_ratio: float, airborne: bool,
		dashing: bool, vertical_speed: float, blocking: bool = false) -> void:
	if _anim == null:
		return
	_airborne_now = airborne
	_blocking_now = blocking
	_plunge_left = maxf(_plunge_left - delta, 0.0)
	_swing_commit = maxf(_swing_commit - delta, 0.0)

	if _role != Role.NONE:
		_action_left -= delta
		var through := _progress()
		_attack_cutting = _role == Role.SWING and _in_window(through)
		# A swing that has done its work gives the body back as soon as the
		# player moves off; standing still, it plays out its follow-through.
		var released := _role == Role.SWING and _swing_commit <= 0.0 and planar_speed > idle_threshold
		if _role == Role.DOWN:
			pass  # held until get_up() or leave_ground()
		elif _action_left <= 0.0 or released:
			_end_action()
	else:
		_attack_cutting = false
	if _trail != null:
		_trail.emitting = _attack_cutting

	if _role == Role.NONE:
		_pick_base(planar_speed, airborne, dashing, vertical_speed, blocking)


func _pick_base(planar: float, airborne: bool, _dashing: bool, _vy: float, blocking: bool) -> void:
	if airborne:
		_set_base(CLIP_AIR, loco_blend, 0.8)
		return
	if blocking:
		_set_base(&"SS_Block_Idle", 0.12, 1.0)
		return
	if _crouching or _wall_climbing:
		# No crouch-walk or climb in the library: the crouched guard stands in.
		_set_base(&"SS_Crouch_Block_Idle", loco_blend, 1.0)
		return
	if planar < idle_threshold:
		_set_base(&"SS_Idle", loco_blend, 1.0)
		return
	var clip := _direction_clip(planar)
	var rate := clampf(planar / float(GROUND_SPEED.get(clip, 1.4)), min_play_rate, max_play_rate)
	_set_base(clip, loco_blend, rate)


## Which cycle fits the way the body is actually travelling relative to where it
## faces — forwards, backwards, or sideways while locked on to something.
func _direction_clip(planar: float) -> StringName:
	var run := planar > run_threshold
	var body := _body as CharacterBody3D
	if body == null:
		return &"SS_Run" if run else &"SS_Walk"
	var local := body.global_transform.basis.inverse() * body.velocity
	var fwd := -local.z
	var side := local.x
	if absf(side) > absf(fwd) * 1.2:
		if side > 0.0:
			return &"SS_Right_Run_Strafe" if run else &"SS_Right_Strafe_Walk"
		return &"SS_Left_Run_Strafe" if run else &"SS_Left_Strafe_Walk"
	if fwd < 0.0:
		return &"SS_Backward_Run" if run else &"SS_Backward_Walk"
	return &"SS_Run" if run else &"SS_Walk"


func _set_base(clip: StringName, blend: float, rate: float) -> void:
	if not _anim.has_animation(clip):
		return
	if clip != _base_clip or _anim.current_animation != clip:
		_base_clip = clip
		_anim.play(clip, blend)
	_anim.speed_scale = rate


func _play_action(clip: StringName, role: Role, rate: float = 1.0, blend: float = -1.0,
		from: float = 0.0, until: float = 1.0) -> bool:
	if not _anim.has_animation(clip):
		return false
	var length := _anim.get_animation(clip).length
	_role = role
	_act_clip = clip
	_action_len = length
	_action_rate = maxf(rate, 0.01)
	_action_left = length * (until - from) / _action_rate
	_base_clip = &""
	_anim.play(clip, action_blend if blend < 0.0 else blend)
	_anim.speed_scale = _action_rate
	if from > 0.0:
		_anim.seek(length * from, true)
	return true


func _end_action() -> void:
	_role = Role.NONE
	_act_clip = &""
	_attack_cutting = false
	_base_clip = &""  # forces the next base pick to crossfade in


func _progress() -> float:
	if _action_len <= 0.0:
		return 1.0
	return clampf(_anim.current_animation_position / _action_len, 0.0, 1.0)


func _in_window(through: float) -> bool:
	var w: Vector2 = CUT_WINDOW.get(_act_clip, Vector2.ZERO)
	return w != Vector2.ZERO and through >= w.x - cut_margin and through <= w.y + cut_margin


#region The rig's interface, as the controller calls it
func attack(style: int = -1) -> void:
	attack_serial += 1
	var clip: StringName
	if style == AttackStyle.OVERHEAD or _airborne_now:
		clip = &"SS_Downward_Slash"
		_attack_style = AttackStyle.OVERHEAD
	else:
		_attack_style = AttackStyle.SIDE
		_flurry_slot = (_flurry_slot + 1) % FLURRY.size()
		clip = FLURRY[_flurry_slot]
	if _play_action(clip, Role.SWING, swing_rate):
		_swing_commit = swing_time()


func swing_time() -> float:
	if _role != Role.SWING or _action_len <= 0.0:
		return attack_duration
	var w: Vector2 = CUT_WINDOW.get(_act_clip, Vector2(0.5, 0.5))
	return minf(_action_len * w.y / _action_rate + swing_recovery, _action_len / _action_rate)


func current_swing() -> StringName:
	return _act_clip if _role == Role.SWING else &""


func plunge(seconds: float) -> void:
	_plunge_left = maxf(seconds, 0.1)
	var length := _anim.get_animation(CLIP_PLUNGE).length if _anim.has_animation(CLIP_PLUNGE) else 1.0
	# The landing of the jump attack — the blade going in and the body coming
	# back up over it — stretched over however long the recovery is.
	_play_action(CLIP_PLUNGE, Role.PLUNGE, length * (1.0 - PLUNGE_FROM) / _plunge_left, 0.06, PLUNGE_FROM, 1.0)


func is_planted() -> bool:
	return _plunge_left > 0.0


func bloody() -> void:
	blade_blood = minf(blade_blood + 0.34, 1.0)
	if _sword_mesh == null:
		return
	var overlay := StandardMaterial3D.new()
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Color(0.35, 0.02, 0.02, blade_blood * 0.7)
	overlay.roughness = 0.35
	_sword_mesh.material_overlay = overlay


func dodge(duration: float) -> void:
	# The roll part of the clip, fitted to the dash so the tumble and the
	# movement finish together; what is left of the clip is the run-out, which
	# the locomotion picks up instead.
	var length := _anim.get_animation(CLIP_ROLL).length if _anim.has_animation(CLIP_ROLL) else 1.0
	_play_action(CLIP_ROLL, Role.ROLL, length * ROLL_SHARE / maxf(duration, 0.05), 0.05, 0.0, ROLL_SHARE)


func dodge_clip(duration: float) -> bool:
	var length := _anim.get_animation(CLIP_ROLL).length if _anim.has_animation(CLIP_ROLL) else 0.0
	if length <= 0.0:
		return false
	return _play_action(CLIP_ROLL, Role.ROLL, length / maxf(duration, 0.05), 0.06)


func hit() -> void:
	flinch()


func flinch() -> void:
	if _role == Role.SWING or _role == Role.DOWN:
		return
	_play_action(&"SS_Blocked_Impact" if _blocking_now else &"SS_Head_Impact", Role.HIT, 1.3, 0.05)


func knock_down() -> void:
	_play_action(CLIP_DOWN, Role.DOWN, 1.4, 0.06)


func get_up(duration: float) -> void:
	# No stand-up clip in the pack: the fall, played back to front.
	if not _anim.has_animation(CLIP_DOWN):
		_end_action()
		return
	var length := _anim.get_animation(CLIP_DOWN).length
	_role = Role.GET_UP
	_act_clip = CLIP_DOWN
	_action_len = length
	_action_rate = length / maxf(duration, 0.05)
	_action_left = maxf(duration, 0.05)
	_anim.play_backwards(CLIP_DOWN, 0.1)
	_anim.speed_scale = _action_rate


func leave_ground() -> void:
	if _role == Role.DOWN or _role == Role.GET_UP:
		_end_action()


func is_down() -> bool:
	return _role == Role.DOWN or _role == Role.GET_UP


func slide(active: bool) -> void:
	# No slide in the library; the crouched guard reads well enough at speed.
	_crouching = active


func wall_climb(active: bool) -> void:
	_wall_climbing = active
	if active and _role != Role.NONE:
		_end_action()


func climb(duration: float) -> void:
	_play_action(&"SS_Jump_From_Idle", Role.CLIMB,
			_anim.get_animation(&"SS_Jump_From_Idle").length / maxf(duration, 0.05), 0.06)


func is_crouched() -> bool:
	return _crouching


func is_wall_climbing() -> bool:
	return _wall_climbing


func weapons_slung() -> float:
	return 0.0  # no sheathing yet — the sword stays in hand


func play_clip(clip: StringName, fade: float = -1.0, speed: float = 1.0) -> bool:
	return _play_action(clip, Role.FREE, speed, fade)


func hold_clip(clip: StringName, through: float) -> bool:
	if not _play_action(clip, Role.FREE, 1.0, 0.0, through):
		return false
	_anim.speed_scale = 0.0
	_action_left = INF
	return true


func current_clip() -> StringName:
	return _act_clip


func clip_weight() -> float:
	return 1.0 if _role != Role.NONE else 0.0


func clip_names() -> PackedStringArray:
	return _anim.get_animation_list() if _anim != null else PackedStringArray()


func has_clips() -> bool:
	return _anim != null
#endregion
