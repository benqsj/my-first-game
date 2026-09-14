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
##
## On top of that sits a second source of movement: AnimRetarget replays hand
## authored clips from the Quaternius animation library on the same joints. The
## two are blended per joint rather than switched between, so a sword swing can
## be thrown mid-stride without the legs losing the walk cycle. Locomotion stays
## procedural because the library ships no idle, walk or run.

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
	"shoulder_r", "upperarm_r_end", "forearm_r_end", "hand_r",
	"hip_l", "thigh_l_end", "shin_l_end", "foot_l",
	"hip_r", "thigh_r_end", "shin_r_end", "foot_r",
]

## Cloth and hair chains, animated as trailing springs rather than by hand.
const CAPE_CHAIN: Array[String] = ["cape_root", "cape_j0", "cape_j1", "cape_j2", "cape_j3", "cape_j4", "cape_j5"]
const TAIL_CHAIN: Array[String] = ["tail_root", "tail_j0", "tail_j1", "tail_j2", "tail_j3", "tail_j4"]

#region Library clips
## Sword swings taken from the animation library, thrown in turn so a flurry
## never repeats the same cut.
const SWING_CLIPS: Array[StringName] = [&"Sword_Regular_A", &"Sword_Regular_B", &"Sword_Regular_C"]
const CLIP_JUMP := &"NinjaJump_Start"
const CLIP_FALL := &"NinjaJump_Idle"
const CLIP_LAND := &"NinjaJump_Land"
const CLIP_HIT := &"Hit_Knockback"
## The library's own evade, used by the double-tapped dodge. The single-press
## roll stays procedural — see dodge().
const CLIP_DODGE := &"Sword_Dash"
const CLIP_SLIDE_IN := &"Slide_Start"
const CLIP_SLIDE := &"Slide"
const CLIP_SLIDE_OUT := &"Slide_Exit"
const CLIP_CLIMB := &"ClimbUp_1m"
#endregion

#region Exported tuning
@export_group("Stride")
## Ground distance covered by one full two-step cycle, in metres.
@export var stride_length: float = 2.0
## Added to the stride at full speed. Without it the legs would just churn
## faster and faster, where a real runner reaches further per step. Too much of
## it and the opposite happens: the cadence drops below what a sprint looks
## like, and the feet have to skate to cover the ground between footfalls.
@export var run_stride_bonus: float = 2.2
## Shoulder counter-swing, radians.
@export var arm_swing: float = 0.3
## Vertical bob of the hips over a stride, metres.
@export var hip_bob: float = 0.05
## Side-to-side hip roll, radians.
@export var hip_roll: float = 0.06
## Forward lean while walking, radians. Sprinting doubles it.
@export var lean: float = 0.1

## How far the foot is picked up over the swing, in metres. A walk barely
## clears the ground; a run lifts the heel most of the way to the hip.
@export var foot_lift: float = 0.1
@export var run_foot_lift: float = 0.32
## Share of the cycle each foot spends on the ground. A walk keeps a foot down
## most of the time; a run is mostly flight, which is what gives it its bounce.
@export_range(0.15, 0.9) var walk_duty: float = 0.62
@export_range(0.1, 0.9) var run_duty: float = 0.34
## How far in front of and behind the hip the foot may be planted, as a fraction
## of the leg's own length. Real stride length comes from the flight phase, not
## from reaching further — past this the foot would have to skate to keep up.
@export_range(0.2, 0.9) var foot_reach: float = 0.48
## Pelvis twist about the spine over a stride, radians. The shoulders already
## counter-rotate above it, so this is what stops the torso reading as one piece.
@export var hip_yaw: float = 0.09
## How far the thighs are drawn in towards the centre line at a sprint. Runners
## plant close to one line; walkers plant under their hips.
@export var run_adduction: float = 0.07

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
## How far the cape is held off the back even at a standstill, radians. Zero
## lets it settle into the mail skirt, which flares wider than it does.
@export var cape_rest_flare: float = 0.16

@export_group("Crouch")
## How far the knees fold, radians. The library ships no crouch of any kind, so
## this one is built here. The hips are then dropped by exactly as much as the
## folded legs shorten, so the boots stay on the ground without a second number
## that has to be kept in step with this one.
@export var crouch_knee: float = 1.9
## Hip flexion as a fraction of the knee fold. Much below a half and the body
## pitches forward onto its face; much above and it sits back on its heels.
@export var crouch_hip_ratio: float = 0.53
## Forward lean of the torso while crouched, radians.
@export var crouch_lean: float = 0.3
## How much of the stride survives a crouch-walk: creeping takes short steps.
## It shortens the stride itself rather than just the swing of the legs, so the
## cadence rises to make up the ground and the feet stay planted.
@export_range(0.1, 1.0) var crouch_stride_scale: float = 0.55
## How fast the body drops into and out of it.
@export var crouch_blend_speed: float = 11.0

@export_group("Wall climb")
## Metres of face covered by one full hand-over-hand cycle.
@export var climb_cycle: float = 1.3
## How fast the body settles into and out of the climbing pose.
@export var climb_blend_speed: float = 8.0
## How far the chest is pressed in towards the face, radians.
@export var climb_hug: float = 0.22
## How far each arm swings between its high reach and its low pull, radians.
@export var climb_reach: float = 0.45
## How far the model is slid towards the face it is holding, in metres. The
## capsule the controller moves is a good deal fatter than the body drawn inside
## it, so without this the hands grip thin air a hand's width off the wall.
@export var climb_close: float = 0.26

