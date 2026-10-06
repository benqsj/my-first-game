extends SceneTree
## Tariel and his shield. Once (2026-10-04) he could go without it, the block
## button then throwing his other string; since 2026-10-06 (the user's word)
## he keeps it: a look with nothing in his other hand gets it back.
##   Godot --headless --path . --script res://tests/shieldless_test.gd

var _failures := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: World = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(world)
	await _wait(30)
	(world.get_node("ArenaPanel") as ArenaPanel)._clear()
	var hero := world.player()
	hero.immortal = true
	await _wait(20)
	var rig := hero.rig as SkinnedRig
	var with_shield: Dictionary = PolysplitLook.default_look(&"tariel", "m")
	print("  look's off hand: ", with_shield.get("o", "?"))
	_check("with his shield: he holds one", rig.holds_shield())
	var sets: Array = rig.moves.get("string_sets", [])
	_check("two strings to throw", sets.size() >= 2, str(sets.size()))

	# Since 2026-10-06 (the user's word) Tariel does not put his shield down:
	# a look with nothing in his other hand gets the shield back, and the
	# block button still raises it. (What the block button did with no shield
	# — the other string — is left in the rig for a hero who has none.)
	var bare := with_shield.duplicate(true)
	bare["o"] = "none"
	hero.set_look(bare)
	await _wait(30)
	hero.call(&"_set_weapons_stowed", false)
	await _wait(30)
	_check("a look without his shield: he holds it still", rig.holds_shield())
	Input.action_press("block")
	await _wait(10)
	_check("and the block button raises it", hero.is_blocking)
	Input.action_release("block")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)
