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
	await _soles_flat(rig, player)
	var lowest := {}
	var paces: Array = [["walk", ["walk", "move_forward"]], ["jog", ["move_forward"]],
			["sprint", ["sprint", "move_forward"]]]
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
		if pace[0] == "jog":
			_check("with nothing held he jogs (Kevin's run, at his jog's pace)",
					clip == "KV_Run01_Forward" and absf(speed - player.jog_speed) < 0.3
					and player.stamina >= player.max_stamina - 0.01,
					"(%s, %.1f of %.1f m/s, stamina %.0f)" % [clip, speed, player.jog_speed, player.stamina])
		if pace[0] == "sprint":
			_check("Shift: the sprint at his run's pace, the stamina going",
					clip == "KV_Sprint01_Forward" and absf(speed - player.run_speed) < 0.4
					and player.stamina < player.max_stamina * 0.85,
					"(%s, %.1f of %.1f m/s, stamina %.0f)" % [clip, speed, player.run_speed, player.stamina])
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


## Standing, each sole lies flat: its heel as low as its toe. The figure's rest
## had the toes 7 cm up, the foot turned with the leg when its rest was set
## onto the mannequin's (vepxis-art tools/ps_creator.py; the user saw him
## stand on his heels, 2026-10-04).
func _soles_flat(rig: SkinnedRig, player: Player) -> void:
	for i in 60:
		await physics_frame
	if player._smoother != null:
		player._smoother.take_off()
	var skel := rig._figure_skel
	var fwd := -player.global_transform.basis.z
	for side: String in ["L", "R"]:
		var ankle_b := skel.find_bone(side + "_ankle_joint")
		var ball_b := skel.find_bone(side + "_ball_joint")
		var pts: Array[Vector3] = []
		for mi: MeshInstance3D in skel.find_children("*", "MeshInstance3D", true, false):
			if mi.visible and mi.skin != null:
				pts.append_array(_posed(mi, skel, [ankle_b, ball_b]))
		if pts.is_empty():
			_check("%s sole found" % side, false, "")
			continue
		var ankle := skel.global_transform * skel.get_bone_global_pose(ankle_b).origin
		var front := -INF
		var back := INF
		for p: Vector3 in pts:
			front = maxf(front, (p - ankle).dot(fwd))
			back = minf(back, (p - ankle).dot(fwd))
		var heel := INF
		var toe := INF
		for p: Vector3 in pts:
			var a := (p - ankle).dot(fwd)
			if a < back + 0.05:
				heel = minf(heel, p.y)
			if a > front - 0.05:
				toe = minf(toe, p.y)
		_check("standing, the %s sole lies flat" % side, absf(toe - heel) < 0.03,
				"(toe %.3f m over the heel; %s, on the floor %s, the ground's normal %s)" % [toe - heel,
				rig._anim.current_animation, player.is_on_floor(), player.get_floor_normal()])


## The points of a skinned mesh carried mostly by one of `bones`, posed.
func _posed(mi: MeshInstance3D, skel: Skeleton3D, bones: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var skin := mi.skin
	var to_bone: Array[int] = []
	for i in skin.get_bind_count():
		to_bone.append(skel.find_bone(skin.get_bind_name(i)))
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if arr[Mesh.ARRAY_BONES] == null:
			continue
		var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := bs.size() / vs.size()
		for v in vs.size():
			var best := 0
			for k in per:
				if ws[v * per + k] > ws[v * per + best]:
					best = k
			if not bones.has(to_bone[bs[v * per + best]]):
				continue
			var p := Vector3.ZERO
			for k in per:
				var w := ws[v * per + k]
				if w > 0.0:
					var j := bs[v * per + k]
					p += (skel.get_bone_global_pose(to_bone[j]) * skin.get_bind_pose(j) * vs[v]) * w
			out.append(skel.global_transform * p)
	return out
