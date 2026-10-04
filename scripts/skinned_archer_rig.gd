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
## The Rain of Arrows' shot into the sky, how fast it is played, and where in
## it the string comes back and is let go (frame 91 of 121).
const SKY_CLIP := &"AV_Sky_Shot"
const SKY_RATE := 2.0
const SKY_DRAW_FROM := 0.5
const SKY_RELEASE := 0.75
var _sky_left: float = 0.0
var _sky_len: float = 0.0

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
## The draw, the aim and the release as played now: his own clips, or on the
## mannequin the picked BOW moves ([Moveset]): the draw played from
## `draw_from` to `draw_until` (shares of its clip).
var draw_clip: StringName = DRAW_CLIP
var draw_from: float = DRAW_FROM
var draw_until: float = 1.0
var aim_idle: StringName = AIM_IDLE
var loose_clip: StringName = LOOSE_CLIP
## The picked RAPID clip (`Bow_RapidShoot`): the bow up and drawn, let go, and
## the next arrow on the string.
var rapid_clip: StringName = &""
## What a tap looks like (AVTANDIL_POLISH, being tried): 0 the loose clip
## over the nock it cut short, 1 the rapid clip, 2 the whole loose clip from
## the bow up and drawn.
var tap_style: int = 1
var loose_from: float = LOOSE_FROM
var loose_to: float = LOOSE_TO
## UAL 2's nock reaches back to the quiver and draws by 0.4 of it; its shot
## lets go at once and is back up by 0.35 (seen on the mannequin).
const UAL_DRAW_UNTIL := 0.4
const UAL_LOOSE_TO := 0.35
## On the mannequin: the modifier on its skeleton (the model's own is kept to
## go back to), and the pack bow's tips in its bone's frame.
var _bow_own: BowModifier
var _bow_mq: BowModifier
var _bow_ends: Array[Vector3] = []
## Where the figure's fist closes, in its hand's frame (measured off the
## mannequin's figure: the middle of the curled fingers).
const FIST := Vector3(0.0, 0.085, -0.02)
var _draw_target: float = 0.0
var _pitch: float = 0.0
var _aim_phase: float = 0.0   # 0 idle, 0..1 through the draw clip, 1 holding
var _drawing_clip: bool = false
var _loose_left: float = 0.0
var _draw_time: float = 0.85

#region Aiming up and down (AVTANDIL_POLISH 1)
## On the mannequin the held aim is one of three clips by how far up or down
## the shot goes: UAL 2's `Bow_Aim_Up` and `Bow_Aim_Down` hold the arrow at
## +0.54 and -0.56 rad, `Bow_Aim_Neutral` level (measured,
## `_shots_tmp/aimpitch_probe.gd`). Past `AIM_ZONE_IN` the steeper clip is
## crossfaded in (over `AIM_SWAP_BLEND`), back under `AIM_ZONE_OUT`; what is
## left over the clip's own angle the chest takes ([member BowModifier.pitch]).
const AIM_LOW_CLIP := &"Bow_Aim_Down"
const AIM_HIGH_PITCH := 0.54
const AIM_LOW_PITCH := -0.56
const AIM_ZONE_IN := 0.32
const AIM_ZONE_OUT := 0.22
const AIM_SWAP_BLEND := 0.22
## The chest's tilt turns the arrow by only this share of it (0.69-0.70
## measured in all three clips): the tilt asked for is the angle over it.
const PITCH_GAIN := 0.7
## How fast what is still off between the arrow on the string and the shot
## is taken up, and how much of it at most (rad).
const TRIM_RATE := 3.0
const TRIM_MAX := 0.25
var aim_high: StringName = &""
var aim_low: StringName = &""
## -1 low, 0 level, 1 high: which held aim clip the pitch asks for now.
var _aim_zone: int = 0
## The angle the base clip holds the arrow at, crossfades followed.
var _clip_pitch: float = 0.0
var _trim: float = 0.0
## The pitch of the last shot, held on through the release and eased off.
var _loose_pitch: float = 0.0


