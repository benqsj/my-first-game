class_name ArcherRig
extends CharacterRig

## Avtandil's rig: everything the knight's does, plus a bow.
##
## The body, the stride, the climb and the jumps all come from [CharacterRig]
## unchanged — that is the whole point of the two of them sharing a joint
## layout. What is added here is the one thing he does that the knight does not:
## draw, hold and loose.
##
## It is procedural, because it has to be. The animation library has forty-three
## clips and not one of them touches a bow, so there is nothing to retarget —
## the same position the crouch and the wall climb were in. What there *is* to
## work with is the two-bone solve written for the legs: the bow hand is put
## where the bow has to be and the drawing hand where the string has to be, and
## the arms are solved to reach them.

## Which hand is which. The model's `*_l` nodes sit on its -X side, and with the
## model facing +Z that is the archer's *right* — so the bow, held in the left
## hand, hangs off `hand_r`, and `hand_l` draws the string.
const BOW_ARM := "shoulder_r"
const BOW_ELBOW := "upperarm_r_end"
const DRAW_ARM := "shoulder_l"
const DRAW_ELBOW := "upperarm_l_end"

#region Exported tuning
@export_group("Bow")
## How fast the body settles into and out of the aim.
@export var aim_blend_speed: float = 11.0
## Where the bow hand is held while aiming, relative to the shoulder it hangs
## off, in metres: out in front at shoulder height and a little across the body,
## which is where a bow arm actually goes.
@export var bow_hand_reach: Vector3 = Vector3(-0.13, 0.01, 0.46)
## Where the drawing hand starts and where it ends up, relative to *its*
## shoulder. It starts out on the string beside the bow and finishes **at the
## jaw** — across the face and a little above the shoulder, which on this model
## is where the head is. Further back than that is not a longer draw, it is an
## arm dislocating: the string has to stop somewhere a hand can hold it.
@export var draw_hand_home: Vector3 = Vector3(0.18, 0.04, 0.34)
@export var draw_hand_full: Vector3 = Vector3(0.17, 0.11, 0.01)
## Which way each elbow is pushed, in the model's frame. This is the one thing a
## shoulder and an elbow leave free once the hand is pinned, and for an arm it is
## most of the pose: the bow arm's elbow rolls down and out of the string's way,
## the drawing elbow goes back and out behind the hand, level with the arrow.
@export var bow_elbow_pole: Vector3 = Vector3(0.45, -1.0, -0.15)
@export var draw_elbow_pole: Vector3 = Vector3(-0.55, 0.15, -1.0)
## How far the body turns side-on at full draw, radians. An archer square to the
## target cannot get the string past his own chest, and has nowhere to put the
## drawing elbow but out sideways — which is what a wrong-looking draw *is*.
## Split across the hips, the spine and the chest, so what turns is the whole
## man and not his shoulders on top of a body still facing front.
@export var aim_torso_turn: float = 0.86
## How long the bow arm takes to come up, in seconds — on its own clock, not on
## the draw's. The bow goes to the target and *then* gets pulled; an arm that
## rises in step with the string spends the whole draw being winched into place,
## and at a quarter draw is still somewhere near the hip. A full draw takes
## `draw_time` (0.85 s); this is a fifth of that.
@export var aim_raise_time: float = 0.17
## How far the limbs bend back at full draw, radians. A bow whose limbs do not
## give is the thing that makes a draw look wrong.
@export var limb_flex: float = 0.42
## How far the body leans back into the draw, radians, and how much the weight
## shifts onto the back foot.
@export var draw_lean: float = 0.12
## How hard the hands shake at full draw. Holding a bow at full stretch is work,
## and a pose that is perfectly still does not look like work.
@export var draw_strain: float = 0.012
## How long the body takes to unwind after the string goes, in seconds.
@export var loose_time: float = 0.3
## How the bow sits in the hand when it is not being drawn: canted out from the
## leg and tipped back, radians. Upright, because a bow carried flat across the
## hip is a stick, and the silhouette is most of what says "archer".
@export var carry_cant: float = 0.34
@export var carry_lean: float = 0.16
#endregion

