class_name FigureFollower
extends Node
## Makes a figure on a skeleton of its own move as the rig's skeleton does.
##
## The figure is not fitted to the rig. It keeps its bones, its proportions
## and its weights; each frame, once the rig's pose is final (clips, stride,
## strike aim, every modifier — [signal Skeleton3D.skeleton_updated]), every
## mapped bone of the figure is turned in the world as its partner in the rig
## has been turned from its rest: `global = (pose * rest⁻¹) * figure_rest`.
## A bone left out of the map rides its parent as it rests. The hips alone
## are moved as well as turned, by the rig's hips' travel scaled to the
## figure's height, so a taller figure's feet still come down on the ground.
##
## Works only between skeletons whose rests point the limbs the same way
## (vepxis-art/tools/bl_blink.py turns the figure's rest onto the rig's).
##
## Two refinements, set before `setup()`:
## * `damp` (figure bone -> 0..1) turns that bone only part of the way its
##   partner has turned — a hunched run carried onto a figure that should
##   stand taller.
## * `mids` (figure bone -> [rig bone a, rig bone b, t]) turns a bone the rig
##   has no partner for part of the way between two that it has — a spine of
##   three bones following a spine of two, so the bend is shared.

## Emitted each time the figure has been posed off the rig, so what hangs off
## the figure's bones (a bow's string) can be put where they now are.
signal followed

## The rig's skeleton, whose pose is read.
var source: Skeleton3D
## The figure's skeleton, which is posed.
var target: Skeleton3D

var _order: PackedInt32Array = PackedInt32Array()
var _from: PackedInt32Array = PackedInt32Array()
var _src_rest: Array[Transform3D] = []
var _dst_rest: Array[Transform3D] = []
var _globals: Array[Transform3D] = []
var _hips: int = -1
var _scale: float = 1.0
var damp: Dictionary = {}
const DAMP_FULL_FROM := 0.6109  # 35 degrees
const DAMP_FULL_AT := 1.3963  # 80 degrees
var mids: Dictionary = {}
## The turn from the rig's skeleton's own frame into the figure's, where the
## two are not made the same way up (a Synty figure: centimetres, Z up, under
## a turned and shrunk skeleton node), set before `setup()`; each turn of the
## rig is carried across it. Identity for two alike.
var space: Basis = Basis.IDENTITY
var _damp: PackedFloat32Array = PackedFloat32Array()
var _mid: Dictionary = {}


## `map` is figure bone -> rig bone; `hips` names the figure's hips bone,
## whose partner's travel is carried over. False if either skeleton lacks a
## bone the map names.
func setup(src: Skeleton3D, dst: Skeleton3D, map: Dictionary, hips: StringName) -> bool:
	source = src
	target = dst
	var n := dst.get_bone_count()
	_from.resize(n)
	_from.fill(-1)
	for key: StringName in map:
		var t := dst.find_bone(String(key))
		var s := src.find_bone(String(map[key]))
		if t < 0 or s < 0:
			push_warning("FigureFollower: no bone %s / %s." % [key, map[key]])
			return false
		_from[t] = s
	_damp.resize(n)
	_damp.fill(1.0)
	for key: StringName in damp:
		var t := dst.find_bone(String(key))
		if t >= 0:
			_damp[t] = float(damp[key])
	for key: StringName in mids:
		var t := dst.find_bone(String(key))
		var m: Array = mids[key]
		var a := src.find_bone(String(m[0]))
		var b := src.find_bone(String(m[1]))
		if t >= 0 and a >= 0 and b >= 0 and _from[t] < 0:
			_mid[t] = [a, b, float(m[2])]
	# Parents before children.
	var done: Dictionary = {}
	while _order.size() < n:
		for i in n:
			if done.has(i):
				continue
			var p := dst.get_bone_parent(i)
			if p < 0 or done.has(p):
				_order.append(i)
				done[i] = true
	_src_rest.resize(src.get_bone_count())
	for i in src.get_bone_count():
		_src_rest[i] = src.get_bone_global_rest(i).orthonormalized()
	_dst_rest.resize(n)
	for i in n:
		_dst_rest[i] = dst.get_bone_global_rest(i).orthonormalized()
	_globals.resize(n)
	_hips = dst.find_bone(String(hips))
	if _hips >= 0 and _from[_hips] >= 0:
		var h_src := _src_rest[_from[_hips]].origin.y
		var up := (space * Vector3.UP).normalized()
		if h_src > 0.01:
			_scale = _dst_rest[_hips].origin.dot(up) / h_src
	src.skeleton_updated.connect(follow)
	follow()
	return true


## Poses the figure off the rig's pose as it stands now.
func follow() -> void:
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	for t in _order:
		var p := target.get_bone_parent(t)
		var parent_g: Transform3D = _globals[p] if p >= 0 else Transform3D.IDENTITY
		var rest_local := target.get_bone_rest(t)
		var g: Transform3D
		var s := _from[t]
		if _mid.has(t):
			var m: Array = _mid[t]
			var qa := _turn(m[0]).get_rotation_quaternion()
			var qb := _turn(m[1]).get_rotation_quaternion()
			var q := qa.slerp(qb, m[2])
			if _damp[t] < 1.0:
				q = Quaternion.IDENTITY.slerp(q, _damp_at(t, q))
			g.basis = Basis(q) * _dst_rest[t].basis
			g.origin = parent_g * rest_local.origin
		elif s >= 0:
			var pose := source.get_bone_global_pose(s).orthonormalized()
			var turn := _across(pose.basis * _src_rest[s].basis.inverse())
			if _damp[t] < 1.0:
				var q := turn.get_rotation_quaternion()
				turn = Basis(Quaternion.IDENTITY.slerp(q, _damp_at(t, q)))
			g.basis = turn * _dst_rest[t].basis
			if t == _hips:
				g.origin = _dst_rest[t].origin + space * (pose.origin - _src_rest[s].origin) * _scale
			else:
				g.origin = parent_g * rest_local.origin
		else:
			g = parent_g * rest_local
		_globals[t] = g
		var local := parent_g.affine_inverse() * g
		target.set_bone_pose_rotation(t, local.basis.get_rotation_quaternion())
		target.set_bone_pose_position(t, local.origin)
	followed.emit()


## How far a damped bone follows: its damping for a lean, easing back to the
## whole turn for a big one (a roll, a dive), which must not be cut short.
func _damp_at(t: int, q: Quaternion) -> float:
	var angle := q.get_angle()
	var k := clampf((angle - DAMP_FULL_FROM) / (DAMP_FULL_AT - DAMP_FULL_FROM), 0.0, 1.0)
	return lerpf(_damp[t], 1.0, k * k * (3.0 - 2.0 * k))


func _turn(s: int) -> Basis:
	var pose := source.get_bone_global_pose(s).orthonormalized()
	return _across(pose.basis * _src_rest[s].basis.inverse())


## A turn made in the rig's frame, as the same turn in the figure's.
func _across(turn: Basis) -> Basis:
	if space == Basis.IDENTITY:
		return turn
	return space * turn * space.inverse()
