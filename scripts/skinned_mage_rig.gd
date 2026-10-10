class_name SkinnedMageRig
extends SkinnedRig

## The mage: a staff, a long white beard, and bolts of lightning thrown from
## afar. The knight's rig with the magic clips Mixamo has, and the bow's
## interface — `aim_bow()` / `loose_bow()` — so the controller charges and
## casts his spell exactly as it draws and looses Avtandil's arrow.
##
## * **Charging** swings the staff round — down, back behind him and up
##   (`MG_Charge_In`, cut from Mixamo's Two Hand Spell Casting) — and then holds
##   it high while the button is (`MG_Charge_Hold`, looped), and the magic
##   gathers at the crystal as a ball of light that grows with the charge and
##   turns from gold to blue-violet when it is full — where the bolt will leave
##   from. The legs walk while he moves.
## * **Casting** is a throw with the staff (`MG_Cast_Throw`, cut from Standing
##   2H Magic Attack 01): swung back behind him and brought through to the
##   front, and the bolt leaves the crystal as it comes past his shoulder
##   (`cast_lead()` after the button, from `spell_origin()`), with a burst of
##   sparks and the crystal flaring there.
## * **Levitating** — the jump held on the way down — is Mixamo's float.
## * **Jumping** is `MG_Jump`, keyed by hand in Blender: the push off, the
##   knees driven up and the staff raised on the way up, open at the top, legs
##   reaching down and the free arm out for balance on the way down. It is not
##   played through at its own pace — how far in it is follows the body's
##   vertical speed, so the top of the clip is always the top of the jump
##   however high or long it is.
##
## Source: `~/Desktop/vepxis-art/heroes/heroes.blend` (`mage_rig`).

## Charging: the staff swung round once, then held high for as long as the
## button is.
const CHARGE_CLIP := &"MG_Charge_In"
const CHARGE_HOLD := &"MG_Charge_Hold"
const CAST_CLIP := &"MG_Cast_Throw"
## The throw: from here, round to the front by `CAST_RELEASE` — measured on the
## crystal, frame 19 of 46, in front of his shoulder — and settled by `CAST_TO`.
const CAST_FROM := 0.04
const CAST_RELEASE := 0.40
const CAST_TO := 0.8
const CAST_RATE := 1.35
const FLOAT_CLIP := &"MG_Float"
const JUMP_CLIP := &"MG_Jump"
## Where the crystal sits up the staff from the hand, in metres.
const CRYSTAL_UP := 0.83
## The crystal's own light at rest: the ice-blue of the stone.
const CRYSTAL_LIGHT := Color(0.45, 0.85, 1.0)

## The throw as played now: his own, or on the mannequin Tariel's spell
## cast (`SS_Spell_Casting`, lent him: no bought pack has one), the legs
## walking under it as he moves (ANIMATION_MIGRATION.md).
var cast_clip: StringName = CAST_CLIP
var cast_from: float = CAST_FROM
var cast_release: float = CAST_RELEASE
var cast_to: float = CAST_TO
const MQ_CAST := &"SS_Spell_Casting"
## Kevin Iglesias' Human Spellcasting on the mannequin (vepxis-art
## tools/kv_godot.gd over kevin_spell/glb): KV_MagicAttack*, KV_Casting*.
const KEVIN_SPELL_LIB := "res://assets/anim/lab/kevin_spell_lib.res"
## Where in Tariel's cast the hand comes through (measured on the mannequin:
## the right hand's fastest, clip_meta.json "release"), and from and to.
const MQ_CAST_FROM := 0.15
const MQ_CAST_TO := 0.8
var _staff_mount: Node3D
var _charge: float = 0.0
var _wind: MageWind
var _cast_left: float = 0.0
var _glow: OmniLight3D
## The charge gathering at the crystal.
var _orb: MeshInstance3D
var _orb_mat: StandardMaterial3D
var _orb_clock: float = 0.0
## How long the charge has been held (for the swing and then the hold), and
## the countdown to the flash at the crystal as the bolt leaves it.
var _charge_time: float = 0.0
var _flash_in: float = -1.0


