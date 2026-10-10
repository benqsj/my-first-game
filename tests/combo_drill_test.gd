extends SceneTree
## The combo practice on the test arena's board (2026-10-10): picked, one of
## the big ones does nothing but that one combo, over and over, coming in to it
## each time; for the ogre (its `COMBOS`) and the troll (its own).
##   Godot --headless --path . --script res://tests/combo_drill_test.gd

var _failures := 0
var _world: World
var _panel: ArenaPanel
var _hero: Player


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _arena() -> void:
	if _world != null:
		_world.queue_free()
		for i in 3:
			await process_frame
	_world = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(_world)
	for i in 30:
		await physics_frame
	_panel = _world.get_node("ArenaPanel") as ArenaPanel
	_panel._clear()
	_hero = _world.player()
	_hero.immortal = true
	for i in 5:
		await physics_frame


func _run() -> void:
	print("combo_drill_test")
	# the ogre, its second combo
	await _arena()
	_panel._drill_kind = 0
	_panel._drill_combo = 1
	_panel.start_drill()
	var ogre := _panel._drill_body as OgreFighter
	_check("the ogre called up for it", ogre != null and ogre.drill_combo == 1, "")
	var at := _hero.global_position
	for i in 60 * 20:
		await physics_frame
		if _hero.state != Player.State.DOWNED:
			_hero.global_position = Vector3(at.x, _hero.global_position.y, at.z)
	var only := true
	for c: int in ogre.combos_made:
		only = only and c == 1
	var allowed: Array = OgreFighter.COMBOS[1]["moves"]
	var strays: Array = []
	for m: int in ogre.moves_made:
		if not allowed.has(m):
			strays.append(m)
	_check("the ogre: that combo over and over", ogre.combos_made.size() >= 2 and only, str(ogre.combos_made))
	_check("the ogre: nothing else", strays.is_empty(), str(strays))
	# the troll, its third, enraged
	_panel._drill_kind = 1
	_panel._drill_combo = 2
	_panel._drill_enraged = true
	_panel.start_drill()
	await physics_frame
	var troll := _panel._drill_body as TrollFighter
	_check("the troll called up for it", troll != null and troll.drill_combo == 2 and troll.raging, "")
	for i in 60 * 16:
		await physics_frame
		if _hero.state != Player.State.DOWNED:
			_hero.global_position = Vector3(at.x, _hero.global_position.y, at.z)
	var t_only := true
	for c: int in troll.hand_combos_made:
		t_only = t_only and c == 2
	_check("the troll: that combo over and over", troll.hand_combos_made.size() >= 2 and t_only,
			str(troll.hand_combos_made))
	_check("the board names it", _panel._drill_combo_label.text.contains("swipe"), _panel._drill_combo_label.text)
	_panel.stop_drill()
	print("combo_drill_test: %s" % ("All checks passed." if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