@export_group("Clips")
## Swing the sword with the library's clips rather than the procedural poses.
## Off falls back to the hand-written swings, which is also what happens on any
## model the library cannot be fitted to.
@export var use_clip_swings: bool = true
## Take off, fall and land on the library's clips.
@export var use_clip_jumps: bool = true
## The library's take-off and landing are both long, deliberate beats — nearly a
## second each — so they are stretched to fit a jump instead of outlasting it.
@export var takeoff_duration: float = 0.4
@export var landing_duration: float = 0.5
## The library's forward cycle, played on the legs alone and retimed to whatever
## the ground speed is. Empty falls back to the procedural stride entirely.
@export var walk_clip: StringName = &"Walk_Carry"
## How much of the walk cycle survives at a full sprint. The clip swings a
## walk's legs, and a sprint reaches much further per step, so most of the
## sprint has to come from the procedural stride — the Standard library ships no
## run cycle, and a walk played faster does not become one.
@export_range(0.0, 1.0) var walk_clip_sprint_share: float = 0.25
## How long a clip takes to fade in over the procedural pose, and out again.
@export var clip_fade_in: float = 0.09
@export var clip_fade_out: float = 0.16
#endregion

var _joints: Dictionary = {}
var _base: Dictionary = {}
## This frame's procedural orientation for every joint, as an Euler triple.
## Filled by the pose functions and only written to the nodes in _apply_pose(),
## which is where the clip blend happens.
var _pose: Dictionary = {}
var _hips_base_y: float = 0.0
## Orientation of whatever the hips hang off, needed to walk the joint chain
## down in model space while blending.
var _root_basis: Basis = Basis.IDENTITY
## Scratch space for that walk, kept between frames so posing the model does not
## allocate a dictionary sixty times a second.
var _model_basis: Dictionary = {}

var _phase: float = 0.0
## Metres of ground one full cycle of the stride covers, this frame. The phase
## and the foot paths are both hung off it, which is what keeps them agreeing.
var _stride_span: float = 2.0
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

## What the clip currently faded in is doing, so the rig knows when the blade is
## live and what should follow when the clip runs out.
enum ClipRole { NONE, SWING, TAKEOFF, FALL, LAND, HIT, SLIDE_IN, SLIDE, SLIDE_OUT, DODGE, CLIMB, FREE }

## One-shots — swings, jumps, the slide, the pull-up. Owns the whole body while
## it plays, unless masked.
var _action: AnimRetarget = null
## The walk cycle, on its own layer so that a swing thrown mid-stride is laid
## over legs that are still walking rather than replacing them.
var _gait: AnimRetarget = null
## Metres of ground one cycle of `walk_clip` covers on this body, measured from
## the clip at load. Zero means the cycle is unusable and the procedural stride
## carries everything.
var _gait_stride: float = 0.0

## Normalised slice of each swing clip over which the blade is actually
## travelling, measured from the clip at load rather than guessed at.
var _swing_windows: Array[Vector2] = []
var _swing_slot: int = -1
var _clip_role: ClipRole = ClipRole.NONE
## The travelling window of the swing being played, empty when it is not one.
var _clip_window: Vector2 = Vector2.ZERO
## Latched so the take-off and landing clips fire on the transition rather than
## every frame the player spends in the air.
var _was_airborne: bool = false
var _crouching: bool = false
var _crouch_blend: float = 0.0
## Thigh and shin lengths, read off the model so the crouch can work out how far
## the hips have to come down for the boots to stay put, and so the stride can
## be solved from where the feet go rather than from angles typed in by hand.
var _thigh_length: float = 0.0
var _shin_length: float = 0.0
## How far the hips were lifted or dropped this frame, so the leg solver can
## take it back off the foot targets and leave the planted foot where it is.
var _hips_rise: float = 0.0

var _wall_climbing: bool = false
var _climb_blend: float = 0.0
var _climb_phase: float = 0.0
## Smoothed climbing input from the controller: x along the face, y up it.
var _climb_drive: Vector2 = Vector2.ZERO
## How fast the body is travelling over the face, in m/s.
var _climb_speed: float = 0.0


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

	var knee := _joints.get("thigh_l_end") as Node3D
	var ankle := _joints.get("shin_l_end") as Node3D
	if knee != null and ankle != null:
		_thigh_length = knee.position.length()
		_shin_length = ankle.position.length()

	_settle_on_ground()
	_swap_weapons()
	_setup_shield()
	_setup_trail()
	_setup_layers()


## Hangs the animation library off the rig and works out, once, how each of its
## joints has to be turned to carry a mannequin pose. Everything keeps working
## without it — the procedural poses are the fallback, not a stopgap.
func _setup_layers() -> void:
	var hips := _joints.get("hips") as Node3D
	if hips == null or hips.get_parent() == null:
		return
	_root_basis = (global_transform.affine_inverse()
			* (hips.get_parent() as Node3D).global_transform).basis.orthonormalized()

	# The clips are measured against a plain standing pose, so the shield arm is
	# taken as hanging rather than in the authored guard, matching the legs.
	var neutral := {}
	for joint_name in AnimRetarget.JOINT_ORDER:
		neutral[joint_name] = SHIELD_LOWERED.get(joint_name, _base.get(joint_name, Vector3.ZERO))

	_action = _make_layer("Actions", neutral)
	if _action == null:
		return
	_action.clip_finished.connect(_on_clip_finished)
	for clip in SWING_CLIPS:
		_swing_windows.append(_action.measure_travel(clip, "hand_l"))

	# A second copy of the library, because the walk has to keep running
	# underneath whatever one-shot is playing over it. One mixer cannot do that.
	if walk_clip.is_empty():
		return
	_gait = _make_layer("Gait", neutral)
	if _gait == null:
		return
	_gait_stride = _gait.measure_stride(walk_clip)
	if _gait_stride <= 0.01:
		push_warning("TarielRig: '%s' has no usable stride, keeping the procedural walk."
				% walk_clip)
		_gait.queue_free()
		_gait = null


