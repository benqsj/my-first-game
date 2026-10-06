extends SceneTree
## The knight's great sword on the mannequin, as [GreatSword] designs it,
## driven by the game's own inputs in the world (the user's word, 2026-10-06):
## - the attack button throws the two-handed string, the block button the
##   one-handed one (no heavy blow on it any more);
## - a blow left alone comes back to guard slower than it cut, the last of a
##   string slower still.
##   Godot --headless --path . --script res://tests/great_sword_test.gd
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


## The blows a button throws, each pressed as soon as the last lets go.
func _string(action: String, count: int) -> Array[StringName]:
	var seen: Array[StringName] = []
	for i in count:
		await _next(action)
		seen.append(rig.current_swing())
	await _frames(40)
	return seen


## Pressed once the blow in hand lets go, and on till the new one is playing.
func _next(action: String) -> void:
	var was := rig.attack_serial
	for i in 120:
		if not player.is_committed():
			break
		await physics_frame
	await _tap(action)
	for i in 30:
		if rig.attack_serial != was and rig.current_swing() != &"":
			return
		await physics_frame


## Seconds from a press to the blow being over and the stance back, standing
## still; and the clip's pace before and after its cut.
func _one_blow(action: String) -> Dictionary:
	await _next(action)
	var t := 0.0
	var pace_cut := 0.0
	var pace_back := 0.0
	var clip := rig.current_swing()
	while rig.current_swing() != &"" and t < 6.0:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		var w: Vector2 = rig.cut_window.get(clip, Vector2.ZERO)
		var at := rig._progress()
		if rig._stop_left <= 0.0:
			if at < w.x:
				pace_cut = rig._anim.speed_scale
			elif at > w.y + rig.cut_margin + 0.02:
				pace_back = rig._anim.speed_scale
	return {"clip": clip, "t": t, "cut": pace_cut, "back": pace_back}


func _initialize() -> void:
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"warrior")
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _frames(2)
	player = world.player()
	player.immortal = true
	for e in world.get_node("Enemies").get_children():
		e.queue_free()
	rig = player.rig as SkinnedRig
	player.set_look(PolysplitLook.default_look(&"warrior", "m"))
	player.set_face(rig.faces.find(SkinnedRig.CUSTOM))
	player.global_position = Vector3(0.0, 0.5, 26.0)
	player.camera_rig.rotation.y = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(30)
	_check("on the mannequin", rig.on_mannequin())
	_check("two hands", rig.moves.get("kind", &"") == &"two_hands", str(rig.moves.get("kind", &"")))
	_check("the block button throws a string", rig.block_throws_string() and player._other_string_ready())
	_check("no heavy blow on it", not player._has_heavy())
	rig._wear_string(0)
	rig.wear_other_string(false)
	await _frames(10)

	var two: Array[StringName] = []
	two.assign(GreatSword.STRINGS[0]["clips"])
	var one: Array[StringName] = []
	one.assign(GreatSword.STRINGS[1]["clips"])
	var seen := await _string("attack", 4)
	_check("the attack button: the two-handed string", seen == two, str(seen))
	await _frames(200)
	seen = await _string("block", 4)
	_check("the block button: the one-handed string", seen == one, str(seen))
	await _frames(200)
	_check("the stamina held out", player.stamina > 0.0, "%.0f" % player.stamina)
	player.stamina = player.max_stamina

	# a first blow left alone, against the same blow with the old pace
	var slow := await _one_blow("attack")
	await _frames(200)
	var keep := [rig.recover_pace, rig.last_recover_pace, rig.recover_blend, rig.last_recover_blend]
	rig.recover_pace = 1.0
	rig.last_recover_pace = 1.0
	var plain := await _one_blow("attack")
	rig.recover_pace = keep[0]
	rig.last_recover_pace = keep[1]
	await _frames(200)
	print("    first blow %s: %.2f s back slowed (pace %.2f -> %.2f), %.2f s as made" % [slow["clip"], slow["t"],
			slow["cut"], slow["back"], plain["t"]])
	_check("the way back slower than the cut", slow["back"] < slow["cut"] * 0.8,
			"%.2f vs %.2f" % [slow["back"], slow["cut"]])
	_check("the blow lasts longer left alone", slow["t"] > plain["t"] + 0.2, "%.2f vs %.2f" % [slow["t"], plain["t"]])
	player.stamina = player.max_stamina

	# the string's last blow comes back slower still
	for i in 3:
		await _next("attack")
	var last := await _one_blow("attack")
	print("    last blow %s: %.2f s (pace %.2f -> %.2f)" % [last["clip"], last["t"], last["cut"], last["back"]])
	_check("the last blow is the string's end", last["clip"] == two[3], str(last["clip"]))
	_check("its way back slower than a first blow's", last["back"] / maxf(last["cut"], 0.01) \
			< slow["back"] / maxf(slow["cut"], 0.01) - 0.1,
			"%.2f vs %.2f" % [last["back"] / maxf(last["cut"], 0.01), slow["back"] / maxf(slow["cut"], 0.01)])

	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)
