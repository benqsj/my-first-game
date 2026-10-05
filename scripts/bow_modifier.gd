class_name BowModifier
extends SkeletonModifier3D

## What the clips cannot know about Avtandil's bow, applied after them each frame.
##
## Mixamo moves a body holding a bow; it has no bow in it. So the bow's own
## behaviour is worked out here, on the pose the clip has just produced:
##
## - the torso tilts up or down onto the shot (`pitch`), from the chest, so the
##   arms and the bow go with it and the legs stay planted;
## - the limbs bend back as the string comes in (`draw`), and snap straight when
##   it goes;
## - the string runs from each tip to the drawing fingers while drawn, and
##   straight tip to tip otherwise;
## - an arrow sits on the string from the fingers through the grip.
##
## The string and arrow are ordinary nodes the rig owns; this only places them,
## because this is the one moment in the frame the final pose is known.

var draw: float = 0.0
var pitch: float = 0.0
## Bend at full draw, radians, per limb.
var limb_flex: float = 0.32
## How much of the pitch the chest takes, and the neck on top of it.
var chest_share: float = 0.7
var neck_share: float = 0.3
## A braced shot (0..1): the hips drop and the knees give, the body leans on
## into the shot from the waist while the chest keeps the aim — the stance of
## a skill shot rather than an ordinary one.
var crouch: float = 0.0
## At full crouch: how far the hips drop, as a share of the leg, and how far
## forward the waist leans (radians; the chest takes it back).
var crouch_drop: float = 0.16
var crouch_lean: float = 0.32
## How much to bring the head level (0..1): the sprint clip, straightened up
## in Blender, leaves the head thrown back ~20° — he ran looking at the sky.
## Brought to `head_lean` forward of upright.
var head_level: float = 0.0
var head_lean: float = deg_to_rad(6.0)
## The free arm flung out at something (0..1), and at what (world space): the
## Hunter's Mark, thrown on the run.
var point: float = 0.0
var point_at: Vector3 = Vector3.ZERO

var string_u: Node3D
var string_l: Node3D
var arrow: Node3D

var _bones := {}


func _ready() -> void:
	active = true


func _bone(name: StringName) -> int:
	if not _bones.has(name):
		var skel := get_skeleton()
		_bones[name] = skel.find_bone(name) if skel != null else -1
	return _bones[name]


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	_brace(skel)
	_tilt(skel)
	_level_head(skel)
	_point_arm(skel)
	_flex(skel)
	_place_string(skel)


## Turns bone `b` by `angle` about the skeleton's own left–right axis.
func _turn(skel: Skeleton3D, b: int, angle: float) -> void:
	if b < 0:
		return
	var parent := skel.get_bone_parent(b)
	var parent_global := skel.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var local_axis := (parent_global.basis * skel.get_bone_pose(b).basis).inverse() * Vector3.RIGHT
	skel.set_bone_pose_rotation(b, skel.get_bone_pose_rotation(b) * Quaternion(local_axis.normalized(), angle))


## Swings the free arm (upper arm, then forearm) round to point at
## `point_at`, by `point`: straight from the shoulder, whatever the legs are
## doing.
func _point_arm(skel: Skeleton3D) -> void:
	if point < 0.001:
		return
	var target := skel.global_transform.affine_inverse() * point_at
	for pair in [[&"upperarm_r", &"lowerarm_r"], [&"lowerarm_r", &"hand_r"]]:
		var b := _bone(pair[0])
		var c := _bone(pair[1])
		if b < 0 or c < 0:
			continue
		var gb := skel.get_bone_global_pose(b)
		var gc := skel.get_bone_global_pose(c)
		var d0 := (gc.origin - gb.origin).normalized()
		var d1 := (target - gb.origin).normalized()
		if d0.length_squared() < 0.5 or d1.length_squared() < 0.5 or d0.dot(d1) > 0.9999:
			continue
		var q := Quaternion.IDENTITY.slerp(Quaternion(d0, d1), point)
		var parent := skel.get_bone_parent(b)
		var pg := skel.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
		var turned := Basis(q) * gb.basis
		skel.set_bone_pose_rotation(b, (pg.inverse() * turned).get_rotation_quaternion())


