class_name HitReact
extends RefCounted

## A blow seen on the body that took it: thrown over the way the blade was
## going — cut from its right, the body goes to its left — and sprung back.
##
## Laid over whatever the clips are playing, so it needs nothing authored and
## works on anything with a spine: the back is bent a share at each joint from
## the hips up (bones), or, for a body with no skeleton of its own, the whole
## of it is tipped over its feet. A spring, a little under-damped: the jolt, a
## touch past upright on the way back, and still. Blows that land on a body
## still thrown over add to it rather than start again, so a flurry rocks it.

## How hard it is pulled back upright, and how much the rocking is damped.
const STIFFNESS := 190.0
const DAMPING := 15.0
## Furthest over a body is thrown, radians.
const MAX_ANGLE := 0.55

var _skeleton: Skeleton3D
var _bones := PackedInt32Array()
var _shares := PackedFloat32Array()
var _body: Node3D
var _body_rest := Basis.IDENTITY
## How far over it is now and how fast it is going: rotation vectors (axis times
## radians) in world space.
var _angle := Vector3.ZERO
var _spin := Vector3.ZERO
var _was_on: bool = false


## Bends a skeleton: `names`, the chain from the hips up, each taking its
## `shares` of the whole (bones the skeleton does not have are skipped).
static func on_bones(skeleton: Skeleton3D, names: Array, shares: Array) -> HitReact:
	var react := HitReact.new()
	react._skeleton = skeleton
	if skeleton != null:
		for i in names.size():
			var bone := skeleton.find_bone(String(names[i]))
			if bone >= 0:
				react._bones.append(bone)
				react._shares.append(float(shares[i]))
	return react


## Tips a whole body over its feet — for one with no bones to bend.
static func on_body(body: Node3D) -> HitReact:
	var react := HitReact.new()
	react._body = body
	if body != null:
		react._body_rest = body.basis
	return react


## A blow going `along` (world space), thrown over at `strength` (radians a
## second: 3 is a cut, 5 a hard one). `away`, from whoever struck to the body:
## what it is thrown along instead when the blow came straight down.
func strike(along: Vector3, strength: float, away: Vector3 = Vector3.ZERO) -> void:
	var push := Vector3(along.x, 0.0, along.z)
	# A chop from above has little to say about which side: it bows the body
	# back away from whoever swung it.
	if push.length_squared() < 0.09:
		var back := Vector3(away.x, 0.0, away.z)
		if back.length_squared() > 0.0001:
			push = push + back.normalized() * 0.6
	if push.length_squared() < 0.0001:
		return
	# Turning about up × push tips the top of the body toward push.
	_spin += Vector3.UP.cross(push.normalized()) * strength


## Puts the body straight at once and forgets the blow — for when something
## else is about to take the body over (a death fall).
func settle() -> void:
	_angle = Vector3.ZERO
	_spin = Vector3.ZERO
	_was_on = false
	if _body != null and is_instance_valid(_body):
		_body.basis = _body_rest


func is_on() -> bool:
	return _angle.length_squared() > 0.00001 or _spin.length_squared() > 0.0004


## Moves the spring on by `delta` and lays the bend over the pose. Call after
## the clips have posed the skeleton for the frame.
func drive(delta: float) -> void:
	if not is_on():
		if _was_on:
			_was_on = false
			_angle = Vector3.ZERO
			_spin = Vector3.ZERO
			if _body != null and is_instance_valid(_body):
				_body.basis = _body_rest
		return
	_was_on = true
	# Stepped in small pieces: a stiff spring and a long frame do not mix.
	var left := minf(delta, 0.1)
	while left > 0.0:
		var dt := minf(left, 1.0 / 120.0)
		left -= dt
		_spin += (-_angle * STIFFNESS - _spin * DAMPING) * dt
		_angle += _spin * dt
	if _angle.length() > MAX_ANGLE:
		_angle = _angle.normalized() * MAX_ANGLE
	_lay()


func _lay() -> void:
	var size := _angle.length()
	if size < 0.00001:
		return
	var axis := _angle / size
	if _skeleton != null and is_instance_valid(_skeleton):
		var frame := _skeleton.global_basis.orthonormalized()
		var inverse := frame.inverse()
		for i in _bones.size():
			var bone := _bones[i]
			# The turn, in the skeleton's own space, then in the bone's parent's.
			var turn := inverse * Basis(axis, size * _shares[i]) * frame
			var parent := _skeleton.get_bone_parent(bone)
			var above := Basis.IDENTITY
			if parent >= 0:
				above = _skeleton.get_bone_global_pose(parent).basis.orthonormalized()
			var local := Quaternion((above.inverse() * turn * above).orthonormalized())
			_skeleton.set_bone_pose_rotation(bone, (local * _skeleton.get_bone_pose_rotation(bone)).normalized())
	elif _body != null and is_instance_valid(_body):
		var parent := _body.get_parent() as Node3D
		var frame := parent.global_basis.orthonormalized() if parent != null else Basis.IDENTITY
		_body.basis = (frame.inverse() * Basis(axis, size) * frame) * _body_rest
