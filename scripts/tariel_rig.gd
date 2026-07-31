class_name TarielRig
extends Node3D

## Procedural animation for the Tariel model.
##
## The model carries no skeleton and no animation clips — it is a hierarchy of
## named joint nodes (hips -> spine -> chest -> shoulders, hips -> hip_l -> ...),
## so every pose is produced by rotating those joints. The player controller
## pushes its state in through animate() once per frame.
##
## The pose baked into the GLB is the designed idle stance: sword carried
## forward in the left hand, shield strapped across the right forearm, cape and
## panther skin hanging behind. That stance is captured on load and used as the
## base for every joint, so the authored silhouette is preserved and animation
## is layered on top of it as offsets.
##
## Angles follow the model's own axes. The model faces +Z, so a *positive* X
## rotation on a limb joint swings that limb backwards.

## Legs are the exception: the shipped pose stands in a static contrapposto,
## which would bias the walk cycle, so these joints start from their rest
## orientation (the `extras.rest` values in the source file) instead.
const NEUTRAL_LEGS := {
	"hip_l": Vector3(0.0, 0.0, 0.06),
	"thigh_l_end": Vector3(0.05, 0.0, 0.0),
	"shin_l_end": Vector3(0.0, 0.0, 0.0),
	"foot_l": Vector3(-0.05, 0.0, 0.0),
	"hip_r": Vector3(0.0, 0.0, -0.06),
	"thigh_r_end": Vector3(0.05, 0.0, 0.0),
	"shin_r_end": Vector3(0.0, 0.0, 0.0),
	"foot_r": Vector3(-0.05, 0.0, 0.0),
}

## Shield arm at rest: hanging down the right side with the shield turned out,
## which is where it sits whenever the player is not holding block. The authored
## guard — shield up and across the chest — is the captured base pose, so the
## arm blends between the two.
const SHIELD_LOWERED := {
	"shoulder_r": Vector3(0.05, 0.0, -0.14),
	"upperarm_r_end": Vector3(-0.6, 0.0, 0.0),
	"forearm_r_end": Vector3(-0.1, 0.0, 0.0),
}

enum AttackStyle {
	OVERHEAD, ## Full arm, raised over the head and chopped straight down.
	SIDE, ## Blade drawn out to the side and swung horizontally across the body.
	RISING, ## Low backhand that comes up through the target from the off side.
	THRUST, ## Straight stab, shoulder and hips driving the point forward.
}

## The shield disc's normal is its own local +Z. In the guard it points forward;
## stowed it must point straight out from the body so the shield lies flat along
## the forearm instead of cutting through the torso.
const SHIELD_OUT := Vector3(1.0, 0.0, 0.0)
## Where along the forearm the stowed shield hangs. The elbow sits at the
## forearm's origin and the wrist at y = -0.26.
const SHIELD_STOW_WRIST := Vector3(0.0, -0.24, 0.0)

const BODY_JOINTS: Array[String] = [
	"hips", "spine", "chest", "neck", "head",
	"shoulder_l", "upperarm_l_end", "forearm_l_end", "hand_l",
	"shoulder_r", "upperarm_r_end", "forearm_r_end",
	"hip_l", "thigh_l_end", "shin_l_end", "foot_l",
	"hip_r", "thigh_r_end", "shin_r_end", "foot_r",
]

## Cloth and hair chains, animated as trailing springs rather than by hand.
const CAPE_CHAIN: Array[String] = ["cape_root", "cape_j0", "cape_j1", "cape_j2", "cape_j3", "cape_j4", "cape_j5"]
const TAIL_CHAIN: Array[String] = ["tail_root", "tail_j0", "tail_j1", "tail_j2", "tail_j3", "tail_j4"]

