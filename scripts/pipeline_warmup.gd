class_name PipelineWarmup
extends Node

## Draws the whole level once, behind a black screen, before play starts.
##
## Godot builds a render pipeline the first time it draws a given material in a
## given pass, and building one costs anywhere from a few milliseconds to most
## of a second. Left alone that bill is paid *during* play, a piece at a time,
## whenever something is seen for the first time — which is what a walk across
## this level feels like: smooth, then a lurch as a house or a creature comes
## round a corner, then smooth again. Profiling it is unambiguous: the frame
## times settle to a flat 7.6 ms once everything has been on screen once, and
## nothing that is switched off afterwards makes any difference at all.
##
## So the level is shown to the renderer up front instead. A handful of frames
## from vantage points that between them see all of it, with the screen held
## black, and the stalls happen here rather than in front of the player.
##
## This is a warm-up, not a loading screen: nothing is loaded, and the scene is
## already live behind the black. Skipped without a display, where there are no
## pipelines to build.

## Distance from the middle of the level for the ground-level poses. Wide enough
## to hold the far side in shot at `field_of_view`.
##
## Zero works it out from the level instead, which is what it is left at: a
## number typed in here goes stale the moment the ground changes size, and it
## goes stale *silently* — the warm-up still runs, it simply stops seeing the
## outer half of the map, and the stalls it was there to prevent come back.
@export var ring_radius: float = 0.0
## Height of the overhead poses. Zero works it out from the level.
@export var ceiling: float = 0.0
## What the level is measured by, when the two above are left to work themselves
## out. The ground plane, not everything visible — the mountains on the skyline
## are two hundred metres further out than anything that is ever walked on, and
## measuring against them would put every pose out where the whole level is a
## smudge in the distance.
@export var measure_from: NodePath = ^"Level/Ground"
## Deliberately wide: what matters is how much is inside the frustum, not
## whether the framing looks like anything.
@export var field_of_view: float = 100.0
## Frames spent on each pose. Two, because a pipeline built while drawing one
## frame is only proven by the next one not stalling.
@export var frames_per_pose: int = 2
## Off skips the whole thing, for when the stutter is the thing being measured.
@export var enabled: bool = true

var _camera: Camera3D
var _cover: CanvasLayer
var _props: Node3D
var _restore: Camera3D
var _poses: Array[Transform3D] = []
var _pose: int = 0
var _left: int = 0


func _ready() -> void:
	if not enabled or DisplayServer.get_name() == "headless":
		queue_free()
		return

	var world := get_parent() as Node3D
	if world == null:
		queue_free()
		return

	_poses = _plan(_bounds(world))
	if _poses.is_empty():
		queue_free()
		return

	_cover = CanvasLayer.new()
	_cover.layer = 128
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.add_child(black)
	add_child(_cover)

	_restore = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.fov = field_of_view
	# The level is 240 m across and the poses stand off the edge of it.
	_camera.far = 600.0
	# Hung off *this* node, not off the level.
	#
	# `_ready()` runs while the level is still handing readiness down to its
	# children, and a node in the middle of that refuses to take another one:
	# `world.add_child()` here fails outright with "parent node is busy setting
	# up children". It failed silently, too — an unparented camera cannot be
	# made current and cannot be moved, so the warm-up spent its frames drawing
	# nothing and every pipeline it was supposed to compile got compiled on the
	# first frame the player saw instead.
	#
	# This node is a plain `Node`, so the camera is the root of its own transform
	# chain and the poses below are already in world space. Nothing else changes.
	add_child(_camera)
	_camera.current = true

	_left = frames_per_pose
	_camera.global_transform = _poses[0]

	# What only shows up in a fight — a puglin's mud in the air and over the
	# eyes — built now too: the first lump to hit used to stall the frame.
	_props = MudBall.warm_props()
	_camera.add_child(_props)
	_props.position = Vector3(0.0, 0.0, -1.5)
	ScreenMud.splat(get_tree(), 1.0)


func _process(_delta: float) -> void:
	_left -= 1
	if _left > 0:
		return

	_pose += 1
	if _pose >= _poses.size():
		_finish()
		return
	_camera.global_transform = _poses[_pose]
	_left = frames_per_pose


## Hands the view back and gets out of the way. Everything built along the way
## stays built — the pipelines belong to the renderer, not to this node.
func _finish() -> void:
	ScreenMud.clear(get_tree())
	if _restore != null and is_instance_valid(_restore):
		_restore.current = true
	if _camera != null:
		_camera.queue_free()
	queue_free()


## Vantage points that between them put every part of the level on screen.
##
## A ring at head height catches what the player will actually see — the near
## faces of things, lit and shadowed from the side — and the overhead pair
## catches whatever the ring had hidden behind something else.
func _plan(box: AABB) -> Array[Transform3D]:
	var middle := box.get_center()
	# Half the ground's longer side, plus enough to stand off the edge of it.
	var reach := maxf(box.size.x, box.size.z) * 0.5
	var ring := ring_radius if ring_radius > 0.0 else reach * 0.55
	var high := ceiling if ceiling > 0.0 else reach * 0.75

	var poses: Array[Transform3D] = []
	const AROUND := 6
	for i in AROUND:
		var angle := TAU * float(i) / AROUND
		var at := middle + Vector3(cos(angle), 0.0, sin(angle)) * ring
		at.y = box.position.y + 2.0
		poses.append(_looking(at, middle))
	poses.append(_looking(middle + Vector3.UP * high, middle + Vector3(0.1, 0.0, 0.0)))
	poses.append(_looking(middle + Vector3(ring * 0.5, high, ring * 0.5), middle))
	poses.append(_looking(middle + Vector3(-ring * 0.5, high, -ring * 0.5), middle))
	return poses


func _looking(from: Vector3, at: Vector3) -> Transform3D:
	return Transform3D.IDENTITY.translated(from).looking_at(at, Vector3.UP, true)


## How far the level actually reaches, so the poses do not have to be numbers
## that go stale the moment anything is moved.
func _bounds(world: Node3D) -> AABB:
	# The ground alone, when the level says which node that is. Everything else
	# visible includes the skyline, which is nowhere near the part being warmed.
	var ground := world.get_node_or_null(measure_from) as Node3D
	if ground != null:
		var box := AABB()
		var found := false
		for node in ground.find_children("*", "VisualInstance3D", true, true):
			var mesh := node as VisualInstance3D
			var here := mesh.global_transform * mesh.get_aabb()
			box = here if not found else box.merge(here)
			found = true
		if found:
			return box

	var whole := AABB()
	var started := false
	for node in world.find_children("*", "VisualInstance3D", true, false):
		var instance := node as VisualInstance3D
		var here := instance.global_transform * instance.get_aabb()
		whole = here if not started else whole.merge(here)
		started = true
	return whole if started else AABB(Vector3(-120.0, 0.0, -120.0), Vector3(240.0, 12.0, 240.0))