## How far the bow is drawn, 0 to 1, and where it is being pointed.
var _draw: float = 0.0
var _draw_target: float = 0.0
var _aim_pitch: float = 0.0
var _aim_pitch_target: float = 0.0

var _bow: Node3D
var _bow_arrow: Node3D
var _string: Array[Node3D] = []
var _limbs: Array[Node3D] = []
var _limb_rest: Array[float] = []
var _nock: Node3D
## What is left of the snap after the string goes, 1 down to 0.
var _loose: float = 0.0
## How much of the string the hand has taken, 0 to 1. It follows the arm up
## rather than the draw, because the string cannot be hanging off a hand that has
## not reached it yet.
var _grip: float = 0.0
## Where the drawing hand holds the string.
var _draw_hand: Node3D


func _ready() -> void:
	super()
	_bow = find_child("bow", true, false) as Node3D
	if _bow == null:
		push_warning("ArcherRig: no bow on this model.")
		return
	_bow_arrow = _bow.find_child("bow_arrow", true, false) as Node3D
	_nock = _bow.find_child("bow_nock", true, false) as Node3D
	_draw_hand = find_child("draw", true, false) as Node3D
	for tag in ["bow_string_u", "bow_string_l"]:
		var half := _bow.find_child(tag, true, false) as Node3D
		if half != null:
			_string.append(half)
	for tag in ["bow_limb_u", "bow_limb_l"]:
		var limb := _bow.find_child(tag, true, false) as Node3D
		if limb != null:
			_limbs.append(limb)
			_limb_rest.append(limb.rotation.x)
	if _bow_arrow != null:
		_bow_arrow.visible = false
	# Built for a reach-over-the-shoulder nock that is no longer done: the hand
	# goes straight to the string, so the carried arrow is never shown.
	var spare := _bow.find_child("bow_spare", true, false) as Node3D
	if spare != null:
		spare.visible = false


## How far the bow is drawn and how far off the level the shot is aimed. The
## controller owns both: it knows what the player is holding down and where the
## camera or the locked target is.
func aim_bow(draw: float, pitch: float) -> void:
	_draw_target = clampf(draw, 0.0, 1.0)
	_aim_pitch_target = clampf(pitch, -1.1, 1.1)


## The string has gone. Snaps the limbs straight, throws the drawing hand open
## and lets the body unwind — which is the half of a shot that says it happened.
func loose_bow() -> void:
	if _draw <= 0.05:
		return
	_loose = 1.0


## True once the bow is far enough up for the pose to be the aim rather than the
## run it is coming out of.
func is_aiming() -> bool:
	return _draw > 0.3


#region The aim
## The shot's own clock, and the feet it is taken from.
##
## An archer draws from a **set stance**: the bow-side foot forward, the weight
## between the feet, the body turned side-on to the shot. That last one is not
## decoration — square to the target there is nowhere for the drawing hand to go
## but out sideways, and the elbow ends up sticking off the body instead of
## sitting in behind the arrow. Turning the body is what puts it in line, and it
## is why this runs with the legs rather than with the arms.
func _pose_stance(delta: float) -> void:
	var weight := 1.0 - exp(-aim_blend_speed * delta)
	_draw = lerpf(_draw, _draw_target, weight)
	_aim_pitch = lerpf(_aim_pitch, _aim_pitch_target, weight)
	_loose = maxf(_loose - delta / maxf(loose_time, 0.01), 0.0)
	# The bow arm leads the string, on its own clock. Everything that has to be
	# *held* — the bow up at the target, the hand on the string, the arrow across
	# the rest — rides this rather than the draw, so the pose is assembled first
	# and pulled second. Held up through the loose as well: the follow-through is
	# part of the shot, and an arm that drops the moment the string goes has not
	# shot anything.
	_grip = move_toward(_grip, maxf(1.0 if _draw_target > 0.01 else 0.0, _loose),
			delta / maxf(aim_raise_time, 0.01))

	if _bow_arrow != null:
		# On the string from the moment the hand is on it, and gone the moment it
		# is loosed — the arrow in the air is a different arrow entirely.
		_bow_arrow.visible = _draw > 0.02 and _loose <= 0.0
	# The feet are set as soon as the bow comes up, not as the string comes back:
	# they go first, which is the order anyone shooting a bow does it in.
	_brace = _grip


