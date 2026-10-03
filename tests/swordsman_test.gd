extends SceneTree
## Tariel's sword and shield on the mannequin, as [Swordsman] designs it,
## driven by the game's own inputs in the world:
## - the string is A -> B -> C, the same every time;
## - the evade is Sword_Dash, played at its rate, cutting on the way, going
##   ahead, and given up as soon as he moves off once the dash is over;
## - the jump attack is Sword_GroundPound: the blade held over the head in the
##   air, played on at near its own pace when he lands, to its end, the chop
##   cutting.
##   Godot --headless --path . --script res://tests/swordsman_test.gd
var _failures := 0
var player: Player
var rig: SkinnedRig


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _initialize() -> void:
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _frames(2)
	player = world.player()
	player.immortal = true
	for e in world.get_node("Enemies").get_children():
		e.queue_free()
	rig = player.rig as SkinnedRig
	player.set_look(PolysplitLook.default_look(&"tariel", "m"))
	player.set_face(rig.faces.find(SkinnedRig.CUSTOM))
	player.global_position = Vector3(0.0, 0.5, 26.0)
	player.camera_rig.rotation.y = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(30)
	_check("on the mannequin", rig.on_mannequin())
	# the designed string and heavy blow, whatever was last picked to try
	rig._wear_string(0)

	# the string, twice
	for round in 2:
		var seen: Array[StringName] = []
		for i in 60:
			if i % 8 == 0 and seen.size() < 3:
				await _tap("attack")
			else:
				await physics_frame
			var s := rig.current_swing()
			if s != &"" and (seen.is_empty() or seen[seen.size() - 1] != s):
				seen.append(s)
		_check("string %d is A, B, C" % (round + 1), seen == Swordsman.STRING, str(seen))
		await _frames(180)

	# the evade, standing
	await _frames(30)
	var from := player.global_position
	await _tap("dash")
	await physics_frame
	var clip := rig._anim.current_animation
	_check("the evade is Sword_Dash", clip == "Sword_Dash", "(%s at x%.2f)" % [clip, rig._anim.speed_scale])
	var cut := false
	var ahead := -player.global_transform.basis.z
	while player.state == Player.State.DASHING:
		await physics_frame
		if not rig.get_cutting_edge().is_empty():
			cut = true
	var went := (player.global_position - from).dot(ahead)
	_check("it cuts on the way", cut)
	_check("it goes ahead 1.5-4 m", went > 1.5 and went < 4.0, "(%.2f m)" % went)
	_check("still in it after the dash (its recovery)", rig._anim.current_animation == "Sword_Dash")
	Input.action_press("move_forward")
	await _frames(12)
	_check("moving off gives it up", rig._anim.current_animation != "Sword_Dash",
			"(%s)" % rig._anim.current_animation)
	Input.action_release("move_forward")
	await _frames(90)

	# the jump attack
	await _tap("jump")
	await _frames(6)
	await _tap("attack")
	await physics_frame
	clip = rig._anim.current_animation
	_check("in the air it is Sword_GroundPound", clip == "Sword_GroundPound", "(%s)" % clip)
	var held := false
	while not player.is_on_floor():
		await physics_frame
		if rig._anim.speed_scale == 0.0 and rig._anim.current_animation == "Sword_GroundPound":
			held = true
	_check("the blade held over the head in the air", held)
	await _frames(3)
	var rate := rig._anim.speed_scale
	_check("landing it plays on near its own pace", rate > 0.8 and rate < 1.5, "(x%.2f)" % rate)
	var furthest := 0.0
	var chopped := false
	for i in 90:
		await physics_frame
		if rig._anim.current_animation == "Sword_GroundPound":
			furthest = maxf(furthest, rig._anim.current_animation_position / rig._anim.current_animation_length)
		if not rig.get_cutting_edge().is_empty():
			chopped = true
	_check("the chop cuts, on the ground", chopped)
	_check("played to its end", furthest > 0.9, "(%.2f)" % furthest)

	# the run: Kevin's sprint near its own pace (x0.88 at 6.3 m/s since the
	# figure's longer legs are counted in its pace, 2026-10-03)
	Input.action_press("move_forward")
	await _frames(70)
	_check("the run is Kevin's sprint near its own pace", rig._anim.current_animation == Swordsman.RUN
			and absf(rig._anim.speed_scale - 1.0) < 0.15, "(%s at x%.2f, %.1f m/s)" % [rig._anim.current_animation,
			rig._anim.speed_scale, Vector2(player.velocity.x, player.velocity.z).length()])
	Input.action_release("move_forward")
	await _frames(40)

	# crouched, the feet flat on the ground (FootFlat): the toes no lower than
	# the ankle by much
	Input.action_press("crouch")
	await _frames(40)
	var skel := rig.skeleton_now()
	var worst := 0.0
	for side in ["l", "r"]:
		var foot := skel.get_bone_global_pose(skel.find_bone("foot_" + side)).origin
		var ball := skel.get_bone_global_pose(skel.find_bone("ball_" + side)).origin
		var drop := foot.y - ball.y
		worst = maxf(worst, drop - (skel.get_bone_global_rest(skel.find_bone("foot_" + side)).origin.y
				- skel.get_bone_global_rest(skel.find_bone("ball_" + side)).origin.y))
	_check("crouched, the feet lie flat", worst < 0.04, "(%s: the toes %.3f m lower than standing)" % [
			rig._anim.current_animation, worst])
	Input.action_release("crouch")
	await _frames(30)

	# the strings to try: each one A, B, C... in its order
	for i in (rig.moves["string_sets"] as Array).size():
		var named := rig._wear_string(i)
		var want: Array = rig.moves["string_sets"][i]["clips"]
		var seen: Array[StringName] = []
		for k in 180:
			if k % 8 == 0 and seen.size() < want.size():
				await _tap("attack")
			else:
				await physics_frame
			var sw := rig.current_swing()
			if sw != &"" and (seen.is_empty() or seen[seen.size() - 1] != sw):
				seen.append(sw)
		_check("the string %s" % named, seen == want, str(seen))
		await _frames(150)
	# the deaths: his class's
	rig.die()
	await physics_frame
	_check("he dies his class's death", rig._anim.current_animation == Moveset.DEATHS["swordsman"],
			"(%s)" % rig._anim.current_animation)

	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)
