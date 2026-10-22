extends SceneTree
## The portal's merchant and altar ([PortalEvent], 2026-10-22):
## - the merchant: three wares on his table, each bought for its price in
##   gold, and on the hero then; not bought without the gold;
## - the altar: blood takes a fifth of his life and lays a blessing's lights;
##   then the other is closed; gold takes half his gold for a heavier blade;
## - both are places to rest, offered behind a portal now and then.
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

	_check("both are places to rest", Dungeon.PLACES["merchant"].has("rest") and Dungeon.PLACES["altar"].has("rest"))
	var seen := {}
	for n in 400:
		seen[d._rest_pick(false, false)] = true
	_check("the merchant is not offered to one with no gold", not seen.has("merchant"), str(seen.keys()))
	purse.give(500)
	seen = {}
	for n in 400:
		seen[d._rest_pick(false, false)] = true
	_check("with gold: the merchant and the altar both offered", seen.has("merchant") and seen.has("altar"), str(seen.keys()))
	_check("hurt: the spring", d._rest_pick(true, true) == "spring")

	# the merchant
	d.view_place("merchant")
	await _wait(20)
	var ev := d._event_here()
	_check("the merchant's place built", ev != null and ev.kind == "merchant")
	if ev == null:
		_end()
		return
	_check("three wares on his table", ev._deals.size() == 3)
	var gold0 := purse.gold
	var first: Dictionary = ev._deals[0]
	var id := String(first["id"])
	var price := int(PortalEvent.WARES[id]["price"])
	var hp0 := hero.max_health
	var book := hero.get_node_or_null("Leveling") as Leveling
	hero.health = hero.max_health * 0.5
	hero.flasks_left = 0
	hero.global_position = ev.to_global(first["at"] as Vector3) + Vector3.UP * 0.3
	await _wait(5)
	_check("the price shown as he comes up", ev._prompt.visible and ev._prompt.text.contains(str(price)), ev._prompt.text)
	ev.interact()
	await _wait(5)
	_check("bought: its price out of his purse", purse.gold == gold0 - price, "%d -> %d (%s %d)" % [gold0, purse.gold, id, price])
	var on := false
	match id:
		"flask":
			on = hero.flasks_left == hero.flask_count
		"heal":
			on = hero.health >= hero.max_health - 0.5
		"life":
			on = hero.max_health > hp0 * 1.14
		"blade", "boon":
			on = true
	_check("and on him (%s)" % id, on)
	_check("gone off the table", bool(first["sold"]) and not (first["node"] as Node3D).visible)
	purse.take(purse.gold)
	var second: Dictionary = ev._deals[1]
	hero.global_position = ev.to_global(second["at"] as Vector3) + Vector3.UP * 0.3
	await _wait(5)
	ev.interact()
	await _wait(5)
	_check("no gold: not sold", not bool(second["sold"]) and ev._prompt.text.contains("არ გყოფნის"), ev._prompt.text)

	# the altar
	purse.give(200)
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