## Brings the head to `head_lean` forward of upright, by `head_level`.
func _level_head(skel: Skeleton3D) -> void:
	if head_level < 0.001:
		return
	var head := _bone(&"head")
	if head < 0:
		return
	var y := skel.get_bone_global_pose(head).basis.y.normalized()
	# Measured against the skeleton's own forward, which is +Z here (the
	# armature is turned about in the glb): checked with the head probe.
	var lean := atan2(y.dot(Vector3.BACK), y.dot(Vector3.UP))
	_turn(skel, head, clampf(head_lean - lean, -0.8, 0.8) * head_level)


## The braced stance: hips down, thighs forward, shins back, feet flat; the
## waist leaning on. The knee angle is worked out from the leg's own length so
## the feet stay where they were.
func _brace(skel: Skeleton3D) -> void:
	if crouch < 0.001:
		return
	var pelvis := _bone(&"pelvis")
	var thigh := _bone(&"thigh_l")
	var foot := _bone(&"foot_l")
	if pelvis < 0 or thigh < 0 or foot < 0:
		return
	var leg := skel.get_bone_global_pose(thigh).origin.distance_to(skel.get_bone_global_pose(foot).origin)
	var drop := leg * crouch_drop * crouch
	var knee := acos(clampf((leg - drop) / maxf(leg, 0.0001), -1.0, 1.0))
	var parent := skel.get_bone_parent(pelvis)
	var down := Vector3.DOWN * drop
	if parent >= 0:
		down = skel.get_bone_global_pose(parent).basis.inverse() * down
	skel.set_bone_pose_position(pelvis, skel.get_bone_pose_position(pelvis) + down)
	for side in [&"_l", &"_r"]:
		_turn(skel, _bone(StringName("thigh" + side)), -knee)
		_turn(skel, _bone(StringName("calf" + side)), 2.0 * knee)
		_turn(skel, _bone(StringName("foot" + side)), -knee)
	_turn(skel, _bone(&"spine_01"), crouch_lean * crouch)


## Pitches the chest and neck about the body's own left–right axis (and gives
## back what the braced stance's waist took, so the aim holds).
func _tilt(skel: Skeleton3D) -> void:
	var tilt := pitch + crouch_lean * crouch
	if absf(tilt) < 0.001:
		return
	var side := Vector3.RIGHT  # the skeleton's own right; the model faces its -Z
	for pair in [[&"spine_02", chest_share], [&"neck_01", neck_share]]:
		var b := _bone(pair[0])
		if b < 0:
			continue
		var parent := skel.get_bone_parent(b)
		var parent_global := skel.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
		var local_axis := (parent_global.basis * skel.get_bone_pose(b).basis).inverse() * side
		var q := Quaternion(local_axis.normalized(), -tilt * float(pair[1]))
		skel.set_bone_pose_rotation(b, skel.get_bone_pose_rotation(b) * q)


func _flex(skel: Skeleton3D) -> void:
	var bend := limb_flex * clampf(draw, 0.0, 1.0)
	var grip := _bone(&"bow_l")
	var pinch := _bone(&"draw_r")
	if bend <= 0.0001 or grip < 0 or pinch < 0:
		return
	# Towards the string hand is the way a drawn limb gives. Worked out from the
	# pose rather than from the bone's axes, so it does not depend on how the
	# exporter left them.
	var toward := skel.get_bone_global_pose(pinch).origin - skel.get_bone_global_pose(grip).origin
	if toward.length() < 0.01:
		return
	toward = toward.normalized()
	for pair in [[&"bow_limb_u", &"bow_tip_u"], [&"bow_limb_l", &"bow_tip_l"]]:
		var b := _bone(pair[0])
		var t := _bone(pair[1])
		if b < 0 or t < 0:
			continue
		var g := skel.get_bone_global_pose(b)
		var limb := skel.get_bone_global_pose(t).origin - g.origin
		var axis := limb.cross(toward)
		if axis.length() < 0.0001:
			continue
		var turned := Basis(axis.normalized(), bend) * g.basis
		var parent := skel.get_bone_parent(b)
		var pg := skel.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
		skel.set_bone_pose_rotation(b, (pg.inverse() * turned).get_rotation_quaternion())


## Puts the string and arrow on another skeleton's bow — a figure's, with bones
## of the same names (see [FigureFollower]) — once it has been posed.
func place_string_on(skel: Skeleton3D) -> void:
	_place_string(skel, skel != get_skeleton())