## The held aim clip for a pitch, the zone kept until it is well left.
func _aim_clip() -> StringName:
	var p := _pitch
	if _aim_zone == 0:
		if p > AIM_ZONE_IN and aim_high != &"":
			_aim_zone = 1
		elif p < -AIM_ZONE_IN and aim_low != &"":
			_aim_zone = -1
	elif _aim_zone == 1 and p < AIM_ZONE_OUT:
		_aim_zone = 0
	elif _aim_zone == -1 and p > -AIM_ZONE_OUT:
		_aim_zone = 0
	if _aim_zone == 1 and _anim.has_animation(aim_high):
		return aim_high
	if _aim_zone == -1 and _anim.has_animation(aim_low):
		return aim_low
	return aim_idle


## The angle the clip playing now holds the arrow at, followed through the
## crossfade (Godot's is linear over its blend time).
func _follow_clip_pitch(delta: float) -> void:
	var cur := StringName(_anim.current_animation)
	var to := 0.0
	if cur != &"" and cur == aim_high:
		to = AIM_HIGH_PITCH
	elif cur != &"" and cur == aim_low:
		to = AIM_LOW_PITCH
	var blend := AIM_SWAP_BLEND if cur == aim_idle or to != 0.0 else 0.06
	_clip_pitch = move_toward(_clip_pitch, to, delta * AIM_HIGH_PITCH / blend)


func _zone_pitch() -> float:
	var cur := StringName(_anim.current_animation)
	if cur != &"" and cur == aim_high:
		return AIM_HIGH_PITCH
	if cur != &"" and cur == aim_low:
		return AIM_LOW_PITCH
	return 0.0


## The chest's tilt that brings the arrow to `want` (rad, + up) over the clip.
func _chest_for(want: float, delta: float) -> float:
	var d := arrow_dir()
	# taken up only once the clip is in: through a crossfade the arrow lags
	var settled := absf(_clip_pitch - _zone_pitch()) < 0.01
	if d != Vector3.ZERO and _aim_phase >= 1.0 and _bow_mod.has_string() and settled:
		var off := want - asin(clampf(d.y, -1.0, 1.0))
		_trim = clampf(_trim + off * TRIM_RATE * delta, -TRIM_MAX, TRIM_MAX)
	else:
		_trim = move_toward(_trim, 0.0, delta * 1.5)
	return clampf((want - _clip_pitch) / PITCH_GAIN + _trim, -1.25, 1.25)
#endregion

#region The bow kept ready (AVTANDIL_POLISH 2)
## In a fight (locked on, or within [constant SkinnedRig.EASE_AFTER] of a shot)
## and standing, the bow is not let down to the waist the way the loose clip
## ends (its last third drops it there, sideways): the clip is held at
## `READY_AT`, the bow still out before him after the shot, and the chest
## leans `READY_DIP` down so it points a little under the line. At ease he
## stands as before. The next draw is taken up from there, past the nock's
## start where the bow sits at the waist (`READY_DRAW_FROM`).
const READY_AT := 0.66
const READY_DIP := -0.3
const READY_BLEND := 0.3
const READY_DRAW_FROM := 0.1
var bow_ready: bool = true
var _readying: bool = false
var _draw_start: float = 0.0


## Standing ready: the loose clip run on to `READY_AT` and stopped there, or
## crossfaded to that frame when coming from anything else.
func _hold_ready() -> void:
	var at := _anim.get_animation(loose_clip).length * READY_AT
	if _anim.current_animation == loose_clip:
		if not _readying:
			_readying = true
			_base_clip = loose_clip
		var pos := _anim.current_animation_position
		_anim.speed_scale = 1.3 if pos < at - 0.01 else 0.0
		return
	_readying = true
	_base_clip = loose_clip
	_anim.play(loose_clip, READY_BLEND)
	_anim.seek(at, true)
	_anim.speed_scale = 0.0


func _ready_now(planar: float, airborne: bool, blocking: bool) -> bool:
	return bow_ready and _on_mq and not airborne and not blocking and not _crouching \
			and planar < idle_threshold and fighting() and _anim.has_animation(loose_clip) \
			and (moves.get("bow", {}) as Dictionary).has(&"loose")
#endregion


