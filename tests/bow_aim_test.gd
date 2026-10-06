extends SceneTree

## Avtandil's shots go into what he shoots at, with the hunter's bow: a
## skeleton held still in the test arena (Hold still) is struck by every
## shot, drawn or snapped, locked on at 12 m (even when it was held still in
## the middle of a step, its velocity left over) and with the crosshair held
## on its chest at 12 and 22 m, and the arrows land about the body, not
## about its feet.
##
##   godot --headless --path . --script res://tests/bow_aim_test.gd

var _failed := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _initialize() -> void:
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"avtandil")
	for case: Array in [[12.0, false, false], [12.0, false, true], [12.0, true, false], [22.0, true, false]]:
		await _range(case[0], case[1], case[2])
	Input.action_release("attack")
	print("bow_aim_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


func _range(dist: float, free: bool, stale: bool) -> void:
	var world: World = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(world)
	await _wait(30)
	var panel := world.get_node("ArenaPanel") as ArenaPanel
	panel._clear()
	panel._wait_for_blow = false
	var hero := world.player()
	hero.immortal = true
	var rig: Node = hero.rig
	var custom: int = (rig.get("faces") as Array).find(&"custom")
	if custom >= 0:
		hero.set_face(custom)
	var look: Dictionary = rig.call("get_look")
	look["w"] = "bow"
	hero.set_look(look)
	await _wait(5)
	var fwd := -hero.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	panel._frozen = true
	var body := panel.call_up("res://scenes/enemies/pack/skeleton.tscn", false,
			hero.global_position + fwd * dist) as CharacterBody3D
	body.set("max_health", 99999.0)
	body.set("health", 99999.0)
	var hurt := [0]
	body.connect("hurt", func(_h: float) -> void: hurt[0] += 1)
	await _wait(20)
	if stale:
		# held still mid-stride: the velocity it had is left on it
		body.velocity = Vector3(1.4, -4.0, 1.0)
	if not free:
		Input.action_press("lock_on")
		await _wait(2)
		Input.action_release("lock_on")
	await _wait(20)
	var shots := 0
	var heights: Array[float] = []
	var seen := {}
	for shot in 4:
		Input.action_press("attack")
		for f in (80 if shot % 2 == 0 else 20):
			await physics_frame
			if free:
				# the crosshair kept on its chest
				var chest := body.global_position + Vector3.UP * 1.1
				var to_c := chest - hero.camera_rig.global_position
				hero.camera_rig.rotation.y = atan2(-to_c.x, -to_c.z)
				var tc := chest - hero.camera.global_position
				var look_dir := -hero.camera.global_transform.basis.z
				hero.spring_arm.rotation.x += atan2(tc.y, Vector2(tc.x, tc.z).length()) \
						- atan2(look_dir.y, Vector2(look_dir.x, look_dir.z).length())
		Input.action_release("attack")
		shots += 1
		var arrow: Arrow = null
		var last := Vector3.ZERO
		for f in 60:
			await physics_frame
			for n in Blood.world_of(hero).get_children():
				if n is Arrow and not seen.has(n):
					seen[n] = true
					arrow = n
			if arrow != null and is_instance_valid(arrow):
				last = arrow.global_position
		heights.append(last.y - body.global_position.y)
		await _wait(20)
	var how := ("crosshair on it" if free else "locked") + (", held mid-step" if stale else "")
	_check("%.0f m, %s: every shot strikes it" % [dist, how], hurt[0] == shots, "%d of %d" % [hurt[0], shots])
	var low := 9.0
	for h in heights:
		low = minf(low, h)
	_check("%.0f m, %s: about the body, not its feet" % [dist, how], low > 0.55, "heights %s" % str(heights))
	world.queue_free()
	for i in 3:
		await process_frame