func _place_string(skel: Skeleton3D, foreign: bool = false) -> void:
	var tu := skel.find_bone("bow_tip_u") if foreign else _bone(&"bow_tip_u")
	var tl := skel.find_bone("bow_tip_l") if foreign else _bone(&"bow_tip_l")
	var pinch := skel.find_bone("draw_r") if foreign else _bone(&"draw_r")
	var grip := skel.find_bone("bow_l") if foreign else _bone(&"bow_l")
	if tu < 0 or tl < 0:
		return
	var xf := skel.global_transform
	var a := xf * skel.get_bone_global_pose(tu).origin
	var c := xf * skel.get_bone_global_pose(tl).origin
	var hand := xf * skel.get_bone_global_pose(pinch).origin if pinch >= 0 else (a + c) * 0.5
	var g := xf * skel.get_bone_global_pose(grip).origin if grip >= 0 else (a + c) * 0.5
	place_string_at(a, c, hand, g, pinch >= 0)


## The string from the tips `a` and `c` to the drawing fingers at `hand` (as
## far as the draw has brought it), and the arrow from them through the grip
## `g`: for a bow with no bones of this rig's names (the pack's bow on the
## mannequin's figure, whose tips the rig works out itself).
func place_string_at(a: Vector3, c: Vector3, hand: Vector3, g: Vector3, fingers: bool = true) -> void:
	# The fingers take the string when they reach it, not when the draw starts:
	# a nock that goes to the quiver first would otherwise drag the string off
	# after the hand, across the archer's back. Past `CATCH_ANYWAY` of the draw
	# it is taken wherever the hand is, so a clip that never quite comes to the
	# string still draws it.
	span = hand.distance_to(g)
	if not fingers or draw <= 0.05:
		_caught = false
		_nearest = INF
	elif not _caught:
		# Taken where the hand comes nearest the bow on its way to the string
		# and turns back with it: the clips' fingers pass the string a little
		# off it (never within CATCH_REACH), and taken only at CATCH_ANYWAY the
		# string jumped from its rest to a hand already most of the way back
		# (the user's word, 2026-10-05).
		var turned := draw > 0.08 and span > _nearest + CATCH_TURN
		_nearest = minf(_nearest, span)
		_caught = turned or _to_line(hand, a, c) < CATCH_REACH or draw >= CATCH_ANYWAY
		if _caught:
			_caught_ms = Time.get_ticks_msec()
	var drawn := _caught
	# The string comes off its rest line onto the fingers over `CATCH_BLEND`
	# seconds from the moment they take it, never in a jump.
	var take := smoothstep(0.0, 1.0, float(Time.get_ticks_msec() - _caught_ms) / (CATCH_BLEND * 1000.0))
	var mid := ((a + c) * 0.5).lerp(hand, take) if drawn else (a + c) * 0.5
	_stretch(string_u, a, mid)
	_stretch(string_l, c, mid)
	if arrow != null:
		arrow.visible = drawn
		if drawn:
			var along := g - hand
			if along.length() > 0.05:
				arrow.global_transform = Transform3D(Basis.looking_at(along, Vector3.UP), hand)


## How near (m) the drawing fingers must come to the resting string to take it,
## and the share of the draw past which they take it wherever they are.
## The drawing hand's distance to where the arrow rests on the bow, last placed.
var span: float = 0.0
const CATCH_REACH := 0.12
## How far back past its nearest the hand must come to have turned with the
## string, and how long the string takes to come onto the fingers.
const CATCH_TURN := 0.03
const CATCH_BLEND := 0.15
var _nearest: float = INF
var _caught_ms: int = 0
const CATCH_ANYWAY := 0.6
var _caught: bool = false


## True once the drawing fingers have the string, for this draw.
func has_string() -> bool:
	return _caught


static func _to_line(p: Vector3, a: Vector3, c: Vector3) -> float:
	var ac := c - a
	var u := clampf((p - a).dot(ac) / maxf(ac.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ac * u)


## Puts a string half at `from`, pointing its -Y at `to`, one unit long scaled to
## reach: the same convention the procedural bow used, so anything that reads it
## (the archer test does) finds the end at to_global(0, -1, 0).
func _stretch(half: Node3D, from: Vector3, to: Vector3) -> void:
	if half == null:
		return
	var d := to - from
	var length := d.length()
	if length < 0.001:
		return
	var down := -d / length
	var side := down.cross(Vector3.FORWARD)
	if side.length() < 0.01:
		side = down.cross(Vector3.RIGHT)
	side = side.normalized()
	var fwd := side.cross(down).normalized()
	half.global_transform = Transform3D(Basis(side, down * length, fwd), from)