func _configure() -> void:
	heft_swings = false
	swing_sounds = LIGHT_SWINGS.duplicate()
	# His two outfits (see [Inventory]): the ranger's hooded mantle, worn; the
	# wanderer's kaftan and cowl, in the bag.
	garbs = [&"avtandil_ranger", &"avtandil_wanderer"]
	# Who he is, picked on the hero select (tools/dg16_avtandil.py in
	# vepxis-art): the assassin's green — Quaternius' Ranger (CC0) fitted onto
	# his rig in its own shape, his own bow in the left fist and his quiver on
	# his back — THE RANGER with the hood up and only shadow in it, THE HUNTER
	# with the hood off, long hair and his face wrapped in dark cloth; or the
	# one he was, in the two outfits above.
	mesh_prefix = "avtandil"
	# and YOUR OWN, made on the hero select out of Polysplit's heroes
	# ([PolysplitLook], `SkinnedRig._add_maker()`)
	polysplit_hero = &"avtandil"
	# Only AS HE WAS is worn (2026-10-02, the user's pick): THE RANGER, THE
	# HUNTER, THE HUNTSMAN and THE FOX HUNTER were taken off the hero select.
	faces = [&"box"]
	face_skulls = faces.duplicate()
	face_names = ["AS HE WAS"]
	whole_faces = []
	swing_volume = -4.0
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
	_bow_own = _bow_mod
	if _on_mq:
		_mannequin_worn(true)
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


## The figure worn has been posed: the string and the arrow go on its bow.
func _on_figure_followed(id: StringName) -> void:
	if _bow_mod != null and _figure_skel != null and _figs.has(id) and _figs[id]["skel"] == _figure_skel:
		if _on_mq:
			_place_pack_string()
		else:
			_bow_mod.place_string_on(_figure_skel)


## On the mannequin: its own modifier (the chest tilting onto the shot), and
## the picked BOW clips for the draw, the aim and the release; back on his
## own rig, his.
func _mannequin_worn(on: bool) -> void:
	if _bow_own == null:
		return
	if on and _bow_mq == null:
		_bow_mq = BowModifier.new()
		_bow_mq.name = "Bow"
		_skel.add_child(_bow_mq)
		_bow_mq.string_u = _bow_own.string_u
		_bow_mq.string_l = _bow_own.string_l
		_bow_mq.arrow = _bow_own.arrow
	_bow_mod = _bow_mq if on else _bow_own
	# one modifier places the shared string: the other is still
	_bow_own.active = not on
	if _bow_mq != null:
		_bow_mq.active = on
	_bow_ends.clear()
	var bow: Dictionary = moves.get("bow", {}) if on else {}
	draw_clip = bow.get(&"draw", DRAW_CLIP)
	draw_from = 0.0 if bow.has(&"draw") else DRAW_FROM
	draw_until = UAL_DRAW_UNTIL if bow.has(&"draw") else 1.0
	aim_idle = bow.get(&"aim", AIM_IDLE)
	aim_high = bow.get(&"aim_high", &"")
	aim_low = AIM_LOW_CLIP if on and bow.has(&"aim") else &""
	_aim_zone = 0
	rapid_clip = bow.get(&"rapid", &"")
	loose_clip = bow.get(&"loose", LOOSE_CLIP)
	if bow.has(&"loose"):
		loose_from = maxf(float(Moveset.clip_meta(loose_clip).get("release", 0.05)) - 0.05, 0.0)
		loose_to = UAL_LOOSE_TO
	else:
		loose_from = LOOSE_FROM
		loose_to = LOOSE_TO
	if _anim != null:
		for c: StringName in [aim_idle, aim_high, aim_low]:
			if c != &"" and _anim.has_animation(c):
				_anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR


func _apply_moves() -> void:
	super()
	if _on_mq and _bow_own != null:
		_mannequin_worn(true)