func _configure() -> void:
	# The long wine cape from under the high collar, gold at the hem, runes.
	capes = [{
		"bone": "spine_02", "left": [0.2, 0.155, 1.44], "right": [-0.2, 0.155, 1.44],
		"length": 1.08, "spread": 1.35, "flare": 0.1, "wrap": 0.12, "cols": 7, "rows": 11,
		"base": Color.html("3f0d18"), "hem": Color.html("c8a04a"), "trim": Color.html("c8a04a"),
		"pattern": "runes", "hold": 0.5, "wind": 1.0, "drag": 0.6,
		"colliders": [["pelvis", "neck_01", 0.17], ["thigh_l", "calf_l", 0.14], ["thigh_r", "calf_r", 0.14],
				["calf_l", "foot_l", 0.1], ["calf_r", "foot_r", 0.1]],
	}]
	# His robes (see [Inventory]), the first worn, each with its cape.
	garbs = [&"mage_storm", &"mage_ember", &"mage_sage", &"mage_wine"]
	garb_capes = [
		[{"base": Color.html("172142"), "hem": Color.html("c9ced6"), "trim": Color.html("c9ced6")}],
		[{"base": Color.html("111114"), "hem": Color.html("8e1222"), "trim": Color.html("8e1222")}],
		[{"base": Color.html("b9b09c"), "hem": Color.html("c8a04a"), "trim": Color.html("c8a04a")}],
		[{}],
	]
	heft_swings = false
	swing_sounds = LIGHT_SWINGS.duplicate()
	swing_volume = -4.0
	clips = {
		&"idle": &"MG_Idle", &"walk": &"MG_Walk", &"run": &"MG_Run",
		&"walk_back": &"MG_Walk_Back", &"run_back": &"MG_Run_Back",
		&"walk_left": &"MG_Walk_Left", &"walk_right": &"MG_Walk_Right",
		&"run_left": &"MG_Run_Left", &"run_right": &"MG_Run_Right",
		&"block_idle": &"MG_Block", &"block_walk": &"MG_Walk",
		&"block_walk_back": &"MG_Walk_Back", &"block_walk_left": &"MG_Walk_Left",
		&"block_walk_right": &"MG_Walk_Right",
		&"crouch": &"MG_Crouch", &"air": &"MG_Fall",
		&"crouch_walk": &"MG_Crouch_Walk", &"crouch_walk_back": &"MG_Crouch_Walk_Back",
		&"crouch_walk_left": &"MG_Crouch_Walk_Left", &"crouch_walk_right": &"MG_Crouch_Walk_Right",
		&"roll": &"MG_Roll", &"down": &"MG_Death",
		&"hit": &"MG_Hit", &"hit_blocked": &"MG_Hit",
		&"mantle": &"MG_Mantle", &"plunge": &"MG_Cast_Ground",
		&"overhead": &"MG_Cast_Ground",
	}
	ground_speed = {
		# Mixamo's walks and runs, the staff arm kept from his own clips.
		&"MG_Walk": 0.79, &"MG_Run": 2.7, &"MG_Walk_Back": 0.4, &"MG_Run_Back": 2.29,
		&"MG_Walk_Left": 1.25, &"MG_Walk_Right": 1.25, &"MG_Run_Left": 3.27, &"MG_Run_Right": 2.61,
		&"MG_Crouch_Walk": 0.96, &"MG_Crouch_Walk_Back": 0.69, &"MG_Crouch_Walk_Left": 0.9,
		&"MG_Crouch_Walk_Right": 0.93,
	}
	looping = [
		&"MG_Idle", &"MG_Walk", &"MG_Run", &"MG_Walk_Back", &"MG_Run_Back", &"MG_Walk_Left",
		&"MG_Walk_Right", &"MG_Run_Left", &"MG_Run_Right", &"MG_Crouch", &"MG_Crouch_Walk",
		&"MG_Crouch_Walk_Back", &"MG_Crouch_Walk_Left", &"MG_Crouch_Walk_Right", &"MG_Fall",
		&"MG_Float", &"MG_Cast_Sustained", &"MG_Block", CHARGE_HOLD,
	]
	# A press with nothing charged is a quick shove of the staff.
	flurry = [&"MG_Cast_Sweep"]
	cut_window = {}
	run_threshold = 2.2
	max_play_rate = 2.4
	roll_share = 0.8
	cloth_enabled = false
	# As he was, or YOUR OWN, made on the hero select out of Polysplit's
	# heroes ([PolysplitLook], `SkinnedRig._add_maker()`), a sword in his
	# hand (2026-10-02, the user's word) and a staff in the other if he will.
	polysplit_hero = &"mage"
	# light: thrown a fifth further by a felling blow (the user's word, 2026-10-10)
	fall_carry = 1.2
	mq_borrow = {MQ_CAST: "tariel"}
	# the elf's Frost Step glides in the warrior's slide ([MageSkills])
	mq_borrow[MageSkills.GLIDE_CLIP] = "warrior"
	mq_libs = [KEVIN_SPELL_LIB]


