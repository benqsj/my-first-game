extends SceneTree
## TARIEL_POLISH.md 10, stepping round what he is locked on: behind the raised
## shield or walking, every way he goes he keeps facing it, his legs stepping
## the way he goes (the strafe walks under the guard); running, he turns the
## way he runs, as before.
##   Godot --headless --path . --script res://tests/lock_strafe_test.gd

var _failures := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var modes: Array = ["block", "walk", "run"]
	var want := {"move_forward": "Forward", "move_back": "Backward", "move_left": "Left", "move_right": "Right"}
	var world: World = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(world)
	for i in 30:
		await physics_frame
	var panel := world.get_node("ArenaPanel") as ArenaPanel
	panel._clear()
	panel._wait_for_blow = false
	var hero := world.player()
	hero.immortal = true
	hero.call(&"_set_weapons_stowed", false)
	for i in 20:
		await physics_frame
	var fwd := -hero.global_basis.z
	var body := panel.call_up("res://scenes/enemies/pack/skeleton.tscn", false, hero.global_position + fwd * 4.0) as Node3D
	for i in 5:
		await physics_frame
	body.set_physics_process(false)
	body.process_mode = Node.PROCESS_MODE_DISABLED
	hero._hold_target(body)
	var rig := hero.rig as SkinnedRig
	for mode: String in modes:
		if mode == "block":
			Input.action_press("block")
		elif mode == "walk":
			Input.action_press("walk")
		for dir: String in ["move_forward", "move_back", "move_left", "move_right"]:
			Input.action_press(dir)
			var clips := {}
			var faced := 0.0
			for f in 80:
				await physics_frame
				# the legs: the walk under the guard, or the walk itself
				clips[String(rig._stride_clip if mode == "block" else rig._anim.current_animation)] = true
				var to := body.global_position - hero.global_position
				to.y = 0.0
				faced += (-hero.global_basis.z).dot(to.normalized())
			Input.action_release(dir)
			var v := hero.velocity
			var facing := faced / 80.0
			var last := String(rig._stride_clip if mode == "block" else rig._anim.current_animation)
			print("  %s %s facing %.2f speed %.2f clips %s" % [mode, dir, facing, Vector2(v.x, v.z).length(), clips.keys()])
			if mode == "run":
				if dir == "move_left" or dir == "move_right":
					_check("running %s locked on: turned the way he runs" % dir, facing < 0.5, "%.2f" % facing)
			else:
				_check("%s, %s locked on: facing it" % [mode, dir], facing > 0.9, "%.2f" % facing)
				_check("%s, %s: the legs step that way" % [mode, dir], last.ends_with(want[dir]), last)
			for f in 25:
				await physics_frame
		Input.action_release("block")
		Input.action_release("walk")
		for f in 20:
			await physics_frame
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)