func _make_layer(layer_name: String, neutral: Dictionary) -> AnimRetarget:
	var layer := AnimRetarget.new()
	layer.name = layer_name
	add_child(layer)
	if layer.setup(self, _joints, neutral):
		return layer
	layer.queue_free()
	return null


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
	# Written straight onto the nodes rather than through _pose_joint(), which
	# only fills the frame's pose table and does not touch the model.
	for joint_name: String in SHIELD_LOWERED:
		(_joints[joint_name] as Node3D).rotation = SHIELD_LOWERED[joint_name]
	force_update_transform()
	for joint_name in ["shoulder_r", "upperarm_r_end", "forearm_r_end"]:
		(_joints[joint_name] as Node3D).force_update_transform()
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
		(_joints[joint_name] as Node3D).rotation = _base[joint_name]


## Drives the whole rig for one frame. `speed_ratio` is 0 standing still, 1 at
## walking pace and above 1 while sprinting.
func animate(delta: float, planar_speed: float, speed_ratio: float, airborne: bool,
		dashing: bool, vertical_speed: float, blocking: bool = false) -> void:
	if _joints.is_empty():
		return

	if _action != null:
		_action.advance(delta)
		if _wall_climbing:
			# Hanging off a wall is not falling, whatever the controller's floor
			# check says. Latching the flag keeps the landing clip from firing on
			# the grab and leaves it armed for whenever the body lets go.
			_was_airborne = airborne
		else:
			_track_airborne(airborne, vertical_speed)
			_release_landing()

	_attack_timer = maxf(_attack_timer - delta, 0.0)

	var blend := 1.0 - exp(-pose_blend_speed * delta)
	_stride_blend = lerpf(_stride_blend, clampf(speed_ratio, 0.0, 1.0), blend)
	_run_blend = lerpf(_run_blend, clampf(speed_ratio - 1.0, 0.0, 1.0), blend)
	_air_blend = lerpf(_air_blend, 1.0 if airborne else 0.0, blend)
	_dash_blend = lerpf(_dash_blend, 1.0 if dashing else 0.0, blend)
	_block_blend = lerpf(_block_blend, 1.0 if blocking else 0.0, 1.0 - exp(-block_speed * delta))
	_crouch_blend = lerpf(_crouch_blend, 1.0 if _crouching and not airborne else 0.0,
			1.0 - exp(-crouch_blend_speed * delta))
	_climb_blend = lerpf(_climb_blend, 1.0 if _wall_climbing else 0.0,
			1.0 - exp(-climb_blend_speed * delta))

	# One cycle per stride keeps the feet in step with the ground speed. How long
	# that stride is has to answer to the gait as well as the pace: dawdling and
	# creeping both take shorter steps, and a stride that stayed long through
	# either would leave the feet sliding to cover ground the legs never crossed.
	_stride_span = maxf((stride_length + run_stride_bonus * _run_blend)
			* lerpf(0.6, 1.0, _stride_blend)
			* lerpf(1.0, crouch_stride_scale, _crouch_blend), 0.3)
	_phase = wrapf(_phase + TAU * planar_speed / _stride_span * delta, 0.0, TAU)
	# After the phase, which is what the walk cycle is hung off.
	_drive_gait(delta, planar_speed, airborne)

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

	# One reach per `climb_cycle` of face covered, so the hands keep up with the
	# body however fast it is going up.
	_climb_phase = wrapf(_climb_phase + TAU * _climb_speed * delta / maxf(climb_cycle, 0.05),
			0.0, TAU)

	var t := Time.get_ticks_msec() / 1000.0
	# Legs first: how far the hips have to come down for the feet to stay on the
	# ground is worked out there, and the torso hangs off the answer.
	_pose_legs()
	_pose_torso(t)
	_pose_arms(t)
	_pose_climb()
	_pose_cloth(delta, vertical_speed)
	_apply_pose()


## Starts a one-shot sword swing.
##
## With the animation library loaded the cuts come from it, taken in turn so a
## flurry never repeats itself; at a run only the upper body is handed over so
## the legs keep striding underneath. Passing an AttackStyle forces one of the
## procedural swings instead, which is also what happens with no library.
func attack(style: int = -1) -> void:
	attack_serial += 1

	if style < 0 and use_clip_swings and not _swing_windows.is_empty():
		_swing_slot = (_swing_slot + 1) % SWING_CLIPS.size()
		var running := _stride_blend > 0.35
		if _play_clip(SWING_CLIPS[_swing_slot], ClipRole.SWING, clip_fade_in, 1.0,
				AnimRetarget.Mask.UPPER if running else AnimRetarget.Mask.FULL):
			_clip_window = _swing_windows[_swing_slot]
			_attack_timer = 0.0
			return

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


## The procedural swing currently being thrown. Meaningless while a clip is
## driving the cut — use current_swing() to tell one swing from the next.
func current_attack_style() -> AttackStyle:
	return _attack_style


## Which cut is being thrown, named. A clip reports itself, a procedural swing
## reports its style, so anything counting a combo or checking that a flurry
## varies works the same either way.
func current_swing() -> StringName:
	if _clip_role == ClipRole.SWING:
		return _action.current_clip()
	return StringName(AttackStyle.keys()[_attack_style])


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
##
## Deliberately still procedural: this is the one the dash button throws on a
## single press, and the library's evades run over a second — squeezing one into
## a 0.45s roll only makes it flicker.
func dodge(duration: float) -> void:
	_roll_duration = maxf(duration, 0.05)
	_roll_timer = _roll_duration


## The library's own evade, for the double-tapped dodge, which is given room to
## run at something near the speed it was authored at. Stretched to whatever the
## controller allows so the movement and the animation finish together.
func dodge_clip(duration: float) -> bool:
	var length := _action.clip_length(CLIP_DODGE) if _action != null else 0.0
	if length <= 0.0:
		return false
	# The roll must not still be turning the body over underneath the clip.
	_roll_timer = 0.0
	return _play_clip(CLIP_DODGE, ClipRole.DODGE, 0.06, length / maxf(duration, 0.05))