func _ready() -> void:
	super()
	if _skel == null:
		return
	_wind = MageWind.new()
	_wind.name = "Wind"
	add_child(_wind)
	# The crystal's light and the ball gathering at it: on the staff of his own
	# model, or, YOUR OWN worn on the mannequin (which has no weapon_l and is
	# worn before this runs), on the rig itself, put every frame where the
	# figure's staff head or empty off fist is (`_crystal_at()`). Before
	# 2026-10-06 it was never made on the mannequin, so nothing gathered and
	# the bolt left from 1.6 m over his feet, off the staff (the user's word).
	var model := _own.get("skel", _skel) as Skeleton3D
	var bone := model.find_bone("weapon_l") if model != null else -1
	var up := Vector3.UP
	if bone >= 0:
		var mount := BoneAttachment3D.new()
		mount.name = "StaffMount"
		model.add_child(mount)
		mount.bone_name = "weapon_l"
		_staff_mount = mount
		up = (model.get_bone_global_rest(bone).basis.inverse() * Vector3.UP).normalized()
	_glow = OmniLight3D.new()
	_glow.name = "Crystal"
	_glow.position = up * CRYSTAL_UP
	_glow.light_color = CRYSTAL_LIGHT
	_glow.omni_range = 3.0
	_glow.light_energy = 0.15
	_glow.shadow_enabled = false
	(_staff_mount if _staff_mount != null and not _on_mq else self as Node3D).add_child(_glow)
	_orb = MeshInstance3D.new()
	_orb.name = "Gathering"
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 16
	ball.rings = 8
	_orb.mesh = ball
	_orb_mat = StandardMaterial3D.new()
	_orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_orb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_orb_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_orb.material_override = _orb_mat
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orb.visible = false
	_glow.add_child(_orb)
	if _on_mq:
		_mannequin_worn(true)
	_warm_skills.call_deferred()


## Her skills' look built in front of the view for a few frames as she comes
## into the world (where there is a window: the level's own warm-up does it
## too, behind its black screen), so the first cast does not stall.
func _warm_skills() -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	for i in 2:
		await get_tree().process_frame
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var props := Node3D.new()
	props.name = "SkillWarmup"
	cam.add_child(props)
	props.position = Vector3(0.0, 0.0, -2.0)
	props.scale = Vector3.ONE * 0.15
	MageSkills.warm(props)
	DarkSkills.warm(props)
	for i in 4:
		await get_tree().process_frame
	if is_instance_valid(props):
		props.queue_free()


#region The spell, as the controller calls it (the bow's interface)
func aim_bow(draw: float, _pitch: float) -> void:
	_charge = clampf(draw, 0.0, 1.0)


func loose_bow() -> void:
	_cast_left = 0.45 + cast_lead()
	_charge = 0.0
	_flash_in = cast_lead()
	if _anim.has_animation(cast_clip):
		_play_action(cast_clip, Role.FREE, CAST_RATE, 0.1, cast_from, cast_to)
		# on the mannequin Tariel's cast is the arms only: the legs go on
		walk_under = _on_mq


## How long after the button the staff comes through and the bolt goes.
func cast_lead() -> float:
	if _anim == null or not _anim.has_animation(cast_clip):
		return 0.0
	return _anim.get_animation(cast_clip).length * (cast_release - cast_from) / CAST_RATE