func _pose_weapon(_delta: float) -> void:
	# `_grip` as well as the draw: the arm is still on its way down after a draw
	# that was let go of, and dropping out here would snap it to his side.
	if _draw <= 0.001 and _loose <= 0.0 and _grip <= 0.001:
		_flex_limbs(0.0)
		return

	# How far into the shot the body is. The draw is what the pose is worth, and
	# the snap after it is worth the same again for a moment: both are "this is
	# a person shooting a bow" and the run underneath should not show through.
	var up := maxf(_draw, _loose)
	var hard := _draw * _draw
	# Loosing throws everything the other way for a beat.
	var snap := _loose * _loose

	# Torso: turned side-on, leaning back into the string, and unwinding when it
	# goes. Squared, so a snap shot barely leaves the run and a full draw commits
	# the whole body.
	var turn := -aim_torso_turn * hard * (1.0 - snap * 0.55)
	var lean := draw_lean * hard - draw_lean * 1.4 * snap
	_blend_to("hips", (_base["hips"] as Vector3)
			+ Vector3(lean * 0.3, turn * 0.35, 0.0), up)
	_blend_to("spine", (_base["spine"] as Vector3)
			+ Vector3(-_aim_pitch * 0.25 - lean * 0.7, turn * 0.4, 0.0), up)
	_blend_to("chest", (_base["chest"] as Vector3)
			+ Vector3(-_aim_pitch * 0.3 - lean * 0.5, turn * 0.25, 0.0), up)
	# The head stays on the arrow whatever the shoulders do under it.
	_blend_to("neck", Vector3(-_aim_pitch * 0.2, -turn * 0.5, 0.0), up)
	_blend_to("head", Vector3(-_aim_pitch * 0.25, -turn * 0.55, 0.0), up)

	# A bow held at full stretch shakes. Tiny, and only at the top of the draw,
	# but a pose that is perfectly still does not read as effort.
	var strain := draw_strain * hard * sin(Time.get_ticks_msec() * 0.031)

	# The bow arm goes straight out at the target and stays there. It rides
	# `_grip`, not the draw, so the bow is up and level while the string is still
	# at rest — which is the order an archer does it in.
	var reach := bow_hand_reach.rotated(Vector3.RIGHT, -_aim_pitch)
	reach += Vector3(0.0, strain, -0.05 * snap)
	_reach_with(BOW_ARM, BOW_ELBOW, reach, bow_elbow_pole, _grip)

	# The drawing hand comes onto the string beside the bow, then takes it back
	# to the jaw, and is thrown open behind the ear when it goes. Eased at both
	# ends: a hand that starts and stops at full speed is a hand on rails.
	var pull := smoothstep(0.0, 1.0, _draw)
	var hand := draw_hand_home.lerp(draw_hand_full, pull)
	hand += Vector3(0.0, strain * 1.5, 0.0)
	hand = hand.lerp(draw_hand_full + Vector3(-0.06, 0.04, -0.20), snap)
	_reach_with(DRAW_ARM, DRAW_ELBOW, hand.rotated(Vector3.RIGHT, -_aim_pitch),
			draw_elbow_pole, _grip)

	_flex_limbs(_draw * (1.0 - snap))


