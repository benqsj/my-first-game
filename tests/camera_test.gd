extends SceneTree
## The view (2026-10-22, the user's word):
## - its arm a ball swept out, not a ray;
## - swung round into a wall at his back, it stays on his side of it;
## - locked on a great foe it stands further off, and comes back in after;
##   eased, never a jump.
##   Godot --headless --path . --script res://tests/camera_test.gd

var _failures := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node("Game")
	game.set(&"dungeon_id", 0)
	game.call("choose", &"tariel")
	var world: World = load("res://scenes/world/dungeon.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await _wait(5)
	while world.get_node_or_null("PipelineWarmup") != null:
		await process_frame
	var d := world.get_node("Level/Rooms") as Dungeon
	var hero := world.player()
	hero.immortal = true
	_check("the arm is a ball", hero.spring_arm.shape is SphereShape3D)

	var step := 2
	d._take_down(d.current)
	d._arrive_at(step, "crypt", "")
	await _wait(10)
	for b: Variant in d._room_foes[step]:
		if is_instance_valid(b):
			(b as Node).queue_free()
	d._room_foes[step] = []
	var c := d.centre(step)
	var w: float = d._room(step)["w"]
	hero.global_position = c + Vector3(w * 0.5 - 1.6, 0.3, 6.0)
	var inside := true
	var jump := 0.0
	var last := hero.camera.global_position
	for f in 120:
		hero.velocity = Vector3.ZERO
		hero.camera_rig.rotation.y = PI * 0.5
		hero.spring_arm.rotation.x = deg_to_rad(-14.0)
		await process_frame
		if f > 20:
			var pq := PhysicsPointQueryParameters3D.new()
			pq.position = hero.camera.global_position
			pq.collision_mask = 1
			if not hero.get_world_3d().direct_space_state.intersect_point(pq, 1).is_empty():
				inside = false
			jump = maxf(jump, hero.camera.global_position.distance_to(last))
		last = hero.camera.global_position
	_check("swung into the wall at his back: never inside anything solid", inside,
			"camera x %.2f, wall at %.2f" % [hero.camera.global_position.x, c.x + w * 0.5])
	# the wall behind him gone: it eases back out
	hero.camera_rig.rotation.y = -PI * 0.5
	var lengths: Array[float] = []
	for f in 60:
		hero.camera_rig.rotation.y = -PI * 0.5
		await process_frame
		lengths.append(hero.spring_arm.spring_length)
	var step_most := 0.0
	for k in range(1, lengths.size()):
		step_most = maxf(step_most, lengths[k] - lengths[k - 1])
	_check("back out eased, not a jump", step_most < 0.2 and lengths[-1] > lengths[0] + 0.5, "%.2f most a frame, now %.2f" % [step_most, lengths[-1]])

	var last_i := d.steps.size() - 1
	d._take_down(d.current)
	d._arrive_at(last_i, "throne", "")
	await _wait(20)
	var lord: Node3D = d._lord_fight.lord if is_instance_valid(d._lord_fight) else null
	_check("the lord there", lord != null)
	if lord == null:
		_end()
		return
	var lc := d.centre(last_i)
	hero.global_position = lc + Vector3(0, 0.3, 4.0)
	lord.global_position = lc + Vector3(0, 0.3, -1.5)
	lord.set_physics_process(false)
	var rest := hero.spring_arm.spring_length
	hero.call(&"_hold_target", lord)
	await create_timer(3.0).timeout
	var far := hero.spring_arm.spring_length
	_check("locked on the lord: the view wants to stand further off", float(hero.get(&"_big_view")) > 0.95
			and far > rest, "%.2f -> %.2f, wide %.2f" % [rest, far, float(hero.get(&"_big_view"))])
	hero.call(&"_drop_target")
	# away from him, out of the fight
	hero.global_position = lc + Vector3(0, 0.3, 30.0)
	await create_timer(3.0).timeout
	_check("let go, nothing great fighting him: back in", float(hero.get(&"_big_view")) < 0.05,
			"wide %.2f, arm %.2f" % [float(hero.get(&"_big_view")), hero.spring_arm.spring_length])
	_end()


func _end() -> void:
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)
