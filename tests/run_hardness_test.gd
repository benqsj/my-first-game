extends SceneTree
## The run kept hard however strong the heroes grow, however many they are
## (Dungeon.hard_factors / net_harden; the user's word, 2026-10-22):
## - nothing extra for a run that gave what is expected, or for one hero;
## - a run that made his blows much heavier: its bosses' health by the excess
##   (no more than POWER_MOST), their blows by half of it; the other
##   creatures from the sixth step on, by its root; before that, not at all;
## - two heroes: a boss and the lord's guard COOP_BOSS more, the others
##   COOP_FOE more, the stance COOP_STANCE more;
## - the lord at the end, made harder as his place wakes, once.
##   Godot --headless --path . --script res://tests/run_hardness_test.gd

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


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.02


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
	var last := d.steps.size() - 1

	var f := d.hard_factors(last, 1, 1.0)
	_check("one hero, nothing given: as it was", _near(f["boss"], 1.0) and _near(f["foe"], 1.0) and _near(f["hit"], 1.0), str(f))
	f = d.hard_factors(last, 1, Dungeon.EXPECT_POWER)
	_check("one hero, what a run is expected to give: as it was", _near(f["boss"], 1.0), str(f))
	f = d.hard_factors(last, 1, Dungeon.EXPECT_POWER * 2.0)
	_check("blows twice as heavy as expected: only part made up for", _near(f["boss"], 1.0 + Dungeon.BOSS_SHARE)
			and _near(f["hit"], minf(1.0 + Dungeon.HIT_SHARE, Dungeon.POWER_HIT_MOST)) and _near(f["foe"], 1.0 + Dungeon.FOE_SHARE)
			and f["boss"] < 2.0, str(f))
	f = d.hard_factors(last, 1, 9.0)
	_check("no more than POWER_MOST", _near(f["boss"], Dungeon.POWER_MOST), str(f))
	f = d.hard_factors(1, 1, 3.0)
	_check("early places: the other creatures as they were", _near(f["foe"], 1.0), str(f))
	f = d.hard_factors(last, 2, 1.0)
	_check("two heroes: the boss and its guard more, the others more, the stance more",
			_near(f["boss"], 1.0 + Dungeon.COOP_BOSS) and _near(f["guard"], 1.0 + Dungeon.COOP_BOSS)
			and _near(f["foe"], 1.0 + Dungeon.COOP_FOE) and _near(f["stance"], 1.0 + Dungeon.COOP_STANCE), str(f))

	# what the run gave: five blades
	var p0 := d.run_power()
	for k in 5:
		d.rewards_given.append("blade")
	var p1 := d.run_power()
	_check("five blades: the run's power", _near(p1 / p0, pow(1.15, 5.0)), "%.2f -> %.2f" % [p0, p1])

	# the lord's place, woken
	d._take_down(d.current)
	d._arrive_at(last, "throne", "")
	await _wait(20)
	var lord: Node3D = null
	for body: Variant in d._room_foes[last]:
		if is_instance_valid(body) and (body as Node).has_meta(&"boss_name"):
			lord = body
	if lord == null and is_instance_valid(d._lord_fight):
		lord = d._lord_fight.lord
	_check("the lord there", lord != null)
	if lord == null:
		_end()
		return
	var hp0 := float(lord.get(&"max_health"))
	var hit0 := float(lord.get(&"hit_damage"))
	var guard0 := float(d._lord_fight.guards[0].get(&"max_health")) if not d._lord_fight.guards.is_empty() else -1.0
	d._wake(last)
	await _wait(5)
	var want := d.hard_factors(last, 1, d.run_power())
	var excess := d.run_power() / Dungeon.EXPECT_POWER
	_check("the lord's health by part of the run's power: harder, still sooner killed",
			_near(float(lord.get(&"max_health")) / hp0, want["boss"]) and float(lord.get(&"max_health")) > hp0 * 1.2
			and float(lord.get(&"max_health")) / hp0 < excess, "%.0f -> %.0f (power over expected %.2f)" % [hp0, float(lord.get(&"max_health")), excess])
	_check("and whole", _near(float(lord.get(&"health")), float(lord.get(&"max_health"))))
	_check("his blows heavier", float(lord.get(&"hit_damage")) > hit0 * 1.1, "%.0f -> %.0f" % [hit0, float(lord.get(&"hit_damage"))])
	if guard0 > 0.0:
		_check("one hero: his guard as it was", _near(float(d._lord_fight.guards[0].get(&"max_health")), guard0))
	var once := float(lord.get(&"max_health"))
	d._hold_hard(last)
	await _wait(2)
	_check("made harder once only", _near(float(lord.get(&"max_health")), once))
	_end()


func _end() -> void:
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)
