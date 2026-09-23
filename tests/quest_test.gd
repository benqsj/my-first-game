extends SceneTree

## The quest givers and the quest book: that the three are where they should
## be and standing on something, that talking to one offers the job and a
## second word takes it, that the right deaths count and the wrong ones do not,
## and that the job can be handed in.
##
##     godot --headless --script res://tests/quest_test.gd

var _failures := 0


func _initialize() -> void:
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _wait(3)
	var player: Player = world.player()
	var book := world.get_node_or_null("Quests") as QuestBook
	_check("the level has a quest book", book != null)
	if book == null:
		_finish()
		return
	var givers: Array[QuestGiver] = []
	for node in world.find_children("*", "Node3D", true, false):
		if node is QuestGiver:
			givers.append(node)
	_check("three people with jobs", givers.size() == 3, "%d" % givers.size())
	await _wait(10)

	# Each stands on something, not in the air and not buried.
	var space := world.get_world_3d().direct_space_state
	for giver in givers:
		var ray := PhysicsRayQueryParameters3D.create(giver.global_position + Vector3.UP * 0.5,
				giver.global_position + Vector3.DOWN * 1.0, 1)
		var solids: Array[RID] = []
		for node in giver.find_children("*", "StaticBody3D", true, false):
			solids.append((node as StaticBody3D).get_rid())
		ray.exclude = solids
		var hit := space.intersect_ray(ray)
		var gap := giver.global_position.y - (hit["position"] as Vector3).y if not hit.is_empty() else 99.0
		_check("%s stands on the ground" % giver.npc_name, absf(gap) < 0.15, "%.2f m off it" % gap)
	var baqaq: QuestGiver = null
	var datvi: QuestGiver = null
	for giver in givers:
		if giver.quest == &"arkdeva":
			baqaq = giver
		elif giver.quest == &"wolves":
			datvi = giver
	var bay := world.get_node_or_null("Bay") as Marsh
	if baqaq != null and bay != null:
		_check("the fisherman is on the dock, above the water", baqaq.global_position.y > bay.water_level + 0.1,
				"y %.2f, water %.2f" % [baqaq.global_position.y, bay.water_level])

	# The creatures are sent away: this is about talking, not fighting.
	var wolves: Array[Node] = []
	for node in world.get_node("Enemies").get_children():
		if QuestBook.kind_of(node) == &"wolf":
			wolves.append(node)
		(node as Node).set_physics_process(false)
		(node as Node3D).global_position += Vector3.DOWN * 60.0
	_check("wolves are known as wolves", wolves.size() >= 4, "%d" % wolves.size())

	# --- Talking --------------------------------------------------------------
	player.global_position = datvi.global_position + Vector3(0.0, 0.3, 2.2)
	player.velocity = Vector3.ZERO
	await _wait(20)
	_check("close by, the book knows who you are next to", book._near == datvi)
	_check("and says so on screen", book._prompt.visible and book._prompt.text.contains("Datvi"),
			book._prompt.text)
	book.interact()
	await _wait(2)
	_check("talking to him offers the job", book._dialog.visible
			and book._dialog_text.text.contains("wolves"), book._dialog_text.text)
	book.interact()
	await _wait(2)
	_check("a second word takes it on", int(book.state[&"wolves"]) == QuestBook.State.TAKEN)
	_check("and it goes up in the corner", book._tracker.get_child_count() == 1)

	# --- Counting ---------------------------------------------------------------
	book.note_kill(&"imp")
	_check("an imp does not count for wolves", int(book.progress[&"wolves"]) == 0)
	for i in 3:
		wolves[i].set("is_dead", true)
	await _wait(30)
	_check("dead wolves are counted as they die", int(book.progress[&"wolves"]) == 3,
			"%d" % book.progress[&"wolves"])
	await _wait(30)
	_check("and not twice", int(book.progress[&"wolves"]) == 3, "%d" % book.progress[&"wolves"])
	wolves[3].set("is_dead", true)
	await _wait(30)
	_check("the fourth finishes it", int(book.state[&"wolves"]) == QuestBook.State.DONE)

	# --- Handing in -------------------------------------------------------------
	player.global_position = datvi.global_position + Vector3(0.0, 0.3, 2.2)
	await _wait(10)
	book.interact()
	await _wait(2)
	_check("he knows it is done", book._dialog_text.text.contains("Quiet"), book._dialog_text.text)
	book.interact()
	await _wait(2)
	_check("and it is handed in", int(book.state[&"wolves"]) == QuestBook.State.REWARDED)
	_check("and gone from the corner", book._tracker.get_child_count() == 0)

	# Walking off closes a conversation.
	book.interact()
	await _wait(2)
	player.global_position = datvi.global_position + Vector3(0.0, 0.3, 12.0)
	await _wait(10)
	_check("walking away ends it", not book._dialog.visible)
	_finish()


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _finish() -> void:
	print("")
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
