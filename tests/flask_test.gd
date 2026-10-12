extends SceneTree
## Flasks (the user's word, 2026-10-12): R drinks one, 4 of them, each 40 %
## of his health a moment into the drink; struck before that it is spilt;
## none left, none drunk; all back after a death; the ogre at him for it.

var _failed := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _initialize() -> void:
	_run.call_deferred()


func _arena() -> Array:
	var world: World = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(world)
	for i in 30:
		await physics_frame
	var panel := world.get_node("ArenaPanel") as ArenaPanel
	panel._clear()
	return [world, panel, world.player()]


func _done(world: Node) -> void:
	world.queue_free()
	for i in 3:
		await process_frame


func _run() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	# the arena keeps him whole, and he mends on his own: neither here
	(a[1] as ArenaPanel)._unhurt = false
	hero.mend_rate = 0.0
	_check("he carries four", hero.flasks_left == 4 and hero.flask_count == 4, str(hero.flasks_left))
	Controls.apply()
	_check("R is the flask", InputMap.has_action(&"heal"))
	hero.health = 100.0
	var drank := hero._drink()
	var t0 := hero._now()
	_check("he drinks", drank and hero.flasks_left == 3 and hero.drinking(), "left %d" % hero.flasks_left)
	var healed_at := -1.0
	while hero._now() - t0 < 3.0:
		await physics_frame
		if healed_at < 0.0 and hero.health > 100.5:
			healed_at = hero._now() - t0
	_check("a moment into it, 40 % of his health", absf(hero.health - (100.0 + hero.max_health * 0.4)) < 1.0
			and healed_at > 0.3, "health %.1f at %.2f s" % [hero.health, healed_at])
	# struck before it goes down: spilt
	hero.health = 100.0
	hero._drink()
	await physics_frame
	hero._take_damage(5.0)
	for i in 150:
		await physics_frame
	_check("struck while drinking, it is spilt", hero.health < 100.0 and hero.flasks_left == 2,
			"health %.1f, left %d" % [hero.health, hero.flasks_left])
	hero.flasks_left = 0
	for i in 30:
		await physics_frame
	_check("none left, none drunk", not hero._drink())
	hero._die()
	for i in int((hero.respawn_time + 1.0) * 60.0):
		await physics_frame
	_check("all four back after a death", hero.flasks_left == 4 and not hero.is_dead, str(hero.flasks_left))
	await _done(a[0])
	# the ogre at him for it
	a = await _arena()
	hero = a[2]
	var panel: ArenaPanel = a[1]
	var ahead := -hero.global_basis.z
	ahead.y = 0.0
	var ogre := panel.call_up("res://scenes/enemies/pack/ogre.tscn", false, hero.global_position + ahead.normalized() * 9.0) as OgreFighter
	ogre.max_health = 99999.0
	ogre.health = 99999.0
	await physics_frame
	ogre._rouse(hero)
	ogre.spacing_time = Vector2.ZERO
	var start := hero.global_position
	for i in 30:
		await physics_frame
		hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
		ogre._cooldown = 99.0
	var before := ogre.punishes_made
	hero._drink()
	for i in 40:
		await physics_frame
		hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
	_check("the ogre comes at him for a drink", ogre.punishes_made > before, "%d" % (ogre.punishes_made - before))
	await _done(a[0])
	print("flask_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)
