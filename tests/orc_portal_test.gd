extends SceneTree
## The orc palace's round 12 (claude/orc_portal_ideas.md, 2026-10-21):
## - blessings ([Boons]), and their doubles (frost + the third: the shatter): three lights laid, one walked into and taken, what
##   each does on a blow (fire, frost, the third's knock), on him (iron, swift);
## - roles ([FoeRoles]): the shaman's call, the elite; one two-sword orc;
## - every room to look round from F1 ([method Dungeon.view_place]);
## - goals ([RoomGoal]): the captain falls and the rest run; the totems ward
##   and hold the place till broken; holding out till the time is up;
## - the places of rest ([RestSpot]): the spring heals, the prisoner is freed;
## - the lord's fight ([LordFight]): his name, his bar, his second stage with
##   his guard, the guard falling with him;
## - the village grows ([Trades]): the orcs' tusks counted, the freed men's
##   trades bought at their stalls ([VillageTrade]) and put on him;
## - what is won is his for good: the lord's blade for his class.
##   Godot --headless --path . --script res://tests/orc_portal_test.gd

var _failures := 0
var d: Dungeon
var hero: Player


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run.call_deferred()


func _go(step: int, place: String, goal: String = "") -> void:
	for ch in d.choices:
		ch.queue_free()
	d.choices.clear()
	d._take_down(d.current)
	# (a step is gone through once in a run; here some twice)
	d.cleared[step] = false
	d._arrive_at(step, place, "", false, goal)
	hero.global_position = d.entry_point(0, step)
	hero.velocity = Vector3.ZERO
	await _wait(20)


func _foes(role: String) -> Array[Fighter]:
	var out: Array[Fighter] = []
	for item: Variant in d._room_foes[d.current]:
		if is_instance_valid(item) and (role == "" or String((item as Node).get_meta(&"role", "")) == role):
			out.append(item as Fighter)
	return out


