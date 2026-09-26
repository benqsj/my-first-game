extends SceneTree

## Levels ([Leveling]): every hero starts at 1; 3 wolves are level 2, 7 more
## level 3, 10 more level 4; each level grows the hero along his own line and
## heals him; only the heroes near a kill share in it; the hero's profile on
## disk is untouched.
##
##     godot --path . --headless --script res://tests/leveling_test.gd

var _failures := 0


func _initialize() -> void:
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _wait(3)
	var player := world.player()
	player.immortal = true
	var book := player.get_node_or_null(^"Leveling") as Leveling
	_check("every hero has his level book", book != null)
	if book == null:
		_finish()
		return
	_check("and starts at level 1 with nothing", book.level == 1 and book.xp == 0,
			"level %d, %d xp" % [book.level, book.xp])
	var wolves: Array[Wolf] = []
	for node in world.get_node("Enemies").get_children():
		(node as Node).set_physics_process(false)
		if node is Wolf:
			wolves.append(node)
	# The hill has sixteen; more come in the way a camp's would, and are watched
	# as they arrive.
	var wolf_scene := load("res://scenes/enemies/wolf.tscn") as PackedScene
	while wolves.size() < 21:
		var extra := wolf_scene.instantiate() as Wolf
		extra.name = "ExtraWolf%d" % wolves.size()
		world.get_node("Enemies").add_child(extra)
		extra.set_physics_process(false)
		wolves.append(extra)
	await _wait(2)
	var base_health := player.max_health
	var base_def := player.p_def
	var base_atk := player.profile.damage
	var ups := [0]
	book.leveled_up.connect(func(_l: int) -> void: ups[0] += 1)

	# One far off gives nothing.
	var far := wolves.pop_back() as Wolf
	far.global_position = player.global_position + Vector3(60.0, 0.0, 0.0)
	far._die()
	await _wait(2)
	_check("a wolf killed far away is nothing to him", book.xp == 0 and book.level == 1)

	var at := 0
	for want: Array in [[3, 2], [7, 3], [10, 4]]:
		for k in int(want[0]):
			var w := wolves[at]
			at += 1
			w.global_position = player.global_position + Vector3(2.0, 0.0, 0.0)
			if k == int(want[0]) - 1:
				player.health = player.max_health * 0.4
			w._die()
			await _wait(1)
		_check("%d wolves more: level %d" % [want[0], want[1]], book.level == int(want[1]) and book.xp == 0,
				"level %d, %d xp" % [book.level, book.xp])
		_check("  and whole again", is_equal_approx(player.health, player.max_health),
				"%.0f / %.0f" % [player.health, player.max_health])
	_check("three levels gained, one at a time", ups[0] == 3, "%d" % ups[0])
	var g: Dictionary = Leveling.GROWTH[&"tariel"]
	_check("Tariel grew by his line: health", is_equal_approx(player.max_health, base_health + 3.0 * float(g["hp"])),
			"%.0f" % player.max_health)
	_check("  p.def", is_equal_approx(player.p_def, base_def + 3.0 * float(g["p_def"])), "%.1f" % player.p_def)
	_check("  p.atk (his own copy)", is_equal_approx(player.profile.damage, base_atk + 3.0 * float(g["p_atk"])),
			"%.1f" % player.profile.damage)
	var disk := load("res://scenes/player/tariel.tres") as CharacterProfile
	_check("the profile everyone shares is untouched", is_equal_approx(disk.damage, base_atk)
			and is_equal_approx(disk.max_health, base_health))
	var imp: Node = load("res://scenes/enemies/imp.tscn").instantiate()
	var orc: Node = load("res://scenes/enemies/orc_greataxe.tscn").instantiate()
	_check("a wolf is worth 10, an imp 6, an orc 30", Leveling.worth(wolves[0]) == 10
			and Leveling.worth(imp) == 6 and Leveling.worth(orc) == 30)
	imp.free()
	orc.free()
	_check("the hud shows it", player.get("_hud") == null or (player.get("_hud") as PlayerHud)._book == book)
	_finish()


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _finish() -> void:
	print("\n%s" % ("All checks passed." if _failures == 0 else "%d check(s) failed." % _failures))
	quit(1 if _failures else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok   - %s" % label)
	else:
		_failures += 1
		print("  FAIL - %s %s" % [label, ("(%s)" % detail) if detail else ""])
