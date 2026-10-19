extends SceneTree
## The gates and the dungeons (portal_dungeons_plan.md, 2026-10-19):
## - `world`: a solo game's open world is peaceful (no camps, none of the
##   level's own creatures, no quests) and the five gates stand in it;
## - `dungeon`: the first dungeon's five rooms, each waking as the hero walks
##   in, its iron gate going up when the last of it is down, the room after
##   holding more; the boss down, the dungeon is closed, the hero is at its
##   last level (10) and a way out stands.
##   Godot --headless --path . --script res://tests/dungeon_test.gd -- world|dungeon

var _failures := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var part := args[0] if args.size() > 0 else "dungeon"
	if part == "world":
		await _world()
	else:
		await _dungeon()
	print("dungeon_test %s: %s" % [part, "All checks passed." if _failures == 0 else "%d FAILED" % _failures])
	quit(1 if _failures > 0 else 0)


func _world() -> void:
	var game := root.get_node_or_null("Game")
	game.set(&"peaceful", true)
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _wait(40)
	var creatures := world.get_node_or_null("Enemies")
	_check("no creatures in the open world", creatures != null and creatures.get_child_count() == 0,
			str(creatures.get_child_count() if creatures != null else -1))
	_check("no quests", world.get_node_or_null("Quests") == null and world.get_node_or_null("People/Datvi") == null)
	var gates := world.get_node_or_null("Portals") as Portals
	_check("five gates", gates != null and gates.gates.size() == 5)
	if gates != null:
		for i in gates.gates.size():
			var at := gates.gates[i].global_position
			print("    gate %d at %s, ground %.2f" % [i + 1, at, Terrain.height_under(at.x, at.z, 1.8)])
	var hero := world.player()
	_check("a hero", hero != null)


func _dungeon() -> void:
	var game := root.get_node_or_null("Game")
	game.set(&"dungeon_id", 0)
	var world: World = load("res://scenes/world/dungeon.tscn").instantiate()
	root.add_child(world)
	await _wait(40)
	var d := world.get_node("Level/Rooms") as Dungeon
	_check("five rooms", d.rooms.size() == 5)
	_check("the orc lord is the boss", String(Dungeon.BOSS[0]).ends_with("orc_chief.tscn"))
	_check("four iron gates", d.gates.size() == 4)
	var hero := world.player()
	_check("a hero in the first room", hero != null and d.room_at(hero.global_position) == 0,
			str(hero.global_position if hero != null else Vector3.ZERO))
	if hero == null:
		return
	hero.immortal = true
	var book := hero.get_node("Leveling") as Leveling
	_check("comes in at level 1", book.level == 1, str(book.level))
	var creatures := world.get_node("Enemies")
	_check("every room's creatures made at the start", creatures.get_child_count() == 31,
			str(creatures.get_child_count()))
	var counts: Array[int] = []
	for r in d.rooms.size():
		hero.global_position = d.centre(r) + Vector3(0.0, 0.3, 4.0)
		await _wait(20)
		_check("room %d wakes" % (r + 1), d.current == r, str(d.current))
		var alive := 0
		for body in creatures.get_children():
			if not bool(body.get("is_dead")) and String(body.name).begins_with("D0_R%d_" % r):
				alive += 1
		counts.append(alive)
		var expected := 0
		for entry: Array in d.rooms[r]["foes"]:
			expected += int(entry[1])
		_check("room %d holds its %d" % [r + 1, expected], alive == expected, str(alive))
		if r < d.gates.size():
			_check("its gate is down", d.gates[r].position.y < 0.1)
		if r == 2:
			# The crowd: of the twelve, two at him at most; the rest held back.
			await _wait(40)
			var at_him := 0
			var held := 0
			for body in creatures.get_children():
				if not bool(body.get("is_dead")) and "held_back" in body and String(body.name).begins_with("D0_R2_"):
					if bool(body.get("held_back")):
						held += 1
					else:
						at_him += 1
			_check("only two let at him", at_him <= Dungeon.CROWD and held >= expected - Dungeon.CROWD,
					"%d at him, %d held" % [at_him, held])
			_check("the dungeon's music", d.music_wanted() == &"dungeon")
		if r == 3:
			# The two orcs at a lone hero: one at him, the other waiting.
			await _wait(30)
			var waiting := 0
			for body in creatures.get_children():
				if body is PackBrute and not bool(body.get("is_dead")) and String(body.name).begins_with("D0_R3_"):
					if (body as PackBrute).held_back:
						waiting += 1
			_check("the orcs take turns", waiting == 1, str(waiting))
			_check("orcs show level 7", Leveling.level_of(creatures.get_node("D0_R3_0")) == 7)
		if r == 4:
			_check("comes to the lord at level 7", book.level == 7, str(book.level))
			_check("the lord shows level 8", Leveling.level_of(creatures.get_node("D0_R4_0")) == 8)
			_check("the boss's music", d.music_wanted() == &"dungeon_boss")
		for body in creatures.get_children():
			if not bool(body.get("is_dead")) and body.has_method("_die") and String(body.name).begins_with("D0_R%d_" % r):
				body.call("_die")
		await _wait(80)
		_check("room %d cleared" % (r + 1), d.cleared[r])
		if r < d.gates.size():
			_check("its gate is up", d.gates[r].position.y > 2.0, "%.2f" % d.gates[r].position.y)
		print("    level %d after room %d" % [book.level, r + 1])
	_check("the dungeon is closed", d.is_closed)
	_check("the hero is at level 10", book.level == 10, str(book.level))
	_check("a way out stands", world.get_node_or_null("Level/Rooms/WayOut") != null)
	print("    rooms held %s" % str(counts))
