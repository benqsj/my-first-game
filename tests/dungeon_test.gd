extends SceneTree
## The gates and the dungeons (portal_dungeons_plan.md, 2026-10-19):
## - `world`: a solo game's open world is peaceful (no camps, none of the
##   level's own creatures, no quests) and the five gates stand in it;
## - `dungeon`: the first dungeon's run of five places: the first a hall, then
##   each time two portals to two places with two rewards, the one walked
##   into built and its creatures woken; the reward given when it is cleared;
##   the lord last; the dungeon closed, the hero at its last level (10) and
##   a way out standing.
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
	if hero == null:
		return
	# What he has on now comes with him into a dungeon.
	var made: Dictionary = hero.look.duplicate(true)
	if made.is_empty():
		print("    (no look to carry: not on the mannequin)")
		return
	made["o"] = "none"
	hero.set_look(made)
	hero.remember_worn()
	var o_before := String(hero.look.get("o", ""))
	world.queue_free()
	await _wait(10)
	game.set(&"peaceful", false)
	game.set(&"dungeon_id", 0)
	var inside: World = load("res://scenes/world/dungeon.tscn").instantiate()
	root.add_child(inside)
	await _wait(60)
	var there := inside.player()
	_check("what he had on comes with him", there != null and String(there.look.get("o", "?")) == o_before,
			"%s / %s" % [o_before, String(there.look.get("o", "?")) if there != null else "-"])


