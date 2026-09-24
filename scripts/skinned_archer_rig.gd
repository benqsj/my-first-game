class_name SkinnedArcherRig
extends SkinnedRig

## Avtandil on a real skeleton: Mixamo's longbow pack for the body, climbing
## clips for the wall, and [BowModifier] for the bow itself — the string, the
## limbs bending, the arrow on the string and the aim tilting the chest.
##
## Everything the knight's rig does comes from [SkinnedRig]; this swaps in the
## hunter's clip table and adds what a bow and a wall need. The controller talks
## to it through `aim_bow()` / `loose_bow()` exactly as it did to [ArcherRig].
##
## Source: `~/Desktop/vepxis-art/avtandil/avtandil.blend`; measurements in
## `avtandil_clip_meta.json` next to it.

## The draw clip reaches back to the quiver, nocks and comes up to the aim; the
## string only comes back with the hand over its last part.
## Built in Blender from the back half of the pack's "Draw Arrow" (the nock and
## the draw; the reach to the quiver is dropped), with the bow arm held on the
## target throughout — the bow goes up first and the string comes back to it,
## which is the order an archer does it in.
const DRAW_CLIP := &"AV_Nock_Draw"
const DRAW_STRING_FROM := 0.0
const DRAW_FROM := 0.0
const AIM_IDLE := &"AV_Aim_Idle_01"
const LOOSE_CLIP := &"AV_Shooting_Arrow"
## Where in the shooting clip the string goes (0.23, measured) and the snap after it.
const LOOSE_FROM := 0.215
const LOOSE_TO := 0.3
## How far one cycle of each climbing clip moves the body (m/s at 1x), estimated
## in Blender from how far the hands and feet travel against the pelvis.
const CLIMB_UP_SPEED := 0.4
const SHIMMY_SPEED := 0.36

var _bow_mod: BowModifier
var _draw_target: float = 0.0
var _pitch: float = 0.0
var _aim_phase: float = 0.0   # 0 idle, 0..1 through the draw clip, 1 holding
var _drawing_clip: bool = false
var _loose_left: float = 0.0
var _draw_time: float = 0.85


func _configure() -> void:
	clips = {
		&"idle": &"AV_Idle_01", &"walk": &"AV_Walk_Forward", &"run": &"AV_Run_Forward",
		&"sprint": &"AV_Sprint_Upright",
		&"walk_back": &"AV_Walk_Back", &"run_back": &"AV_Run_Back",
		&"walk_left": &"AV_Walk_Left", &"walk_right": &"AV_Walk_Right",
		&"run_left": &"AV_Run_Left", &"run_right": &"AV_Run_Right",
		&"aim_walk": &"AV_Aim_Walk_Forward", &"aim_walk_back": &"AV_Aim_Walk_Back",
		&"aim_walk_left": &"AV_Aim_Walk_Left", &"aim_walk_right": &"AV_Aim_Walk_Right",
		&"crouch": &"AV_Crouch_Idle_01", &"crouch_walk": &"AV_Crouch_Walk_Forward",
		&"crouch_walk_back": &"AV_Crouch_Walk_Back", &"crouch_walk_left": &"AV_Crouch_Walk_Left",
		&"crouch_walk_right": &"AV_Crouch_Walk_Right",
		&"block_idle": &"AV_Block", &"block_walk": &"AV_Walk_Forward",
		&"block_walk_back": &"AV_Walk_Back", &"block_walk_left": &"AV_Walk_Left",
		&"block_walk_right": &"AV_Walk_Right",
		&"air": &"AV_Jump_Air", &"roll": &"AV_Dive_Forward", &"dodge": &"AV_Dodge_Forward",
		&"down": &"AV_Death_Backward_01", &"hit": &"AV_React_Small_From_Front",
		&"hit_blocked": &"AV_React_Small_From_Front",
		&"mantle": &"AV_Braced_Hang_To_Crouch", &"plunge": &"AV_Melee_Kick",
		&"overhead": &"AV_Melee_Kick",
		&"climb_up": &"AV_Climbing_Up_Wall", &"climb_down": &"AV_Climbing_Down_Wall",
		&"shimmy_left": &"AV_Shimmy_Left", &"shimmy_right": &"AV_Shimmy_Right",
		&"hang": &"AV_Hanging_Idle",
	}
	ground_speed = {
		&"AV_Walk_Forward": 1.16, &"AV_Run_Forward": 3.25, &"AV_Sprint_Upright": 4.09,
		&"AV_Walk_Back": 0.94, &"AV_Run_Back": 2.65, &"AV_Walk_Left": 1.51,
		&"AV_Walk_Right": 1.52, &"AV_Run_Left": 2.49, &"AV_Run_Right": 2.96,
		&"AV_Aim_Walk_Forward": 1.16, &"AV_Aim_Walk_Back": 0.94,
		&"AV_Aim_Walk_Left": 1.51, &"AV_Aim_Walk_Right": 1.42,
		&"AV_Crouch_Walk_Forward": 1.54, &"AV_Crouch_Walk_Back": 1.19,
		&"AV_Crouch_Walk_Left": 1.34, &"AV_Crouch_Walk_Right": 1.39,
	}
	looping = [
		&"AV_Idle_01", &"AV_Walk_Forward", &"AV_Run_Forward", &"AV_Sprint_Upright",
		&"AV_Walk_Back", &"AV_Run_Back", &"AV_Walk_Left", &"AV_Walk_Right", &"AV_Run_Left",
		&"AV_Run_Right", &"AV_Aim_Idle_01", &"AV_Aim_Walk_Forward", &"AV_Aim_Walk_Back",
		&"AV_Aim_Walk_Left", &"AV_Aim_Walk_Right", &"AV_Crouch_Idle_01",
		&"AV_Crouch_Walk_Forward", &"AV_Crouch_Walk_Back", &"AV_Crouch_Walk_Left",
		&"AV_Crouch_Walk_Right", &"AV_Climbing_Up_Wall",
		&"AV_Climbing_Down_Wall", &"AV_Shimmy_Left", &"AV_Shimmy_Right", &"AV_Hanging_Idle",
	]
	flurry = [&"AV_Melee_Punch", &"AV_Melee_Kick"]
	cut_window = {}
	roll_share = 0.75
	# He runs at 5.9 m/s on the pack's sprint (authored at 4.1), straightened
	# up 28 degrees in Blender — as shipped it runs bent nearly double.
	max_play_rate = 2.0
	idle_threshold = 0.25