func _run() -> void:
	root.get_node("Game").set(&"dungeon_id", 0)
	var world: World = load("res://scenes/world/dungeon.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await _wait(90)
	hero = world.player()
	hero.immortal = true
	d = world.get_node("Level/Rooms") as Dungeon
	await _boons()
	await _roles()
	await _goals()
	await _rest()
	await _lord()
	await _trades()
	_gift()
	print("orc_portal_test: %s" % ("All checks passed." if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _boons() -> void:
	print("blessings")
	await _go(1, "court")
	var c := d.centre(1)
	d.boons.lay(c, d)
	await _wait(2)
	_check("three lights laid", d.boons._lights.size() == 3, str(d.boons._lights.size()))
	var first: Dictionary = d.boons._lights[0]
	var id := StringName(first["id"])
	hero.global_position = (first["node"] as Node3D).global_position
	await _wait(5)
	_check("walked into one, it is his", d.boons.has(id), String(id))
	_check("the others gone out", d.boons._lights.is_empty())
	for b: StringName in [&"burn", &"frost", &"third", &"iron", &"swift"]:
		d.boons.take(b)
	_check("iron: blows hurt less", absf(hero.taken_scale - Boons.IRON_TAKEN) < 0.01, str(hero.taken_scale))
	d._wake(1)
	await _wait(10)
	var foe: Fighter = null
	for f in _foes(""):
		if f.visible and f.process_mode != Node.PROCESS_MODE_DISABLED and FoeRoles.role_of(f) == &"":
			foe = f
			break
	_check("a creature to try them on", foe != null)
	if foe != null:
		hero.global_position = foe.global_position + Vector3(0.0, 0.0, 2.0)
		var hit := HitInfo.make(20.0, foe.global_position + Vector3.UP, Vector3.FORWARD, false, true, hero)
		hit.by_blade = true
		foe.hurtbox().take(hit)
		var marks := Afflictions.of(foe, false)
		_check("fire on it", marks != null and marks.is_burning())
		_check("frost on it", marks != null and marks.is_chilled())
		# the doubles: frost and the third blow make the shatter
		var offered := d.boons.offer(3)
		_check("a double offered when both halves are his", offered.has(&"shatter") and not offered.has(&"storm_fire"),
				str(offered))
		d.boons.take(&"shatter")
		var before := foe.health
		for k in 3:
			var cut := HitInfo.make(20.0, foe.global_position + Vector3.UP, Vector3.FORWARD, false, true, hero)
			cut.by_blade = true
			foe.hurtbox().take(cut)
			await _wait(2)
		_check("the third blow on the frozen one shatters it", d.boons.shattered == 1,
				"%d, %.0f" % [d.boons.shattered, before - foe.health])


func _roles() -> void:
	print("roles")
	await _go(2, "great_hall")
	var shaman := _foes("shaman")
	var elite := _foes("elite")
	_check("a shaman in the great hall", shaman.size() == 1)
	_check("an elite in its second wave", elite.size() == 1 and d._reserve.has(elite[0]))
	if elite.size() == 1:
		_check("the elite bigger and harder", elite[0].visual_scale > 1.5 and elite[0].max_health > 300.0,
				"%.2f %.0f" % [elite[0].visual_scale, elite[0].max_health])
	d._wake(2)
	var empowered := false
	for f in 400:
		await physics_frame
		for item: Variant in d._alive:
			if is_instance_valid(item) and (item as Node).has_meta(&"empowered_until"):
				empowered = true
		if empowered:
			break
	_check("the shaman's call: its kin burn red", empowered)
	_check("the shaman keeps back", shaman.size() == 1 and shaman[0].held_back)
	await _go(3, "terrace")
	var orcs := _foes("")
	_check("one orc before the lord, with two swords", orcs.size() == 1 and FoeRoles.role_of(orcs[0]) == &"",
			str(orcs.size()))
	# every room to look round (F1's "Rooms")
	for place: String in Dungeon.VIEW:
		d.view_place(place)
		await _wait(3)
		var step := int(Dungeon.VIEW[place][0])
		if String(d.rooms[step]["place"]) != place or not d._room_foes[step].is_empty() or not d.choices.is_empty():
			_check("look round %s" % place, false)
			return
	_check("every room to look round, empty, no portals", true)


func _goals() -> void:
	print("goals")
	# the captain: down, and the rest run
	await _go(1, "court", "captain")
	var captain := _foes("captain")
	_check("a captain among them", captain.size() == 1)
	d._wake(1)
	await _wait(20)
	if captain.size() == 1:
		captain[0].call(&"_die")
		await _wait(30)
		_check("the captain down: the place is clear", d.cleared[1])
	# the totems: warded while they stand, the place held till they fall
	await _go(1, "cave", "totems")
	d._wake(1)
	await _wait(10)
	var goal := d._goal
	_check("three totems", goal != null and goal._totems.size() == 3)
	var warded := 0
	for f in _foes(""):
		if f.ward < 1.0:
			warded += 1
	_check("its creatures warded", warded > 0, str(warded))
	for f in _foes(""):
		if is_instance_valid(f) and not f.is_dead:
			f.call(&"_die")
	for body: Variant in d._reserve:
		if is_instance_valid(body):
			(body as Fighter).call(&"_die")
	await _wait(40)
	_check("all down, totems standing: not clear yet", not d.cleared[1])
	if goal != null:
		for t in goal._totems:
			for k in OrcTotem.BLOWS:
				t._last_hit = -1.0
				t.receive_hit(HitInfo.make(10.0, t.global_position + Vector3.UP, Vector3.FORWARD, false, false, hero))
		await _wait(20)
		_check("totems broken: clear", d.cleared[1])
	# holding out
	await _go(2, "crypt", "survive")
	d._wake(2)
	await _wait(10)
	_check("the rift stands open", is_instance_valid(d._rift))
	if d._goal != null:
		d._goal._left = 0.5
	await _wait(80)
	_check("held out: clear", d.cleared[2])


func _rest() -> void:
	print("rest")
	await _go(2, "spring")
	d._wake(2)
	await _wait(10)
	_check("the spring: clear at once", d.cleared[2])
	var spot := d._room_nodes[2].get_node_or_null(^"Rest") as RestSpot
	hero.health = hero.max_health * 0.3
	if spot != null:
		hero.global_position = spot.global_position + Vector3(0.0, 0.5, 1.0)
	await _wait(10)
	_check("in the water, healed whole", hero.health >= hero.max_health - 0.5, "%.0f/%.0f" % [hero.health, hero.max_health])
	await _go(2, "prison")
	d._wake(2)
	await _wait(10)
	spot = d._room_nodes[2].get_node_or_null(^"Rest") as RestSpot
	var game := root.get_node("Game")
	var before := (game.get(&"freed") as Array).size()
	if spot != null and spot._cage != null:
		hero.global_position = spot._cage.global_position + Vector3(-2.0, 0.5, 0.0)
	await _wait(10)
	_check("the prisoner freed, to live in the village", (game.get(&"freed") as Array).size() == before + 1)


func _lord() -> void:
	print("the lord")
	await _go(4, "throne")
	var fight := d._lord_fight
	_check("his fight made with his court", fight != null and fight.lord != null)
	if fight == null or fight.lord == null:
		return
	var lord := fight.lord as PackBrute
	_check("his name on his bar", String(lord.get_meta(&"boss_name", "")).begins_with(LordFight.NAME))
	_check("his guard made, out of sight", fight.guards.size() == LordFight.GUARDS and not fight.guards[0].visible)
	var game := root.get_node("Game")
	var tusks_before := int(game.get(&"tusks"))
	d._wake(4)
	await _wait(30)
	lord.health = lord.max_health * 0.45
	for f in 200:
		await physics_frame
		if fight.phase == 1:
			break
	await _wait(150)
	_check("half gone: his rage, his second stage", fight.phase == 1 and lord.raging)
	var out := 0
	for g in fight.guards:
		if is_instance_valid(g) and g.visible and d._alive.has(g):
			out += 1
	_check("his guard out of the fire", out == LordFight.GUARDS, str(out))
	lord._die()
	await _wait(20)
	var down := 0
	for g in fight.guards:
		if is_instance_valid(g) and bool(g.get("is_dead")):
			down += 1
	_check("down: his guard fall with him", fight.won and down == LordFight.GUARDS, str(down))
	await _wait(10)
	var got := int(game.get(&"tusks")) - tusks_before
	_check("his tusks and his guards'", got == Trades.LORD_TUSKS + LordFight.GUARDS, str(got))
	# the run's end: its summary up at the dawn
	d._viewing = false
	d._run_over = false
	if d._run_start < 0.0:
		d._run_start = 0.0
	for f in 600:
		await physics_frame
		if d.get_node_or_null(^"RunSummary") != null:
			break
	var summary := d.get_node_or_null(^"RunSummary") as RunSummary
	_check("won: the run's summary", summary != null and summary.won and int(summary.lines["tusks"]) >= Trades.LORD_TUSKS,
			str(summary.lines if summary != null else {}))


func _trades() -> void:
	print("the village's trades")
	var game := root.get_node("Game")
	var freed: Array = game.get(&"freed")
	_check("the first freed is the smith", Trades.trade_of(0) == "smith" and Trades.open(game, "smith"),
			str(freed.size()))
	game.set(&"tusks", 100)
	var stall := VillageTrade.new()
	stall.trade = "smith"
	stall.man_name = "გიორგი"
	d.add_child(stall)
	stall.global_position = hero.global_position + Vector3(1.5, 0.0, 0.0)
	await _wait(5)
	var scale_before := hero.dealt_scale
	stall.interact()
	stall.interact()
	_check("bought at his stall: his blade sharper", Trades.level(game, "smith") == 1
			and is_equal_approx(hero.dealt_scale, scale_before * 1.08) and int(game.get(&"tusks")) == 92,
			"%d %.3f %d" % [Trades.level(game, "smith"), hero.dealt_scale / scale_before, int(game.get(&"tusks"))])
	_check("a trade whose man is not freed: shut", not bool(game.call(&"buy_trade", "priest")))
	game.set(&"tusks", 3)
	stall.interact()
	_check("too few tusks: nothing", Trades.level(game, "smith") == 1)
	stall.queue_free()


func _gift() -> void:
	print("the lord's gift")
	var bag := hero.get_node_or_null(^"Inventory") as Inventory
	if bag == null:
		print("    (no bag)")
		return
	var item := bag.special_arm(Dungeon.LORD_GIFT, Dungeon.LORD_GIFT_NAME)
	_check("the lord's blade for his class", not item.is_empty() and String(item.get("name", "")).begins_with("The Orc Lord's"),
			String(item.get("name", "-")))