#region Exported tuning
@export_group("Stride")
## Ground distance covered by one full two-step cycle, in metres.
@export var stride_length: float = 2.0
## Added to the stride at full speed. Without it the legs would just churn
## faster and faster, where a real runner reaches further per step.
@export var run_stride_bonus: float = 3.5
## Peak hip swing at walking pace, radians.
@export var hip_swing: float = 0.55
## Extra swing added on top once sprinting.
@export var run_hip_swing: float = 0.2
## Knee fold on the back half of the stride, radians.
@export var knee_bend: float = 0.9
## Shoulder counter-swing, radians.
@export var arm_swing: float = 0.3
## Vertical bob of the hips over a stride, metres.
@export var hip_bob: float = 0.05
## Side-to-side hip roll, radians.
@export var hip_roll: float = 0.06
## Forward lean while walking, radians. Sprinting doubles it.
@export var lean: float = 0.1

@export_group("Sprint")
## Extra forward lean once sprinting, on top of the walking lean.
@export var run_extra_lean: float = 0.3
## How much tighter the elbows are tucked while sprinting, radians.
@export var run_elbow_pump: float = 0.55
## Extra shoulder swing while sprinting, radians.
@export var run_arm_swing: float = 0.28

@export_group("Weapons")
## Replaces the sword built into the model. The grip is placed in the hand and
## the blade is aimed along the attachment point's +Y, matching the original.
@export var sword_scene: PackedScene
## Distance from the replacement sword's own origin to its grip, along its
## blade axis. The models are authored lying along -Z with the grip offset.
@export var sword_grip_offset: float = 0.28
@export var sword_scale: float = 0.85
## Twist about the blade's own length. The blade is authored lying flat, so
## without this it swings edge-up and strikes with the side of the steel.
@export var sword_roll: float = 1.5708
## Replaces the shield built into the model. Its disc lies flat in XZ, so it is
## turned to face along the attachment point's +Z like the original.
@export var shield_scene: PackedScene
@export var shield_scale: float = 0.75

@export_group("Shield")
## How far the stowed shield stands off the arm. Raise it if the plate clips
## the hip or thigh.
@export var shield_stow_clearance: float = 0.22
## Extra twist on the stowed shield, radians. Negative swings the near edge
## away from the body.
@export var shield_stow_twist: float = -1.13

@export_group("Idle")
@export var breath_rate: float = 1.5
@export var breath_amount: float = 0.025

@export_group("Actions")
@export var attack_duration: float = 0.55
## How fast the shield comes up and drops again, radians per second of blend.
@export var block_speed: float = 16.0
## How fast poses cross-fade when the movement state changes.
@export var pose_blend_speed: float = 14.0
## Forward lean while dashing, radians.
@export var dash_lean: float = 0.45

@export_group("Secondary motion")
## How quickly the cape and ponytail catch up with the body.
@export var cloth_stiffness: float = 9.0
## How far the chains trail back at full speed, radians.
@export var cloth_trail: float = 0.45
#endregion

var _joints: Dictionary = {}
var _base: Dictionary = {}
var _hips_base_y: float = 0.0

var _phase: float = 0.0
var _stride_blend: float = 0.0
var _run_blend: float = 0.0
var _air_blend: float = 0.0
var _dash_blend: float = 0.0
var _block_blend: float = 0.0
var _attack_timer: float = 0.0
## Alternates so consecutive swings chain overhead -> side -> overhead.
var _attack_style: AttackStyle = AttackStyle.SIDE

## Bumped once per swing, so a target can tell one cut from the next.
var attack_serial: int = 0
## How bloodied the blade is, 0 to 1.
var blade_blood: float = 0.0
var _sword_model: Node3D
var _attack_rng := RandomNumberGenerator.new()
var _blade_base: Node3D
var _blade_tip: Node3D

var _attack_arm: Vector4 = Vector4.ZERO
var _attack_body: Vector3 = Vector3.ZERO
## Shoulder abduction during a swing: keeps the sword arm off the ribs.
var _attack_roll: float = 0.0
## How far into the step-through the strike is, 0 to 1.
var _attack_step: float = 0.0
## True only while the blade is actually travelling, which is when it streaks.
var _attack_cutting: bool = false