## The pack's bow on the mannequin's figure has no bones to its tips: they
## are read off its mesh (its two ends, in its bone's frame) and the string
## drawn from them to the right fist.
func _place_pack_string() -> void:
	var w := String(ps_look.get("w", ""))
	var mesh := "ps_w_" + (w if w.begins_with("aw_") else "bow")
	var bow := _figure.find_child(mesh, true, false) as MeshInstance3D if _figure != null else null
	if bow == null or not bow.visible:
		return
	var bone := _figure_skel.find_bone("weapon_l")
	var hand := _figure_skel.find_bone("weapon_r")
	if bone < 0 or hand < 0:
		return
	if _bow_ends.is_empty():
		var a := _far(bow, &"weapon_l")
		var c := a
		var bind := Transform3D()
		for i in bow.skin.get_bind_count():
			if bow.skin.get_bind_name(i) == &"weapon_l":
				bind = bow.skin.get_bind_pose(i)
		for v: Vector3 in bow.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var p := bind * v
			if p.distance_squared_to(a) > c.distance_squared_to(a):
				c = p
		_bow_ends = [a, c]
		# The arrow rests on the bow at its middle, level with the middle of
		# the string, not on the fist (which holds the pack's bow 9 cm below
		# its middle): the fist's point slid up the bow's line to there.
		var along := (c - a).normalized()
		_rest = FIST + along * ((a + c) * 0.5 - FIST).dot(along)
	var xf := _figure_skel.global_transform
	var held_s := _square_bow(bone, _figure_skel.get_bone_global_pose(bone),
			_figure_skel.get_bone_global_pose(hand) * FIST)
	var held := xf * held_s
	var drawing := xf * _figure_skel.get_bone_global_pose(hand)
	_bow_mod.place_string_at(held * _bow_ends[0], held * _bow_ends[1], drawing * FIST, held * _rest)


## How far the bow is turned in the fist onto the shot, by the draw.
const SQUARE_BY_DRAW := 3.0
## Where the arrow rests on the pack's bow, in its bone's frame (see above).
var _rest := FIST

## The pack's bow, held as the clips leave it, sits at a slant to the line from
## the bow hand to the drawing hand: the string, taken by the fingers, came off
## it well below the middle and the arrow lay along the lower limb. Drawn, the
## bow is turned about the fist (the bone `weapon_l`, skeleton space `held`) so
## that its string line stands square across the arrow, and the arrow from the
## drawing fingers at `hand` lies over the bow's middle (`_rest`) and meets the
## string at its middle. Returns the turned pose, also set on the bone.
func _square_bow(bone: int, held: Transform3D, hand: Vector3) -> Transform3D:
	var w := clampf(_bow_mod.draw * SQUARE_BY_DRAW, 0.0, 1.0) if _bow_mod.has_string() else 0.0
	if w <= 0.0:
		return held
	var fist := held * FIST
	# The turn that squares it, found twice over: the rest moves as it turns.
	var q_all := Quaternion.IDENTITY
	var now := held
	var v := Vector3.ZERO
	var d2 := Vector3.ZERO
	for i in 2:
		var rest := now * _rest
		var a := now * (_bow_ends[0] as Vector3)
		var c := now * (_bow_ends[1] as Vector3)
		var shot := rest - hand
		if shot.length() < 0.1 or a.distance_to(c) < 0.3:
			return held
		v = shot.normalized()
		var d := (c - a).normalized()
		var o := (a + c) * 0.5 - rest
		o -= d * o.dot(d)
		if o.length() < 0.02:
			return held
		var o_hat := o.normalized()
		d2 = d - v * d.dot(v)
		if d2.length() < 0.1:
			return held
		d2 = d2.normalized()
		var from := Basis(d, o_hat, d.cross(o_hat)).orthonormalized()
		var to := Basis(d2, -v, d2.cross(-v)).orthonormalized()
		var q := Quaternion(to * from.inverse())
		q_all = q * q_all
		now = Transform3D(Basis(q_all) * held.basis, fist + q_all * (held.origin - fist))
	var qw := Quaternion.IDENTITY.slerp(q_all, w)
	var tremble := shake()
	if tremble > 0.0:
		qw = Quaternion(v.cross(d2).normalized(), SHAKE_TURN * tremble * _shake_noise(5.0)) \
				* Quaternion(d2, SHAKE_TURN * 0.6 * tremble * _shake_noise(9.0)) * qw
	var turned := Transform3D(Basis(qw) * held.basis, fist + qw * (held.origin - fist))
	var p := _figure_skel.get_bone_parent(bone)
	var local := (_figure_skel.get_bone_global_pose(p) if p >= 0 else Transform3D()).affine_inverse() * turned
	_figure_skel.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion())
	_figure_skel.set_bone_pose_position(bone, local.origin)
	return turned