#region Clips
## Takes the flinch when something lands a hit.
func hit() -> void:
	_play_clip(CLIP_HIT, ClipRole.HIT, 0.05)


## Drops into or comes out of a crouch, and stays there for as long as `down`
## does.
##
## Built by hand rather than played, because the library has no crouch of any
## kind — and a hand-built one keeps the walk cycle underneath it, so creeping
## forward is the same stride, only lower and shorter.
func crouch(down: bool) -> void:
	_crouching = down


## Whether the body is far enough down for the crouch to be worth anything.
func is_crouched() -> bool:
	return _crouch_blend > 0.5


## Metres of ground one full cycle of the stride is covering right now. Read by
## tooling that wants to sample exactly one cycle; the gait itself keeps it.
func stride_span() -> float:
	return _stride_span


## Throws the body into a slide, or lets it back out of one. Unlike the crouch
## this *is* a clip: sliding is the one thing the library covers.
func slide(active: bool) -> void:
	if active:
		_play_clip(CLIP_SLIDE_IN, ClipRole.SLIDE_IN, clip_fade_in)
	elif _clip_role in [ClipRole.SLIDE_IN, ClipRole.SLIDE]:
		_play_clip(CLIP_SLIDE_OUT, ClipRole.SLIDE_OUT, clip_fade_in)


## Takes hold of a wall, or lets go of it.
##
## Procedural, like the crouch and for the same reason: the library ships a
## one-metre mantle and nothing else that touches a vertical face. Unlike a
## clip, this also has to hold any pose between "hanging still" and "climbing
## flat out sideways", which is what the drive from the controller decides.
func wall_climb(active: bool) -> void:
	if active == _wall_climbing:
		return
	_wall_climbing = active
	# Letting go stops the reaching as well: the controller only feeds the drive
	# in while the body is actually on a wall.
	_climb_drive = Vector2.ZERO
	_climb_speed = 0.0
	if not active:
		return
	_climb_phase = 0.0
	# Nothing that was playing means anything on a wall.
	if _action != null:
		_action.stop(0.12)
	if _gait != null:
		_gait.stop(0.12)


## How the body is working its way along the face this frame: `drive` is the
## stick in the wall's own frame (x sideways, y up), `speed` how fast the body
## is actually travelling, which is what paces the reaches.
func climb_drive(drive: Vector2, speed: float) -> void:
	_climb_drive = drive
	_climb_speed = speed


## True once the body is far enough into the climbing pose to read as being on
## the wall rather than in front of it.
func is_wall_climbing() -> bool:
	return _climb_blend > 0.5


## Hauls the body over a ledge. `duration` stretches the clip to however long
## the controller is taking to move it, so the hands stay on the lip.
func climb(duration: float) -> void:
	var length := _action.clip_length(CLIP_CLIMB) if _action != null else 0.0
	var speed := length / maxf(duration, 0.05) if length > 0.0 else 1.0
	_play_clip(CLIP_CLIMB, ClipRole.CLIMB, 0.06, speed)


## Plays any clip from the library by name, full body, until it ends. Nothing in
## the controller needs this — it is here so the whole library can be previewed
## and so one-off scripted beats do not need a new entry point each time.
func play_clip(clip: StringName, fade: float = -1.0, speed: float = 1.0) -> bool:
	return _play_clip(clip, ClipRole.FREE, clip_fade_in if fade < 0.0 else fade, speed)


## Freezes one frame of a clip, `through` being how far into it to stop. For
## tooling only — it holds the pose until something else plays.
func hold_clip(clip: StringName, through: float) -> bool:
	if _action == null or not _action.hold(clip, through):
		return false
	_clip_role = ClipRole.FREE
	_clip_window = Vector2.ZERO
	return true


## The one-shot playing over the body right now, empty when the procedural pose
## and the walk cycle have it to themselves.
func current_clip() -> StringName:
	return _action.current_clip() if _action != null else &""


## Everything the library has to offer, for tooling.
func clip_names() -> PackedStringArray:
	return _action.clip_names() if _action != null else PackedStringArray()


## True once the animation library has been fitted to the model. False means
## every pose is the procedural one.
func has_clips() -> bool:
	return _action != null


func _play_clip(clip: StringName, role: ClipRole, fade: float, speed: float = 1.0,
		mask: AnimRetarget.Mask = AnimRetarget.Mask.FULL) -> bool:
	if _action == null or not _action.play(clip, fade, speed, mask):
		return false
	_clip_role = role
	_clip_window = Vector2.ZERO
	return true


## Fires the take-off, fall and landing clips off the controller's own airborne
## flag, so jumping needs nothing wired up on the controller side.
func _track_airborne(airborne: bool, vertical_speed: float) -> void:
	if airborne == _was_airborne:
		# A take-off that ends while still in the air hands over to the fall loop.
		if airborne and _clip_role == ClipRole.NONE and use_clip_jumps:
			_play_clip(CLIP_FALL, ClipRole.FALL, 0.14)
		return
	_was_airborne = airborne

	if not use_clip_jumps or _clip_role in [ClipRole.SWING, ClipRole.CLIMB, ClipRole.DODGE]:
		return
	if airborne:
		# Stepping off a ledge is a fall, not a jump; only an upward push is one.
		if vertical_speed > 1.0:
			_play_clip(CLIP_JUMP, ClipRole.TAKEOFF, 0.06, _fit(CLIP_JUMP, takeoff_duration))
		else:
			_play_clip(CLIP_FALL, ClipRole.FALL, 0.16)
	else:
		_play_clip(CLIP_LAND, ClipRole.LAND, 0.05, _fit(CLIP_LAND, landing_duration))