var _trail: SwordTrail = null

var _roll_timer: float = 0.0
var _roll_duration: float = 0.45
## How far through the somersault we are, 0 to TAU.
var _roll_angle: float = 0.0
## How tucked the body is, peaking halfway through the roll.
var _roll_tuck: float = 0.0

var _shield: Node3D = null
var _shield_guard_basis: Basis = Basis.IDENTITY
var _shield_stow_basis: Basis = Basis.IDENTITY
## Kept aside because Basis.slerp() only accepts orthonormal bases, so the
## shield's own scale has to be reapplied after the blend.
var _shield_scale: Vector3 = Vector3.ONE
var _shield_guard_pos: Vector3 = Vector3.ZERO
var _shield_stow_pos: Vector3 = Vector3.ZERO

var _cape_angles: PackedFloat32Array = PackedFloat32Array()
var _tail_angles: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	_attack_rng.randomize()
	var wanted: Array[String] = BODY_JOINTS.duplicate()
	wanted.append_array(CAPE_CHAIN)
	wanted.append_array(TAIL_CHAIN)

	for joint_name in wanted:
		var node := find_child(joint_name, true, false) as Node3D
		if node == null:
			push_warning("TarielRig: joint '%s' is missing from the model." % joint_name)
			continue
		_joints[joint_name] = node
		# Authored stance for everything except the legs, which start neutral.
		var base: Vector3 = NEUTRAL_LEGS.get(joint_name, node.rotation)
		_base[joint_name] = base
		node.rotation = base

	_cape_angles.resize(CAPE_CHAIN.size())
	_tail_angles.resize(TAIL_CHAIN.size())

	var hips := _joints.get("hips") as Node3D
	if hips != null:
		_hips_base_y = hips.position.y

	_settle_on_ground()
	_swap_weapons()
	_setup_shield()
	_setup_trail()


## Drops the model so its boots rest on the ground plane.
##
## The legs are posed from their rest values rather than the stance baked into
## the file, and dead-straight legs reach slightly further than the bent ones
## did — enough to sink the feet through the floor. Rather than hand-tuning a
## number, measure how far under the origin the boots end up and lift by that.
func _settle_on_ground() -> void:
	var hips := _joints.get("hips") as Node3D
	if hips == null:
		return

	var lowest := INF
	for boot_name in ["boot_l", "boot_l_toe", "boot_r", "boot_r_toe"]:
		var boot := find_child(boot_name, true, false) as MeshInstance3D
		if boot == null:
			continue
		var in_rig := global_transform.affine_inverse() * boot.global_transform
		lowest = minf(lowest, (in_rig * boot.get_aabb()).position.y)

	if is_inf(lowest) or lowest >= 0.0:
		return
	_hips_base_y -= lowest
	hips.position.y = _hips_base_y


## Hides the sword and shield modelled into the character and hangs the
## replacement props off the same attachment points, so every pose, swing and
## block keeps working untouched.
func _swap_weapons() -> void:
	if sword_scene != null:
		var hand := find_child("sword", true, false) as Node3D
		if hand != null:
			_hide_meshes(hand)
			var blade: Node3D = sword_scene.instantiate()
			blade.name = "SwordModel"
			_sword_model = blade
			hand.add_child(blade)
			# Turn the blade from the model's -Z onto the mount's +Y, then slide
			# it back so the grip, not the model origin, sits in the fist.
			# Aim the blade along +Y, then roll it about that axis so the edge,
			# not the flat, faces the direction a swing travels.
			var aim := Basis(Vector3.UP, sword_roll) * Basis(Vector3.RIGHT, PI * 0.5)
			blade.transform = Transform3D(
					aim.scaled(Vector3.ONE * sword_scale),
					Vector3(0.0, sword_grip_offset * sword_scale, 0.0))

	if shield_scene != null:
		var arm := find_child("shield", true, false) as Node3D
		if arm != null:
			_hide_meshes(arm)
			var plate: Node3D = shield_scene.instantiate()
			plate.name = "ShieldModel"
			arm.add_child(plate)
			# The disc lies flat in XZ; stand it up to face along +Z.
			plate.transform = Transform3D(
					Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3.ONE * shield_scale),
					Vector3.ZERO)


