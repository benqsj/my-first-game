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
	_tilt(skel)
	_flex(skel)
	_place_string(skel)


## Pitches the chest and neck about the body's own left–right axis.
func _tilt(skel: Skeleton3D) -> void:
	if absf(pitch) < 0.001:
		return
	var side := Vector3.RIGHT  # the skeleton's own right; the model faces its -Z
	for pair in [[&"spine_02", chest_share], [&"neck_01", neck_share]]:
		var b := _bone(pair[0])
		if b < 0:
			continue
		var parent := skel.get_bone_parent(b)
		var parent_global := skel.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
		var local_axis := (parent_global.basis * skel.get_bone_pose(b).basis).inverse() * side
		var q := Quaternion(local_axis.normalized(), -pitch * float(pair[1]))
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


func _place_string(skel: Skeleton3D) -> void:
	var tu := _bone(&"bow_tip_u")
	var tl := _bone(&"bow_tip_l")
	var pinch := _bone(&"draw_r")
	var grip := _bone(&"bow_l")
	if tu < 0 or tl < 0:
		return
	var xf := skel.global_transform
	var a := xf * skel.get_bone_global_pose(tu).origin
	var c := xf * skel.get_bone_global_pose(tl).origin
	var drawn := draw > 0.05 and pinch >= 0
	var hand := xf * skel.get_bone_global_pose(pinch).origin if pinch >= 0 else (a + c) * 0.5
	# The string comes off its rest line onto the fingers over the first part of
	# the draw rather than jumping to them.
	var mid := ((a + c) * 0.5).lerp(hand, clampf(draw * 4.0, 0.0, 1.0)) if pinch >= 0 else (a + c) * 0.5
	_stretch(string_u, a, mid)
	_stretch(string_l, c, mid)
	if arrow != null:
		arrow.visible = drawn
		if drawn and grip >= 0:
			var g := xf * skel.get_bone_global_pose(grip).origin
			var along := g - hand
			if along.length() > 0.05:
				arrow.global_transform = Transform3D(Basis.looking_at(along, Vector3.UP), hand)


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
