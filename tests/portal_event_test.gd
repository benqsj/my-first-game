extends SceneTree
## The portal's altar ([PortalEvent], 2026-10-22; the merchant taken out,
## 2026-10-26):
## - the altar: blood takes a fifth of his life and lays a blessing's lights;
##   then the other is closed; gold takes half his gold for a heavier blade;
## - it is a place to rest, offered behind a portal now and then; the
##   merchant no more.
##   Godot --headless --path . --script res://tests/portal_event_test.gd

var _failures := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node("Game")
	game.set(&"dungeon_id", 0)
	var world: World = load("res://scenes/world/dungeon.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await _wait(5)
	while world.get_node_or_null("PipelineWarmup") != null:
		await process_frame
	var d := world.get_node("Level/Rooms") as Dungeon
	var hero := world.player()
	hero.immortal = true
	var purse := Purse.of(hero)

	_check("the altar is a place to rest", Dungeon.PLACES["altar"].has("rest"))
	_check("no merchant any more", not Dungeon.PLACES.has("merchant"))
	purse.give(500)
	var seen := {}
	for n in 400:
		seen[d._rest_pick(false, false)] = true
	_check("the altar offered, never the merchant", seen.has("altar") and not seen.has("merchant"), str(seen.keys()))
	_check("hurt: the spring", d._rest_pick(true, true) == "spring")
	var ev: PortalEvent

	# the altar
	d.view_place("altar")
	await _wait(20)
	ev = d._event_here()
	_check("the altar's place built", ev != null and ev.kind == "altar" and ev._deals.size() == 2)
	if ev == null:
		_end()
		return
	var max0 := hero.max_health
	var lights0 := root.find_children("*", "", true, false).filter(func(n: Node) -> bool: return String(n.name).begins_with("Boon")).size()
	hero.global_position = ev.to_global(ev._deals[0]["at"] as Vector3) + Vector3.UP * 0.3
	await _wait(5)
	ev.interact()
	await _wait(10)
	_check("blood: a fifth of his life", absf(hero.max_health - max0 * 0.8) < 0.5, "%.0f -> %.0f" % [max0, hero.max_health])
	var lights1 := root.find_children("*", "", true, false).filter(func(n: Node) -> bool: return String(n.name).begins_with("Boon")).size()
	_check("a blessing's lights laid", lights1 > lights0, "%d -> %d" % [lights0, lights1])
	var g0 := purse.gold
	hero.global_position = ev.to_global(ev._deals[1]["at"] as Vector3) + Vector3.UP * 0.3
	await _wait(5)
	ev.interact()
	await _wait(5)
	_check("one or the other: the gold altar closed after", purse.gold == g0 and not bool(ev._deals[1]["sold"]))
	_end()


func _end() -> void:
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)