## Playback rate that makes `clip` last `seconds`.
func _fit(clip: StringName, seconds: float) -> float:
	var length := _action.clip_length(clip) if _action != null else 0.0
	return length / maxf(seconds, 0.05) if length > 0.0 else 1.0


## How far the hips have to come down for the folded legs to leave the boots
## where they were.
##
## Solved from the leg the model actually has rather than dialled in by hand: a
## depth typed in beside the knee angle drifts out of step with it the moment
## either is touched, and the feet start floating or sinking.
func _crouch_sink() -> float:
	if _crouch_blend <= 0.001 or _thigh_length <= 0.0:
		return 0.0
	var knee := crouch_knee * _crouch_blend
	var thigh := -knee * crouch_hip_ratio
	var standing := _thigh_length + _shin_length
	return standing - (_thigh_length * cos(thigh) + _shin_length * cos(thigh + knee))


## What the two clip layers between them want done to the hips. A full-body
## action — a jump, a slide — takes the walk cycle's own weight shift with it.
func _clip_hips_offset() -> Vector3:
	var shift := Vector3.ZERO
	if _gait != null:
		var taken: float = _action.joint_weight("hips") if _action != null else 0.0
		shift += _gait.hips_offset() * (1.0 - taken)
	if _action != null:
		shift += _action.hips_offset()
	return shift


## Lays the library's walk cycle over the legs, in step with the ground.
##
## The cycle is *seeked* from the procedural stride phase rather than played at
## a speed of its own. The library's only forward cycle is a slow carrying walk
## — 1.3 m of ground per two-second cycle — so at this game's pace playing it
## straight would blur the legs, and slowing it down would skate the feet.
## Borrowing the phase sidesteps both: the phase is already one cycle per stride
## of ground covered, whatever the speed.
##
## What the borrowed phase cannot fix is amplitude. The clip swings a walk's
## legs, and a sprint reaches much further per step, so the clip's share is
## wound down as the pace rises and the procedural stride — which lengthens with
## speed — takes the difference.
func _drive_gait(delta: float, planar_speed: float, airborne: bool) -> void:
	if _gait == null:
		return

	var moving := smoothstep(0.2, 0.9, planar_speed)
	var upright := 0.0 if airborne or _roll_timer > 0.0 else 1.0 - _crouch_blend
	var pace := lerpf(1.0, walk_clip_sprint_share, _run_blend)
	var wanted := moving * upright * pace

	if wanted <= 0.001:
		_gait.stop(0.14)
	else:
		if _gait.loaded_clip() != walk_clip:
			_gait.play(walk_clip, 0.14, 1.0, AnimRetarget.Mask.LOWER, wanted)
		else:
			_gait.blend_to(wanted, 0.14)
		_gait.seek_ratio(_phase / TAU)

	# Last, so the pose read out is the one the seek above just set.
	_gait.advance(delta)
	if wanted <= 0.001 and _gait.weight() <= 0.001:
		_gait.halt()


## The landing clip is a full stop — knees deep, weight settling over a second —
## and holding it while the player has already run off reads as skating. Moving
## cuts it short.
func _release_landing() -> void:
	if _clip_role != ClipRole.LAND or _stride_blend < 0.15:
		return
	# The impact beat is worth keeping even when running out of the landing;
	# it is the long settle afterwards that has to go.
	if _action.clip_progress() < 0.35:
		return
	_clip_role = ClipRole.NONE
	_clip_window = Vector2.ZERO
	_action.stop(0.1)


func _on_clip_finished(_clip: StringName) -> void:
	match _clip_role:
		ClipRole.SLIDE_IN:
			if _play_clip(CLIP_SLIDE, ClipRole.SLIDE, 0.1):
				return
		ClipRole.TAKEOFF:
			if _was_airborne and _play_clip(CLIP_FALL, ClipRole.FALL, 0.12):
				return
	# Held poses — the slide and the fall — loop, so they never arrive here;
	# they are ended by slide(false) or by touching the ground.
	_clip_role = ClipRole.NONE
	_clip_window = Vector2.ZERO
	if _action != null:
		_action.stop(clip_fade_out)
#endregion


