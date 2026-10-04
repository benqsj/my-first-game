extends SceneTree

## The story's opening and the burnt village ([Intro], [VillageFire],
## [Cutscene], [DragonFlyby]): that a level loaded with no word from the menu
## has no story; that with it the hero lies in the meadow under the film's
## camera with no body or HUD of his own; that the dragon flies and the
## roofs catch; that a skip puts the world where the film ends (all six
## buildings burning, the hero up with his camera back); that walking in
## among the houses plays the second film with Datvi; and that a rewarded job
## puts its buildings back.
##
##     godot --headless --path . --fixed-fps 30 --script res://tests/intro_test.gd

var _failures := 0


func _initialize() -> void:
	var game := root.get_node_or_null("Game")

	# No word from the menu: no story.
	var plain: Node3D = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(plain)
	await _wait(12)
	_check("no story without the menu's word", plain.get_node("Intro").get("stage") == 0
			and plain.get_node_or_null("VillageFire") == null)
	plain.queue_free()
	await _wait(3)

	game.call("choose", &"tariel")
	game.set("story_pending", true)
	var world: Node3D = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	var intro := world.get_node("Intro") as Intro
	await _wait(40)
	_check("the menu's word is taken", not bool(game.get("story_pending")))
	var player: Player = world.call("player")
	_check("the opening film runs", intro.stage == 1, "stage %d" % intro.stage)
	_check("the hero is the film's: no physics of his own", not player.is_physics_processing())
	_check("the film's camera is the one drawn", not player.camera.current)
	var hud := player.get_node_or_null("Hud") as CanvasLayer
	_check("his HUD is hidden", hud == null or not hud.visible)
	_check("he lies in the glade in the wolves' wood",
			Vector2(player.global_position.x, player.global_position.z).distance_to(Intro.LIE_AT) < 1.0,
			"%s" % player.global_position)
	_check("lying down (the clip held)", player.rig.current_clip() == Intro.LIE_DOWN,
			"%s" % player.rig.current_clip())
	var arms_seen := 0
	for mesh: MeshInstance3D in player.rig.find_children("*", "MeshInstance3D", true, false):
		if Intro.is_arm(mesh) and mesh.is_visible_in_tree():
			arms_seen += 1
	_check("unarmed: no sword, no shield", arms_seen == 0, "%d seen" % arms_seen)
	var creatures_seen := 0
	for body in world.get_node("Enemies").get_children():
		if (body as Node3D).visible:
			creatures_seen += 1
	_check("no creature in the film", creatures_seen == 0, "%d seen" % creatures_seen)
	_check("the village is not burning yet", intro.fire != null and not intro.fire.is_burnt(&"Marani"))

	# The dragon comes and the roofs catch.
	var saw_dragon := false
	var t := 0.0
	while intro.stage == 1 and t < 45.0:
		await process_frame
		t += 1.0 / 30.0
		if intro.dragon != null:
			saw_dragon = true
	_check("the dragon flew", saw_dragon)
	var lit := 0
	for kind: StringName in intro.fire.kinds():
		if intro.fire.is_burnt(kind):
			lit += 1
	_check("the film ends in good time", intro.stage == 2, "stage %d after %.0f s" % [intro.stage, t])
	_check("six buildings burn", lit == 6, "%d" % lit)
	_check("the hero has his body back", player.is_physics_processing())
	_check("and his camera", player.camera.current)
	_check("standing, not lying", player.rig.current_clip() != Intro.LIE_DOWN)
	var arms_back := 0
	for mesh: MeshInstance3D in player.rig.find_children("*", "MeshInstance3D", true, false):
		if Intro.is_arm(mesh) and mesh.is_visible_in_tree():
			arms_back += 1
	_check("his arms back after it", arms_back > 0)
	var near_glade := 0
	var far_shown := 0
	for body in world.get_node("Enemies").get_children():
		var b3 := body as Node3D
		var d := Vector2(b3.global_position.x, b3.global_position.z).distance_to(Intro.LIE_AT)
		if d < Intro.QUIET_ROUND and b3.visible:
			near_glade += 1
		elif d >= Intro.QUIET_ROUND and b3.visible:
			far_shown += 1
	_check("the creatures round the glade still away", near_glade == 0, "%d" % near_glade)
	_check("the rest back", far_shown > 0)
	var to_village := Vector2(Intro.LOOK_AT.x - player.global_position.x, Intro.LOOK_AT.y - player.global_position.z)
	var facing := Vector2(-player.global_basis.z.x, -player.global_basis.z.z)
	_check("up facing the village", facing.normalized().dot(to_village.normalized()) > 0.9,
			"%.2f" % facing.normalized().dot(to_village.normalized()))

	# Into the village: Datvi's film; skipped, it hands the game back.
	player.global_position = Vector3(64.0, Terrain.height(64.0, 12.0) + 0.2, 12.0)
	await _wait(4)
	_check("coming in plays the arrival", intro.stage == 3, "stage %d" % intro.stage)
	var cut := intro.get("_cut") as Cutscene
	await _wait(20)
	if cut != null:
		cut.skip()
	await _wait(30)
	_check("then the village is his to rebuild", intro.stage == 4, "stage %d" % intro.stage)
	var datvi := world.get_node("People/Datvi") as Node3D
	var all_back := true
	for body in world.get_node("Enemies").get_children():
		if not (body as Node3D).visible:
			all_back = false
	_check("every creature back after the arrival", all_back)
	_check("he was brought to Datvi", player.global_position.distance_to(datvi.global_position) < 6.0,
			"%.1f m" % player.global_position.distance_to(datvi.global_position))

	# The wolves' job done: its two houses come back.
	var book := world.get_node("Quests") as QuestBook
	book.state[&"wolves"] = QuestBook.State.REWARDED
	book.changed.emit()
	await _wait(100)
	_check("the wolves' houses are rebuilt", not intro.fire.is_burnt(&"House6") and not intro.fire.is_burnt(&"House7"))
	_check("the others still burnt", intro.fire.is_burnt(&"Marani") and intro.fire.is_burnt(&"House2"))
	var house := world.get_node("Level/Village/Houses/House6") as MeshInstance3D
	_check("the soot is washed off", house.material_overlay == null)
	_finish()


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _check(what: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ok    ", what)
	else:
		_failures += 1
		print("  FAIL  ", what, ("  (" + detail + ")") if detail != "" else "")


func _finish() -> void:
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) failed." % _failures)
	quit(1 if _failures > 0 else 0)
