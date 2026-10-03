class_name VisualSmoother
extends Node

## Draws a body that moves on physics ticks where it is *between* two of them.
##
## A [CharacterBody3D] moves sixty times a second; the screen is drawn as often
## as the machine manages, which is never exactly sixty. At 45 frames a second
## one frame has no tick in it, the next one, the next two, so the body is
## drawn standing still, then a step on, then two steps on: a run judders, and
## the camera, smoothly following a body that jumps, makes the world judder
## round it when it turns. That is a good part of "it stutters when I run and
## turn the camera", at a frame rate that is not bad at all.
##
## Godot's own physics interpolation does this for the whole tree, but
## everything here that is moved from `_process` (the camera rig, the blade
## arcs, the bars over heads, the cloth) would then be drawn a tick late. So it
## is done for the bodies that need it: the body's last two ticks are kept, and
## its model ([member visual], a child of the body) is drawn where the body was
## the fraction of a tick ago that the frame is drawn at.
##
## Only *drawn* there. The offset is put on after everything else's `_process`
## and taken off again before anything else's next `_process` or
## `_physics_process` ([VisualSmoother.Undo]), so the game itself never sees
## it: the body, its collider, the model's own transform that other scripts set
## (a corpse sinking, a hero lifted by a skill) are all exactly what they were.

## More than this between two ticks is a teleport (a waystone, a respawn) and is
## drawn at once rather than slid along.
const JUMP := 4.0

var body: Node3D
var visual: Node3D

var _prev := Transform3D()
var _cur := Transform3D()
var _primed := false
## What was put on the model this frame (in the body's frame), to be taken off.
var _offset := Transform3D()
var _applied := false


## Smooths `model` (a child of `of`) between `of`'s physics ticks. Returns the
## smoother, already added under `of`.
static func attach(of: Node3D, model: Node3D) -> VisualSmoother:
	var smoother := VisualSmoother.new()
	smoother.name = "VisualSmoother"
	smoother.body = of
	smoother.visual = model
	# The tick is read after the body has moved in it; the offset goes on after
	# everything else has had its frame.
	smoother.process_physics_priority = 1000
	smoother.process_priority = 1000
	var undo := Undo.new()
	undo.name = "Undo"
	undo.smoother = smoother
	undo.process_physics_priority = -1000
	undo.process_priority = -1000
	smoother.add_child(undo)
	of.add_child(smoother)
	return smoother


func _ready() -> void:
	_cur = body.global_transform
	_prev = _cur


func _exit_tree() -> void:
	take_off()


func _physics_process(_delta: float) -> void:
	_prev = _cur
	_cur = body.global_transform
	if not _primed or _prev.origin.distance_to(_cur.origin) > JUMP:
		_prev = _cur
		_primed = true


func _process(_delta: float) -> void:
	if not _primed or not is_instance_valid(visual):
		return
	take_off()
	var now := body.global_transform
	if not now.is_equal_approx(_cur):
		# Moved outside a tick (put somewhere by a script): that is where it is.
		_cur = now
		_prev = now
	_offset = now.affine_inverse() * _interpolated()
	visual.transform = _offset * visual.transform
	_applied = true


## Takes this frame's offset off the model again.
func take_off() -> void:
	if _applied and is_instance_valid(visual):
		visual.transform = _offset.affine_inverse() * visual.transform
	_applied = false


func _interpolated() -> Transform3D:
	var f := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	var q := _prev.basis.get_rotation_quaternion().slerp(_cur.basis.get_rotation_quaternion(), f)
	return Transform3D(Basis(q).scaled(_cur.basis.get_scale()), _prev.origin.lerp(_cur.origin, f))


## Where the body is drawn this frame, for whatever follows it (the camera).
func drawn_at() -> Vector3:
	if not _primed:
		return body.global_position
	return _interpolated().origin


## Takes the offset off first thing in every tick and every frame.
class Undo:
	extends Node
	var smoother: VisualSmoother

	func _physics_process(_delta: float) -> void:
		smoother.take_off()

	func _process(_delta: float) -> void:
		smoother.take_off()