func _hide_meshes(root: Node) -> void:
	for m in root.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).visible = false


## Hangs the air-cutting streak off the blade itself, so it follows whatever the
## swing does rather than being animated per attack.
func _setup_trail() -> void:
	var blade_base: Node3D
	var blade_tip: Node3D

	var mount := find_child("sword", true, false) as Node3D
	if mount != null and mount.has_node("SwordModel"):
		# Replacement blade: it runs along the mount's +Y from the grip, so the
		# ends are marked out rather than looked up by name.
		blade_base = Marker3D.new()
		blade_base.position = Vector3(0.0, 0.18 * sword_scale, 0.0)
		mount.add_child(blade_base)
		blade_tip = Marker3D.new()
		blade_tip.position = Vector3(0.0, 1.1 * sword_scale, 0.0)
		mount.add_child(blade_tip)
	else:
		blade_base = find_child("sword_guard", true, false) as Node3D
		blade_tip = find_child("blade_tip", true, false) as Node3D

	if blade_base == null or blade_tip == null:
		push_warning("TarielRig: blade ends unknown, no sword trail.")
		return
	_blade_base = blade_base
	_blade_tip = blade_tip
	_trail = SwordTrail.new()
	_trail.name = "SwordTrail"
	add_child(_trail)
	_trail.setup(blade_base, blade_tip)


## Works out where the shield sits when it is not being used as a guard.
##
## The stowed orientation is solved rather than hand-tuned: the arm is put in
## its lowered pose, and the shield is given the local rotation that makes its
## disc face straight out from the body with the disc lying along the forearm.
func _setup_shield() -> void:
	_shield = find_child("shield", true, false) as Node3D
	if _shield == null:
		return
	_shield_scale = _shield.transform.basis.get_scale()
	_shield_guard_basis = _shield.transform.basis.orthonormalized()
	_shield_guard_pos = _shield.position

	var arm := _shield.get_parent() as Node3D
	if arm == null:
		return

	# Pose the arm as it hangs, so the solve happens in the pose it is used in.
	for joint_name: String in SHIELD_LOWERED:
		_pose_joint(joint_name, (SHIELD_LOWERED[joint_name] as Vector3) - (_base[joint_name] as Vector3))
	force_update_transform()
	arm.force_update_transform()

	# Everything is resolved in the model's own frame, so the player's heading
	# never leaks into the result.
	var arm_in_model := global_transform.affine_inverse() * arm.global_transform

	# Disc normal (+Z) points out from the body; the disc's own +Y runs down the
	# arm, which leaves the plate hanging flat against it.
	var target := Basis(Vector3.DOWN.cross(SHIELD_OUT), Vector3.DOWN, SHIELD_OUT).orthonormalized()
	# A little twist about the hanging axis swings the plate's near edge clear
	# of the hip instead of leaving it flat against the leg.
	target = target.rotated(Vector3.UP, shield_stow_twist)
	_shield_stow_basis = (arm_in_model.basis.inverse() * target).orthonormalized()
	_shield_stow_pos = SHIELD_STOW_WRIST + _shield_stow_basis.z * shield_stow_clearance

	# Put the arm back the way it was found.
	for joint_name: String in SHIELD_LOWERED:
		_pose_joint(joint_name, Vector3.ZERO)