#region Poses
## Poses the legs from where the feet have to be, rather than by swinging the
## joints and hoping the feet land somewhere sensible.
##
## Each foot is given a path — planted, with the body travelling over it, then
## picked up, carried through and set back down — and the hip, knee and ankle
## are solved from it. That is what a stride actually is: the ground holds the
## foot still while the body moves past. Sines on the joints cannot say that,
## which is why the old cycle had to stop the knee scything through the floor by
## hand and why its feet skated at a run.
##
## Everything that gives the gait its character then falls out of two numbers
## that mean something — how long the foot stays down and how far it is picked
## up — instead of half a dozen amplitudes that have to be balanced against each
## other by eye.
func _pose_legs() -> void:
	# Airborne: stop striding and tuck instead — front knee up, back leg trailing.
	# Rolling overrides both: the legs curl into the somersault.
	var tuck := _air_blend * (1.0 - _roll_tuck)
	var ground := (1.0 - tuck) * (1.0 - _roll_tuck)
	var curl := _roll_tuck
	# How much stride there is at all. The *length* of it is already in
	# `_stride_span`; this only closes the cycle down to a standing pose when
	# there is nothing to stride about.
	var amount := smoothstep(0.0, 0.22, _stride_blend) * ground

	# A swing steps through: the shield-side leg goes forward and takes the
	# weight while the sword-side leg braces behind. Damped while already
	# striding so it does not fight the walk cycle.
	var step := _attack_step * (1.0 - 0.65 * _stride_blend)

	# The crouch folds both legs the same way underneath everything else, so a
	# crouch-walk is still a walk, only lower.
	var knee := crouch_knee * _crouch_blend * ground
	var thigh := -knee * crouch_hip_ratio
	var ankle := -(thigh + knee)

	var leg := _thigh_length + _shin_length
	var stride := _stride_span
	var duty := lerpf(walk_duty, run_duty, _run_blend)
	var lift := lerpf(foot_lift, run_foot_lift, _run_blend) * amount
	# A walker sets the foot down well in front and pushes off behind; a runner
	# lands much closer to underneath and drives much further back. The two
	# always add to two, so the ground a stance covers is `half` either way.
	var bias := Vector2(1.0 - 0.5 * _run_blend, 1.0 + 0.5 * _run_blend)
	# A foot can only be planted as far out as the leg reaches — measured against
	# the far end of the stance, which is the one that asks for the most. Stride
	# beyond that has to come out of the flight phase, which is exactly how a run
	# lengthens in the first place, and why a sprinter's foot is on the ground
	# for a fraction of the time a walker's is.
	var half := minf(stride * duty * 0.5, leg * foot_reach / bias.y) * amount
	# Contact then lasts exactly as long as the foot stays put — the ground the
	# body covers in that time and the ground the foot gives back are the same
	# number, which is what it means for a foot not to skate.
	duty = clampf(2.0 * half / stride, minf(0.12, duty), duty)

	var left := _foot_track(_phase, duty, half, lift, bias)
	var right := _foot_track(_phase + PI, duty, half, lift, bias)

	# The hips come down by whatever the spread legs ask for, so the planted foot
	# stays where it was put instead of being dragged off the ground. That single
	# rule is what dips the body at a walk's double support and floats it through
	# a run's flight, with neither animated by hand.
	var own_legs := 1.0 - (_gait.weight() if _gait != null else 0.0)
	var dip := maxf(_hip_drop(left, leg), _hip_drop(right, leg))
	# A run also sinks through its stance, absorbing the landing. A walk does not.
	dip += hip_bob * _run_blend * amount * (0.5 + 0.5 * cos(2.0 * _phase))
	_hips_rise = -dip * own_legs

	# The authored pelvis is pitched forward, and the somersault turns it right
	# over. Feet belong to the ground rather than to the pelvis, so the targets
	# are turned back out of whatever it is doing before they are solved.
	var pelvis := (_base.get("hips", Vector3.ZERO) as Vector3).x + _roll_angle
	var solved_l := _solve_leg(left, leg, amount, pelvis)
	var solved_r := _solve_leg(right, leg, amount, pelvis)
	# Runners plant close to one line; walkers plant under their hips.
	var adduct := run_adduction * _run_blend * amount

	_pose_joint("hip_l", Vector3(
			solved_l.x - 0.6 * tuck - 1.75 * curl + 0.22 * step + thigh, 0.0, adduct))
	_pose_joint("hip_r", Vector3(
			solved_r.x + 0.25 * tuck - 1.6 * curl - 0.5 * step + thigh, 0.0, -adduct))
	_pose_joint("thigh_l_end", Vector3(
			solved_l.y + 1.1 * tuck + 2.2 * curl + knee, 0.0, 0.0))
	_pose_joint("thigh_r_end", Vector3(
			solved_r.y + 0.45 * tuck + 2.1 * curl + 0.4 * step + knee, 0.0, 0.0))
	# The ankles hold whatever the solve asked of them, on top of whatever the
	# crouch did to the leg above.
	_pose_joint("foot_l", Vector3(solved_l.z - 0.35 * tuck + ankle, 0.0, 0.0))
	_pose_joint("foot_r", Vector3(solved_r.z - 0.15 * tuck + ankle, 0.0, 0.0))


## Where one foot is this frame: how far ahead of the hip it sits, how far off
## the ground it is, and how the sole is tilted. All three in the model's own
## frame, distances in metres. `bias` splits the stance into how far the foot
## reaches in front and how far it drives behind.
func _foot_track(phase: float, duty: float, half: float, lift: float, bias: Vector2) -> Vector3:
	# Mid-stance sits at phase zero, where the foot passes under the hip — the
	# same neutral the old cycle had, so the library's walk cycle still lines up
	# when it is blended over the top of this one.
	var u := wrapf(phase / TAU + duty * 0.5, 0.0, 1.0)
	var front := bias.x
	var back := bias.y

	if u < duty:
		# Stance. The foot is on the ground, so every bit of movement here is the
		# hip travelling past it.
		var t := u / maxf(duty, 0.001)
		# The heel comes off at the end and the body rolls out over the toe,
		# which lifts the ankle although the foot has not left the ground.
		var off := smoothstep(0.65, 1.0, t)
		var strike := -0.16 * (1.0 - _run_blend) * (1.0 - smoothstep(0.0, 0.22, t))
		return Vector3(
				half * (front - t * (front + back)),
				0.3 * lift * off,
				strike + 0.55 * off)

	# Swing. The knee folds on its own here: the ankle is carried nearer the hip
	# than a straight leg would reach, and the solve has nowhere else to put it.
	var t := (u - duty) / maxf(1.0 - duty, 0.001)
	return Vector3(
			lerpf(-half * back, half * front, smoothstep(0.0, 1.0, t)),
			lift * (0.3 * (1.0 - smoothstep(0.0, 0.3, t)) + sin(PI * pow(t, 0.85))),
			# Toe still down off the push, up to clear the ground, and level
			# again — or heel first at a walk — to land.
			0.45 * (1.0 - smoothstep(0.0, 0.35, t))
					- 0.3 * smoothstep(0.05, 0.4, t)
					+ (0.3 - 0.16 * (1.0 - _run_blend)) * smoothstep(0.45, 1.0, t))


