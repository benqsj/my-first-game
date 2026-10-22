extends SceneTree
## A cut landing felt by the one who threw it (gameplay_plan B2, 2026-10-22):
## a small one, a little knock of his view; a big one that does not stop for
## it, a harder knock and shake, and a deep body-blow under the steel (and a
## heavy blow, the rush of air too).
##   Godot --headless --path . --script res://tests/bite_felt_test.gd

var _failures := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _sounds() -> int:
	return root.find_children("*", "AudioStreamPlayer3D", true, false).size()


func _initialize() -> void:
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _wait(2)
	world.creature_think_distance = 0.0
	var hero := world.player()
	hero.immortal = true
	var imp: Node3D = null
	for node in world.get_node("Enemies").get_children():
		(node as Node).set_physics_process(false)
		if node is Fighter and imp == null:
			imp = node
	await _wait(30)
	imp.global_position = hero.global_position - hero.global_basis.z * 2.0
	await _wait(2)
	var cam := hero.camera
	if cam.has_meta(&"nudge"):
		cam.remove_meta(&"nudge")
	var s0 := _sounds()
	hero._bite_felt(imp, 1.0, 1.0)
	_check("a small one: his view knocked a little", cam.has_meta(&"nudge"))
	_check("a small one: no body-blow under it", _sounds() == s0, "%d -> %d" % [s0, _sounds()])
	await _wait(30)
	cam.remove_meta(&"nudge")
	var peak := 0.0
	s0 = _sounds()
	hero._bite_felt(imp, 1.8, 0.0)
	var s1 := _sounds()
	for i in 10:
		await process_frame
		peak = maxf(peak, Vector2(cam.h_offset, cam.v_offset).length())
	_check("a big one: knocked harder", peak > hero.bite_knock_small * 1.5, "%.3f m" % peak)
	_check("a big one, a heavy blow: the body-blow and the rush under the steel", s1 >= s0 + 2, "%d -> %d" % [s0, s1])
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)