## Drives the whole rig for one frame. `speed_ratio` is 0 standing still, 1 at
## walking pace and above 1 while sprinting.
func animate(delta: float, planar_speed: float, speed_ratio: float, airborne: bool,
		dashing: bool, vertical_speed: float, blocking: bool = false) -> void:
	if _joints.is_empty():
		return

	_attack_timer = maxf(_attack_timer - delta, 0.0)

	var blend := 1.0 - exp(-pose_blend_speed * delta)
	_stride_blend = lerpf(_stride_blend, clampf(speed_ratio, 0.0, 1.0), blend)
	_run_blend = lerpf(_run_blend, clampf(speed_ratio - 1.0, 0.0, 1.0), blend)
	_air_blend = lerpf(_air_blend, 1.0 if airborne else 0.0, blend)
	_dash_blend = lerpf(_dash_blend, 1.0 if dashing else 0.0, blend)
	_block_blend = lerpf(_block_blend, 1.0 if blocking else 0.0, 1.0 - exp(-block_speed * delta))

	# One cycle per stride keeps the feet in step with the ground speed.
	var stride := stride_length + run_stride_bonus * _run_blend
	_phase = wrapf(_phase + TAU * planar_speed / maxf(stride, 0.01) * delta, 0.0, TAU)

	_roll_timer = maxf(_roll_timer - delta, 0.0)
	if _roll_timer > 0.0:
		var p := 1.0 - _roll_timer / _roll_duration
		# Eased so the somersault leaves and lands softly, and finishes on a
		# whole turn — TAU and zero are the same orientation, so there is no pop.
		_roll_angle = TAU * smoothstep(0.0, 1.0, p)
		_roll_tuck = sin(PI * p)
	else:
		_roll_angle = 0.0
		_roll_tuck = 0.0

	_update_attack()
	if _trail != null:
		_trail.emitting = _attack_cutting

	var t := Time.get_ticks_msec() / 1000.0
	_pose_legs()
	_pose_torso(t)
	_pose_arms(t)
	_pose_cloth(delta, vertical_speed)


## Starts a one-shot sword swing. Called with no argument the swings chain:
## overhead, then elbow, then overhead again. Pass an AttackStyle to force one.
func attack(style: int = -1) -> void:
	if style < 0:
		# Anything but the cut just thrown, so a flurry never repeats itself.
		var choices: Array[int] = []
		for candidate in AttackStyle.values():
			if candidate != _attack_style:
				choices.append(candidate)
		_attack_style = choices[_attack_rng.randi() % choices.size()] as AttackStyle
	else:
		_attack_style = style as AttackStyle
	_attack_timer = attack_duration
	attack_serial += 1


## The swing currently being thrown.
func current_attack_style() -> AttackStyle:
	return _attack_style


## Marks the blade as having drawn blood; it darkens as the fight goes on.
func bloody() -> void:
	blade_blood = minf(blade_blood + 0.34, 1.0)
	Blood.stain_blade(_sword_model, blade_blood)


## The blade as a world-space line segment while it is actually travelling,
## empty otherwise. Anything that wants to know what the swing hit reads this:
## the segment says *where* along the edge contact happened, which a collision
## body would not.
func get_cutting_edge() -> PackedVector3Array:
	if not _attack_cutting or _blade_base == null or _blade_tip == null:
		return PackedVector3Array()
	return PackedVector3Array([_blade_base.global_position, _blade_tip.global_position])


## Starts a forward somersault lasting `duration` seconds. Called by the
## controller when a dodge begins, so the roll and the movement stay in sync.
func dodge(duration: float) -> void:
	_roll_duration = maxf(duration, 0.05)
	_roll_timer = _roll_duration