## Where the bolt leaves from: the staff's crystal.
func spell_origin() -> Vector3:
	if _glow != null and _glow.is_inside_tree():
		return _glow.global_position
	return global_position + Vector3.UP * 1.6


func is_aiming() -> bool:
	return _charge > 0.05


func attack(style: int = -1) -> void:
	if _on_mq:
		# YOUR OWN holds a sword (2026-10-02, the user's word): he cuts with it
		super(style)
		return
	attack_serial += 1
	_play_action(flurry[0], Role.FREE, 1.6, 0.06)


## His own long cape (`capes`) only over his own robes: over YOUR OWN, which
## wears its class's cape or cloak, it hung a second one inside the clothes (the
## user's word, 2026-10-06).
func set_garb(index: int) -> void:
	super(index)
	if faces.size() > face and bool((figure_faces.get(faces[face], {}) as Dictionary).get("custom", false)):
		for cape in cloth_capes:
			cape.queue_free()
		cloth_capes.clear()


## On the mannequin: Tariel's cast for the throw, and the crystal's light off
## the hidden model (on the rig, put where the figure's off hand is).
func _mannequin_worn(on: bool) -> void:
	var lent := on and _anim != null and _anim.has_animation(MQ_CAST)
	cast_clip = MQ_CAST if lent else CAST_CLIP
	cast_from = MQ_CAST_FROM if lent else CAST_FROM
	cast_to = MQ_CAST_TO if lent else CAST_TO
	cast_release = float(Moveset.clip_meta(MQ_CAST).get("release", 0.45)) if lent else CAST_RELEASE
	if _glow != null and _staff_mount != null:
		_glow.reparent(self if on else _staff_mount, false)
		if not on and _skel.find_bone("weapon_l") >= 0:
			_glow.position = (_skel.get_bone_global_rest(_skel.find_bone("weapon_l")).basis.inverse()
					* Vector3.UP).normalized() * CRYSTAL_UP


## Where the crystal is on the mannequin's figure: the top of the staff in
## the off hand (its far end on the thumb's side), or the off fist.
func _crystal_at() -> Vector3:
	if _figure_skel == null:
		return global_position + Vector3.UP * 1.6
	var b := _figure_skel.find_bone("weapon_l")
	var held := _figure_skel.global_transform * _figure_skel.get_bone_global_pose(b)
	var o := String(ps_look.get("o", ""))
	if o.begins_with("staff") or PolysplitLook.aw_name(o) == "staff":
		if not _heads.has(o):
			_heads[o] = _staff_head(_figure.find_child("ps_o_" + o, true, false) as MeshInstance3D)
		return held * (_heads[o] as Vector3)
	return held * Vector3(0.0, 0.085, -0.02)


## Each staff's head in the hand's (weapon_l's) space, worked out once.
var _heads: Dictionary = {}


## The middle of a staff's head in weapon_l's space: the staff lies along the
## bone's z with its head towards +z (the hand holds it a little below its
## middle, so its foot is the vertex furthest from the hand, which is what
## was used before 2026-10-06 and, turned round, put the ball 0.16 m past the
## head and off to its side); the head is the vertices within 0.12 m of its top.
func _staff_head(mesh: MeshInstance3D) -> Vector3:
	if mesh == null or mesh.skin == null or mesh.mesh == null or _figure_skel == null:
		return Vector3(0.0, 0.0, 0.8)
	var at := _figure_skel.find_bone("weapon_l")
	var bind := Transform3D()
	var found := false
	for i in mesh.skin.get_bind_count():
		var named := mesh.skin.get_bind_name(i)
		if named == &"weapon_l" or (named == &"" and mesh.skin.get_bind_bone(i) == at):
			bind = mesh.skin.get_bind_pose(i)
			found = true
	if not found:
		return Vector3(0.0, 0.0, 0.8)
	var points: Array[Vector3] = []
	var top := -INF
	for s in mesh.mesh.get_surface_count():
		for v: Vector3 in mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			var p := bind * v
			points.append(p)
			top = maxf(top, p.z)
	var sum := Vector3.ZERO
	var n := 0
	for p in points:
		if p.z >= top - 0.12:
			sum += p
			n += 1
	return sum / float(n) if n > 0 else Vector3(0.0, 0.0, 0.8)
