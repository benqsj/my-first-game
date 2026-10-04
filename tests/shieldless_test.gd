extends SceneTree
## Tariel with no shield in his hand (his look's off hand "none"; the user's
## word, 2026-10-04): the block button raises nothing — no empty arm held up —
## and throws the other string instead, the one F6 would pick; the attack
## button keeps the string F6 picked. With his shield back, the block button
## raises it again.
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
	var main: Array = sets[rig._main_string]["clips"]
	var other: Array = sets[(rig._main_string + 1) % sets.size()]["clips"]

	var bare := with_shield.duplicate(true)
	bare["o"] = "none"
	hero.set_look(bare)
	await _wait(30)
	hero.call(&"_set_weapons_stowed", false)
	await _wait(30)
	_check("no shield: he holds none", not rig.holds_shield())
	Input.action_press("block")
	await _wait(3)
	var right := String(rig._act_clip)
	await _wait(20)
	_check("the block button raises no guard", not hero.is_blocking)
	Input.action_release("block")
	_check("it throws the other string's first cut", right == String(other[0]), "%s (want %s)" % [right, other[0]])
	await _wait(150)
	Input.action_press("attack")
	await _wait(3)
	var left := String(rig._act_clip)
	Input.action_release("attack")
	_check("the attack button keeps F6's string", left == String(main[0]), "%s (want %s)" % [left, main[0]])
	await _wait(150)

	hero.set_look(with_shield)
	await _wait(30)
	Input.action_press("block")
	await _wait(10)
	_check("his shield back: the block button raises it", hero.is_blocking)
	Input.action_release("block")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)
