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
@export var bow_hand_reach: Vector3 = Vector3(-0.13, 0.01, 0.48)
## Where the drawing hand starts and where it ends up, relative to *its*
## shoulder. Ending behind the shoulder is what makes a draw read as a draw —
## anything in front of it is a man holding a bow, not one drawing it.
@export var draw_hand_home: Vector3 = Vector3(0.10, 0.06, 0.22)
@export var draw_hand_full: Vector3 = Vector3(0.09, 0.16, -0.24)
## How far the shoulders turn side-on at full draw, radians. An archer square to
## the target cannot get the string past their own chest.
@export var aim_torso_turn: float = 0.52
#endregion

## How far the bow is drawn, 0 to 1, and where it is being pointed.
var _draw: float = 0.0
var _draw_target: float = 0.0
var _aim_pitch: float = 0.0
var _aim_pitch_target: float = 0.0

var _bow: Node3D
var _bow_arrow: Node3D
var _string: Array[Node3D] = []
var _nock: Node3D
## Where the drawing hand holds the string, and where the bow sits when it is
## hanging in the hand rather than being aimed.
var _draw_hand: Node3D
var _bow_carry: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	super()
	_bow = find_child("bow", true, false) as Node3D
	if _bow == null:
		push_warning("ArcherRig: no bow on this model.")
		return
	_bow_carry = _bow.transform
	_bow_arrow = _bow.find_child("bow_arrow", true, false) as Node3D
	_nock = _bow.find_child("bow_nock", true, false) as Node3D
	_draw_hand = find_child("draw", true, false) as Node3D
	for tag in ["bow_string_u", "bow_string_l"]:
		var half := _bow.find_child(tag, true, false) as Node3D
		if half != null:
			_string.append(half)
	if _bow_arrow != null:
		_bow_arrow.visible = false


## How far the bow is drawn and how far off the level the shot is aimed. The
## controller owns both: it knows what the player is holding down and where the
## camera or the locked target is.
func aim_bow(draw: float, pitch: float) -> void:
	_draw_target = clampf(draw, 0.0, 1.0)
	_aim_pitch_target = clampf(pitch, -1.1, 1.1)


## True once the bow is far enough up for the pose to be the aim rather than the
## run it is coming out of.
func is_aiming() -> bool:
	return _draw > 0.3


#region The aim
func _pose_weapon(delta: float) -> void:
	var weight := 1.0 - exp(-aim_blend_speed * delta)
	_draw = lerpf(_draw, _draw_target, weight)
	_aim_pitch = lerpf(_aim_pitch, _aim_pitch_target, weight)
	if _bow_arrow != null:
		_bow_arrow.visible = _draw > 0.02

	if _draw <= 0.001:
		return

	# The draw is what the pose is worth; a half-drawn bow is half the turn, half
	# the reach and half the lean. Squared, so an early snap shot barely leaves
	# the run and a full draw commits the whole body.
	var up := _draw
	var hard := _draw * _draw

	# Torso side-on, head still looking down the arrow.
	var turn := -aim_torso_turn * hard
	_blend_to("hips", (_base["hips"] as Vector3) + Vector3(0.0, turn * 0.35, 0.0), up)
	_blend_to("spine", (_base["spine"] as Vector3)
			+ Vector3(-_aim_pitch * 0.25, turn * 0.4, 0.0), up)
	_blend_to("chest", (_base["chest"] as Vector3)
			+ Vector3(-_aim_pitch * 0.3, turn * 0.25, 0.0), up)
	_blend_to("neck", Vector3(-_aim_pitch * 0.2, -turn * 0.5, 0.0), up)
	_blend_to("head", Vector3(-_aim_pitch * 0.25, -turn * 0.5, 0.0), up)

	# The bow arm holds the bow out at the aim; the drawing arm takes the string
	# back past the jaw. Both are solved rather than posed, so the reach does not
	# have to be re-tuned every time the model's proportions change.
	var reach := bow_hand_reach.rotated(Vector3.RIGHT, -_aim_pitch)
	_reach_with(BOW_ARM, BOW_ELBOW, reach, up, 1.0)
	var home := draw_hand_home.lerp(draw_hand_full, _draw)
	_reach_with(DRAW_ARM, DRAW_ELBOW, home.rotated(Vector3.RIGHT, -_aim_pitch), up, -1.0)


## The bow and its string, once the arms holding them are final.
func _place_props() -> void:
	_hold_bow_upright(_draw)
	_string_to_hand()


## Stands the bow up in the hand.
##
## Carried, it hangs off the wrist and goes wherever the arm does — which, once
## the arm is held out at a target, lays it flat. So while aiming it is given an
## orientation in the *model's* frame instead: limbs upright, face square to the
## shot. The hand keeps holding it; it just stops being the thing that decides
## which way up it is.
func _hold_bow_upright(weight: float) -> void:
	if _bow == null:
		return
	var hand := _joints.get("hand_r") as Node3D
	if hand == null:
		return
	var at := to_local(hand.global_position) + Vector3(0.0, -0.06, 0.0)
	# Identity in the model's frame is already right: the limbs were built along
	# +Y and leaning towards +Z, which is the way the body faces.
	var aimed := _place_in_model(_bow, Basis.IDENTITY.rotated(Vector3.RIGHT, -_aim_pitch), at)
	_bow.transform = _blend_transform(_bow_carry, aimed, weight, Vector3.ONE)


## Puts one hand where it has to be. `target` is relative to the shoulder in the
## model's own frame, and `fold` picks which side of the line the elbow bends to.
##
## Solved with a yaw as well as a pitch, because a bow arm and a drawing arm are
## nowhere near the same plane and a shoulder that can only pitch reaches
## neither of them.
func _reach_with(root_name: String, elbow_name: String, target: Vector3,
		weight: float, fold: float) -> void:
	var root := _joints.get(root_name) as Node3D
	if root == null or _upperarm_length <= 0.0:
		return
	var parent := root.get_parent() as Node3D
	var aim := target
	if parent != null:
		var in_model := global_transform.basis.inverse() * parent.global_transform.basis
		aim = in_model.orthonormalized().inverse() * target
	var solved := _solve_aim(aim, _upperarm_length, _forearm_length, fold)
	_blend_to(root_name, Vector3(solved.x, solved.y, 0.0), weight)
	_blend_to(elbow_name, Vector3(solved.z, 0.0, 0.0), weight)


## Pulls both halves of the string onto the drawing hand, and the arrow with it.
##
## Where the hand actually is, not where a number says the draw should have put
## it: the arm is solved, so the only thing that knows where the string ends up
## is the hand itself. Each half hangs from its own nock along its own axis, so
## pointing it is a rotation and reaching it is a scale — no string geometry has
## to be rebuilt per frame.
func _string_to_hand() -> void:
	if _string.is_empty() or _nock == null or _bow == null:
		return

	var pull := _nock.position
	if _draw_hand != null:
		pull = _bow.to_local(_draw_hand.global_position)

	for half in _string:
		var along := pull - half.position
		if along.length_squared() < 1e-6:
			continue
		# Each half hangs towards the grip: the upper one down its -Y, the lower
		# one up its +Y, which is what its own resting scale says.
		var axis := Vector3.DOWN if half.position.y > 0.0 else Vector3.UP
		half.transform.basis = _swing(axis, along.normalized())
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