## Bends the limbs back as the string comes in, and lets them go when it does.
##
## This is what a drawn bow *is*: the limbs give, and the string is straight
## between two ends that have moved. With rigid limbs the string bends round a
## shape that is not giving, which is exactly the thing that looks wrong.
func _flex_limbs(amount: float) -> void:
	for i in _limbs.size():
		var limb := _limbs[i]
		# Upper and lower lean opposite ways, so the flex follows the lean.
		var back := -limb_flex * amount * signf(_limb_rest[i])
		limb.rotation.x = _limb_rest[i] + back


## The bow and its string, once the arms holding them are final.
func _place_props() -> void:
	# `_grip`, not the draw: the bow squares up to the target as the arm carries
	# it there, not as the string comes back.
	_hold_bow_upright(_grip)
	_string_to_hand()


## Stands the bow up in the hand.
##
## Left to hang off the wrist it goes wherever the arm does, which lays it flat
## across the hip when he walks and flat across the shot when he aims — a stick
## in the hand either way. So its orientation is given in the *model's* frame at
## both ends: canted out from the leg while it is carried, square to the target
## while it is drawn. The hand keeps holding it; it just stops being the thing
## that decides which way up it is.
func _hold_bow_upright(weight: float) -> void:
	if _bow == null:
		return
	var hand := _joints.get("hand_r") as Node3D
	if hand == null:
		return
	var at := to_local(hand.global_position) + Vector3(0.0, -0.06, 0.0)
	# Identity in the model's frame is already the aim: the limbs were built
	# along +Y and leaning towards +Z, which is the way the body faces.
	var carried := Basis.IDENTITY.rotated(Vector3.FORWARD, carry_cant) \
			.rotated(Vector3.RIGHT, carry_lean)
	var aimed := Basis.IDENTITY.rotated(Vector3.RIGHT, -_aim_pitch)
	_bow.transform = _place_in_model(_bow,
			carried.slerp(aimed, clampf(weight, 0.0, 1.0)), at)


## Puts one hand where it has to be **and the elbow where it should be**.
##
## `target` and `pole` are both relative to the shoulder in the model's own
## frame: the hand goes to the target, and the elbow is pushed round towards the
## pole. Two bones and a pinned hand leave exactly one thing free — which way
## round the limb axis the elbow swings — and for an arm that one thing is most
## of the pose. Solved without it, the drawing arm comes out with the upper arm
## pointing at the sky and the forearm folded back down it, which is the
## chicken wing the earlier pass had.
##
## The shoulder is given a whole basis rather than a pitch and a yaw, because a
## pitch and a yaw *are* the version with no elbow control. The bone runs down
## its own -Y and the elbow bends about its own X, so the basis is built from
## the upper arm's direction and the axis that carries it onto the forearm.
func _reach_with(root_name: String, elbow_name: String, target: Vector3,
		pole: Vector3, weight: float) -> void:
	var root := _joints.get(root_name) as Node3D
	if root == null or _upperarm_length <= 0.0 or _forearm_length <= 0.0:
		return

	# Everything is worked out in the shoulder's parent frame, which is the frame
	# the pose is written in.
	var aim := target
	var out := pole
	var parent := root.get_parent() as Node3D
	if parent != null:
		var into_parent := (global_transform.basis.inverse()
				* parent.global_transform.basis).orthonormalized().inverse()
		aim = into_parent * target
		out = into_parent * pole

	var span := clampf(aim.length(), 0.05,
			(_upperarm_length + _forearm_length) * 0.999)
	var to := aim.normalized()
	# Law of cosines: how far off the line to the hand the elbow has to sit for
	# the far end of the second bone to land on it.
	var off := acos(clampf((_upperarm_length * _upperarm_length + span * span
			- _forearm_length * _forearm_length)
			/ (2.0 * _upperarm_length * span), -1.0, 1.0))
	# The pole squared off against that line is *which* way off it.
	var side := out - to * out.dot(to)
	if side.length_squared() < 1e-8:
		side = to.cross(Vector3.UP)
		if side.length_squared() < 1e-8:
			side = to.cross(Vector3.RIGHT)
	side = side.normalized()

	var arm := (to * cos(off) + side * sin(off)).normalized()
	var fore := aim - arm * _upperarm_length
	if fore.length_squared() < 1e-10:
		return
	fore = fore.normalized()

	var hinge := arm.cross(fore)
	hinge = side if hinge.length_squared() < 1e-10 else hinge.normalized()
	_blend_basis(root_name, root, Basis(hinge, -arm, hinge.cross(-arm)), weight)
	_blend_to(elbow_name, Vector3(arm.angle_to(fore), 0.0, 0.0), weight)


