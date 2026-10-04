extends SceneTree

## The story's opening and the burnt village ([Intro], [VillageFire],
## [Cutscene], [DragonFlyby]):
## - a level loaded with no word from the menu has no story;
## - with it the hero lies unarmed in the wood under the film's camera, with
##   no body, HUD or creature of his own in sight;
## - what goes over is never seen (only its shadow), and the roofs catch;
## - he gets up facing the village, still unarmed, the wood's creatures away;
## - coming down the hill plays the sighting, and the fire then goes out;
## - coming in plays the arrival: the burnt houses fallen in, Datvi;
## - taking Datvi's job gives him his arms and fills the wood again;
## - the job rewarded puts its houses back up.
## Every film is skipped part-way, which is also what a player may do.
##
##     godot --headless --path . --fixed-fps 30 --script res://tests/intro_test.gd

var _failures := 0


func _initialize() -> void:
	var game := root.get_node_or_null("Game")

	# No word from the menu: no story.
	var plain: Node3D = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(plain)
	await _wait(12)
	var plain_player: Player = plain.call("player")
	_check("no story without the menu's word", (plain.get_node("Intro") as Intro).stage == Intro.Stage.NONE
			and plain.get_node_or_null("VillageFire") == null and not plain_player.unarmed)
	plain.queue_free()
	await _wait(3)

	game.call("choose", &"tariel")
	# The menu's word with the films off (as the game is now): straight into
	# the burnt village.
	game.set("story_pending", true)
	var quiet: Node3D = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(quiet)
	await _wait(40)
	var qi := quiet.get_node("Intro") as Intro
	var qp: Player = quiet.call("player")
	_check("no films: straight into the village", qi.stage == Intro.Stage.VILLAGE and qp.camera.current
			and qp.is_physics_processing() and quiet.get_node_or_null("Intro/Opening") == null)
	_check("the burnt houses already fallen in", qi.fire != null and qi.fire.is_ruined(&"House6")
			and qi.fire.is_ruined(&"Marani") and _lit(qi) == 6)
	_check("armed, the wood as it is", not qp.unarmed and _arms_seen(qp) > 0 and _creatures_seen(quiet, true) > 0)
	var qd := quiet.get_node("People/Datvi") as Node3D
	_check("on the square, by Datvi", qp.global_position.distance_to(qd.global_position) < 20.0,
			"%.1f m" % qp.global_position.distance_to(qd.global_position))
	quiet.queue_free()
	await _wait(3)

	# The films (kept to be put back), all of them.
	game.set("story_pending", true)
	var world: Node3D = load("res://scenes/world/greybox_world.tscn").instantiate()
	var intro := world.get_node("Intro") as Intro
	intro.films = true
	root.add_child(world)
	await _wait(40)
	_check("the menu's word is taken", not bool(game.get("story_pending")))
	var player: Player = world.call("player")
	_check("the opening film runs", intro.stage == Intro.Stage.OPENING, "stage %d" % intro.stage)
	_check("the hero is the film's: no physics of his own", not player.is_physics_processing())
	_check("the film's camera is the one drawn", not player.camera.current)
	var hud := player.get_node_or_null("Hud") as CanvasLayer
	_check("his HUD is hidden", hud == null or not hud.visible)
	_check("he lies in the glade up in the wood",
			Vector2(player.global_position.x, player.global_position.z).distance_to(Intro.LIE_AT) < 1.0,
			"%s" % player.global_position)
	_check("lying down (the clip held)", player.rig.current_clip() == Intro.LIE_DOWN,
			"%s" % player.rig.current_clip())
	_check("unarmed", player.unarmed)
	_check("no sword, no shield to be seen", _arms_seen(player) == 0, "%d seen" % _arms_seen(player))
	_check("no creature in the film", _creatures_seen(world, false) == 0)
	_check("the village is not burning yet", intro.fire != null and not intro.fire.is_burnt(&"Marani"))

	# Something goes over; the roofs catch.
	var saw_dragon := false
	var dragon_shown := false
	var t := 0.0
	while intro.stage == Intro.Stage.OPENING and t < 45.0:
		await process_frame
		t += 1.0 / 30.0
		if intro.dragon != null:
			saw_dragon = true
			for mesh: GeometryInstance3D in intro.dragon.find_children("*", "GeometryInstance3D", true, false):
				if mesh.is_visible_in_tree() \
						and mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
					dragon_shown = true
	_check("the dragon flew over", saw_dragon)
	_check("and was never seen, only its shadow", not dragon_shown)
	_check("the film ends in good time", intro.stage == Intro.Stage.TO_SIGHT, "stage %d after %.0f s" % [intro.stage, t])
	_check("the roofs are alight", _lit(intro) == 6, "%d" % _lit(intro))
	_check("the hero has his body back", player.is_physics_processing())
	_check("and his camera", player.camera.current)
	_check("standing, not lying", player.rig.current_clip() != Intro.LIE_DOWN)
	_check("still unarmed", player.unarmed and _arms_seen(player) == 0)
	var to_village := Vector2(Intro.LOOK_AT.x - player.global_position.x, Intro.LOOK_AT.y - player.global_position.z)
	var facing := Vector2(-player.global_basis.z.x, -player.global_basis.z.z)
	_check("up facing the way it went (the village)", facing.normalized().dot(to_village.normalized()) > 0.9,
			"%.2f" % facing.normalized().dot(to_village.normalized()))
	_check("the wood's creatures kept away", _creatures_seen(world, true) == 0, "%d" % _creatures_seen(world, true))
	_check("the rest back", _creatures_seen(world, false) > 0)

	# Down the hill: the sighting.
	player.global_position = Vector3(66.0, Terrain.height(66.0, Intro.SIGHT_Z - 2.0) + 0.2, Intro.SIGHT_Z - 2.0)
	await _wait(4)
	_check("coming down the hill plays the sighting", intro.stage == Intro.Stage.SIGHTING, "stage %d" % intro.stage)
	await _wait(40)
	(intro.get("_cut") as Cutscene).skip()
	await _wait(10)
	_check("then the way down to the village", intro.stage == Intro.Stage.TO_VILLAGE, "stage %d" % intro.stage)

	# Into the village: the fire out, the houses fallen in, Datvi.
	player.global_position = Vector3(64.0, Terrain.height(64.0, 80.0) + 0.2, 80.0)
	await _wait(4)
	_check("coming in plays the arrival", intro.stage == Intro.Stage.ARRIVAL, "stage %d" % intro.stage)
	await _wait(40)
	(intro.get("_cut") as Cutscene).skip()
	await _wait(30)
	_check("then the village", intro.stage == Intro.Stage.VILLAGE, "stage %d" % intro.stage)
	_check("the burnt houses fallen in", intro.fire.is_ruined(&"House6") and intro.fire.is_ruined(&"Marani"))
	var house := world.get_node("Level/Village/Houses/House6") as MeshInstance3D
	_check("the house itself gone from sight", not house.visible)
	_check("a ruin standing in its place", world.get_node_or_null("Level/Village/Houses/House6_Fallen") != null)
	var datvi := world.get_node("People/Datvi") as Node3D
	_check("he was brought to Datvi", player.global_position.distance_to(datvi.global_position) < 6.0,
			"%.1f m" % player.global_position.distance_to(datvi.global_position))
	_check("unarmed till he takes the job", player.unarmed)

	# The job taken: his arms, and the wood full again.
	var book := world.get_node("Quests") as QuestBook
	book.state[&"wolves"] = QuestBook.State.TAKEN
	book.changed.emit()
	await _wait(10)
	_check("Datvi's job gives him his arms", not player.unarmed and _arms_seen(player) > 0)
	_check("and the wood fills again", _creatures_seen(world, true) > 0)

	# Done: its two houses come back.
	book.state[&"wolves"] = QuestBook.State.REWARDED
	book.changed.emit()
	await _wait(100)
	_check("the wood's houses are rebuilt", not intro.fire.is_burnt(&"House6") and not intro.fire.is_burnt(&"House7")
			and not intro.fire.is_ruined(&"House6") and house.visible)
	_check("the others still fallen", intro.fire.is_ruined(&"Marani") and intro.fire.is_ruined(&"House2"))
	_check("the soot is washed off", house.material_overlay == null)
	_finish()


func _lit(intro: Intro) -> int:
	var n := 0
	for kind: StringName in intro.fire.kinds():
		if intro.fire.is_burnt(kind):
			n += 1
	return n


func _arms_seen(player: Player) -> int:
	var n := 0
	for mesh: MeshInstance3D in player.rig.find_children("*", "MeshInstance3D", true, false):
		if Intro.is_arm(mesh) and mesh.is_visible_in_tree():
			n += 1
	return n


## Creatures in sight; `wood_only` counts only those in the wolves' wood.
func _creatures_seen(world: Node3D, wood_only: bool) -> int:
	var n := 0
	for body in world.get_node("Enemies").get_children():
		var b3 := body as Node3D
		if b3 == null or not b3.visible:
			continue
		if wood_only and not Intro.WOOD.has_point(Vector2(b3.global_position.x, b3.global_position.z)):
			continue
		n += 1
	return n


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