#endregion


func animate(delta: float, planar_speed: float, speed_ratio: float, airborne: bool,
		dashing: bool, vertical_speed: float, blocking: bool = false) -> void:
	if _anim == null:
		return
	_cast_left = maxf(_cast_left - delta, 0.0)
	_place_crystal()
	if _flash_in >= 0.0:
		_flash_in -= delta
		if _flash_in < 0.0 and _glow != null and _glow.is_inside_tree():
			# The bolt leaves the crystal: a burst of sparks there, thrown the
			# way he faces, and the stone flares.
			var ahead := -(_body as Node3D).global_transform.basis.z if _body is Node3D else Vector3.FORWARD
			ParryFlash.burst(Blood.world_of(self), _glow.global_position, ahead, 1.0, false)
			_glow.light_energy = 6.0
	_charge_time = _charge_time + delta if _charge > 0.05 else 0.0
	if _glow != null:
		var want := 0.15 + 2.6 * _charge + (1.6 if _cast_left > 0.0 else 0.0)
		_glow.light_energy = lerpf(_glow.light_energy, want, clampf(delta * 12.0, 0.0, 1.0))
		var full := _charge >= 0.97
		_glow.light_color = Color(0.62, 0.55, 1.0) if full else CRYSTAL_LIGHT
	if _orb != null:
		_orb_clock += delta
		_orb.visible = _charge > 0.05
		if _orb.visible:
			var full := _charge >= 0.97
			var pulse := 1.0 + (0.18 if full else 0.06) * sin(_orb_clock * (14.0 if full else 8.0))
			_orb.scale = Vector3.ONE * lerpf(0.06, 0.34, _charge) * pulse
			var tint := Color(0.62, 0.55, 1.0) if full else Color(1.0, 0.8, 0.4)
			_orb_mat.albedo_color = Color(tint, lerpf(0.35, 0.85, _charge))
	if _wind != null:
		var body := _body as Player
		var floating := body != null and body.is_levitating()
		# Only while he floats (the jump held): a plain jump is just a jump.
		_wind.amount = 1.35 if floating and airborne else 0.0
	super(delta, planar_speed, speed_ratio, airborne, dashing, vertical_speed, blocking)
	# again once this frame's pose is laid, so the ball sits on the staff head
	# as it swings rather than a frame behind it
	_place_crystal()


## On the mannequin: the crystal (and the ball under it) on the figure's staff
## head or off fist.
func _place_crystal() -> void:
	if _on_mq and _glow != null and _glow.get_parent() == self:
		_glow.global_position = _crystal_at()


func _pick_base(planar: float, airborne: bool, dashing: bool, vy: float, blocking: bool) -> void:
	var body := _body as Player
	if airborne and body != null and body.is_levitating() and _anim.has_animation(FLOAT_CLIP):
		_set_base(FLOAT_CLIP, 0.3, 1.0)
		return
	if airborne and _anim.has_animation(JUMP_CLIP):
		# Rising at full jump speed is the start of the clip, the top of the
		# arc is its middle, falling as fast again is its end.
		var v0 := body._jump_velocity if body != null and body._jump_velocity > 0.1 else 8.0
		var through := clampf(0.5 - 0.5 * vy / v0, 0.0, 1.0)
		_set_base(JUMP_CLIP, 0.12, 1.0)
		_anim.seek(_anim.get_animation(JUMP_CLIP).length * through, false)
		return
	if _charge > 0.05 and not airborne and planar < idle_threshold and _anim.has_animation(CHARGE_CLIP):
		# The staff swung round once, then held high while the button is.
		var swing := _anim.get_animation(CHARGE_CLIP).length
		if _charge_time < swing or not _anim.has_animation(CHARGE_HOLD):
			_set_base(CHARGE_CLIP, 0.15, 1.0)
		else:
			_set_base(CHARGE_HOLD, 0.2, 1.0)
		return
	super(planar, airborne, dashing, vy, blocking)