## Eases a joint towards a whole orientation.
##
## Through the *rotation*, not through its three angles: an arm held out level
## sits on the euler singularity, where the yaw and the roll trade off against
## each other freely, and two sets of angles that mean the same orientation
## interpolate to something that means nothing at all.
func _blend_basis(joint_name: String, node: Node3D, wanted: Basis,
		weight: float) -> void:
	if not _pose.has(joint_name):
		return
	var order := node.rotation_order
	var here := Basis.from_euler(_pose[joint_name] as Vector3, order)
	_pose[joint_name] = here.slerp(wanted.orthonormalized(),
			clampf(weight, 0.0, 1.0)).get_euler(order)


## Pulls both halves of the string onto the drawing hand, and the arrow with it.
##
## Where the hand actually is, not where a number says the draw should have put
## it: the arm is solved, so the only thing that knows where the string ends up
## is the hand itself. Each half hangs from its own nock along its own axis, so
## pointing it is a rotation and reaching it is a scale — no string geometry has
## to be rebuilt per frame.
##
## The aiming is done in each half's *parent* frame — the horn it hangs off,
## which the limb flex has just moved. A point in the bow's frame compared
## against a position in the horn's is two different rooms, and the string comes
## out as a line to somewhere near the archer's feet.
func _string_to_hand() -> void:
	if _string.is_empty() or _nock == null or _bow == null:
		return

	# Where the string is being held: at rest on the bow, or wherever the drawing
	# hand actually ended up. Eased between the two by `_grip` rather than
	# switched, because the hand takes a moment to arrive and a string that snaps
	# onto it the instant the draw begins is a string nobody ever picked up.
	var pull := _nock.position
	if _draw_hand != null and _loose <= 0.0 and _grip > 0.0:
		pull = pull.lerp(_bow.to_local(_draw_hand.global_position), _grip)
	var held := _bow.to_global(pull)

	for half in _string:
		var horn := half.get_parent() as Node3D
		if horn == null:
			continue
		var along := horn.to_local(held) - half.position
		if along.length_squared() < 1e-6:
			continue
		# Both halves are built hanging down their own -Y, so both swing the same
		# way; what makes them mirror each other is the horn they hang off.
		half.transform.basis = _swing(Vector3.DOWN, along.normalized())
		half.scale = Vector3(1.0, along.length(), 1.0)

	# The arrow sits on the string and points down the bow: out along +Z, which
	# is where the limbs lean and so where the shot goes.
	if _bow_arrow != null:
		_bow_arrow.position = pull
		_bow_arrow.rotation = Vector3(PI * 0.5, 0.0, 0.0)


## The least rotation that carries `from` onto `to`, as a basis.
static func _swing(from: Vector3, to: Vector3) -> Basis:
	var axis := from.cross(to)
	if axis.length_squared() < 1e-12:
		if from.dot(to) > 0.0:
			return Basis.IDENTITY
		var side := from.cross(Vector3.RIGHT if absf(from.x) < 0.9 else Vector3.UP)
		return Basis(side.normalized(), PI)
	return Basis(axis.normalized(), from.angle_to(to))
#endregion