## How far the hip has to drop before a straight leg could reach `track`. Zero
## whenever the foot is already inside the leg's reach, which is most of the
## cycle: only the ends of a stance actually ask for anything.
static func _hip_drop(track: Vector3, leg: float) -> float:
	var span := leg * leg - track.x * track.x
	if span <= 0.0:
		return leg
	return maxf(leg - track.y - sqrt(span), 0.0)


## Hip, knee and ankle angles that put the foot on `track`, as offsets from the
## straight-legged rest pose — so a stride of no amplitude leaves the model
## standing exactly as it was authored.
##
## Two bones and a target is a triangle, so the knee comes straight out of the
## law of cosines rather than out of a curve shaped by hand.
func _solve_leg(track: Vector3, leg: float, amount: float, pelvis: float) -> Vector3:
	if leg <= 0.0 or amount <= 0.001 or _thigh_length <= 0.0 or _shin_length <= 0.0:
		return Vector3.ZERO

	# The hips have already been dropped by `dip`, so the foot sits that much
	# higher relative to the joint the leg hangs from. The pelvis tilt is faded
	# in with the stride, so a body standing still keeps the stance it was
	# authored in rather than snapping out of it the moment it moves.
	var tilt := pelvis * amount
	var target := Vector3(0.0, -leg - _hips_rise + track.y, track.x).rotated(Vector3.RIGHT, -tilt)
	var reach := clampf(target.length(), 0.05, leg * 0.9999)
	var thigh := _thigh_length
	var shin := _shin_length

	var knee := PI - acos(clampf(
			(thigh * thigh + shin * shin - reach * reach) / (2.0 * thigh * shin), -1.0, 1.0))
	# Straight down is zero, and the knee leads, so the thigh sits that much in
	# front of the line from the hip to the foot.
	var hip := atan2(-target.z, -target.y) - acos(clampf(
			(thigh * thigh + reach * reach - shin * shin) / (2.0 * thigh * reach), -1.0, 1.0))
	# The sole's tilt is measured against the ground, so everything above it —
	# the pelvis included — has to be taken back off.
	return Vector3(hip, knee, track.z * amount - (hip + knee) - tilt)


func _pose_torso(t: float) -> void:
	var hips := _joints.get("hips") as Node3D
	if hips != null:
		# The bob is not a curve of its own: it is however far the legs had to
		# pull the hips down to keep the planted foot on the ground, worked out
		# in _pose_legs() and already damped by whatever share of them the walk
		# clip has taken.
		var step_drop := _attack_step * (1.0 - 0.65 * _stride_blend)
		# A clip that crouches or leaves the ground carries the hips with it; the
		# travel is already scaled down to this body.
		var shift := _clip_hips_offset()
		hips.position = Vector3(
				shift.x,
				_hips_base_y + _hips_rise + 0.04 * _air_blend - 0.26 * _roll_tuck
						- 0.07 * step_drop - _crouch_sink() + shift.y,
				0.14 * step_drop + shift.z)

	var pitch := (lean * _stride_blend + run_extra_lean * _run_blend
			+ dash_lean * _dash_blend * (1.0 - _roll_tuck)
			+ crouch_lean * _crouch_blend)
	var breathe := sin(t * breath_rate) * breath_amount * (1.0 - _stride_blend)

	# The somersault is a full turn about the hips, so the legs come with it.
	# The pelvis also twists with the stride — the leading hip comes forward with
	# its leg — which is what the shoulders above it counter-rotate against. A
	# torso that turns in one piece is the other half of a mechanical-looking run.
	_pose_joint("hips", Vector3(
			_roll_angle,
			_attack_body.z - sin(_phase) * hip_yaw * _stride_blend,
			sin(_phase) * hip_roll * _stride_blend))
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


## Lays the climbing pose over whatever the body was doing, once it has taken
## hold of a wall.
##
## Hands and feet work in diagonal pairs — the left hand reaches as the right
## knee comes up — which is what keeps a climber's weight over the wall instead
## of hanging off their arms. The cycle is paced by how much face the body has
## actually covered, so a slow haul reaches slowly and a scramble reaches fast,
## and a body hanging still holds the grip it is on.
##
## Written as absolute orientations rather than offsets: this is a pose the
## authored stance has nothing to say about, so there is nothing to preserve.
func _pose_climb() -> void:
	# The whole model is slid up against the face, because the capsule it lives
	# in stands a good deal further off the wall than a body ever would. Set
	# before the early out so that letting go puts it back.
	position.z = -climb_close * _climb_blend
	if _climb_blend <= 0.001:
		return
	var w := _climb_blend
	var reach_l := 0.5 + 0.5 * sin(_climb_phase)
	var reach_r := 1.0 - reach_l
	# Sideways travel leans the body the way it is going, so a shuffle along a
	# face reads as reaching rather than sliding.
	var drift := clampf(_climb_drive.x, -1.0, 1.0)

	# Arms: high and nearly straight on the reach, folded on the pull.
	_blend_to("shoulder_l", Vector3(lerpf(-2.45, -2.85, reach_l), 0.0, -0.2), w)
	_blend_to("upperarm_l_end", Vector3(lerpf(1.05, 0.2, reach_l), 0.0, 0.0), w)
	_blend_to("forearm_l_end", Vector3(-0.1, 0.0, 0.0), w)
	_blend_to("shoulder_r", Vector3(lerpf(-2.45, -2.85, reach_r), 0.0, 0.2), w)
	_blend_to("upperarm_r_end", Vector3(lerpf(1.05, 0.2, reach_r), 0.0, 0.0), w)
	_blend_to("forearm_r_end", Vector3(-0.1, 0.0, 0.0), w)

	# Legs: the knee opposite the reaching hand comes up onto a hold while the
	# other leg stands on the one it already has.
	var up_l := reach_r
	var up_r := reach_l
	_blend_to("hip_l", Vector3(lerpf(0.12, -0.8, up_l), 0.0, lerpf(-0.08, -0.38, up_l)), w)
	_blend_to("thigh_l_end", Vector3(lerpf(0.18, 1.35, up_l), 0.0, 0.0), w)
	_blend_to("foot_l", Vector3(lerpf(-0.1, -0.35, up_l), 0.0, 0.0), w)
	_blend_to("hip_r", Vector3(lerpf(0.12, -0.8, up_r), 0.0, lerpf(0.08, 0.38, up_r)), w)
	_blend_to("thigh_r_end", Vector3(lerpf(0.18, 1.35, up_r), 0.0, 0.0), w)
	_blend_to("foot_r", Vector3(lerpf(-0.1, -0.35, up_r), 0.0, 0.0), w)

	# Torso: held in to the face, turning a little with whichever arm is working,
	# head up because that is where the next hold is.
	var twist := (reach_l - reach_r) * 0.13
	_blend_to("hips", Vector3(climb_hug * 0.2, -twist, drift * 0.12), w)
	_blend_to("spine", Vector3(climb_hug * 0.6, twist * 0.6, 0.0), w)
	_blend_to("chest", Vector3(climb_hug * 0.4, twist, 0.0), w)
	_blend_to("neck", Vector3(-0.3, twist * 0.4, 0.0), w)
	_blend_to("head", Vector3(-0.35, twist * 0.5, 0.0), w)

	# The hips ride closer to the face than the shoulders do, which is the whole
	# trick of climbing: the weight stays over the feet.
	var hips := _joints.get("hips") as Node3D
	if hips != null:
		hips.position.y = lerpf(hips.position.y, _hips_base_y - 0.04, w)
		hips.position.z = lerpf(hips.position.z, 0.05, w)