func _ready() -> void:
	super()
	if _skel == null:
		return
	_bow_mod = BowModifier.new()
	_bow_mod.name = "Bow"
	_skel.add_child(_bow_mod)
	# Named as the procedural bow's nodes were, so anything that looks them up
	# by name — the archer test does — still finds them.
	_bow_mod.string_u = _make_string("bow_string_u")
	_bow_mod.string_l = _make_string("bow_string_l")
	_bow_mod.arrow = _make_arrow()
	# And the joints the procedural rig had, by their old names, for anything
	# that still asks for them (the archer test measures the drawing arm with
	# them). The old `*_l` nodes are anatomically right: see [CharacterRig].
	for pair in [["bow", &"bow_l"], ["draw", &"draw_r"], ["hand_r", &"hand_l"],
			["shoulder_l", &"upperarm_r"], ["upperarm_l_end", &"lowerarm_r"], ["head", &"head"]]:
		var at := BoneAttachment3D.new()
		at.name = pair[0]
		_skel.add_child(at)
		at.bone_name = pair[1]


func _make_string(tag: String) -> Node3D:
	var half := Node3D.new()
	half.name = tag
	half.top_level = true
	add_child(half)
	var cord := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.008, 1.0, 0.008)
	cord.mesh = box
	cord.position = Vector3(0.0, -0.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("cfc3a8")
	cord.material_override = mat
	half.add_child(cord)
	return half


func _make_arrow() -> Node3D:
	var arrow := Node3D.new()
	arrow.name = "bow_arrow"
	arrow.top_level = true
	arrow.visible = false
	add_child(arrow)
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.006
	cyl.bottom_radius = 0.006
	cyl.height = 0.82
	shaft.mesh = cyl
	# Along -Z (the way the arrow points), starting a touch behind the fingers.
	shaft.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	shaft.position = Vector3(0.0, 0.0, -0.36)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("8a6a44")
	shaft.material_override = wood
	arrow.add_child(shaft)
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.016
	cone.height = 0.06
	head.mesh = cone
	head.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	head.position = Vector3(0.0, 0.0, -0.8)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("a8b0b8")
	steel.metallic = 0.7
	head.material_override = steel
	arrow.add_child(head)
	return arrow


#region The bow, as the controller calls it
func aim_bow(draw: float, pitch: float) -> void:
	_draw_target = clampf(draw, 0.0, 1.0)
	_pitch = clampf(pitch, -1.1, 1.1)


func loose_bow() -> void:
	if _aim_phase <= 0.05 and _draw_target <= 0.05:
		return
	_loose_left = 0.35
	_drawing_clip = false
	_aim_phase = 0.0
	if _anim.has_animation(LOOSE_CLIP):
		_play_action(LOOSE_CLIP, Role.FREE, 1.3, 0.05, LOOSE_FROM, LOOSE_TO)


func is_aiming() -> bool:
	return _aim_phase > 0.3


func attack(style: int = -1) -> void:
	# A bow has no cut; a melee press is a kick or a punch, no blade to track.
	attack_serial += 1
	_flurry_slot = (_flurry_slot + 1) % flurry.size()
	_play_action(flurry[_flurry_slot], Role.FREE, 1.4, 0.06)
#endregion


func animate(delta: float, planar_speed: float, speed_ratio: float, airborne: bool,
		dashing: bool, vertical_speed: float, blocking: bool = false) -> void:
	if _anim == null:
		return
	_loose_left = maxf(_loose_left - delta, 0.0)
	var drawing := _draw_target > 0.001 and not _wall_climbing
	var body_p := _body as Player
	if body_p != null and body_p.profile != null:
		_draw_time = maxf(body_p.profile.draw_time, 0.2)
	var moving := planar_speed > idle_threshold
	if _drawing_clip and moving:
		# The draw clip is a standing one. Moving, it would slide him across the
		# ground; the aiming walk takes over and brings the bow up on the way.
		_drawing_clip = false
		_base_clip = &""
	if drawing and _role == Role.NONE and not _drawing_clip and moving:
		_aim_phase = minf(maxf(_aim_phase, 0.0) + delta / _draw_time, 1.0)
	if drawing and _role == Role.NONE:
		if _aim_phase <= 0.0 and not _drawing_clip and not moving and _anim.has_animation(DRAW_CLIP):
			# Up out of whatever he was doing: the draw clip fitted to the draw
			# time the profile gives, so the string is back when the power is.
			var draw_time := 0.85
			var body := _body as Player
			if body != null and body.profile != null:
				draw_time = maxf(body.profile.draw_time, 0.2)
			_drawing_clip = true
			_base_clip = DRAW_CLIP
			var clip_len := _anim.get_animation(DRAW_CLIP).length
			_anim.play(DRAW_CLIP, 0.08)
			_anim.seek(clip_len * DRAW_FROM, true)
			# The nock-and-draw at no slower than it was performed; faster when the
			# profile's draw time asks for it. The power keeps building after.
			_anim.speed_scale = maxf(clip_len * (1.0 - DRAW_FROM) / draw_time, 1.0)
		if _drawing_clip:
			var draw_len := _anim.get_animation(DRAW_CLIP).length
			var through := _anim.current_animation_position / draw_len if _anim.current_animation == DRAW_CLIP else 1.0
			_aim_phase = clampf(through, 0.0, 1.0)
			if through >= 0.98 or _anim.current_animation != DRAW_CLIP:
				_drawing_clip = false
				_aim_phase = 1.0
	elif not drawing and _loose_left <= 0.0:
		_drawing_clip = false
		_aim_phase = 0.0
	if _bow_mod != null:
		var string := 0.0
		if drawing:
			string = clampf((_aim_phase - DRAW_STRING_FROM) / (1.0 - DRAW_STRING_FROM), 0.0, 1.0)
			string *= maxf(_draw_target, 0.6)
		_bow_mod.draw = string
		_bow_mod.pitch = _pitch * (1.0 if _aim_phase > 0.5 else _aim_phase * 2.0)
	if _drawing_clip:
		# The draw clip owns the body until it is through; the base cycle must
		# not be picked over it.
		_airborne_now = airborne
		_blocking_now = blocking
		if _trail != null:
			_trail.emitting = false
		return
	super(delta, planar_speed, speed_ratio, airborne, dashing, vertical_speed, blocking)


func _pick_base(planar: float, airborne: bool, dashing: bool, vy: float, blocking: bool) -> void:
	if _wall_climbing:
		_pick_climb()
		return
	if _aim_phase > 0.0 and _draw_target > 0.001 and not airborne:
		if planar < idle_threshold:
			_set_base(AIM_IDLE, 0.12, 1.0)
		else:
			var clip := _dir4(&"aim_walk", &"aim_walk_back", &"aim_walk_left", &"aim_walk_right")
			_set_base(clip, 0.15, _rate(clip, planar))
		return
	super(planar, airborne, dashing, vy, blocking)


func _direction_clip(planar: float) -> StringName:
	var clip := super(planar)
	# Straight ahead there are three gears: his walk, the pack's run, and its
	# sprint for the pace he actually covers ground at. It is played no more
	# than half as fast again as it was authored: much quicker than that and
	# his legs blur.
	if clip == clips[&"run"] and planar > 4.6:
		return clips[&"sprint"]
	return clip


func _pick_climb() -> void:
	var drive := _climb_drive
	if drive.length() < 0.15 or _climb_speed < 0.05:
		_set_base(clips[&"hang"], 0.2, 1.0)
		return
	if absf(drive.y) >= absf(drive.x):
		var up := drive.y > 0.0
		_set_base(clips[&"climb_up"] if up else clips[&"climb_down"], 0.2,
				clampf(_climb_speed / CLIMB_UP_SPEED, 0.4, 3.0))
	else:
		_set_base(clips[&"shimmy_right"] if drive.x > 0.0 else clips[&"shimmy_left"], 0.2,
				clampf(_climb_speed / SHIMMY_SPEED, 0.4, 3.0))


func dodge_clip(duration: float) -> bool:
	var clip: StringName = clips[&"dodge"]
	if not _anim.has_animation(clip):
		return false
	return _play_action(clip, Role.ROLL, _anim.get_animation(clip).length / maxf(duration, 0.05), 0.06)
