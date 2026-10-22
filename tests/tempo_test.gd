extends SceneTree
## A creature's tempo (the user's word, 2026-10-23: the minotaur a little
## faster; from F1 any creature sped up): its clips' rate and its moves' clock
## ([method HitFeel.pace]) and its paces on the ground go with it; the minotaur
## is a little faster than it was; every creature of F1's board is there.
##   godot --headless --path . --script res://tests/tempo_test.gd

var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		_failed += 1


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)

	var mino := (load("res://scenes/enemies/minotaur.tscn") as PackedScene).instantiate() as Monster
	world.add_child(mino)
	await process_frame
	_check("the minotaur a little faster than its own (%.2f)" % mino.tempo, mino.tempo > 1.05 and mino.tempo < 1.4)
	var chase := float(mino.get(&"chase_speed"))
	_check("its chase as fast as its tempo (%.2f)" % chase, is_equal_approx(chase, 3.6 * mino.tempo))
	_check("its clips and moves at its tempo", is_equal_approx(HitFeel.pace(mino), mino.tempo))
	mino.set_tempo(1.5)
	_check("set again, from its own paces, not the sped ones (%.2f)" % float(mino.get(&"chase_speed")),
			is_equal_approx(float(mino.get(&"chase_speed")), 3.6 * 1.5))
	_check("and its walk (%.2f)" % mino.speed, is_equal_approx(mino.speed, 1.5 * 1.5))
	mino.set_meta(&"bite_until", HitFeel.now_ms() + 5000)
	_check("held in a bite, still all but still", HitFeel.pace(mino) < 0.5)
	mino.remove_meta(&"bite_until")
	mino.set_tempo(1.0)
	_check("back to 1", is_equal_approx(float(mino.get(&"chase_speed")), 3.6))

	var orc := (load("res://scenes/enemies/pack/orc.tscn") as PackedScene).instantiate() as Monster
	world.add_child(orc)
	await process_frame
	_check("the others as they were", is_equal_approx(orc.tempo, 1.0) and is_equal_approx(HitFeel.pace(orc), 1.0))

	var missing: Array = []
	for e: Array in ArenaPanel.ENTRIES:
		if not ResourceLoader.exists(String(e[1])):
			missing.append(e[0])
	_check("every creature of F1's board there %s" % str(missing), missing.is_empty())
	var names: Array = ArenaPanel.ENTRIES.map(func(e: Array) -> String: return String(e[0]))
	for want: String in ["Minotaur", "Pig butcher", "Ghost skull", "Dragonet", "Imp", "Puglin", "Wolf"]:
		_check("%s on the board" % want, names.has(want))
	_check("F1 starts at x1", is_equal_approx(ArenaPanel.TEMPOS[0], 1.0))
	print("FAILED %d" % _failed if _failed > 0 else "ALL PASSED")
	quit(1 if _failed > 0 else 0)