## Where the shot leaves the bow: the head of the arrow on the string, or
## nowhere (not finite) with none nocked, for the controller's own height.
func loose_point() -> Vector3:
	if _bow_mod != null and _bow_mod.arrow != null and _bow_mod.arrow.visible:
		var at := _bow_mod.arrow.global_transform * Vector3(0.0, 0.0, -ARROW_HEAD)
		_loose_local = global_transform.affine_inverse() * at
		return at
	# A tap: the string never came back, but the bow goes up as it is let go,
	# so the arrow leaves where it last left a drawn bow.
	if _on_mq:
		return global_transform * _loose_local
	return Vector3.INF


## The last drawn shot's head of the arrow, in the rig's own frame; until one
## has been drawn, where it was measured at full draw on the mannequin.
var _loose_local := Vector3(-0.07, 1.62, 0.75)


#region The bow, as the controller calls it
func aim_bow(draw: float, pitch: float) -> void:
	_draw_target = clampf(draw, 0.0, 1.0)
	_pitch = clampf(pitch, -1.1, 1.1)


func loose_bow() -> void:
	if _aim_phase <= 0.05 and _draw_target <= 0.05:
		return
	var tap := _aim_phase < 0.6
	_rouse()
	_loose_pitch = _pitch * (1.0 if _aim_phase > 0.5 else _aim_phase * 2.0)
	_full_t = -1.0
	_loose_left = 0.35
	_drawing_clip = false
	_aim_phase = 0.0
	if tap and tap_style == 1 and rapid_clip != &"" and _anim.has_animation(rapid_clip):
		_play_action(rapid_clip, Role.FREE, 1.0, 0.06)
	elif tap and tap_style == 2 and _anim.has_animation(loose_clip):
		_play_action(loose_clip, Role.FREE, 1.15, 0.1, 0.0, 0.5)
	elif _anim.has_animation(loose_clip):
		_play_action(loose_clip, Role.FREE, 1.3, 0.05, loose_from, loose_to)


#region The moment to let go (AVTANDIL_POLISH 7, being tried)
## On (the user's pick, 2026-10-04): the string at full draw settles
## for `SETTLE` before the moment comes; let go within `PERFECT_WINDOW` of it it
## is a perfect release, and held on past it the bow starts to shake. The moment
## is marked only for the archer himself, by a small glint on the arrowhead and
## no sound: whoever he is shooting at must read it off his body, not off a
## light.
var release_timing: bool = true
const SETTLE := 0.25
const PERFECT_WINDOW := 0.25
const SHAKE_RAMP := 1.2
const SHAKE_PITCH := 0.06
const SHAKE_TURN := 0.09
var _full_t: float = -1.0
var _shake_t: float = 0.0
var _glinted: bool = false


## 0 not yet (or not at full draw), 1 a perfect release now, 2 held too long.
func release_grade() -> int:
	if _full_t < SETTLE:
		return 0
	return 1 if _full_t <= SETTLE + PERFECT_WINDOW else 2


## How hard the bow shakes, 0 to 1.
func shake() -> float:
	if not release_timing or _full_t < 0.0:
		return 0.0
	return clampf((_full_t - SETTLE - PERFECT_WINDOW) / SHAKE_RAMP, 0.0, 1.0)


func _tick_release(delta: float, drawing: bool) -> void:
	if drawing and _draw_target >= 0.999 and _aim_phase >= 1.0 and _skill_t < 0.0:
		if _full_t < 0.0:
			_full_t = 0.0
			_glinted = false
		else:
			_full_t += delta
		if release_timing and not _glinted and _full_t >= SETTLE:
			_glinted = true
			if _body == null or _body.is_multiplayer_authority():
				_glint()
	else:
		_full_t = -1.0
	_shake_t += delta


func _shake_noise(seed_at: float) -> float:
	var s := _shake_t + seed_at
	return sin(s * 43.0) * 0.5 + sin(s * 27.0 + 1.3) * 0.35 + sin(s * 61.0 + 2.1) * 0.15


func _glint() -> void:
	if _bow_mod == null or _bow_mod.arrow == null:
		return
	var head := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.014
	ball.height = 0.028
	head.mesh = ball
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.95, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	head.material_override = mat
	head.position = Vector3(0.0, 0.0, -0.8)
	_bow_mod.arrow.add_child(head)
	var tw := head.create_tween()
	tw.tween_property(head, "scale", Vector3.ONE * 1.8, 0.06)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tw.tween_callback(head.queue_free)
