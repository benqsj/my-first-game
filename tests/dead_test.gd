extends SceneTree

## The zombies ([ZombieFighter]) and the ghoul ([GhoulFighter]) in the test
## arena: a zombie lies under the ground, unseen and unlockable, until he
## comes near, then climbs out and its blows land; roused, it brings the dead
## round it; cut down it may get up again once, and then dies for good. The
## ghoul leaps at him from a few paces and lands on him, and darts off after
## its swings.
##
##   godot --headless --path . --script res://tests/dead_test.gd

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
	panel._wait_for_blow = false
	var hero := world.player()
	hero.immortal = true
	return [world, panel, hero]


func _ahead(hero: Player, d: float, side: float = 0.0) -> Vector3:
	var fwd := -hero.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	return hero.global_position + fwd * d + fwd.cross(Vector3.UP) * side


func _done(world: Node) -> void:
	world.queue_free()
	for i in 3:
		await process_frame


func _run() -> void:
	await _buried()
	await _waiting()
	await _horde()
	await _getup()
	await _ghoul()
	print("dead_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


func _buried() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var start := hero.global_position
	var z := (a[1] as ArenaPanel).call_up("res://scenes/enemies/pack/zombie_m.tscn", false, _ahead(hero, 14.0)) as ZombieFighter
	for i in 60:
		await physics_frame
		hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
	_check("a zombie lies under the ground, unseen", z.under and not z.body.visible and not z.is_in_group(&"enemy"),
			"under %s visible %s" % [z.under, z.body.visible])
	var near := z.global_position + (start - z.global_position).normalized() * 5.0
	var rose := false
	var struck := [0]
	hero.struck.connect(func(_d: float, _b: bool) -> void: struck[0] += 1)
	for f in 60 * 12:
		await physics_frame
		hero.global_position = Vector3(near.x, hero.global_position.y, near.z)
		if z.act == Brawler.RISE:
			rose = true
	_check("he comes near: it climbs out of the ground", rose and not z.under and z.body.visible and z.is_in_group(&"enemy"))
	_check("and its blows land on him", struck[0] >= 2, "%d" % struck[0])
	await _done(a[0])


## The arena's rule (wait for his blow): under the ground all the same, out
## of it when he comes near, and then it waits for his blow.
func _waiting() -> void:
	var a: Array = await _arena()
	var panel: ArenaPanel = a[1]
	var hero: Player = a[2]
	panel._wait_for_blow = true
	var start := hero.global_position
	var z := panel.call_up("res://scenes/enemies/pack/zombie_m.tscn", false, _ahead(hero, 14.0)) as ZombieFighter
	for i in 30:
		await physics_frame
		hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
	_check("waiting for his blow, it is still under the ground", z.under and not z.body.visible)
	var near := z.global_position + (start - z.global_position).normalized() * 5.0
	var rose := false
	for f in 60 * 5:
		await physics_frame
		hero.global_position = Vector3(near.x, hero.global_position.y, near.z)
		rose = rose or z.act == Brawler.RISE
	_check("he comes near: it climbs out and waits for his blow", rose and not z.under
			and z.mode == Fighter.Mode.GUARD, "mode %d" % z.mode)
	await _done(a[0])


func _horde() -> void:
	var a: Array = await _arena()
	var panel: ArenaPanel = a[1]
	var hero: Player = a[2]
	var one := panel.call_up("res://scenes/enemies/pack/zombie_m.tscn", false, _ahead(hero, 20.0, -3.0)) as ZombieFighter
	var two := panel.call_up("res://scenes/enemies/pack/zombie_f.tscn", false, _ahead(hero, 22.0, 4.0)) as ZombieFighter
	for i in 10:
		await physics_frame
	one._rouse(hero)
	await physics_frame
	_check("roused, it brings the dead round it", two.mode != Fighter.Mode.GUARD and two._quarry == hero,
			"mode %d" % two.mode)
	await _done(a[0])


func _getup() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var z := (a[1] as ArenaPanel).call_up("res://scenes/enemies/pack/zombie_f.tscn", false, _ahead(hero, 3.0)) as ZombieFighter
	await physics_frame
	z.under = false
	z.getup_chance = 1.0
	z._rouse(hero)
	await physics_frame
	z._receive(9999.0, z.global_position + Vector3.UP, Vector3.FORWARD, hero)
	await physics_frame
	_check("cut down, it only falls the first time", not z.is_dead and z.act == ZombieFighter.DOWN, "act %d" % z.act)
	var up := false
	for f in 60 * 7:
		await physics_frame
		if z.act == ZombieFighter.GETUP:
			up = true
		if up and z.act != ZombieFighter.GETUP:
			break
	_check("and gets up again", up and not z.is_dead and z.health >= z.max_health * 0.3, "health %.0f" % z.health)
	z._receive(9999.0, z.global_position + Vector3.UP, Vector3.FORWARD, hero)
	await physics_frame
	_check("the second time it is dead", z.is_dead)
	await _done(a[0])


func _ghoul() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var start := hero.global_position
	var g := (a[1] as ArenaPanel).call_up("res://scenes/enemies/pack/ghoul.tscn", false, _ahead(hero, 9.0)) as GhoulFighter
	g.max_health = 9999.0
	g.health = 9999.0
	var struck := [0]
	var in_leap := [false]
	var leap_hits := [0]
	hero.struck.connect(func(_d: float, _b: bool) -> void:
		struck[0] += 1
		if in_leap[0]:
			leap_hits[0] += 1)
	var leaps := 0
	var darts := 0
	var serial := -1
	var was_darting := false
	for f in 60 * 16:
		await physics_frame
		hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
		in_leap[0] = g.act == GhoulFighter.LEAP
		if g.act_serial != serial:
			serial = g.act_serial
			if g.act == GhoulFighter.LEAP:
				leaps += 1
		if g._dart_left > 0.0 and not was_darting:
			darts += 1
		was_darting = g._dart_left > 0.0
	_check("the ghoul leaps at him", leaps >= 2, "%d leaps" % leaps)
	_check("and lands on him", leap_hits[0] >= leaps - 1 and leap_hits[0] >= 1, "%d of %d" % [leap_hits[0], leaps])
	_check("it darts off after its swings", darts >= 2, "%d" % darts)
	await _done(a[0])
