extends SceneTree

## [VisualSmoother]: a body moved on physics ticks is drawn between them, and
## nothing else ever sees the offset.
##
##     godot --headless --path . --script res://tests/smoother_test.gd

const SPEED := 6.0

var _failures := 0
var _body: CharacterBody3D
var _model: Node3D
var _smoother: VisualSmoother
## What the model's own transform read as from inside every physics tick.
var _seen_in_ticks: Array[Transform3D] = []


class Mover:
	extends Node
	var body: CharacterBody3D
	var seen: Array[Transform3D]
	var model: Node3D

	func _physics_process(delta: float) -> void:
		seen.append(model.transform)
		body.global_position += Vector3(SPEED * delta, 0.0, 0.0)


func _initialize() -> void:
	# A frame rate that is not the tick rate, so frames fall between ticks.
	Engine.max_fps = 0
	Engine.physics_ticks_per_second = 20
	_body = CharacterBody3D.new()
	root.add_child(_body)
	_model = Node3D.new()
	_model.name = "Visuals"
	_model.scale = Vector3.ONE * 1.25
	_model.position = Vector3(0.0, 0.1, 0.0)
	_body.add_child(_model)
	_smoother = VisualSmoother.attach(_body, _model)
	var mover := Mover.new()
	mover.body = _body
	mover.seen = _seen_in_ticks
	mover.model = _model
	_body.add_child(mover)
	var own := _model.transform

	for i in 30:
		await physics_frame
	var between := 0
	var frames := 0
	var behind_ok := true
	for i in 200:
		await process_frame
		frames += 1
		# Read after every `_process` has run: this is what is drawn.
		var drawn := _model.global_position.x
		var body_x := _body.global_position.x
		var f := Engine.get_physics_interpolation_fraction()
		# Drawn at most one tick behind the body, never ahead of it.
		if drawn > body_x + 0.0001 or drawn < body_x - SPEED / 20.0 - 0.0001:
			behind_ok = false
		if f > 0.05 and f < 0.95 and absf(drawn - body_x) > 0.001:
			between += 1
		await create_timer(0.004).timeout
	_check("the model is drawn between the body's ticks", between > 10, "%d of %d frames" % [between, frames])
	_check("never ahead of the body, at most a tick behind", behind_ok)
	var clean := true
	for t in _seen_in_ticks:
		if not t.is_equal_approx(own):
			clean = false
			break
	_check("inside a tick the model is where it was put", clean)
	_check("its own scale is kept", _model.scale.is_equal_approx(Vector3.ONE * 1.25) or _model.transform.basis.get_scale().is_equal_approx(Vector3.ONE * 1.25))
	# A teleport is not slid along.
	_body.global_position += Vector3(100.0, 0.0, 0.0)
	for i in 3:
		await physics_frame
	await process_frame
	_check("a teleport is drawn at once", absf(_model.global_position.x - _body.global_position.x) < SPEED)
	# Taken out of the tree, the model is left as it was found.
	_smoother.get_parent().remove_child(_smoother)
	_check("taken away, it leaves the model as it was", _model.transform.is_equal_approx(own))
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok   - %s" % label)
	else:
		_failures += 1
		print("  FAIL - %s %s" % [label, ("(%s)" % detail) if detail else ""])