#endregion


func is_aiming() -> bool:
	return _aim_phase > 0.3


## The Rain of Arrows' shot (`AV_Sky_Shot`, built in Blender from his
## shooting clip): a hand to the quiver, the arrow nocked, the body leaning
## back until the bow points at the sky, the string drawn and let go, and
## upright again after. Returns how long until the string goes (0 with no
## clip), when the arrow has to leave the bow.
func sky_shot() -> float:
	if _anim == null or not _anim.has_animation(SKY_CLIP):
		return 0.0
	_drawing_clip = false
	_aim_phase = 0.0
	_play_action(SKY_CLIP, Role.FREE, SKY_RATE, 0.12)
	_sky_len = _anim.get_animation(SKY_CLIP).length / SKY_RATE
	_sky_left = _sky_len
	return sky_lead()


## How long after it starts the sky shot lets the string go.
func sky_lead() -> float:
	if _anim == null or not _anim.has_animation(SKY_CLIP):
		return 0.0
	return _anim.get_animation(SKY_CLIP).length / SKY_RATE * SKY_RELEASE


## Hunter's Mark: thrown on the run. No clip — the legs go on with whatever
## they were doing — only the free arm flung out at the prey
## ([member BowModifier.point]): up in `POINT_UP`, held `POINT_HOLD`, down in
## `POINT_DOWN`. (`AV_Point_Charge`, the lunge it used to be, is still in the
## glb, unused.)
const POINT_UP := 0.09
const POINT_HOLD := 0.14
const POINT_DOWN := 0.2
var _point_t: float = -1.0
var _point_node: Node3D = null
var _point_last := Vector3.ZERO


func point_lead() -> float:
	return POINT_UP


## Flings the arm out at `at`; returns how long until the glint goes.
func point_mark(at: Node3D = null) -> float:
	_point_node = at
	if at != null:
		_point_last = at.global_position + Vector3.UP * 1.2
	_point_t = 0.0
	return POINT_UP


## A blow landed while a skill was under way: let the string and the arm go.
func cancel_skill_shot() -> void:
	_skill_t = -1.0
	_point_t = -1.0


## The skill shots (Piercing and Fire Arrow): drawn as an ordinary shot is
## (`AV_Nock_Draw` over `draw_time`), held at full aim for `hold` seconds, then
## let go with the ordinary release ([method loose_skill_shot]).
## (`NOCK_RATE` and `AV_Aim_Overdraw` are no longer used.)
const NOCK_RATE := 1.25
const OVERDRAW_CLIP := &"AV_Aim_Overdraw"
## The release of `AV_Shooting_Arrow` and its follow-through, in frames of 151.
const LOOSE_PART := Vector2(116.0 / 151.0, 1.0)
## How far from the nock the arrowhead is (the arrow [method _make_arrow] makes).
const ARROW_HEAD := 0.8
## A skill shot's string: seconds since the nock began (-1 when none is
## drawn), how long the nock and the hold are, and the pitch it is aimed at.
var _skill_t: float = -1.0
var _skill_nock: float = 0.3
var _skill_hold: float = 0.5
var _skill_pitch: float = 0.0
## How far a skill shot braces the body (hips down, leaning on; see
## [member BowModifier.crouch]), and where the brace is now.
var _skill_brace: float = 0.0
var _brace_now: float = 0.0


## How long a skill shot's draw takes: braced, a quarter slower; `quick`
## times faster.
func nock_lead(brace: float = 0.0, quick: float = 1.0) -> float:
	return _draw_time * (1.0 + 0.25 * clampf(brace, 0.0, 1.0)) / maxf(quick, 0.1)