#region Poses
func _pose_legs() -> void:
	var s := sin(_phase)
	var swing := (hip_swing + run_hip_swing * _run_blend) * _stride_blend
	var bend := knee_bend * _stride_blend

	# Airborne: stop striding and tuck instead — front knee up, back leg trailing.
	# Rolling overrides both: the legs curl into the somersault.
	var tuck := _air_blend * (1.0 - _roll_tuck)
	var ground := (1.0 - tuck) * (1.0 - _roll_tuck)
	var curl := _roll_tuck

	# A swing steps through: the shield-side leg goes forward and takes the
	# weight while the sword-side leg braces behind. Damped while already
	# striding so it does not fight the walk cycle.
	var step := _attack_step * (1.0 - 0.65 * _stride_blend)

	_pose_joint("hip_l", Vector3(swing * s * ground - 0.6 * tuck - 1.75 * curl + 0.22 * step, 0.0, 0.0))
	_pose_joint("hip_r", Vector3(-swing * s * ground + 0.25 * tuck - 1.6 * curl - 0.5 * step, 0.0, 0.0))

	# The knee only folds while its leg travels backwards, which keeps the foot
	# from scything through the ground on the return swing.
	_pose_joint("thigh_l_end", Vector3(maxf(0.0, sin(_phase - 0.7)) * bend * ground + 1.1 * tuck + 2.2 * curl, 0.0, 0.0))
	_pose_joint("thigh_r_end", Vector3(maxf(0.0, sin(_phase - 0.7 + PI)) * bend * ground + 0.45 * tuck + 2.1 * curl + 0.4 * step, 0.0, 0.0))

	# Ankles roll off the toe at the end of each push.
	_pose_joint("foot_l", Vector3(-0.22 * maxf(0.0, sin(_phase + 1.3)) * _stride_blend * ground - 0.35 * tuck, 0.0, 0.0))
	_pose_joint("foot_r", Vector3(-0.22 * maxf(0.0, sin(_phase + 1.3 + PI)) * _stride_blend * ground - 0.15 * tuck, 0.0, 0.0))


func _pose_torso(t: float) -> void:
	var hips := _joints.get("hips") as Node3D
	if hips != null:
		# Two bobs per cycle, one per footfall. The somersault drops the whole
		# body towards the ground as it goes over.
		var bob := -absf(sin(_phase)) * hip_bob * _stride_blend
		var step_drop := _attack_step * (1.0 - 0.65 * _stride_blend)
		hips.position.y = _hips_base_y + bob + 0.04 * _air_blend - 0.26 * _roll_tuck - 0.07 * step_drop
		hips.position.z = 0.14 * step_drop

	var pitch := lean * _stride_blend + run_extra_lean * _run_blend + dash_lean * _dash_blend * (1.0 - _roll_tuck)
	var breathe := sin(t * breath_rate) * breath_amount * (1.0 - _stride_blend)

	# The somersault is a full turn about the hips, so the legs come with it.
	_pose_joint("hips", Vector3(_roll_angle, _attack_body.z, sin(_phase) * hip_roll * _stride_blend))
	_pose_joint("spine", Vector3(
			pitch * 0.6 + breathe + 0.62 * _roll_tuck + _attack_body.x * 0.6,
			_attack_body.y * 0.55,
			0.0))
	_pose_joint("chest", Vector3(
			pitch * 0.4 - breathe * 0.5 + 0.45 * _roll_tuck + _attack_body.x * 0.4,
			sin(_phase) * 0.1 * _stride_blend + _attack_body.y * 0.45,
			0.0))
	# Hold the head level while the torso pitches underneath it.
	_pose_joint("neck", Vector3(-pitch * 0.5 + 0.5 * _roll_tuck, 0.0, 0.0))
	_pose_joint("head", Vector3(
			-pitch * 0.4 + breathe - _attack_body.x * 0.35,
			-sin(_phase) * 0.05 * _stride_blend - _attack_body.y * 0.45,
			0.0))


