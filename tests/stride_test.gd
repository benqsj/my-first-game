extends SceneTree
## Feet on the ground: a hero in YOUR OWN on the mannequin, driven by the
## game's own inputs, walking and running in the world. While a foot is the
## one standing (the lower of the two), it should stay where it is on the
## ground is measured (the figure's ankle, in the world)
## and should be under SLIDE_OK. And the evade thrown on the run should be a
## roll ahead, not the dodge that hops back.
##   Godot --headless --path . --script res://tests/stride_test.gd -- [hero] [run clip]

const SLIDE_OK := 0.45
var _failures := 0


func _check(what: String, ok: bool, detail: String) -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _initialize() -> void:
	# one frame drawn for each physics tick: headless, frames run free, and a
	# tick with no frame in it (the pose not moved on while the body has) or
	# two (the pose moved on twice) read as the standing foot sliding
	Engine.max_fps = Engine.physics_ticks_per_second
	var args := OS.get_cmdline_user_args()
	var hero := StringName(args[0]) if args.size() > 0 else &"tariel"
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", hero)
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var player: Player = world.player()
	player.immortal = true
	for e in world.get_node("Enemies").get_children():
		e.queue_free()
	var rig := player.rig as SkinnedRig
	player.set_look(PolysplitLook.default_look(hero, "m"))
	player.set_face(rig.faces.find(SkinnedRig.CUSTOM))
	# out on the open ground, facing up the field
	player.global_position = Vector3(0.0, 0.5, 26.0)
	player.camera_rig.rotation.y = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 20:
		await physics_frame
	_check("%s on the mannequin" % hero, rig.on_mannequin(), "")
	if args.size() > 1:
		# a run of the ones to try (Swordsman.RUNS)
		rig._set_run(StringName(args[1]))
	var lowest := {}
	var paces: Array = [["walk", ["walk", "move_forward"]], ["run", ["move_forward"]]]
	if player.profile != null and player.profile.can_block:
		paces.append(["guarded walk", ["block", "move_forward"]])
	for pace: Array in paces:
		for a: String in pace[1]:
			Input.action_press(a)
		for i in 90:
			await physics_frame
		var slides: Array[float] = []
		var rates: Array[float] = []
		var clip := ""
		var track := {"L_ankle_joint": [], "R_ankle_joint": []}
		for i in 90:
			await physics_frame
			# where the body is, not where it is drawn: the model is drawn a
			# fraction of a tick behind ([VisualSmoother]), by a different
			# fraction each frame, and that read as the planted foot sliding
			if player._smoother != null:
				player._smoother.take_off()
			var skel := rig._figure_skel
			for foot: String in track:
				(track[foot] as Array).append(skel.global_transform * skel.get_bone_global_pose(skel.find_bone(foot)).origin)
			rates.append(rig._anim.speed_scale)
			clip = rig._anim.current_animation
		# how low the feet go, over the ground he stands on
		var low := INF
		for foot: String in track:
			for p: Vector3 in track[foot]:
				low = minf(low, p.y - player.global_position.y)
		lowest[pace[0]] = low
		# a foot down flat (within 2 cm of its lowest) should not move
		for foot: String in track:
			var ps: Array = track[foot]
			var floor_y := INF
			for p: Vector3 in ps:
				floor_y = minf(floor_y, p.y)
			for i in range(1, ps.size()):
				var a: Vector3 = ps[i - 1]
				var b: Vector3 = ps[i]
				if a.y < floor_y + 0.02 and b.y < floor_y + 0.02:
					slides.append(Vector2(b.x - a.x, b.z - a.z).length() * Engine.physics_ticks_per_second)
		for a: String in pace[1]:
			Input.action_release(a)
		slides.sort()
		var median := slides[int(slides.size() * 0.5)] if not slides.is_empty() else INF
		var speed := Vector2(player.velocity.x, player.velocity.z).length()
		_check("%s: the standing foot stays put" % pace[0], median < SLIDE_OK,
				"(%s at x%.2f, %.1f m/s: the standing foot slides %.2f m/s)" % [clip, rates[rates.size() - 1], speed, median])
		for i in 30:
			await physics_frame
	if lowest.has("guarded walk"):
		_check("walking behind the guard, the feet stay out of the ground", float(lowest["guarded walk"])
				> float(lowest["walk"]) - 0.04, "(lowest ankle %.3f m, walking %.3f m)" % [lowest["guarded walk"], lowest["walk"]])
	# the evade on the run
	Input.action_press("move_forward")
	for i in 60:
		await physics_frame
	Input.action_press("dash")
	await physics_frame
	await physics_frame
	Input.action_release("dash")
	var evade := rig._anim.current_animation
	var hop: Array = Moveset.clip_meta(StringName(evade)).get("hop", [])
	_check("the evade on the run goes ahead", hop.is_empty() or float(hop[1]) > 0.0, "(%s)" % evade)
	Input.action_release("move_forward")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)