## Draws exactly as for an ordinary shot — the same clip over the same
## `draw_time`, the string coming back with it — then holds at full (the
## draw's last frames, slowed right down) for `hold` seconds, until [method loose_skill_shot]
## lets go with the ordinary release. Returns how long the draw takes. `pitch`
## is how far up (+) or down the shot goes, radians: the chest tilts onto it as
## the string comes back.
func charged_shot(hold: float, pitch: float = 0.0, brace: float = 0.0, quick: float = 1.0) -> float:
	_drawing_clip = false
	_aim_phase = 0.0
	if _anim == null or not _anim.has_animation(draw_clip):
		return 0.3
	var clip_len := _anim.get_animation(draw_clip).length * (draw_until - draw_from)
	# A braced shot is drawn heavier: a quarter slower.
	var nock := play_part(draw_clip, clip_len / nock_lead(brace, quick), draw_from, draw_until, 0.1)
	if nock <= 0.0:
		return 0.3
	# The string is drawn by hand for a skill shot: [method animate] brings it
	# back with the draw and holds it at full until [method loose_skill_shot].
	_skill_t = 0.0
	_skill_nock = nock
	_skill_hold = hold
	_skill_pitch = clampf(pitch, -0.9, 1.1)
	_skill_brace = clampf(brace, 0.0, 1.0)
	# Held at full: the draw's last frames, stretched over the hold, so the
	# bow stays up and the string at the cheek (the aim idle drops the bow).
	get_tree().create_timer(nock * 0.97, false).timeout.connect(func() -> void:
		if _act_clip == draw_clip and _skill_t >= 0.0:
			var held := draw_until - 0.03 * (draw_until - draw_from)
			play_part(draw_clip, clip_len * 0.03 / maxf(hold + 0.25, 0.05), held, draw_until, 0.02))
	return nock


## Lets the skill shot go: the ordinary release.
func loose_skill_shot() -> void:
	_rouse()
	_skill_t = -1.0
	_loose_left = 0.35
	if _anim != null and _anim.has_animation(loose_clip):
		_play_action(loose_clip, Role.FREE, 1.3, 0.05, loose_from, loose_to)


## Where the arrow on the string has its head right now — where a shot leaves
## the bow from. The bow hand when no arrow is on the string.
func arrow_tip() -> Vector3:
	if _bow_mod != null and _bow_mod.arrow != null and _bow_mod.arrow.visible:
		return _bow_mod.arrow.global_transform * Vector3(0.0, 0.0, -ARROW_HEAD)
	return bow_hand()


## The way the arrow on the string points (zero when there is none).
func arrow_dir() -> Vector3:
	if _bow_mod != null and _bow_mod.arrow != null and _bow_mod.arrow.visible:
		return -_bow_mod.arrow.global_transform.basis.z.normalized()
	return Vector3.ZERO