## Blends a joint towards an orientation of its own rather than towards an
## offset from the authored stance. For poses the stance has nothing to say
## about — climbing is the only one so far.
func _blend_to(joint_name: String, pose: Vector3, weight: float) -> void:
	if not _pose.has(joint_name):
		return
	_pose[joint_name] = (_pose[joint_name] as Vector3).lerp(pose, weight)


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
	if _clip_role == ClipRole.SWING:
		# The swing is coming from a clip, so the blade is live over the slice of
		# it that was measured at load and the procedural pose stays out of it.
		var through := _action.clip_progress()
		_attack_cutting = through >= _clip_window.x and through <= _clip_window.y
		_attack_arm = Vector4.ZERO
		_attack_body = Vector3.ZERO
		_attack_roll = 0.0
		_attack_step = 0.0
		return

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
	# Climbing, the cape hangs off a body that is barely moving, whatever the
	# controller reports for ground speed while it works its way sideways.
	var upright := 1.0 - _climb_blend
	var drive := (_stride_blend * cloth_trail * upright + _dash_blend * 0.5
			+ clampf(-vertical_speed * 0.02, 0.0, 0.4) * upright)
	var flutter := sin(_phase * 2.0) * 0.06 * _stride_blend * upright
	var weight := 1.0 - exp(-cloth_stiffness * delta)

	# Standing still the cape has nothing sweeping it back, and the mail skirt
	# below it is wider than the shoulders it hangs from, so it needs holding
	# clear of the body — cloth over armour never lies flat against it anyway.
	_chase(CAPE_CHAIN, _cape_angles, cape_rest_flare + drive + flutter, weight, 1.0)
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
	if not _base.has(joint_name):
		return
	_pose[joint_name] = (_base[joint_name] as Vector3) + offset


## Layers a second offset on a joint that was already posed this frame.
func _add_offset(joint_name: String, offset: Vector3) -> void:
	if not _pose.has(joint_name):
		return
	_pose[joint_name] = (_pose[joint_name] as Vector3) + offset


## Writes the frame's pose onto the model, blending in whatever the two clip
## layers want joint by joint.
##
## Three sources stack, weakest first: the procedural pose, then the walk cycle
## over the legs, then whatever one-shot is running. Each is a slerp, so a layer
## that is only half in leaves the one under it showing through rather than
## replacing it.
##
## Retargeted clips arrive as *model*-space orientations, so each joint has to
## be resolved against the pose its parent was actually given — which is the
## blended one, not the clip's — otherwise a half-faded clip or an upper-body
## mask would leave the chain hinged in the middle. Walking the joints in
## hierarchy order keeps that parent available.
func _apply_pose() -> void:
	var gait_weight := _gait.weight() if _gait != null else 0.0
	var action_weight := _action.weight() if _action != null else 0.0
	# Reused rather than rebuilt: this runs every frame, and every joint is
	# written before it is read, so nothing survives from the last one.
	var model := _model_basis
	model[""] = _root_basis

	for joint_name in AnimRetarget.JOINT_ORDER:
		var node := _joints.get(joint_name) as Node3D
		if node == null:
			continue
		var parent: Basis = model[AnimRetarget.JOINT_PARENT[joint_name]]
		var into_model := parent.inverse()
		var local := Basis.from_euler(_pose.get(joint_name, _base[joint_name]), node.rotation_order)

		if gait_weight > 0.001:
			var share := _gait.joint_weight(joint_name)
			if share > 0.001:
				local = local.slerp(into_model * _gait.joint_basis(joint_name), share)
		if action_weight > 0.001:
			var share := _action.joint_weight(joint_name)
			if share > 0.001:
				local = local.slerp(into_model * _action.joint_basis(joint_name), share)

		node.basis = local
		model[joint_name] = parent * local

	# Cloth, hair and anything else the library has no counterpart for.
	for joint_name: String in _pose:
		if AnimRetarget.JOINT_PARENT.has(joint_name):
			continue
		var node := _joints.get(joint_name) as Node3D
		if node != null:
			node.rotation = _pose[joint_name]