func _dungeon() -> void:
	var game := root.get_node_or_null("Game")
	game.set(&"dungeon_id", 0)
	var world: World = load("res://scenes/world/dungeon.tscn").instantiate()
	root.add_child(world)
	await _wait(40)
	var d := world.get_node("Level/Rooms") as Dungeon
	# (the user's word, 2026-10-22: ten steps, every fifth a boss)
	_check("ten steps, the fifth and the tenth a boss's", d.steps.size() == 10 and d.stage_count() == 10
			and d.is_boss(4) and d.is_boss(9) and not d.is_boss(3), str(d.steps.size()))
	_check("the orc lord is the boss", String(Dungeon.BOSS[0]).ends_with("orc_chief.tscn"))
	_check("one place built to start with", d.rooms.size() == 1 and String(d.rooms[0]["place"]) == "hall")
	var hero := world.player()
	_check("a hero in the first place", hero != null and d.room_at(hero.global_position) == 0,
			str(hero.global_position if hero != null else Vector3.ZERO))
	if hero == null:
		return
	hero.immortal = true
	var book := hero.get_node("Leveling") as Leveling
	_check("comes in at level 1", book.level == 1, str(book.level))
	var creatures := world.get_node("Enemies")
	var counts: Array[int] = []
	var seen: Array[String] = []
	for r in d.steps.size():
		if r > 0:
			# Two portals, each its own place and reward; before a boss, his
			# and the spring.
			var n := d.choices.size()
			_check("step %d: two portals" % (r + 1), n == 2, str(n))
			_check("  each with a picture of where it goes", d.choices[0].view != null)
			if n == 2 and d.is_boss(r):
				_check("  the boss's way, and the spring beside it", String(d.choices[1].get_meta(&"place")) == "spring"
						and String(d.choices[0].get_meta(&"place")) != "spring")
			elif n == 2:
				var a := d.choices[0]
				var b := d.choices[1]
				_check("  to two places, for two rewards",
						a.get_meta(&"place") != b.get_meta(&"place") and a.get_meta(&"reward") != b.get_meta(&"reward"),
						"%s/%s %s/%s" % [a.get_meta(&"place"), a.get_meta(&"reward"), b.get_meta(&"place"), b.get_meta(&"reward")])
			# Walk into the first of them (a plain place: the goals have
			# their own test, orc_portal_test.gd).
			d.choices[0].set_meta(&"goal", "")
			hero.global_position = d.choices[0].global_position + Vector3(0.0, 0.3, 0.4)
			for f in 200:
				await physics_frame
				if d.rooms.size() == r + 1 and d.current == r and d.choices.is_empty() and not d._going:
					break
			_check("  through it to place %d (%s)" % [r + 1, d.rooms[r]["place"] if d.rooms.size() > r else "-"],
					d.current == r and d.room_at(hero.global_position) == r, str(hero.global_position))
		seen.append(String(d.rooms[r]["place"]))
		# It wakes a moment after he comes.
		for f in 160:
			await physics_frame
			if d._woken:
				break
		_check("place %d wakes" % (r + 1), d._woken)
		var alive := 0
		for body in creatures.get_children():
			if not bool(body.get("is_dead")) and String(body.name).begins_with("D0_R%d_" % r):
				alive += 1
		counts.append(alive)
		var expected := 0
		for entry: Array in d.rooms[r]["foes"]:
			expected += int(entry[1])
		_check("place %d holds its %d" % [r + 1, expected], alive == expected, str(alive))
		if r == 1 or r == 2:
			# No more than five up at once; the rest come through a rift once those are down.
			var up := 0
			for body in creatures.get_children():
				if not bool(body.get("is_dead")) and String(body.name).begins_with("D0_R%d_" % r) and (body as Node3D).visible:
					up += 1
			_check("  %d of them up at once" % up, up <= Dungeon.AT_ONCE and up > 0 and d.waves == int(ceil(float(expected) / 5.0)),
					"%d waves" % d.waves)
		if r == 1:
			for body in creatures.get_children():
				if not bool(body.get("is_dead")) and String(body.name).begins_with("D0_R1_") and (body as Node3D).visible:
					body.call("_die")
			for f in 400:
				await physics_frame
				if d.wave >= 2:
					break
			await _wait(10)
			var next := 0
			for body in creatures.get_children():
				if not bool(body.get("is_dead")) and String(body.name).begins_with("D0_R1_") and (body as Node3D).visible:
					next += 1
			_check("  the next wave out of the rift", d.wave == 2 and next > 0, "wave %d, %d up" % [d.wave, next])
		if r == 2:
			await _wait(40)
			var at_him := 0
			var held := 0
			for body in creatures.get_children():
				if not bool(body.get("is_dead")) and "held_back" in body and String(body.name).begins_with("D0_R2_") \
						and (body as Node3D).visible:
					if bool(body.get("held_back")):
						held += 1
					else:
						at_him += 1
			_check("only two let at him", at_him <= Dungeon.CROWD and held >= 1,
					"%d at him, %d held" % [at_him, held])
			_check("the dungeon's music", d.music_wanted() == &"dungeon")
		if r == 3:
			await _wait(30)
			var waiting := 0
			for body in creatures.get_children():
				if body is PackBrute and not bool(body.get("is_dead")) and String(body.name).begins_with("D0_R3_"):
					if (body as PackBrute).held_back:
						waiting += 1
			var orcs := 0
			for body in creatures.get_children():
				if body is PackBrute and not bool(body.get("is_dead")) and String(body.name).begins_with("D0_R3_"):
					orcs += 1
			_check("one orc, with two swords", orcs == 1 and waiting == 0, "%d orcs, %d waiting" % [orcs, waiting])
			_check("the orc shows level 4", Leveling.level_of(creatures.get_node("D0_R3_0")) == 4)
		if r == 4:
			_check("the first boss, alone", alive == 1 and d.is_boss(4), str(alive))
			_check("  its music", d.music_wanted() == &"dungeon_boss")
		if r == 9:
			_check("comes to the lord at level 7 or more", book.level >= 7, str(book.level))
			_check("the lord shows level 8", Leveling.level_of(creatures.get_node("D0_R9_0")) == 8)
			_check("the boss's music", d.music_wanted() == &"dungeon_boss")
		var health_before := hero.max_health
		for body in creatures.get_children():
			if not bool(body.get("is_dead")) and body.has_method("_die") and String(body.name).begins_with("D0_R%d_" % r):
				body.call("_die")
		await _wait(60)
		_check("place %d cleared" % (r + 1), d.cleared[r])
		if r > 0 and r < d.steps.size() - 1:
			# (a cursed place gives its reward twice over)
			_check("  its reward given (%s)" % d.rooms[r]["reward"], d.rewards_given.size() >= r)
			if String(d.rooms[r]["reward"]) == "life":
				_check("  more life", hero.max_health > health_before, "%.0f > %.0f" % [hero.max_health, health_before])
		print("    level %d after place %d" % [book.level, r + 1])
	_check("the dungeon is closed", d.is_closed)
	_check("the hero is at level 10", book.level == 10, str(book.level))
	_check("a way out stands", world.get_node_or_null("Level/Rooms/WayOut") != null)
	print("    places %s, held %s" % [str(seen), str(counts)])
	# A place to rest put in between is not a step (the user's word,
	# 2026-10-22): the run still counts ten, the rest the step it comes before.
	d._rest_between(5, "spring")
	_check("a rest put in: still ten steps", d.steps.size() == 11 and d.stage_count() == 10
			and d.is_rest(5) and d.stage_of(5) == 6 and d.stage_of(6) == 6 and d.stage_of(10) == 10
			and d.is_boss(10) and not d.cleared[5],
			"%d steps, %d counted, rest at 5 is %d" % [d.steps.size(), d.stage_count(), d.stage_of(5)])
