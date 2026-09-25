class_name SkinnedMageRig
extends SkinnedRig

## The mage: a staff, a long white beard, and bolts of lightning thrown from
## afar. The knight's rig with the magic clips Mixamo has, and the bow's
## interface — `aim_bow()` / `loose_bow()` — so the controller charges and
## casts his spell exactly as it draws and looses Avtandil's arrow.
##
## * **Charging** draws the staff back over his shoulder, as far as the charge
##   has come (the cast clip held at its wind-up), and the magic gathers at
##   the crystal as a ball of light that grows with the charge and turns from
##   gold to blue-violet when it is full — where the bolt will leave from. The
##   legs walk while he moves.
## * **Casting** is a throw with the staff: drawn back over the shoulder and
##   brought round to the front, and the bolt leaves the crystal as it comes
##   through (`cast_lead()` after the button, from `spell_origin()`) — not the
##   free hand's push the clip also has, which is why only this part of it is
##   played.
## * **Levitating** — the jump held on the way down — is Mixamo's float.
## * **Jumping** is `MG_Jump`, keyed by hand in Blender: the push off, the
##   knees driven up and the staff raised on the way up, open at the top, legs
##   reaching down and the free arm out for balance on the way down. It is not
##   played through at its own pace — how far in it is follows the body's
##   vertical speed, so the top of the clip is always the top of the jump
##   however high or long it is.
##
## Source: `~/Desktop/vepxis-art/heroes/heroes.blend` (`mage_rig`).

## Charging holds the cast clip at its wind-up: the staff drawn back.
const CHARGE_CLIP := &"MG_Cast_1H"
## How far into the cast clip the staff sits at no charge and at full charge.
const WIND_FROM := 0.3
const CAST_CLIP := &"MG_Cast_1H"
## The staff's throw in the cast clip: drawn back from here, round to the front
## by `CAST_RELEASE`, where the bolt leaves it, and settled by `CAST_TO`.
## Measured on the crystal: at 0.50 it is behind the head, at 0.70 a metre in
## front at shoulder height.
const CAST_FROM := 0.50
const CAST_RELEASE := 0.70
const CAST_TO := 0.84
const CAST_RATE := 2.0
const FLOAT_CLIP := &"MG_Float"
const JUMP_CLIP := &"MG_Jump"
## Where the crystal sits up the staff from the hand, in metres.
const CRYSTAL_UP := 0.83
## The crystal's own light at rest: the ice-blue of the stone.
const CRYSTAL_LIGHT := Color(0.45, 0.85, 1.0)

var _charge: float = 0.0
var _wind: MageWind
var _cast_left: float = 0.0
var _glow: OmniLight3D
## The charge gathering at the crystal.
var _orb: MeshInstance3D
var _orb_mat: StandardMaterial3D
var _orb_clock: float = 0.0


func _configure() -> void:
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
		&"MG_Float", &"MG_Cast_Sustained", &"MG_Block",
	]
	# A press with nothing charged is a quick shove of the staff.
	flurry = [&"MG_Cast_Sweep"]
	cut_window = {}
	run_threshold = 2.2
	max_play_rate = 2.4
	roll_share = 0.8
	cloth_enabled = false


func _ready() -> void:
	super()
	if _skel == null:
		return
	_wind = MageWind.new()
	_wind.name = "Wind"
	add_child(_wind)
	var bone := _skel.find_bone("weapon_l")
	if bone < 0:
		return
	var mount := BoneAttachment3D.new()
	mount.name = "StaffMount"
	_skel.add_child(mount)
	mount.bone_name = "weapon_l"
	var up := (_skel.get_bone_global_rest(bone).basis.inverse() * Vector3.UP).normalized()
	_glow = OmniLight3D.new()
	_glow.name = "Crystal"
	_glow.position = up * CRYSTAL_UP
	_glow.light_color = CRYSTAL_LIGHT
	_glow.omni_range = 3.0
	_glow.light_energy = 0.15
	_glow.shadow_enabled = false
	mount.add_child(_glow)
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


#region The spell, as the controller calls it (the bow's interface)
func aim_bow(draw: float, _pitch: float) -> void:
	_charge = clampf(draw, 0.0, 1.0)


func loose_bow() -> void:
	_cast_left = 0.45
	_charge = 0.0
	if _anim.has_animation(CAST_CLIP):
		_play_action(CAST_CLIP, Role.FREE, CAST_RATE, 0.08, CAST_FROM, CAST_TO)


## How long after the button the staff comes through and the bolt goes.
func cast_lead() -> float:
	if _anim == null or not _anim.has_animation(CAST_CLIP):
		return 0.0
	return _anim.get_animation(CAST_CLIP).length * (CAST_RELEASE - CAST_FROM) / CAST_RATE


## Where the bolt leaves from: the staff's crystal.
func spell_origin() -> Vector3:
	if _glow != null and _glow.is_inside_tree():
		return _glow.global_position
	return global_position + Vector3.UP * 1.6


func is_aiming() -> bool:
	return _charge > 0.05


func attack(_style: int = -1) -> void:
	attack_serial += 1
	_play_action(flurry[0], Role.FREE, 1.6, 0.06)
#endregion


func animate(delta: float, planar_speed: float, speed_ratio: float, airborne: bool,
		dashing: bool, vertical_speed: float, blocking: bool = false) -> void:
	if _anim == null:
		return
	_cast_left = maxf(_cast_left - delta, 0.0)
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
		# Held, not played: the staff comes back as the charge builds.
		_set_base(CHARGE_CLIP, 0.15, 0.0)
		var length := _anim.get_animation(CHARGE_CLIP).length
		_anim.seek(length * lerpf(WIND_FROM, CAST_FROM, _charge), false)
		return
	super(planar, airborne, dashing, vy, blocking)