func _pose_arms(t: float) -> void:
	var s := sin(_phase)
	var swing := arm_swing * _stride_blend
	var idle_sway := sin(t * breath_rate * 0.7) * 0.03 * (1.0 - _stride_blend)

	# Sword arm: counter-swings against the left leg, and carries the attack.
	var swing_pose := _attack_arm

	# Swinging the sword arm outward keeps the blade from sweeping through the
	# shield as the shoulders counter-rotate. The authored idle stance is left
	# alone: the offset fades in with the stride.
	var sword_clearance := -0.3 * _stride_blend - 0.5 * _run_blend
	_pose_joint("shoulder_l", Vector3(
			-(swing + run_arm_swing * _run_blend) * s + idle_sway + swing_pose.x,
			swing_pose.y,
			sword_clearance + _attack_roll))
	_pose_joint("upperarm_l_end", Vector3(swing_pose.z - run_elbow_pump * 0.3 * _run_blend, 0.0, 0.0))
	_pose_joint("hand_l", Vector3(swing_pose.w, 0.0, 0.0))

	# Shield arm. The captured base pose is the guard — shield up and across the
	# chest — so it is only reached at full block. Otherwise the arm blends down
	# to its resting position with the shield hanging at the side.
	for joint_name: String in SHIELD_LOWERED:
		var lowered: Vector3 = SHIELD_LOWERED[joint_name]
		var down: Vector3 = lowered - (_base[joint_name] as Vector3)
		_pose_joint(joint_name, down * (1.0 - _block_blend))

	# A little counter-swing and dash tuck, but only while the shield is down —
	# a raised guard should stay rock steady.
	var carry := 1.0 - _block_blend
	_add_offset("shoulder_r", Vector3((swing * 0.3 * s + idle_sway) * carry - 1.1 * _roll_tuck, 0.0, 0.0))
	_add_offset("upperarm_r_end", Vector3((-0.12 * _dash_blend - run_elbow_pump * _run_blend) * carry - 1.2 * _roll_tuck, 0.0, 0.0))
	_add_offset("shoulder_l", Vector3(-1.15 * _roll_tuck, 0.0, 0.0))
	_add_offset("upperarm_l_end", Vector3(-1.3 * _roll_tuck, 0.0, 0.0))

	# The shield swings between the guard and its stowed position on the wrist,
	# where it lies edge-on along the forearm instead of through the torso.
	if _shield != null:
		_shield.transform.basis = _shield_stow_basis.slerp(_shield_guard_basis, _block_blend).scaled(_shield_scale)
		_shield.position = _shield_stow_pos.lerp(_shield_guard_pos, _block_blend)