## Where the arrow leaves the bow: his bow hand.
func bow_hand() -> Vector3:
	if _skel != null:
		var hand := _skel.find_bone("hand_l")
		if hand >= 0:
			return _skel.global_transform * _skel.get_bone_global_pose(hand).origin
	return global_position + Vector3.UP * 1.5


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
		if _aim_phase <= 0.0 and not _drawing_clip and not moving and _anim.has_animation(draw_clip):
			# Up out of whatever he was doing: the draw clip fitted to the draw
			# time the profile gives, so the string is back when the power is.
			var draw_time := 0.85
			var body := _body as Player
			if body != null and body.profile != null:
				draw_time = maxf(body.profile.draw_time, 0.2)
			_drawing_clip = true
			# From the bow kept ready, past the nock's start at the waist.
			_draw_start = draw_from
			if _readying and _on_mq:
				_draw_start = maxf(draw_from, READY_DRAW_FROM)
			_readying = false
			_base_clip = draw_clip
			var clip_len := _anim.get_animation(draw_clip).length
			_anim.play(draw_clip, 0.12 if _draw_start > draw_from else 0.08)
			_anim.seek(clip_len * _draw_start, true)
			# The nock-and-draw at no slower than it was performed; faster when the
			# profile's draw time asks for it. The power keeps building after.
			_anim.speed_scale = maxf(clip_len * (draw_until - _draw_start) / draw_time, 1.0)
		if _drawing_clip:
			var draw_len := _anim.get_animation(draw_clip).length
			var at := _anim.current_animation_position / draw_len if _anim.current_animation == draw_clip else 1.0
			var through := (at - _draw_start) / maxf(draw_until - _draw_start, 0.01)
			_aim_phase = clampf(through, 0.0, 1.0)
			if through >= 0.98 or _anim.current_animation != draw_clip:
				_drawing_clip = false
				_aim_phase = 1.0
	elif not drawing and _loose_left <= 0.0:
		_drawing_clip = false
		_aim_phase = 0.0
	_tick_release(delta, drawing)
	_sky_left = maxf(_sky_left - delta, 0.0)
	if _bow_mod != null and _sky_left > 0.0:
		# The sky shot draws its own string: back over the stretch the hand is
		# on it, let go at the release.
		var through := 1.0 - _sky_left / maxf(_sky_len, 0.01)
		_bow_mod.draw = smoothstep(SKY_DRAW_FROM, SKY_RELEASE - 0.02, through) if through < SKY_RELEASE else 0.0
		_bow_mod.pitch = 0.0
	elif _bow_mod != null and _skill_t >= 0.0:
		# A skill shot: the string comes back over the nock's second half, is
		# held at full, and goes at [method loose_skill_shot]. A shot that never
		# went (the hero was hit, say) lets go of itself.
		_skill_t += delta
		var u := clampf(_skill_t / maxf(_skill_nock, 0.01), 0.0, 1.0)
		var d := u
		_bow_mod.draw = d
		# The chest comes onto the line first, the string after it.
		_bow_mod.pitch = _skill_pitch * smoothstep(0.1, 0.7, u) / PITCH_GAIN
		if _skill_t > _skill_nock + _skill_hold + 1.5:
			_skill_t = -1.0
	elif _bow_mod != null:
		var string := 0.0
		if drawing:
			string = clampf((_aim_phase - DRAW_STRING_FROM) / (1.0 - DRAW_STRING_FROM), 0.0, 1.0)
			string *= maxf(_draw_target, 0.6)
		_bow_mod.draw = string
		_follow_clip_pitch(delta)
		if drawing:
			_bow_mod.pitch = _chest_for(_pitch, delta) * (1.0 if _aim_phase > 0.5 else _aim_phase * 2.0)
		elif _loose_left > 0.0:
			# Let go: the bow stays on the line it was shot along and eases off.
			_bow_mod.pitch = _chest_for(_loose_pitch * smoothstep(0.0, 0.35, _loose_left), delta)
		else:
			_trim = 0.0
			_bow_mod.pitch = move_toward(_bow_mod.pitch, READY_DIP if _readying else 0.0, delta * 1.5)
		_bow_mod.pitch += SHAKE_PITCH * shake() * _shake_noise(0.0)
	if _bow_mod != null:
		# The mark's flung arm.
		var w := 0.0
		if _point_t >= 0.0:
			_point_t += delta
			if _point_node != null and is_instance_valid(_point_node):
				_point_last = _point_node.global_position + Vector3.UP * 1.2
			if _point_t < POINT_UP:
				w = smoothstep(0.0, 1.0, _point_t / POINT_UP)
			elif _point_t < POINT_UP + POINT_HOLD:
				w = 1.0
			elif _point_t < POINT_UP + POINT_HOLD + POINT_DOWN:
				w = 1.0 - smoothstep(0.0, 1.0, (_point_t - POINT_UP - POINT_HOLD) / POINT_DOWN)
			else:
				_point_t = -1.0
		_bow_mod.point = w
		_bow_mod.point_at = _point_last
		# The brace comes on with the draw and goes a little after the release.
		var brace_to := _skill_brace if _skill_t >= 0.0 else 0.0
		_brace_now = move_toward(_brace_now, brace_to, delta * (2.2 if brace_to > _brace_now else 1.6))
		_bow_mod.crouch = _brace_now
		# Running, not aiming: the head level, not thrown back.
		var running := String(_anim.current_animation).contains("Run") \
				or String(_anim.current_animation).contains("Sprint")
		var level_to := 1.0 if running and _aim_phase < 0.1 and _skill_t < 0.0 else 0.0
		_bow_mod.head_level = move_toward(_bow_mod.head_level, level_to, delta * 4.0)
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
			var held := _aim_clip()
			_set_base(held, AIM_SWAP_BLEND if held != aim_idle or _base_clip in [aim_high, aim_low] else 0.12, 1.0)
		else:
			var clip := _dir4(&"aim_walk", &"aim_walk_back", &"aim_walk_left", &"aim_walk_right")
			_set_base(clip, 0.15, _rate(clip, planar))
		_readying = false
		return
	if _ready_now(planar, airborne, blocking):
		_hold_ready()
		return
	_readying = false
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
