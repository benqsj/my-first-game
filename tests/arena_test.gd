extends SceneTree

## The test arena: the hero stands on an empty floor with no camp raised, and
## every creature and boss on its board ([ArenaPanel]) can be called up in front
## of him — each one arrives, stands on the floor, lives a while among the rest
## and goes when the floor is cleared. The look arrows step through his looks.
##
##   godot --headless --path . --script res://tests/arena_test.gd

const ARENA := "res://scenes/world/test_arena.tscn"

var _failed := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: World = load(ARENA).instantiate()
	root.add_child(world)
	await _wait(2)
	var hero: Player = world.player()
	_check("the hero is spawned", hero != null)
	if hero == null:
		quit(1)
		return
	hero.immortal = true
	var creatures := world.get_node("Enemies")
	await _wait(20)
	var present := 0
	for entry: Array in ArenaPanel.ENTRIES:
		present += 1 if ResourceLoader.exists(String(entry[1])) else 0
	_check("no camp raised; one of every kind stands there from the start", creatures.get_child_count() == present,
			"%d of %d" % [creatures.get_child_count(), present])
	var still := 0
	await _wait(120)
	for c in creatures.get_children():
		if c is Fighter and (c as Fighter).act_serial == 0:
			still += 1
	_check("none of them starts a fight", still == creatures.get_children().filter(func(c: Node) -> bool: return c is Fighter).size(),
			"%d still" % still)
	(creatures.get_parent().get_node("ArenaPanel") as ArenaPanel)._clear()
	await _wait(3)
	_check("the hero stands on the floor", hero.is_on_floor() and absf(hero.global_position.y) < 0.1,
			"y %.2f" % hero.global_position.y)

	var panel := world.get_node("ArenaPanel") as ArenaPanel
	for entry: Array in ArenaPanel.ENTRIES:
		var path := String(entry[1])
		if not ResourceLoader.exists(path):
			_check("%s: its scene is there" % entry[0], false, path)
			continue
		var body := panel.call_up(path, bool(entry[2]))
		await _wait(45)
		var ok := is_instance_valid(body) and body.is_inside_tree()
		var y := body.global_position.y if ok else INF
		_check("%s: called up, on the floor" % entry[0], ok and y > -0.5 and y < 3.0, "y %.2f" % y)
	_check("all of them standing together", creatures.get_child_count() == ArenaPanel.ENTRIES.size(),
			str(creatures.get_child_count()))
	await _wait(30)

	panel._toggle_freeze()
	await _wait(2)
	var held := 0
	for c in creatures.get_children():
		held += 0 if c.is_physics_processing() else 1
	_check("hold still holds every one", held == creatures.get_child_count(), "%d held" % held)
	panel._toggle_freeze()

	panel._clear()
	await _wait(3)
	_check("the floor cleared", creatures.get_child_count() == 0, str(creatures.get_child_count()))

	# Waiting for his blow (the default): the minotaur stands by him and does
	# nothing; struck once it comes at him; and he loses nothing to it.
	hero.immortal = false
	var mino := panel.call_up("res://scenes/enemies/minotaur.tscn", true) as Brawler
	if mino != null:
		for i in 240:
			await physics_frame
		_check("waiting for his blow, the boss does not come at him", mino.act_serial == 0 and mino.mode == Fighter.Mode.GUARD,
				"acts %d, mode %d" % [mino.act_serial, mino.mode])
		mino.take_hit(10.0, mino.global_position + Vector3.UP, Vector3.FORWARD)
		var came := false
		for i in 600:
			await physics_frame
			if mino.act_serial > 0 and mino._moves().has(mino.act):
				came = true
		_check("struck, it fights back", came, "acts %d" % mino.act_serial)
		await process_frame
		_check("and he loses no health to it", hero.health >= hero.max_health, "%.0f of %.0f" % [hero.health, hero.max_health])
	panel._clear()
	await _wait(3)
	hero.immortal = true
	panel._wait_for_blow = false

	# Each creature on clips of its own, alone on the floor with him: its clips
	# are loaded, it sees him, comes at him and swings.
	for entry: Array in ArenaPanel.ENTRIES:
		var path := String(entry[1])
		if not ResourceLoader.exists(path):
			continue
		var body := panel.call_up(path, bool(entry[2]))
		if not body is Brawler:
			body.queue_free()
			await _wait(2)
			continue
		var b := body as Brawler
		var loaded := b._anim != null and b._anim.has_clip(b.walk_clip) and b._anim.has_clip(b.attacks[0])
		var swung := false
		for i in 600:
			await physics_frame
			if b.act_serial > 0 and b._moves().has(b.act):
				swung = true
				break
		_check("%s: its own clips, and it comes at him and swings" % entry[0], loaded and swung,
				"clips %s, acts %d, mode %d, %.1f m off" % [loaded, b.act_serial, b.mode,
				b.global_position.distance_to(hero.global_position)])
		panel._clear()
		await _wait(3)

	var rig := panel._rig()
	if rig != null and rig.faces.size() > 1:
		var was := rig.face
		panel._step_look(1)
		await _wait(3)
		_check("the look arrow steps his look", rig.face == (was + 1) % rig.faces.size(),
				"%d -> %d" % [was, rig.face])
		panel._step_look(-1)
		await _wait(3)
		_check("and back", rig.face == was, str(rig.face))

	print("arena_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)