## Rebuilds the swing pose for this frame into `_attack_arm` and `_attack_body`.
##
## A swing is a whole-body movement. Driving the arm alone is what makes a
## character look mechanical, so the torso coils away on the wind-up and unwinds
## through the strike, the hips lead the turn, and the head keeps facing the
## target while the shoulders rotate underneath it.
##
## The wrist matters just as much. Carried, the blade points forward and down
## out of the hand — right for a chop, but it makes a horizontal swing read as
## waving the arm about. The side cut rolls the wrist so the blade lies out
## along the arm and the edge leads.
func _update_attack() -> void:
	if _attack_timer <= 0.0:
		_attack_arm = Vector4.ZERO
		_attack_body = Vector3.ZERO
		_attack_roll = 0.0
		_attack_step = 0.0
		_attack_cutting = false
		return

	# arm  = (shoulder pitch, shoulder yaw, elbow, wrist roll)
	# body = (torso pitch, torso twist, hip twist)
	var wind_arm: Vector4
	var strike_arm: Vector4
	var wind_body: Vector3
	var strike_body: Vector3
	var wind_roll: float
	var strike_roll: float

	if _attack_style == AttackStyle.OVERHEAD:
		# Whole arm raised above the head, then chopped straight down, with the
		# torso rocking back and then driving the blade through.
		wind_arm = Vector4(-2.5, -0.15, -0.5, 0.0)
		strike_arm = Vector4(0.5, 0.1, 0.15, 0.0)
		wind_body = Vector3(-0.3, 0.24, 0.14)
		strike_body = Vector3(0.45, -0.2, -0.12)
		wind_roll = -0.15
		strike_roll = -0.2
	else:
		# Blade drawn out wide and swept flat across the body. Most of the reach
		# comes from the torso unwinding, not from the shoulder.
		# The shoulder is held out wide the whole way through: swept across the
		# chest at this height the upper arm would otherwise pass through the
		# ribs, and most of the reach comes from the torso anyway.
		wind_arm = Vector4(-1.25, -0.8, -0.7, 1.75)
		strike_arm = Vector4(-1.15, 0.85, 0.15, 1.95)
		wind_body = Vector3(-0.12, 0.72, 0.4)
		strike_body = Vector3(0.14, -0.85, -0.48)
		wind_roll = -0.75
		strike_roll = -0.95

	const WIND_END := 0.28
	const STRIKE_END := 0.72

	var a := 1.0 - _attack_timer / maxf(attack_duration, 0.001)
	var from_arm := Vector4.ZERO
	var to_arm := wind_arm
	var from_body := Vector3.ZERO
	var to_body := wind_body
	var from_roll := 0.0
	var to_roll := wind_roll
	var weight := 0.0

	_attack_cutting = a >= WIND_END and a < STRIKE_END + 0.1

	if a < WIND_END:
		weight = smoothstep(0.0, 1.0, a / WIND_END)
	elif a < STRIKE_END:
		# Accelerate into the hit rather than easing into it.
		from_arm = wind_arm
		to_arm = strike_arm
		from_body = wind_body
		to_body = strike_body
		from_roll = wind_roll
		to_roll = strike_roll
		weight = 1.0 - pow(1.0 - (a - WIND_END) / (STRIKE_END - WIND_END), 3.0)
	else:
		from_arm = strike_arm
		to_arm = Vector4.ZERO
		from_body = strike_body
		to_body = Vector3.ZERO
		from_roll = strike_roll
		weight = smoothstep(0.0, 1.0, (a - STRIKE_END) / (1.0 - STRIKE_END))

	_attack_arm = from_arm.lerp(to_arm, weight)
	_attack_body = from_body.lerp(to_body, weight)
	_attack_roll = lerpf(from_roll, to_roll, weight)
	# The weight goes onto the front foot as the blade comes through, then eases
	# back — a swing planted flat on both feet is what reads as robotic.
	_attack_step = sin(clampf(a, 0.0, 1.0) * PI)


func _pose_cloth(delta: float, vertical_speed: float) -> void:
	# Each link chases the one above it, so speed and falling sweep the chain
	# backwards in sequence instead of all at once.
	var drive := _stride_blend * cloth_trail + _dash_blend * 0.5 + clampf(-vertical_speed * 0.02, 0.0, 0.4)
	var flutter := sin(_phase * 2.0) * 0.06 * _stride_blend
	var weight := 1.0 - exp(-cloth_stiffness * delta)

	_chase(CAPE_CHAIN, _cape_angles, drive + flutter, weight, 1.0)
	_chase(TAIL_CHAIN, _tail_angles, drive * 0.6 + flutter, weight, 0.8)


func _chase(chain: Array[String], angles: PackedFloat32Array, drive: float,
		weight: float, scale: float) -> void:
	var last := maxf(chain.size() - 1.0, 1.0)
	for i in chain.size():
		# Links further down react later and swing a little wider.
		var link_target := drive * scale * (0.5 + 0.5 * float(i) / last)
		angles[i] = lerpf(angles[i], link_target, weight * (1.0 - 0.08 * i))
		_pose_joint(chain[i], Vector3(angles[i], 0.0, 0.0))
#endregion


## Applies an offset on top of a joint's captured base orientation.
func _pose_joint(joint_name: String, offset: Vector3) -> void:
	var node := _joints.get(joint_name) as Node3D
	if node == null:
		return
	node.rotation = _base[joint_name] + offset


## Layers a second offset on a joint that was already posed this frame.
func _add_offset(joint_name: String, offset: Vector3) -> void:
	var node := _joints.get(joint_name) as Node3D
	if node == null:
		return
	node.rotation += offset
